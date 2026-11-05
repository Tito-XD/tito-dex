import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/theme/app_visual_style.dart';
import 'package:titodex/theme/tito_theme.dart';
import 'package:titodex/widgets/handheld_input.dart';
import 'package:titodex/widgets/tito_snack_bar.dart';

Future<BuildContext> _pumpHost(
  WidgetTester tester, {
  bool disableAnimations = false,
}) async {
  late BuildContext pageContext;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTitoTheme(AppVisualStyle.classic),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations),
        child: TitoSnackHost(child: child!),
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            pageContext = context;
            return const SizedBox.expand();
          },
        ),
      ),
    ),
  );
  return pageContext;
}

double _opacity(WidgetTester tester, String text) {
  final fade = tester.widget<FadeTransition>(
    find
        .ancestor(of: find.text(text), matching: find.byType(FadeTransition))
        .first,
  );
  return fade.opacity.value;
}

void main() {
  testWidgets('toast fades in, offers a close button and animates out', (
    tester,
  ) async {
    final context = await _pumpHost(tester);
    showTitoSnackBar(context, '已保存');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final early = _opacity(tester, '已保存');
    expect(early, greaterThan(0));
    expect(early, lessThan(1), reason: 'entrance must be a transition');
    await tester.pumpAndSettle();
    expect(_opacity(tester, '已保存'), 1);

    final close = find.byKey(const ValueKey('tito-snack-close'));
    expect(close, findsOneWidget);
    expect(tester.getSize(close).height, greaterThanOrEqualTo(44));
    await tester.tap(close);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.text('已保存'), findsOneWidget, reason: 'exit is animated');
    expect(_opacity(tester, '已保存'), lessThan(1));
    await tester.pumpAndSettle();
    expect(find.text('已保存'), findsNothing);
  });

  testWidgets('toast dismisses itself after its duration', (tester) async {
    final context = await _pumpHost(tester);
    showTitoSnackBar(context, '稍后消失', duration: const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('稍后消失'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('稍后消失'), findsNothing);
  });

  testWidgets('action runs once and closes the toast', (tester) async {
    final context = await _pumpHost(tester);
    var taps = 0;
    showTitoSnackBar(
      context,
      '有新版本',
      actionLabel: '查看',
      onAction: () => taps++,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看'));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(find.text('有新版本'), findsNothing);
  });

  testWidgets('a newer message replaces the visible one', (tester) async {
    final context = await _pumpHost(tester);
    showTitoSnackBar(context, '正在启动');
    await tester.pumpAndSettle();
    showTitoSnackBar(context, '启动失败');
    await tester.pumpAndSettle();
    expect(find.text('正在启动'), findsNothing);
    expect(find.text('启动失败'), findsOneWidget);
  });

  testWidgets('reduced motion shows and hides without a transition', (
    tester,
  ) async {
    final context = await _pumpHost(tester, disableAnimations: true);
    showTitoSnackBar(context, '无动画');
    await tester.pump();
    await tester.pump();
    expect(_opacity(tester, '无动画'), 1);
    await tester.tap(find.byKey(const ValueKey('tito-snack-close')));
    await tester.pump();
    await tester.pump();
    expect(find.text('无动画'), findsNothing);
  });

  testWidgets('D-pad reaches the toast action and close, and holds it open', (
    tester,
  ) async {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic,
    );
    late BuildContext pageContext;
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTitoTheme(AppVisualStyle.classic),
        builder: (context, child) =>
            HandheldInputShell(child: TitoSnackHost(child: child!)),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              pageContext = context;
              return Center(
                child: TextButton(onPressed: () {}, child: const Text('页面')),
              );
            },
          ),
        ),
      ),
    );
    showTitoSnackBar(
      pageContext,
      '有新版本',
      duration: const Duration(seconds: 2),
      actionLabel: '查看',
      onAction: () => opened++,
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.context?.widget, isA<Focus>());
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    final close = find.byKey(const ValueKey('tito-snack-close'));
    final action = find.widgetWithText(TextButton, '查看');
    bool focusedIn(Finder finder) {
      final primary = FocusManager.instance.primaryFocus?.context;
      return primary != null &&
          find
              .descendant(of: finder, matching: find.byWidget(primary.widget))
              .evaluate()
              .isNotEmpty;
    }

    expect(focusedIn(action) || focusedIn(close), isTrue);
    // Focus on the toast suspends its timer.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('有新版本'), findsOneWidget);
    if (!focusedIn(action)) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
    }
    expect(focusedIn(action), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(find.text('有新版本'), findsNothing);
  });
}
