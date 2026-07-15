import 'dart:convert';
import 'dart:isolate';

import '../../l10n/game_zh.dart';
import 'dex_models.dart';

/// The small, precomputed part of an offline dex bundle used by list, search,
/// and reference filters.  Detail files deliberately stay outside this model:
/// they are only needed after a species has been opened.
class DexCatalog {
  const DexCatalog({
    required this.summaries,
    required this.moveLearners,
    required this.eggGroups,
    required this.abilityPokemonIds,
    this.moves = const {},
    this.abilities = const {},
  });

  static const filename = 'dex_catalog.json';
  static const version = 1;

  final List<PokemonSummary> summaries;
  final Map<int, List<int>> moveLearners;
  final Map<String, List<int>> eggGroups;
  final Map<int, List<int>> abilityPokemonIds;
  final Map<int, CachedMove> moves;
  final Map<int, CachedAbility> abilities;

  Map<int, PokemonSummary> get summariesById => {
    for (final summary in summaries) summary.id: summary,
  };

  Map<String, dynamic> toJson() => {
    'version': version,
    'summaries': summaries.map((summary) => summary.toJson()).toList(),
    'moveLearners': _encodeIntIndex(moveLearners),
    'eggGroups': eggGroups,
    'abilityPokemonIds': _encodeIntIndex(abilityPokemonIds),
    'moves': {
      for (final entry in moves.entries) '${entry.key}': entry.value.toJson(),
    },
    'abilities': {
      for (final entry in abilities.entries)
        '${entry.key}': entry.value.toJson(),
    },
  };

  factory DexCatalog.fromJson(Map<String, dynamic> json) {
    final summariesRaw = json['summaries'];
    if (summariesRaw is! List) {
      throw const FormatException('Dex catalog has no summaries list');
    }
    return DexCatalog(
      summaries: summariesRaw
          .whereType<Map>()
          .map(
            (entry) =>
                PokemonSummary.fromJson(Map<String, dynamic>.from(entry)),
          )
          .toList(growable: false),
      moveLearners: _decodeIntIndex(json['moveLearners']),
      eggGroups: _decodeStringIndex(json['eggGroups']),
      abilityPokemonIds: _decodeIntIndex(json['abilityPokemonIds']),
      moves: _decodeMoves(json['moves']),
      abilities: _decodeAbilities(json['abilities']),
    );
  }

  /// JSON decoding is deliberately isolated: decoding a full 1025-species
  /// catalog must never take a frame away from the handheld UI.
  static Future<DexCatalog> decode(String source) async {
    final decoded = await Isolate.run(() => _decodeCatalogPayload(source));
    return DexCatalog.fromJson(decoded);
  }

  /// Compatibility bridge for bundles published before [filename] existed.
  /// It deliberately runs while a bundle is being installed, never from the
  /// Dex page or a filter interaction.
  static Future<DexCatalog> buildFromLegacyBundle({
    required String summariesSource,
    required String movesSource,
    required String abilitiesSource,
    required List<String> detailSources,
  }) async {
    final decoded = await Isolate.run(
      () => _buildCatalogPayload(
        summariesSource,
        movesSource,
        abilitiesSource,
        detailSources,
      ),
    );
    return DexCatalog.fromJson(decoded);
  }

  static Map<String, List<int>> _decodeStringIndex(Object? raw) {
    if (raw is! Map) {
      return const {};
    }
    return Map<String, List<int>>.unmodifiable({
      for (final entry in raw.entries)
        if (entry.key is String) entry.key as String: _decodeIds(entry.value),
    });
  }

  static Map<int, List<int>> _decodeIntIndex(Object? raw) {
    if (raw is! Map) {
      return const {};
    }
    final decoded = <int, List<int>>{};
    for (final entry in raw.entries) {
      final id = int.tryParse(entry.key.toString());
      if (id != null) {
        decoded[id] = _decodeIds(entry.value);
      }
    }
    return Map<int, List<int>>.unmodifiable(decoded);
  }

  static List<int> _decodeIds(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    return List<int>.unmodifiable(
      raw.whereType<num>().map((value) => value.toInt()),
    );
  }

