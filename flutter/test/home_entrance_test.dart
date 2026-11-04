import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/theme/app_visual_style.dart';
import 'package:titodex/theme/motion_preferences.dart';
import 'package:titodex/theme/tito_theme.dart';
import 'package:titodex/widgets/handheld_input.dart';
import 'package:titodex/widgets/handheld_focus_geometry.dart';
import 'package:titodex/widgets/home_entrance.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await motionPreferences.setListAnimationsEnabled(true);
  });

  tearDown(() async {
    await motionPreferences.setListAnimationsEnabled(true);
    await appVisualStyle.setStyle(AppVisualStyle.classic);
  });

  for (final style in AppVisualStyle.values) {
    testWidgets('$style Home entrance is bounded and keeps controls visible', (
      tester,
    ) async {
      await appVisualStyle.setStyle(style);
      await tester.pumpWidget(_host(style: style));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(_opacity(tester, 0), greaterThan(_opacity(tester, 5)));
      expect(_opacity(tester, 5), greaterThan(.5));
      for (var index = 0; index < 6; index++) {
        final control = find.descendant(
          of: find.byKey(ValueKey('entrance-$index')),
          matching: find.byType(HandheldFocusDecorator),
        );
        final node = Focus.of(
          tester.element(
            find.descendant(
              of: control,
              matching: find.byType(HandheldPressed),
            ),
          ),
        );
        expect(HandheldFocusGeometry.of(node)?.bounds, tester.getRect(control));
      }
      await tester.pump(const Duration(milliseconds: 450));
      for (var index = 0; index < 6; index++) {
        expect(_opacity(tester, index), 1);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('bootstrap waits, refresh and orientation do not replay Home', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final ready = ValueNotifier(false);
    final revision = ValueNotifier(0);
    addTearDown(ready.dispose);
    addTearDown(revision.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<bool>(
        valueListenable: ready,
        builder: (context, value, _) => ValueListenableBuilder<int>(
          valueListenable: revision,
          builder: (context, number, _) =>
              _host(ready: value, revision: number),
        ),
      ),
    );
    expect(_opacity(tester, 5), 1);
    await tester.pump(const Duration(seconds: 1));
    ready.value = true;
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(_opacity(tester, 5), lessThan(1));
    await tester.pump(const Duration(milliseconds: 450));
    revision.value++;
    await tester.pump();
    expect(_opacity(tester, 5), 1);
    tester.view.physicalSize = const Size(800, 480);
    await tester.pump();
    expect(_opacity(tester, 5), 1);
    ready.value = false;
    await tester.pump();
    ready.value = true;
    await tester.pump();
    expect(_opacity(tester, 5), 1);
  });

  testWidgets('returning from another route keeps the completed entrance', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_host(navigator: navigator));
    await tester.pumpAndSettle();
    navigator.currentState!.push<void>(
      MaterialPageRoute(builder: (_) => const Scaffold(body: Text('detail'))),
    );
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(_opacity(tester, 0), 1);
    expect(_opacity(tester, 5), 1);
  });

  testWidgets('D-pad and activation work before the last entrance begins', (
    tester,
  ) async {
    var activations = 0;
    await tester.pumpWidget(_host(onActivate: (_) => activations++));
    expect(_opacity(tester, 5), lessThan(1));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(_opacity(tester, 5), 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
    await tester.pump();
    expect(activations, 1);
  });

  testWidgets('touch activates immediately and settles every Home item', (
    tester,
  ) async {
    var activated = -1;
    await tester.pumpWidget(_host(onActivate: (index) => activated = index));
    await tester.tap(find.text('action-5-0'));
    await tester.pump();
    expect(activated, 5);
    expect(_opacity(tester, 0), 1);
    expect(_opacity(tester, 5), 1);
  });

  testWidgets('first-frame painted lower edge remains tappable', (
    tester,
  ) async {
    var activated = -1;
    await tester.pumpWidget(_host(onActivate: (index) => activated = index));
    final control = find.descendant(
      of: find.byKey(const ValueKey('entrance-5')),
      matching: find.byType(HandheldFocusDecorator),
    );
    final rect = tester.getRect(control);
    await tester.tapAt(Offset(rect.center.dx, rect.bottom - 1));
    await tester.pump();
    expect(activated, 5);
    expect(_opacity(tester, 5), 1);
  });

  testWidgets('system and App reduced motion settle without replay', (
    tester,
  ) async {
    final reduced = ValueNotifier(false);
    addTearDown(reduced.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<bool>(
        valueListenable: reduced,
        builder: (context, value, _) => _host(reduced: value),
      ),
    );
    await tester.pump(const Duration(milliseconds: 40));
    reduced.value = true;
    await tester.pump();
    expect(_opacity(tester, 5), 1);
    reduced.value = false;
    await tester.pump();
    expect(_opacity(tester, 5), 1);

    await tester.pumpWidget(const SizedBox());
    await motionPreferences.setListAnimationsEnabled(false);
    await tester.pumpWidget(_host());
    expect(_opacity(tester, 5), 1);
    await motionPreferences.setListAnimationsEnabled(true);
    await tester.pump();
    expect(_opacity(tester, 5), 1);
  });

  testWidgets('App motion toggle interrupts an active entrance once', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(_opacity(tester, 5), lessThan(1));
    await motionPreferences.setListAnimationsEnabled(false);
    await tester.pump();
    expect(_opacity(tester, 5), 1);
    await motionPreferences.setListAnimationsEnabled(true);
    await tester.pump(const Duration(milliseconds: 60));
    expect(_opacity(tester, 5), 1);
  });

  testWidgets('backgrounding settles an active entrance', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 40));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(_opacity(tester, 5), 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(_opacity(tester, 5), 1);
  });
}

double _opacity(WidgetTester tester, int index) => tester
    .widget<Opacity>(
      find
          .descendant(
            of: find.byKey(ValueKey('entrance-$index')),
            matching: find.byType(Opacity),
          )
          .first,
    )
    .opacity;

Widget _host({
  AppVisualStyle style = AppVisualStyle.classic,
  bool ready = true,
  bool reduced = false,
  int revision = 0,
  ValueChanged<int>? onActivate,
  GlobalKey<NavigatorState>? navigator,
}) => MaterialApp(
  theme: buildTitoTheme(style),
  navigatorKey: navigator,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
    child: HandheldInputShell(child: child!),
  ),
  home: Scaffold(
    body: HomeEntrance(
      ready: ready,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < 6; index++)
              HomeEntranceItem(
                key: ValueKey('entrance-$index'),
                index: index,
                child: HandheldFocusDecorator(
                  onActivate: () => onActivate?.call(index),
                  child: SizedBox(
                    width: 180,
                    height: 48,
                    child: TextButton(
                      onPressed: () => onActivate?.call(index),
                      child: Text('action-$index-$revision'),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  ),
);
