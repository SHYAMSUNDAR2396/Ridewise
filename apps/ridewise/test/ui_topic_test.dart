import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridewise/domain/models.dart';
import 'package:ridewise/generation/types.dart';
import 'package:ridewise/ui/player_screen.dart';
import 'package:ridewise/ui/topic_screen.dart';
import 'package:ridewise/ui/widgets/primary_button.dart';
import 'ui_support.dart';

void main() {
  Future<void> pumpTopic(WidgetTester tester, TestEnv env) async {
    usePhone(tester);
    env.trips
      ..setEndpoints('Rajiv Chowk', 'Hauz Khas')
      ..setTransportMode(TransportMode.metro)
      ..setEstimatedSeconds(1080);
    await tester.pumpWidget(env.app(const TopicScreen()));
  }

  /// The test font is wide, so lower sections may be below the fold of the lazy list.
  Future<void> reveal(WidgetTester tester, Finder finder) =>
      tester.scrollUntilVisible(
        finder,
        150,
        scrollable: find.byType(Scrollable).first,
      );

  VoidCallback? generateAction(WidgetTester tester) => tester
      .widget<PrimaryButton>(
        find.widgetWithText(PrimaryButton, 'Generate my capsule'),
      )
      .onPressed;

  testWidgets('disables Generate until a topic is chosen', (tester) async {
    await pumpTopic(tester, TestEnv());
    expect(generateAction(tester), isNull);

    await tester.tap(find.text('Careers'));
    await tester.pump();
    expect(generateAction(tester), isNotNull);
  });

  testWidgets('disables Generate when there is no trip time', (tester) async {
    usePhone(tester);
    final env = TestEnv();
    await tester.pumpWidget(env.app(const TopicScreen()));
    await tester.tap(find.text('Careers'));
    await tester.pump();
    expect(generateAction(tester), isNull);
  });

  testWidgets('a typed topic replaces a chosen chip', (tester) async {
    final requests = <CreateCapsuleRequest>[];
    final env = TestEnv(
      generate: (r) {
        requests.add(r);
        return finishedStream();
      },
    );
    await pumpTopic(tester, env);

    await tester.tap(find.text('Careers'));
    await tester.enterText(
      find.byKey(const Key('custom-topic')),
      'Monsoon trains',
    );
    await tester.pump();
    await tester.tap(find.text('Generate my capsule'));
    await tester.pumpAndSettle();

    expect(requests.single.topic, 'Monsoon trains');
  });

  testWidgets('opens the player with the capsule on success', (tester) async {
    final requests = <CreateCapsuleRequest>[];
    final env = TestEnv(
      generate: (r) {
        requests.add(r);
        return finishedStream();
      },
    );
    await pumpTopic(tester, env);

    await tester.tap(find.text('Careers'));
    await tester.pump();
    await tester.tap(find.text('Generate my capsule'));
    await tester.pumpAndSettle();

    expect(find.byType(PlayerScreen), findsOneWidget);
    expect(requests.single.topic, 'Careers');
    expect(requests.single.style, ListeningStyle.quickOverview);
    expect(requests.single.language, CapsuleLanguage.enIN);
    expect(requests.single.trip.tripSeconds, 1080);
  });

  testWidgets('passes the chosen style and language', (tester) async {
    final requests = <CreateCapsuleRequest>[];
    final env = TestEnv(
      generate: (r) {
        requests.add(r);
        return finishedStream();
      },
    );
    await pumpTopic(tester, env);

    await tester.tap(find.text('Careers'));
    await reveal(tester, find.text('Learn deeply'));
    await tester.tap(find.text('Learn deeply'));
    await reveal(tester, find.text('Hindi'));
    await tester.tap(find.text('Hindi'));
    await tester.pump();
    await tester.tap(find.text('Generate my capsule'));
    await tester.pumpAndSettle();

    expect(requests.single.style, ListeningStyle.learnDeeply);
    expect(requests.single.language, CapsuleLanguage.hiIN);
  });

  testWidgets('keeps every selection and offers Retry when generation fails', (
    tester,
  ) async {
    final requests = <CreateCapsuleRequest>[];
    var failNext = true;
    final env = TestEnv(
      generate: (r) {
        requests.add(r);
        if (failNext) {
          failNext = false;
          return Stream.error(
            GenerationException(
              CapsuleErrorCode.speechSynthesisFailed,
              "We couldn't record your capsule's audio. Please try again.",
            ),
          );
        }
        return finishedStream();
      },
    );
    await pumpTopic(tester, env);

    await tester.tap(find.text('Technology'));
    await reveal(tester, find.text('Learn deeply'));
    await tester.tap(find.text('Learn deeply'));
    await reveal(tester, find.text('Hindi'));
    await tester.tap(find.text('Hindi'));
    await tester.pump();
    await tester.tap(find.text('Generate my capsule'));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
    expect(
      find.text("We couldn't record your capsule's audio. Please try again."),
      findsOneWidget,
    );
    expect(generateAction(tester), isNotNull);
    expect(find.byType(PlayerScreen), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(requests, hasLength(2));
    expect(requests[1].topic, 'Technology');
    expect(requests[1].style, ListeningStyle.learnDeeply);
    expect(requests[1].language, CapsuleLanguage.hiIN);
    expect(find.byType(PlayerScreen), findsOneWidget);
  });

  testWidgets('shows what the phone is doing until the first part is ready', (
    tester,
  ) async {
    final feed = StreamController<CapsuleUpdate>();
    addTearDown(feed.close);
    final env = TestEnv(generate: (_) => feed.stream);
    await pumpTopic(tester, env);

    await tester.tap(find.text('Careers'));
    await tester.pump();
    await tester.tap(find.text('Generate my capsule'));
    await tester.pump();
    expect(find.text('Preparing your capsule...'), findsOneWidget);

    feed.add(
      const CapsuleUpdate(
        progress: GenerationProgress(GenerationPhase.models, 42, 100),
      ),
    );
    await tester.pump();
    expect(find.text('Getting ready, 42%'), findsOneWidget);
    expect(
      find.text(
        'Downloading the voice and writer once. They stay on this phone.',
      ),
      findsOneWidget,
    );

    feed.add(
      const CapsuleUpdate(
        progress: GenerationProgress(GenerationPhase.script, 0, 1),
      ),
    );
    await tester.pump();
    expect(find.text('Writing your script...'), findsOneWidget);

    feed.add(
      const CapsuleUpdate(
        progress: GenerationProgress(GenerationPhase.voice, 2, 9),
      ),
    );
    await tester.pump();
    expect(find.text('Recording part 3 of 9...'), findsOneWidget);
    expect(find.byType(PlayerScreen), findsNothing);
  });

  testWidgets(
    'opens the player after the FIRST part while the rest keeps generating',
    (tester) async {
      final feed = StreamController<CapsuleUpdate>();
      addTearDown(feed.close);
      final env = TestEnv(generate: (_) => feed.stream);
      await pumpTopic(tester, env);

      await tester.tap(find.text('Careers'));
      await tester.pump();
      await tester.tap(find.text('Generate my capsule'));
      await tester.pump();

      feed.add(
        CapsuleUpdate(
          capsule: makeCapsule(parts: [30], complete: false),
          progress: const GenerationProgress(GenerationPhase.voice, 0, 4),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(PlayerScreen), findsOneWidget);
      expect(env.generation.isGenerating, isTrue);
      expect(env.store.byId('cap-1')!.capsule.segments, hasLength(1));

      feed.add(
        CapsuleUpdate(capsule: makeCapsule(parts: [30, 28], complete: false)),
      );
      await tester.pump();
      expect(env.store.byId('cap-1')!.capsule.segments, hasLength(2));

      feed.add(
        CapsuleUpdate(
          capsule: makeCapsule(parts: [30, 28], complete: true),
          complete: true,
        ),
      );
      await tester.pump();
      expect(env.generation.isGenerating, isFalse);
    },
  );

  testWidgets('disables Generate while another capsule is being made', (
    tester,
  ) async {
    final feed = StreamController<CapsuleUpdate>();
    addTearDown(feed.close);
    final env = TestEnv(generate: (_) => feed.stream);
    await pumpTopic(tester, env);
    env.generation.start(
      CreateCapsuleRequest(
        trip: env.trips.draft,
        topic: 'Other',
        style: ListeningStyle.quickOverview,
        language: CapsuleLanguage.enIN,
      ),
    );
    await tester.tap(find.text('Careers'));
    await tester.pump();

    expect(generateAction(tester), isNull);
  });
}
