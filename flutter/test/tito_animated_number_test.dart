import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/theme/motion_preferences.dart';
import 'package:titodex/widgets/tito_animated_number.dart';

const _textKey = ValueKey('number-text');

Widget _app(
  num value, {
  Object identity = 'attacker:25:attack',
  bool reduced = false,
  bool active = true,
  bool countUp = false,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: TickerMode(
      enabled: active,
      child: Scaffold(
        body: TitoAnimatedNumber(
          value: value,
          identity: identity,
          countUp: countUp,
          textKey: _textKey,
          style: const TextStyle(fontSize: 36),
        ),
      ),
    ),
  ),
);

String _shown(WidgetTester tester) => tester
    .state<TitoAnimatedNumberState>(find.byType(TitoAnimatedNumber))
    .displayedText
    .trim();

/// Every distinct reading of the wheels until the roll settles.
Future<List<String>> _frames(WidgetTester tester) async {
  final seen = <String>[_shown(tester)];
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    final now = _shown(tester);
    if (now != seen.last) seen.add(now);
  }
  return seen;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TitoAnimatedNumberState.debugResetMemory();
    await motionPreferences.setListAnimationsEnabled(true);
  });

  tearDown(() async {
    await motionPreferences.setListAnimationsEnabled(true);
  });

  testWidgets('first value is final; semantics always read the target', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_app(100));
      expect(tester.widget<Text>(find.byKey(_textKey)).data, '100');
      expect(tester.hasRunningAnimations, isFalse);
      expect(
        tester.widget<Text>(find.byKey(_textKey)).style!.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      await tester.pumpWidget(_app(200));
      expect(find.bySemanticsLabel('200'), findsOneWidget);
      expect(find.bySemanticsLabel('100'), findsNothing);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(_textKey)).data, '200');
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('only changed digits roll, each to its own new digit', (
    tester,
  ) async {
    await tester.pumpWidget(_app(120));
    await tester.pumpWidget(_app(136));
    var frames = await _frames(tester);
    expect(frames.first, '120');
    expect(frames.last, '136');
    expect(frames.every((f) => f.startsWith('1')), isTrue);
    // Ones count 0→6, tens 2→3: no other values in between.
    expect(frames.every((f) => f[1] == '2' || f[1] == '3'), isTrue);

    await tester.pumpWidget(_app(236));
    frames = await _frames(tester);
    expect(frames, ['136', '236']);

    await tester.pumpWidget(_app(210));
    frames = await _frames(tester);
    expect(frames.first, '236');
    expect(frames.last, '210');
    expect(frames.every((f) => f.startsWith('2')), isTrue);
    // Each changed slot rolls a single step: it only ever shows its old or its
    // new digit (tens 3→1, ones 6→0), never the digits in between.
    expect(frames.every((f) => f[1] == '3' || f[1] == '1'), isTrue);
    expect(frames.every((f) => f[2] == '6' || f[2] == '0'), isTrue);
    expect(frames.toSet().difference({'236', '216', '230', '210'}), isEmpty);
  });

  testWidgets('count up rolls in from zero, then changes roll in place', (
    tester,
  ) async {
    await tester.pumpWidget(_app(136, countUp: true));
    expect(_shown(tester), '0');
    await tester.pumpAndSettle();
    expect(_shown(tester), '136');
    await tester.pumpWidget(_app(140, countUp: true));
    final frames = await _frames(tester);
    expect(frames.every((f) => f.startsWith('1')), isTrue);
    expect(frames.last, '140');
  });

  testWidgets('decimals and suffixes keep their place', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TitoAnimatedNumber(
            value: 29.7,
            identity: 'pct',
            fractionDigits: 1,
            suffix: '%',
            textKey: _textKey,
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TitoAnimatedNumber(
            value: 31.2,
            identity: 'pct',
            fractionDigits: 1,
            suffix: '%',
            textKey: _textKey,
          ),
        ),
      ),
    );
    final frames = await _frames(tester);
    expect(frames.every((f) => f.endsWith('%') && f[2] == '.'), isTrue);
    expect(frames.last, '31.2%');
    expect(tester.takeException(), isNull);
  });

  testWidgets('held keyboard input shows each update immediately', (
    tester,
  ) async {
    await tester.pumpWidget(_app(100));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
    try {
      await tester.pumpWidget(_app(200));
      expect(_shown(tester), '200');
      expect(tester.hasRunningAnimations, isFalse);
    } finally {
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
    }
    await tester.pumpWidget(_app(300));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(_shown(tester), '300');
  });

  testWidgets('an interrupted roll continues from what is shown', (
    tester,
  ) async {
    await tester.pumpWidget(_app(100));
    await tester.pumpWidget(_app(109));
    await tester.pump(const Duration(milliseconds: 120));
    final mid = _shown(tester);
    expect(mid, isNot('100'));
    await tester.pumpWidget(_app(105));
    expect(_shown(tester), mid);
    await tester.pumpAndSettle();
    expect(_shown(tester), '105');
  });

  testWidgets('changing subject or metric replaces the value immediately', (
    tester,
  ) async {
    await tester.pumpWidget(_app(100));
    await tester.pumpWidget(_app(200));
    await tester.pump(const Duration(milliseconds: 70));
    await tester.pumpWidget(_app(70, identity: 'defender:25:attack'));
    expect(_shown(tester), '70');
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('reduced motion, app switch and hidden tabs settle at once', (
    tester,
  ) async {
    await tester.pumpWidget(_app(100));
    await tester.pumpWidget(_app(200));
    await tester.pump(const Duration(milliseconds: 70));
    await tester.pumpWidget(_app(200, reduced: true));
    expect(_shown(tester), '200');
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pumpWidget(_app(200));
    await tester.pumpWidget(_app(300));
    await tester.pump(const Duration(milliseconds: 70));
    await motionPreferences.setListAnimationsEnabled(false);
    await tester.pump();
    expect(_shown(tester), '300');
    expect(tester.hasRunningAnimations, isFalse);
    await motionPreferences.setListAnimationsEnabled(true);

    await tester.pumpWidget(_app(400, active: false));
    expect(_shown(tester), '400');
    await tester.pumpWidget(_app(400));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('a rebuilt slot rolls on from its last value, not from zero', (
    tester,
  ) async {
    await tester.pumpWidget(_app(120, countUp: true));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(136, countUp: true));
    final frames = await _frames(tester);
    expect(frames.first, '120');
    expect(frames.last, '136');
    expect(frames.every((f) => f.startsWith('1')), isTrue);

    // A slot that has never been shown still counts up from zero.
    await tester.pumpWidget(_app(80, countUp: true, identity: 'fresh'));
    expect(_shown(tester), '0');
    await tester.pumpAndSettle();
    expect(_shown(tester), '80');
  });
}
