import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/theme/motion_preferences.dart';
import 'package:titodex/widgets/tito_animated_number.dart';

const _textKey = ValueKey('number-text');

Widget _app(
  int value, {
  Object identity = 'attacker:25:attack',
  bool reduced = false,
  bool active = true,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: TickerMode(
      enabled: active,
      child: Scaffold(
        body: TitoAnimatedNumber(
          value: value,
          identity: identity,
          textKey: _textKey,
          style: const TextStyle(fontSize: 36),
        ),
      ),
    ),
  ),
);

int _shown(WidgetTester tester) =>
    int.parse(tester.widget<Text>(find.byKey(_textKey)).data!);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await motionPreferences.setListAnimationsEnabled(true);
  });

  tearDown(() async {
    await motionPreferences.setListAnimationsEnabled(true);
  });

  testWidgets('first value is final; changes animate with final semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_app(100));
      expect(_shown(tester), 100);
      expect(tester.hasRunningAnimations, isFalse);
      expect(
        tester.widget<Text>(find.byKey(_textKey)).style!.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );

      await tester.pumpWidget(_app(200));
      expect(_shown(tester), 100);
      expect(find.bySemanticsLabel('200'), findsOneWidget);
      expect(find.bySemanticsLabel('100'), findsNothing);
      await tester.pump(const Duration(milliseconds: 70));
      expect(_shown(tester), greaterThan(100));
      expect(_shown(tester), lessThan(200));
      expect(find.bySemanticsLabel('200'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 150));
      expect(_shown(tester), 200);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('inherited font features survive tabular digit styling', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DefaultTextStyle(
            style: TextStyle(fontFeatures: [FontFeature('ss01')]),
            child: TitoAnimatedNumber(
              value: 100,
              identity: 'attack',
              textKey: _textKey,
            ),
          ),
        ),
      ),
    );
    final features = tester.widget<Text>(find.byKey(_textKey)).style!.fontFeatures;
    expect(features, contains(const FontFeature('ss01')));
    expect(features, contains(const FontFeature.tabularFigures()));
  });

  testWidgets('held keyboard input shows each update immediately', (
    tester,
  ) async {
    await tester.pumpWidget(_app(100));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
    try {
      await tester.pumpWidget(_app(200));
      expect(_shown(tester), 200);
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(_app(250));
      expect(_shown(tester), 250);
      expect(tester.hasRunningAnimations, isFalse);
    } finally {
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
    }
    await tester.pumpWidget(_app(250));
    expect(_shown(tester), 250);
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(_app(300));
    expect(_shown(tester), 250);
    await tester.pump(const Duration(milliseconds: 70));
    expect(_shown(tester), greaterThan(250));
    expect(_shown(tester), lessThan(300));
  });

  testWidgets('rapid changes continue from the displayed value', (
    tester,
  ) async {
    await tester.pumpWidget(_app(100));
    await tester.pumpWidget(_app(300));
    await tester.pump(const Duration(milliseconds: 70));
    final interrupted = _shown(tester);
    expect(interrupted, greaterThan(100));
    expect(interrupted, lessThan(300));

    await tester.pumpWidget(_app(80));
    expect(_shown(tester), interrupted);
    await tester.pump(const Duration(milliseconds: 70));
    expect(_shown(tester), lessThan(interrupted));
    expect(_shown(tester), greaterThan(80));
    await tester.pump(const Duration(milliseconds: 150));
    expect(_shown(tester), 80);
  });

  testWidgets('same-value rebuild does not restart the running change', (
    tester,
  ) async {
    await tester.pumpWidget(_app(100));
    await tester.pumpWidget(_app(200));
    await tester.pump(const Duration(milliseconds: 100));
    final intermediate = _shown(tester);
    await tester.pumpWidget(_app(200));
    expect(_shown(tester), intermediate);
    // One millisecond avoids the ticker's exact-duration floating point edge.
    // A restarted animation would still have 99ms left here.
    await tester.pump(const Duration(milliseconds: 121));
    expect(_shown(tester), 200);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('changing subject or metric replaces the value immediately', (
    tester,
  ) async {
    await tester.pumpWidget(_app(100));
    await tester.pumpWidget(_app(200));
    await tester.pump(const Duration(milliseconds: 70));
    await tester.pumpWidget(_app(70, identity: 'defender:25:attack'));
    expect(_shown(tester), 70);
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(_app(90, identity: 'defender:25:defense'));
    expect(_shown(tester), 90);
    await tester.pumpWidget(_app(150, identity: 'defender:6:defense'));
    expect(_shown(tester), 150);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('system reduced motion stops an active run and never replays', (
    tester,
  ) async {
    await tester.pumpWidget(_app(100));
    await tester.pumpWidget(_app(200));
    await tester.pump(const Duration(milliseconds: 70));
    await tester.pumpWidget(_app(200, reduced: true));
    expect(_shown(tester), 200);
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(_app(250, reduced: true));
    expect(_shown(tester), 250);
    await tester.pumpWidget(_app(250));
    expect(_shown(tester), 250);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets(
    'app motion preference stops immediately without parent rebuild',
    (tester) async {
      await tester.pumpWidget(_app(100));
      await tester.pumpWidget(_app(200));
      await tester.pump(const Duration(milliseconds: 70));
      await motionPreferences.setListAnimationsEnabled(false);
      await tester.pump();
      expect(_shown(tester), 200);
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(_app(250));
      expect(_shown(tester), 250);
      await motionPreferences.setListAnimationsEnabled(true);
      await tester.pump();
      expect(_shown(tester), 250);
      expect(tester.hasRunningAnimations, isFalse);
    },
  );

  testWidgets('hidden tabs settle now and do not replay when returning', (
    tester,
  ) async {
    await tester.pumpWidget(_app(100));
    await tester.pumpWidget(_app(200));
    await tester.pump(const Duration(milliseconds: 70));
    await tester.pumpWidget(_app(200, active: false));
    expect(_shown(tester), 200);
    await tester.pumpWidget(_app(300, active: false));
    expect(_shown(tester), 300);
    await tester.pumpWidget(_app(300));
    expect(_shown(tester), 300);
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pump(const Duration(milliseconds: 70));
    expect(_shown(tester), 300);
  });
}
