import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/dex/dex_catalog.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/features/dex/dex_repository.dart';
import 'package:titodex/features/journey/ask_titodex_settings.dart';
import 'package:titodex/l10n/app_locale.dart';
import 'package:titodex/l10n/app_zh.dart';
import 'package:titodex/models/journey.dart';
import 'package:titodex/pages/search_page.dart';
import 'package:titodex/theme/app_visual_style.dart';
import 'package:titodex/theme/tito_theme.dart';
import 'package:titodex/widgets/tito_page_container.dart';

const recentKey = 'search_page_recent_queries_v1';
const history = [
  'bulbasaur',
  '小火龙',
  'charmander',
  '杰尼龟',
  'chespin',
  '熊猫',
  '火暴兽',
  '帝牙',
  '妙蛙草',
  '水箭龟',
];
final recent = find.byKey(const ValueKey('search-recent-section'));
final suggestions = find.byKey(const ValueKey('search-suggestion-section'));
final field = find.byKey(const ValueKey('pokemon-search-field'));

Future<void> host(
  WidgetTester tester, {
  AppVisualStyle style = AppVisualStyle.classic,
  Size size = const Size(390, 844),
  double scale = 1,
  AppUiLanguage language = AppUiLanguage.zh,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  AppLocale.instance.debugOverride(language);
  await appVisualStyle.setStyle(style);
  await askTitoDexSettings.enableWithConsent();
  final router = GoRouter(
    initialLocation: '/search',
    routes: [
      GoRoute(
        path: '/search',
        builder: (_, _) => TitoPageContainer(
          child: SearchPage(
            journey: CurrentJourney.mock(),
            assistantDisplayMode: SearchAssistantDisplayMode.prominent,
            onAskTitoDex: () {},
          ),
        ),
      ),
      GoRoute(
        path: '/search/reference',
        builder: (_, _) => const Scaffold(body: Text('reference destination')),
      ),
      GoRoute(
        path: '/search/companion',
        builder: (_, _) => const Scaffold(body: Text('battle destination')),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const Scaffold(body: Text('settings destination')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: buildTitoTheme(style),
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openHelp(WidgetTester tester) async {
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
}

void expectSingleRow(WidgetTester tester, Finder section) {
  final chips = find.descendant(of: section, matching: find.byType(ActionChip));
  final tops = tester.getTopLeft(chips.first).dy;
  for (var i = 0; i < chips.evaluate().length; i++) {
    expect(tester.getTopLeft(chips.at(i)).dy, closeTo(tops, .01));
  }
  final scroll = find.descendant(
    of: section,
    matching: find.byType(SingleChildScrollView),
  );
  expect(
    tester.widget<SingleChildScrollView>(scroll).scrollDirection,
    Axis.horizontal,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final documents = Directory('build/search-page-fixture').absolute;
    final cache = Directory('${documents.path}/dex_offline')
      ..createSync(recursive: true);
    File('${cache.path}/manifest.json').writeAsStringSync(
      jsonEncode(
        const DexCacheManifest(
          version: DexCacheManifest.currentVersion,
          complete: true,
          preferOffline: true,
          pokemonCount: 3,
        ).toJson(),
      ),
    );
    const entries = [
      PokemonSummary(
        id: 1,
        nameEn: 'bulbasaur',
        nameZh: '妙蛙种子',
        types: ['grass', 'poison'],
      ),
      PokemonSummary(
        id: 4,
        nameEn: 'charmander',
        nameZh: '小火龙',
        types: ['fire'],
      ),
      PokemonSummary(
        id: 150,
        nameEn: 'mewtwo',
        nameZh: '超梦',
        types: ['psychic'],
        tags: ['legendary'],
      ),
    ];
    File('${cache.path}/${DexCatalog.filename}').writeAsStringSync(
      jsonEncode({'summaries': entries.map((e) => e.toJson()).toList()}),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => documents.path,
        );
    await dexRepository.getAllSummaries();
  });
  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({recentKey: history});
    askTitoDexSettings.resetForTest();
  });
  tearDown(() async {
    AppLocale.instance.debugOverride(AppUiLanguage.zh);
    await appVisualStyle.setStyle(AppVisualStyle.classic);
    askTitoDexSettings.resetForTest();
  });

  for (final style in AppVisualStyle.values) {
    for (final config in [
      (AppUiLanguage.zh, const Size(360, 360), 1.0),
      (AppUiLanguage.zh, const Size(390, 844), 2.0),
      (AppUiLanguage.en, const Size(360, 360), 2.0),
    ]) {
      testWidgets(
        '${style.name} ${config.$1.name} ${config.$2} scale ${config.$3}: equal entry heights and on-demand single rows',
        (tester) async {
          await host(
            tester,
            style: style,
            language: config.$1,
            size: config.$2,
            scale: config.$3,
          );
          expect(find.text(AppZh.extensionSearchAskHint), findsOneWidget);
          if (config.$1 == AppUiLanguage.zh) {
            expect(AppZh.extensionSearchAskHint, '基于 Exa 搜索和 AI 整理的游戏助手（测试中）');
          }
          expect(recent, findsNothing);
          expect(suggestions, findsNothing);
          expect(find.text(AppZh.searchEmptyHint), findsNothing);
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('search-reference-entry')),
            140,
            scrollable: find.byType(Scrollable).first,
          );
          expect(
            tester
                .getSize(find.byKey(const ValueKey('search-reference-entry')))
                .height,
            tester
                .getSize(find.byKey(const ValueKey('search-battle-entry')))
                .height,
          );
          await openHelp(tester);
          expect(recent, findsOneWidget);
          expect(suggestions, findsOneWidget);
          expectSingleRow(tester, recent);
          expectSingleRow(tester, suggestions);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'recent queries scroll, expand, collapse, search, and persist explicitly',
    (tester) async {
      await host(tester);
      await openHelp(tester);
      final row = find.descendant(
        of: recent,
        matching: find.byType(SingleChildScrollView),
      );
      await tester.ensureVisible(row);
      await tester.drag(row, const Offset(-800, 0));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SingleChildScrollView>(row).controller!.offset,
        greaterThan(0),
      );
      final more = find.descendant(
        of: recent,
        matching: find.text(AppZh.searchQueriesExpand),
      );
      await tester.ensureVisible(more);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(
        recent,
        findsOneWidget,
        reason: 'Moving focus to an expand button keeps the dropdown open',
      );
      final chips = find.descendant(
        of: recent,
        matching: find.byType(ActionChip),
      );
      expect(
        tester.getTopLeft(chips.last).dy,
        greaterThan(tester.getTopLeft(chips.first).dy),
      );
      final less = find.descendant(
        of: recent,
        matching: find.text(AppZh.searchQueriesCollapse),
      );
      await tester.tap(less);
      await tester.pumpAndSettle();
      expectSingleRow(tester, recent);
      // Reopen expanded to access a previously hidden shortcut.
      await tester.tap(more);
      await tester.pumpAndSettle();
      final shortcut = find.descendant(
        of: recent,
        matching: find.byKey(const ValueKey('search-query-小火龙')),
      );
      await tester.ensureVisible(shortcut);
      await tester.tap(shortcut);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, '小火龙');
      expect(recent, findsNothing);
      expect(suggestions, findsNothing);
      expect(find.byKey(const ValueKey('search-result-小火龙-4')), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getStringList(recentKey)!.first,
        '小火龙',
      );
      await tester.enterText(field, '');
      await tester.pumpAndSettle();
      expectSingleRow(tester, recent);
      expectSingleRow(tester, suggestions);
    },
  );

  testWidgets(
    'suggestions run a real search; clearing history removes only its section',
    (tester) async {
      await host(tester);
      await openHelp(tester);
      final clear = find.descendant(
        of: recent,
        matching: find.text(AppZh.searchRecentClear),
      );
      await tester.ensureVisible(clear);
      await tester.tap(clear);
      await tester.pumpAndSettle();
      expect(recent, findsNothing);
      expect(suggestions, findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getStringList(recentKey),
        isNull,
      );
      final more = find.descendant(
        of: suggestions,
        matching: find.text(AppZh.searchQueriesExpand),
      );
      await tester.ensureVisible(more);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: suggestions,
          matching: find.text(AppZh.searchQueriesCollapse),
        ),
        findsOneWidget,
      );
      final legendary = find.descendant(
        of: suggestions,
        matching: find.byKey(const ValueKey('search-query-传说')),
      );
      await tester.ensureVisible(legendary);
      await tester.tap(legendary);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('search-result-传说-150')),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(field).controller!.text, '传说');
    },
  );

  testWidgets('blur closes help and empty history has no placeholder card', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await host(tester);
    await openHelp(tester);
    expect(recent, findsNothing);
    expect(suggestions, findsOneWidget);
    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pumpAndSettle();
    expect(suggestions, findsNothing);
    expect(find.text(AppZh.searchEmptyHint), findsNothing);
    await openHelp(tester);
    expectSingleRow(tester, suggestions);
  });
}