  static Map<int, CachedMove> _decodeMoves(Object? raw) {
    if (raw is! Map) return const {};
    final result = <int, CachedMove>{};
    for (final entry in raw.entries) {
      final id = int.tryParse(entry.key.toString());
      if (id != null && entry.value is Map) {
        result[id] = CachedMove.fromJson(
          Map<String, dynamic>.from(entry.value),
        );
      }
    }
    return Map<int, CachedMove>.unmodifiable(result);
  }

  static Map<int, CachedAbility> _decodeAbilities(Object? raw) {
    if (raw is! Map) return const {};
    final result = <int, CachedAbility>{};
    for (final entry in raw.entries) {
      final id = int.tryParse(entry.key.toString());
      if (id != null && entry.value is Map) {
        result[id] = CachedAbility.fromJson(
          Map<String, dynamic>.from(entry.value),
          fallbackId: id,
        );
      }
    }
    return Map<int, CachedAbility>.unmodifiable(result);
  }

  static Map<String, List<int>> _encodeIntIndex(Map<int, List<int>> index) => {
    for (final entry in index.entries) '${entry.key}': entry.value,
  };
}

Map<String, dynamic> _decodeCatalogPayload(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map) {
    throw const FormatException('Dex catalog root must be an object');
  }
  return Map<String, dynamic>.from(decoded);
}

Map<String, dynamic> _buildCatalogPayload(
  String summariesSource,
  String movesSource,
  String abilitiesSource,
  List<String> detailSources,
) {
  final summariesDecoded = jsonDecode(summariesSource);
  final movesDecoded = jsonDecode(movesSource);
  final abilitiesDecoded = jsonDecode(abilitiesSource);
  if (summariesDecoded is! List ||
      movesDecoded is! Map ||
      abilitiesDecoded is! Map) {
    throw const FormatException('Legacy dex bundle is missing catalog sources');
  }

  final moveLearners = <String, Set<int>>{};
  final eggGroups = <String, Set<int>>{};
  for (final source in detailSources) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      continue;
    }
    final summary = decoded['summary'];
    final id = summary is Map ? (summary['id'] as num?)?.toInt() : null;
    if (id == null) {
      continue;
    }
    for (final moveId in _moveIdsFromDetailJson(decoded)) {
      moveLearners.putIfAbsent('$moveId', () => <int>{}).add(id);
    }
    final groups = decoded['eggGroups'];
    if (groups is List) {
      for (final label in groups.whereType<String>()) {
        final slug = eggGroupSlugForLabelZh(label);
        if (slug != null) {
          eggGroups.putIfAbsent(slug, () => <int>{}).add(id);
        }
      }
    }
  }

  final abilityPokemonIds = <String, List<int>>{};
  for (final entry in abilitiesDecoded.entries) {
    if (entry.value is! Map) {
      continue;
    }
    final ids =
        (entry.value['pokemonIds'] as List? ?? const [])
            .whereType<num>()
            .map((id) => id.toInt())
            .toSet()
            .toList()
          ..sort();
    abilityPokemonIds['${entry.key}'] = ids;
  }

  return {
    'version': DexCatalog.version,
    'summaries': summariesDecoded,
    'moveLearners': {
      for (final entry in moveLearners.entries)
        entry.key: entry.value.toList()..sort(),
    },
    'eggGroups': {
      for (final entry in eggGroups.entries)
        entry.key: entry.value.toList()..sort(),
    },
    'abilityPokemonIds': abilityPokemonIds,
    'moves': movesDecoded,
    'abilities': abilitiesDecoded,
  };
}

Set<int> _moveIdsFromDetailJson(Map<dynamic, dynamic> detail) {
  final result = <int>{};

  void collect(Object? rawMoveSet) {
    if (rawMoveSet is! Map) {
      return;
    }
    for (final key in const ['levelUp', 'machine', 'egg', 'tutor']) {
      final refs = rawMoveSet[key];
      if (refs is! List) {
        continue;
      }
      for (final ref in refs) {
        if (ref is Map && ref['moveId'] is num) {
          result.add((ref['moveId'] as num).toInt());
        }
      }
    }
  }

  collect(detail['moveSet']);
  final moveSets = detail['moveSets'];
  if (moveSets is Map) {
    for (final moveSet in moveSets.values) {
      collect(moveSet);
    }
  }
  return result;
}
