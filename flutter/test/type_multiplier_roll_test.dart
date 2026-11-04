import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/dex/type_chart.dart';
import 'package:titodex/l10n/app_locale.dart';
import 'package:titodex/theme/app_visual_style.dart';
import 'package:titodex/theme/motion_preferences.dart';
import 'package:titodex/theme/tito_theme.dart';
import 'package:titodex/widgets/pokemon_detail_sections.dart';
import 'package:titodex/widgets/tito_rolling_value.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final nunito = FontLoader('Nunito');
    for (final weight in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
      nunito.addFont(rootBundle.load('assets/fonts/Nunito-$weight.ttf'));
    }
    await nunito.load();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await motionPreferences.setListAnimationsEnabled(true);
    AppLocale.instance.debugOverride(AppUiLanguage.zh);
  });
  tearDown(() async {
    await motionPreferences.setListAnimationsEnabled(true);
    await appVisualStyle.setStyle(AppVisualStyle.classic);
    AppLocale.instance.debugOverride(AppUiLanguage.zh);
  });

  test(
    'multiplier formatting preserves fractions and exact ability values',
    () {
      final cases = <double, String>{
        0: '0',
        .125: '0.125',
        .25: '1/4',
        .5: '1/2',
        .625: '0.625',
        .75: '0.75',
        1: '1',
        1.25: '1.25',
        1.5: '1.5',
        2: '2',
        2.5: '2.5',
        4: '4',
        5: '5',
        8: '8',
      };
      for (final entry in cases.entries) {
        expect(formatTypeMultiplier(entry.key), entry.value);
      }
      expect(formatTypeMultiplier(-0.0), '0');
      expect(formatTypeMultiplier(2.25), '2.25');
      // Float noise never leaks into a visible multiplier.
      expect(formatTypeMultiplier(0.1 + 0.2), '0.3');
    },
  );

  test('Dry Skin values stay exact after stacking on type resistance', () {
    final multipliers = computeDefensiveMultipliersWithAbility(
      defenderTypes: ['water'],
      relationsByType: const {
        'fire': TypeDamageRelations(
          doubleDamageTo: {},
          halfDamageTo: {'water'},
          noDamageTo: {},
        ),
      },
      defenderAbilitySlug: 'dry-skin',
    );
    expect(multipliers['fire'], .625);
    expect(formatTypeMultiplier(multipliers['fire']!), '0.625');
  });

  testWidgets(
    'fixed type slot rolls exact text with immediate final semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(_host({'fire': 2}));
        await tester.pumpAndSettle();
        final slot = find.byKey(const ValueKey('type-multiplier-fire'));
        final state = tester.state(slot);
        expect(_texts(tester, slot), {'2'});
        expect(tester.hasRunningAnimations, isFalse);

        await tester.pumpWidget(_host({'fire': .5}));
        expect(tester.state(slot), same(state));
        await tester.pump(const Duration(milliseconds: 70));
        expect(_texts(tester, slot), containsAll(['2', '1/2']));
        expect(_texts(tester, slot).difference({'2', '1/2'}), isEmpty);
        // Grid semantics group each type name with its current multiplier.
        expect(
          find.bySemanticsLabel('${typeNameZh('fire')}\n1/2'),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('${typeNameZh('fire')}\n2'), findsNothing);
        expect(tester.hasRunningAnimations, isTrue);

        await tester.pump(const Duration(milliseconds: 151));
        expect(_texts(tester, slot), {'1/2'});
        expect(tester.hasRunningAnimations, isFalse);

        await tester.pumpWidget(_host({'fire': 1.25}));
        await tester.pump(const Duration(milliseconds: 70));
        expect(_texts(tester, slot), containsAll(['1/2', '1.25']));
        expect(
          find.bySemanticsLabel('${typeNameZh('fire')}\n1.25'),
          findsOneWidget,
        );
        await tester.pump(const Duration(milliseconds: 151));
        expect(_texts(tester, slot), {'1.25'});
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('grid reflow keeps multiplier state and reduced motion snaps', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host({'fire': 2}));
    await tester.pumpAndSettle();
    final slot = find.byKey(const ValueKey('type-multiplier-fire'));
    final state = tester.state(slot);
    await tester.pumpWidget(_host({'fire': .125}));
    await tester.pump(const Duration(milliseconds: 70));

    tester.view.physicalSize = const Size(800, 480);
    await tester.pumpWidget(_host({'fire': .125}, scale: 2));
    expect(tester.state(slot), same(state));
    expect(_texts(tester, slot), containsAll(['2', '0.125']));

    await tester.pumpWidget(_host({'fire': 2.5}, scale: 2, reduced: true));
    expect(_texts(tester, slot), {'2.5'});
    await tester.pumpWidget(_host({'fire': 2.5}, scale: 2));
    expect(_texts(tester, slot), {'2.5'});
    await tester.pump(const Duration(milliseconds: 70));
    expect(_texts(tester, slot), {'2.5'});
    // Rotation also schedules scroll-metrics work outside the value widgets.
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final style in AppVisualStyle.values) {
    for (final scenario in [
      (size: const Size(320, 640), scale: 1.0),
      (size: const Size(480, 480), scale: 1.0),
      (size: const Size(800, 480), scale: 1.0),
      (size: const Size(390, 844), scale: 2.0),
      (size: const Size(800, 480), scale: 2.0),
    ]) {
      testWidgets(
        '$style type grid at ${scenario.size} scale ${scenario.scale}',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = scenario.size;
          addTearDown(tester.view.reset);
          await appVisualStyle.setStyle(style);
          AppLocale.instance.debugOverride(
            scenario.scale > 1 ? AppUiLanguage.en : AppUiLanguage.zh,
          );
          const values = {
            'fire': .125,
            'water': .25,
            'electric': .5,
            'grass': 1.25,
            'ice': 2.5,
            'ground': 0.0,
          };
          await tester.pumpWidget(
            _host(values, style: style, scale: scenario.scale),
          );
          await tester.pumpAndSettle();
          expect(find.byType(TitoRollingValue), findsNWidgets(18));
          for (final type in typeGridOrder) {
            final cell = find.byKey(ValueKey('type-effectiveness-cell-$type'));
            final text = find.byKey(ValueKey('type-multiplier-text-$type'));
            final paragraph = tester.renderObject<RenderParagraph>(text);
            final cellRect = tester.getRect(cell);
            final textRect = tester.getRect(text);
            expect(
              tester.widget<Text>(text).data,
              formatTypeMultiplier(values[type] ?? 1),
            );
            expect(paragraph.didExceedMaxLines, isFalse);
            expect(textRect.left, greaterThanOrEqualTo(cellRect.left - .01));
            expect(textRect.right, lessThanOrEqualTo(cellRect.right + .01));
            expect(textRect.bottom, lessThanOrEqualTo(cellRect.bottom + .01));
          }
          expect(tester.hasRunningAnimations, isFalse);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

Set<String> _texts(WidgetTester tester, Finder slot) => tester
    .widgetList<Text>(find.descendant(of: slot, matching: find.byType(Text)))
    .map((text) => text.data!)
    .toSet();

Widget _host(
  Map<String, double> multipliers, {
  AppVisualStyle style = AppVisualStyle.classic,
  double scale = 1,
  bool reduced = false,
}) => MaterialApp(
  theme: buildTitoTheme(style),
  themeAnimationDuration: Duration.zero,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale),
      disableAnimations: reduced,
    ),
    child: child!,
  ),
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: TypeEffectivenessGrid(multipliers: multipliers),
    ),
  ),
);
