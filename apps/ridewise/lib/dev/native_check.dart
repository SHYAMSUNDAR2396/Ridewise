// Debug entrypoint that exercises the real native stack on a device or emulator:
//   flutter build apk --debug --target-platform android-arm64 -t lib/dev/native_check.dart
// Results are printed with the NATIVECHECK prefix: adb logcat -s flutter
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:llamadart/llamadart.dart';

import '../domain/models.dart';
import '../domain/text.dart';
import '../generation/native/model_files.dart';
import '../generation/native/runtime.dart';
import '../generation/native/sherpa_speech.dart';
import '../generation/types.dart';

void main() {
  // ignore: avoid_print
  print('NATIVECHECK main() isolate=${Isolate.current.hashCode}');
  runApp(const MaterialApp(home: NativeCheck()));
}

class NativeCheck extends StatefulWidget {
  const NativeCheck({super.key});

  @override
  State<NativeCheck> createState() => _NativeCheckState();
}

class _NativeCheckState extends State<NativeCheck> {
  final _lines = <String>[];

  void _log(String message) {
    // ignore: avoid_print
    print('NATIVECHECK $message');
    if (mounted) setState(() => _lines.add(message));
  }

  String get _rss {
    try {
      final line = File(
        '/proc/self/status',
      ).readAsLinesSync().firstWhere((l) => l.startsWith('VmRSS'));
      return line.replaceAll(RegExp(r'\s+'), ' ');
    } catch (_) {
      return 'rss n/a';
    }
  }

  @override
  void initState() {
    super.initState();
    // ignore: avoid_print
    print('NATIVECHECK initState state=${identityHashCode(this)}');
    _run();
  }

  // Build with --dart-define=STEPS=speechlong to run only some steps (default: all).
  static const _only = String.fromEnvironment('STEPS');

  Future<void> _step(String name, Future<void> Function() body) async {
    if (_only.isNotEmpty && !_only.split(',').any(name.startsWith)) return;
    final watch = Stopwatch()..start();
    _log('--- $name: start ($_rss)');
    try {
      await body();
      _log(
        '--- $name: done in ${(watch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s ($_rss)',
      );
    } catch (error, stack) {
      _log('--- $name: FAILED $error\n$stack');
    }
  }

