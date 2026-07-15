import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/dex_asset_seed_installer.dart';
import 'package:titodex/features/dex/dex_cache_store.dart';
import 'package:titodex/features/dex/dex_cdn_config.dart';
import 'package:titodex/features/dex/dex_models.dart';

class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle(this._files);

  final Map<String, List<int>> _files;

  @override
  Future<ByteData> load(String key) async {
    final bytes = _files[key];
    if (bytes == null) {
      throw FlutterError('Missing asset $key');
    }
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final bytes = _files[key];
    if (bytes == null) {
      throw FlutterError('Missing asset $key');
    }
    return utf8.decode(bytes);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DexAssetSeedInstaller', () {
    test('needsSeed is true when local cache incomplete', () async {
      final temp = await Directory.systemTemp.createTemp('titodex-seed-');
      addTearDown(() async {
        if (await temp.exists()) {
          await temp.delete(recursive: true);
        }
      });

      final store = DexCacheStore(paths: DexCachePaths(temp));
      await store.writeManifest(
        const DexCacheManifest(
          version: 5,
          complete: false,
          preferOffline: true,
          pokemonCount: 0,
        ),
      );

      final sidecar = utf8.encode(
        jsonEncode({
          'bundleVersion': 5,
          'pokemonCount': 1025,
          'archiveSha256': 'abc',
          'archiveSizeBytes': 10,
        }),
      );
      final assets = _FakeAssetBundle({
        DexAssetSeedInstaller.archiveAssetPath: [1, 2, 3],
        DexAssetSeedInstaller.manifestAssetPath: sidecar,
      });

      final installer = DexAssetSeedInstaller(
        store: store,
        assetBundle: assets,
      );

      expect(await installer.needsSeed(), isTrue);
      expect(await installer.hasBundledArchive(), isTrue);

      final loaded = await installer.loadSidecarManifest();
      expect(loaded.bundleVersion, 5);
      expect(loaded.pokemonCount, 1025);
      expect(loaded.hasIntegrityCheck, isTrue);
    });

    test('needsSeed is false when local complete and version current', () async {
      final temp = await Directory.systemTemp.createTemp('titodex-seed-');
      addTearDown(() async {
        if (await temp.exists()) {
          await temp.delete(recursive: true);
        }
      });

      final store = DexCacheStore(paths: DexCachePaths(temp));
      await store.writeManifest(
        const DexCacheManifest(
          version: 5,
          complete: true,
          preferOffline: true,
          pokemonCount: 1025,
        ),
      );

      final sidecar = utf8.encode(
        jsonEncode({
          'bundleVersion': 5,
          'pokemonCount': 1025,
          'archiveSha256': 'abc',
          'archiveSizeBytes': 10,
        }),
      );
      final assets = _FakeAssetBundle({
        DexAssetSeedInstaller.archiveAssetPath: [1, 2, 3],
        DexAssetSeedInstaller.manifestAssetPath: sidecar,
      });

      final installer = DexAssetSeedInstaller(
        store: store,
        assetBundle: assets,
      );

      expect(await installer.needsSeed(), isFalse);
      expect(await installer.needsSeed(force: true), isTrue);
    });

    test('needsSeed is true when local version behind sidecar', () async {
      final temp = await Directory.systemTemp.createTemp('titodex-seed-');
      addTearDown(() async {
        if (await temp.exists()) {
          await temp.delete(recursive: true);
        }
      });

      final store = DexCacheStore(paths: DexCachePaths(temp));
      await store.writeManifest(
        const DexCacheManifest(
          version: 4,
          complete: true,
          preferOffline: true,
          pokemonCount: 493,
        ),
      );

      final sidecar = utf8.encode(
        jsonEncode({
          'bundleVersion': 5,
          'pokemonCount': 1025,
          'archiveSha256': 'abc',
          'archiveSizeBytes': 10,
        }),
      );
      final assets = _FakeAssetBundle({
        DexAssetSeedInstaller.archiveAssetPath: [1, 2, 3],
        DexAssetSeedInstaller.manifestAssetPath: sidecar,
      });

      final installer = DexAssetSeedInstaller(
        store: store,
        assetBundle: assets,
      );

      expect(await installer.needsSeed(), isTrue);
    });

    test('sidecar JSON parses without archiveUrl', () {
      final manifest = DexBundleManifest.fromJson({
        'bundleVersion': 5,
        'pokemonCount': 1025,
        'archiveSha256': 'C2EB245D',
        'archiveSizeBytes': 41154067,
      });
      expect(manifest.bundleVersion, 5);
      expect(manifest.archiveSha256, 'c2eb245d');
      expect(manifest.archiveSizeBytes, 41154067);
      expect(manifest.archiveUrl, DexCdnConfig.bundleUrl);
    });
  });
}
