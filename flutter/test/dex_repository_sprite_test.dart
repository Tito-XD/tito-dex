import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/dex_cache_store.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/features/dex/dex_offline_service.dart';
import 'package:titodex/features/dex/dex_repository.dart';

class _FakeOffline extends DexOfflineService {
  _FakeOffline(this._paths)
      : super(store: DexCacheStore(paths: _paths));

  final DexCachePaths _paths;

  @override
  Future<bool> shouldPreferOffline() async => true;

  @override
  Future<List<PokemonSummary>> readAllSummaries() async {
    return const [
      PokemonSummary(
        id: 25,
        nameEn: 'pikachu',
        nameZh: '皮卡丘',
        types: ['electric'],
        localSpritePath: 'sprites/25.png',
      ),
    ];
  }

  @override
  Future<String?> absolutePathForRelative(String relativePath) async {
    return '${_paths.root.path}/$relativePath';
  }

  @override
  String spriteUrlFor(int id) => 'https://cdn.example/sprites/$id.png';
}

void main() {
  test('getAllSummaries resolves relative sprite paths', () async {
    final root = await Directory.systemTemp.createTemp('titodex_repo_sprite');
    addTearDown(() => root.delete(recursive: true));

    final paths = DexCachePaths(root);
    await paths.ensureLayout();
    await paths.spritesDir.create(recursive: true);
    await paths.spriteFile(25).writeAsString('png');

    final offline = _FakeOffline(paths);
    final repo = DexRepository(offline: offline);

    final summaries = await repo.getAllSummaries();
    expect(summaries, hasLength(1));
    expect(summaries.first.localSpritePath, endsWith('sprites/25.png'));
    expect(summaries.first.displaySpritePath, isNot('sprites/25.png'));
  });

  test('search resolves sprite paths for matched entries', () async {
    final root = await Directory.systemTemp.createTemp('titodex_repo_search');
    addTearDown(() => root.delete(recursive: true));

    final paths = DexCachePaths(root);
    await paths.ensureLayout();
    await paths.spriteFile(25).writeAsString('png');

    final offline = _FakeOffline(paths);
    final repo = DexRepository(offline: offline);

    final results = await repo.search('皮卡丘');
    expect(results, hasLength(1));
    expect(results.first.localSpritePath, endsWith('sprites/25.png'));
  });
}
