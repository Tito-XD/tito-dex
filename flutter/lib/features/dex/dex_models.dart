import 'dex_game_scope.dart';
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

class PokemonBaseStats {
  const PokemonBaseStats({
    required this.hp,
    required this.attack,
    required this.defense,
    required this.specialAttack,
    required this.specialDefense,
    required this.speed,
  });

  final int hp;
  final int attack;
  final int defense;
  final int specialAttack;
  final int specialDefense;
  final int speed;

  int get total =>
      hp + attack + defense + specialAttack + specialDefense + speed;

  Map<String, dynamic> toJson() => {
        'hp': hp,
        'attack': attack,
        'defense': defense,
        'specialAttack': specialAttack,
        'specialDefense': specialDefense,
        'speed': speed,
      };

  factory PokemonBaseStats.fromJson(Map<String, dynamic> json) =>
      PokemonBaseStats(
        hp: json['hp'] as int,
        attack: json['attack'] as int,
        defense: json['defense'] as int,
        specialAttack: json['specialAttack'] as int,
        specialDefense: json['specialDefense'] as int,
        speed: json['speed'] as int,
      );

  List<MapEntry<String, int>> get entries => [
        MapEntry('hp', hp),
        MapEntry('attack', attack),
        MapEntry('defense', defense),
        MapEntry('special-attack', specialAttack),
        MapEntry('special-defense', specialDefense),
        MapEntry('speed', speed),
      ];
}

class FlavorTextEntry {
  const FlavorTextEntry({
    required this.version,
    required this.text,
  });

  final String version;
  final String text;

  Map<String, dynamic> toJson() => {
        'version': version,
        'text': text,
      };

  factory FlavorTextEntry.fromJson(Map<String, dynamic> json) =>
      FlavorTextEntry(
        version: json['version'] as String,
        text: json['text'] as String,
      );
}

class ObtainLocationEntry {
  const ObtainLocationEntry({
    required this.areaSlug,
    required this.areaLabelZh,
    this.minLevel,
    this.maxChance = 0,
  });

  final String areaSlug;
  final String areaLabelZh;
  final int? minLevel;
  final int maxChance;

  Map<String, dynamic> toJson() => {
        'areaSlug': areaSlug,
        'areaLabelZh': areaLabelZh,
        if (minLevel != null) 'minLevel': minLevel,
        'maxChance': maxChance,
      };

  factory ObtainLocationEntry.fromJson(Map<String, dynamic> json) =>
      ObtainLocationEntry(
        areaSlug: json['areaSlug'] as String,
        areaLabelZh: json['areaLabelZh'] as String? ??
            encounterAreaLabelZh(json['areaSlug'] as String),
        minLevel: json['minLevel'] as int?,
        maxChance: json['maxChance'] as int? ?? 0,
      );
}

class PokemonMoveSet {
  const PokemonMoveSet({
    this.levelUp = const [],
    this.machine = const [],
    this.egg = const [],
  });

  final List<PokemonMove> levelUp;
  final List<PokemonMove> machine;
  final List<PokemonMove> egg;

  Map<String, dynamic> toJson() => {
        'levelUp': _refs(levelUp),
        'machine': _refs(machine),
        'egg': _refs(egg),
      };

  static List<Map<String, dynamic>> _refs(List<PokemonMove> moves) => moves
      .map(
        (entry) => {
          'moveId': entry.move.id,
          'method': entry.method,
          if (entry.level != null) 'level': entry.level,
        },
      )
      .toList();

