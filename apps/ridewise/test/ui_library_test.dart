import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridewise/ui/library_screen.dart';
import 'package:ridewise/ui/player_screen.dart';
import 'ui_support.dart';

void main() {
  Future<TestEnv> pumpLibrary(WidgetTester tester) async {
    usePhone(tester);
    final env = TestEnv();
    env.store
      ..upsert(makeCapsule(id: 'a', title: 'The History of Colaba'))
      ..upsert(makeCapsule(id: 'b', title: 'Why Metro Lines Get Built'))
      ..toggleSaved('a');
    await tester.pumpWidget(env.app(const Scaffold(body: LibraryScreen())));
    return env;
  }

  testWidgets('lists capsules newest first', (tester) async {
    await pumpLibrary(tester);
    expect(find.text('The History of Colaba'), findsOneWidget);
    expect(find.text('Why Metro Lines Get Built'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Why Metro Lines Get Built')).dy,
      lessThan(tester.getTopLeft(find.text('The History of Colaba')).dy),
    );
  });

  testWidgets('the Saved tab shows only saved capsules', (tester) async {
    await pumpLibrary(tester);
    await tester.tap(find.text('Saved'));
    await tester.pump();

    expect(find.text('The History of Colaba'), findsOneWidget);
    expect(find.text('Why Metro Lines Get Built'), findsNothing);
  });

  testWidgets('shows a tab-specific empty state', (tester) async {
    usePhone(tester);
    await tester.pumpWidget(
      TestEnv().app(const Scaffold(body: LibraryScreen())),
    );
    expect(find.text('No capsules yet'), findsOneWidget);

    await tester.tap(find.text('Saved'));
    await tester.pump();
    expect(find.text('No saved capsules'), findsOneWidget);
  });

  testWidgets('shows a progress bar only for a started capsule', (
    tester,
  ) async {
    final env = await pumpLibrary(tester);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    env.store.setProgress('a', 600);
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('deleting removes the row and its audio', (tester) async {
    final env = await pumpLibrary(tester);
    await tester.tap(find.byTooltip('Delete The History of Colaba'));
    await tester.pumpAndSettle();

    expect(find.text('The History of Colaba'), findsNothing);
    expect(env.store.byId('a'), isNull);
    expect(env.deleted, ['a']);
  });

  testWidgets('tapping a row opens the player', (tester) async {
    await pumpLibrary(tester);
    await tester.tap(find.text('The History of Colaba'));
    await tester.pumpAndSettle();
    expect(find.byType(PlayerScreen), findsOneWidget);
  });
}
