import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titodex/theme/device_layout.dart';
import 'package:titodex/theme/tito_typography.dart';

void main() {
  testWidgets('square handheld uses smaller typography scale', (tester) async {
    late double? titleSize;
    late double headingSize;
    late double bodySize;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(720, 720)),
          child: Builder(
            builder: (context) {
              titleSize = DeviceLayout.appTitleSize(context);
              headingSize = DeviceLayout.cardHeadingSize(context);
              bodySize = DeviceLayout.bodyTextSize(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(titleSize, 14);
    expect(headingSize, 13);
    expect(bodySize, 11);
  });

  testWidgets('detects RG Rotate square handheld', (tester) async {
    late bool square;
    late bool compact;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(720, 720)),
          child: Builder(
            builder: (context) {
              square = DeviceLayout.useSquareDashboard(context);
              compact = DeviceLayout.isCompact(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(square, isTrue);
    expect(compact, isTrue);
  });

  testWidgets('detects short landscape RG screen', (tester) async {
    late bool square;
    late bool compact;
    late bool short;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(640, 480)),
          child: Builder(
            builder: (context) {
              square = DeviceLayout.useSquareDashboard(context);
              compact = DeviceLayout.isCompact(context);
              short = DeviceLayout.isShortScreen(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(square, isTrue);
    expect(compact, isTrue);
    expect(short, isTrue);
  });

  testWidgets('detects 3:4 portrait handheld', (tester) async {
    late bool square;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(480, 640)),
          child: Builder(
            builder: (context) {
              square = DeviceLayout.useSquareDashboard(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(square, isTrue);
  });

  testWidgets('phone portrait is not square dashboard', (tester) async {
    late bool square;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Builder(
            builder: (context) {
              square = DeviceLayout.useSquareDashboard(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(square, isFalse);
  });

  testWidgets('header action and explicit Home typography keep current sizes', (
    tester,
  ) async {
    late double headerSize;
    late double secondaryCardTitleSize;
    late double homeCardTitleSize;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(720, 720)),
          child: Builder(
            builder: (context) {
              headerSize = DeviceLayout.headerIconSize(context);
              secondaryCardTitleSize = context.tito.cardTitle.fontSize!;
              homeCardTitleSize = context.titoHome.cardTitle.fontSize!;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(headerSize, 33);
    expect(secondaryCardTitleSize, 13);
    expect(homeCardTitleSize, 19.5);
  });

  test('isHandheldPanelSize accepts 1:1 and 3:4 either orientation', () {
    expect(DeviceLayout.isHandheldPanelSize(const Size(720, 720)), isTrue);
    expect(DeviceLayout.isHandheldPanelSize(const Size(640, 480)), isTrue);
    expect(DeviceLayout.isHandheldPanelSize(const Size(480, 640)), isTrue);
    expect(DeviceLayout.isHandheldPanelSize(const Size(390, 844)), isFalse);
  });
}
