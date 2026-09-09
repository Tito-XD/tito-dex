import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/features/game/game_edition.dart';
import 'package:titodex/features/game/game_edition_repository.dart';
import 'package:titodex/l10n/app_zh.dart';
import 'package:titodex/pages/pokemon_detail_page.dart';
import 'package:titodex/theme/app_visual_style.dart';
import 'package:titodex/theme/tito_theme.dart';
import 'package:titodex/widgets/dex_detail_controls.dart';
import 'package:titodex/widgets/dex_detail_picker_sheet.dart';
import 'package:titodex/widgets/pokemon_detail_sections.dart';
import 'package:titodex/widgets/pokemon_obtain_sections.dart';

const _locations = {
  'heartgold': [
    ObtainLocationEntry(areaSlug: 'hg-test', areaLabelZh: '心金测试地点'),
  ],
  'soulsilver': [
    ObtainLocationEntry(areaSlug: 'ss-test', areaLabelZh: '魂银测试地点'),
  ],
  'sword': [
    ObtainLocationEntry(areaSlug: 'sword-test', areaLabelZh: '剑本篇测试地点'),
  ],
  'shield': [
    ObtainLocationEntry(areaSlug: 'shield-test', areaLabelZh: '盾本篇测试地点'),
  ],
  'the-isle-of-armor-sword': [
    ObtainLocationEntry(areaSlug: 'armor-test', areaLabelZh: '铠岛测试地点'),
  ],
  'the-crown-tundra-sword': [
    ObtainLocationEntry(areaSlug: 'crown-test', areaLabelZh: '雪原测试地点'),
  ],
};

const _forms = [
  PokemonFormDetail(
    obtainLocationsByVersion: _locations,
    key: 'charizard',
    pokemonId: 6,
    nameEn: 'charizard',
    nameZh: '喷火龙',
    kind: PokemonFormKind.form,
    isDefault: true,
    isBattleOnly: false,
    isMega: false,
    isCosmetic: false,
    types: ['fire', 'flying'],
    heightDm: 17,
    weightHg: 905,
  ),
  PokemonFormDetail(
    key: 'charizard-mega-x',
    pokemonId: 10034,
    nameEn: 'charizard-mega-x',
    nameZh: '超级喷火龙 X',
    kind: PokemonFormKind.mega,
    isDefault: false,
    isBattleOnly: true,
    isMega: true,
    isCosmetic: false,
    types: ['fire', 'dragon'],
    heightDm: 17,
    weightHg: 1105,
  ),
];

// Deliberately distinct fixture locations: this exercises scope selection,
// rather than asserting real Charizard encounter locations.
const _detail = PokemonDetail(
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
  forms: _forms,
  flavorEntries: [
    FlavorTextEntry(
      version: 'heartgold',
      text: '心金描述',
      versionGroup: 'heartgold-soulsilver',
    ),
    FlavorTextEntry(
      version: 'soulsilver',
      text: '魂银描述',
      versionGroup: 'heartgold-soulsilver',
    ),
    FlavorTextEntry(
      version: 'sword',
      text: '剑描述',
      versionGroup: 'sword-shield',
    ),
    FlavorTextEntry(
      version: 'shield',
      text: '盾描述',
      versionGroup: 'sword-shield',
    ),
  ],
  obtainLocationsByVersion: _locations,
);

