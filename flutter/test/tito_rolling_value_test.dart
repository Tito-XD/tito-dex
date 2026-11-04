import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/theme/motion_preferences.dart';
import 'package:titodex/theme/tito_motion.dart';
import 'package:titodex/widgets/tito_rolling_value.dart';

const _textKey = ValueKey('rolling-current-value');
const _inheritedStyle = TextStyle(fontSize: 24, color: Colors.blue);
final _midway = Duration(milliseconds: TitoMotion.standard.inMilliseconds ~/ 3);
final _finished = TitoMotion.standard + const Duration(milliseconds: 1);

Widget _app(
  String value, {
  Object identity = 'defender:25:effectiveness',
  TextStyle? style,
  TextStyle inheritedStyle = _inheritedStyle,
  double scale = 1,
  bool reduced = false,
  bool bold = false,
  bool active = true,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      disableAnimations: reduced,
      boldText: bold,
      textScaler: TextScaler.linear(scale),
    ),
    child: TickerMode(
      enabled: active,
      child: Scaffold(
        body: Center(
          child: DefaultTextStyle(
            style: inheritedStyle,
            child: TitoRollingValue(
              value: value,
              identity: identity,
              textKey: _textKey,
              style: style,
            ),
          ),
        ),
      ),
    ),
  ),
);

Finder get _rolling => find.byType(TitoRollingValue);
Finder get _texts => find.descendant(of: _rolling, matching: find.byType(Text));

List<String> _tokens(WidgetTester tester) =>
    tester.widgetList<Text>(_texts).map((text) => text.data!).toList();

Map<String, Offset> _positions(WidgetTester tester) => {
  for (final value in _tokens(tester))
    value: tester.getCenter(find.text(value)),
};

void _expectSeparatedLayers(WidgetTester tester) {
  final bounds = [
    for (final value in _tokens(tester)) tester.getRect(find.text(value)),
  ]..sort((a, b) => a.top.compareTo(b.top));
  if (bounds.length < 2) return;
  expect(bounds[0].bottom, lessThanOrEqualTo(bounds[1].top + .01));
  expect(
    bounds[1].center.dy - bounds[0].center.dy,
    greaterThanOrEqualTo(tester.getSize(_rolling).height - .01),
    reason: 'Retargeted text rows must remain at least one full line apart.',
  );
}

