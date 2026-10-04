import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ridewise/domain/models.dart';
import 'package:ridewise/generation/pipeline.dart';
import 'package:ridewise/generation/types.dart';

CreateCapsuleRequest request({
  int? seconds = 1200,
  CapsuleLanguage language = CapsuleLanguage.enIN,
}) => CreateCapsuleRequest(
  trip: TripDraft(manualSeconds: seconds),
  topic: 'Careers',
  style: ListeningStyle.quickOverview,
  language: language,
);

/// [n] short words in one sentence: about 500 characters for 100 words, so one segment.
String sentence(int n) => '${List.filled(n, 'word').join(' ')}.';

class SectionCall {
  SectionCall(this.index, this.words, this.previousText);
  final int index;
  final int words;
  final String previousText;
}

class FakeScript implements ScriptWriter {
  FakeScript({
    this.sections = 3,
    this.wordsPerSection = 100,
    this.onSection,
    this.outlineError,
  });

  final int sections;
  final int wordsPerSection;

  /// Overrides the text for a section (e.g. to delay or fail it).
  final Future<String> Function(int index)? onSection;
  final Object? outlineError;
  final calls = <SectionCall>[];
  ScriptRequest? outlineRequest;

  @override
  Future<ScriptOutline> outline(ScriptRequest request) async {
    outlineRequest = request;
    if (outlineError != null) throw outlineError!;
    return ScriptOutline(
      title: 'A title',
      headings: [for (var i = 0; i < sections; i++) 'Part ${i + 1}'],
    );
  }

  @override
  Future<String> writeSection({
    required ScriptRequest request,
    required ScriptOutline outline,
    required int index,
    required int words,
    required String previousText,
  }) {
    calls.add(SectionCall(index, words, previousText));
    return onSection != null
        ? onSection!(index)
        : Future.value(sentence(wordsPerSection));
  }
}

class FakeSpeech implements SpeechEngine {
  FakeSpeech({this.secondsPerWord = 0.4, this.onSpeak});

  final double secondsPerWord;

  /// Runs before each call; may delay or throw. Gets the zero-based call number.
  final Future<void> Function(int call)? onSpeak;
  final spoken = <String>[];
  final languages = <CapsuleLanguage>[];
  var calls = 0;

  @override
  Future<({double durationSeconds})> synthesizeToFile(
    String text,
    String filePath,
    CapsuleLanguage language,
  ) async {
    final call = calls++;
    languages.add(language);
    if (onSpeak != null) await onSpeak!(call);
    spoken.add(text);
    final words = text.split(' ').length;
    return (durationSeconds: words * secondsPerWord);
  }
}

class Harness {
  Harness({FakeScript? script, FakeSpeech? speech})
    : script = script ?? FakeScript(),
      speech = speech ?? FakeSpeech();

  final FakeScript script;
  final FakeSpeech speech;
  final cleaned = <String>[];
  final deleted = <String>[];

  PipelineDeps get deps => PipelineDeps(
    script: script,
    speech: speech,
    segmentPath: (id, index) => '/docs/$id/$index.wav',
    newId: () => 'cap-1',
    now: () => DateTime.utc(2026, 10, 4),
    cleanup: (id) async => cleaned.add(id),
    deleteFile: (path) async => deleted.add(path),
    retryDelay: const Duration(milliseconds: 1),
  );

  Stream<CapsuleUpdate> run([CreateCapsuleRequest? r]) =>
      createCapsuleOnDevice(r ?? request(), deps);
}

Matcher failsWith(CapsuleErrorCode code) =>
    throwsA(isA<GenerationException>().having((e) => e.code, 'code', code));

List<CapsuleUpdate> withCapsule(List<CapsuleUpdate> updates) => [
  for (final u in updates)
    if (u.capsule != null) u,
];

