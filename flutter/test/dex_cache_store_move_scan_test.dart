import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/dex_cache_store.dart';
import 'package:titodex/features/dex/dex_models.dart';

void main() {
  test('findPokemonIdsWithMove scans cached detail learnsets', () async {
    final root = await Directory.systemTemp.createTemp('titodex_move_scan');
    addTearDown(() => root.delete(recursive: true));

    final paths = DexCachePaths(root);
    await paths.ensureLayout();

    await paths.detailFile(1).writeAsString(
          jsonEncode({
            'summary': const PokemonSummary(
              id: 1,
              nameEn: 'bulbasaur',
              nameZh: '妙蛙种子',
              types: ['grass', 'poison'],
            ).toJson(),
            'genusZh': '种子宝可梦',
            'heightDm': 7,
            'weightHg': 69,
            'weaknesses': const [],
            'resistances': const [],
            'immunities': const [],
            'stabSuperEffective': const [],
            'evolutionChain': null,
            'moveSet': {
              'levelUp': [
                {'moveId': 33, 'method': 'level-up', 'level': 1},
              ],
              'machine': const [],
              'egg': const [],
              'tutor': const [],
            },
          }),
        );

    await paths.detailFile(4).writeAsString(
          jsonEncode({
            'summary': const PokemonSummary(
              id: 4,
              nameEn: 'charmander',
              nameZh: '小火龙',
              types: ['fire'],
            ).toJson(),
            'genusZh': '蜥蜴宝可梦',
            'heightDm': 6,
            'weightHg': 85,
            'weaknesses': const [],
            'resistances': const [],
            'immunities': const [],
            'stabSuperEffective': const [],
            'evolutionChain': null,
            'moveSet': {
              'levelUp': [
                {'moveId': 10, 'method': 'level-up', 'level': 1},
              ],
              'machine': const [],
              'egg': const [],
              'tutor': const [],
            },
          }),
        );

    final store = DexCacheStore(paths: paths);
    final matches = await store.findPokemonIdsWithMove(33);

    expect(matches, [1]);
  });

  test('absolutePathForRelative resolves files under bundle root', () async {
    final root = await Directory.systemTemp.createTemp('titodex_sprite');
    addTearDown(() => root.delete(recursive: true));

    final paths = DexCachePaths(root);
    await paths.ensureLayout();
    await paths.spriteFile(25).writeAsString('png');

    final store = DexCacheStore(paths: paths);
    final absolute = await store.absolutePathForRelative('sprites/25.png');

    expect(absolute, paths.spriteFile(25).path);
  });
}
