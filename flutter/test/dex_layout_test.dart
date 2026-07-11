import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/theme/device_layout.dart';
import 'package:titodex/theme/tito_colors.dart';
import 'package:titodex/widgets/handheld_input.dart';
import 'package:titodex/widgets/pokemon_card.dart';
import 'package:titodex/widgets/pokemon_detail_sections.dart';
import 'package:titodex/widgets/tito_progress_bar.dart';
import 'package:titodex/widgets/type_badge.dart';

PokemonSummary _summary(int id, String nameZh, List<String> types) =>
    PokemonSummary(
      id: id,
      nameEn: 'pokemon-$id',
      nameZh: nameZh,
      types: types,
    );

Widget _wrap(Widget child, {Size size = const Size(360, 360)}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('TitoTypeBadge shows symbol icon + Chinese label',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const Center(child: TitoTypeBadge(typeEn: 'grass'))),
    );

    expect(find.text('草'), findsOneWidget);
    expect(find.byIcon(Icons.grass), findsOneWidget);
  });

  testWidgets(
      'dex grid of mini cards fits RG square (360x360 logical) without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(720, 720);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final entries = [
      _summary(1, '妙蛙种子', ['grass', 'poison']),
      _summary(4, '小火龙', ['fire']),
      _summary(6, '喷火龙', ['fire', 'flying']),
      _summary(151, '梦幻', ['psychic']),
      _summary(230, '刺龙王', ['water', 'dragon']),
      _summary(493, '阿尔宙斯', ['normal']),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final columns = DeviceLayout.dexGridColumns(context);
              final ratio = DeviceLayout.dexCardAspectRatio(context);
              expect(columns, 3);
              return GridView.count(
                crossAxisCount: columns,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: ratio,
                children: [
                  for (final entry in entries)
                    PokemonMiniCard(
                      summary: entry,
                      status: entry.id == 1
                          ? DexEncounterStatus.caught
                          : DexEncounterStatus.unknown,
                      compact: true,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('妙蛙种子'), findsOneWidget);
    expect(find.text('#493'), findsOneWidget);
    // Type badges render icon + Chinese text combos inside the cards.
    expect(find.text('草'), findsWidgets);
    expect(find.byIcon(Icons.local_fire_department), findsWidgets);
  });

  testWidgets('TitoProgressBar fill width matches value fraction',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const Padding(
          padding: EdgeInsets.all(30),
          child: TitoProgressBar(value: 0.5, height: 10),
        ),
      ),
    );

    final containers = find.descendant(
      of: find.byType(TitoProgressBar),
      matching: find.byType(Container),
    );
    expect(containers, findsNWidgets(2));
    final trackWidth = tester.getSize(containers.first).width;
    final fillWidth = tester.getSize(containers.last).width;
    expect(fillWidth, moreOrLessEquals(trackWidth * 0.5, epsilon: 1));
  });

  testWidgets('mini card shows yellow focus ring on D-pad focus',
      (tester) async {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 140,
            child: PokemonMiniCard(
              summary: _summary(1, '妙蛙种子', ['grass', 'poison']),
              status: DexEncounterStatus.unknown,
              compact: true,
            ),
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(PokemonMiniCard),
        matching: find.byType(FocusableActionDetector),
      ),
      findsOneWidget,
    );

    // D-pad/keyboard traversal moves focus onto the card.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    final ringFinder = find.descendant(
      of: find.byType(HandheldFocusDecorator),
      matching: find.byWidgetPredicate((widget) {
        if (widget is! DecoratedBox) {
          return false;
        }
        final decoration = widget.decoration;
        return decoration is BoxDecoration &&
            decoration.border != null &&
            decoration.border!.top.color == TitoColors.softYellow;
      }),
    );
    expect(ringFinder, findsWidgets);
  });

  testWidgets('BaseStatsCard renders six visible stat bars', (tester) async {
    const stats = PokemonBaseStats(
      hp: 45,
      attack: 49,
      defense: 49,
      specialAttack: 65,
      specialDefense: 65,
      speed: 45,
    );

    await tester.pumpWidget(
      _wrap(SingleChildScrollView(child: const BaseStatsCard(stats: stats))),
    );

    expect(find.byType(TitoProgressBar), findsNWidgets(6));
    expect(find.text('318'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
