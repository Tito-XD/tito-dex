import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/features/dex/dex_repository.dart';
import 'package:titodex/features/dex/dex_offline_service.dart';
import 'package:titodex/features/save/save_types.dart';
import 'package:titodex/models/journey.dart';
import 'package:titodex/pages/dex_page.dart';
import 'package:titodex/pages/pokemon_detail_page.dart';
import 'package:titodex/pages/settings_page.dart';
import 'package:titodex/theme/app_visual_style.dart';
import 'package:titodex/theme/tito_colors.dart';
import 'package:titodex/theme/tito_theme.dart';
import 'package:titodex/widgets/pokemon_card.dart';
import 'package:titodex/widgets/retro_forms.dart';
import 'package:titodex/widgets/tito_page_container.dart';
import 'package:titodex/widgets/type_badge.dart';

const _summary = PokemonSummary(
  id: 1,
  nameEn: 'Bulbasaur',
  nameZh: '妙蛙种子',
  types: ['grass', 'poison'],
);

const _immediateDetail = PokemonDetail(
  summary: _summary,
  forms: [
    PokemonFormDetail(
      key: 'audit-form',
      pokemonId: 1,
      nameEn: 'bulbasaur',
      nameZh: '妙蛙种子',
      kind: PokemonFormKind.form,
      isDefault: true,
      isBattleOnly: false,
      isMega: false,
      isCosmetic: false,
      types: ['grass', 'poison'],
      heightDm: 7,
      weightHg: 69,
      availableVersionGroups: ['scarlet-violet'],
    ),
  ],
  genusZh: '种子宝可梦',
  heightDm: 7,
  weightHg: 69,
  weaknesses: [],
  resistances: [],
  immunities: [],
  stabSuperEffective: [],
  evolutionChain: null,
  moveSet: PokemonMoveSet(
    levelUp: [
      PokemonMove(
        move: CachedMove(
          id: 33,
          nameEn: 'tackle',
          nameZh: '撞击',
          type: 'normal',
          category: 'physical',
        ),
        method: 'level-up',
        level: 1,
      ),
    ],
    machine: [
      PokemonMove(
        move: CachedMove(
          id: 182,
          nameEn: 'protect',
          nameZh: '守住',
          type: 'normal',
          category: 'status',
        ),
        method: 'machine',
      ),
    ],
  ),
);

const _captureFont = String.fromEnvironment('UI_AUDIT_CJK_FONT');
const _boundary = ValueKey('ui-audit-boundary');

