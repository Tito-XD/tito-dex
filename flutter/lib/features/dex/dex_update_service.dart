import 'package:http/http.dart' as http;

import 'dex_cache_store.dart';
import 'dex_cdn_config.dart';
import 'dex_models.dart';

/// Kind of CDN update available for the local offline cache.
enum DexUpdateKind {
  /// Full bundle.tar.zst re-download required.
  full,

  /// Incremental l10n / maps / config slice only.
  l10nOnly,
}

/// Result of comparing remote bundle-manifest.json with local dex_offline state.
class DexUpdateInfo {
  const DexUpdateInfo({
    required this.hasUpdate,
    this.updateKind,
    required this.remoteManifest,
    this.localManifest,
  });

  final bool hasUpdate;
  final DexUpdateKind? updateKind;
  final DexBundleManifest remoteManifest;
  final DexCacheManifest? localManifest;
}

/// Checks CDN bundle-manifest.json against the installed offline cache.
class DexUpdateService {
  DexUpdateService({
    DexCdnConfig? config,
    DexCacheStore? store,
    http.Client? httpClient,
  })  : _config = config ?? const DexCdnConfig(),
        _store = store ?? DexCacheStore(),
        _httpClient = httpClient;

  final DexCdnConfig _config;
  final DexCacheStore _store;
  final http.Client? _httpClient;

  Future<DexUpdateInfo> checkForUpdates() async {
    final remote = await _config.fetchManifest(client: _httpClient);
    final local = await _store.readManifest();

    if (!local.complete) {
      return DexUpdateInfo(
        hasUpdate: false,
        remoteManifest: remote,
        localManifest: local,
      );
    }

    final kind = compareManifests(remote: remote, local: local);
    return DexUpdateInfo(
      hasUpdate: kind != null,
      updateKind: kind,
      remoteManifest: remote,
      localManifest: local,
    );
  }

  /// Compare remote CDN manifest with local offline cache manifest.
  static DexUpdateKind? compareManifests({
    required DexBundleManifest remote,
    required DexCacheManifest local,
  }) {
    if (remote.bundleVersion > local.version) {
      return DexUpdateKind.full;
    }

    final remoteL10n = remote.l10nVersion;
    final localL10n = local.l10nVersion;
    if (remoteL10n != null &&
        remoteL10n.isNotEmpty &&
        remoteL10n != localL10n) {
      return DexUpdateKind.l10nOnly;
    }

    final remoteConfig = remote.configVersion;
    final localConfig = local.configVersion;
    if (remoteConfig != null &&
        remoteConfig > 0 &&
        remoteConfig != localConfig) {
      return DexUpdateKind.l10nOnly;
    }

    return null;
  }
}

final dexUpdateService = DexUpdateService();
