import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'dex_cache_store.dart';
import 'dex_cdn_config.dart';
import 'dex_models.dart';
import '../../config/app_config.dart';
import '../../l10n/zh_catalog.dart';

/// Known l10n JSON files published under the active versioned CDN prefix.
const kDexL10nFileNames = [
  'manifest.json',
  'location_area_labels.json',
  'location_area_id_to_slug.json',
  'species_labels.json',
  'moves_labels.json',
  'abilities_labels.json',
  'items_labels.json',
  'hgss_map_labels.json',
];

/// Downloads incremental l10n / maps / config without the full bundle archive.
class DexL10nInstaller {
  DexL10nInstaller({
    DexCacheStore? store,
    DexCdnConfig? config,
    http.Client? httpClient,
  }) : _store = store ?? DexCacheStore(),
       _config = config ?? const DexCdnConfig(),
       _http = httpClient ?? http.Client();

  final DexCacheStore _store;
  final DexCdnConfig _config;
  final http.Client _http;

  Stream<DexCacheProgress> install({DexBundleManifest? remoteManifest}) async* {
    final manifest =
        remoteManifest ?? await _config.fetchManifest(client: _http);
    final paths = await DexCachePaths.resolve();
    await paths.ensureLayout();
    await paths.l10nDir.create(recursive: true);
    await paths.mapsDir.create(recursive: true);
    await paths.configDir.create(recursive: true);

    final files = [
      ...kDexL10nFileNames.map((name) => _DownloadTarget.l10n(name)),
      _DownloadTarget.map('hgss_map_list.json'),
      _DownloadTarget.config('app_config.json'),
    ];
    List<http.Response>? downloaded;
    for (final prefix in DexCdnConfig.apiVersionPrefixes) {
      final candidates = <http.Response>[];
      var complete = true;
      for (final target in files) {
        final response = await _http.get(
          Uri.parse(target.url(_config, prefix: prefix)),
        );
        if (response.statusCode != 200) {
          complete = false;
          break;
        }
        candidates.add(response);
      }
      if (complete) {
        downloaded = candidates;
        break;
      }
    }
    if (downloaded == null) {
      throw DexCdnException(
        'Failed to download a complete l10n slice from v5, v4, v3, or v2',
      );
    }

    for (var i = 0; i < files.length; i++) {
      final target = files[i];
      yield DexCacheProgress(
        phase: 'l10n_download',
        current: i,
        total: files.length,
        label: target.label,
      );

      final response = downloaded[i];

      final outFile = File('${paths.root.path}/${target.relativePath}');
      await outFile.parent.create(recursive: true);
      final decoded = jsonDecode(response.body);
      await outFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(decoded),
      );
    }

    yield DexCacheProgress(
      phase: 'l10n_download',
      current: files.length,
      total: files.length,
      label: null,
    );

    final local = await _store.readManifest();
    final sizeBytes = await _store.directorySizeBytes();
    await _store.writeManifest(
      DexCacheManifest(
        version: local.version,
        complete: local.complete,
        preferOffline: local.preferOffline,
        downloadedAt: DateTime.now().toIso8601String(),
        pokemonCount: local.pokemonCount,
        moveCount: local.moveCount,
        sizeBytes: sizeBytes,
        l10nVersion: manifest.l10nVersion ?? local.l10nVersion,
        configVersion: manifest.configVersion ?? local.configVersion,
      ),
    );

    await ZhCatalog.instance.reload();
    await AppConfig.instance.reload();

    yield DexCacheProgress(phase: 'done', current: 1, total: 1, label: null);
  }
}

class _DownloadTarget {
  const _DownloadTarget._({required this.label, required this.relativePath});

  factory _DownloadTarget.l10n(String name) =>
      _DownloadTarget._(label: name, relativePath: 'l10n/zh/$name');

  factory _DownloadTarget.map(String name) =>
      _DownloadTarget._(label: name, relativePath: 'maps/$name');

  factory _DownloadTarget.config(String name) =>
      _DownloadTarget._(label: name, relativePath: 'config/$name');

  final String label;
  final String relativePath;
  String url(DexCdnConfig config, {required String prefix}) {
    if (relativePath.startsWith('maps/')) {
      return config.mapFileUrl(label, prefix: prefix);
    }
    if (relativePath.startsWith('config/')) {
      return config.configFileUrl(label, prefix: prefix);
    }
    return config.l10nFileUrl(label, prefix: prefix);
  }
}