void _expectSettled(WidgetTester tester, String value) {
  expect(_tokens(tester), [value]);
  expect(tester.hasRunningAnimations, isFalse);
  final current = tester.getCenter(find.byKey(_textKey));
  final slot = tester.getCenter(_rolling);
  expect(current.dx, closeTo(slot.dx, .01));
  expect(current.dy, closeTo(slot.dy, .01));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await motionPreferences.setListAnimationsEnabled(true);
  });

  tearDown(() async {
    await motionPreferences.setListAnimationsEnabled(true);
  });

  testWidgets(
    'rolls exact integer, decimal and fraction tokens with final semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(_app('2×'));
        _expectSettled(tester, '2×');

        var previous = '2×';
        for (final next in ['0.5×', '½×']) {
          await tester.pumpWidget(_app(next));
          expect(_tokens(tester), unorderedEquals([previous, next]));
          expect(tester.widget<Text>(find.byKey(_textKey)).data, next);
          expect(find.bySemanticsLabel(next), findsOneWidget);
          expect(find.bySemanticsLabel(previous), findsNothing);
          for (var frame = 0; frame < 3; frame++) {
            await tester.pump(_midway);
            // Intermediate frames contain only complete supplied strings; they
            // never claim a fictitious calculated value such as 1.3×.
            expect(
              _tokens(tester).toSet().difference({previous, next}),
              isEmpty,
            );
            expect(find.bySemanticsLabel(next), findsOneWidget);
            expect(find.bySemanticsLabel(previous), findsNothing);
          }
          await tester.pump(_finished);
          _expectSettled(tester, next);
          previous = next;
        }
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'rapid retargeting keeps at most two tokens and a visible token continuous',
    (tester) async {
      await tester.pumpWidget(_app('2×'));
      await tester.pumpWidget(_app('0.5×'));
      final supplied = <String>{'2×', '0.5×'};
      for (final (index, next) in ['½×', '4×', '0×', '0.25×', '2×'].indexed) {
        // First interrupt after the incoming token becomes dominant, then
        // retarget earlier frames too. Both sides of the roll need spacing.
        await tester.pump(
          index == 0 ? _midway : const Duration(milliseconds: 25),
        );
        _expectSeparatedLayers(tester);
        final before = _positions(tester);
        supplied.add(next);
        await tester.pumpWidget(_app(next));
        final after = _positions(tester);
        expect(_tokens(tester).length, lessThanOrEqualTo(2));
        expect(after.length, _tokens(tester).length);
        _expectSeparatedLayers(tester);
        expect(after.keys, contains(next));
        expect(after.keys.toSet().difference(supplied), isEmpty);
        final retained = before.keys.toSet().intersection(after.keys.toSet());
        expect(retained, isNotEmpty);
        expect(
          retained.any(
            (token) => (before[token]!.dy - after[token]!.dy).abs() < .01,
          ),
          isTrue,
          reason: 'At least one existing token must keep its painted position.',
        );
      }
      await tester.pump(_finished);
      _expectSettled(tester, '2×');
    },
  );

  testWidgets('a quick reversal preserves both token positions', (
    tester,
  ) async {
    await tester.pumpWidget(_app('2×'));
    await tester.pumpWidget(_app('0.5×'));
    await tester.pump(_midway);
    final before = _positions(tester);
    expect(before, hasLength(2));
    expect(before['2×']!.dy, isNot(closeTo(before['0.5×']!.dy, .01)));

    await tester.pumpWidget(_app('2×'));
    final after = _positions(tester);
    expect(after.keys, unorderedEquals(before.keys));
    for (final token in before.keys) {
      expect(after[token]!.dx, closeTo(before[token]!.dx, .01));
      expect(after[token]!.dy, closeTo(before[token]!.dy, .01));
    }
    await tester.pump(_finished);
    _expectSettled(tester, '2×');
  });

  testWidgets('same-value rebuild neither jumps nor restarts an active roll', (
    tester,
  ) async {
    await tester.pumpWidget(_app('2×'));
    await tester.pumpWidget(_app('0.5×'));
    await tester.pump(_midway);
    final before = _positions(tester);
    await tester.pumpWidget(_app('0.5×'));
    final after = _positions(tester);
    for (final token in before.keys) {
      expect(after[token]!.dy, closeTo(before[token]!.dy, .01));
    }
    await tester.pump(_finished - _midway);
    _expectSettled(tester, '0.5×');
  });

  testWidgets('initial values and changed subject or metric show immediately', (
    tester,
  ) async {
    await tester.pumpWidget(_app('½×'));
    _expectSettled(tester, '½×');
    await tester.pumpWidget(_app('2×'));
    await tester.pump(_midway);
    await tester.pumpWidget(_app('0×', identity: 'defender:6:effectiveness'));
    _expectSettled(tester, '0×');
    await tester.pumpWidget(_app('25%', identity: 'defender:6:damage-range'));
    _expectSettled(tester, '25%');
  });

  testWidgets('held input settles each change and release does not replay it', (
    tester,
  ) async {
    await tester.pumpWidget(_app('2×'));
    await tester.pumpWidget(_app('0.5×'));
    await tester.pump(_midway);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
    try {
      await tester.pumpWidget(_app('½×'));
      _expectSettled(tester, '½×');
      await tester.pumpWidget(_app('0×'));
      _expectSettled(tester, '0×');
    } finally {
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
    }
    await tester.pumpWidget(_app('0×'));
    await tester.pump(_finished);
    _expectSettled(tester, '0×');
    await tester.pumpWidget(_app('2×'));
    expect(_tokens(tester), unorderedEquals(['0×', '2×']));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pump(_finished);
  });

  testWidgets(
    'system reduced motion snaps active and new values without replay',
    (tester) async {
      await tester.pumpWidget(_app('2×'));
      await tester.pumpWidget(_app('0.5×'));
      await tester.pump(_midway);
      await tester.pumpWidget(_app('0.5×', reduced: true));
      _expectSettled(tester, '0.5×');
      await tester.pumpWidget(_app('½×', reduced: true));
      _expectSettled(tester, '½×');
      await tester.pumpWidget(_app('½×'));
      await tester.pump(_finished);
      _expectSettled(tester, '½×');
    },
  );

  testWidgets(
    'App motion preference snaps without a parent rebuild and never replays',
    (tester) async {
      await tester.pumpWidget(_app('2×'));
      await tester.pumpWidget(_app('0.5×'));
      await tester.pump(_midway);
      await motionPreferences.setListAnimationsEnabled(false);
      await tester.pump();
      _expectSettled(tester, '0.5×');
      await tester.pumpWidget(_app('½×'));
      _expectSettled(tester, '½×');
      await motionPreferences.setListAnimationsEnabled(true);
      await tester.pump();
      _expectSettled(tester, '½×');
      await tester.pump(_finished);
      _expectSettled(tester, '½×');
    },
  );

  testWidgets(
    'hidden ticker snaps active and hidden changes and never replays',
    (tester) async {
      await tester.pumpWidget(_app('2×'));
      await tester.pumpWidget(_app('0.5×'));
      await tester.pump(_midway);
      await tester.pumpWidget(_app('0.5×', active: false));
      _expectSettled(tester, '0.5×');
      await tester.pumpWidget(_app('½×', active: false));
      _expectSettled(tester, '½×');
      await tester.pumpWidget(_app('½×'));
      _expectSettled(tester, '½×');
      await tester.pump(_finished);
      _expectSettled(tester, '½×');
    },
  );

  testWidgets(
    'both token layers inherit typography and preserve tabular font features',
    (tester) async {
      const inherited = TextStyle(
        fontFamily: 'Nunito',
        fontFamilyFallback: ['Noto Sans CJK SC'],
        fontSize: 28,
        height: 1.3,
        color: Colors.blue,
        fontFeatures: [FontFeature('ss01')],
      );
      const oldStyle = TextStyle(fontWeight: FontWeight.w600);
      const newStyle = TextStyle(fontWeight: FontWeight.w800);
      await tester.pumpWidget(
        _app('2×', style: oldStyle, inheritedStyle: inherited),
      );
      await tester.pumpWidget(
        _app('½×', style: newStyle, inheritedStyle: inherited),
      );
      for (final text in tester.widgetList<Text>(_texts)) {
        expect(text.style!.fontFamily, 'Nunito');
        expect(text.style!.fontFamilyFallback, ['Noto Sans CJK SC']);
        expect(text.style!.fontSize, 28);
        expect(text.style!.height, 1.3);
        expect(text.style!.color, Colors.blue);
        expect(text.style!.fontFeatures, contains(const FontFeature('ss01')));
        expect(
          text.style!.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
      }
      expect(
        tester.widget<Text>(find.text('2×')).style!.fontWeight,
        FontWeight.w600,
      );
      expect(
        tester.widget<Text>(find.byKey(_textKey)).style!.fontWeight,
        FontWeight.w800,
      );
      await tester.pump(_finished);
    },
  );

  testWidgets('same slot keeps its width after a longer fraction leaves', (
    tester,
  ) async {
    await tester.pumpWidget(_app('123⁄256×'));
    final wide = tester.getSize(_rolling).width;
    await tester.pumpWidget(_app('2×'));
    expect(tester.getSize(_rolling).width, closeTo(wide, .01));
    await tester.pump(_finished);
    _expectSettled(tester, '2×');
    // Also rebuild after removal: retaining only the transition's width is
    // insufficient when the next parent build would move neighboring labels.
    await tester.pumpWidget(_app('2×'));
    expect(tester.getSize(_rolling).width, closeTo(wide, .01));
    await tester.pumpWidget(_app('½×'));
    await tester.pump(_finished);
    await tester.pumpWidget(_app('½×'));
    expect(tester.getSize(_rolling).width, closeTo(wide, .01));
    await tester.pumpWidget(_app('½×', identity: 'another-metric'));
    _expectSettled(tester, '½×');
    expect(tester.getSize(_rolling).width, lessThan(wide));
  });

  testWidgets(
    'system bold text uses the rendered weight when measuring its slot',
    (tester) async {
      // A real font keeps this sensitive to weight metrics; the default test
      // font can use identical advances for regular and bold glyphs.
      await tester.runAsync(() async {
        final font = FontLoader('RollingValueMetrics');
        for (final weight in ['Regular', 'Bold']) {
          font.addFont(rootBundle.load('assets/fonts/Nunito-$weight.ttf'));
        }
        await font.load();
      });
      const inherited = TextStyle(
        fontFamily: 'RollingValueMetrics',
        fontSize: 36,
        fontWeight: FontWeight.w400,
        height: 1.2,
      );
      await tester.pumpWidget(_app('0.5×', inheritedStyle: inherited));
      for (final scale in [1.0, 1.8]) {
        await tester.pumpWidget(
          _app('0.5×', inheritedStyle: inherited, scale: scale, bold: true),
        );
        _expectSettled(tester, '0.5×');
        final text = tester.widget<Text>(find.byKey(_textKey));
        expect(text.style!.fontWeight, FontWeight.bold);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.byKey(_textKey),
            matching: find.byType(RichText),
          ),
        );
        final slot = tester.getSize(_rolling);
        expect(
          slot.width,
          closeTo(paragraph.getMaxIntrinsicWidth(double.infinity), .01),
        );
        expect(slot.height, greaterThanOrEqualTo(paragraph.size.height));
      }
      await tester.pumpWidget(_app('0.5×', inheritedStyle: inherited));
      expect(
        tester.widget<Text>(find.byKey(_textKey)).style!.fontWeight,
        FontWeight.w400,
      );
      _expectSettled(tester, '0.5×');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'slot measures larger inherited fonts and accessibility text scale',
    (tester) async {
      await tester.pumpWidget(_app('0.5×'));
      final normal = tester.getSize(_rolling);
      await tester.pumpWidget(_app('0.5×', scale: 1.8));
      final scaled = tester.getSize(_rolling);
      expect(scaled.width, greaterThan(normal.width));
      expect(scaled.height, greaterThan(normal.height));
      final rendered = tester.getSize(find.byKey(_textKey));
      expect(scaled.width, greaterThanOrEqualTo(rendered.width));
      expect(scaled.height, greaterThanOrEqualTo(rendered.height));
      _expectSettled(tester, '0.5×');

      await tester.pumpWidget(
        _app('0.5×', inheritedStyle: const TextStyle(fontSize: 48)),
      );
      final largerFont = tester.getSize(_rolling);
      expect(largerFont.width, greaterThan(normal.width));
      expect(largerFont.height, greaterThan(normal.height));
      await tester.pumpWidget(_app('0.5×'));
      expect(tester.getSize(_rolling).width, closeTo(normal.width, .01));
      expect(tester.getSize(_rolling).height, closeTo(normal.height, .01));
      expect(tester.takeException(), isNull);
    },
  );
}
