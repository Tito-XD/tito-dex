import 'type_chart.dart';

// HGSS national dex scope (Gen IV).
const hgssMaxNationalDexId = 493;

// Data models for the national dex backed by PokeAPI.
class PokemonSummary {
  const PokemonSummary({
    required this.id,
    required this.nameEn,
    required this.nameZh,
    required this.types,
    this.spriteUrl,
    this.localSpritePath,
  });

  final int id;
  final String nameEn;
  final String nameZh;
  final List<String> types;
  final String? spriteUrl;
  final String? localSpritePath;

  String get typesLabel => types.map(typeNameZh).join('/');

  String? get displaySpritePath => localSpritePath ?? spriteUrl;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nameEn': nameEn,
        'nameZh': nameZh,
        'types': types,
        if (spriteUrl != null) 'spriteUrl': spriteUrl,
        if (localSpritePath != null) 'localSpritePath': localSpritePath,
      };

  factory PokemonSummary.fromJson(Map<String, dynamic> json) => PokemonSummary(
        id: json['id'] as int,
        nameEn: json['nameEn'] as String,
        nameZh: json['nameZh'] as String,
        types: (json['types'] as List<dynamic>).cast<String>(),
        spriteUrl: json['spriteUrl'] as String?,
        localSpritePath: json['localSpritePath'] as String?,
      );

  PokemonSummary copyWith({
    String? spriteUrl,
    String? localSpritePath,
  }) {
    return PokemonSummary(
      id: id,
      nameEn: nameEn,
      nameZh: nameZh,
      types: types,
      spriteUrl: spriteUrl ?? this.spriteUrl,
      localSpritePath: localSpritePath ?? this.localSpritePath,
    );
  }
}

enum DexEncounterStatus {
  caught,
  seen,
  unknown,
}

class CachedMove {
  const CachedMove({
    required this.id,
    required this.nameEn,
    required this.nameZh,
    required this.type,
    required this.category,
    this.power,
    this.accuracy,
    this.pp,
  });

  final int id;
  final String nameEn;
  final String nameZh;
  final String type;
  final String category;
  final int? power;
  final int? accuracy;
  final int? pp;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nameEn': nameEn,
        'nameZh': nameZh,
        'type': type,
        'category': category,
        if (power != null) 'power': power,
        if (accuracy != null) 'accuracy': accuracy,
        if (pp != null) 'pp': pp,
      };

  factory CachedMove.fromJson(Map<String, dynamic> json) => CachedMove(
        id: json['id'] as int,
        nameEn: json['nameEn'] as String,
        nameZh: json['nameZh'] as String,
        type: json['type'] as String,
        category: json['category'] as String,
        power: json['power'] as int?,
        accuracy: json['accuracy'] as int?,
        pp: json['pp'] as int?,
      );
}

class PokemonMoveRef {
  const PokemonMoveRef({
    required this.moveId,
    required this.method,
    this.level,
  });

  final int moveId;
  final String method;
  final int? level;

  Map<String, dynamic> toJson() => {
        'moveId': moveId,
        'method': method,
        if (level != null) 'level': level,
      };

  factory PokemonMoveRef.fromJson(Map<String, dynamic> json) => PokemonMoveRef(
        moveId: json['moveId'] as int,
        method: json['method'] as String,
        level: json['level'] as int?,
      );
}

class PokemonMove {
  const PokemonMove({
    required this.move,
    required this.method,
    this.level,
  });

  final CachedMove move;
  final String method;
  final int? level;
}

class PokemonDetail {
  const PokemonDetail({
    required this.summary,
    required this.genusZh,
    required this.heightDm,
    required this.weightHg,
    required this.weaknesses,
    required this.resistances,
    required this.immunities,
    required this.stabSuperEffective,
    required this.evolutionChain,
    this.moves = const [],
  });

  final PokemonSummary summary;
  final String genusZh;
  final int heightDm;
  final int weightHg;
  final List<String> weaknesses;
  final List<String> resistances;
  final List<String> immunities;
  final List<String> stabSuperEffective;
  final EvolutionNode? evolutionChain;
  final List<PokemonMove> moves;

  Map<String, dynamic> toJson() => {
        'summary': summary.toJson(),
        'genusZh': genusZh,
        'heightDm': heightDm,
        'weightHg': weightHg,
        'weaknesses': weaknesses,
        'resistances': resistances,
        'immunities': immunities,
        'stabSuperEffective': stabSuperEffective,
        if (evolutionChain != null)
          'evolutionChain': evolutionChain!.toJson(),
        'moves': moves
            .map(
              (entry) => {
                'moveId': entry.move.id,
                'method': entry.method,
                if (entry.level != null) 'level': entry.level,
              },
            )
            .toList(),
      };

