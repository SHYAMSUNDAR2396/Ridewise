import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridewise/data/capsule_store.dart';
import 'package:ridewise/domain/models.dart';
import 'package:ridewise/ui/home_screen.dart';
import 'package:ridewise/ui/player_screen.dart';
import 'package:ridewise/ui/shell.dart';
import 'ui_support.dart';

void main() {
  testWidgets('starts planning from the hero card', (tester) async {
    usePhone(tester);
    final env = TestEnv();
    await tester.pumpWidget(env.app(const Scaffold(body: HomeScreen())));

    await tester.tap(find.text('Plan a capsule'));
    expect(env.shell.index, ShellController.plan);
  });

  testWidgets('shows an empty state until a capsule exists', (tester) async {
    usePhone(tester);
    await tester.pumpWidget(TestEnv().app(const Scaffold(body: HomeScreen())));
    expect(find.text('No capsules yet'), findsOneWidget);
  });

  testWidgets('shows the planned trip on the hero card', (tester) async {
    usePhone(tester);
    final env = TestEnv();
    env.trips
      ..setEndpoints('Andheri', 'Churchgate')
      ..setTransportMode(TransportMode.localTrain);
    await tester.pumpWidget(env.app(const Scaffold(body: HomeScreen())));

    expect(find.text('Andheri to Churchgate'), findsOneWidget);
    expect(find.text('Local train'), findsOneWidget);
  });

  testWidgets('lists a recent capsule and offers to continue a started one', (
    tester,
  ) async {
    usePhone(tester);
    final env = TestEnv();
    env.store.upsert(makeCapsule());
    env.store.setProgress('cap-1', 600);
    await tester.pumpWidget(env.app(const Scaffold(body: HomeScreen())));

    expect(find.text('English, 35 min'), findsOneWidget);
    await tester.tap(find.text('Index Funds, Explained').last);
    await tester.pumpAndSettle();
    expect(find.byType(PlayerScreen), findsOneWidget);
  });

  testWidgets('keeps the stored progress when a capsule is upserted again', (
    tester,
  ) async {
    final env = TestEnv();
    env.store.upsert(makeCapsule());
    env.store.setProgress('cap-1', 90);
    env.store.upsert(makeCapsule());
    expect(env.store.byId('cap-1')!.progressSeconds, 90);
    expect(env.store.capsules, hasLength(1));
    expect(env.store.capsules.first, isA<StoredCapsule>());
  });
}
