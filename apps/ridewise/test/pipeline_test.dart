import 'package:flutter_test/flutter_test.dart';
import 'package:ridewise/domain/models.dart';
import 'package:ridewise/generation/pipeline.dart';
import 'package:ridewise/generation/types.dart';

CreateCapsuleRequest request(int? seconds, {CapsuleLanguage language = CapsuleLanguage.enIN}) =>
    CreateCapsuleRequest(
      trip: TripDraft(
        startLabel: 'A',
        endLabel: 'B',
        transportMode: TransportMode.metro,
        manualSeconds: seconds,
      ),
      topic: 'Careers',
      style: ListeningStyle.quickOverview,
      language: language,
    );

class FakeScript implements ScriptWriter {
  FakeScript(this.transcriptFor);
  final String Function(int call) transcriptFor;
  final targetWords = <int>[];

  @override
  Future<Script> write(ScriptRequest request) async {
    targetWords.add(request.targetWords);
    return Script(title: 'A title', transcript: transcriptFor(targetWords.length));
  }
}

class FakeSpeech implements SpeechEngine {
  FakeSpeech(this.durationFor);
  final double Function(String text) durationFor;
  final spoken = <String>[];
  final languages = <CapsuleLanguage>[];

  @override
  Future<({double durationSeconds})> synthesizeToFile(
    String text,
    String filePath,
    CapsuleLanguage language,
  ) async {
    spoken.add(text);
    languages.add(language);
    return (durationSeconds: durationFor(text));
  }
}

class FailingSpeech implements SpeechEngine {
  int attempts = 0;

  @override
  Future<({double durationSeconds})> synthesizeToFile(String t, String p, CapsuleLanguage l) {
    attempts++;
    throw Exception('engine error');
  }
}

String shortScript() =>
    List.generate(12, (i) => 'Sentence number ${i + 1} is here.').join(' ');

({PipelineDeps deps, List<String> cleaned, List<GenerationProgress> progress}) makeDeps({
  required ScriptWriter script,
  required SpeechEngine speech,
}) {
  final cleaned = <String>[];
  final progress = <GenerationProgress>[];
  return (
    deps: PipelineDeps(
      script: script,
      speech: speech,
      segmentPath: (id, index) => '/docs/$id/$index.wav',
      newId: () => 'cap-1',
      now: () => DateTime.utc(2026, 10, 3),
      cleanup: (id) async => cleaned.add(id),
      onProgress: progress.add,
      retryDelay: const Duration(milliseconds: 1),
    ),
    cleaned: cleaned,
    progress: progress,
  );
}

Matcher failsWith(CapsuleErrorCode code) =>
    throwsA(isA<GenerationException>().having((e) => e.code, 'code', code));

void main() {
  test('builds a capsule of local segments that fits the trip', () async {
    final script = FakeScript((_) => shortScript());
    final speech = FakeSpeech((_) => 10);
    final ctx = makeDeps(script: script, speech: speech);

    final capsule = await createCapsuleOnDevice(request(1200), ctx.deps);

    expect(capsule.targetSeconds, 1080);
    expect(capsule.segments, isNotEmpty);
    expect(capsule.segments.first.url, 'file:///docs/cap-1/0.wav');
    expect(capsule.audioSeconds, capsule.segments.length * 10);
    expect(capsule.audioSeconds, lessThanOrEqualTo(capsule.targetSeconds));
    expect(capsule.language, CapsuleLanguage.enIN);
    expect(capsule.createdAt, DateTime.utc(2026, 10, 3));
    expect(script.targetWords, [2700]);
    expect(speech.languages.toSet(), {CapsuleLanguage.enIN});
    expect(ctx.progress.first.phase, GenerationPhase.script);
    expect(ctx.progress.last.phase, GenerationPhase.voice);
  });

  test('uses a slower pace and passes the language through for Hindi', () async {
    final script = FakeScript((_) => shortScript());
    final speech = FakeSpeech((_) => 10);
    final ctx = makeDeps(script: script, speech: speech);

    final capsule = await createCapsuleOnDevice(request(1200, language: CapsuleLanguage.hiIN), ctx.deps);

    expect(script.targetWords, [2340]); // 1080 s at 130 words per minute
    expect(capsule.language, CapsuleLanguage.hiIN);
    expect(speech.languages.toSet(), {CapsuleLanguage.hiIN});
  });

  test('makes one shorter attempt after an overrun, stopping early and cleaning up', () async {
    // The first segment alone is longer than the 1080 s target, so speaking stops there.
    final script = FakeScript((_) => shortScript());
    final speech = FakeSpeech((_) => 1100);
    final ctx = makeDeps(script: script, speech: speech);

    await expectLater(
      createCapsuleOnDevice(request(1200), ctx.deps),
      failsWith(CapsuleErrorCode.capsuleTooLong),
    );

    expect(script.targetWords, [2700, 2295]);
    expect(ctx.cleaned, ['cap-1', 'cap-1']);
    expect(speech.spoken, hasLength(2)); // one segment per attempt, then stopped
  });

  test('succeeds on the shorter second attempt', () async {
    final script = FakeScript((call) => call == 1 ? 'A long sentence. ' * 60 : 'Short one.');
    final speech = FakeSpeech((text) => text.length > 20 ? 600 : 5);
    final ctx = makeDeps(script: script, speech: speech);

    final capsule = await createCapsuleOnDevice(request(1200), ctx.deps);

    expect(script.targetWords, hasLength(2));
    expect(capsule.audioSeconds, 5);
  });

  test('maps a script failure to scriptGenerationFailed', () async {
    final ctx = makeDeps(
      script: FakeScript((_) => throw Exception('model crashed')),
      speech: FakeSpeech((_) => 1),
    );
    await expectLater(
      createCapsuleOnDevice(request(1200), ctx.deps),
      failsWith(CapsuleErrorCode.scriptGenerationFailed),
    );
  });

  test('retries a failed segment, then gives up with speechSynthesisFailed and cleans up', () async {
    final speech = FailingSpeech();
    final ctx = makeDeps(script: FakeScript((_) => shortScript()), speech: speech);

    await expectLater(
      createCapsuleOnDevice(request(1200), ctx.deps),
      failsWith(CapsuleErrorCode.speechSynthesisFailed),
    );
    expect(speech.attempts, 3);
    expect(ctx.cleaned, ['cap-1']);
  });

  test('requires a trip time', () async {
    final ctx = makeDeps(script: FakeScript((_) => shortScript()), speech: FakeSpeech((_) => 1));
    await expectLater(
      createCapsuleOnDevice(request(null), ctx.deps),
      failsWith(CapsuleErrorCode.routeUnavailable),
    );
    await expectLater(
      createCapsuleOnDevice(request(0), ctx.deps),
      failsWith(CapsuleErrorCode.routeUnavailable),
    );
  });
}
