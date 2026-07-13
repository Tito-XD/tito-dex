import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:zstandard/zstandard.dart';

import 'dex_cache_store.dart';
import 'dex_cdn_config.dart';
import 'dex_models.dart';
import '../../config/app_config.dart';
import '../../l10n/zh_catalog.dart';

class DexBundleInstaller {
  DexBundleInstaller({
    DexCacheStore? store,
    DexCdnConfig? config,
    http.Client? httpClient,
    Zstandard? zstandard,
  })  : _store = store ?? DexCacheStore(),
        _config = config ?? const DexCdnConfig(),
        _http = httpClient ?? http.Client(),
        _zstandard = zstandard ?? Zstandard();

  final DexCacheStore _store;
  final DexCdnConfig _config;
  final http.Client _http;
  final Zstandard _zstandard;

  Stream<DexCacheProgress> install({DexBundleManifest? manifest}) async* {
    yield _progress(
      phase: 'cdn_manifest',
      current: 1,
      total: 1,
      label: 'bundle-manifest.json',
    );

    final bundleManifest = manifest ?? await _config.fetchManifest(client: _http);

    final totalBytes = bundleManifest.archiveSizeBytes > 0
        ? bundleManifest.archiveSizeBytes
        : 1;

    final request = http.Request('GET', Uri.parse(bundleManifest.archiveUrl));
    final response = await _http.send(request);
    if (response.statusCode != 200) {
      throw DexCdnException(
        'Failed to download bundle: HTTP ${response.statusCode}',
      );
    }

    final chunks = <int>[];
    var downloaded = 0;
    await for (final chunk in response.stream) {
      chunks.addAll(chunk);
      downloaded += chunk.length;
      yield _progress(
        phase: 'cdn_download',
        current: downloaded,
        total: totalBytes,
        label: _formatBytes(downloaded, totalBytes),
      );
    }
    final archiveBytes = Uint8List.fromList(chunks);

    yield _progress(phase: 'cdn_verify', current: 1, total: 1, label: 'SHA-256');

    if (bundleManifest.hasIntegrityCheck) {
      final digest = sha256.convert(archiveBytes).toString();
      if (digest != bundleManifest.archiveSha256) {
        throw DexCdnException(
          'Bundle SHA-256 mismatch: expected ${bundleManifest.archiveSha256}, got $digest',
        );
      }
    }

    yield _progress(phase: 'cdn_decompress', current: 0, total: 1, label: 'zstd');

    final tarBytes = await _decompress(archiveBytes);
    if (tarBytes == null || tarBytes.isEmpty) {
      throw DexCdnException('Failed to decompress bundle archive');
    }

    yield _progress(phase: 'cdn_decompress', current: 1, total: 1, label: 'zstd');

    await _store.clearAll();
    final paths = await _resolvePaths();

    final archive = TarDecoder().decodeBytes(tarBytes);
    final files = archive.where((entry) => entry.isFile).toList();
    final fileCount = files.length;

    for (var i = 0; i < files.length; i++) {
      final entry = files[i];
      final outFile = File('${paths.root.path}/${entry.name}');
      await outFile.parent.create(recursive: true);
      await outFile.writeAsBytes(entry.content as List<int>);
      final shouldReport =
          i == 0 || i + 1 == fileCount || (i + 1) % 50 == 0;
      if (shouldReport) {
        yield _progress(
          phase: 'cdn_extract',
          current: i + 1,
          total: fileCount,
          label: null,
        );
      }
    }

    final cacheManifest = await _store.readManifest();
    final sizeBytes = await _store.directorySizeBytes();
    final summaries = await _store.readSummaries();
    final moves = await _store.readMoves();
    final pokemonTotal = summaries.isNotEmpty
        ? summaries.length
        : (bundleManifest.pokemonCount ?? titodexMaxNationalDexId);
    await _store.writeManifest(
      DexCacheManifest(
        version: DexCdnConfig.bundleVersion,
        complete: true,
        preferOffline: true,
        downloadedAt:
            cacheManifest.downloadedAt ?? DateTime.now().toIso8601String(),
        pokemonCount: pokemonTotal,
        moveCount: moves.length,
        sizeBytes: sizeBytes,
        l10nVersion: bundleManifest.l10nVersion,
        configVersion: bundleManifest.configVersion,
      ),
    );

    await ZhCatalog.instance.reload();
    await AppConfig.instance.reload();

    yield _progress(
      phase: 'done',
      current: pokemonTotal,
      total: pokemonTotal,
      label: null,
    );
  }

  Future<Uint8List?> _decompress(Uint8List compressed) async {
    try {
      return await _zstandard.decompress(compressed);
    } catch (error, stackTrace) {
      debugPrint('DexBundleInstaller: zstd decompress failed: $error');
      debugPrint('$stackTrace');
      return null;
    }
  }

  Future<DexCachePaths> _resolvePaths() async {
    final paths = await DexCachePaths.resolve();
    await paths.ensureLayout();
    return paths;
  }

  DexCacheProgress _progress({
    required String phase,
    required int current,
    required int total,
    String? label,
  }) {
    return DexCacheProgress(
      phase: phase,
      current: current,
      total: total,
      label: label,
    );
  }

  String _formatBytes(int downloaded, int total) {
    if (total <= 0) {
      return _humanBytes(downloaded);
    }
    return '${_humanBytes(downloaded)} / ${_humanBytes(total)}';
  }

  String _humanBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
