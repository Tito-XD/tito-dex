import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/models/journey.dart';
import 'package:titodex/widgets/home_dashboard_body.dart';
import 'package:titodex/widgets/journey_card.dart';

void main() {
  const journey = CurrentJourney(
    game: 'SoulSilver',
    trainerName: 'Tito',
    location: '满金市',
    badges: 3,
    maxBadges: 8,
    playTime: '18:42',
    party: [
      PartyMember(species: 'Alpha', level: 24),
      PartyMember(species: 'Beta', level: 18),
    ],
    timeline: [],
    companion: 'Cyndaquil',
  );

  Future<void> pumpDashboard(
    WidgetTester tester, {
    required Size size,
    required bool saveLinked,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeDashboardBody(
            journey: journey,
            saveLinked: saveLinked,
            onJourneyOpen: () {},
            quickActions: const SizedBox(height: 60),
          ),
        ),
      ),
    );
  }

  testWidgets('tablet landscape composes fixed rows, not stretched columns', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      size: const Size(1280, 800),
      saveLinked: true,
    );

    // Trainer + journey share one intrinsic-height row: the journey card no
    // longer balloons to fill the screen height.
    expect(find.byType(IntrinsicHeight), findsOneWidget);
    final journeyHeight = tester.getSize(find.byType(JourneyCard)).height;
    expect(journeyHeight, lessThan(220));

    // Party renders as the capped 6-across strip.
    final gridHeight = tester.getSize(find.byType(GridView)).height;
    expect(gridHeight, lessThanOrEqualTo(200));
  });

  testWidgets('square handheld keeps the packed two-column layout', (
    tester,
  ) async {
    await pumpDashboard(tester, size: const Size(720, 720), saveLinked: true);

    // No tablet row composition on square screens.
    expect(find.byType(IntrinsicHeight), findsNothing);
    expect(find.byType(JourneyCard), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
  });
}
