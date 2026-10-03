import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridewise/ui/player_screen.dart';
import 'ui_support.dart';

void main() {
  Future<TestEnv> pumpPlayer(
    WidgetTester tester, {
    double progress = 372,
    bool preloaded = false,
  }) async {
    usePhone(tester);
    final env = TestEnv();
    final capsule = makeCapsule();
    env.store.upsert(capsule);
    env.store.setProgress(capsule.id, progress);
    if (preloaded) await env.playback.load(capsule, startSeconds: progress);
    env.playback.loads.clear();
    await tester.pumpWidget(env.app(PlayerScreen(capsule: capsule)));
    await tester.pump();
    return env;
  }

  testWidgets(
    'loads the capsule from its stored progress and marks it as now playing',
    (tester) async {
      final env = await pumpPlayer(tester);

      expect(env.playback.loads.single.start, 372);
      expect(env.nowPlaying.capsuleId, 'cap-1');
      expect(find.text('Index Funds, Explained'), findsOneWidget);
      expect(find.text('Personal finance, English'), findsOneWidget);
      expect(find.text('6:12'), findsOneWidget);
      expect(find.text('-28:48'), findsOneWidget);
    },
  );

  testWidgets('starts a finished capsule from the beginning', (tester) async {
    final env = await pumpPlayer(tester, progress: 2100);
    expect(env.playback.loads.single.start, 0);
  });

  testWidgets('does not reload a capsule that is already loaded', (
    tester,
  ) async {
    final env = await pumpPlayer(tester, preloaded: true);
    expect(env.playback.loads, isEmpty);
  });

  testWidgets('plays, pauses and skips', (tester) async {
    final env = await pumpPlayer(tester);

    await tester.tap(find.byTooltip('Play'));
    await tester.pump();
    expect(env.playback.plays, 1);

    await tester.tap(find.byTooltip('Forward 30 seconds'));
    await tester.tap(find.byTooltip('Replay 10 seconds'));
    await tester.pump();
    expect(env.playback.seeks, [402, 392]);

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(env.playback.pauses, 1);
  });

  testWidgets('opens the transcript', (tester) async {
    await pumpPlayer(tester);
    await tester.tap(find.text('Transcript'));
    await tester.pumpAndSettle();
    expect(
      find.text('The transcript of Index Funds, Explained.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Collapse transcript'));
    await tester.pumpAndSettle();
    expect(
      find.text('The transcript of Index Funds, Explained.'),
      findsNothing,
    );
  });

  testWidgets('saves and unsaves the capsule', (tester) async {
    final env = await pumpPlayer(tester);
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(env.store.byId('cap-1')!.saved, isTrue);
    expect(find.text('Saved'), findsOneWidget);

    await tester.tap(find.text('Saved'));
    await tester.pump();
    expect(env.store.byId('cap-1')!.saved, isFalse);
  });

  testWidgets('offers Retry when the audio cannot play', (tester) async {
    final env = await pumpPlayer(tester);
    env.playback.error = true;
    await tester.pump();

    expect(find.text('Audio unavailable right now.'), findsOneWidget);
    env.playback.loads.clear();
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(env.playback.loads, hasLength(1));
    expect(find.text('Audio unavailable right now.'), findsNothing);
  });

  testWidgets('collapses', (tester) async {
    usePhone(tester);
    final env = TestEnv();
    final capsule = makeCapsule();
    await tester.pumpWidget(
      env.app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PlayerScreen(capsule: capsule),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(PlayerScreen), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Collapse player'));
    await tester.pumpAndSettle();
    expect(find.byType(PlayerScreen), findsNothing);
  });
}
