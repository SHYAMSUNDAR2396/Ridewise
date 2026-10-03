import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridewise/domain/models.dart';
import 'package:ridewise/ui/plan_screen.dart';
import 'package:ridewise/ui/trip_check_screen.dart';
import 'ui_support.dart';

void main() {
  Future<void> pumpPlan(WidgetTester tester, TestEnv env) async {
    usePhone(tester);
    await tester.pumpWidget(env.app(const Scaffold(body: PlanScreen())));
  }

  testWidgets('requires a starting point, then a destination', (tester) async {
    final env = TestEnv();
    await pumpPlan(tester, env);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Enter a starting point'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('plan-Start')), 'Rajiv Chowk');
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Enter a destination'), findsOneWidget);
    expect(find.byType(TripCheckScreen), findsNothing);
  });

  testWidgets('requires a transport mode', (tester) async {
    await pumpPlan(tester, TestEnv());
    await tester.enterText(find.byKey(const Key('plan-Start')), 'Rajiv Chowk');
    await tester.enterText(
      find.byKey(const Key('plan-Destination')),
      'Hauz Khas',
    );
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(find.text('Choose how you are travelling'), findsOneWidget);
  });

  testWidgets('saves the trip and moves on when complete', (tester) async {
    final env = TestEnv();
    await pumpPlan(tester, env);
    await tester.enterText(find.byKey(const Key('plan-Start')), 'Rajiv Chowk');
    await tester.enterText(
      find.byKey(const Key('plan-Destination')),
      'Hauz Khas',
    );
    await tester.tap(find.text('Metro'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(env.trips.draft.startLabel, 'Rajiv Chowk');
    expect(env.trips.draft.endLabel, 'Hauz Khas');
    expect(env.trips.draft.transportMode, TransportMode.metro);
    expect(find.byType(TripCheckScreen), findsOneWidget);
  });
}
