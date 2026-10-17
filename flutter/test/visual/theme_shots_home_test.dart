// Home + Settings theme shots for the TitoSkin refresh.
//
//   cd flutter
//   flutter test test/visual/theme_shots_home_test.dart \
//     --dart-define=TITODEX_THEME_SHOTS=true
//
// PNGs land in flutter/build/theme_shots/home2_* and settings2_*.
// Without the define every case still pumps as a layout smoke test and
// captureThemeShot writes nothing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/save/save_types.dart';
import 'package:titodex/l10n/app_zh.dart';
import 'package:titodex/models/journey.dart';
import 'package:titodex/pages/home_page.dart';
import 'package:titodex/pages/settings_page.dart';
import 'package:titodex/theme/app_visual_style.dart';
import 'package:titodex/theme/retro_style.dart';
import 'package:titodex/theme/tito_theme.dart';
import 'package:titodex/widgets/tito_page_container.dart';

import 'theme_shot_harness.dart';

const _themeNames = {
  AppVisualStyle.classic: 'journal',
  AppVisualStyle.solidPlastic: 'plastic',
  AppVisualStyle.flatUi: 'flat',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    WidgetsApp.debugAllowBannerOverride = false;
    installThemeShotPlatformMocks();
    await loadThemeShotFonts();
  });

  Future<void> useStyle(AppVisualStyle style) async {
    SharedPreferences.setMockInitialValues({
      'style.visual': style.storageValue,
    });
    await appVisualStyle.setStyle(style);
    await retroStyle.setEnabled(true);
  }

  tearDown(() async {
    await appVisualStyle.setStyle(AppVisualStyle.classic);
    await retroStyle.setEnabled(true);
  });

  Future<void> pumpRouted(
    WidgetTester tester,
    AppVisualStyle style,
    String location,
    Widget page,
  ) async {
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(path: '/', builder: (_, _) => page),
        GoRoute(path: '/settings', builder: (_, _) => const SizedBox()),
        GoRoute(path: '/settings/appearance', builder: (_, _) => page),
        GoRoute(path: '/team', builder: (_, _) => const SizedBox()),
        GoRoute(path: '/dex', builder: (_, _) => const SizedBox()),
        GoRoute(path: '/search', builder: (_, _) => const SizedBox()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: themeShotBoundaryKey,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: buildTitoTheme(style),
          routerConfig: router,
        ),
      ),
    );
    await pumpThemeShotFrames(tester, frames: 6);
  }

  Widget homePage() => TitoPageContainer(
    child: HomePage(journey: CurrentJourney.mock(), onJourneyOpen: () {}),
  );

  Widget settingsPage() => TitoPageContainer(
    child: SettingsPage(
      journey: CurrentJourney.mock(),
      saveConfig: const SaveFileConfig(),
      emulatorChoice: null,
      onImportFixture: () {},
      onResetMock: () {},
      onSaveJourney: (_) {},
      onPickSaveFile: () {},
      onClearSaveFile: () {},
      onToggleAutoLoad: (_) {},
      onSyncNow: () {},
      onExportJourney: () {},
      onImportJourney: () {},
      onPickEmulator: () {},
      onClearEmulator: () {},
      section: SettingsSection.appearance,
    ),
  );

  for (final style in AppVisualStyle.values) {
    final theme = _themeNames[style]!;
    for (final viewport in ThemeShotViewport.all) {
      testWidgets('$theme home @${viewport.name}', (tester) async {
        viewport.apply(tester);
        addTearDown(tester.view.reset);
        await useStyle(style);
        await withThemeShotHostNoiseIgnored(() async {
          await pumpRouted(tester, style, '/', homePage());
          expect(find.text('训练家 Tito'), findsWidgets);
          expect(find.text(AppZh.currentParty), findsOneWidget);
          expect(find.text(AppZh.navTeam), findsOneWidget);
          expect(tester.takeException(), isNull);
          await captureThemeShot(tester, 'home2_${theme}_${viewport.name}');
          await tester.pumpWidget(const SizedBox());
        });
      });

      testWidgets('$theme settings @${viewport.name}', (tester) async {
        viewport.apply(tester);
        addTearDown(tester.view.reset);
        await useStyle(style);
        await withThemeShotHostNoiseIgnored(() async {
          await pumpRouted(
            tester,
            style,
            '/settings/appearance',
            settingsPage(),
          );
          expect(find.text('训练家手帐'), findsOneWidget);
          expect(find.text('纸贴纸 · 胶带 · 印章'), findsOneWidget);
          expect(find.text('固态塑料'), findsOneWidget);
          expect(find.text('半透外壳 · 压铸按键'), findsOneWidget);
          expect(find.text('扁平贴纸'), findsOneWidget);
          expect(find.text('色块 · 大字 · 干脆'), findsOneWidget);
          expect(
            find.byKey(const Key('settings-visual-theme')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await captureThemeShot(tester, 'settings2_${theme}_${viewport.name}');
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 50));
        });
      });
    }
  }

  testWidgets('switching theme shows an undo snackbar', (tester) async {
    await useStyle(AppVisualStyle.classic);
    await withThemeShotHostNoiseIgnored(() async {
      await pumpRouted(
        tester,
        AppVisualStyle.classic,
        '/settings/appearance',
        settingsPage(),
      );
      await tester.tap(find.byKey(const ValueKey('theme-style-solid_plastic')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(appVisualStyle.style, AppVisualStyle.solidPlastic);
      expect(find.text('已切换为固态塑料'), findsOneWidget);
      await tester.tap(find.widgetWithText(SnackBarAction, '撤销'));
      await tester.pump();
      expect(appVisualStyle.style, AppVisualStyle.classic);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}
