// Theme shots for team, search, journey, and sleep.
//
//   cd flutter
//   flutter test test/visual/theme_shots_tools_test.dart \
//     --dart-define=TITODEX_THEME_SHOTS=true
//
// PNGs land in flutter/build/theme_shots/tools2_<theme>_<screen>_480.png.
// Without the define the same pages still pump as a fast smoke test and
// nothing is written. Fixtures avoid save files and network.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/journey/journey_assistant.dart';
import 'package:titodex/models/journey.dart';
import 'package:titodex/pages/journey_page.dart';
import 'package:titodex/pages/search_page.dart';
import 'package:titodex/pages/sleep_tools_page.dart';
import 'package:titodex/pages/team_page.dart';
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

const _assistant = JourneyAssistantSnapshot(
  locationLabel: '满金市',
  locationMatched: true,
  nearbyUncaught: [],
  nearbyUncaughtCount: 0,
  exactVersion: 'soulsilver',
  exactVersionLabel: '魂银',
  pairedVersionLabel: '心金',
  versionEncounterGaps: [],
  versionEncounterGapCount: 0,
  evolutionOrTradeMissing: [],
  evolutionOrTradeMissingCount: 0,
  partyEvolutions: [],
);

CurrentJourney _shotJourney() {
  const party = [
    PartyMember(
      species: 'Quilava',
      nickname: '小炎',
      level: 24,
      types: ['fire'],
      currentHp: 68,
      maxHp: 72,
      experience: 13824,
    ),
    PartyMember(
      species: 'Riolu',
      level: 18,
      types: ['fighting'],
      currentHp: 42,
      maxHp: 48,
      experience: 5832,
    ),
  ];
  return CurrentJourney.mock().copyWith(party: party, partyUserOverride: false);
}

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

  Future<void> pumpPage(
    WidgetTester tester,
    AppVisualStyle style,
    Widget page,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => TitoPageContainer(child: page),
        ),
        GoRoute(path: '/settings', builder: (_, _) => const SizedBox()),
        GoRoute(path: '/dex', builder: (_, _) => const SizedBox()),
        GoRoute(path: '/dex/:id', builder: (_, _) => const SizedBox()),
        GoRoute(
          path: '/search/sleep-tools',
          builder: (_, _) => const SizedBox(),
        ),
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

  final screens = <String, Widget Function()>{
    'team': () => TeamPage(journey: _shotJourney(), onSaveJourney: (_) {}),
    'search': () => SearchPage(journey: _shotJourney()),
    'journey': () => JourneyPage(
      journey: _shotJourney(),
      assistantFuture: Future.value(_assistant),
    ),
    'sleep': () => const SleepToolsPage(),
  };

  for (final style in AppVisualStyle.values) {
    final theme = _themeNames[style]!;
    for (final entry in screens.entries) {
      testWidgets('$theme ${entry.key} tools shot', (tester) async {
        ThemeShotViewport.square.apply(tester);
        addTearDown(tester.view.reset);
        await useStyle(style);
        await pumpPage(tester, style, entry.value());
        expect(tester.takeException(), isNull);
        expect(find.textContaining('队伍').evaluate().isNotEmpty ||
            find.textContaining('搜索').evaluate().isNotEmpty ||
            find.textContaining('旅程').evaluate().isNotEmpty ||
            find.textContaining('睡眠').evaluate().isNotEmpty, isTrue);
        await captureThemeShot(
          tester,
          'tools2_${theme}_${entry.key}_480',
        );
      });
    }
  }
}
