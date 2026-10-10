import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/theme/app_visual_style.dart';
import 'package:titodex/theme/tito_colors.dart';
import 'package:titodex/theme/tito_theme.dart';
import 'package:titodex/widgets/battle_tool_panels.dart';
import 'package:titodex/widgets/handheld_focus_geometry.dart';
import 'package:titodex/widgets/handheld_input.dart';
import 'package:titodex/widgets/tito_segmented_control.dart';

Future<Uint8List> pixels(WidgetTester tester, GlobalKey key) async {
  return (await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final result = (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!.buffer.asUint8List();
    image.dispose();
    return result;
  }))!;
}

void main() {
  for (final style in AppVisualStyle.values) {
    for (final detail in [false, true]) {
      testWidgets(
        '${style.name} ${detail ? 'Dex' : 'battle'} ink stays inside each painted button',
        (tester) async {
          final boundaryKey = GlobalKey();
          var activations = 0;
          const labels = {0: 'Basic', 1: 'Stats', 2: 'Moves', 3: 'Other'};
          await tester.pumpWidget(
            MaterialApp(
              theme: buildTitoTheme(style).copyWith(
                splashFactory: InkSplash.splashFactory,
                splashColor: Colors.red.withValues(alpha: .8),
                highlightColor: Colors.red.withValues(alpha: .5),
              ),
              home: Scaffold(
                body: Center(
                  child: RepaintBoundary(
                    key: boundaryKey,
                    child: ColoredBox(
                      color: Colors.white,
                      child: SizedBox(
                        width: 360,
                        height: 80,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: detail
                              ? TitoSegmentedControl<int>(
                                  value: 0,
                                  options: labels,
                                  onChanged: (_) => activations++,
                                  floating: true,
                                  railColor: TitoColors.card,
                                  railForeground: TitoColors.ink,
                                  selectedColor: Colors.blue,
                                  selectedForeground: Colors.white,
                                  indicatorKey: const ValueKey('indicator'),
                                )
                              : BattleSegmentedControl<int>(
                                  value: 0,
                                  options: labels,
                                  onChanged: (_) => activations++,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final origin = tester.getTopLeft(find.byKey(boundaryKey));
          final indicator = tester.getRect(
            find.byKey(
              ValueKey(detail ? 'indicator' : 'battle-segment-indicator'),
            ),
          );
          for (final index in [0, 3]) {
            final ink = find.ancestor(
              of: find.text(labels[index]!),
              matching: find.byType(InkWell),
            );
            final button = tester.getRect(ink);
            expect(button.height, 30);
            if (index == 0) expect(button, indicator);
            final focus = Focus.of(
              tester.element(
                find.descendant(
                  of: find.ancestor(
                    of: ink,
                    matching: find.byType(HandheldFocusDecorator),
                  ),
                  matching: find.byType(HandheldPressed),
                ),
              ),
            );
            expect(HandheldFocusGeometry.of(focus)!.bounds, button);
            final before = await pixels(tester, boundaryKey);
            final gesture = await tester.startGesture(button.center);
            await tester.pump(const Duration(milliseconds: 100));
            await tester.pump(const Duration(milliseconds: 250));
            final pressed = await pixels(tester, boundaryKey);
            final allowed = RRect.fromRectAndRadius(
              button.shift(-origin).inflate(1),
              const Radius.circular(TitoRadii.sm),
            );
            var changed = 0;
            for (var y = 0; y < 80; y++) {
              for (var x = 0; x < 360; x++) {
                final offset = (y * 360 + x) * 4;
                if (List.generate(
                  4,
                  (i) => before[offset + i] != pressed[offset + i],
                ).any((v) => v)) {
                  changed++;
                  expect(
                    allowed.contains(Offset(x + .5, y + .5)),
                    isTrue,
                    reason: 'Ink leaked outside button $index at ($x,$y)',
                  );
                }
              }
            }
            expect(
              changed,
              greaterThan(100),
              reason: 'Held press must show visible ink',
            );
            await gesture.up();
            await tester.pumpAndSettle();
            expect(
              activations,
              index == 0 ? 1 : 2,
              reason: 'One callback per tap',
            );
          }
          // The invisible vertical padding remains tappable, without widening ink.
          final first = tester.getRect(
            find.ancestor(
              of: find.text('Basic'),
              matching: find.byType(InkWell),
            ),
          );
          await tester.tapAt(Offset(first.center.dx, first.top - 4));
          await tester.pumpAndSettle();
          expect(activations, 3);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
