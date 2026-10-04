import 'dart:async';
import 'dart:isolate';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../../domain/models.dart';
import '../types.dart';

// Kokoro speaker ids in the multi-language model: 3 = af_heart (English), 31 = hf_alpha (Hindi).
const _speakerId = {CapsuleLanguage.enIN: 3, CapsuleLanguage.hiIN: 31};

/// Kokoro speech through sherpa-onnx. Synthesis runs in its own isolate so the UI
/// never stalls; engines are created there on first use, one per language.
class SherpaSpeech implements SpeechEngine {
  SherpaSpeech(this.modelDir);

  final String modelDir;

  Isolate? _isolate;
  SendPort? _send;
  ReceivePort? _receive;
  final _pending = <int, Completer<double>>{};
  int _nextId = 0;
  Future<void>? _starting;

  Future<void> _start() async {
    final receive = ReceivePort();
    final ready = Completer<SendPort>();
    receive.listen((message) {
      if (message is SendPort) {
        ready.complete(message);
        return;
      }
      final reply = message as List<Object?>;
      final done = _pending.remove(reply[0] as int);
      if (reply[1] is String) {
        done?.completeError(StateError(reply[1] as String));
      } else {
        done?.complete(reply[1] as double);
      }
    });
    _receive = receive;
    _isolate = await Isolate.spawn(_worker, [receive.sendPort, modelDir]);
    _send = await ready.future;
  }

  @override
  Future<({double durationSeconds})> synthesizeToFile(
    String text,
    String filePath,
    CapsuleLanguage language,
  ) async {
    await (_starting ??= _start());
    final id = _nextId++;
    final done = _pending[id] = Completer<double>();
    _send!.send([id, text, filePath, language.index]);
    return (durationSeconds: await done.future);
  }

  /// Frees the native engines. Safe to call more than once.
  Future<void> destroy() async {
    _send?.send(null);
    _receive?.close();
    _isolate?.kill();
    _isolate = null;
    _send = null;
    _receive = null;
    _starting = null;
    for (final waiting in _pending.values) {
      waiting.completeError(StateError('Speech engine was destroyed.'));
    }
    _pending.clear();
  }
}

void _worker(List<Object?> args) {
  final toParent = args[0] as SendPort;
  final dir = args[1] as String;
  sherpa.initBindings();

  final engines = <CapsuleLanguage, sherpa.OfflineTts>{};
  sherpa.OfflineTts engineFor(CapsuleLanguage language) =>
      engines.putIfAbsent(language, () {
        final english = language == CapsuleLanguage.enIN;
        return sherpa.OfflineTts(
          sherpa.OfflineTtsConfig(
            model: sherpa.OfflineTtsModelConfig(
              kokoro: sherpa.OfflineTtsKokoroModelConfig(
                model: '$dir/model.int8.onnx',
                voices: '$dir/voices.bin',
                tokens: '$dir/tokens.txt',
                dataDir: '$dir/espeak-ng-data',
                dictDir: '$dir/dict',
                lexicon: english ? '$dir/lexicon-us-en.txt' : '',
                lang: english ? 'en-us' : 'hi',
              ),
              numThreads: 2,
              debug: false,
            ),
          ),
        );
      });

  final inbox = ReceivePort();
  toParent.send(inbox.sendPort);
  inbox.listen((message) {
    if (message == null) {
      for (final engine in engines.values) {
        engine.free();
      }
      inbox.close();
      return;
    }
    final request = message as List<Object?>;
    final id = request[0] as int;
    try {
      final language = CapsuleLanguage.values[request[3] as int];
      final audio = engineFor(
        language,
      ).generate(text: request[1] as String, sid: _speakerId[language]!);
      final written = sherpa.writeWave(
        filename: request[2] as String,
        samples: audio.samples,
        sampleRate: audio.sampleRate,
      );
      if (!written) throw StateError('Could not write ${request[2]}');
      toParent.send([id, audio.samples.length / audio.sampleRate]);
    } catch (error) {
      toParent.send([id, error.toString()]);
    }
  });
}
