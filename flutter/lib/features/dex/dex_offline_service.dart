import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'dex_cache_store.dart';
import 'dex_models.dart';
import 'dex_sprite_codec.dart';
import 'pokeapi_client.dart';
import 'type_chart.dart';

class DexOfflineService {
  DexOfflineService({
    PokeApiClient? client,
    DexCacheStore? store,
    DexSpriteCodec? codec,
  })  : _client = client ?? PokeApiClient(),
        _store = store ?? DexCacheStore(),
        _codec = codec ?? const DexSpriteCodec();

  final PokeApiClient _client;
  final DexCacheStore _store;
  final DexSpriteCodec _codec;
  final http.Client _http = http.Client();

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
    final manifest = await _store.readManifest();
    return manifest.complete;
  }

  Future<bool> shouldPreferOffline() async {
    final manifest = await _store.readManifest();
    return manifest.complete && manifest.preferOffline;
  }

  Future<List<PokemonSummary>> readAllSummaries() => _store.readSummaries();

  Future<PokemonSummary?> readSummary(int id) async {
    final summaries = await _store.readSummaries();
    for (final entry in summaries) {
      if (entry.id == id) {
        return _attachAbsoluteSprite(entry);
      }
    }
    return null;
  }

  Future<PokemonDetail?> readDetail(int id) async {
    final detail = await _store.readDetail(id);
    if (detail == null) {
      return null;
    }
    return _attachAbsoluteSpritesToDetail(detail);
  }

  Future<String?> typeIconPath(String type) async {
    final relative = await _store.typeIconRelativePath(type);
    if (relative == null) {
      return null;
    }
    return _store.absolutePathForRelative(relative);
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

      final summaries = <PokemonSummary>[];
      final moves = <int, CachedMove>{};

      for (var start = 1; start <= hgssMaxNationalDexId; start += 10) {
        final end = (start + 9).clamp(1, hgssMaxNationalDexId);
        for (var id = start; id <= end; id++) {
          yield _setProgress(
            phase: 'pokemon',
            current: id,
            total: hgssMaxNationalDexId,
            label: '#$id',
          );

          final detail = await _client.fetchDetailWithMoves(id);
          mergeMoves(moves, detail.moveSet.allMoves);

          final spritePath = await _cachePokemonSprite(id, detail.summary.spriteUrl);
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
            moveSet: detail.moveSet,
            genderFemalePercent: detail.genderFemalePercent,
            eggGroups: detail.eggGroups,
            hatchCounter: detail.hatchCounter,
          );

          await _store.writeDetail(id, localizedDetail);
          summaries.add(summary);
        }

        await _store.writeMoves(moves);
        await _store.writeSummaries(summaries);
      }

      final sizeBytes = await _store.directorySizeBytes();
      final manifest = DexCacheManifest(
        version: DexCacheManifest.currentVersion,
        complete: true,
        preferOffline: true,
        downloadedAt: DateTime.now().toIso8601String(),
        pokemonCount: summaries.length,
        moveCount: moves.length,
        sizeBytes: sizeBytes,
      );
      await _store.writeManifest(manifest);

      yield _setProgress(
        phase: 'done',
        current: hgssMaxNationalDexId,
        total: hgssMaxNationalDexId,
        label: null,
      );
    } finally {
      _downloading = false;
      _progress = null;
    }
  }

  Future<void> clearAll() async {
    await _store.clearAll();
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
    return await _store.spriteRelativePath(id);
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
    if (relative == null) {
      return summary;
    }
    final absolute = await _store.absolutePathForRelative(relative);
    if (absolute == null) {
      return summary;
    }
    return summary.copyWith(localSpritePath: absolute);
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
    if (node.localSpritePath != null) {
      absolute = await _store.absolutePathForRelative(node.localSpritePath!) ??
          node.localSpritePath;
    }
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
