import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/companion/companion_repository.dart';
import 'package:titodex/models/journey.dart';
import 'package:titodex/pages/companion_position_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('position canvas fills the phone and commits a smooth drag', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await companionRepository.setOffset(0, 0);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/position',
      routes: [
        GoRoute(
          path: '/position',
          builder: (context, state) => Scaffold(
            body: CompanionPositionPage(journey: CurrentJourney.mock()),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump(const Duration(milliseconds: 300));

    final canvas = find.byKey(const ValueKey('companion-position-canvas'));
    expect(tester.getSize(canvas).height, greaterThan(650));

    await tester.drag(canvas, const Offset(60, 40));
    await tester.pump();

    expect(companionRepository.offsetX, greaterThan(0));
    expect(companionRepository.offsetY, greaterThan(0));
  });
}
