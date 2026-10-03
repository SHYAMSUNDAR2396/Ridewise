import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridewise/ui/mini_player.dart';
import 'package:ridewise/ui/player_screen.dart';
import 'ui_support.dart';

void main() {
  Future<TestEnv> pumpMini(WidgetTester tester) async {
    usePhone(tester);
    final env = TestEnv();
    env.store.upsert(makeCapsule());
    env.store.setProgress('cap-1', 372);
    await tester.pumpWidget(
      env.app(const Scaffold(bottomNavigationBar: MiniPlayer())),
    );
    return env;
  }

  testWidgets('is hidden until a capsule is playing', (tester) async {
    await pumpMini(tester);
    expect(find.text('Index Funds, Explained'), findsNothing);
  });

  testWidgets('shows the capsule and the time left, and opens the player', (
    tester,
  ) async {
    final env = await pumpMini(tester);
    env.nowPlaying.set('cap-1');
    await tester.pump();

    expect(find.text('Index Funds, Explained'), findsOneWidget);
    expect(find.text('28:48 left'), findsOneWidget);

    await tester.tap(find.text('Index Funds, Explained'));
    await tester.pumpAndSettle();
    expect(find.byType(PlayerScreen), findsOneWidget);
  });

  testWidgets('toggles playback', (tester) async {
    final env = await pumpMini(tester);
    env.nowPlaying.set('cap-1');
    await tester.pump();

    await tester.tap(find.byTooltip('Play'));
    await tester.pump();
    expect(env.playback.plays, 1);

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(env.playback.pauses, 1);
  });
}
