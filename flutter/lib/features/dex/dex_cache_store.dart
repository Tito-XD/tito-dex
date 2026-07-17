import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'dex_catalog.dart';
import 'dex_models.dart';
import 'type_chart.dart';

class DexCachePaths {
  DexCachePaths(this.root);

  final Directory root;

  File get manifestFile => File('${root.path}/manifest.json');
  File get summariesFile => File('${root.path}/summaries.json');
  File get typesFile => File('${root.path}/types.json');
  File get movesFile => File('${root.path}/moves.json');
  File get abilitiesFile => File('${root.path}/abilities.json');
  File get catalogFile => File('${root.path}/${DexCatalog.filename}');
  File jsonFile(String name) => File('${root.path}/$name');
  Directory get detailsDir => Directory('${root.path}/details');
  Directory get spritesDir => Directory('${root.path}/sprites');
  Directory get artworkDir => Directory('${root.path}/artwork');
  Directory get typeIconsDir => Directory('${root.path}/type_icons');
  Directory get l10nDir => Directory('${root.path}/l10n/zh');
  Directory get mapsDir => Directory('${root.path}/maps');
  Directory get configDir => Directory('${root.path}/config');

  File get appConfigFile => File('${configDir.path}/app_config.json');
  File l10nFile(String filename) => File('${l10nDir.path}/$filename');
  File mapFile(String filename) => File('${mapsDir.path}/$filename');

  File detailFile(int id) => File('${detailsDir.path}/$id.json');
  File spriteFile(int id) => File('${spritesDir.path}/$id.png');
  File artworkFile(int id) => File('${artworkDir.path}/$id.png');
  File typeIconFile(String type) => File('${typeIconsDir.path}/$type.png');

  static Future<DexCachePaths> resolve() async {
    final documents = await getApplicationDocumentsDirectory();
    final root = Directory('${documents.path}/dex_offline');
    return DexCachePaths(root);
  }

  Future<void> ensureLayout() async {
    await root.create(recursive: true);
    await detailsDir.create(recursive: true);
    await spritesDir.create(recursive: true);
    await artworkDir.create(recursive: true);
    await typeIconsDir.create(recursive: true);
  }
}

class DexCacheStore {
  DexCacheStore({DexCachePaths? paths})
    : _pathsFuture = paths != null
          ? Future.value(paths)
          : DexCachePaths.resolve();

  final Future<DexCachePaths> _pathsFuture;

  Future<DexCacheManifest> readManifest() async {
    final paths = await _pathsFuture;
    final file = paths.manifestFile;
    if (!await file.exists()) {
      return const DexCacheManifest(
        version: DexCacheManifest.currentVersion,
        complete: false,
        preferOffline: true,
      );
    }
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return DexCacheManifest.fromJson(json);
  }

