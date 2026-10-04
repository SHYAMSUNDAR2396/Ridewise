import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridewise/data/capsule_store.dart';
import 'package:ridewise/data/generation_controller.dart';
import 'package:ridewise/domain/models.dart';
import 'package:ridewise/generation/types.dart';
import 'package:ridewise/ui/player_screen.dart';
import 'package:ridewise/ui/widgets/generating_tag.dart';
import 'ui_support.dart';

CreateCapsuleRequest _request() => const CreateCapsuleRequest(
  trip: TripDraft(manualSeconds: 600),
  topic: 'Careers',
  style: ListeningStyle.quickOverview,
  language: CapsuleLanguage.enIN,
);

void main() {
  group('GenerationController', () {
    late StreamController<CapsuleUpdate> feed;
    late CapsuleStore store;
    late GenerationController controller;

    setUp(() {
      feed = StreamController<CapsuleUpdate>();
      store = CapsuleStore(storage: MemoryStorage(), deleteAudio: (_) async {});
      controller = GenerationController(
        generate: (_) => feed.stream,
        store: store,
      );
    });
    tearDown(() => feed.close());

    test(
      'completes with the first capsule while the stream stays open',
      () async {
        final first = controller.start(_request());
        expect(controller.isGenerating, isTrue);

        feed.add(
          const CapsuleUpdate(
            progress: GenerationProgress(GenerationPhase.script, 0, 1),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(controller.progress?.phase, GenerationPhase.script);
        expect(store.capsules, isEmpty);

        feed.add(
          CapsuleUpdate(capsule: makeCapsule(parts: [30], complete: false)),
        );
        final capsule = await first;
        expect(capsule.segments, hasLength(1));
        expect(controller.isGenerating, isTrue);
        expect(controller.activeCapsuleId, 'cap-1');
        expect(store.byId('cap-1')!.capsule.segments, hasLength(1));
      },
    );

    test(
      'writes every growing update into the store, keeping progress and saved',
      () async {
        final first = controller.start(_request());
        feed.add(
          CapsuleUpdate(capsule: makeCapsule(parts: [30], complete: false)),
        );
        await first;
        store
          ..setProgress('cap-1', 12)
          ..toggleSaved('cap-1');

        feed.add(
          CapsuleUpdate(capsule: makeCapsule(parts: [30, 28], complete: false)),
        );
        await Future<void>.delayed(Duration.zero);

        final stored = store.byId('cap-1')!;
        expect(stored.capsule.segments, hasLength(2));
        expect(stored.capsule.audioSeconds, 58);
        expect(stored.progressSeconds, 12);
        expect(stored.saved, isTrue);
      },
    );

    test('the complete update ends generation and keeps its notice', () async {
      final first = controller.start(_request());
      feed.add(
        CapsuleUpdate(capsule: makeCapsule(parts: [30], complete: false)),
      );
      await first;

      feed.add(
        CapsuleUpdate(
          capsule: makeCapsule(parts: [30], complete: true),
          complete: true,
          notice: 'Ended early.',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.isGenerating, isFalse);
      expect(controller.progress, isNull);
      expect(controller.notice, 'Ended early.');
      expect(controller.activeCapsuleId, 'cap-1');
      expect(store.byId('cap-1')!.capsule.complete, isTrue);

      controller.dismissNotice();
      expect(controller.notice, isNull);
    });

    test(
      'a failure after the first part ends the capsule with a notice instead of crashing',
      () async {
        final first = controller.start(_request());
        feed.add(
          CapsuleUpdate(capsule: makeCapsule(parts: [30], complete: false)),
        );
        await first;

        feed.addError(
          GenerationException(CapsuleErrorCode.speechSynthesisFailed, 'boom'),
        );
        await Future<void>.delayed(Duration.zero);

        expect(controller.isGenerating, isFalse);
        expect(controller.notice, contains("couldn't finish"));
        expect(store.byId('cap-1')!.capsule.complete, isTrue);
        expect(store.byId('cap-1')!.capsule.segments, hasLength(1));
      },
    );

    test('an error before any part fails start and stops generating', () async {
      final first = controller.start(_request());
      feed.addError(
        GenerationException(
          CapsuleErrorCode.scriptGenerationFailed,
          'no script',
        ),
      );
      await expectLater(first, throwsA(isA<GenerationException>()));
      expect(controller.isGenerating, isFalse);
      expect(store.capsules, isEmpty);

      // Ready for a retry.
      feed = StreamController<CapsuleUpdate>();
      controller.start(_request()).ignore();
      expect(controller.isGenerating, isTrue);
    });

    test('a stream that ends with nothing made fails start', () async {
      final first = controller.start(_request());
      await feed.close();
      await expectLater(first, throwsA(isA<GenerationException>()));
      expect(controller.isGenerating, isFalse);
    });

    test('only one capsule is generated at a time', () async {
      controller.start(_request()).ignore();
      expect(() => controller.start(_request()), throwsStateError);
    });

    test(
      'cancel stops generating, keeps the parts made and frees a waiting start',
      () async {
        final firstA = controller.start(_request());
        final result = expectLater(firstA, throwsA(isA<GenerationException>()));
        await controller.cancel();
        await result;
        expect(controller.isGenerating, isFalse);

        feed = StreamController<CapsuleUpdate>();
        final firstB = controller.start(_request());
        feed.add(
          CapsuleUpdate(capsule: makeCapsule(parts: [30], complete: false)),
        );
        await firstB;
        await controller.cancel();
        expect(controller.isGenerating, isFalse);
        expect(store.byId('cap-1')!.capsule.complete, isTrue);
        expect(store.byId('cap-1')!.capsule.segments, hasLength(1));
      },
    );
  });

  group('CapsuleStore growth', () {
    test('upsert replaces a growing capsule but keeps progress and saved', () {
      final store = CapsuleStore(
        storage: MemoryStorage(),
        deleteAudio: (_) async {},
      );
      store.upsert(makeCapsule(parts: [30], complete: false));
      store
        ..setProgress('cap-1', 20)
        ..toggleSaved('cap-1');
      store.upsert(
        makeCapsule(parts: [30, 28], title: 'New title', complete: false),
      );

      final s = store.byId('cap-1')!;
      expect(store.capsules, hasLength(1));
      expect(s.capsule.title, 'New title');
      expect(s.capsule.segments, hasLength(2));
      expect(s.progressSeconds, 20);
      expect(s.saved, isTrue);
    });

    test('load treats a half-made capsule as complete', () async {
      final storage = MemoryStorage()
        ..data = jsonEncode({
          'capsules': [
            {
              ...makeCapsule(parts: [30], complete: false).toJson(),
              'progressSeconds': 5.0,
              'saved': true,
            },
            makeCapsule(id: 'cap-2', complete: true).toJson(),
          ],
        });
      final store = CapsuleStore(storage: storage, deleteAudio: (_) async {});
      await store.load();

      expect(store.byId('cap-1')!.capsule.complete, isTrue);
      expect(store.byId('cap-1')!.progressSeconds, 5);
      expect(store.byId('cap-2')!.capsule.complete, isTrue);
    });

    test('an old library file without the complete flag still loads', () async {
      final json = makeCapsule().toJson()..remove('complete');
      final storage = MemoryStorage()
        ..data = jsonEncode({
          'capsules': [json],
        });
      final store = CapsuleStore(storage: storage, deleteAudio: (_) async {});
      await store.load();
      expect(store.byId('cap-1')!.capsule.complete, isTrue);
    });

    test(
      'writes survive many quick updates and end with the latest data',
      () async {
        final storage = MemoryStorage();
        final store = CapsuleStore(storage: storage, deleteAudio: (_) async {});
        for (var i = 1; i <= 6; i++) {
          store.upsert(
            makeCapsule(parts: List.filled(i, 10.0), complete: i == 6),
          );
        }
        await store.flushed;
        final saved = (jsonDecode(storage.data!) as Map)['capsules'] as List;
        expect(saved, hasLength(1));
        expect((saved.single as Map)['segments'], hasLength(6));
      },
    );
  });

  group('PlaybackGrower', () {
    test(
      'appends new parts to the loaded capsule, not to other capsules',
      () async {
        final env = TestEnv();
        await env.playback.load(makeCapsule(parts: [30], complete: false));
        env.store.upsert(makeCapsule(parts: [30], complete: false));

        env.store.upsert(makeCapsule(parts: [30, 28], complete: false));
        expect(env.playback.appends.single.segments, hasLength(2));

        env.store.upsert(
          makeCapsule(id: 'other', parts: [10, 10, 10], complete: false),
        );
        expect(env.playback.appends, hasLength(1));
      },
    );

    test(
      'tells the player when the capsule is complete without new parts',
      () async {
        final env = TestEnv();
        await env.playback.load(makeCapsule(parts: [30], complete: false));
        env.store.upsert(makeCapsule(parts: [30], complete: true));
        expect(env.playback.appends.single.complete, isTrue);
      },
    );
  });

  group('Player while the capsule grows', () {
    late StreamController<CapsuleUpdate> feed;

    /// A stream event is delivered while a pump runs, so the frame showing it needs a second pump.
    Future<void> next(WidgetTester t) async {
      await t.pump();
      await t.pump();
    }

    Future<TestEnv> pumpGrowing(WidgetTester tester) async {
      usePhone(tester);
      // Created inside the test body so its events run in the test's fake-async zone.
      feed = StreamController<CapsuleUpdate>();
      addTearDown(feed.close);
      final env = TestEnv(generate: (_) => feed.stream);
      final first = env.generation.start(_request());
      feed.add(
        CapsuleUpdate(capsule: makeCapsule(parts: [60, 58], complete: false)),
      );
      final capsule = await first;
      await tester.pumpWidget(env.app(PlayerScreen(capsule: capsule)));
      await next(tester);
      return env;
    }

    testWidgets('shows a status line and a trailing + on the remaining time', (
      tester,
    ) async {
      await pumpGrowing(tester);
      expect(find.text('Writing the next part...'), findsOneWidget);
      expect(find.text('-1:58+'), findsOneWidget);
    });

    testWidgets('names the part being recorded', (tester) async {
      await pumpGrowing(tester);
      feed.add(
        const CapsuleUpdate(
          progress: GenerationProgress(GenerationPhase.voice, 2, 5),
        ),
      );
      await next(tester);
      expect(find.text('Recording part 3 of 5...'), findsOneWidget);
    });

    testWidgets(
      'says it is waiting when playback ran out of audio, and resumes when a part arrives',
      (tester) async {
        final env = await pumpGrowing(tester);
        env.playback.runOutOfAudio();
        await next(tester);
        expect(find.text('Waiting for the next part...'), findsOneWidget);

        feed.add(
          CapsuleUpdate(
            capsule: makeCapsule(parts: [60, 58, 55], complete: false),
          ),
        );
        await next(tester);

        expect(env.playback.appends.last.segments, hasLength(3));
        expect(env.playback.waitingForMore, isFalse);
        expect(env.playback.playing, isTrue);
        expect(find.text('Waiting for the next part...'), findsNothing);
        expect(find.text('-0:55+'), findsOneWidget);
      },
    );

    testWidgets('the transcript sheet shows the growing transcript', (
      tester,
    ) async {
      await pumpGrowing(tester);
      await tester.tap(find.text('Transcript'));
      await tester.pumpAndSettle();
      expect(
        find.text('The transcript of Index Funds, Explained.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'the status line and + disappear once the capsule is complete',
      (tester) async {
        await pumpGrowing(tester);
        feed.add(
          CapsuleUpdate(
            capsule: makeCapsule(parts: [60, 58, 55], complete: true),
            complete: true,
          ),
        );
        await next(tester);
        expect(find.text('Writing the next part...'), findsNothing);
        expect(find.textContaining('+'), findsNothing);
        expect(find.text('-2:53'), findsOneWidget);
      },
    );

    testWidgets('shows a dismissible notice when generation ended early', (
      tester,
    ) async {
      await pumpGrowing(tester);
      feed.addError(
        GenerationException(CapsuleErrorCode.speechSynthesisFailed, 'boom'),
      );
      await next(tester);
      expect(find.textContaining("couldn't finish"), findsOneWidget);

      await tester.tap(find.byTooltip('Dismiss'));
      await next(tester);
      expect(find.textContaining("couldn't finish"), findsNothing);
    });

    testWidgets('does not crash when the capsule is removed while playing', (
      tester,
    ) async {
      final env = await pumpGrowing(tester);
      await env.store.remove('cap-1');
      await next(tester);
      expect(find.byType(PlayerScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the Generating tag marks only the capsule being made', (
      tester,
    ) async {
      final env = await pumpGrowing(tester);
      await tester.pumpWidget(
        env.app(
          const Scaffold(
            body: Column(
              children: [
                GeneratingTag(capsuleId: 'cap-1'),
                GeneratingTag(capsuleId: 'other'),
              ],
            ),
          ),
        ),
      );
      await next(tester);
      expect(find.text('Generating'), findsOneWidget);

      feed.add(
        CapsuleUpdate(
          capsule: makeCapsule(parts: [60, 58], complete: true),
          complete: true,
        ),
      );
      await next(tester);
      expect(find.text('Generating'), findsNothing);
    });
  });
}
