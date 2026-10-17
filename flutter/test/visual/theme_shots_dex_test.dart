// Dex / Pokémon detail skin shots.
//
//   cd flutter
//   flutter test test/visual/theme_shots_dex_test.dart \
//     --dart-define=TITODEX_THEME_SHOTS=true
//
// PNGs land in flutter/build/theme_shots/dex2_<theme>_<grid|filter|detail>_<480|800>.png.
// Without the define every scene still pumps (overflow smoke) and nothing
// is written, so the normal test gate stays fast.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/dex/dex_filter.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/features/dex/type_chart.dart';
import 'package:titodex/l10n/app_zh.dart';
import 'package:titodex/models/journey.dart';
import 'package:titodex/pages/dex_page.dart';
import 'package:titodex/theme/app_visual_style.dart';
import 'package:titodex/theme/retro_style.dart';
import 'package:titodex/theme/tito_skin.dart';
import 'package:titodex/theme/tito_theme.dart';
import 'package:titodex/widgets/pokemon_card.dart';
import 'package:titodex/widgets/pokemon_detail_sections.dart';
import 'package:titodex/widgets/sticker_card.dart';
import 'package:titodex/widgets/tito_page_container.dart';
import 'package:titodex/widgets/type_badge.dart';

import 'theme_shot_harness.dart';

const _themeNames = {
  AppVisualStyle.classic: 'journal',
  AppVisualStyle.solidPlastic: 'plastic',
  AppVisualStyle.flatUi: 'flat',
};

const _journey = CurrentJourney(
  game: 'SoulSilver',
  trainerName: 'Tito',
  location: '桔梗市',
  badges: 4,
  maxBadges: 16,
  playTime: '18:24',
  party: [],
  timeline: [],
  companion: '',
);

