import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titodex/models/journey.dart';
import 'package:titodex/theme/device_layout.dart';
import 'package:titodex/widgets/home_dashboard_body.dart';
import 'package:titodex/widgets/journey_card.dart';
import 'package:titodex/widgets/trainer_card.dart';

Widget _wrapSquare(Widget child) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(360, 360)),
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
    await tester.pumpWidget(
      _wrapSquare(
        Builder(
          builder: (context) {
            // v0.6.7: square dashboards drop the trainer card to the micro
            // height (116×dim) so the journey card below stops overflowing.
            squareHeight = DeviceLayout.trainerSquareCardHeight(context);
            expect(DeviceLayout.useSquareDashboard(context), isTrue);
            expect(
              squareHeight,
              DeviceLayout.trainerMicroCardHeight(context),
            );
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

    // micro 116 + 16 padding at dim 1.0 (360px square test surface).
    expect(trainerCard.height, lessThanOrEqualTo(132));
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