  Future<void> _run() async {
    // audio_service starts a second Flutter engine (a second main()) unless MainActivity extends
    // AudioServiceActivity; only the run that wins this lock does the work. Delete the lock
    // before each launch: adb shell run-as com.ridewise.ridewise rm app_flutter/check.lock
    try {
      File('${await documentsPath()}/check.lock').createSync(exclusive: true);
    } on FileSystemException {
      _log('duplicate main() (second engine) - skipping');
      return;
    }
    late ModelPaths models;

    await _step('models', () async {
      var last = -5;
      models = await ensureModels((percent) {
        if (percent - last >= 5 || percent == 100) {
          last = percent;
          _log('models $percent%');
        }
      });
      _log('kokoro=${models.kokoroDir} gemma=${models.gemmaPath}');
    });

    await _step('speech', () async {
      final docs = await documentsPath();
      final speech = SherpaSpeech(models.kokoroDir);
      try {
        const samples = {
          CapsuleLanguage.enIN:
              'Mumbai suburban railway carries over seven million passengers every day. '
              'It was built in eighteen fifty three, and it remains the backbone of the city.',
          CapsuleLanguage.hiIN:
              'मुंबई की लोकल ट्रेन हर दिन सत्तर लाख से ज़्यादा यात्रियों को ले जाती है। '
              'यह अठारह सौ तिरपन में शुरू हुई थी, और आज भी शहर की रीढ़ है।',
        };
        for (final entry in samples.entries) {
          for (final pass in ['cold', 'warm']) {
            final watch = Stopwatch()..start();
            final result = await speech.synthesizeToFile(
              entry.value,
              '$docs/check-${entry.key.code}-$pass.wav',
              entry.key,
            );
            final seconds = watch.elapsedMilliseconds / 1000;
            _log(
              'tts ${entry.key.code} $pass: gen ${seconds.toStringAsFixed(2)}s, '
              'audio ${result.durationSeconds.toStringAsFixed(2)}s, '
              'RTF ${(seconds / result.durationSeconds).toStringAsFixed(2)} ($_rss)',
            );
          }
        }
      } finally {
        await speech.destroy();
      }
    });

    await _step('speechlong', () async {
      final docs = await documentsPath();
      final speech = SherpaSpeech(models.kokoroDir);
      const hindi =
          'नमस्ते! आज हम व्यक्तिगत वित्त के बारे में बात करेंगे। वित्तीय प्रबंधन का अर्थ है पैसे को कुशलता से प्रबंधित करना। '
          'यह आपके जीवन को बेहतर बनाने का एक महत्वपूर्ण तरीका है। वित्त क्या है? यह आपकी संपत्ति और दायित्वों का प्रबंधन करने की प्रक्रिया है। '
          'इसमें आपके पास मौजूद धन को बुद्धिमानी से खर्च करना और बचाना शामिल है। हर महीने की शुरुआत में अपना बजट बनाइए। '
          'अपनी आमदनी और खर्चों की सूची लिखिए। बचत को सबसे पहले अलग रखिए।';
      const english =
          'Welcome to this quick guide on understanding your money. I am here to help you take control of your finances. '
          'Let us start by understanding your current financial situation. Where does your money currently go each month? '
          'Write down your income and your expenses. Then set aside your savings first, before you spend on anything else. '
          'A simple budget is the strongest tool you have. Review it every month and adjust it when your life changes.';
      try {
        for (final entry in {
          CapsuleLanguage.enIN: english,
          CapsuleLanguage.hiIN: hindi,
        }.entries) {
          for (final pass in ['a', 'b']) {
            final watch = Stopwatch()..start();
            final result = await speech.synthesizeToFile(
              entry.value,
              '$docs/long-${entry.key.code}-$pass.wav',
              entry.key,
            );
            final seconds = watch.elapsedMilliseconds / 1000;
            _log(
              'long tts ${entry.key.code} $pass: ${entry.value.length} chars, gen ${seconds.toStringAsFixed(1)}s, '
              'audio ${result.durationSeconds.toStringAsFixed(1)}s, RTF ${(seconds / result.durationSeconds).toStringAsFixed(2)} ($_rss)',
            );
          }
        }
      } finally {
        await speech.destroy();
      }
    });

    await _step('speechsplit', () async {
      final docs = await documentsPath();
      final speech = SherpaSpeech(models.kokoroDir);
      const english =
          'Welcome to this quick guide on understanding your money. I am here to help you take control of your finances. '
          'Let us start by understanding your current financial situation. Where does your money currently go each month? '
          'Write down your income and your expenses. Then set aside your savings first, before you spend on anything else. '
          'A simple budget is the strongest tool you have. Review it every month and adjust it when your life changes.';
      const hindi =
          'नमस्ते! आज हम व्यक्तिगत वित्त के बारे में बात करेंगे। वित्तीय प्रबंधन का अर्थ है पैसे को कुशलता से प्रबंधित करना। '
          'यह आपके जीवन को बेहतर बनाने का एक महत्वपूर्ण तरीका है। वित्त क्या है? यह आपकी संपत्ति और दायित्वों का प्रबंधन करने की प्रक्रिया है। '
          'इसमें आपके पास मौजूद धन को बुद्धिमानी से खर्च करना और बचाना शामिल है। हर महीने की शुरुआत में अपना बजट बनाइए। '
          'अपनी आमदनी और खर्चों की सूची लिखिए। बचत को सबसे पहले अलग रखिए।';
      try {
        for (final entry in {
          CapsuleLanguage.enIN: english,
          CapsuleLanguage.hiIN: hindi,
        }.entries) {
          // Warm the engine first so load time does not distort the numbers.
          await speech.synthesizeToFile('Hello.', '$docs/warm.wav', entry.key);
          for (final size in [100, 200, 300]) {
            final sentences = splitIntoSegments(entry.value, size);
            final watch = Stopwatch()..start();
            var audio = 0.0;
            for (final (i, part) in sentences.indexed) {
              audio += (await speech.synthesizeToFile(
                part,
                '$docs/split-$size-$i.wav',
                entry.key,
              )).durationSeconds;
            }
            final seconds = watch.elapsedMilliseconds / 1000;
            _log(
              'split ${entry.key.code} max $size chars: ${sentences.length} calls, gen ${seconds.toStringAsFixed(1)}s, '
              'audio ${audio.toStringAsFixed(1)}s, RTF ${(seconds / audio).toStringAsFixed(2)}',
            );
          }
        }
      } finally {
        await speech.destroy();
      }
    });

    await _step('gemma', () async {
      final engine = LlamaEngine(LlamaBackend());
      try {
        final load = Stopwatch()..start();
        await engine.loadModel(
          models.gemmaPath,
          modelParams: const ModelParams(
            contextSize: 4096,
            gpuLayers: 0,
            preferredBackend: GpuBackend.cpu,
          ),
        );
        _log(
          'gemma load ${(load.elapsedMilliseconds / 1000).toStringAsFixed(1)}s ($_rss)',
        );

        const prompts = {
          'en':
              'Write about 80 words of a spoken audio script that explains what an index fund is, '
              'in clear Indian English. Plain sentences only, no lists or markdown.',
          'hi':
              'एक ऑडियो स्क्रिप्ट के लिए लगभग 80 शब्दों में सरल हिंदी (देवनागरी) में समझाइए कि इंडेक्स फंड क्या होता है। '
              'सिर्फ़ सादे वाक्य लिखिए, कोई सूची या मार्कडाउन नहीं।',
        };
        for (final entry in prompts.entries) {
          final watch = Stopwatch()..start();
          int? firstMs;
          final out = StringBuffer();
          await for (final chunk in engine.create([
            LlamaChatMessage.fromText(
              role: LlamaChatRole.user,
              text: entry.value,
            ),
          ], params: const GenerationParams(maxTokens: 220, temp: 0.7))) {
            final text = chunk.choices.first.delta.content;
            if (text != null && text.isNotEmpty) {
              firstMs ??= watch.elapsedMilliseconds;
              out.write(text);
            }
          }
          final totalMs = watch.elapsedMilliseconds;
          final tokens = await engine.getTokenCount(out.toString());
          final genSeconds = (totalMs - (firstMs ?? 0)) / 1000;
          _log(
            'gemma ${entry.key}: first token ${firstMs}ms, $tokens tokens in ${(totalMs / 1000).toStringAsFixed(1)}s, '
            '${genSeconds > 0 ? (tokens / genSeconds).toStringAsFixed(1) : 'n/a'} tok/s after first ($_rss)',
          );
          _log(
            'gemma ${entry.key} reply: ${out.toString().replaceAll('\n', ' | ')}',
          );
        }
      } finally {
        await engine.dispose();
      }
    });

    for (final language in [CapsuleLanguage.enIN, CapsuleLanguage.hiIN]) {
      await _step('capsule ${language.code}', () async {
        final request = CreateCapsuleRequest(
          trip: const TripDraft(
            manualSeconds: 240,
            transportMode: TransportMode.metro,
          ),
          topic: language == CapsuleLanguage.enIN
              ? 'Personal finance'
              : 'व्यक्तिगत वित्त',
          style: ListeningStyle.quickOverview,
          language: language,
        );
        var phase = '';
        final capsule = await generateCapsuleOnDevice(request, (progress) {
          final label =
              '${progress.phase.name} ${progress.done}/${progress.total}';
          if (progress.phase != GenerationPhase.models && label != phase) {
            phase = label;
            _log('progress $label');
          }
        });
        _log(
          'capsule ${language.code}: ${capsule.segments.length} segments, '
          'audio ${capsule.audioSeconds.toStringAsFixed(1)}s of target ${capsule.targetSeconds}s, '
          'title "${capsule.title}"',
        );
        final text = capsule.transcript;
        _log(
          'capsule ${language.code} transcript (${text.length} chars): '
          '${text.substring(0, text.length < 300 ? text.length : 300)}',
        );
      });
    }

    _log('ALL DONE');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Native check')),
    body: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final line in _lines)
          Text(line, style: const TextStyle(fontSize: 11)),
      ],
    ),
  );
}
