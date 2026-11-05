import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/theme/app_visual_style.dart';
import 'package:titodex/theme/motion_preferences.dart';
import 'package:titodex/theme/number_style_preferences.dart';
import 'package:titodex/theme/tito_colors.dart';
import 'package:titodex/theme/tito_theme.dart';
import 'package:titodex/widgets/tito_animated_number.dart';
import 'package:titodex/widgets/tito_retro_digits.dart';

const _textKey = ValueKey('retro-number');
const _retroStyles = [
  TitoNumberStyle.segment,
  TitoNumberStyle.dotMatrix,
  TitoNumberStyle.pixel,
  TitoNumberStyle.splitFlap,
];

// One ThemeData per style: a fresh instance each pump would start the
// MaterialApp theme animation and look like a running number animation.
final _themes = <AppVisualStyle, ThemeData>{};

TextStyle get _hero => const TextStyle(
  fontSize: 34,
  fontWeight: FontWeight.w800,
  color: TitoColors.softYellow,
);

Widget _host(
  Widget child, {
  AppVisualStyle style = AppVisualStyle.classic,
  bool reduced = false,
}) => MaterialApp(
  theme: _themes.putIfAbsent(style, () => buildTitoTheme(style)),
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(360, 640),
      disableAnimations: reduced,
    ),
    child: Scaffold(
      body: Container(
        width: 360,
        color: TitoColors.deepBlue,
        padding: const EdgeInsets.all(16),
        alignment: Alignment.centerLeft,
        child: child,
      ),
    ),
  ),
);

Widget _number(
  num value, {
  AppVisualStyle style = AppVisualStyle.classic,
  bool retro = true,
  bool reduced = false,
  int fractionDigits = 0,
  String suffix = '',
}) => _host(
  TitoAnimatedNumber(
    value: value,
    identity: 'retro-test',
    retro: retro,
    textKey: _textKey,
    fractionDigits: fractionDigits,
    suffix: suffix,
    style: _hero,
  ),
  style: style,
  reduced: reduced,
);

