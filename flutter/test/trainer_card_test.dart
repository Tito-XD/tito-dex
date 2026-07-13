import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titodex/models/journey.dart';
import 'package:titodex/theme/device_layout.dart';
import 'package:titodex/widgets/home_dashboard_body.dart';
import 'package:titodex/widgets/trainer_card.dart';

Widget _wrapSquare(Widget child) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(360, 360)),
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('square home uses dense trainer card height matching portrait',
      (tester) async {
    tester.view.physicalSize = const Size(720, 720);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final journey = CurrentJourney.mock();

    double denseCardHeight(BuildContext context) {
      return DeviceLayout.trainerDenseCardHeight(context);
    }

    late double squareDenseHeight;
    await tester.pumpWidget(
      _wrapSquare(
        Builder(
          builder: (context) {
            squareDenseHeight = denseCardHeight(context);
            expect(DeviceLayout.useSquareDashboard(context), isTrue);
            expect(
              DeviceLayout.trainerSquareCardHeight(context),
              squareDenseHeight,
            );
            return HomeDashboardBody(
              journey: journey,
              saveLinked: false,
              onJourneyOpen: () {},
              quickActions: const SizedBox(height: 48),
            );
          },
        ),
      ),
    );

    final trainerCard = tester.getSize(find.byType(TrainerCard));
    // StickerCard padding on square dashboard is 8px per side.
    expect(trainerCard.height, squareDenseHeight + 16);

    // Old micro layout was ~65px interior — dense should be substantially taller.
    expect(trainerCard.height, greaterThan(130));
  });
}
