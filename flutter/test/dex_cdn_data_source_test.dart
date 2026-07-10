import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:titodex/features/dex/dex_cdn_data_source.dart';

MockClient _mockCdn() {
  return MockClient((request) async {
    final path = request.url.path;
    if (path == '/v2/summaries.json') {
      return http.Response(
        jsonEncode([
          {
            'id': 1,
            'nameEn': 'Bulbasaur',
            'nameZh': '妙蛙种子',
            'types': ['grass', 'poison'],
            'spriteUrl': 'https://dex.tito.cafe/v2/sprites/1.png',
            'artworkUrl': 'https://dex.tito.cafe/v2/artwork/1.png',
            'localSpritePath': 'sprites/1.png',
          },
          {
            'id': 155,
            'nameEn': 'Cyndaquil',
            'nameZh': '火球鼠',
            'types': ['fire'],
            'spriteUrl': 'https://dex.tito.cafe/v2/sprites/155.png',
            'localSpritePath': 'sprites/155.png',
          },
        ]),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    if (path == '/v2/moves.json') {
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
    if (path == '/v2/details/1.json') {
      return http.Response(
        jsonEncode({
          'summary': {
            'id': 1,
            'nameEn': 'Bulbasaur',
            'nameZh': '妙蛙种子',
            'types': ['grass', 'poison'],
            'spriteUrl': 'https://dex.tito.cafe/v2/sprites/1.png',
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
  test('fetchAllSummaries parses CDN list and strips localSpritePath',
      () async {
    final source = DexCdnDataSource(client: _mockCdn());

    final summaries = await source.fetchAllSummaries();

    expect(summaries, hasLength(2));
    expect(summaries.first.nameZh, '妙蛙种子');
    // Without a downloaded bundle the local path must not be used; the
    // display path should fall back to the CDN sprite URL.
    expect(summaries.first.localSpritePath, isNull);
    expect(
      summaries.first.displaySpritePath,
      'https://dex.tito.cafe/v2/sprites/1.png',
    );
  });

  test('fetchDetail resolves moves via CDN moves.json', () async {
    final source = DexCdnDataSource(client: _mockCdn());

    final detail = await source.fetchDetail(1);

    expect(detail.summary.nameZh, '妙蛙种子');
    expect(detail.baseStats?.hp, 45);
    expect(detail.moveSet.levelUp, hasLength(1));
    expect(detail.moveSet.levelUp.first.move.nameZh, '撞击');
    expect(detail.summary.localSpritePath, isNull);
  });

  test('fetchDetail throws on CDN error status', () async {
    final source = DexCdnDataSource(
      client: MockClient((_) async => http.Response('boom', 500)),
    );

    expect(source.fetchDetail(1), throwsA(isA<Exception>()));
  });
}