  factory PokemonMoveSet.fromJson(
    Map<String, dynamic> json, {
    required Map<int, CachedMove> moveLookup,
  }) {
    List<PokemonMove> parseList(String key) {
      final refs = (json[key] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();
      final moves = <PokemonMove>[];
      for (final ref in refs) {
        final move = moveLookup[ref['moveId'] as int];
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
      return moves;
    }

    return PokemonMoveSet(
      levelUp: parseList('levelUp'),
      machine: parseList('machine'),
      egg: parseList('egg'),
    );
  }

  Iterable<CachedMove> get allMoves sync* {
    for (final entry in levelUp) {
      yield entry.move;
    }
    for (final entry in machine) {
      yield entry.move;
    }
    for (final entry in egg) {
      yield entry.move;
    }
  }
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
    this.johtoDexNumber,
    this.baseStats,
    this.typeMultipliers = const {},
    this.flavorEntries = const [],
    this.obtainLocations = const [],
    this.moveSet = const PokemonMoveSet(),
    this.genderFemalePercent,
    this.eggGroups = const [],
    this.hatchCounter,
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
  final int? johtoDexNumber;
  final PokemonBaseStats? baseStats;
  final Map<String, double> typeMultipliers;
  final List<FlavorTextEntry> flavorEntries;
  final List<ObtainLocationEntry> obtainLocations;
  final PokemonMoveSet moveSet;
  final double? genderFemalePercent;
  final List<String> eggGroups;
  final int? hatchCounter;

  int get hatchSteps => hatchCounter == null ? 0 : hatchCounter! * 256;

  String get nationalDexLabel =>
      '#${summary.id.toString().padLeft(3, '0')}';

  String? get johtoDexLabel => johtoDexNumber == null
      ? null
      : '城都 #${johtoDexNumber!.toString().padLeft(3, '0')}';

  Map<String, dynamic> toJson() => {
        'summary': summary.toJson(),
        'genusZh': genusZh,
        'heightDm': heightDm,
        'weightHg': weightHg,
        'weaknesses': weaknesses,
        'resistances': resistances,
        'immunities': immunities,
        'stabSuperEffective': stabSuperEffective,
        if (johtoDexNumber != null) 'johtoDexNumber': johtoDexNumber,
        if (baseStats != null) 'baseStats': baseStats!.toJson(),
        'typeMultipliers': typeMultipliers.map(
          (key, value) => MapEntry(key, value),
        ),
        'flavorEntries':
            flavorEntries.map((entry) => entry.toJson()).toList(),
        'obtainLocations':
            obtainLocations.map((entry) => entry.toJson()).toList(),
        'moveSet': moveSet.toJson(),
        if (genderFemalePercent != null)
          'genderFemalePercent': genderFemalePercent,
        'eggGroups': eggGroups,
        if (hatchCounter != null) 'hatchCounter': hatchCounter,
        if (evolutionChain != null)
          'evolutionChain': evolutionChain!.toJson(),
      };

  factory PokemonDetail.fromJson(
    Map<String, dynamic> json, {
    required Map<int, CachedMove> moveLookup,
  }) {
    final moveSetJson = json['moveSet'] as Map<String, dynamic>?;
    final moveSet = moveSetJson == null
        ? const PokemonMoveSet()
        : PokemonMoveSet.fromJson(moveSetJson, moveLookup: moveLookup);

    final legacyMoves = <PokemonMove>[];
    final moveRefs = (json['moves'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    for (final ref in moveRefs) {
      final move = moveLookup[ref['moveId'] as int];
      if (move == null) {
        continue;
      }
      legacyMoves.add(
        PokemonMove(
          move: move,
          method: ref['method'] as String,
          level: ref['level'] as int?,
        ),
      );
    }

    final typeMultiplierJson =
        json['typeMultipliers'] as Map<String, dynamic>? ?? const {};
    final typeMultipliers = typeMultiplierJson.map(
      (key, value) => MapEntry(key, (value as num).toDouble()),
    );

    var resolvedMoveSet = moveSet;
    if (resolvedMoveSet.levelUp.isEmpty &&
        resolvedMoveSet.machine.isEmpty &&
        resolvedMoveSet.egg.isEmpty &&
        legacyMoves.isNotEmpty) {
      resolvedMoveSet = PokemonMoveSet(levelUp: legacyMoves);
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
      johtoDexNumber: json['johtoDexNumber'] as int?,
      baseStats: json['baseStats'] == null
          ? null
          : PokemonBaseStats.fromJson(
              json['baseStats'] as Map<String, dynamic>,
            ),
      typeMultipliers: typeMultipliers,
      flavorEntries: (json['flavorEntries'] as List<dynamic>? ?? const [])
          .map((item) => FlavorTextEntry.fromJson(item as Map<String, dynamic>))
          .toList(),
      obtainLocations: (json['obtainLocations'] as List<dynamic>? ?? const [])
          .map(
            (item) => ObtainLocationEntry.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      moveSet: resolvedMoveSet,
      genderFemalePercent: (json['genderFemalePercent'] as num?)?.toDouble(),
      eggGroups:
          (json['eggGroups'] as List<dynamic>? ?? const []).cast<String>(),
      hatchCounter: json['hatchCounter'] as int?,
      evolutionChain: json['evolutionChain'] == null
          ? null
          : EvolutionNode.fromJson(json['evolutionChain'] as Map<String, dynamic>),
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

  static const currentVersion = 2;

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
