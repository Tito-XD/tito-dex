import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:titodex/features/dex/dex_cdn_data_source.dart';

MockClient _mockCdn() {
  return MockClient((request) async {
    final path = request.url.path;
    if (path == '/v3/summaries.json') {
      return http.Response(
        jsonEncode([
          {
            'id': 1,
            'nameEn': 'Bulbasaur',
            'nameZh': '妙蛙种子',
            'types': ['grass', 'poison'],
            'spriteUrl': 'https://dex.tito.cafe/v3/sprites/1.png',
            'artworkUrl': 'https://dex.tito.cafe/v3/artwork/1.png',
            'localSpritePath': 'sprites/1.png',
            'pokedexNumbers': {'national': 1, 'kanto': 1},
          },
          {
            'id': 155,
            'nameEn': 'Cyndaquil',
            'nameZh': '火球鼠',
            'types': ['fire'],
            'spriteUrl': 'https://dex.tito.cafe/v3/sprites/155.png',
            'localSpritePath': 'sprites/155.png',
            'pokedexNumbers': {'national': 155, 'original-johto': 4},
          },
        ]),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    if (path == '/v3/moves.json') {
      return http.Response(
        jsonEncode({
          '33': {
            'id': 33,
            'nameEn': 'Tackle',
            'nameZh': '撞击',
            'type': 'normal',
            'category': 'physical',
            'power': 40,
          },
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    if (path == '/v3/abilities.json') {
      return http.Response(
        jsonEncode({
          '65': {
            'nameEn': 'Overgrow',
            'nameZh': '茂盛',
            'descriptionZh': 'HP减少时，草属性招式的威力会提高。',
            'pokemonIds': [1, 2, 3],
          },
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    if (path == '/v3/details/1.json') {
      return http.Response(
        jsonEncode({
          'summary': {
            'id': 1,
            'nameEn': 'Bulbasaur',
            'nameZh': '妙蛙种子',
            'types': ['grass', 'poison'],
            'spriteUrl': 'https://dex.tito.cafe/v3/sprites/1.png',
            'localSpritePath': 'sprites/1.png',
          },
          'genusZh': '种子宝可梦',
          'heightDm': 7,
          'weightHg': 69,
          'weaknesses': <String>[],
          'resistances': <String>[],
          'immunities': <String>[],
          'stabSuperEffective': <String>[],
          'baseStats': {
            'hp': 45,
            'attack': 49,
            'defense': 49,
            'specialAttack': 65,
            'specialDefense': 65,
            'speed': 45,
          },
          'moveSet': {
            'levelUp': [
              {'moveId': 33, 'method': 'level-up', 'level': 1},
            ],
          },
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    return http.Response('not found', 404);
  });
}

void main() {
  test('fetchAllSummaries parses v3 CDN list and strips localSpritePath',
      () async {
    final source = DexCdnDataSource(client: _mockCdn());

    final summaries = await source.fetchAllSummaries();

    expect(summaries, hasLength(2));
    expect(summaries.first.nameZh, '妙蛙种子');
    expect(summaries.first.pokedexNumbers?['kanto'], 1);
    expect(summaries.first.localSpritePath, isNull);
    expect(
      summaries.first.displaySpritePath,
      'https://dex.tito.cafe/v3/sprites/1.png',
    );
  });

  test('fetchDetail resolves moves via v3 CDN moves.json', () async {
    final source = DexCdnDataSource(client: _mockCdn());

    final detail = await source.fetchDetail(1);

    expect(detail.summary.nameZh, '妙蛙种子');
    expect(detail.baseStats?.hp, 45);
    expect(detail.moveSet.levelUp, hasLength(1));
    expect(detail.moveSet.levelUp.first.move.nameZh, '撞击');
  });

  test('fetchAllAbilities loads v3 abilities index', () async {
    final source = DexCdnDataSource(client: _mockCdn());

    final abilities = await source.fetchAllAbilities();

    expect(abilities, hasLength(1));
    expect(abilities[65]?.nameZh, '茂盛');
    expect(abilities[65]?.pokemonIds, [1, 2, 3]);
  });

  test('fetchAbilityEncyclopedia returns indexed ability', () async {
    final source = DexCdnDataSource(client: _mockCdn());

    final ability = await source.fetchAbilityEncyclopedia(65);

    expect(ability.nameZh, '茂盛');
    expect(ability.pokemonIds, [1, 2, 3]);
  });

  test('fetchDetail throws on CDN error status', () async {
    final source = DexCdnDataSource(
      client: MockClient((_) async => http.Response('boom', 500)),
    );

    expect(source.fetchDetail(1), throwsA(isA<Exception>()));
  });
}
