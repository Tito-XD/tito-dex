import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'dex_bundle_installer.dart';
import 'dex_cache_store.dart';
import 'dex_cdn_config.dart';
import 'dex_cdn_data_source.dart';
import 'dex_models.dart';
import 'dex_sprite_codec.dart';
import '../../config/app_config.dart';
import '../../l10n/zh_catalog.dart';
import 'poke_api_throttle.dart';
import 'pokeapi_client.dart';
import 'type_chart.dart';

class DexOfflineService {
  DexOfflineService({
    PokeApiClient? client,
    DexCacheStore? store,
    DexSpriteCodec? codec,
    DexCdnConfig? cdnConfig,
    DexBundleInstaller? bundleInstaller,
    this.pokemonRetryAttempts = 5,
    this.checkpointEvery = 5,
  })  : _client = client ?? PokeApiClient(),
        _store = store ?? DexCacheStore(),
        _codec = codec ?? const DexSpriteCodec(),
        _cdnConfig = cdnConfig ?? const DexCdnConfig(),
        _explicitBundleInstaller = bundleInstaller;

  final PokeApiClient _client;
  final DexCacheStore _store;
  final DexSpriteCodec _codec;
  final DexCdnConfig _cdnConfig;
  final DexBundleInstaller? _explicitBundleInstaller;
  DexBundleInstaller? _resolvedBundleInstaller;
  final http.Client _http = http.Client();
  final int pokemonRetryAttempts;
  final int checkpointEvery;

  DexBundleInstaller get _bundleInstaller =>
      _explicitBundleInstaller ??
      (_resolvedBundleInstaller ??= DexBundleInstaller(
        store: _store,
        config: _cdnConfig,
      ));

  bool _downloading = false;
  DexCacheProgress? _progress;

  bool get isDownloading => _downloading;
  DexCacheProgress? get progress => _progress;

  Future<DexCacheStatus> getStatus() async {
    final manifest = await _store.readManifest();
    final sizeBytes = await _store.directorySizeBytes();
    return DexCacheStatus(
      manifest: manifest,
      sizeBytes: sizeBytes,
      isDownloading: _downloading,
      progress: _progress,
    );
  }

  Future<void> setPreferOffline(bool enabled) async {
    final manifest = await _store.readManifest();
    await _store.writeManifest(
      DexCacheManifest(
        version: manifest.version,
        complete: manifest.complete,
        preferOffline: enabled,
        downloadedAt: manifest.downloadedAt,
        pokemonCount: manifest.pokemonCount,
        moveCount: manifest.moveCount,
        sizeBytes: manifest.sizeBytes,
      ),
    );
  }

  Future<bool> isReady() async {
    if (kIsWeb) {
      return false;
    }
    final manifest = await _store.readManifest();
    return manifest.complete;
  }

  Future<bool> shouldPreferOffline() async {
    // Web preview has no file-backed offline cache (`path_provider`
    // unsupported) — always fall back to live PokeAPI there.
    if (kIsWeb) {
      return false;
    }
    final manifest = await _store.readManifest();
    if (!manifest.preferOffline) {
      return false;
    }
    return manifest.complete || manifest.pokemonCount > 0;
  }

  Future<List<PokemonSummary>> readAllSummaries() =>
      kIsWeb ? Future.value(const <PokemonSummary>[]) : _store.readSummaries();

  Future<PokemonSummary?> readSummary(int id) async {
    if (kIsWeb) {
      return null;
    }
    final summaries = await _store.readSummaries();
    for (final entry in summaries) {
      if (entry.id == id) {
        return _attachAbsoluteSprite(entry);
      }
    }
    final detail = await readDetail(id);
    return detail?.summary;
  }

  Future<PokemonDetail?> readDetail(int id) async {
    if (kIsWeb) {
      return null;
    }
    final detail = await _store.readDetail(id);
    if (detail == null) {
      return null;
    }
    return _attachAbsoluteSpritesToDetail(detail);
  }

