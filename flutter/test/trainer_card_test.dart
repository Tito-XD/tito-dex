import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titodex/features/journey/journey_assistant.dart';
import 'package:titodex/models/journey.dart';
import 'package:titodex/theme/device_layout.dart';
import 'package:titodex/widgets/home_dashboard_body.dart';
import 'package:titodex/widgets/journey_card.dart';
import 'package:titodex/widgets/trainer_card.dart';

Widget _wrapSquare(Widget child, {Size size = const Size(360, 360)}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('square home fits compact trainer and journey cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 720);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final journey = CurrentJourney.mock();

    late double squareHeight;
    late double avatarSize;
    await tester.pumpWidget(
      _wrapSquare(
        Builder(
          builder: (context) {
            // v0.6.7: square dashboards drop the trainer card to the micro
            // height (116×dim) so the journey card below stops overflowing.
            squareHeight = DeviceLayout.trainerSquareCardHeight(context);
            avatarSize = DeviceLayout.trainerMicroAvatarSize(context);
            expect(DeviceLayout.useSquareDashboard(context), isTrue);
            expect(squareHeight, DeviceLayout.trainerMicroCardHeight(context));
            return HomeDashboardBody(
              journey: journey,
              saveLinked: true,
              onJourneyOpen: () {},
              quickActions: SizedBox(
                height: DeviceLayout.squareQuickTileHeight(context),
              ),
            );
          },
        ),
      ),
    );

    final trainerCard = tester.getSize(find.byType(TrainerCard));
    // StickerCard padding on square dashboard is 8px per side.
    expect(trainerCard.height, squareHeight + 16);
    expect(avatarSize / squareHeight, greaterThan(0.6));

    // The compact body plus card padding still leaves room for Journey.
    expect(trainerCard.height, lessThanOrEqualTo(132));
    expect(tester.takeException(), isNull);
  });

  testWidgets('square journey separates progress from assistant status', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 720);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    const journey = CurrentJourney(
      game: 'SoulSilver',
      trainerName: 'Tito',
      location: '满金市 · 宝可梦中心',
      badges: 3,
      maxBadges: 8,
      playTime: '18:42',
      party: [],
      timeline: [],
      companion: 'Cyndaquil',
    );
    const snapshot = JourneyAssistantSnapshot(
      locationLabel: '满金市',
      locationMatched: true,
      nearbyUncaught: [],
      nearbyUncaughtCount: 4,
      exactVersion: 'soulsilver',
      exactVersionLabel: '魂银',
      pairedVersionLabel: '心金',
      versionEncounterGaps: [],
      versionEncounterGapCount: 0,
      evolutionOrTradeMissing: [],
      evolutionOrTradeMissingCount: 0,
      partyEvolutions: [],
    );

    await tester.pumpWidget(
      _wrapSquare(
        Center(
          child: SizedBox(
            width: 300,
            height: 220,
            child: JourneyCard(
              journey: journey,
              onOpenDetail: () {},
              compact: true,
              dense: true,
              assistantFuture: Future.value(snapshot),
            ),
          ),
        ),
        size: const Size(640, 640),
      ),
    );
    await tester.pump();

    expect(find.text('徽章 3/8'), findsOneWidget);
    expect(find.text('游戏时间 18:42 · 附近 4 种待捕'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('portrait home journey card has no bottom overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(360, 780)),
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 140,
              child: JourneyCard(
                journey: CurrentJourney.mock(),
                onOpenDetail: () {},
                compact: true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
