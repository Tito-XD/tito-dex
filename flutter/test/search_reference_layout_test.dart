import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/journey/ask_titodex_settings.dart';
import 'package:titodex/l10n/app_locale.dart';
import 'package:titodex/l10n/app_zh.dart';
import 'package:titodex/pages/search_reference_page.dart';
import 'package:titodex/theme/app_visual_style.dart';
import 'package:titodex/theme/tito_theme.dart';
import 'package:titodex/widgets/handheld_input.dart';
import 'package:titodex/widgets/tito_page_container.dart';

const _font = String.fromEnvironment('UI_AUDIT_CJK_FONT');
const _screenshots = bool.fromEnvironment('APP_LAYOUT_SCREENSHOTS');
const _boundary = ValueKey('reference-audit-boundary');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await askTitoDexSettings.setExtensionEnabled(false);
    AppLocale.instance.debugOverride(AppUiLanguage.zh);
  });
  tearDown(() async {
    AppLocale.instance.debugOverride(AppUiLanguage.zh);
    await appVisualStyle.setStyle(AppVisualStyle.classic);
  });

  for (final style in AppVisualStyle.values) {
    for (final scenario in [
      (size: const Size(390, 844), scale: 1.0, columns: 2),
      (size: const Size(480, 480), scale: 1.0, columns: 3),
      (size: const Size(800, 480), scale: 1.0, columns: 4),
      (size: const Size(390, 844), scale: 1.8, columns: 2),
      (size: const Size(800, 480), scale: 2.0, columns: 2),
    ]) {
      testWidgets(
        '$style reference grid at ${scenario.size} scale ${scenario.scale}',
        (tester) async {
          await appVisualStyle.setStyle(style);
          // Large text also covers the longer English reference labels.
          AppLocale.instance.debugOverride(
            scenario.scale > 1 ? AppUiLanguage.en : AppUiLanguage.zh,
          );
          final router = _router();
          addTearDown(router.dispose);
          tester.view.physicalSize = scenario.size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(_app(router, style, scenario.scale));
          await tester.pumpAndSettle();
          final gridFinder = find.byKey(const Key('reference-catalog-grid'));
          final grid = tester.widget<GridView>(gridFinder);
          final delegate =
              grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
          expect(delegate.crossAxisCount, scenario.columns);
          expect(grid.physics, isA<NeverScrollableScrollPhysics>());
          final gridRect = tester.getRect(gridFinder);
          for (var index = 0; index < 11; index++) {
            final card = find.byKey(ValueKey('reference-entry-$index'));
            expect(card, findsOneWidget);
            final rect = tester.getRect(card);
            expect(rect.left, greaterThanOrEqualTo(gridRect.left - .01));
            expect(rect.right, lessThanOrEqualTo(gridRect.right + .01));
            final label = find.descendant(
              of: card,
              matching: find.byType(Text),
            );
            final paragraph = tester.renderObject<RenderParagraph>(label);
            expect(paragraph.didExceedMaxLines, isFalse);
            final textRect = tester.getRect(label);
            expect(textRect.top, greaterThanOrEqualTo(rect.top));
            expect(textRect.bottom, lessThanOrEqualTo(rect.bottom));
          }
          expect(tester.takeException(), isNull);
          if (scenario.scale == 1 && scenario.size.width != 480) {
            await _capture(
              tester,
              'reference-${style.name}-${scenario.size.width.toInt()}x${scenario.size.height.toInt()}',
            );
          }
          await tester.ensureVisible(find.text(AppZh.quizTitle));
          await tester.pumpAndSettle();
          await tester.tap(find.text(AppZh.quizTitle));
          await tester.pumpAndSettle();
          expect(find.text('opened-quiz'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('reference entries retain keyboard traversal and activation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router, AppVisualStyle.classic, 1));
    await tester.pumpAndSettle();
    FocusNode nodeFor(int index) => Focus.of(
      tester.element(
        find.descendant(
          of: find.byKey(ValueKey('reference-entry-$index')),
          matching: find.byType(HandheldPressed),
        ),
      ),
    );
    nodeFor(0).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(nodeFor(1).hasPrimaryFocus, isTrue);
    for (var index = 2; index < 11; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(nodeFor(index).hasPrimaryFocus, isTrue);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
    await tester.pumpAndSettle();
    expect(find.text('opened-quiz'), findsOneWidget);
  });
}

GoRouter _router() => GoRouter(
  initialLocation: '/search/reference',
  routes: [
    GoRoute(
      path: '/search/reference',
      builder: (_, _) => const TitoPageContainer(child: SearchReferencePage()),
    ),
    GoRoute(
      path: '/dex/quiz',
      builder: (_, _) => const Scaffold(body: Text('opened-quiz')),
    ),
    GoRoute(
      path: '/settings',
      builder: (_, _) => const Scaffold(body: Text('settings')),
    ),
  ],
);

Widget _app(GoRouter router, AppVisualStyle style, double scale) {
  var theme = buildTitoTheme(style);
  if (_font.isNotEmpty) {
    theme = theme.copyWith(
      textTheme: theme.textTheme.apply(
        fontFamilyFallback: const ['Noto Sans CJK SC'],
      ),
      primaryTextTheme: theme.primaryTextTheme.apply(
        fontFamilyFallback: const ['Noto Sans CJK SC'],
      ),
    );
  }
  return RepaintBoundary(
    key: _boundary,
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: theme,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: HandheldInputShell(child: child!),
      ),
    ),
  );
}

Future<void> _loadFonts() async {
  if (_font.isEmpty) return;
  await (FontLoader('Noto Sans CJK SC')..addFont(
        Future.value(ByteData.sublistView(File(_font).readAsBytesSync())),
      ))
      .load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  final nunito = FontLoader('Nunito');
  for (final weight in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
    nunito.addFont(rootBundle.load('assets/fonts/Nunito-$weight.ttf'));
  }
  await nunito.load();
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!_screenshots) return;
  await tester.runAsync(() async {
    final image = await tester
        .renderObject<RenderRepaintBoundary>(find.byKey(_boundary))
        .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/app-layout-audit').createSync(recursive: true);
    File(
      'build/app-layout-audit/$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