  factory PokemonDetail.fromJson(
    Map<String, dynamic> json, {
    required Map<int, CachedMove> moveLookup,
  }) {
    final moveRefs = (json['moves'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final moves = <PokemonMove>[];
    for (final ref in moveRefs) {
      final moveId = ref['moveId'] as int;
      final move = moveLookup[moveId];
      if (move == null) {
        continue;
      }
      moves.add(
        PokemonMove(
          move: move,
          method: ref['method'] as String,
          level: ref['level'] as int?,
        ),
      );
    }

    return PokemonDetail(
      summary: PokemonSummary.fromJson(
        json['summary'] as Map<String, dynamic>,
      ),
      genusZh: json['genusZh'] as String? ?? '',
      heightDm: json['heightDm'] as int? ?? 0,
      weightHg: json['weightHg'] as int? ?? 0,
      weaknesses: (json['weaknesses'] as List<dynamic>? ?? const [])
          .cast<String>(),
      resistances: (json['resistances'] as List<dynamic>? ?? const [])
          .cast<String>(),
      immunities: (json['immunities'] as List<dynamic>? ?? const [])
          .cast<String>(),
      stabSuperEffective:
          (json['stabSuperEffective'] as List<dynamic>? ?? const [])
              .cast<String>(),
      evolutionChain: json['evolutionChain'] == null
          ? null
          : EvolutionNode.fromJson(json['evolutionChain'] as Map<String, dynamic>),
      moves: moves,
    );
  }
}

class EvolutionNode {
  const EvolutionNode({
    required this.id,
    required this.nameEn,
    required this.nameZh,
    this.spriteUrl,
    this.localSpritePath,
    this.evolvesFrom,
    this.triggerZh,
    this.children = const [],
  });

  final int id;
  final String nameEn;
  final String nameZh;
  final String? spriteUrl;
  final String? localSpritePath;
  final String? evolvesFrom;
  final String? triggerZh;
  final List<EvolutionNode> children;

  String? get displaySpritePath => localSpritePath ?? spriteUrl;

  bool containsId(int pokemonId) {
    if (id == pokemonId) {
      return true;
    }
    return children.any((child) => child.containsId(pokemonId));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nameEn': nameEn,
        'nameZh': nameZh,
        if (spriteUrl != null) 'spriteUrl': spriteUrl,
        if (localSpritePath != null) 'localSpritePath': localSpritePath,
        if (evolvesFrom != null) 'evolvesFrom': evolvesFrom,
        if (triggerZh != null) 'triggerZh': triggerZh,
        'children': children.map((child) => child.toJson()).toList(),
      };

  factory EvolutionNode.fromJson(Map<String, dynamic> json) => EvolutionNode(
        id: json['id'] as int,
        nameEn: json['nameEn'] as String,
        nameZh: json['nameZh'] as String,
        spriteUrl: json['spriteUrl'] as String?,
        localSpritePath: json['localSpritePath'] as String?,
        evolvesFrom: json['evolvesFrom'] as String?,
        triggerZh: json['triggerZh'] as String?,
        children: (json['children'] as List<dynamic>? ?? const [])
            .map((item) => EvolutionNode.fromJson(item as Map<String, dynamic>))
            .toList(),
      );

  EvolutionNode copyWithLocalSprite(String path) {
    return EvolutionNode(
      id: id,
      nameEn: nameEn,
      nameZh: nameZh,
      spriteUrl: spriteUrl,
      localSpritePath: path,
      evolvesFrom: evolvesFrom,
      triggerZh: triggerZh,
      children: children,
    );
  }
}

class DexCacheManifest {
  const DexCacheManifest({
    required this.version,
    required this.complete,
    required this.preferOffline,
    this.downloadedAt,
    this.pokemonCount = 0,
    this.moveCount = 0,
    this.sizeBytes = 0,
  });

  static const currentVersion = 1;

  final int version;
  final bool complete;
  final bool preferOffline;
  final String? downloadedAt;
  final int pokemonCount;
  final int moveCount;
  final int sizeBytes;

  Map<String, dynamic> toJson() => {
        'version': version,
        'complete': complete,
        'preferOffline': preferOffline,
        if (downloadedAt != null) 'downloadedAt': downloadedAt,
        'pokemonCount': pokemonCount,
        'moveCount': moveCount,
        'sizeBytes': sizeBytes,
      };

  factory DexCacheManifest.fromJson(Map<String, dynamic> json) =>
      DexCacheManifest(
        version: json['version'] as int? ?? 1,
        complete: json['complete'] as bool? ?? false,
        preferOffline: json['preferOffline'] as bool? ?? true,
        downloadedAt: json['downloadedAt'] as String?,
        pokemonCount: json['pokemonCount'] as int? ?? 0,
        moveCount: json['moveCount'] as int? ?? 0,
        sizeBytes: json['sizeBytes'] as int? ?? 0,
      );
}

class DexCacheProgress {
  const DexCacheProgress({
    required this.phase,
    required this.current,
    required this.total,
    this.label,
  });

  final String phase;
  final int current;
  final int total;
  final String? label;

  double get fraction => total == 0 ? 0 : current / total;
}

class DexCacheStatus {
  const DexCacheStatus({
    required this.manifest,
    required this.sizeBytes,
    required this.isDownloading,
    this.progress,
  });

  final DexCacheManifest manifest;
  final int sizeBytes;
  final bool isDownloading;
  final DexCacheProgress? progress;
}
