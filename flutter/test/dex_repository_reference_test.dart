import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/dex_cache_store.dart';
import 'package:titodex/features/dex/dex_cdn_data_source.dart';
import 'package:titodex/features/dex/dex_offline_service.dart';
import 'package:titodex/features/dex/dex_repository.dart';

class _ReferenceOffline extends DexOfflineService {
  _ReferenceOffline({
    required this.ready,
    required this.preferOffline,
    required this.entries,
    this.bundledSeedReady = false,
  }) : super(store: DexCacheStore(paths: DexCachePaths(Directory.systemTemp)));

  final bool ready;
  final bool preferOffline;
  final List<Map<String, dynamic>> entries;
  final bool bundledSeedReady;
  int readCount = 0;
  int ensureSeedCount = 0;

  @override
  Future<bool> isReady() async => ready;

  @override
  Future<bool> shouldPreferOffline() async => preferOffline;

  @override
  Future<bool> ensureApkBundledOfflinePackReady({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    ensureSeedCount++;
    return bundledSeedReady;
  }

  @override
  Future<List<Map<String, dynamic>>> readReferenceArray(String filename) async {
    readCount++;
    return entries;
  }
}

class _ReferenceCdn extends DexCdnDataSource {
  _ReferenceCdn({required this.entries, this.error});

  final List<Map<String, dynamic>> entries;
  final Object? error;
  int readCount = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchReferenceArray(
    String filename,
  ) async {
    readCount++;
    if (error != null) {
      throw error!;
    }
    return entries;
  }
}

void main() {
  const localEntries = <Map<String, dynamic>>[
    {'slug': 'potion', 'nameZh': '伤药'},
  ];
  const remoteEntries = <Map<String, dynamic>>[
    {'slug': 'super-potion', 'nameZh': '好伤药'},
  ];

  test(
    'complete offline bundle serves reference data without touching CDN',
    () async {
      final offline = _ReferenceOffline(
        ready: true,
        preferOffline: false,
        entries: localEntries,
      );
      final cdn = _ReferenceCdn(entries: remoteEntries);
      final repository = DexRepository(offline: offline, cdn: cdn);

      expect(await repository.getReferenceEntries('items.json'), localEntries);
      expect(offline.readCount, 1);
      expect(cdn.readCount, 0);
    },
  );

  test('lite install stays CDN first', () async {
    final offline = _ReferenceOffline(
      ready: false,
      preferOffline: false,
      entries: localEntries,
    );
    final cdn = _ReferenceCdn(entries: remoteEntries);
    final repository = DexRepository(offline: offline, cdn: cdn);

    expect(await repository.getReferenceEntries('items.json'), remoteEntries);
    expect(offline.readCount, 0);
    expect(cdn.readCount, 1);
  });

  test(
    'offline install uses CDN only when the local file is missing',
    () async {
      final offline = _ReferenceOffline(
        ready: true,
        preferOffline: false,
        entries: const [],
      );
      final cdn = _ReferenceCdn(entries: remoteEntries);
      final repository = DexRepository(offline: offline, cdn: cdn);

      expect(await repository.getReferenceEntries('items.json'), remoteEntries);
      expect(offline.readCount, 1);
      expect(cdn.readCount, 1);
    },
  );

  test(
    'offline APK waits for its bundled seed instead of touching CDN',
    () async {
      final offline = _ReferenceOffline(
        ready: false,
        preferOffline: false,
        bundledSeedReady: true,
        entries: localEntries,
      );
      final cdn = _ReferenceCdn(entries: remoteEntries);
      final repository = DexRepository(offline: offline, cdn: cdn);

      expect(await repository.getReferenceEntries('items.json'), localEntries);
      expect(offline.ensureSeedCount, 1);
      expect(offline.readCount, 1);
      expect(cdn.readCount, 0);
    },
  );

  test('lite install falls back to offline cache after a CDN error', () async {
    final offline = _ReferenceOffline(
      ready: false,
      preferOffline: false,
      entries: localEntries,
    );
    final cdn = _ReferenceCdn(entries: const [], error: StateError('offline'));
    final repository = DexRepository(offline: offline, cdn: cdn);

    expect(await repository.getReferenceEntries('items.json'), localEntries);
    expect(offline.readCount, 1);
    expect(cdn.readCount, 1);
  });
}