  Future<List<Map<String, dynamic>>> readReferenceArray(String filename) async {
    if (kIsWeb) {
      return const [];
    }
    final array = await _store.readJsonArray(filename);
    if (array.isNotEmpty) {
      return array;
    }
    final object = await _store.readJsonObject(filename);
    if (object.isEmpty) {
      return const [];
    }
    return DexCdnDataSource.objectEntriesToList(object);
  }

  Future<Map<int, CachedAbility>> readAbilitiesIndex() async {
    if (kIsWeb) {
      return const {};
    }
    return _store.readAbilities();
  }

  Future<Map<int, CachedMove>> readMovesIndex() async {
    if (kIsWeb) {
      return const {};
    }
    return _store.readMoves();
  }

  Future<String?> typeIconPath(String type) async {
    final relative = await _store.typeIconRelativePath(type);
    if (relative != null) {
      return _store.absolutePathForRelative(relative);
    }
    return _cdnConfig.typeIconUrl(type);
  }

  Stream<DexCacheProgress> downloadFromCdnBundle() async* {
    if (_downloading) {
      return;
    }
    _downloading = true;

    try {
      await for (final progress in _bundleInstaller.install()) {
        yield _setProgress(
          phase: progress.phase,
          current: progress.current,
          total: progress.total,
          label: progress.label,
        );
      }
    } finally {
      _downloading = false;
      _progress = null;
    }
  }

  Stream<DexCacheProgress> downloadAll() async* {
    if (_downloading) {
      return;
    }
    _downloading = true;

    try {
      yield _setProgress(
        phase: 'types',
        current: 0,
        total: typeNamesZh.length,
        label: '属性图标',
      );

      final relations = await _client.loadAllTypeRelations();
      await _store.writeTypeRelations(relations);

      var typeIndex = 0;
      for (final type in typeNamesZh.keys) {
        typeIndex++;
        await _downloadTypeIcon(type);
        yield _setProgress(
          phase: 'types',
          current: typeIndex,
          total: typeNamesZh.length,
          label: typeNameZh(type),
        );
      }

      final summaries = await _store.readSummaries();
      final moves = await _store.readMoves();
      _client.primeMoveCache(moves);

      final completedIds = summaries.map((entry) => entry.id).toSet();
      final failedIds = <int>[];

      for (var id = 1; id <= hgssMaxNationalDexId; id++) {
        if (completedIds.contains(id)) {
          continue;
        }

        yield _setProgress(
          phase: 'pokemon',
          current: id,
          total: hgssMaxNationalDexId,
          label: '宝可梦 #$id',
        );

        final detail = await _fetchPokemonDetailWithRetry(id);
        if (detail == null) {
          failedIds.add(id);
          continue;
        }

        mergeMoves(moves, detail.moveSet.allMoves);

        final spritePath =
            await _cachePokemonSprite(id, detail.summary.spriteUrl);
        final summary = detail.summary.copyWith(localSpritePath: spritePath);
        final localizedEvolution = await _localizeEvolutionSprites(
          detail.evolutionChain,
        );
        final localizedDetail = PokemonDetail(
          summary: summary,
          genusZh: detail.genusZh,
          heightDm: detail.heightDm,
          weightHg: detail.weightHg,
          weaknesses: detail.weaknesses,
          resistances: detail.resistances,
          immunities: detail.immunities,
          stabSuperEffective: detail.stabSuperEffective,
          evolutionChain: localizedEvolution,
          johtoDexNumber: detail.johtoDexNumber,
          baseStats: detail.baseStats,
          typeMultipliers: detail.typeMultipliers,
          flavorEntries: detail.flavorEntries,
          obtainLocations: detail.obtainLocations,
          moveSet: detail.moveSet,
          genderFemalePercent: detail.genderFemalePercent,
          eggGroups: detail.eggGroups,
          hatchCounter: detail.hatchCounter,
        );

        await _store.writeDetail(id, localizedDetail);
        summaries.add(summary);
        completedIds.add(id);

        if (id % checkpointEvery == 0 || id == hgssMaxNationalDexId) {
          await _store.writeMoves(moves);
          await _store.writeSummaries(summaries);
          await _writeCheckpoint(
            pokemonCount: summaries.length,
            moveCount: moves.length,
            complete: false,
          );
        }
      }

      await _store.writeMoves(moves);
      await _store.writeSummaries(summaries);

      if (failedIds.isEmpty && summaries.length == hgssMaxNationalDexId) {
        final sizeBytes = await _store.directorySizeBytes();
        await _store.writeManifest(
          DexCacheManifest(
            version: DexCacheManifest.currentVersion,
            complete: true,
            preferOffline: true,
            downloadedAt: DateTime.now().toIso8601String(),
            pokemonCount: summaries.length,
            moveCount: moves.length,
            sizeBytes: sizeBytes,
          ),
        );

        yield _setProgress(
          phase: 'done',
          current: hgssMaxNationalDexId,
          total: hgssMaxNationalDexId,
          label: null,
        );
        return;
      }

      await _writeCheckpoint(
        pokemonCount: summaries.length,
        moveCount: moves.length,
        complete: false,
      );

      debugPrint(
        'DexOfflineService: partial download '
        '${summaries.length}/$hgssMaxNationalDexId, failed=$failedIds',
      );

      yield _setProgress(
        phase: 'partial',
        current: summaries.length,
        total: hgssMaxNationalDexId,
        label: failedIds.isEmpty ? null : '${failedIds.length} 只失败',
      );
    } finally {
      _downloading = false;
      _progress = null;
    }
  }