void main() {
  test('builds a capsule part by part that fits the trip', () async {
    final h = Harness();
    final updates = await h.run().toList();
    final growing = withCapsule(updates);

    expect(growing.length, 4); // 3 growing updates + the final complete one
    expect(growing.map((u) => u.capsule!.segments.length), [1, 2, 3, 3]);
    expect(growing.map((u) => u.capsule!.complete), [
      false,
      false,
      false,
      true,
    ]);
    expect(growing.last.complete, isTrue);
    expect(growing.last.notice, isNull);

    final capsule = growing.last.capsule!;
    expect(capsule.targetSeconds, 1080);
    expect(capsule.segments.first.url, 'file:///docs/cap-1/0.wav');
    expect(capsule.audioSeconds, closeTo(120, 1e-9)); // 3 x 100 words x 0.4 s
    expect(capsule.audioSeconds, lessThanOrEqualTo(capsule.targetSeconds));
    expect(capsule.title, 'A title');
    expect(capsule.language, CapsuleLanguage.enIN);
    expect(capsule.createdAt, DateTime.utc(2026, 10, 4));
    expect(capsule.transcript, contains('word word'));
    // Earlier updates are snapshots: they are not changed by later parts.
    expect(growing.first.capsule!.segments.length, 1);
    expect(h.cleaned, isEmpty);
  });

  test(
    'emits the first capsule update while later sections are still pending',
    () async {
      final gate = Completer<String>();
      final h = Harness(
        script: FakeScript(
          onSection: (i) => i == 0 ? Future.value(sentence(100)) : gate.future,
        ),
      );

      final updates = <CapsuleUpdate>[];
      var done = false;
      h.run().listen(updates.add, onDone: () => done = true);
      await pumpEventQueue();

      final first = withCapsule(updates);
      expect(first, hasLength(1));
      expect(first.single.capsule!.segments, hasLength(1));
      expect(first.single.capsule!.complete, isFalse);
      expect(done, isFalse, reason: 'section 2 has not been written yet');

      gate.complete(sentence(100));
      await pumpEventQueue();
      expect(done, isTrue);
      expect(withCapsule(updates).last.complete, isTrue);
    },
  );

  test(
    'starts writing the next section while the current one is being spoken',
    () async {
      final speakGate = Completer<void>();
      final h = Harness(
        speech: FakeSpeech(
          onSpeak: (call) => call == 0 ? speakGate.future : Future.value(),
        ),
      );

      final sub = h.run().listen((_) {});
      await pumpEventQueue();

      expect(
        h.speech.spoken,
        isEmpty,
        reason: 'first segment is still being spoken',
      );
      expect(h.script.calls.map((c) => c.index), [0, 1]);
      expect(h.script.calls[1].previousText, sentence(100));

      speakGate.complete();
      await sub.asFuture<void>();
    },
  );

  test(
    're-measures the pace and gives later sections fewer words when speech is slow',
    () async {
      Future<List<SectionCall>> callsFor(double secondsPerWord) async {
        final h = Harness(
          script: FakeScript(sections: 4),
          speech: FakeSpeech(secondsPerWord: secondsPerWord),
        );
        await h.run().toList();
        return h.script.calls;
      }

      final normal = await callsFor(
        0.4,
      ); // exactly the assumed 150 words per minute
      final slow = await callsFor(0.8);

      // Section 0: 1080 s over 4 sections at 0.4 s/word.
      expect(normal[0].words, 675);
      expect(slow[0].words, 675);
      // Section 2 is requested while section 1 is spoken, after section 0 was measured.
      expect(normal[2].words, 1250);
      expect(slow[2].words, 575);
      expect(slow[2].words, lessThan(normal[2].words));
    },
  );

  test(
    'never publishes audio over the target: an overrunning segment is dropped',
    () async {
      final h = Harness(
        speech: FakeSpeech(secondsPerWord: 1),
      ); // 100 s per segment
      final updates = await h
          .run(request(seconds: 240))
          .toList(); // target 180 s
      final growing = withCapsule(updates);

      expect(growing.last.complete, isTrue);
      expect(growing.last.notice, isNull);
      expect(growing.last.capsule!.segments, hasLength(1));
      expect(growing.last.capsule!.audioSeconds, 100);
      expect(growing.last.capsule!.audioSeconds, lessThanOrEqualTo(180));
      expect(h.deleted, ['/docs/cap-1/1.wav']);
      for (final u in growing) {
        expect(u.capsule!.audioSeconds, lessThanOrEqualTo(180));
      }
    },
  );

  test(
    'fails with capsuleTooLong when even the first segment does not fit',
    () async {
      final h = Harness(speech: FakeSpeech(secondsPerWord: 5)); // 500 s
      await expectLater(
        h.run(request(seconds: 240)).toList(),
        failsWith(CapsuleErrorCode.capsuleTooLong),
      );
      expect(h.cleaned, ['cap-1']);
    },
  );

  group('failure', () {
    test('before the first segment throws and cleans up', () async {
      var attempts = 0;
      final h = Harness(
        speech: FakeSpeech(
          onSpeak: (_) async {
            attempts++;
            throw Exception('engine error');
          },
        ),
      );
      await expectLater(
        h.run().toList(),
        failsWith(CapsuleErrorCode.speechSynthesisFailed),
      );
      expect(attempts, 3);
      expect(h.cleaned, ['cap-1']);
    });

    test('in the outline or the first section is a script failure', () async {
      final noOutline = Harness(
        script: FakeScript(outlineError: Exception('x')),
      );
      await expectLater(
        noOutline.run().toList(),
        failsWith(CapsuleErrorCode.scriptGenerationFailed),
      );

      final noSection = Harness(
        script: FakeScript(onSection: (_) => Future.error(Exception('x'))),
      );
      await expectLater(
        noSection.run().toList(),
        failsWith(CapsuleErrorCode.scriptGenerationFailed),
      );
      expect(noSection.cleaned, ['cap-1']);
    });

    test(
      'after the first segment ends with a complete update and a notice, without throwing',
      () async {
        final h = Harness(
          speech: FakeSpeech(
            onSpeak: (call) async {
              if (call >= 1) throw Exception('engine error');
            },
          ),
        );
        final updates = await h.run().toList(); // does not throw
        final last = updates.last;

        expect(last.complete, isTrue);
        expect(last.notice, 'We could not finish the rest of this capsule.');
        expect(last.capsule!.segments, hasLength(1));
        expect(last.capsule!.complete, isTrue);
        expect(h.cleaned, isEmpty, reason: 'the playable part is kept');
      },
    );

    test(
      'a later section that cannot be written ends the capsule with a notice',
      () async {
        final h = Harness(
          script: FakeScript(
            onSection: (i) => i == 1
                ? Future.error(Exception('model crashed'))
                : Future.value(sentence(100)),
          ),
        );
        final updates = await h.run().toList();

        expect(updates.last.complete, isTrue);
        expect(updates.last.notice, isNotNull);
        expect(updates.last.capsule!.segments, hasLength(1));
      },
    );
  });

  test(
    'Hindi starts at 130 words per minute and passes the language to speech',
    () async {
      final hindi = Harness();
      await hindi.run(request(language: CapsuleLanguage.hiIN)).toList();
      expect(
        hindi.script.outlineRequest!.targetWords,
        2340,
      ); // 1080 s / 60 * 130
      expect(hindi.script.outlineRequest!.language, CapsuleLanguage.hiIN);
      expect(hindi.speech.languages.toSet(), {CapsuleLanguage.hiIN});

      final english = Harness();
      await english.run().toList();
      expect(
        english.script.outlineRequest!.targetWords,
        2700,
      ); // 1080 s / 60 * 150
    },
  );

  test('requires a trip time', () async {
    for (final r in [request(seconds: null), request(seconds: 0)]) {
      await expectLater(
        Harness().run(r).toList(),
        failsWith(CapsuleErrorCode.routeUnavailable),
      );
    }
  });

  test(
    'reports progress: script first, then voice with a total that never shrinks',
    () async {
      final updates = await Harness().run().toList();
      final progress = [
        for (final u in updates)
          if (u.progress != null) u.progress!,
      ];

      expect(progress.first.phase, GenerationPhase.script);
      final voice = progress
          .where((p) => p.phase == GenerationPhase.voice)
          .toList();
      expect(voice.map((p) => p.done), [0, 1, 2]);
      var previousTotal = 0;
      for (final p in voice) {
        expect(p.total, greaterThanOrEqualTo(previousTotal));
        expect(p.total, greaterThan(p.done));
        previousTotal = p.total;
      }
    },
  );

  test(
    'cancelling stops the work and a later section failure is not an uncaught error',
    () async {
      final gate = Completer<String>();
      final h = Harness(
        script: FakeScript(
          onSection: (i) => i == 0 ? Future.value(sentence(100)) : gate.future,
        ),
      );

      final updates = <CapsuleUpdate>[];
      late StreamSubscription<CapsuleUpdate> sub;
      sub = h.run().listen((u) {
        updates.add(u);
        if (u.capsule != null) sub.cancel();
      });
      await pumpEventQueue();
      expect(withCapsule(updates), hasLength(1));

      // The prefetched section fails after the listener is gone; the test fails on an uncaught error.
      gate.completeError(Exception('model crashed'));
      await pumpEventQueue();
      expect(h.cleaned, isEmpty);
    },
  );
}