String _shown(WidgetTester tester) => tester
    .state<TitoAnimatedNumberState>(find.byType(TitoAnimatedNumber))
    .displayedText
    .trim();

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TitoAnimatedNumberState.debugResetMemory();
    await motionPreferences.setListAnimationsEnabled(true);
    await numberStylePreferences.setStyle(TitoNumberStyle.standard);
  });

  tearDown(() async {
    await numberStylePreferences.setStyle(TitoNumberStyle.standard);
    await appVisualStyle.setStyle(AppVisualStyle.classic);
    await motionPreferences.setListAnimationsEnabled(true);
  });

  for (final visual in AppVisualStyle.values) {
    for (final retro in _retroStyles) {
      testWidgets('${retro.name} renders in ${visual.name} at 360px', (
        tester,
      ) async {
        await appVisualStyle.setStyle(visual);
        for (final text in ['123.4%', '–', '×2', '-5/10 ']) {
          await tester.pumpWidget(
            _host(
              TitoRetroNumber(
                numberStyle: retro,
                slots: TitoRetroNumber.restSlots(text),
                style: _hero,
              ),
              style: visual,
            ),
          );
          expect(tester.takeException(), isNull, reason: text);
          final size = tester.getSize(find.byType(TitoRetroNumber));
          expect(size.width, lessThanOrEqualTo(360 - 32), reason: text);
          expect(size.height, greaterThan(0));
        }
        // Mid-roll frames of every transition kind paint too.
        for (final t in [0.0, .25, .5, .75, 1.0]) {
          for (final up in [true, false]) {
            await tester.pumpWidget(
              _host(
                TitoRetroNumber(
                  numberStyle: retro,
                  slots: const [
                    TitoRetroSlot('', '1'),
                    TitoRetroSlot('9', '0'),
                    TitoRetroSlot('.', '.'),
                    TitoRetroSlot('5', ' '),
                    TitoRetroSlot('%', '×'),
                  ],
                  style: _hero,
                  t: t,
                  up: up,
                ),
                style: visual,
              ),
            );
            expect(tester.takeException(), isNull);
          }
        }
      });
    }
  }

  testWidgets('retro styles keep semantics on the plain value', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      for (final retro in _retroStyles) {
        await numberStylePreferences.setStyle(retro);
        await tester.pumpWidget(_number(29.7, fractionDigits: 1, suffix: '%'));
        expect(find.bySemanticsLabel('29.7%'), findsOneWidget);
        expect(find.byKey(_textKey), findsOneWidget);
        expect(find.byType(TitoRetroNumber), findsOneWidget);
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('reduced motion shows the final value at once', (tester) async {
    for (final retro in _retroStyles) {
      await numberStylePreferences.setStyle(retro);
      TitoAnimatedNumberState.debugResetMemory();
      await tester.pumpWidget(_number(100, reduced: true));
      await tester.pumpWidget(_number(236, reduced: true));
      expect(tester.hasRunningAnimations, isFalse, reason: retro.name);
      expect(_shown(tester), '236');
      expect(find.byType(TitoRetroNumber), findsOneWidget);
    }
  });

  testWidgets('a value change rolls with a retro style, then settles', (
    tester,
  ) async {
    for (final retro in _retroStyles) {
      for (final visual in AppVisualStyle.values) {
        await numberStylePreferences.setStyle(retro);
        TitoAnimatedNumberState.debugResetMemory();
        await tester.pumpWidget(_number(120, style: visual));
        await tester.pumpWidget(_number(136, style: visual));
        expect(tester.hasRunningAnimations, isTrue, reason: retro.name);
        await tester.pump(const Duration(milliseconds: 120));
        expect(tester.takeException(), isNull);
        expect(find.byType(TitoRetroNumber), findsOneWidget);
        await tester.pumpAndSettle();
        expect(_shown(tester), '136');
        expect(tester.hasRunningAnimations, isFalse);
        // Shrinking rolls the other way.
        await tester.pumpWidget(_number(98, style: visual));
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        expect(_shown(tester), '98');
      }
    }
  });

  testWidgets('standard style and retro: false keep the plain Text', (
    tester,
  ) async {
    await tester.pumpWidget(_number(120));
    expect(find.byType(TitoRetroNumber), findsNothing);
    expect(tester.widget<Text>(find.byKey(_textKey)).data, '120');

    await numberStylePreferences.setStyle(TitoNumberStyle.segment);
    await tester.pumpWidget(_number(120, retro: false));
    expect(find.byType(TitoRetroNumber), findsNothing);
    expect(tester.widget<Text>(find.byKey(_textKey)).data, '120');
    await tester.pumpWidget(_number(150, retro: false));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(_textKey)).data, '150');
  });

  testWidgets('switching the preference restyles a live number', (
    tester,
  ) async {
    await tester.pumpWidget(_number(120));
    expect(find.byType(TitoRetroNumber), findsNothing);
    await numberStylePreferences.setStyle(TitoNumberStyle.dotMatrix);
    await tester.pump();
    expect(find.byType(TitoRetroNumber), findsOneWidget);
    await numberStylePreferences.setStyle(TitoNumberStyle.standard);
    await tester.pump();
    expect(find.byType(TitoRetroNumber), findsNothing);
    expect(tester.widget<Text>(find.byKey(_textKey)).data, '120');
  });

  test('the number style persists through SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({});
    await numberStylePreferences.setStyle(TitoNumberStyle.pixel);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('appearance.numberStyle'), 'pixel');

    SharedPreferences.setMockInitialValues({
      'appearance.numberStyle': 'splitFlap',
    });
    final fresh = NumberStylePreferences();
    expect(fresh.style, TitoNumberStyle.standard);
    await fresh.load();
    expect(fresh.style, TitoNumberStyle.splitFlap);

    SharedPreferences.setMockInitialValues({'appearance.numberStyle': 'bogus'});
    final unknown = NumberStylePreferences();
    await unknown.load();
    expect(unknown.style, TitoNumberStyle.standard);
  });
}
