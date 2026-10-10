import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/dex/type_chart.dart';
import 'package:titodex/l10n/app_locale.dart';
import 'package:titodex/l10n/app_zh.dart';
import 'package:titodex/theme/app_visual_style.dart';
import 'package:titodex/theme/tito_theme.dart';
import 'package:titodex/widgets/companion_tool_fields.dart';
import 'package:titodex/widgets/sticker_card.dart';
import 'package:titodex/widgets/type_badge.dart';

const selectionKey = ValueKey('type-picker-selection');

Finder selectionButton() =>
    find.ancestor(of: find.byKey(selectionKey), matching: find.byType(InkWell));

Finder option(String type) => find.byKey(ValueKey('type-picker-option-$type'));

Finder optionButton(String type) =>
    find.ancestor(of: option(type), matching: find.byType(InkWell));

Future<void> pumpPicker(
  WidgetTester tester, {
  double width = 300,
  double textScale = 1,
  List<String> initial = const [],
  int maxSelected = 2,
}) async {
  var selected = initial;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTitoTheme(appVisualStyle.style),
      home: Scaffold(
        body: SingleChildScrollView(
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width + 32,
                child: StickerCard(
                  child: StatefulBuilder(
                    builder: (context, setState) => CollapsibleTypePicker(
                      label: '属性',
                      selected: selected,
                      maxSelected: maxSelected,
                      onChanged: (value) => setState(() => selected = value),
                    ),
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
}

BoxDecoration selectionDecoration(WidgetTester tester) =>
    tester.widget<Ink>(find.byKey(selectionKey)).decoration! as BoxDecoration;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppLocale.instance.debugOverride(AppUiLanguage.zh);
    await appVisualStyle.setStyle(AppVisualStyle.solidPlastic);
  });

  tearDown(() async {
    await appVisualStyle.setStyle(AppVisualStyle.classic);
  });

  testWidgets('selection keeps type colours and both names after collapsing', (
    tester,
  ) async {
    await pumpPicker(tester, width: 148, initial: ['rock']);
    expect(selectionDecoration(tester).color, typeTileColor('rock'));
    await tester.tap(selectionButton());
    await tester.pumpAndSettle();
    await tester.tap(optionButton('dragon'));
    await tester.pumpAndSettle();
    await tester.tap(selectionButton());
    await tester.pumpAndSettle();

    final fill = selectionDecoration(tester).gradient! as LinearGradient;
    expect(fill.colors, [
      typeTileColor('rock'),
      typeTileColor('rock'),
      typeTileColor('dragon'),
      typeTileColor('dragon'),
    ]);
    expect(fill.stops, [0, 0.5, 0.5, 1]);
    expect(find.text('岩石'), findsOneWidget);
    expect(find.text('龙'), findsOneWidget);
    expect(option('dragon'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'dual type icons have equal sizes and stay in their colour halves',
    (tester) async {
      await pumpPicker(
        tester,
        width: 148,
        textScale: 1.5,
        initial: ['psychic', 'ghost'],
      );
      final tile = tester.getRect(find.byKey(selectionKey));
      expect(tile.height, 48);
      for (var i = 0; i < 2; i++) {
        final type = ['psychic', 'ghost'][i];
        final icon = find.byWidgetPredicate(
          (widget) => widget is TypeIconImage && widget.typeEn == type,
        );
        final rect = tester.getRect(icon);
        expect(rect.size, const Size(20, 20));
        expect(rect.left, greaterThan(tile.left + tile.width * i / 2));
        expect(rect.right, lessThan(tile.left + tile.width * (i + 1) / 2));
      }
      final arrow = find.byIcon(Icons.expand_more_rounded);
      expect(tester.getSize(arrow), const Size(12, 12));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact dual colours and fixed icons apply to every theme and language',
    (tester) async {
      for (final style in AppVisualStyle.values) {
        for (final language in AppUiLanguage.values) {
          AppLocale.instance.debugOverride(language);
          await appVisualStyle.setStyle(style);
          await pumpPicker(
            tester,
            width: 148,
            textScale: 2,
            initial: ['psychic', 'ghost'],
          );
          final tile = tester.getRect(find.byKey(selectionKey));
          expect(tile.height, 48);
          final fill = selectionDecoration(tester).gradient! as LinearGradient;
          expect(fill.colors.first, typeTileColor('psychic'));
          expect(fill.colors.last, typeTileColor('ghost'));
          for (var i = 0; i < 2; i++) {
            final type = ['psychic', 'ghost'][i];
            final icon = find.byWidgetPredicate(
              (widget) => widget is TypeIconImage && widget.typeEn == type,
            );
            final rect = tester.getRect(icon);
            expect(rect.size, const Size(20, 20));
            expect(rect.left, greaterThan(tile.left + tile.width * i / 2));
            expect(rect.right, lessThan(tile.left + tile.width * (i + 1) / 2));
            expect(find.text(typeNameZh(type)), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    },
  );

  for (final style in AppVisualStyle.values) {
    for (final width in [148.0, 240.0, 360.0]) {
      testWidgets('$style picker fits $width pixels with readable options', (
        tester,
      ) async {
        await appVisualStyle.setStyle(style);
        await pumpPicker(tester, width: width, textScale: 1.5);
        await tester.tap(selectionButton());
        await tester.pumpAndSettle();

        final columns = width >= 240 ? 4 : 3;
        final top = tester.getTopLeft(option(typeGridOrder.first)).dy;
        for (var i = 0; i < columns; i++) {
          expect(tester.getTopLeft(option(typeGridOrder[i])).dy, top);
        }
        expect(
          tester.getTopLeft(option(typeGridOrder[columns])).dy,
          greaterThan(top),
        );
        for (final type in typeGridOrder) {
          expect(option(type), findsOneWidget);
          expect(
            find.descendant(
              of: option(type),
              matching: find.text(typeNameZh(type)),
            ),
            findsOneWidget,
          );
          expect(tester.getSize(option(type)).height, greaterThanOrEqualTo(48));
          final size = tester.getSize(option(type));
          if (width >= 240) {
            expect(size.height, closeTo(size.width, 0.1));
          } else {
            expect((size.height - size.width).abs(), lessThan(10));
          }
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('single selection replaces the previous type and can clear', (
    tester,
  ) async {
    await pumpPicker(tester, initial: ['electric'], maxSelected: 1);
    await tester.tap(selectionButton());
    await tester.pumpAndSettle();
    await tester.tap(optionButton('water'));
    await tester.pumpAndSettle();
    expect(selectionDecoration(tester).color, typeTileColor('water'));
    expect(selectionDecoration(tester).gradient, isNull);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    await tester.tap(optionButton('water'));
    await tester.pumpAndSettle();
    expect(selectionDecoration(tester).gradient, isNull);
    expect(find.text(AppZh.noneSelected), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
