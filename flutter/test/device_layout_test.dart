import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titodex/theme/device_layout.dart';

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

    expect(square, isFalse);
    expect(compact, isTrue);
    expect(short, isTrue);
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
}
