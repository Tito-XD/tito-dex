import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/widgets/battle_content_fade.dart';
import 'package:titodex/widgets/battle_tool_panels.dart';
import 'package:titodex/theme/tito_theme.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets(
      'capsule slides and content fades without losing input (reduced=$reduced)',
      (tester) async {
        var selected = 0;
        final controller = TextEditingController(text: '177');
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTitoTheme(),
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: StatefulBuilder(
                builder: (context, setState) => Scaffold(
                  body: Column(
                    children: [
                      BattleSegmentedControl<int>(
                        value: selected,
                        options: const {0: '克制', 1: '伤害'},
                        onChanged: (v) => setState(() => selected = v),
                      ),
                      BattleContentFade(
                        changeKey: selected,
                        child: TextField(controller: controller),
                      ),
                      const SizedBox(
                        key: ValueKey('aligned-card'),
                        width: double.infinity,
                        height: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        final indicator = find.byKey(
          const ValueKey('battle-segment-indicator'),
        );
        final start = tester.getCenter(indicator).dx;
        final rail = tester.getRect(
          find.byKey(const ValueKey('battle-segment-rail')),
        );
        final card = tester.getRect(find.byKey(const ValueKey('aligned-card')));
        expect(rail.left, card.left);
        expect(rail.right, card.right);
        await tester.tap(find.text('伤害'));
        await tester.pump();
        final fade = tester.widget<FadeTransition>(
          find.descendant(
            of: find.byType(BattleContentFade),
            matching: find.byType(FadeTransition),
          ),
        );
        expect(fade.opacity.value, reduced ? 1 : .75);
        await tester.pump(const Duration(milliseconds: 70));
        final middle = tester.getCenter(indicator).dx;
        await tester.pumpAndSettle();
        final end = tester.getCenter(indicator).dx;
        expect(end, greaterThan(start));
        if (!reduced) {
          expect(middle, greaterThan(start));
          expect(middle, lessThan(end));
        }
        expect(fade.opacity.value, 1);
        expect(controller.text, '177');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
