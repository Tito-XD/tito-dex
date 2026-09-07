import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/dex/dex_browse_scope.dart';
import 'package:titodex/features/dex/dex_filter.dart';
import 'package:titodex/features/dex/dex_game_scope.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/features/dex/dex_progress.dart';
import 'package:titodex/features/dex/type_chart.dart';
import 'package:titodex/features/game/game_edition.dart';
import 'package:titodex/features/game/game_edition_repository.dart';
import 'package:titodex/pages/pokemon_detail_page.dart';
import 'package:titodex/widgets/dex_detail_controls.dart';
import 'package:titodex/widgets/dex_search_filter_sheet.dart';
import 'package:titodex/widgets/pokemon_detail_sections.dart';
import 'package:titodex/widgets/tito_pokeball_loading.dart';

Widget _app(Widget child) => MaterialApp(
  home: MediaQuery(
    data: const MediaQueryData(size: Size(360, 640), disableAnimations: true),
    child: Scaffold(body: child),
  ),
);

const _referenceMove = CachedMove(
  id: 33,
  nameEn: 'tackle',
  nameZh: '撞击',
  type: 'normal',
  category: 'physical',
);

void main() {
  testWidgets(
    'shimmer ball rotates without changing position or using colored artwork',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: TitoPokeballLoading())),
        ),
      );
      final ball = find.byType(TitoPokeballLoading);
      final rotation = find.descendant(
        of: ball,
        matching: find.byType(Transform),
      );
      final center = tester.getCenter(ball);
      final start = tester.widget<Transform>(rotation).transform.clone();
      await tester.pump(const Duration(milliseconds: 450));
      expect(tester.getCenter(ball), center);
      expect(tester.getSize(ball), const Size.square(28));
      expect(
        tester.widget<Transform>(rotation).transform.entry(0, 0),
        isNot(start.entry(0, 0)),
      );
      expect(
        tester.widget<Transform>(rotation).transform.getTranslation().length,
        0,
      );
      expect(
        find.descendant(of: ball, matching: find.byType(Image)),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'filter sheet keeps search and apply visible above a compact keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              viewInsets: const EdgeInsets.only(bottom: 220),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDexSearchFilterSheet(
                  context,
                  filter: DexFilter.empty,
                  scope: const DexBrowseScope.region(
                    DexRegionalPokedex.national,
                  ),
                  encounter: DexEncounterFilter.all,
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField).hitTestable(), findsOneWidget);
      expect(find.text('查看结果').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'detail merges App edition and offers only combined reference versions',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await gameEditionRepository.save(
        GameEdition.hgss.withFlavor('soulsilver'),
      );
      const detail = PokemonDetail(
        summary: PokemonSummary(
          id: 6,
          nameEn: 'charizard',
          nameZh: '喷火龙',
          types: ['fire', 'flying'],
        ),
        genusZh: '火焰宝可梦',
        heightDm: 17,
        weightHg: 905,
        weaknesses: [],
        resistances: [],
        immunities: [],
        stabSuperEffective: [],
        evolutionChain: null,
        moveSets: {
          'heartgold-soulsilver': PokemonMoveSet(
            levelUp: [
              PokemonMove(move: _referenceMove, method: 'level-up', level: 5),
            ],
          ),
          'scarlet-violet': PokemonMoveSet(
            levelUp: [
              PokemonMove(move: _referenceMove, method: 'level-up', level: 9),
            ],
          ),
        },
        flavorEntries: [
          FlavorTextEntry(
            version: 'soulsilver',
            text: '魂银描述',
            versionGroup: 'heartgold-soulsilver',
          ),
          FlavorTextEntry(
            version: 'scarlet',
            text: '朱的描述',
            versionGroup: 'scarlet-violet',
          ),
        ],
      );
      final router = GoRouter(
        initialLocation: '/dex/6',
        routes: [
          GoRoute(
            path: '/dex/:id',
            builder: (context, state) => const Scaffold(
              body: MediaQuery(
                data: MediaQueryData(disableAnimations: true),
                child: PokemonDetailPage(pokemonId: 6, initialDetail: detail),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Material>(
              find.byKey(const ValueKey('detail-tab-surface-0')),
            )
            .color,
        typeTileColor('fire'),
      );
      expect(
        (tester
                    .widget<Container>(
                      find.byKey(const ValueKey('detail-bottom-tabs')),
                    )
                    .decoration!
                as BoxDecoration)
            .color,
        Colors.transparent,
      );
      expect(
        tester
            .widget<DexDetailControls>(find.byType(DexDetailControls))
            .edition
            .selectedFlavor,
        isNull,
      );
      expect(
        tester
            .widget<FlavorTextCarousel>(find.byType(FlavorTextCarousel))
            .entries
            .single
            .text,
        '魂银描述',
      );
      final controls = tester.widget<DexDetailControls>(
        find.byType(DexDetailControls),
      );
      controls.onEditionChanged(
        gameEditionFromSlug('sv')!.withFlavor('scarlet'),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FlavorTextCarousel>(find.byType(FlavorTextCarousel))
            .entries
            .single
            .text,
        '朱的描述',
      );
      expect(gameEditionRepository.edition.selectedFlavor, 'soulsilver');
      expect(find.byTooltip('清除版本'), findsNothing);
      final versionPicker = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const ValueKey('detail-version-sv:')),
      );
      final versionDropdown = tester.widget<DropdownButton<String>>(
        find.descendant(
          of: find.byKey(const ValueKey('detail-version-sv:')),
          matching: find.byType(DropdownButton<String>),
        ),
      );
      expect(versionDropdown.items!.length, GameEdition.all.length + 1);
      expect(
        versionDropdown.items!.map((item) => item.value),
        isNot(contains('sv:scarlet')),
      );
      versionPicker.onChanged!('general:');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DexDetailControls>(find.byType(DexDetailControls))
            .edition
            .isGeneral,
        isTrue,
      );
      expect(
        tester
            .widget<FlavorTextCarousel>(find.byType(FlavorTextCarousel))
            .entries,
        hasLength(2),
      );
      await tester.tap(find.text('招式'));
      await tester.pumpAndSettle();
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.text('蛋'), findsNothing);
      expect(find.text('教学'), findsNothing);
      final movePanel = tester.widget<MoveCategoryPanel>(
        find.byType(MoveCategoryPanel),
      );
      expect(movePanel.moves.single.move.id, 33);
      expect(movePanel.moves.single.level, isNull);
      expect(movePanel.showLevel, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sheet combines search, region and attributes and applies one draft',
    (tester) async {
      DexSearchFilterSelection? result;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showDexSearchFilterSheet(
                  context,
                  filter: DexFilter.empty,
                  scope: const DexBrowseScope.region(
                    DexRegionalPokedex.national,
                  ),
                  encounter: DexEncounterFilter.all,
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '火 飞行');
      final scope = tester.widget<DropdownButtonFormField<DexRegionalPokedex>>(
        find.byKey(const ValueKey('地区图鉴-DexRegionalPokedex.national-0')),
      );
      scope.onChanged!(DexRegionalPokedex.johto);
      tester
          .widget<DropdownButtonFormField<int>>(
            find.byKey(const ValueKey('世代-0-0')),
          )
          .onChanged!(1);
      tester
          .widget<DropdownButtonFormField<bool>>(
            find.byKey(const ValueKey('浏览对象-false-0')),
          )
          .onChanged!(true);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(FilterChip, '火'));
      await tester.tap(find.widgetWithText(FilterChip, '火'));
      await tester.tap(find.text('查看结果'));
      await tester.pumpAndSettle();
      expect(result!.filter.query, '火 飞行');
      expect(result!.filter.typeSlugs, {'fire'});
      expect(result!.scope.region, DexRegionalPokedex.johto);
      expect(result!.filter.generation, 1);
      expect(result!.journeyOnly, isTrue);
      expect(result!.encounter, DexEncounterFilter.all);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dismissed sheet does not mutate applied filters', (
    tester,
  ) async {
    const filter = DexFilter(query: '伊布', typeSlugs: {'normal'});
    DexSearchFilterSelection? result;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDexSearchFilterSheet(
                context,
                filter: filter,
                scope: const DexBrowseScope.region(DexRegionalPokedex.johto),
                encounter: DexEncounterFilter.caught,
              );
            },
            child: const Text('打开'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清空条件'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(filter.query, '伊布');
    expect(filter.typeSlugs, {'normal'});
  });

  testWidgets(
    'compact detail controls and reduced-motion loader fit handheld',
    (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              DexDetailControls(
                forms: const [],
                selectedFormKey: null,
                edition: GameEdition.general,
                onFormChanged: (_) {},
                onEditionChanged: (_) {},
              ),
              const TitoPokeballLoading(),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
      final image = tester.widgetList<Image>(find.byType(Image));
      expect(
        image.any(
          (i) =>
              i.image is AssetImage &&
              (i.image as AssetImage).assetName ==
                  'assets/icons/titodex-app.png',
        ),
        isTrue,
      );
    },
  );
}
