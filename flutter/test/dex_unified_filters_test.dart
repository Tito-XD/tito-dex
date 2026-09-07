import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/dex/dex_browse_scope.dart';
import 'package:titodex/features/dex/dex_cache_store.dart';
import 'package:titodex/features/dex/dex_offline_service.dart';
import 'package:titodex/features/dex/dex_browse_session.dart';
import 'package:titodex/features/dex/dex_filter.dart';
import 'package:titodex/features/dex/dex_game_scope.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/features/dex/dex_repository.dart';
import 'package:titodex/features/game/game_edition.dart';
import 'package:titodex/features/game/game_edition_repository.dart';
import 'package:titodex/widgets/pokemon_card.dart';
import 'package:titodex/widgets/dex_detail_controls.dart';

const _fire = PokemonSummary(
  id: 6,
  nameEn: 'charizard',
  nameZh: '喷火龙',
  types: ['fire', 'flying'],
  colorSlug: 'red',
  heightDm: 17,
  generation: 1,
  shapeSlug: 'upright',
  formSearchTerms: ['charizard-mega-x'],
);
const _water = PokemonSummary(
  id: 7,
  nameEn: 'squirtle',
  nameZh: '杰尼龟',
  types: ['water'],
);
const _mega = PokemonFormDetail(
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
);

class _Repository extends DexRepository {
  _Repository()
    : super(
        offline: DexOfflineService(
          store: DexCacheStore(paths: DexCachePaths(Directory.systemTemp)),
        ),
      );
  int reads = 0;
  @override
  Future<List<PokemonSummary>> getAllSummaries() async => [_fire, _water];
  @override
  Future<List<int>> findPokemonWithMove(int id) async => [6, 7];
  @override
  Future<List<PokemonSummary>> findByAbility(int id) async => [_fire];
  @override
  Future<List<PokemonSummary>> findByEggGroup(String slug) async =>
      slug == 'dragon' ? [_fire] : [_water];
  @override
  Future<PokemonDetail> getDetail(int id) async {
    reads++;
    return const PokemonDetail(
      summary: _fire,
      genusZh: '火焰宝可梦',
      heightDm: 17,
      weightHg: 905,
      weaknesses: [],
      resistances: [],
      immunities: [],
      stabSuperEffective: [],
      evolutionChain: null,
      forms: [_mega],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('collapsed reference labels omit species and expansion detail', () {
    PokemonFormDetail named(String name) => PokemonFormDetail.fromJson({
      ..._mega.toJson(),
      'nameZh': name,
    }, moveLookup: const {});
    expect(DexDetailControls.selectedFormLabel(_mega, '喷火龙'), '超级X');
    expect(
      DexDetailControls.selectedFormLabel(named('喷火龙（超极巨化）'), '喷火龙'),
      '超极巨化',
    );
    expect(DexDetailControls.selectedFormLabel(named('喷火龙'), '喷火龙'), '基础形态');
    expect(
      DexDetailControls.selectedFormLabel(named('雷丘（阿罗拉的样子）'), '雷丘'),
      '阿罗拉的样子',
    );
    expect(gameEditionFromSlug('sv')!.referenceGameNameZh, '朱/紫');
    expect(
      gameEditionFromSlug('sv')!.referenceExpansionZh,
      contains('碧之假面、蓝之圆盘'),
    );
    expect(
      gameEditionFromSlug('swsh')!.referenceExpansionZh,
      contains('铠之孤岛、冠之雪原'),
    );
    expect(gameEditionFromSlug('lza')!.referenceExpansionZh, contains('超次元爆涌'));
  });
  test('regional dex membership intersects debut generation', () {
    final region = const DexBrowseScope.region(DexRegionalPokedex.paldea);
    const generation = DexFilter(generation: 1);
    final entries = [
      _fire.copyWith(pokedexNumbers: {'blueberry': 168}),
      const PokemonSummary(
        id: 155,
        nameEn: 'cyndaquil',
        nameZh: '火球鼠',
        types: ['fire'],
        generation: 2,
        pokedexNumbers: {'blueberry': 175},
      ),
      _water.copyWith(generation: 1, pokedexNumbers: {}),
    ];
    expect(
      entries
          .where(region.matches)
          .where(generation.matchesSpeciesAxes)
          .map((p) => p.id),
      [6],
    );
  });
  test(
    'references intersect and cannot mask a conflicting constraint',
    () async {
      final repo = _Repository();
      expect(
        await repo.filterSummaries(
          const DexFilter(
            learnsMoveId: 1,
            abilityId: 1,
            eggGroupSlug: 'water1',
          ),
        ),
        isEmpty,
      );
      final result = await repo.filterSummaries(
        const DexFilter(
          learnsMoveId: 1,
          abilityId: 1,
          eggGroupSlug: 'dragon',
          query: '火 飞行',
          typeSlugs: {'fire'},
          colorSlugs: {'red', 'brown'},
        ),
      );
      expect(result.map((p) => p.id), [6]);
      expect(repo.reads, 0);
    },
  );
  test(
    'form types, identity and scope survive expansion and serialization',
    () async {
      final repo = _Repository();
      final result = await repo.filterSummaries(
        const DexFilter(
          formDisplay: DexFormDisplay.alternate,
          typeSlugs: {'dragon'},
        ),
      );
      final form = result.single;
      expect(form.id, 6);
      expect(form.formKey, 'charizard-mega-x');
      expect(form.spriteResourceId, 10034);
      expect(const DexBrowseScope.generation(1).matches(form), isTrue);
      expect(PokemonSummary.fromJson(form.toJson()).formKey, form.formKey);
      expect(form.copyWith(spriteUrl: 'test').formKey, form.formKey);
      expect(pokemonCardHeroTag(form), isNot(pokemonCardHeroTag(_fire)));
      expect(repo.reads, 1);
    },
  );
  test('obsolete form search stops before scheduling detail reads', () async {
    final repo = _Repository();
    expect(
      await repo.filterSummaries(
        const DexFilter(formDisplay: DexFormDisplay.all),
        isCancelled: () => true,
      ),
      isEmpty,
    );
    expect(repo.reads, 0);
  });
  test('all unified constraints participate in browse restoration', () {
    const f = DexFilter(
      query: '火',
      typeSlugs: {'fire'},
      formDisplay: DexFormDisplay.all,
    );
    expect(
      dexFilterFingerprint(f),
      isNot(dexFilterFingerprint(DexFilter.empty)),
    );
    expect(
      f
          .withSpeciesAxes(shapeSlug: 'upright', colorSlugs: {}, sizeSlug: null)
          .query,
      '火',
    );
    expect(f.without(color: true).formDisplay, DexFormDisplay.all);
    expect(f.copyWith(tag: 'legendary').typeSlugs, {'fire'});
  });
  test(
    'general selection persists without retaining a previous exact game',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repo = GameEditionRepository();
      await repo.save(GameEdition.hgss.withFlavor('soulsilver'));
      await repo.save(GameEdition.general);
      final fresh = GameEditionRepository();
      await fresh.load();
      expect(fresh.edition.isGeneral, isTrue);
      expect(fresh.edition.selectedFlavor, isNull);
      expect(fresh.edition.dataVersionGroupKey, 'general');
      expect(fresh.edition.defaultRegionalPokedex, DexRegionalPokedex.national);
      expect(fresh.edition.assistantGameKey, isNull);
      expect(fresh.edition.iconAsset, 'assets/icons/titodex-app.png');
    },
  );
}