  Future<void> writeManifest(DexCacheManifest manifest) async {
    final paths = await _pathsFuture;
    await paths.ensureLayout();
    await paths.manifestFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
    );
  }

  Future<void> writeSummaries(List<PokemonSummary> summaries) async {
    final paths = await _pathsFuture;
    await paths.ensureLayout();
    final payload = summaries.map((entry) => entry.toJson()).toList();
    await paths.summariesFile.writeAsString(jsonEncode(payload));
  }

  Future<List<PokemonSummary>> readSummaries() async {
    final paths = await _pathsFuture;
    final file = paths.summariesFile;
    if (!await file.exists()) {
      return const [];
    }
    final list = jsonDecode(await file.readAsString()) as List<dynamic>;
    return list
        .map((item) => PokemonSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<DexCatalog?> readCatalog() async {
    final paths = await _pathsFuture;
    final file = paths.catalogFile;
    if (!await file.exists()) {
      return null;
    }
    return DexCatalog.decode(await file.readAsString());
  }

  Future<bool> hasCatalog() async =>
      await (await _pathsFuture).catalogFile.exists();

  Future<void> writeCatalog(DexCatalog catalog) async {
    final paths = await _pathsFuture;
    await paths.ensureLayout();
    await paths.catalogFile.writeAsString(jsonEncode(catalog.toJson()));
  }

  /// Converts a legacy bundle once during installation.  Do not call this
  /// from UI data reads: the resulting catalog is specifically what prevents
  /// those reads from scanning every detail file.
  Future<DexCatalog?> rebuildCatalogFromLegacyBundle() async {
    final paths = await _pathsFuture;
    final summariesFile = paths.summariesFile;
    final movesFile = paths.movesFile;
    final abilitiesFile = paths.abilitiesFile;
    if (!await summariesFile.exists() ||
        !await movesFile.exists() ||
        !await abilitiesFile.exists()) {
      return null;
    }
    final detailSources = <String>[];
    if (await paths.detailsDir.exists()) {
      await for (final entity in paths.detailsDir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          detailSources.add(await entity.readAsString());
        }
      }
    }
    if (detailSources.isEmpty) {
      return null;
    }
    final catalog = await DexCatalog.buildFromLegacyBundle(
      summariesSource: await summariesFile.readAsString(),
      movesSource: await movesFile.readAsString(),
      abilitiesSource: await abilitiesFile.readAsString(),
      detailSources: detailSources,
    );
    await writeCatalog(catalog);
    return catalog;
  }

  /// Resolves a bundle-relative sprite without an expensive per-file stat.
  /// Catalog entries are only trusted after the bundle manifest is complete.
  Future<String> absolutePathForKnownRelative(String relativePath) async {
    final paths = await _pathsFuture;
    return '${paths.root.path}/$relativePath';
  }

  Future<String> rootPath() async => (await _pathsFuture).root.path;

  Future<void> writeTypeRelations(
    Map<String, TypeDamageRelations> relations,
  ) async {
    final paths = await _pathsFuture;
    await paths.ensureLayout();
    final payload = <String, dynamic>{};
    for (final entry in relations.entries) {
      payload[entry.key] = {
        'doubleDamageTo': entry.value.doubleDamageTo.toList(),
        'halfDamageTo': entry.value.halfDamageTo.toList(),
        'noDamageTo': entry.value.noDamageTo.toList(),
      };
    }
    await paths.typesFile.writeAsString(jsonEncode(payload));
  }

  Future<Map<String, TypeDamageRelations>> readTypeRelations() async {
    final paths = await _pathsFuture;
    final file = paths.typesFile;
    if (!await file.exists()) {
      return {};
    }
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final relations = <String, TypeDamageRelations>{};
    for (final entry in json.entries) {
      final map = entry.value as Map<String, dynamic>;
      relations[entry.key] = TypeDamageRelations(
        doubleDamageTo: (map['doubleDamageTo'] as List<dynamic>)
            .cast<String>()
            .toSet(),
        halfDamageTo: (map['halfDamageTo'] as List<dynamic>)
            .cast<String>()
            .toSet(),
        noDamageTo: (map['noDamageTo'] as List<dynamic>).cast<String>().toSet(),
      );
    }
    return relations;
  }

  Future<void> writeMoves(Map<int, CachedMove> moves) async {
    final paths = await _pathsFuture;
    await paths.ensureLayout();
    final payload = <String, dynamic>{};
    for (final entry in moves.entries) {
      payload['${entry.key}'] = entry.value.toJson();
    }
    await paths.movesFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
  }

  Future<Map<int, CachedMove>> readMoves() async {
    final paths = await _pathsFuture;
    final file = paths.movesFile;
    if (!await file.exists()) {
      return {};
    }
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final moves = <int, CachedMove>{};
    for (final entry in json.entries) {
      final id = int.tryParse(entry.key);
      if (id == null) {
        continue;
      }
      moves[id] = CachedMove.fromJson(entry.value as Map<String, dynamic>);
    }
    return moves;
  }

  /// Read CDN reference indices bundled offline (natures, weather, items, …).
  Future<List<Map<String, dynamic>>> readJsonArray(String filename) async {
    final paths = await _pathsFuture;
    final file = paths.jsonFile(filename);
    if (!await file.exists()) {
      return const [];
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! List) {
      return const [];
    }
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  /// Read object-shaped CDN indices (items.json, moves.json, …).
  Future<Map<String, dynamic>> readJsonObject(String filename) async {
    final paths = await _pathsFuture;
    final file = paths.jsonFile(filename);
    if (!await file.exists()) {
      return const {};
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      return const {};
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<Map<int, CachedAbility>> readAbilities() async {
    final json = await readJsonObject('abilities.json');
    final abilities = <int, CachedAbility>{};
    for (final entry in json.entries) {
      final id = int.tryParse(entry.key);
      if (id == null) {
        continue;
      }
      abilities[id] = CachedAbility.fromJson(
        entry.value as Map<String, dynamic>,
        fallbackId: id,
      );
    }
    return abilities;
  }

  Future<void> writeDetail(int id, PokemonDetail detail) async {
    final paths = await _pathsFuture;
    await paths.ensureLayout();
    await paths
        .detailFile(id)
        .writeAsString(
          const JsonEncoder.withIndent('  ').convert(detail.toJson()),
        );
  }

  Future<PokemonDetail?> readDetail(int id) async {
    final paths = await _pathsFuture;
    final file = paths.detailFile(id);
    if (!await file.exists()) {
      return null;
    }
    final moves = await readMoves();
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return PokemonDetail.fromJson(json, moveLookup: moves);
  }

  Future<void> writeSpriteBytes(int id, List<int> bytes) async {
    final paths = await _pathsFuture;
    await paths.ensureLayout();
    await paths.spriteFile(id).writeAsBytes(bytes);
  }

  Future<void> writeArtworkBytes(int id, List<int> bytes) async {
    final paths = await _pathsFuture;
    await paths.ensureLayout();
    await paths.artworkFile(id).writeAsBytes(bytes);
  }

  Future<String?> artworkAbsolutePath(int id) async {
    final paths = await _pathsFuture;
    final file = paths.artworkFile(id);
    if (!await file.exists()) {
      return null;
    }
    return file.path;
  }

  Future<void> writeTypeIconBytes(String type, List<int> bytes) async {
    final paths = await _pathsFuture;
    await paths.ensureLayout();
    await paths.typeIconFile(type).writeAsBytes(bytes);
  }

  Future<String?> spriteRelativePath(int id) async {
    final paths = await _pathsFuture;
    final file = paths.spriteFile(id);
    if (!await file.exists()) {
      return null;
    }
    return 'sprites/$id.png';
  }

  Future<String?> typeIconRelativePath(String type) async {
    final paths = await _pathsFuture;
    final file = paths.typeIconFile(type);
    if (!await file.exists()) {
      return null;
    }
    return 'type_icons/$type.png';
  }

  Future<String?> absolutePathForRelative(String relativePath) async {
    final paths = await _pathsFuture;
    final file = File('${paths.root.path}/$relativePath');
    if (!await file.exists()) {
      return null;
    }
    return file.path;
  }

  /// Scan cached detail JSON for species that learn [moveId].
  Future<List<int>> findPokemonIdsWithMove(int moveId) async {
    final paths = await _pathsFuture;
    final dir = paths.detailsDir;
    if (!await dir.exists()) {
      return const [];
    }

    final matches = <int>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) {
        continue;
      }
      final fileName = entity.uri.pathSegments.last;
      final id = int.tryParse(fileName.replaceAll('.json', ''));
      if (id == null) {
        continue;
      }
      try {
        final json =
            jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
        if (_detailJsonContainsMove(json, moveId)) {
          matches.add(id);
        }
      } catch (error) {
        // Skip corrupt detail files, but leave a trace for diagnosis.
        debugPrint('DexCacheStore: corrupt detail #$id skipped: $error');
      }
    }
    matches.sort();
    return matches;
  }

  static bool _detailJsonContainsMove(Map<String, dynamic> json, int moveId) {
    bool listHasMove(List<dynamic>? refs) {
      if (refs == null) {
        return false;
      }
      for (final ref in refs) {
        if (ref is! Map) {
          continue;
        }
        if ((ref['moveId'] as num?)?.toInt() == moveId) {
          return true;
        }
      }
      return false;
    }

    bool moveSetHasMove(Map<String, dynamic>? moveSet) {
      if (moveSet == null) {
        return false;
      }
      return listHasMove(moveSet['levelUp'] as List<dynamic>?) ||
          listHasMove(moveSet['machine'] as List<dynamic>?) ||
          listHasMove(moveSet['egg'] as List<dynamic>?) ||
          listHasMove(moveSet['tutor'] as List<dynamic>?);
    }

    if (moveSetHasMove(json['moveSet'] as Map<String, dynamic>?)) {
      return true;
    }
    final moveSets = json['moveSets'] as Map<String, dynamic>?;
    if (moveSets != null) {
      for (final entry in moveSets.values) {
        if (entry is Map<String, dynamic> && moveSetHasMove(entry)) {
          return true;
        }
      }
    }
    return false;
  }

  Future<int> directorySizeBytes() async {
    final paths = await _pathsFuture;
    if (!await paths.root.exists()) {
      return 0;
    }
    var total = 0;
    await for (final entity in paths.root.list(recursive: true)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  Future<void> clearAll() async {
    final paths = await _pathsFuture;
    if (await paths.root.exists()) {
      await paths.root.delete(recursive: true);
    }
  }
}

/// Merge move dictionaries without duplicating shared move definitions.
Map<int, CachedMove> mergeMoves(
  Map<int, CachedMove> existing,
  Iterable<CachedMove> incoming,
) {
  final merged = Map<int, CachedMove>.from(existing);
  for (final move in incoming) {
    merged.putIfAbsent(move.id, () => move);
  }
  return merged;
}

String typeIconRemoteUrl(String type) =>
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/types/generation-iii/colosseum/$type.png';