  Future<PokemonDetail?> _fetchPokemonDetailWithRetry(int id) async {
    for (var attempt = 0; attempt < pokemonRetryAttempts; attempt++) {
      try {
        return await _client.fetchDetailWithMoves(id);
      } on PokeApiException catch (error, stackTrace) {
        debugPrint(
          'DexOfflineService: #$id attempt ${attempt + 1} failed: $error',
        );
        debugPrint('$stackTrace');
        if (attempt == pokemonRetryAttempts - 1) {
          return null;
        }
        await Future<void>.delayed(pokeApiRetryDelay(attempt));
      } catch (error, stackTrace) {
        debugPrint(
          'DexOfflineService: #$id unexpected error on attempt ${attempt + 1}: $error',
        );
        debugPrint('$stackTrace');
        if (attempt == pokemonRetryAttempts - 1) {
          return null;
        }
        await Future<void>.delayed(pokeApiRetryDelay(attempt));
      }
    }
    return null;
  }

  Future<void> _writeCheckpoint({
    required int pokemonCount,
    required int moveCount,
    required bool complete,
  }) async {
    final manifest = await _store.readManifest();
    final sizeBytes = await _store.directorySizeBytes();
    await _store.writeManifest(
      DexCacheManifest(
        version: DexCacheManifest.currentVersion,
        complete: complete,
        preferOffline: true,
        downloadedAt: manifest.downloadedAt ?? DateTime.now().toIso8601String(),
        pokemonCount: pokemonCount,
        moveCount: moveCount,
        sizeBytes: sizeBytes,
      ),
    );
  }

  Future<void> clearAll() async {
    await _store.clearAll();
    await ZhCatalog.instance.reload();
    await AppConfig.instance.reload();
  }

  DexCacheProgress _setProgress({
    required String phase,
    required int current,
    required int total,
    String? label,
  }) {
    _progress = DexCacheProgress(
      phase: phase,
      current: current,
      total: total,
      label: label,
    );
    return _progress!;
  }

  Future<void> _downloadTypeIcon(String type) async {
    final response = await _http.get(Uri.parse(typeIconRemoteUrl(type)));
    if (response.statusCode != 200) {
      return;
    }
    final compressed = _codec.compressPngBytes(response.bodyBytes);
    if (compressed == null) {
      return;
    }
    await _store.writeTypeIconBytes(type, compressed);
  }

