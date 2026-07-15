import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'dex_bundle_installer.dart';
import 'dex_cache_store.dart';
import 'dex_cdn_config.dart';
import 'dex_models.dart';

/// Seeds `dex_offline/` from the optional APK-bundled archive.  Lite builds
/// simply do not contain these assets and take the normal CDN path.
class DexAssetSeedInstaller {
  DexAssetSeedInstaller({
    DexCacheStore? store,
    DexBundleInstaller? bundleInstaller,
    AssetBundle? assetBundle,
  }) : _store = store ?? DexCacheStore(),
       _bundleInstaller = bundleInstaller ?? DexBundleInstaller(store: store),
       _assets = assetBundle ?? rootBundle;

  static const archiveAssetPath = 'assets/dex/bundle.tar.zst';
  static const manifestAssetPath = 'assets/dex/bundle-manifest.json';

  final DexCacheStore _store;
  final DexBundleInstaller _bundleInstaller;
  final AssetBundle _assets;

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

  Future<bool> needsSeed({bool force = false}) async {
    if (kIsWeb || !await hasBundledArchive()) {
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
    yield const DexCacheProgress(
      phase: 'apk_seed_manifest',
      current: 1,
      total: 1,
      label: 'bundle-manifest.json',
    );
    final sidecar = await loadSidecarManifest();
    final data = await _assets.load(archiveAssetPath);
    final archiveBytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );

    if (sidecar.hasIntegrityCheck) {
      final digest = sha256.convert(archiveBytes).toString();
      if (digest != sidecar.archiveSha256) {
        throw DexCdnException('APK bundle SHA-256 mismatch');
      }
    }

    yield* _bundleInstaller.installFromArchiveBytes(
      archiveBytes: archiveBytes,
      bundleManifest: sidecar,
      verifySha256: false,
      progressPrefix: 'apk_seed',
    );
  }
}
