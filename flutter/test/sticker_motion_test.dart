import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/theme/app_visual_style.dart';
import 'package:titodex/theme/motion_preferences.dart';
import 'package:titodex/theme/retro_style.dart';
import 'package:titodex/theme/tito_theme.dart';
import 'package:titodex/widgets/handheld_input.dart';
import 'package:titodex/widgets/retro_forms.dart';
import 'package:titodex/widgets/sticker_pressable.dart';

const _bodyKey = ValueKey('press-body');
Widget _press({bool interactive = true}) => StickerPressable(
  interactive: interactive,
  borderRadius: BorderRadius.circular(12),
  child: const SizedBox(key: _bodyKey, width: 120, height: 80),
);
Widget _host(
  Widget child, {
  AppVisualStyle style = AppVisualStyle.classic,
  bool disabled = false,
}) => MaterialApp(
  theme: buildTitoTheme(style),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disabled),
    child: Scaffold(body: Center(child: child)),
  ),
);
double _dy(WidgetTester tester) => tester
    .widget<Transform>(
      find
          .descendant(
            of: find.byType(StickerPressable),
            matching: find.byType(Transform),
          )
          .first,
    )
    .transform
    .getTranslation()
    .y;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await motionPreferences.setListAnimationsEnabled(true);
    await retroStyle.setEnabled(true);
  });
  tearDown(() async {
    await motionPreferences.setListAnimationsEnabled(true);
    await retroStyle.setEnabled(true);
  });

  for (final style in [AppVisualStyle.classic, AppVisualStyle.solidPlastic]) {
    testWidgets(
      '$style rapid release/repress keeps latest hold and returns to rest',
      (tester) async {
        await tester.pumpWidget(_host(_press(), style: style));
        final origin = tester.getTopLeft(find.byKey(_bodyKey));
        final size = tester.getSize(find.byType(StickerPressable));
        final first = await tester.startGesture(
          tester.getCenter(find.byKey(_bodyKey)),
          pointer: 1,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 35));
        final partial = _dy(tester);
        expect(partial, greaterThan(0));
        await first.up();
        await tester.pump();
        expect(_dy(tester), closeTo(partial, 0.001));
        await tester.pump(const Duration(milliseconds: 20));
        final second = await tester.startGesture(
          tester.getCenter(find.byKey(_bodyKey)),
          pointer: 2,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        final held = _dy(tester);
        expect(held, greaterThan(0));
        await tester.pump(const Duration(milliseconds: 300));
        expect(_dy(tester), held);
        expect(tester.getSize(find.byType(StickerPressable)), size);
        await second.cancel();
        await tester.pumpAndSettle();
        expect(_dy(tester), 0);
        expect(tester.getTopLeft(find.byKey(_bodyKey)), origin);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'scroll cancellation and multiple pointers cannot strand a press',
    (tester) async {
      await tester.pumpWidget(_host(_press()));
      final center = tester.getCenter(find.byKey(_bodyKey));
      final first = await tester.startGesture(center, pointer: 1);
      final second = await tester.startGesture(center, pointer: 2);
      await tester.pumpAndSettle();
      await first.up();
      await tester.pumpAndSettle();
      expect(_dy(tester), greaterThan(0));
      await second.moveBy(const Offset(0, 50));
      await tester.pumpAndSettle();
      expect(_dy(tester), 0);
      await second.up();
      final pending = await tester.startGesture(center, pointer: 3);
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await pending.cancel();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );

  for (final system in [true, false]) {
    testWidgets(
      '${system ? 'system' : 'preference'} stops an active press immediately',
      (tester) async {
        await tester.pumpWidget(_host(_press()));
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(_bodyKey)),
        );
        await tester.pumpAndSettle();
        expect(_dy(tester), greaterThan(0));
        if (system) {
          await tester.pumpWidget(_host(_press(), disabled: true));
        } else {
          await motionPreferences.setListAnimationsEnabled(false);
          await tester.pump();
        }
        expect(_dy(tester), 0);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(_dy(tester), 0);
      },
    );
  }

  testWidgets(
    'losing D-pad focus while held releases without waiting for key-up',
    (tester) async {
      final a = FocusNode();
      final b = FocusNode();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await tester.pumpWidget(
        _host(
          Column(
            children: [
              HandheldFocusDecorator(
                onActivate: () {},
                child: Focus(focusNode: a, child: _press()),
              ),
              Focus(focusNode: b, child: const SizedBox(width: 80, height: 80)),
            ],
          ),
        ),
      );
      a.requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.gameButtonA);
      await tester.pumpAndSettle();
      expect(_dy(tester), greaterThan(0));
      b.requestFocus();
      await tester.pumpAndSettle();
      expect(_dy(tester), 0);
      a.requestFocus();
      await tester.pumpAndSettle();
      expect(_dy(tester), 0);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.gameButtonA);
    },
  );

  for (final style in AppVisualStyle.values) {
    testWidgets(
      '$style switch reverses continuously and reduced motion is immediate',
      (tester) async {
        final selected = ValueNotifier(false);
        final disabled = ValueNotifier(false);
        addTearDown(selected.dispose);
        addTearDown(disabled.dispose);
        await tester.pumpWidget(
          ValueListenableBuilder<bool>(
            valueListenable: disabled,
            builder: (_, reduce, _) => _host(
              ValueListenableBuilder<bool>(
                valueListenable: selected,
                builder: (_, value, _) => StickerSwitch(
                  value: value,
                  onChanged: (v) => selected.value = v,
                ),
              ),
              style: style,
              disabled: reduce,
            ),
          ),
        );
        Finder knob() => find.descendant(
          of: find.byType(StickerSwitch),
          matching: find.byType(Transform),
        );
        double x() => tester.getCenter(knob()).dx;
        final start = x();
        await tester.tap(find.byType(StickerSwitch));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        final middle = x();
        expect(middle, greaterThan(start));
        final shape = tester.widget<Transform>(knob()).transform;
        expect(shape.storage[0] * shape.storage[5], closeTo(1, 0.001));
        if (style != AppVisualStyle.flatUi) {
          expect(shape.storage[0], greaterThan(1));
        }
        await tester.tap(find.byType(StickerSwitch));
        await tester.pump();
        expect(x(), closeTo(middle, 0.001));
        await tester.pumpAndSettle();
        expect(x(), start);
        expect(tester.widget<Transform>(knob()).transform.storage[0], 1);
        selected.value = true;
        await tester.pumpAndSettle();
        final end = x();
        selected.value = false;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 30));
        disabled.value = true;
        await tester.pump();
        expect(x(), start);
        selected.value = true;
        await tester.pump();
        expect(x(), end);
        expect(tester.widget<Transform>(knob()).transform.storage[0], 1);
        disabled.value = false;
        await motionPreferences.setListAnimationsEnabled(false);
        selected.value = false;
        await tester.pump();
        expect(x(), start);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
