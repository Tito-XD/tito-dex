import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/widgets/liquid_glass.dart';

void main() {
  testWidgets('normal Solid Plastic surfaces use static opaque optics', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 180,
              height: 96,
              child: LiquidGlassSurface(child: Text('static plastic')),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsNothing);
    final fill = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('solid-plastic-static-fill')),
    );
    final decoration = fill.decoration as BoxDecoration;
    final colors = (decoration.gradient! as LinearGradient).colors;
    expect(colors, hasLength(3));
    expect(colors.every((color) => color.a >= 0.85), isTrue);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('solid-plastic-static-fill')),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
  });

  testWidgets('compact glass chrome can opt in to one light backdrop pass', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BackdropGroup(
            child: const Center(
              child: SizedBox(
                width: 180,
                height: 52,
                child: LiquidGlassSurface(
                  blurBackdrop: true,
                  blurSigma: 5,
                  child: Text('light blur'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(
      find.byKey(const ValueKey('solid-plastic-backdrop')),
      findsOneWidget,
    );
  });

  testWidgets('round header control keeps a solid tint with bounded blur', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BackdropGroup(
            child: LiquidGlassRoundButton(
              size: 44,
              semanticLabel: '设置',
              onTap: () {},
              child: const Icon(Icons.settings_rounded),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsOneWidget);
    final fill = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('solid-plastic-static-fill')),
    );
    final colors =
        ((fill.decoration as BoxDecoration).gradient! as LinearGradient).colors;
    expect(colors.every((color) => color.a >= 0.85), isTrue);
    expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
  });

  testWidgets('reduced effects fall back to the static plastic surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: BackdropGroup(
              child: LiquidGlassSurface(
                blurBackdrop: true,
                child: const Text('no sampling'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsNothing);
    expect(
      find.byKey(const ValueKey('solid-plastic-static-fill')),
      findsOneWidget,
    );
  });
}
