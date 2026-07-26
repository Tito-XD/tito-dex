import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/widgets/pokemon_card.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('structured trade-with-item shows the held item and lock icon',
      (tester) async {
    // 飞天螳螂 → 巨钳螳螂: triggerZh flattens to 交换, structured knows the item.
    const chain = EvolutionNode(
      id: 123,
      nameEn: 'Scyther',
      nameZh: '飞天螳螂',
      children: [
        EvolutionNode(
          id: 212,
          nameEn: 'Scizor',
          nameZh: '巨钳螳螂',
          triggerZh: '交换',
          triggers: [
            EvolutionTrigger(trigger: 'trade', heldItem: 'metal-coat'),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      _wrap(const EvolutionChainVerticalView(root: chain, highlightId: 123)),
    );

    expect(find.text('通讯交换 · 金属膜'), findsOneWidget);
    expect(find.byIcon(Icons.swap_horiz_rounded), findsOneWidget);
  });

  testWidgets('non-trade alternative suppresses the trade lock', (tester) async {
    // 美纳斯-style: beauty level-up OR trade+prism scale — not trade-locked.
    const chain = EvolutionNode(
      id: 349,
      nameEn: 'Feebas',
      nameZh: '丑丑鱼',
      children: [
        EvolutionNode(
          id: 350,
          nameEn: 'Milotic',
          nameZh: '美纳斯',
          triggerZh: '交换',
          triggers: [
            EvolutionTrigger(trigger: 'level-up', minBeauty: 171),
            EvolutionTrigger(trigger: 'trade', heldItem: 'prism-scale'),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      _wrap(const EvolutionChainVerticalView(root: chain, highlightId: 349)),
    );

    expect(find.text('美丽度 / 通讯交换 · 美丽鳞片'), findsOneWidget);
    expect(find.byIcon(Icons.swap_horiz_rounded), findsNothing);
  });

  testWidgets('falls back to triggerZh on pre-trigger bundles', (tester) async {
    const chain = EvolutionNode(
      id: 13,
      nameEn: 'Weedle',
      nameZh: '独角虫',
      children: [
        EvolutionNode(
          id: 14,
          nameEn: 'Kakuna',
          nameZh: '铁壳蛹',
          triggerZh: 'Lv.7',
        ),
      ],
    );

    await tester.pumpWidget(
      _wrap(const EvolutionChainVerticalView(root: chain, highlightId: 13)),
    );

    expect(find.text('Lv.7'), findsOneWidget);
    expect(find.byIcon(Icons.swap_horiz_rounded), findsNothing);
  });
}