Future<void> _tapChoice(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.scrollUntilVisible(
    finder,
    180,
    scrollable: find
        .descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Scrollable),
        )
        .last,
  );
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _page(WidgetTester tester, {String? version}) async {
  final router = GoRouter(
    initialLocation: '/dex/6',
    routes: [
      GoRoute(
        path: '/dex/:id',
        builder: (_, _) => Scaffold(
          body: PokemonDetailPage(
            pokemonId: 6,
            initialDetail: _detail,
            initialObtainVersion: version,
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(theme: buildTitoTheme(), routerConfig: router),
  );
  await tester.pumpAndSettle();
}

DexDetailControls _controls(WidgetTester tester) =>
    tester.widget<DexDetailControls>(find.byType(DexDetailControls));

void main() {
  test('DLC choices use bundled icons for the correct paired game', () {
    for (final slug in ['swsh', 'sv']) {
      final game = gameEditionFromSlug(slug)!;
      for (final version in dexDetailExactVersions(game)) {
        final choice = game.withFlavor(version);
        expect(File(choice.iconAsset!).existsSync(), isTrue, reason: version);
        final side = game.flavorVersions.singleWhere(
          (side) => version.endsWith(side),
        );
        expect(choice.iconAsset, game.withFlavor(side).iconAsset);
      }
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await appVisualStyle.setStyle(AppVisualStyle.classic);
    await gameEditionRepository.save(GameEdition.hgss.withFlavor('soulsilver'));
  });
  tearDown(() async => appVisualStyle.setStyle(AppVisualStyle.classic));

  for (final style in AppVisualStyle.values) {
    testWidgets(
      'form and version sheets select and cancel on a small screen in $style',
      (tester) async {
        tester.view.physicalSize = const Size(320, 480);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await appVisualStyle.setStyle(style);
        var formKey = _forms.first.key;
        var edition = GameEdition.hgss.withFlavor('soulsilver');
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTitoTheme(style),
            builder: (_, child) => MediaQuery(
              data: MediaQueryData(
                size: const Size(320, 480),
                textScaler: TextScaler.linear(1.4),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => Padding(
                  padding: const EdgeInsets.all(8),
                  child: DexDetailControls(
                    forms: _forms,
                    selectedFormKey: formKey,
                    speciesNameZh: '喷火龙',
                    edition: edition,
                    onFormChanged: (form) => setState(() => formKey = form.key),
                    onEditionChanged: (value) =>
                        setState(() => edition = value),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);
        await tester.tap(find.byKey(const ValueKey('detail-form-picker')));
        await tester.pumpAndSettle();
        expect(find.text('超级喷火龙 X'), findsOneWidget);
        // Two choices should not reserve a tall, mostly empty menu.
        expect(tester.getSize(find.byType(BottomSheet)).height, lessThan(320));
        await _tapChoice(tester, 'detail-form-choice-charizard-mega-x');
        expect(formKey, 'charizard-mega-x');
        expect(edition.selectedFlavor, 'soulsilver');
        expect(find.byType(BottomSheet), findsNothing);

        await tester.tap(find.byKey(const ValueKey('detail-version-picker')));
        await tester.pumpAndSettle();
        await _tapChoice(tester, 'detail-game-choice-hgss');
        await _tapChoice(tester, 'detail-version-choice-heartgold');
        expect(edition.selectedFlavor, 'heartgold');
        expect(formKey, 'charizard-mega-x');

        await tester.tap(find.byKey(const ValueKey('detail-version-picker')));
        await tester.pumpAndSettle();
        await _tapChoice(tester, 'detail-game-choice-sv');
        await tester.tap(find.byTooltip(AppZh.close));
        await tester.pumpAndSettle();
        expect(edition.selectedFlavor, 'heartgold');

        await tester.tap(find.byKey(const ValueKey('detail-version-picker')));
        await tester.pumpAndSettle();
        await _tapChoice(tester, 'detail-game-choice-hgss');
        await _tapChoice(tester, 'detail-version-choice-hgss:merged');
        expect(edition.selectedFlavor, isNull);
        expect(edition.slug, 'hgss');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('one form stays a non-interactive label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DexDetailControls(
            forms: [_forms.first],
            selectedFormKey: _forms.first.key,
            edition: GameEdition.general,
            onFormChanged: (_) => fail('single form must not change'),
            onEditionChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('detail-form-picker')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets(
    'live App edition and local form/edition changes keep exact scope',
    (tester) async {
      await _page(tester);
      expect(_controls(tester).edition.selectedFlavor, 'soulsilver');
      await gameEditionRepository.save(
        GameEdition.hgss.withFlavor('heartgold'),
      );
      await tester.pumpAndSettle();
      expect(_controls(tester).edition.selectedFlavor, 'heartgold');
      _controls(tester).onFormChanged(_forms.last);
      await tester.pumpAndSettle();
      expect(_controls(tester).edition.selectedFlavor, 'heartgold');
      _controls(tester).onFormChanged(_forms.first);
      _controls(
        tester,
      ).onEditionChanged(GameEdition.hgss.withFlavor('soulsilver'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('获取'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ObtainLocationsCard>(find.byType(ObtainLocationsCard))
            .locations
            .single
            .areaSlug,
        'ss-test',
      );
      await gameEditionRepository.save(gameEditionFromSlug('sv')!);
      await tester.pumpAndSettle();
      expect(_controls(tester).edition.selectedFlavor, 'soulsilver');
      expect(gameEditionRepository.edition.slug, 'sv');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'DLC links retain their exact side and include earlier owned areas',
    (tester) async {
      await _page(tester, version: 'the-crown-tundra-sword');
      expect(
        _controls(tester).edition.selectedFlavor,
        'the-crown-tundra-sword',
      );
      expect(
        tester
            .widget<FlavorTextCarousel>(find.byType(FlavorTextCarousel))
            .entries
            .single
            .text,
        '剑描述',
      );
      await tester.tap(find.text('获取'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ObtainLocationsCard>(find.byType(ObtainLocationsCard))
            .locations
            .map((entry) => entry.areaSlug),
        unorderedEquals(['sword-test', 'armor-test', 'crown-test']),
      );
      _controls(
        tester,
      ).onEditionChanged(gameEditionFromSlug('swsh')!.withFlavor('sword'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ObtainLocationsCard>(find.byType(ObtainLocationsCard))
            .locations
            .single
            .areaSlug,
        'sword-test',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a known exact link survives absent encounter data; unknown links fall back',
    (tester) async {
      await _page(tester, version: 'violet');
      expect(_controls(tester).edition.selectedFlavor, 'violet');
      await tester.pumpWidget(const SizedBox());
      await _page(tester, version: 'unknown-version');
      expect(_controls(tester).edition.selectedFlavor, 'soulsilver');
    },
  );

  testWidgets(
    'planning prompt opens the same exact picker and resolves into a plan',
    (tester) async {
      var edition = GameEdition.hgss;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTitoTheme(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                child: VersionChainPlanningCard(
                  chain: const EvolutionNode(
                    id: 6,
                    nameEn: 'charizard',
                    nameZh: '喷火龙',
                  ),
                  currentDetail: _detail,
                  versionGroup: edition.dataVersionGroupKey,
                  exactVersion: edition.selectedFlavor,
                  detailsFuture: Future.value({6: _detail}),
                  onPickVersion: () async {
                    final result = await showDexEditionPicker(
                      context,
                      selected: edition,
                      exactOnly: true,
                    );
                    if (result != null) setState(() => edition = result);
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(AppZh.dexChainPlanningPickVersion), findsOneWidget);
      await tester.tap(
        find.widgetWithText(OutlinedButton, AppZh.dexObtainExactVersion),
      );
      await tester.pumpAndSettle();
      await _tapChoice(tester, 'detail-version-choice-soulsilver');
      expect(find.text(AppZh.dexChainPlanningPickVersion), findsNothing);
      expect(find.text(AppZh.dexChainPlanningTitle), findsOneWidget);
      expect(edition.selectedFlavor, 'soulsilver');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'single releases select immediately; General clears the exact choice',
    (tester) async {
      GameEdition? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => result = await showDexEditionPicker(
                  context,
                  selected: GameEdition.hgss.withFlavor('soulsilver'),
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      await _tapChoice(tester, 'detail-game-choice-pt');
      expect(result?.selectedFlavor, 'platinum');
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      await _tapChoice(tester, 'detail-game-choice-general');
      expect(result?.isGeneral, isTrue);
      expect(result?.selectedFlavor, isNull);
    },
  );
}