double _contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return (x > y ? x + .05 : y + .05) / (x > y ? y + .05 : x + .05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final documents = Directory('build/ui-audit-fixture').absolute;
    final cache = Directory('${documents.path}/dex_offline')
      ..createSync(recursive: true);
    File('${cache.path}/manifest.json').writeAsStringSync(
      jsonEncode(
        const DexCacheManifest(
          version: DexCacheManifest.currentVersion,
          complete: true,
          preferOffline: true,
          pokemonCount: 18,
        ).toJson(),
      ),
    );
    const names = [
      '妙蛙种子',
      '妙蛙草',
      '妙蛙花',
      '小火龙',
      '火恐龙',
      '喷火龙',
      '杰尼龟',
      '卡咪龟',
      '水箭龟',
      '绿毛虫',
      '铁甲蛹',
      '巴大蝶',
      '独角虫',
      '铁壳蛹',
      '大针蜂',
      '波波',
      '比比鸟',
      '大比鸟',
    ];
    File('${cache.path}/summaries.json').writeAsStringSync(
      jsonEncode([
        for (var id = 1; id <= 18; id++)
          PokemonSummary(
            id: id,
            nameEn: 'fixture-$id',
            nameZh: names[id - 1],
            types: const ['grass'],
          ).toJson(),
      ]),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => documents.path,
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          ),
    );
    expect(
      (await dexRepository.getAllSummaries().timeout(
        const Duration(seconds: 10),
      )).length,
      18,
    );
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() async {
    await appVisualStyle.setStyle(AppVisualStyle.classic);
  });
  testWidgets(
    'caught card and toggles expose one labelled action per control',
    (tester) async {
      final semantics = tester.ensureSemantics();
      for (final style in AppVisualStyle.values) {
        await appVisualStyle.setStyle(style);
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTitoTheme(style),
            home: Scaffold(
              body: Column(
                children: [
                  SizedBox(
                    width: 140,
                    height: 170,
                    child: PokemonMiniCard(
                      summary: _summary,
                      status: DexEncounterStatus.caught,
                      onTap: () => taps++,
                    ),
                  ),
                  StickerPillToggle(
                    label: '测试开关',
                    value: true,
                    onChanged: (_) => taps++,
                  ),
                  const EvolutionChainVerticalView(
                    root: EvolutionNode(
                      id: 2,
                      nameEn: 'ivysaur',
                      nameZh: '妙蛙草',
                    ),
                    highlightId: 2,
                  ),
                ],
              ),
            ),
          ),
        );
        await _settle(tester);
        final card = tester.getSemantics(find.bySemanticsLabel('#1 妙蛙种子'));
        expect(
          card.getSemanticsData().hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
        expect(card.getSemanticsData().flagsCollection.isButton, isTrue);
        expect(card.getSemanticsData().value, '已捕获');
        final evolution = tester.getSemantics(find.bySemanticsLabel('#2 妙蛙草'));
        expect(evolution.getSemanticsData().flagsCollection.isButton, isTrue);
        expect(
          evolution.getSemanticsData().hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
        final toggle = tester.getSemantics(find.bySemanticsLabel('测试开关'));
        expect(toggle.getSemanticsData().flagsCollection.isButton, isTrue);
        expect(
          toggle.getSemanticsData().flagsCollection.isToggled ==
              ui.Tristate.isTrue,
          isTrue,
        );
        final icon = tester.widget<Icon>(
          find.byIcon(Icons.check_circle_rounded),
        );
        expect(_contrast(icon.color!, TitoColors.mint), greaterThan(3));
        if (style == AppVisualStyle.solidPlastic) {
          final badge = tester.widget<Container>(
            find
                .descendant(
                  of: find.byType(TitoTypeBadge).first,
                  matching: find.byType(Container),
                )
                .first,
          );
          final edge =
              ((badge.decoration as BoxDecoration).border! as Border).top;
          expect(edge.color, Colors.white.withValues(alpha: .78));
          expect(edge.width, TitoBorders.glass);
        }
        await tester.tap(find.bySemanticsLabel('#1 妙蛙种子'));
        await tester.tap(find.bySemanticsLabel('测试开关'));
        await _settle(tester);
        expect(taps, 2);
        expect(tester.takeException(), isNull);
      }
      semantics.dispose();
    },
  );

  test(
    'status backing keeps cream text readable at both gradient endpoints',
    () {
      for (final background in [
        TitoColors.shellGradientTop,
        TitoColors.shellGradientBottom,
        TitoColors.glassBackgroundTop,
        TitoColors.glassBackgroundBottom,
      ]) {
        final backing = Color.alphaBlend(
          TitoColors.deepBlue.withValues(alpha: .88),
          background,
        );
        expect(_contrast(TitoColors.card, backing), greaterThanOrEqualTo(4.5));
      }
    },
  );

  testWidgets(
    'three themes render Dex detail tabs and Settings; capture on request',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      if (_captureFont.isNotEmpty) {
        final cjk = FontLoader('Noto Sans CJK SC')
          ..addFont(
            Future.value(
              ByteData.sublistView(File(_captureFont).readAsBytesSync()),
            ),
          );
        await cjk.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
        final nunito = FontLoader('Nunito');
        for (final weight in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
          nunito.addFont(rootBundle.load('assets/fonts/Nunito-$weight.ttf'));
        }
        await nunito.load();
      }
      for (final style in AppVisualStyle.values) {
        await appVisualStyle.setStyle(style);
        final router = GoRouter(
          initialLocation: '/dex',
          routes: [
            GoRoute(
              path: '/dex',
              builder: (_, _) => TitoPageContainer(
                child: DexPage(
                  journey: CurrentJourney.mock().copyWith(
                    saveDexCaughtIds: const [1, 4],
                    saveDexSeenIds: const [1, 4, 7],
                    manualDexCaughtIds: const [1, 4],
                    manualDexSeenIds: const [1, 4, 7],
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/detail',
              builder: (_, _) => const TitoPageContainer(
                child: PokemonDetailPage(
                  pokemonId: 1,
                  initialDetail: _immediateDetail,
                  initialFormKey: 'audit-form',
                ),
              ),
            ),
            GoRoute(
              path: '/settings',
              builder: (_, _) =>
                  TitoPageContainer(child: _settings(_DownloadService())),
            ),
            GoRoute(
              path: '/settings/appearance',
              builder: (_, _) => TitoPageContainer(
                child: _settings(
                  _DownloadService(),
                  section: SettingsSection.appearance,
                ),
              ),
            ),
          ],
        );
        await tester.pumpWidget(
          MaterialApp.router(
            theme: _previewTheme(style),
            routerConfig: router,
            builder: (context, child) =>
                RepaintBoundary(key: _boundary, child: child!),
          ),
        );
        for (var i = 0; i < 12; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          find.byType(PokemonMiniCard),
          findsWidgets,
          reason: tester
              .widgetList<Text>(find.byType(Text))
              .map((t) => t.data)
              .join(' | '),
        );
        final searchInk = find
            .ancestor(of: find.text('筛选'), matching: find.byType(InkWell))
            .first;
        expect(tester.getSize(searchInk).height, greaterThanOrEqualTo(44));
        await _capture(tester, '${style.name}-dex');
        router.go('/detail');
        await _settle(tester);
        for (var index = 0; index < 4; index++) {
          final tab = find.byKey(ValueKey('detail-tab-surface-$index'));
          expect(tester.getSize(tab).height, greaterThanOrEqualTo(44));
          expect(tester.getSize(tab).width, greaterThanOrEqualTo(44));
          await tester.tap(tab);
          await _settle(tester);
          if (index == 1) {
            final status = find.text('· 当前版本不可用');
            expect(status, findsOneWidget);
            final text = tester.widget<Text>(status);
            final backing = tester.widget<Container>(
              find.ancestor(of: status, matching: find.byType(Container)).first,
            );
            final fill = (backing.decoration! as BoxDecoration).color;
            final background = fill == null
                ? TitoColors.flatSurface
                : Color.alphaBlend(fill, TitoColors.shellGradientBottom);
            expect(
              _contrast(text.style!.color!, background),
              greaterThanOrEqualTo(4.5),
            );
          }
          await _capture(tester, '${style.name}-detail-$index');
        }
        // The fixture has level-up and machine moves, so both filters render.
        for (final label in ['等级', '学习器']) {
          final filter = find
              .ancestor(
                of: find.text(label).first,
                matching: find.byType(InkWell),
              )
              .first;
          expect(tester.getSize(filter).height, greaterThanOrEqualTo(44));
        }
        router.go('/settings');
        await _settle(tester);
        await _capture(tester, '${style.name}-settings');
        router.go('/settings/appearance');
        await _settle(tester);
        await _capture(tester, '${style.name}-appearance');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        router.dispose();
      }
    },
  );
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (_captureFont.isEmpty) return;
  await tester.runAsync(() async {
    final image = await tester
        .renderObject<RenderRepaintBoundary>(find.byKey(_boundary))
        .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/ui-audit').createSync(recursive: true);
    File(
      'build/ui-audit/$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

SettingsPage _settings(
  DexOfflineService service, {
  SettingsSection section = SettingsSection.overview,
}) => SettingsPage(
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
  offlineService: service,
  section: section,
);

class _DownloadService extends DexOfflineService {
  bool downloading = false;
  bool complete = false;
  int progressReads = 0;

  void start() => downloading = true;

  void finish() {
    downloading = false;
    complete = true;
  }

  @override
  bool get isDownloading => downloading;

  @override
  DexCacheProgress? get progress {
    progressReads += 1;
    return downloading
        ? const DexCacheProgress(phase: 'cdn_download', current: 1, total: 2)
        : null;
  }

  @override
  Future<DexCacheStatus> getStatus() async => DexCacheStatus(
    manifest: DexCacheManifest(
      version: DexCacheManifest.currentVersion,
      complete: complete,
      preferOffline: true,
      pokemonCount: complete ? 1025 : 0,
    ),
    sizeBytes: 0,
    isDownloading: downloading,
    progress: progress,
  );

  @override
  void requestCancelDownload() => downloading = false;
}

Future<void> _settle(WidgetTester tester) async {
  // File-backed reference reads run outside the fake widget clock.
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

ThemeData _previewTheme(AppVisualStyle style) {
  final theme = buildTitoTheme(style);
  if (_captureFont.isEmpty) return theme;
  // Widget-test engine has no OS CJK fallback. Only the capture host adds it.
  const fallback = ['Noto Sans CJK SC'];
  ButtonStyle? fontFallback(ButtonStyle? style) => style?.copyWith(
    textStyle: WidgetStateProperty.resolveWith(
      (states) => style.textStyle
          ?.resolve(states)
          ?.copyWith(fontFamilyFallback: fallback),
    ),
  );
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamilyFallback: fallback),
    primaryTextTheme: theme.primaryTextTheme.apply(
      fontFamilyFallback: fallback,
    ),
    listTileTheme: theme.listTileTheme.copyWith(
      titleTextStyle: theme.listTileTheme.titleTextStyle?.copyWith(
        fontFamilyFallback: fallback,
      ),
      subtitleTextStyle: theme.listTileTheme.subtitleTextStyle?.copyWith(
        fontFamilyFallback: fallback,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: fontFallback(theme.segmentedButtonTheme.style),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: fontFallback(theme.filledButtonTheme.style),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: fontFallback(theme.outlinedButtonTheme.style),
    ),
    textButtonTheme: TextButtonThemeData(
      style: fontFallback(theme.textButtonTheme.style),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: fontFallback(theme.elevatedButtonTheme.style),
    ),
  );
}