PokemonSummary _summary(int id, String nameZh, List<String> types) =>
    PokemonSummary(id: id, nameEn: 'pokemon-$id', nameZh: nameZh, types: types);

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
    dexFilterController.clearFilter();
  }

  tearDown(() async {
    await appVisualStyle.setStyle(AppVisualStyle.classic);
    await retroStyle.setEnabled(true);
    dexFilterController.clearFilter();
  });

  Future<void> pumpScene(
    WidgetTester tester,
    AppVisualStyle style,
    Widget page,
  ) async {
    await tester.pumpWidget(
      RepaintBoundary(
        key: themeShotBoundaryKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTitoTheme(style),
          home: page,
        ),
      ),
    );
    await pumpThemeShotFrames(tester, frames: 4);
  }

  final scenes = <String, Widget Function()>{
    'grid': () => const _DexGridScene(),
    'detail': () => const _DexDetailScene(),
  };

  for (final style in AppVisualStyle.values) {
    final theme = _themeNames[style]!;
    for (final viewport in ThemeShotViewport.all) {
      for (final entry in scenes.entries) {
        testWidgets('dex2 $theme ${entry.key} @${viewport.name}', (
          tester,
        ) async {
          viewport.apply(tester);
          addTearDown(tester.view.reset);
          await useStyle(style);
          await pumpScene(tester, style, entry.value());
          expect(tester.takeException(), isNull);
          await captureThemeShot(
            tester,
            'dex2_${theme}_${entry.key}_${viewport.name}',
          );
        });
      }

      testWidgets('dex2 $theme filter @${viewport.name}', (tester) async {
        viewport.apply(tester);
        addTearDown(tester.view.reset);
        await useStyle(style);
        final router = GoRouter(
          initialLocation: '/dex',
          routes: [
            GoRoute(
              path: '/dex',
              builder: (context, state) => TitoPageContainer(
                child: DexPage(
                  journey: _journey,
                  bootstrapOverride: () async {},
                ),
              ),
            ),
            GoRoute(path: '/search', builder: (_, _) => const SizedBox()),
            GoRoute(path: '/settings', builder: (_, _) => const SizedBox()),
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
        await pumpThemeShotFrames(tester, frames: 16);
        expect(find.text(AppZh.dexFilterAll), findsOneWidget);
        expect(tester.takeException(), isNull);
        await captureThemeShot(tester, 'dex2_${theme}_filter_${viewport.name}');
      });
    }
  }
}

class _DexGridScene extends StatelessWidget {
  const _DexGridScene();

  @override
  Widget build(BuildContext context) {
    final skin = TitoSkin.of(context);
    const entries = [
      (1, '妙蛙种子', ['grass', 'poison'], DexEncounterStatus.caught),
      (4, '小火龙', ['fire'], DexEncounterStatus.seen),
      (7, '杰尼龟', ['water'], DexEncounterStatus.unknown),
      (25, '皮卡丘', ['electric'], DexEncounterStatus.unknown),
      (155, '火球鼠', ['fire'], DexEncounterStatus.caught),
      (183, '玛力露', ['water', 'fairy'], DexEncounterStatus.seen),
    ];
    return TitoPageContainer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('图鉴', style: skin.heading(22, color: skin.pageInk)),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 0.78,
                children: [
                  for (final entry in entries)
                    PokemonMiniCard(
                      summary: _summary(entry.$1, entry.$2, entry.$3),
                      status: entry.$4,
                      compact: true,
                      onTap: () {},
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DexDetailScene extends StatelessWidget {
  const _DexDetailScene();

  @override
  Widget build(BuildContext context) {
    final skin = TitoSkin.of(context);
    return TitoPageContainer(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        children: [
          Text('火球鼠', style: skin.heading(22, color: skin.pageInk)),
          Text(
            '火焰宝可梦',
            style: TextStyle(
              color: skin.pageMutedInk,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          StickerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('属性', style: skin.heading(15, color: skin.ink)),
                const SizedBox(height: 8),
                const TitoTypeBadgeRow(
                  typesEn: ['fire'],
                  size: TypeBadgeSize.medium,
                ),
                const SizedBox(height: 8),
                const TypeChipRow(
                  types: ['草', '虫', '冰', '钢'],
                  typeKeys: ['grass', 'bug', 'ice', 'steel'],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          PokemonFormSelector(
            forms: const [
              PokemonFormDetail(
                key: 'cyndaquil',
                pokemonId: 155,
                nameEn: 'Cyndaquil',
                nameZh: '火球鼠',
                kind: PokemonFormKind.form,
                isDefault: true,
                isBattleOnly: false,
                isMega: false,
                isCosmetic: false,
                types: ['fire'],
                heightDm: 5,
                weightHg: 79,
              ),
              PokemonFormDetail(
                key: 'quilava',
                pokemonId: 156,
                nameEn: 'Quilava',
                nameZh: '火岩鼠',
                kind: PokemonFormKind.form,
                isDefault: false,
                isBattleOnly: false,
                isMega: false,
                isCosmetic: false,
                types: ['fire'],
                heightDm: 9,
                weightHg: 190,
              ),
            ],
            selectedKey: 'cyndaquil',
            onSelected: (_) {},
          ),
          const SizedBox(height: 8),
          const AbilitiesCard(
            abilities: [
              PokemonAbility(
                nameEn: 'blaze',
                nameZh: '猛火',
                descriptionZh: 'HP 低时，火属性招式的威力会提高。',
              ),
              PokemonAbility(
                nameEn: 'flash-fire',
                nameZh: '引火',
                descriptionZh: '受到火属性招式攻击时，火属性招式威力提升。',
                isHidden: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          TypeEffectivenessGrid(
            multipliers: {
              for (final type in typeGridOrder) type: 1,
              'water': 2,
              'ground': 2,
              'rock': 2,
              'grass': 0.5,
              'ice': 0.5,
              'bug': 0.5,
              'steel': 0.5,
              'fire': 0.5,
            },
            weaknesses: const ['水', '地面', '岩石'],
            resistances: const ['火', '草', '冰', '虫', '钢'],
            immunities: const [],
          ),
        ],
      ),
    );
  }
}