  Future<String?> _cachePokemonSprite(int id, String? remoteUrl) async {
    if (remoteUrl == null) {
      return null;
    }
    final response = await _http.get(Uri.parse(remoteUrl));
    if (response.statusCode != 200) {
      return null;
    }
    final compressed = _compressForPokemon(response.bodyBytes);
    if (compressed == null) {
      return null;
    }
    await _store.writeSpriteBytes(id, compressed);
    return _store.spriteRelativePath(id);
  }

  Uint8List? _compressForPokemon(Uint8List bytes) {
    return _codec.compressPngBytes(bytes);
  }

  Future<EvolutionNode?> _localizeEvolutionSprites(
    EvolutionNode? node,
  ) async {
    if (node == null) {
      return null;
    }

    final spritePath = await _store.spriteRelativePath(node.id) ??
        await _cachePokemonSprite(node.id, node.spriteUrl);
    final localizedChildren = <EvolutionNode>[];
    for (final child in node.children) {
      final localizedChild = await _localizeEvolutionSprites(child);
      if (localizedChild != null) {
        localizedChildren.add(localizedChild);
      }
    }

    return EvolutionNode(
      id: node.id,
      nameEn: node.nameEn,
      nameZh: node.nameZh,
      spriteUrl: node.spriteUrl,
      localSpritePath: spritePath,
      evolvesFrom: node.evolvesFrom,
      triggerZh: node.triggerZh,
      children: localizedChildren,
    );
  }

  Future<PokemonSummary> _attachAbsoluteSprite(PokemonSummary summary) async {
    final relative = summary.localSpritePath;
    if (relative != null && !relative.startsWith('http')) {
      final absolute = await _store.absolutePathForRelative(relative);
      if (absolute != null) {
        return summary.copyWith(localSpritePath: absolute);
      }
    } else if (relative != null) {
      return summary;
    }
    return summary.copyWith(localSpritePath: _cdnConfig.spriteUrl(summary.id));
  }

  Future<PokemonDetail> _attachAbsoluteSpritesToDetail(
    PokemonDetail detail,
  ) async {
    final summary = await _attachAbsoluteSprite(detail.summary);
    final evolution = await _attachAbsoluteSpritesToEvolution(
      detail.evolutionChain,
    );
    return PokemonDetail(
      summary: summary,
      genusZh: detail.genusZh,
      heightDm: detail.heightDm,
      weightHg: detail.weightHg,
      weaknesses: detail.weaknesses,
      resistances: detail.resistances,
      immunities: detail.immunities,
      stabSuperEffective: detail.stabSuperEffective,
      evolutionChain: evolution,
      johtoDexNumber: detail.johtoDexNumber,
      baseStats: detail.baseStats,
      typeMultipliers: detail.typeMultipliers,
      flavorEntries: detail.flavorEntries,
      obtainLocations: detail.obtainLocations,
      moveSet: detail.moveSet,
      genderFemalePercent: detail.genderFemalePercent,
      eggGroups: detail.eggGroups,
      hatchCounter: detail.hatchCounter,
    );
  }

  Future<EvolutionNode?> _attachAbsoluteSpritesToEvolution(
    EvolutionNode? node,
  ) async {
    if (node == null) {
      return null;
    }
    String? absolute;
    if (node.localSpritePath != null &&
        !node.localSpritePath!.startsWith('http')) {
      absolute = await _store.absolutePathForRelative(node.localSpritePath!);
    } else if (node.localSpritePath != null) {
      absolute = node.localSpritePath;
    }
    absolute ??= _cdnConfig.spriteUrl(node.id);
    final children = <EvolutionNode>[];
    for (final child in node.children) {
      final localized = await _attachAbsoluteSpritesToEvolution(child);
      if (localized != null) {
        children.add(localized);
      }
    }
    return EvolutionNode(
      id: node.id,
      nameEn: node.nameEn,
      nameZh: node.nameZh,
      spriteUrl: node.spriteUrl,
      localSpritePath: absolute,
      evolvesFrom: node.evolvesFrom,
      triggerZh: node.triggerZh,
      children: children,
    );
  }
}

final dexOfflineService = DexOfflineService();
