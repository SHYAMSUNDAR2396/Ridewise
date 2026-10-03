import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridewise/domain/models.dart';
import 'package:ridewise/ui/topic_screen.dart';
import 'package:ridewise/ui/trip_check_screen.dart';
import 'ui_support.dart';

void main() {
  TestEnv envWithTrip() {
    final env = TestEnv();
    env.trips
      ..setEndpoints('Rajiv Chowk', 'Hauz Khas')
      ..setTransportMode(TransportMode.metro);
    return env;
  }

  testWidgets('shows the estimate with the route', (tester) async {
    usePhone(tester);
    final env = envWithTrip();
    await tester.pumpWidget(env.app(const TripCheckScreen()));
    await tester.pumpAndSettle();

    expect(find.text('18'), findsOneWidget);
    expect(find.text('ESTIMATED DURATION'), findsOneWidget);
    expect(find.text('Rajiv Chowk'), findsOneWidget);
    expect(find.text('Hauz Khas'), findsOneWidget);
    expect(env.trips.draft.estimatedSeconds, 1080);
  });

  testWidgets('falls back to a manual time when routing fails', (tester) async {
    usePhone(tester);
    final env = envWithTrip();
    env.api.handler = (_) => Future.error(Exception('down'));
    await tester.pumpWidget(env.app(const TripCheckScreen()));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't estimate this route."), findsOneWidget);
    await tester.enterText(find.byKey(const Key('manual-minutes')), '15');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(env.trips.draft.manualSeconds, 900);
    expect(find.byType(TopicScreen), findsOneWidget);
  });

  testWidgets('does not continue from a failed estimate without a valid time', (
    tester,
  ) async {
    usePhone(tester);
    final env = envWithTrip();
    env.api.handler = (_) => Future.error(Exception('down'));
    await tester.pumpWidget(env.app(const TripCheckScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(TopicScreen), findsNothing);
  });

  testWidgets('commits an edited duration when continuing', (tester) async {
    usePhone(tester);
    final env = envWithTrip();
    await tester.pumpWidget(env.app(const TripCheckScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit duration'));
    await tester.pump();
    await tester.tap(find.byTooltip('Increase minutes'));
    await tester.pump();
    expect(find.text('About 19 minutes'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(env.trips.draft.manualSeconds, 19 * 60);
    expect(find.byType(TopicScreen), findsOneWidget);
  });
}
