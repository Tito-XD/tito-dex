import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/dex_cache_store.dart';
import 'package:titodex/features/dex/dex_catalog.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/features/dex/dex_offline_service.dart';
import 'package:titodex/features/dex/dex_repository.dart';

class _CatalogOffline extends DexOfflineService {
  _CatalogOffline(DexCachePaths paths)
    : super(store: DexCacheStore(paths: paths));

  @override
  Future<bool> shouldPreferOffline() async => true;

  @override
  Future<List<PokemonSummary>> readAllSummaries() =>
      throw StateError('catalog-backed reads must not re-read summaries.json');
}

void main() {
  const bulbasaur = PokemonSummary(
    id: 1,
    nameEn: 'bulbasaur',
    nameZh: '妙蛙种子',
    types: ['grass', 'poison'],
    localSpritePath: 'sprites/1.png',
  );
  const charmander = PokemonSummary(
    id: 4,
    nameEn: 'charmander',
    nameZh: '小火龙',
    types: ['fire'],
    localSpritePath: 'sprites/4.png',
  );

  test('legacy bundle catalog is built with all hot filter indices', () async {
    final catalog = await DexCatalog.buildFromLegacyBundle(
      summariesSource: jsonEncode([bulbasaur.toJson(), charmander.toJson()]),
      movesSource:
          '{"33":{"id":33,"nameEn":"Tackle","nameZh":"撞击","type":"normal","category":"physical"}}',
      abilitiesSource:
          '{"65":{"id":65,"nameEn":"Overgrow","nameZh":"Overgrow","descriptionZh":"","pokemonIds":[1,4]},"66":{"id":66,"nameEn":"Blaze","nameZh":"Blaze","descriptionZh":"","pokemonIds":[4]}}',
      detailSources: [
        '{"summary":{"id":1},"eggGroups":["怪兽"],"moveSet":{"levelUp":[{"moveId":33}]},"moveSets":{"heartgold-soulsilver":{"machine":[{"moveId":15}]}}}',
        '{"summary":{"id":4},"eggGroups":["怪兽","龙"],"moveSet":{"egg":[{"moveId":33}]}}',
      ],
    );

    expect(catalog.summaries, hasLength(2));
    expect(catalog.moveLearners[33], [1, 4]);
    expect(catalog.moveLearners[15], [1]);
    expect(catalog.eggGroups['monster'], [1, 4]);
    expect(catalog.eggGroups['dragon'], [4]);
    expect(catalog.abilityPokemonIds[65], [1, 4]);
    expect(catalog.moves[33]?.nameEn, 'Tackle');
  });

  test(
    'repository serves list and every reference filter from catalog memory',
    () async {
      final root = await Directory.systemTemp.createTemp('titodex_catalog');
      addTearDown(() => root.delete(recursive: true));
      final paths = DexCachePaths(root);
      await paths.ensureLayout();
      final store = DexCacheStore(paths: paths);
      await store.writeCatalog(
        const DexCatalog(
          summaries: [bulbasaur, charmander],
          moveLearners: {
            33: [1, 4],
          },
          eggGroups: {
            'monster': [1, 4],
            'dragon': [4],
          },
          abilityPokemonIds: {
            65: [1, 4],
          },
          moves: {
            33: CachedMove(
              id: 33,
              nameEn: 'Tackle',
              nameZh: '撞击',
              type: 'normal',
              category: 'physical',
            ),
          },
        ),
      );

      final repo = DexRepository(offline: _CatalogOffline(paths));
      await repo.warmUp();

      expect((await repo.getSummaryRange(1, 4)).map((entry) => entry.id), [
        1,
        4,
      ]);
      expect((await repo.search('小火')).single.id, 4);
      expect((await repo.findPokemonWithMove(33)), [1, 4]);
      expect((await repo.findByEggGroup('dragon')).single.id, 4);
      expect((await repo.findByAbility(65)).map((entry) => entry.id), [1, 4]);
      expect((await repo.getAllMoves()).single.id, 33);
      expect(
        (await repo.getAllSummaries()).first.localSpritePath,
        contains('sprites/1.png'),
      );
    },
  );
}
