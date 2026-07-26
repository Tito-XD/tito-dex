import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/dex_cache_store.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/features/dex/dex_offline_service.dart';

PokemonSummary _summary(int id) => PokemonSummary(
  id: id,
  nameEn: 'Mon$id',
  nameZh: '宝可梦$id',
  types: const ['normal'],
);

void main() {
  late Directory tempRoot;
  late DexCachePaths paths;
  late DexCacheStore store;
  late DexOfflineService service;

  setUp(() async {
    tempRoot = Directory.systemTemp.createTempSync('titodex_verify_test');
    paths = DexCachePaths(Directory('${tempRoot.path}/dex_offline'));
    await paths.ensureLayout();
    store = DexCacheStore(paths: paths);
    service = DexOfflineService(store: store);
  });

  tearDown(() {
    tempRoot.deleteSync(recursive: true);
  });

  test('reports no data when nothing is installed', () async {
    final result = await service.verifyOfflineData();

    expect(result.hasData, isFalse);
    expect(result.healthy, isFalse);
  });

  test('passes when manifest, catalog, details and sprites line up', () async {
    await store.writeManifest(
      const DexCacheManifest(
        version: DexCacheManifest.currentVersion,
        complete: true,
        preferOffline: true,
        pokemonCount: 2,
        moveCount: 0,
      ),
    );
    await store.writeSummaries([_summary(1), _summary(2)]);
    await paths.catalogFile.writeAsString('{}');
    for (final id in [1, 2]) {
      await paths.detailFile(id).writeAsString('{}');
      await paths.spriteFile(id).writeAsBytes(const [0]);
    }

    final result = await service.verifyOfflineData();

    expect(result.healthy, isTrue);
    expect(result.summaryCount, 2);
    expect(result.missingDetails, 0);
    expect(result.missingSprites, 0);
  });

  test('flags missing details as unhealthy, missing sprites as note only',
      () async {
    await store.writeManifest(
      const DexCacheManifest(
        version: DexCacheManifest.currentVersion,
        complete: true,
        preferOffline: true,
        pokemonCount: 2,
        moveCount: 0,
      ),
    );
    await store.writeSummaries([_summary(1), _summary(2)]);
    await paths.catalogFile.writeAsString('{}');
    // Detail only for #1; sprite only for #2.
    await paths.detailFile(1).writeAsString('{}');
    await paths.spriteFile(2).writeAsBytes(const [0]);

    final result = await service.verifyOfflineData();

    expect(result.missingDetails, 1);
    expect(result.missingSprites, 1);
    expect(result.healthy, isFalse);
  });

  test('an incomplete manifest is unhealthy even with all files present',
      () async {
    await store.writeManifest(
      const DexCacheManifest(
        version: DexCacheManifest.currentVersion,
        complete: false,
        preferOffline: true,
        pokemonCount: 1,
        moveCount: 0,
      ),
    );
    await store.writeSummaries([_summary(1)]);
    await paths.catalogFile.writeAsString('{}');
    await paths.detailFile(1).writeAsString('{}');
    await paths.spriteFile(1).writeAsBytes(const [0]);

    final result = await service.verifyOfflineData();

    expect(result.hasData, isTrue);
    expect(result.missingDetails, 0);
    expect(result.healthy, isFalse);
  });
}
