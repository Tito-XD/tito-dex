import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'dex_bundle_installer.dart';
import 'dex_cache_store.dart';
import 'dex_cdn_config.dart';
import 'dex_models.dart';

/// Seeds `dex_offline/` from the APK-bundled `bundle.tar.zst` (same bytes as CDN).
class DexAssetSeedInstaller {
  DexAssetSeedInstaller({
    DexCacheStore? store,
    DexBundleInstaller? bundleInstaller,
    AssetBundle? assetBundle,
  })  : _store = store ?? DexCacheStore(),
        _bundleInstaller = bundleInstaller ?? DexBundleInstaller(store: store),
        _assets = assetBundle ?? rootBundle;

  static const archiveAssetPath = 'assets/dex/bundle.tar.zst';
  static const manifestAssetPath = 'assets/dex/bundle-manifest.json';

  final DexCacheStore _store;
  final DexBundleInstaller _bundleInstaller;
  final AssetBundle _assets;

  /// True when the offline APK asset is present in the asset bundle.
  Future<bool> hasBundledArchive() async {
    try {
      await _assets.load(archiveAssetPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<DexBundleManifest> loadSidecarManifest() async {
    final raw = await _assets.loadString(manifestAssetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return DexBundleManifest.fromJson(json);
  }

  /// Whether local offline cache is missing or older than the APK-seeded pack.
  Future<bool> needsSeed({bool force = false}) async {
    if (kIsWeb) {
      return false;
    }
    if (!await hasBundledArchive()) {
      return false;
    }
    if (force) {
      return true;
    }
    final local = await _store.readManifest();
    if (!local.complete || local.pokemonCount <= 0) {
      return true;
    }
    final sidecar = await loadSidecarManifest();
    return local.version < sidecar.bundleVersion;
  }

  Stream<DexCacheProgress> seedIfNeeded({bool force = false}) async* {
    if (!await needsSeed(force: force)) {
      return;
    }

    yield DexCacheProgress(
      phase: 'apk_seed_manifest',
      current: 1,
      total: 1,
      label: 'bundle-manifest.json',
    );

    final sidecar = await loadSidecarManifest();

    yield DexCacheProgress(
      phase: 'apk_seed_load',
      current: 0,
      total: sidecar.archiveSizeBytes > 0 ? sidecar.archiveSizeBytes : 1,
      label: 'assets/dex/bundle.tar.zst',
    );

    final data = await _assets.load(archiveAssetPath);
    final archiveBytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );

    yield DexCacheProgress(
      phase: 'apk_seed_load',
      current: archiveBytes.length,
      total: archiveBytes.length,
      label: 'assets/dex/bundle.tar.zst',
    );

    if (sidecar.hasIntegrityCheck) {
      final digest = sha256.convert(archiveBytes).toString();
      if (digest != sidecar.archiveSha256) {
        throw DexCdnException(
          'APK bundle SHA-256 mismatch: expected ${sidecar.archiveSha256}, got $digest',
        );
      }
    }

    yield* _bundleInstaller.installFromArchiveBytes(
      archiveBytes: archiveBytes,
      bundleManifest: sidecar,
      verifySha256: false, // already verified above
      progressPrefix: 'apk_seed',
    );
  }
}
