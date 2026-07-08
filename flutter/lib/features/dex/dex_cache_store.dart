import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'dex_models.dart';
import 'type_chart.dart';

class DexCachePaths {
  DexCachePaths(this.root);

  final Directory root;

  File get manifestFile => File('${root.path}/manifest.json');
  File get summariesFile => File('${root.path}/summaries.json');
  File get typesFile => File('${root.path}/types.json');
  File get movesFile => File('${root.path}/moves.json');
  Directory get detailsDir => Directory('${root.path}/details');
  Directory get spritesDir => Directory('${root.path}/sprites');
  Directory get typeIconsDir => Directory('${root.path}/type_icons');

  File detailFile(int id) => File('${detailsDir.path}/$id.json');
  File spriteFile(int id) => File('${spritesDir.path}/$id.jpg');
  File typeIconFile(String type) => File('${typeIconsDir.path}/$type.jpg');

  static Future<DexCachePaths> resolve() async {
    final documents = await getApplicationDocumentsDirectory();
    final root = Directory('${documents.path}/dex_offline');
    return DexCachePaths(root);
  }

  Future<void> ensureLayout() async {
    await root.create(recursive: true);
    await detailsDir.create(recursive: true);
    await spritesDir.create(recursive: true);
    await typeIconsDir.create(recursive: true);
  }
}

class DexCacheStore {
  DexCacheStore({DexCachePaths? paths}) : _pathsFuture = paths != null
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
    final json =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
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
        doubleDamageTo:
            (map['doubleDamageTo'] as List<dynamic>).cast<String>().toSet(),
        halfDamageTo:
            (map['halfDamageTo'] as List<dynamic>).cast<String>().toSet(),
        noDamageTo:
            (map['noDamageTo'] as List<dynamic>).cast<String>().toSet(),
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
    return json.map(
      (key, value) => MapEntry(
        int.parse(key),
        CachedMove.fromJson(value as Map<String, dynamic>),
      ),
    );
  }

  Future<void> writeDetail(int id, PokemonDetail detail) async {
    final paths = await _pathsFuture;
    await paths.ensureLayout();
    await paths.detailFile(id).writeAsString(
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
    final json =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return PokemonDetail.fromJson(json, moveLookup: moves);
  }

  Future<void> writeSpriteBytes(int id, List<int> bytes) async {
    final paths = await _pathsFuture;
    await paths.ensureLayout();
    await paths.spriteFile(id).writeAsBytes(bytes);
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
    return 'sprites/$id.jpg';
  }

  Future<String?> typeIconRelativePath(String type) async {
    final paths = await _pathsFuture;
    final file = paths.typeIconFile(type);
    if (!await file.exists()) {
      return null;
    }
    return 'type_icons/$type.jpg';
  }

  Future<String?> absolutePathForRelative(String relativePath) async {
    final paths = await _pathsFuture;
    final file = File('${paths.root.path}/$relativePath');
    if (!await file.exists()) {
      return null;
    }
    return file.path;
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
