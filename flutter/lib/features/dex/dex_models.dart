import 'dex_game_scope.dart';
import 'form_evolution_targets.dart';
import 'type_chart.dart';

// HGSS-era national dex cap (Gen IV); browse extends to [titodexMaxNationalDexId].
const hgssMaxNationalDexId = 493;

/// Gen IX national dex upper bound for TitoDex browse.
const titodexMaxNationalDexId = 1025;

// Data models for the national dex backed by PokeAPI.
class PokemonSummary {
  const PokemonSummary({
    required this.id,
    required this.nameEn,
    required this.nameZh,
    required this.types,
    this.spriteUrl,
    this.artworkUrl,
    this.localSpritePath,
    this.pokedexNumbers,
    this.spriteUrlsByVersion = const {},
    this.animatedSpriteUrl,
    this.spriteResourceId,
    this.formSearchTerms = const [],
    this.genusZh,
    this.generation,
    this.shapeSlug,
    this.colorSlug,
    this.tags = const [],
    this.heightDm,
  });

  final int id;
  final String nameEn;
  final String nameZh;
  final List<String> types;
  final String? spriteUrl;
  final String? artworkUrl;
  final String? localSpritePath;
  final Map<String, int>? pokedexNumbers;

  /// CDN URLs keyed by PokeAPI version-group slug (e.g. heartgold-soulsilver).
  final Map<String, String>? spriteUrlsByVersion;
  final String? animatedSpriteUrl;

  /// PokeAPI Pokémon entity used for form-specific sprite history.
  ///
  /// The national dex [id] remains the species id so navigation, evolution
  /// highlighting, and progress continue to work when a form is selected.
  final int? spriteResourceId;

  /// Alternate-form names/slugs folded into species-level dex search.
  final List<String> formSearchTerms;

  /// Pokédex genus ("种子宝可梦"). Lives on the summary — not the detail — so
  /// search can match it without walking 1025 detail files.
  final String? genusZh;

  /// Generation the species debuted in (1–9); drives 「本世代新增」 dex views.
  final int? generation;

  /// Body style / colour from the in-game Pokédex search (`quadruped`, `green`).
  final String? shapeSlug;
  final String? colorSlug;

  /// Semantic tags resolved by search aliases: `legendary`, `mythical`,
  /// `baby`, `pseudo-legendary`.
  final List<String> tags;

  /// Height in decimetres. Duplicated from the detail onto the summary so the
  /// relative-size axis can filter without opening 1025 detail files — the same
  /// reason [genusZh] lives here.
  final int? heightDm;

  String get typesLabel => types.map(typeNameZh).join('/');

  String? spriteUrlForVersionGroup(String versionGroup) =>
      spriteUrlsByVersion?[versionGroup] ?? spriteUrl;

  String? get displaySpritePath => localSpritePath ?? spriteUrl;

  /// Prefer the clear official-artwork asset; fall back to remote sprite or the
  /// bundled local sprite. Used by detail headers and companion media.
  String? get displayArtworkPath => artworkUrl ?? spriteUrl ?? localSpritePath;

  Map<String, dynamic> toJson() => {
    'id': id,
    'nameEn': nameEn,
    'nameZh': nameZh,
    'types': types,
    if (spriteUrl != null) 'spriteUrl': spriteUrl,
    if (artworkUrl != null) 'artworkUrl': artworkUrl,
    if (localSpritePath != null) 'localSpritePath': localSpritePath,
    if (pokedexNumbers != null && pokedexNumbers!.isNotEmpty)
      'pokedexNumbers': pokedexNumbers,
    if (spriteUrlsByVersion != null && spriteUrlsByVersion!.isNotEmpty)
      'spriteUrlsByVersion': spriteUrlsByVersion,
    if (animatedSpriteUrl != null) 'animatedSpriteUrl': animatedSpriteUrl,
    if (spriteResourceId != null) 'spriteResourceId': spriteResourceId,
    if (formSearchTerms.isNotEmpty) 'formSearchTerms': formSearchTerms,
    if (genusZh != null) 'genusZh': genusZh,
    if (generation != null) 'generation': generation,
    if (shapeSlug != null) 'shapeSlug': shapeSlug,
    if (colorSlug != null) 'colorSlug': colorSlug,
    if (tags.isNotEmpty) 'tags': tags,
    if (heightDm != null) 'heightDm': heightDm,
  };

  factory PokemonSummary.fromJson(Map<String, dynamic> json) {
    final pokedexRaw = json['pokedexNumbers'] as Map<String, dynamic>?;
    final pokedexNumbers = pokedexRaw?.map(
      (key, value) => MapEntry(key, (value as num).toInt()),
    );
    final spriteMapRaw = json['spriteUrlsByVersion'] as Map<String, dynamic>?;
    final spriteUrlsByVersion = spriteMapRaw?.map(
      (key, value) => MapEntry(key, value as String),
    );

    return PokemonSummary(
      id: json['id'] as int,
      nameEn: json['nameEn'] as String,
      nameZh: json['nameZh'] as String,
      types: (json['types'] as List<dynamic>).cast<String>(),
      spriteUrl: json['spriteUrl'] as String?,
      artworkUrl: json['artworkUrl'] as String?,
      localSpritePath: json['localSpritePath'] as String?,
      pokedexNumbers: pokedexNumbers,
      spriteUrlsByVersion: spriteUrlsByVersion,
      animatedSpriteUrl: json['animatedSpriteUrl'] as String?,
      spriteResourceId: (json['spriteResourceId'] as num?)?.toInt(),
      formSearchTerms: (json['formSearchTerms'] as List<dynamic>? ?? const [])
          .cast<String>(),
      genusZh: json['genusZh'] as String?,
      generation: (json['generation'] as num?)?.toInt(),
      shapeSlug: json['shapeSlug'] as String?,
      colorSlug: json['colorSlug'] as String?,
      tags: (json['tags'] as List<dynamic>? ?? const []).cast<String>(),
      heightDm: (json['heightDm'] as num?)?.toInt(),
    );
  }

  PokemonSummary copyWith({
    String? spriteUrl,
    String? artworkUrl,
    String? localSpritePath,
    Map<String, int>? pokedexNumbers,
    Map<String, String>? spriteUrlsByVersion,
    String? animatedSpriteUrl,
    int? spriteResourceId,
    List<String>? formSearchTerms,
    String? genusZh,
    int? generation,
    String? shapeSlug,
    String? colorSlug,
    List<String>? tags,
    int? heightDm,
  }) {
    return PokemonSummary(
      id: id,
      nameEn: nameEn,
      nameZh: nameZh,
      types: types,
      spriteUrl: spriteUrl ?? this.spriteUrl,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      localSpritePath: localSpritePath ?? this.localSpritePath,
      pokedexNumbers: pokedexNumbers ?? this.pokedexNumbers,
      spriteUrlsByVersion: spriteUrlsByVersion ?? this.spriteUrlsByVersion,
      animatedSpriteUrl: animatedSpriteUrl ?? this.animatedSpriteUrl,
      spriteResourceId: spriteResourceId ?? this.spriteResourceId,
      formSearchTerms: formSearchTerms ?? this.formSearchTerms,
      genusZh: genusZh ?? this.genusZh,
      generation: generation ?? this.generation,
      shapeSlug: shapeSlug ?? this.shapeSlug,
      colorSlug: colorSlug ?? this.colorSlug,
      tags: tags ?? this.tags,
      heightDm: heightDm ?? this.heightDm,
    );
  }
}

enum DexEncounterStatus { caught, seen, unknown }

class CachedAbility {
  const CachedAbility({
    required this.id,
    required this.nameEn,
    required this.nameZh,
    required this.descriptionZh,
    this.pokemonIds = const [],
  });

  final int id;
  final String nameEn;
  final String nameZh;
  final String descriptionZh;
  final List<int> pokemonIds;

  Map<String, dynamic> toJson() => {
    'id': id,
    'nameEn': nameEn,
    'nameZh': nameZh,
    'descriptionZh': descriptionZh,
    if (pokemonIds.isNotEmpty) 'pokemonIds': pokemonIds,
  };

  factory CachedAbility.fromJson(
    Map<String, dynamic> json, {
    int? fallbackId,
  }) => CachedAbility(
    id: json['id'] as int? ?? fallbackId ?? 0,
    nameEn: json['nameEn'] as String,
    nameZh: json['nameZh'] as String,
    descriptionZh: json['descriptionZh'] as String? ?? '',
    pokemonIds: (json['pokemonIds'] as List<dynamic>? ?? const [])
        .map((value) => (value as num).toInt())
        .toList(growable: false),
  );
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
    this.descriptionZh,
  });

  final int id;
  final String nameEn;
  final String nameZh;
  final String type;
  final String category;
  final int? power;
  final int? accuracy;
  final int? pp;
  final String? descriptionZh;

  Map<String, dynamic> toJson() => {
    'id': id,
    'nameEn': nameEn,
    'nameZh': nameZh,
    'type': type,
    'category': category,
    if (power != null) 'power': power,
    if (accuracy != null) 'accuracy': accuracy,
    if (pp != null) 'pp': pp,
    if (descriptionZh != null) 'descriptionZh': descriptionZh,
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
    descriptionZh: json['descriptionZh'] as String?,
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
  const PokemonMove({required this.move, required this.method, this.level});

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
    this.gameEdition,
    this.versionGroup,
    this.labelZh,
    this.iconUrl,
  });

  final String version;
  final String text;
  final String? gameEdition;
  final String? versionGroup;
  final String? labelZh;
  final String? iconUrl;

  /// Carousel title — per-game version when known (e.g. 晶灿钻石 vs 明亮珍珠).
  /// Edition picker still uses combined [labelZh] / [GameEdition.labelZh].
  String get displayLabel {
    if (flavorVersionHasLabel(version)) {
      return flavorVersionLabelZh(version);
    }
    return labelZh ?? flavorVersionLabelZh(version);
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'text': text,
    if (gameEdition != null) 'gameEdition': gameEdition,
    if (versionGroup != null) 'versionGroup': versionGroup,
    if (labelZh != null) 'labelZh': labelZh,
    if (iconUrl != null) 'iconUrl': iconUrl,
  };

  factory FlavorTextEntry.fromJson(Map<String, dynamic> json) =>
      FlavorTextEntry(
        version:
            json['version'] as String? ??
            json['gameEdition'] as String? ??
            'unknown',
        text: json['text'] as String,
        gameEdition: json['gameEdition'] as String?,
        versionGroup: json['versionGroup'] as String?,
        labelZh: json['labelZh'] as String?,
        iconUrl: json['iconUrl'] as String?,
      );
}

class PokemonAbility {
  const PokemonAbility({
    required this.nameEn,
    required this.nameZh,
    required this.descriptionZh,
    this.isHidden = false,
    this.gameLabelsZh = const [],
  });

  final String nameEn;
  final String nameZh;
  final String descriptionZh;
  final bool isHidden;

  /// Human-readable game edition labels where this ability appears (e.g. 全版本).
  final List<String> gameLabelsZh;

  String get displayNameZh {
    if (gameLabelsZh.isEmpty) {
      return nameZh;
    }
    return '$nameZh（${gameLabelsZh.join('、')}）';
  }

  Map<String, dynamic> toJson() => {
    'nameEn': nameEn,
    'nameZh': nameZh,
    'descriptionZh': descriptionZh,
    if (isHidden) 'isHidden': true,
    if (gameLabelsZh.isNotEmpty) 'gameLabelsZh': gameLabelsZh,
  };

  factory PokemonAbility.fromJson(Map<String, dynamic> json) => PokemonAbility(
    nameEn: json['nameEn'] as String,
    nameZh: json['nameZh'] as String,
    descriptionZh: json['descriptionZh'] as String? ?? '',
    isHidden: json['isHidden'] as bool? ?? false,
    gameLabelsZh: (json['gameLabelsZh'] as List<dynamic>? ?? const [])
        .cast<String>(),
  );

  PokemonAbility copyWith({
    String? nameEn,
    String? nameZh,
    String? descriptionZh,
    bool? isHidden,
    List<String>? gameLabelsZh,
  }) {
    return PokemonAbility(
      nameEn: nameEn ?? this.nameEn,
      nameZh: nameZh ?? this.nameZh,
      descriptionZh: descriptionZh ?? this.descriptionZh,
      isHidden: isHidden ?? this.isHidden,
      gameLabelsZh: gameLabelsZh ?? this.gameLabelsZh,
    );
  }
}

class ObtainLocationEntry {
  const ObtainLocationEntry({
    required this.areaSlug,
    required this.areaLabelZh,
    this.pokemonId,
    this.speciesId,
    String? formKey,
    String? formSlug,
    this.isDefaultForm,
    this.teraType,
    this.isAlpha = false,
    this.isTitan = false,
    this.isTotem = false,
    this.isRaid = false,
    this.isFixedEncounter = false,
    this.formAmbiguous = false,
    this.minLevel,
    this.maxLevel,
    this.maxChance = 0,
    this.rateKind = 'percentage',
    this.rateValue,
    this.versions = const [],
    this.methods = const [],
    this.conditions = const [],
  }) : formKey = formKey ?? formSlug;

  final String areaSlug;
  final String areaLabelZh;
  final int? pokemonId;
  final int? speciesId;
  final String? formKey;
  @Deprecated('Use formKey')
  String? get formSlug => formKey;
  final bool? isDefaultForm;
  final String? teraType;
  final bool isAlpha;
  final bool isTitan;
  final bool isTotem;
  final bool isRaid;
  final bool isFixedEncounter;
  final bool formAmbiguous;
  final int? minLevel;
  final int? maxLevel;
  final int maxChance;
  final String rateKind;
  final num? rateValue;
  final List<String> versions;
  final List<String> methods;
  final List<String> conditions;

  Map<String, dynamic> toJson() => {
    'areaSlug': areaSlug,
    'areaLabelZh': areaLabelZh,
    if (pokemonId != null) 'pokemonId': pokemonId,
    if (speciesId != null) 'speciesId': speciesId,
    if (formKey != null) 'formKey': formKey,
    if (isDefaultForm != null) 'isDefaultForm': isDefaultForm,
    if (teraType != null) 'teraType': teraType,
    if (isAlpha) 'isAlpha': true,
    if (isTitan) 'isTitan': true,
    if (isTotem) 'isTotem': true,
    if (isRaid) 'isRaid': true,
    if (isFixedEncounter) 'isFixedEncounter': true,
    if (formAmbiguous) 'formAmbiguous': true,
    if (minLevel != null) 'minLevel': minLevel,
    if (maxLevel != null) 'maxLevel': maxLevel,
    'maxChance': maxChance,
    'rateKind': rateKind,
    if (rateValue != null) 'rateValue': rateValue,
    if (versions.isNotEmpty) 'versions': versions,
    if (methods.isNotEmpty) 'methods': methods,
    if (conditions.isNotEmpty) 'conditions': conditions,
  };

  factory ObtainLocationEntry.fromJson(Map<String, dynamic> json) {
    final slug = json['areaSlug'] as String;
    final baked = json['areaLabelZh'] as String?;
    // v0.6.7: bundles baked raw location-area ids as labels for areas the
    // build-time catalog missed (e.g. "290"); treat numeric or slug-echo
    // labels as unresolved and re-resolve against the fuller zh catalogs.
    final unresolved =
        baked == null ||
        baked == slug ||
        RegExp(r'^\d+$').hasMatch(baked) ||
        RegExp(r'^地点 \d+$').hasMatch(baked);
    return ObtainLocationEntry(
      areaSlug: slug,
      areaLabelZh: unresolved ? resolveObtainAreaLabelZh(slug) : baked,
      pokemonId: (json['pokemonId'] as num?)?.toInt(),
      speciesId: (json['speciesId'] as num?)?.toInt(),
      formKey: (json['formKey'] ?? json['formSlug']) as String?,
      isDefaultForm: json['isDefaultForm'] as bool?,
      teraType: json['teraType'] as String?,
      isAlpha: json['isAlpha'] as bool? ?? false,
      isTitan: json['isTitan'] as bool? ?? false,
      isTotem: json['isTotem'] as bool? ?? false,
      isRaid: json['isRaid'] as bool? ?? false,
      isFixedEncounter: json['isFixedEncounter'] as bool? ?? false,
      formAmbiguous:
          json['formAmbiguous'] as bool? ??
          (json['formKey'] == null &&
              json['formSlug'] == null &&
              json['pokemonId'] == null),
      minLevel: (json['minLevel'] as num?)?.toInt(),
      maxLevel: (json['maxLevel'] as num?)?.toInt(),
      maxChance: (json['maxChance'] as num?)?.toInt() ?? 0,
      rateKind: json['rateKind'] as String? ?? 'percentage',
      rateValue: json['rateValue'] as num?,
      versions: (json['versions'] as List<dynamic>? ?? const []).cast<String>(),
      methods: (json['methods'] as List<dynamic>? ?? const []).cast<String>(),
      conditions: (json['conditions'] as List<dynamic>? ?? const [])
          .cast<String>(),
    );
  }
}

class PokemonMoveSet {
  const PokemonMoveSet({
    this.levelUp = const [],
    this.machine = const [],
    this.egg = const [],
    this.tutor = const [],
  });

  final List<PokemonMove> levelUp;
  final List<PokemonMove> machine;
  final List<PokemonMove> egg;
  final List<PokemonMove> tutor;

  Map<String, dynamic> toJson() => {
    'levelUp': _refs(levelUp),
    'machine': _refs(machine),
    'egg': _refs(egg),
    'tutor': _refs(tutor),
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
        final moveId = (ref['moveId'] as num?)?.toInt();
        if (moveId == null) {
          continue;
        }
        final move =
            moveLookup[moveId] ??
            CachedMove(
              id: moveId,
              nameEn: 'move-$moveId',
              nameZh: '招式 #$moveId',
              type: 'normal',
              category: 'status',
            );
        moves.add(
          PokemonMove(
            move: move,
            method: ref['method'] as String? ?? key,
            level: (ref['level'] as num?)?.toInt(),
          ),
        );
      }
      return moves;
    }

    return PokemonMoveSet(
      levelUp: parseList('levelUp'),
      machine: parseList('machine'),
      egg: parseList('egg'),
      tutor: parseList('tutor'),
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
    for (final entry in tutor) {
      yield entry.move;
    }
  }
}

enum PokemonFormKind {
  regional,
  mega,
  gigantamax,
  battle,
  form,
  cosmetic;

  String get labelZh => switch (this) {
    regional => '地区形态',
    mega => '超级进化',
    gigantamax => '超极巨化',
    battle => '战斗形态',
    form => '特殊形态',
    cosmetic => '外观形态',
  };

  static PokemonFormKind parse(String? value) => values.firstWhere(
    (kind) => kind.name == value,
    orElse: () => PokemonFormKind.form,
  );
}

/// A PokeAPI Pokemon variety nested under one National Dex species.
///
/// Universal states (ordinary Dynamax and an arbitrary Tera Type) deliberately
/// do not become records here. Forms which change type, stats, abilities,
/// learnset, dimensions, encounter data, or artwork do.
class PokemonFormDetail {
  const PokemonFormDetail({
    required this.key,
    required this.pokemonId,
    required this.nameEn,
    required this.nameZh,
    required this.kind,
    required this.isDefault,
    required this.isBattleOnly,
    required this.isMega,
    required this.isCosmetic,
    required this.types,
    required this.heightDm,
    required this.weightHg,
    this.formId,
    this.formNameZh,
    this.formGroup,
    this.introducedVersionGroup,
    this.availableVersionGroups = const [],
    this.obtainableVersionGroups = const [],
    this.obtainable = true,
    this.eventOnly = false,
    this.deprecated = false,
    this.inheritsFromDefault = false,
    this.dataCompleteness = 'unknown',
    this.sources = const [],
    this.spriteUrl,
    this.artworkUrl,
    this.localSpritePath,
    this.spriteUrlsByVersion = const {},
    this.animatedSpriteUrl,
    this.baseStats,
    this.typeMultipliers = const {},
    this.stabSuperEffective = const [],
    this.abilities = const [],
    this.abilitiesByGame = const {},
    this.obtainLocationsByGame = const {},
    this.obtainLocationsByVersion = const {},
    this.moveSets = const {},
    this.evolutionChain,
  });

  final String key;
  final int pokemonId;
  final int? formId;
  final String nameEn;
  final String nameZh;
  final String? formNameZh;
  final String? formGroup;
  final PokemonFormKind kind;
  final bool isDefault;
  final bool isBattleOnly;
  final bool isMega;
  final bool isCosmetic;
  final String? introducedVersionGroup;
  final List<String> availableVersionGroups;
  final List<String> obtainableVersionGroups;
  final bool obtainable;
  final bool eventOnly;
  final bool deprecated;
  final bool inheritsFromDefault;
  final String dataCompleteness;
  final List<String> sources;
  final List<String> types;
  final int heightDm;
  final int weightHg;
  final String? spriteUrl;
  final String? artworkUrl;
  final String? localSpritePath;
  final Map<String, String> spriteUrlsByVersion;
  final String? animatedSpriteUrl;
  final PokemonBaseStats? baseStats;
  final Map<String, double> typeMultipliers;
  final List<String> stabSuperEffective;
  final List<PokemonAbility> abilities;
  final Map<String, List<PokemonAbility>> abilitiesByGame;
  final Map<String, List<ObtainLocationEntry>> obtainLocationsByGame;
  final Map<String, List<ObtainLocationEntry>> obtainLocationsByVersion;
  final Map<String, PokemonMoveSet> moveSets;
  final EvolutionNode? evolutionChain;

  PokemonSummary summaryFor(PokemonSummary species) {
    final mayInheritAssets = isDefault || isCosmetic || inheritsFromDefault;
    final speciesVisuals = {species.artworkUrl, species.spriteUrl}
      ..removeWhere((source) => source == null);
    final hasOwnVisual =
        !isDefault &&
        (localSpritePath != null ||
            artworkUrl != null && !speciesVisuals.contains(artworkUrl) ||
            spriteUrl != null && !speciesVisuals.contains(spriteUrl));
    // Forms often ship a pixelated 96x96 in-game sprite as [spriteUrl] while
    // [artworkUrl] is the clear official-artwork asset. Prefer artwork so the
    // detail header matches the clear sprite shown in the artwork viewer.
    final inheritedSpriteUrl = mayInheritAssets && !hasOwnVisual
        ? species.spriteUrl
        : null;
    final inheritedArtworkUrl = mayInheritAssets && !hasOwnVisual
        ? species.artworkUrl
        : null;
    return PokemonSummary(
      id: species.id,
      nameEn: nameEn,
      nameZh: nameZh,
      types: types,
      spriteUrl: artworkUrl ?? spriteUrl ?? inheritedSpriteUrl,
      artworkUrl: artworkUrl ?? inheritedArtworkUrl,
      localSpritePath: localSpritePath,
      pokedexNumbers: species.pokedexNumbers,
      spriteUrlsByVersion: spriteUrlsByVersion.isNotEmpty
          ? spriteUrlsByVersion
          : (mayInheritAssets ? species.spriteUrlsByVersion : null),
      animatedSpriteUrl:
          animatedSpriteUrl ??
          (mayInheritAssets ? species.animatedSpriteUrl : null),
      spriteResourceId: pokemonId,
      formSearchTerms: species.formSearchTerms,
    );
  }

  PokemonFormDetail withLocalSpritePath(String? path) => _withResolvedAssets(
    localSpritePath: path,
    evolutionChain: evolutionChain,
  );

  PokemonFormDetail withEvolutionChain(EvolutionNode? chain) =>
      _withResolvedAssets(
        localSpritePath: localSpritePath,
        evolutionChain: chain,
      );

  PokemonFormDetail _withResolvedAssets({
    required String? localSpritePath,
    required EvolutionNode? evolutionChain,
  }) => PokemonFormDetail(
    key: key,
    pokemonId: pokemonId,
    formId: formId,
    nameEn: nameEn,
    nameZh: nameZh,
    formNameZh: formNameZh,
    formGroup: formGroup,
    kind: kind,
    isDefault: isDefault,
    isBattleOnly: isBattleOnly,
    isMega: isMega,
    isCosmetic: isCosmetic,
    introducedVersionGroup: introducedVersionGroup,
    availableVersionGroups: availableVersionGroups,
    obtainableVersionGroups: obtainableVersionGroups,
    obtainable: obtainable,
    eventOnly: eventOnly,
    deprecated: deprecated,
    inheritsFromDefault: inheritsFromDefault,
    dataCompleteness: dataCompleteness,
    sources: sources,
    types: types,
    heightDm: heightDm,
    weightHg: weightHg,
    spriteUrl: spriteUrl,
    artworkUrl: artworkUrl,
    localSpritePath: localSpritePath,
    spriteUrlsByVersion: spriteUrlsByVersion,
    animatedSpriteUrl: animatedSpriteUrl,
    baseStats: baseStats,
    typeMultipliers: typeMultipliers,
    stabSuperEffective: stabSuperEffective,
    abilities: abilities,
    abilitiesByGame: abilitiesByGame,
    obtainLocationsByGame: obtainLocationsByGame,
    obtainLocationsByVersion: obtainLocationsByVersion,
    moveSets: moveSets,
    evolutionChain: evolutionChain,
  );

  Map<String, dynamic> toJson() => {
    'key': key,
    'pokemonId': pokemonId,
    if (formId != null) 'formId': formId,
    'nameEn': nameEn,
    'nameZh': nameZh,
    if (formNameZh != null) 'formNameZh': formNameZh,
    if (formGroup != null) 'formGroup': formGroup,
    'kind': kind.name,
    'isDefault': isDefault,
    'isBattleOnly': isBattleOnly,
    'isMega': isMega,
    'isCosmetic': isCosmetic,
    if (introducedVersionGroup != null)
      'introducedVersionGroup': introducedVersionGroup,
    if (availableVersionGroups.isNotEmpty)
      'availableVersionGroups': availableVersionGroups,
    if (obtainableVersionGroups.isNotEmpty)
      'obtainableVersionGroups': obtainableVersionGroups,
    'obtainable': obtainable,
    if (eventOnly) 'eventOnly': true,
    if (deprecated) 'deprecated': true,
    if (inheritsFromDefault) 'inheritsFromDefault': true,
    'dataCompleteness': dataCompleteness,
    if (sources.isNotEmpty) 'sources': sources,
    'types': types,
    'heightDm': heightDm,
    'weightHg': weightHg,
    if (spriteUrl != null) 'spriteUrl': spriteUrl,
    if (artworkUrl != null) 'artworkUrl': artworkUrl,
    if (localSpritePath != null) 'localSpritePath': localSpritePath,
    if (spriteUrlsByVersion.isNotEmpty)
      'spriteUrlsByVersion': spriteUrlsByVersion,
    if (animatedSpriteUrl != null) 'animatedSpriteUrl': animatedSpriteUrl,
    if (baseStats != null) 'baseStats': baseStats!.toJson(),
    if (typeMultipliers.isNotEmpty) 'typeMultipliers': typeMultipliers,
    if (stabSuperEffective.isNotEmpty) 'stabSuperEffective': stabSuperEffective,
    'abilities': abilities.map((entry) => entry.toJson()).toList(),
    if (abilitiesByGame.isNotEmpty)
      'abilitiesByGame': abilitiesByGame.map(
        (key, value) =>
            MapEntry(key, value.map((entry) => entry.toJson()).toList()),
      ),
    if (obtainLocationsByGame.isNotEmpty)
      'obtainLocationsByGame': obtainLocationsByGame.map(
        (key, value) =>
            MapEntry(key, value.map((entry) => entry.toJson()).toList()),
      ),
    if (obtainLocationsByVersion.isNotEmpty)
      'obtainLocationsByVersion': obtainLocationsByVersion.map(
        (key, value) =>
            MapEntry(key, value.map((entry) => entry.toJson()).toList()),
      ),
    if (moveSets.isNotEmpty)
      'moveSets': moveSets.map((key, value) => MapEntry(key, value.toJson())),
    if (evolutionChain != null) 'evolutionChain': evolutionChain!.toJson(),
  };

  factory PokemonFormDetail.fromJson(
    Map<String, dynamic> json, {
    required Map<int, CachedMove> moveLookup,
  }) {
    final multiplierJson =
        json['typeMultipliers'] as Map<String, dynamic>? ?? const {};
    final obtainJson =
        json['obtainLocationsByGame'] as Map<String, dynamic>? ?? const {};
    final obtainVersionJson =
        json['obtainLocationsByVersion'] as Map<String, dynamic>? ?? const {};
    final abilitiesByGameJson =
        json['abilitiesByGame'] as Map<String, dynamic>? ?? const {};
    final moveSetsJson = json['moveSets'] as Map<String, dynamic>? ?? const {};
    return PokemonFormDetail(
      key: json['key'] as String,
      pokemonId: (json['pokemonId'] as num).toInt(),
      formId: (json['formId'] as num?)?.toInt(),
      nameEn: json['nameEn'] as String,
      nameZh: json['nameZh'] as String,
      formNameZh: json['formNameZh'] as String?,
      formGroup: json['formGroup'] as String?,
      kind: PokemonFormKind.parse(json['kind'] as String?),
      isDefault: json['isDefault'] as bool? ?? false,
      isBattleOnly: json['isBattleOnly'] as bool? ?? false,
      isMega: json['isMega'] as bool? ?? false,
      isCosmetic: json['isCosmetic'] as bool? ?? false,
      introducedVersionGroup: json['introducedVersionGroup'] as String?,
      availableVersionGroups:
          (json['availableVersionGroups'] as List<dynamic>? ?? const [])
              .cast<String>(),
      obtainableVersionGroups:
          (json['obtainableVersionGroups'] as List<dynamic>? ?? const [])
              .cast<String>(),
      obtainable:
          json['obtainable'] as bool? ??
          !(json['isBattleOnly'] as bool? ?? false),
      eventOnly: json['eventOnly'] as bool? ?? false,
      deprecated: json['deprecated'] as bool? ?? false,
      inheritsFromDefault:
          json['inheritsFromDefault'] as bool? ??
          (json['isCosmetic'] as bool? ?? false),
      dataCompleteness: json['dataCompleteness'] as String? ?? 'unknown',
      sources: (json['sources'] as List<dynamic>? ?? const []).cast<String>(),
      types: (json['types'] as List<dynamic>? ?? const []).cast<String>(),
      heightDm: (json['heightDm'] as num?)?.toInt() ?? 0,
      weightHg: (json['weightHg'] as num?)?.toInt() ?? 0,
      spriteUrl: json['spriteUrl'] as String?,
      artworkUrl: json['artworkUrl'] as String?,
      localSpritePath: json['localSpritePath'] as String?,
      spriteUrlsByVersion:
          (json['spriteUrlsByVersion'] as Map<String, dynamic>? ?? const {})
              .map((key, value) => MapEntry(key, value as String)),
      animatedSpriteUrl: json['animatedSpriteUrl'] as String?,
      baseStats: json['baseStats'] == null
          ? null
          : PokemonBaseStats.fromJson(
              json['baseStats'] as Map<String, dynamic>,
            ),
      typeMultipliers: multiplierJson.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      stabSuperEffective:
          (json['stabSuperEffective'] as List<dynamic>? ?? const [])
              .cast<String>(),
      abilities: (json['abilities'] as List<dynamic>? ?? const [])
          .map((item) => PokemonAbility.fromJson(item as Map<String, dynamic>))
          .toList(),
      abilitiesByGame: abilitiesByGameJson.map(
        (key, value) => MapEntry(
          key,
          (value as List<dynamic>)
              .map(
                (item) => PokemonAbility.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
        ),
      ),
      obtainLocationsByGame: obtainJson.map(
        (key, value) => MapEntry(
          key,
          (value as List<dynamic>)
              .map(
                (item) =>
                    ObtainLocationEntry.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
        ),
      ),
      obtainLocationsByVersion: obtainVersionJson.map(
        (key, value) => MapEntry(
          key,
          (value as List<dynamic>)
              .map(
                (item) =>
                    ObtainLocationEntry.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
        ),
      ),
      moveSets: moveSetsJson.map(
        (key, value) => MapEntry(
          key,
          PokemonMoveSet.fromJson(
            value as Map<String, dynamic>,
            moveLookup: moveLookup,
          ),
        ),
      ),
      evolutionChain: json['evolutionChain'] == null
          ? null
          : EvolutionNode.fromJson(
              json['evolutionChain'] as Map<String, dynamic>,
            ),
    );
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
    this.obtainLocationsByGame = const {},
    this.obtainLocationsByVersion = const {},
    this.abilities = const [],
    this.abilitiesByGame = const {},
    this.moveSet = const PokemonMoveSet(),
    this.moveSets = const {},
    this.baseHappiness,
    this.captureRate,
    this.evYield = const {},
    this.genderFemalePercent,
    this.eggGroups = const [],
    this.hatchCounter,
    this.forms = const [],
    this.growthRateSlug,
    this.habitatSlug,
    this.hasGenderDifferences = false,
    this.heldItems = const [],
    this.baseExperience,
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
  final Map<String, List<ObtainLocationEntry>> obtainLocationsByGame;
  final Map<String, List<ObtainLocationEntry>> obtainLocationsByVersion;
  final List<PokemonAbility> abilities;
  final Map<String, List<PokemonAbility>> abilitiesByGame;
  final PokemonMoveSet moveSet;
  final Map<String, PokemonMoveSet> moveSets;
  final int? baseHappiness;
  final int? captureRate;
  final Map<String, int> evYield;
  final double? genderFemalePercent;
  final List<String> eggGroups;
  final int? hatchCounter;
  final List<PokemonFormDetail> forms;

  /// Experience group slug — how fast this species levels. Chinese labels live
  /// in dex_search_terms.dart, never in the bundle: CDN prefixes are immutable,
  /// so a label baked in here could not be corrected without a republish.
  final String? growthRateSlug;

  /// Habitat only exists for Gen I–III species; null everywhere else.
  final String? habitatSlug;

  final bool hasGenderDifferences;

  /// Items wild members may hold, best rarity first.
  final List<PokemonHeldItem> heldItems;

  final int? baseExperience;

  bool get hasMultipleForms => forms.length > 1;

  PokemonFormDetail? get defaultForm {
    for (final form in forms) {
      if (form.isDefault) {
        return form;
      }
    }
    return forms.isEmpty ? null : forms.first;
  }

  /// Replace only paths resolved by the offline cache while preserving every
  /// species field. Keeping this copy in the model prevents cache adapters from
  /// silently dropping newly added fields when [PokemonDetail] grows.
  PokemonDetail withResolvedSprites({
    required PokemonSummary summary,
    required EvolutionNode? evolutionChain,
    required List<PokemonFormDetail> forms,
  }) => PokemonDetail(
    summary: summary,
    genusZh: genusZh,
    heightDm: heightDm,
    weightHg: weightHg,
    weaknesses: weaknesses,
    resistances: resistances,
    immunities: immunities,
    stabSuperEffective: stabSuperEffective,
    evolutionChain: evolutionChain,
    johtoDexNumber: johtoDexNumber,
    baseStats: baseStats,
    typeMultipliers: typeMultipliers,
    flavorEntries: flavorEntries,
    obtainLocations: obtainLocations,
    obtainLocationsByGame: obtainLocationsByGame,
    obtainLocationsByVersion: obtainLocationsByVersion,
    abilities: abilities,
    abilitiesByGame: abilitiesByGame,
    moveSet: moveSet,
    moveSets: moveSets,
    baseHappiness: baseHappiness,
    captureRate: captureRate,
    evYield: evYield,
    genderFemalePercent: genderFemalePercent,
    eggGroups: eggGroups,
    hatchCounter: hatchCounter,
    forms: forms,
    growthRateSlug: growthRateSlug,
    habitatSlug: habitatSlug,
    hasGenderDifferences: hasGenderDifferences,
    heldItems: heldItems,
    baseExperience: baseExperience,
  );

  /// Reuse the existing detail widgets with form-dependent battle data.
  PokemonDetail forForm(PokemonFormDetail form) {
    final inheritsSpeciesData =
        form.isDefault || form.isCosmetic || form.inheritsFromDefault;
    final resolvedMoveSets = inheritsSpeciesData ? moveSets : form.moveSets;
    final resolvedMoveSet =
        resolvedMoveSets['heartgold-soulsilver'] ??
        (inheritsSpeciesData ? moveSet : const PokemonMoveSet());
    final mayUseLegacySpeciesLocations =
        !form.isDefault &&
        (form.isCosmetic || form.inheritsFromDefault) &&
        form.obtainLocationsByGame.isEmpty &&
        form.obtainLocationsByVersion.isEmpty;
    final resolvedObtain = mayUseLegacySpeciesLocations
        ? obtainLocationsByGame
        : form.obtainLocationsByGame;
    final resolvedObtainByVersion = mayUseLegacySpeciesLocations
        ? obtainLocationsByVersion
        : form.obtainLocationsByVersion;
    final hgssObtain =
        resolvedObtain['heartgold-soulsilver'] ??
        (mayUseLegacySpeciesLocations ? obtainLocations : const []);
    return PokemonDetail(
      summary: form.summaryFor(summary),
      genusZh: genusZh,
      heightDm: form.heightDm,
      weightHg: form.weightHg,
      weaknesses: inheritsSpeciesData
          ? weaknesses
          : _typesAtMultiplier(form.typeMultipliers, (value) => value > 1),
      resistances: inheritsSpeciesData
          ? resistances
          : _typesAtMultiplier(
              form.typeMultipliers,
              (value) => value > 0 && value < 1,
            ),
      immunities: inheritsSpeciesData
          ? immunities
          : _typesAtMultiplier(form.typeMultipliers, (value) => value == 0),
      stabSuperEffective: form.stabSuperEffective.isEmpty
          ? stabSuperEffective
          : form.stabSuperEffective,
      // A form only overrides the chain when the bundle actually built one for
      // it; otherwise it falls back to the species chain, which the detail
      // page then narrows with EvolutionNode.filteredForForm. Before this
      // fallback every regional form (洗翠卡蒂狗, 帕底亚乌波…) showed an empty
      // evolution card, because no bundle has ever carried forms[].evolutionChain.
      evolutionChain: inheritsSpeciesData
          ? evolutionChain
          : (form.evolutionChain ?? evolutionChain),
      johtoDexNumber: johtoDexNumber,
      baseStats: inheritsSpeciesData
          ? (form.baseStats ?? baseStats)
          : form.baseStats,
      typeMultipliers: form.typeMultipliers.isEmpty
          ? typeMultipliers
          : form.typeMultipliers,
      flavorEntries: flavorEntries,
      obtainLocations: hgssObtain,
      obtainLocationsByGame: resolvedObtain,
      obtainLocationsByVersion: resolvedObtainByVersion,
      abilities: inheritsSpeciesData && form.abilities.isEmpty
          ? abilities
          : form.abilities,
      abilitiesByGame: inheritsSpeciesData
          ? abilitiesByGame
          : form.abilitiesByGame,
      moveSet: resolvedMoveSet,
      moveSets: resolvedMoveSets,
      baseHappiness: baseHappiness,
      captureRate: captureRate,
      evYield: evYield,
      genderFemalePercent: genderFemalePercent,
      eggGroups: eggGroups,
      hatchCounter: hatchCounter,
      forms: forms,
      // Species-level reference data — identical across forms.
      growthRateSlug: growthRateSlug,
      habitatSlug: habitatSlug,
      hasGenderDifferences: hasGenderDifferences,
      heldItems: heldItems,
      baseExperience: baseExperience,
    );
  }

  static List<String> _typesAtMultiplier(
    Map<String, double> multipliers,
    bool Function(double value) matches,
  ) => multipliers.entries
      .where((entry) => matches(entry.value))
      .map((entry) => typeNameZh(entry.key))
      .toList(growable: false);

  int get hatchSteps => hatchCounter == null ? 0 : hatchCounter! * 256;

  String get nationalDexLabel => '#${summary.id.toString().padLeft(3, '0')}';

  String? get johtoDexLabel => johtoDexNumber == null
      ? null
      : '城都 #${johtoDexNumber!.toString().padLeft(3, '0')}';

  /// Move set for a game version group key (falls back through legacy moveSet).
  PokemonMoveSet moveSetForKey(String versionGroupKey) =>
      resolvedMoveSetForKey(versionGroupKey).$2;

  /// Like [moveSetForKey] but also reports which version-group key actually
  /// backs the data — the UI labels fallbacks so borrowed data from another
  /// game is never presented silently. `$1` is null when nothing matched.
  (String?, PokemonMoveSet) resolvedMoveSetForKey(String versionGroupKey) {
    final direct = moveSets[versionGroupKey];
    if (direct != null && !_moveSetIsEmpty(direct)) {
      return (versionGroupKey, direct);
    }
    if (versionGroupKey == 'heartgold-soulsilver' &&
        !_moveSetIsEmpty(moveSet)) {
      return (versionGroupKey, moveSet);
    }
    for (final entry in moveSets.entries) {
      if (!_moveSetIsEmpty(entry.value)) {
        return (entry.key, entry.value);
      }
    }
    return (null, moveSet);
  }

  static bool _moveSetIsEmpty(PokemonMoveSet set) =>
      set.levelUp.isEmpty &&
      set.machine.isEmpty &&
      set.egg.isEmpty &&
      set.tutor.isEmpty;

  bool get hasMultipleMoveSets => moveSets.length > 1;

  /// Obtain locations for a game version group key (empty CDN lists fall through).
  List<ObtainLocationEntry> obtainLocationsForKey(String versionGroupKey) =>
      resolvedObtainLocationsForKey(versionGroupKey).$2;

  /// Like [obtainLocationsForKey] but also reports the backing key so the UI
  /// can label data borrowed from another game. `$1` is null when empty.
  (String?, List<ObtainLocationEntry>) resolvedObtainLocationsForKey(
    String versionGroupKey,
  ) {
    final byGame = obtainLocationsByGame[versionGroupKey];
    if (byGame != null && byGame.isNotEmpty) {
      return (versionGroupKey, byGame);
    }
    if (versionGroupKey == 'heartgold-soulsilver' &&
        obtainLocations.isNotEmpty) {
      return (versionGroupKey, obtainLocations);
    }
    // Any non-empty obtain data beats showing nothing (offline-first UX).
    for (final entry in obtainLocationsByGame.entries) {
      if (entry.value.isNotEmpty) {
        return (entry.key, entry.value);
      }
    }
    return (
      obtainLocations.isEmpty ? null : 'heartgold-soulsilver',
      obtainLocations,
    );
  }

  /// First non-empty obtain key + locations (for UI labels).
  (String?, List<ObtainLocationEntry>) get firstAvailableObtain {
    for (final entry in obtainLocationsByGame.entries) {
      if (entry.value.isNotEmpty) {
        return (entry.key, entry.value);
      }
    }
    if (obtainLocations.isNotEmpty) {
      return ('heartgold-soulsilver', obtainLocations);
    }
    return (null, const []);
  }

  String? get evYieldLabel {
    if (evYield.isEmpty) {
      return null;
    }
    return evYield.entries
        .map((entry) => '${statLabelZh(entry.key)} +${entry.value}')
        .join(' / ');
  }

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
    'flavorEntries': flavorEntries.map((entry) => entry.toJson()).toList(),
    'obtainLocations': obtainLocations.map((entry) => entry.toJson()).toList(),
    if (obtainLocationsByGame.isNotEmpty)
      'obtainLocationsByGame': obtainLocationsByGame.map(
        (key, value) =>
            MapEntry(key, value.map((entry) => entry.toJson()).toList()),
      ),
    if (obtainLocationsByVersion.isNotEmpty)
      'obtainLocationsByVersion': obtainLocationsByVersion.map(
        (key, value) =>
            MapEntry(key, value.map((entry) => entry.toJson()).toList()),
      ),
    'abilities': abilities.map((entry) => entry.toJson()).toList(),
    if (abilitiesByGame.isNotEmpty)
      'abilitiesByGame': abilitiesByGame.map(
        (key, value) =>
            MapEntry(key, value.map((entry) => entry.toJson()).toList()),
      ),
    'moveSet': moveSet.toJson(),
    if (moveSets.isNotEmpty)
      'moveSets': moveSets.map((key, value) => MapEntry(key, value.toJson())),
    if (baseHappiness != null) 'baseHappiness': baseHappiness,
    if (captureRate != null) 'captureRate': captureRate,
    if (evYield.isNotEmpty) 'evYield': evYield,
    if (genderFemalePercent != null) 'genderFemalePercent': genderFemalePercent,
    'eggGroups': eggGroups,
    if (hatchCounter != null) 'hatchCounter': hatchCounter,
    if (evolutionChain != null) 'evolutionChain': evolutionChain!.toJson(),
    if (forms.isNotEmpty)
      'forms': forms.map((entry) => entry.toJson()).toList(),
    if (growthRateSlug != null) 'growthRateSlug': growthRateSlug,
    if (habitatSlug != null) 'habitatSlug': habitatSlug,
    if (hasGenderDifferences) 'hasGenderDifferences': true,
    if (heldItems.isNotEmpty)
      'heldItems': heldItems.map((entry) => entry.toJson()).toList(),
    if (baseExperience != null) 'baseExperience': baseExperience,
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
      final moveId = (ref['moveId'] as num?)?.toInt();
      if (moveId == null) {
        continue;
      }
      final move =
          moveLookup[moveId] ??
          CachedMove(
            id: moveId,
            nameEn: 'move-$moveId',
            nameZh: '招式 #$moveId',
            type: 'normal',
            category: 'status',
          );
      legacyMoves.add(
        PokemonMove(
          move: move,
          method: ref['method'] as String? ?? 'level-up',
          level: (ref['level'] as num?)?.toInt(),
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

    final moveSetsJson = json['moveSets'] as Map<String, dynamic>?;
    final resolvedMoveSets = <String, PokemonMoveSet>{};
    if (moveSetsJson != null) {
      for (final entry in moveSetsJson.entries) {
        resolvedMoveSets[entry.key] = PokemonMoveSet.fromJson(
          entry.value as Map<String, dynamic>,
          moveLookup: moveLookup,
        );
      }
    }
    if (resolvedMoveSets.isEmpty &&
        (resolvedMoveSet.levelUp.isNotEmpty ||
            resolvedMoveSet.machine.isNotEmpty ||
            resolvedMoveSet.egg.isNotEmpty)) {
      resolvedMoveSets['heartgold-soulsilver'] = resolvedMoveSet;
    }

    final obtainByGameJson =
        json['obtainLocationsByGame'] as Map<String, dynamic>?;
    final resolvedObtainByGame = <String, List<ObtainLocationEntry>>{};
    if (obtainByGameJson != null) {
      for (final entry in obtainByGameJson.entries) {
        resolvedObtainByGame[entry.key] = (entry.value as List<dynamic>)
            .map(
              (item) =>
                  ObtainLocationEntry.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }
    }
    final obtainByVersionJson =
        json['obtainLocationsByVersion'] as Map<String, dynamic>?;
    final resolvedObtainByVersion = <String, List<ObtainLocationEntry>>{};
    if (obtainByVersionJson != null) {
      for (final entry in obtainByVersionJson.entries) {
        resolvedObtainByVersion[entry.key] = (entry.value as List<dynamic>)
            .map(
              (item) =>
                  ObtainLocationEntry.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }
    }

    final abilitiesByGameJson =
        json['abilitiesByGame'] as Map<String, dynamic>?;
    final resolvedAbilitiesByGame = <String, List<PokemonAbility>>{};
    if (abilitiesByGameJson != null) {
      for (final entry in abilitiesByGameJson.entries) {
        resolvedAbilitiesByGame[entry.key] = (entry.value as List<dynamic>)
            .map(
              (item) => PokemonAbility.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }
    }

    final evYieldJson = json['evYield'] as Map<String, dynamic>? ?? const {};
    final evYield = evYieldJson.map(
      (key, value) => MapEntry(key, (value as num).toInt()),
    );

    return PokemonDetail(
      summary: PokemonSummary.fromJson(json['summary'] as Map<String, dynamic>),
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
            (item) =>
                ObtainLocationEntry.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      obtainLocationsByGame: resolvedObtainByGame,
      obtainLocationsByVersion: resolvedObtainByVersion,
      abilities: (json['abilities'] as List<dynamic>? ?? const [])
          .map((item) => PokemonAbility.fromJson(item as Map<String, dynamic>))
          .toList(),
      abilitiesByGame: resolvedAbilitiesByGame,
      moveSet: resolvedMoveSet,
      moveSets: resolvedMoveSets,
      baseHappiness: json['baseHappiness'] as int?,
      captureRate: json['captureRate'] as int?,
      evYield: evYield,
      genderFemalePercent: (json['genderFemalePercent'] as num?)?.toDouble(),
      eggGroups: (json['eggGroups'] as List<dynamic>? ?? const [])
          .cast<String>(),
      hatchCounter: json['hatchCounter'] as int?,
      forms: (json['forms'] as List<dynamic>? ?? const [])
          .map(
            (item) => PokemonFormDetail.fromJson(
              item as Map<String, dynamic>,
              moveLookup: moveLookup,
            ),
          )
          .toList(),
      evolutionChain: json['evolutionChain'] == null
          ? null
          : EvolutionNode.fromJson(
              json['evolutionChain'] as Map<String, dynamic>,
            ),
      growthRateSlug: json['growthRateSlug'] as String?,
      habitatSlug: json['habitatSlug'] as String?,
      hasGenderDifferences: json['hasGenderDifferences'] as bool? ?? false,
      heldItems: (json['heldItems'] as List<dynamic>? ?? const [])
          .map((item) => PokemonHeldItem.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      baseExperience: (json['baseExperience'] as num?)?.toInt(),
    );
  }
}

/// An item wild members of a species may hold, with per-version rarity.
class PokemonHeldItem {
  const PokemonHeldItem({
    required this.slug,
    this.rarityByVersion = const {},
    this.maxRarity = 0,
  });

  final String slug;
  final Map<String, int> rarityByVersion;
  final int maxRarity;

  /// Rarity in a specific game version, or null when that version never
  /// spawns this species holding the item.
  int? rarityForVersion(String version) => rarityByVersion[version];

  Map<String, dynamic> toJson() => {
    'slug': slug,
    if (rarityByVersion.isNotEmpty) 'rarityByVersion': rarityByVersion,
    'maxRarity': maxRarity,
  };

  factory PokemonHeldItem.fromJson(Map<String, dynamic> json) {
    final rarityRaw = json['rarityByVersion'] as Map<String, dynamic>?;
    return PokemonHeldItem(
      slug: json['slug'] as String? ?? '',
      rarityByVersion:
          rarityRaw?.map(
            (key, value) => MapEntry(key, (value as num).toInt()),
          ) ??
          const {},
      maxRarity: (json['maxRarity'] as num?)?.toInt() ?? 0,
    );
  }
}

class EvolutionNode {
  const EvolutionNode({
    required this.id,
    required this.nameEn,
    required this.nameZh,
    this.spriteUrl,
    this.artworkUrl,
    this.localSpritePath,
    this.evolvesFrom,
    this.triggerZh,
    this.triggers = const [],
    this.children = const [],
    this.formKey,
  });

  final int id;
  final String nameEn;
  final String nameZh;
  final String? spriteUrl;
  final String? artworkUrl;
  final String? localSpritePath;
  final String? evolvesFrom;
  final String? triggerZh;

  /// Set when this node stands for one specific form of [id] rather than the
  /// species' default — 洗翠风速狗 instead of 风速狗. Also the marker that says
  /// "this chain has already been resolved for a form", so [filteredForForm]
  /// leaves a bundle-supplied form chain alone instead of filtering it twice.
  final String? formKey;

  /// Structured evolution conditions, one per PokeAPI `evolution_details`
  /// entry. [triggerZh] is a display string that flattens only the first
  /// condition — anything that needs to *decide* (is this a trade evolution?
  /// does it need a held item?) must read these instead of parsing the label.
  final List<EvolutionTrigger> triggers;

  final List<EvolutionNode> children;

  /// Prefer a usable local/network path. A still-relative bundle path
  /// (`sprites/forms/…`) that was never absolutized would make Image.file
  /// draw a hole, so fall through to [spriteUrl] in that case.
  String? get displaySpritePath {
    final local = localSpritePath;
    if (local != null &&
        (local.startsWith('/') ||
            local.startsWith('http') ||
            local.startsWith('assets/'))) {
      return local;
    }
    return spriteUrl ?? local;
  }

  bool containsId(int pokemonId) {
    if (id == pokemonId) {
      return true;
    }
    return children.any((child) => child.containsId(pokemonId));
  }

  /// Returns the chain as it applies to the form [selectedFormKey].
  ///
  /// The species chain is a superset: 喵喵 lists both 猫老大 and 喵头目, and
  /// 卡蒂狗 lists the ordinary 风速狗 even for the Hisuian form. Walking
  /// [kFormEvolutionTargets] prunes the branches the selected form cannot take
  /// and relabels the ones it can (风速狗 → 风速狗（洗翠的样子）).
  ///
  /// [rootSpritePath] is the selected form's own sprite; it is only applied
  /// when the selected form belongs to the *root* species, which is the one
  /// case where the caller's form art is known to be this node's art.
  ///
  /// A chain that already carries [formKey] came from the bundle already
  /// resolved for the form, and is returned untouched.
  EvolutionNode filteredForForm(
    String? selectedFormKey, {
    String? rootSpritePath,
  }) {
    if (selectedFormKey == null || formKey != null) return this;
    final rootKey = _rootFormKey(selectedFormKey);
    if (rootKey == null) return this;
    final root = rootKey == nameEn.toLowerCase()
        ? this
        : _asVariant(
            rootKey.substring(nameEn.length + 1),
            rootKey,
            spritePath: rootKey == selectedFormKey ? rootSpritePath : null,
          );
    return root._withFormTargets(rootKey);
  }

  /// The root species' form key that corresponds to [selectedFormKey].
  ///
  /// The selected form usually sits on the root species (卡蒂狗（洗翠）), but it
  /// can sit further down the chain (风速狗（洗翠）), in which case it is mapped
  /// back onto the root by its form suffix. Species whose slug itself contains
  /// a hyphen (`mr-mime-galar`) can fail to map; they fall through to the
  /// unfiltered species chain, which is what they showed before.
  String? _rootFormKey(String selectedFormKey) {
    final rootSlug = nameEn.toLowerCase();
    if (selectedFormKey == rootSlug ||
        selectedFormKey.startsWith('$rootSlug-')) {
      return kFormEvolutionTargets.containsKey(selectedFormKey)
          ? selectedFormKey
          : null;
    }
    for (var i = 0; i < selectedFormKey.length; i++) {
      if (selectedFormKey[i] != '-') continue;
      final candidate = '$rootSlug${selectedFormKey.substring(i)}';
      if (kFormEvolutionTargets.containsKey(candidate)) return candidate;
    }
    // A default form deeper in the chain (直冲熊) still needs the root pruned
    // to the default branch, or it inherits 堵拦熊 from its Galarian sibling.
    return kFormEvolutionTargets.containsKey(rootSlug) ? rootSlug : null;
  }

  EvolutionNode _withFormTargets(String nodeFormKey) {
    final targets = kFormEvolutionTargets[nodeFormKey];
    // No entry means the form shares its species' chain — keep it whole.
    if (targets == null) return this;
    final kept = <EvolutionNode>[];
    for (final target in targets) {
      for (final child in children) {
        if (child.id != target.speciesId) continue;
        final suffix = target.formSuffix;
        final childSlug = child.nameEn.toLowerCase();
        final childKey = suffix == null ? childSlug : '$childSlug-$suffix';
        final resolved = suffix == null
            ? child
            : child._asVariant(suffix, childKey);
        kept.add(resolved._withFormTargets(childKey));
      }
    }
    return _copyWith(children: kept);
  }

  /// This node as the [suffix] form of its species. The species sprite is kept
  /// unless [spritePath] is given — only the bundle's per-form chain knows the
  /// variant's own art, so an offline install on an older bundle shows the
  /// right name over the species sprite rather than nothing at all.
  EvolutionNode _asVariant(String suffix, String key, {String? spritePath}) {
    final label = formVariantLabelZh(suffix);
    return _copyWith(
      nameZh: label == null || nameZh.contains(label)
          ? nameZh
          : '$nameZh（$label）',
      localSpritePath: spritePath ?? localSpritePath,
      formKey: key,
    );
  }

  EvolutionNode _copyWith({
    String? nameZh,
    String? localSpritePath,
    bool replaceLocalSpritePath = false,
    String? formKey,
    List<EvolutionNode>? children,
  }) => EvolutionNode(
    id: id,
    nameEn: nameEn,
    nameZh: nameZh ?? this.nameZh,
    spriteUrl: spriteUrl,
    artworkUrl: artworkUrl,
    localSpritePath: replaceLocalSpritePath
        ? localSpritePath
        : localSpritePath ?? this.localSpritePath,
    evolvesFrom: evolvesFrom,
    triggerZh: triggerZh,
    triggers: triggers,
    children: children ?? this.children,
    formKey: formKey ?? this.formKey,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nameEn': nameEn,
    'nameZh': nameZh,
    if (spriteUrl != null) 'spriteUrl': spriteUrl,
    if (artworkUrl != null) 'artworkUrl': artworkUrl,
    if (localSpritePath != null) 'localSpritePath': localSpritePath,
    if (evolvesFrom != null) 'evolvesFrom': evolvesFrom,
    if (triggerZh != null) 'triggerZh': triggerZh,
    if (formKey != null) 'formKey': formKey,
    if (triggers.isNotEmpty)
      'triggers': triggers.map((trigger) => trigger.toJson()).toList(),
    'children': children.map((child) => child.toJson()).toList(),
  };

  factory EvolutionNode.fromJson(Map<String, dynamic> json) => EvolutionNode(
    id: json['id'] as int,
    nameEn: json['nameEn'] as String,
    nameZh: json['nameZh'] as String,
    spriteUrl: json['spriteUrl'] as String?,
    artworkUrl: json['artworkUrl'] as String?,
    localSpritePath: json['localSpritePath'] as String?,
    evolvesFrom: json['evolvesFrom'] as String?,
    triggerZh: json['triggerZh'] as String?,
    formKey: json['formKey'] as String?,
    triggers: (json['triggers'] as List<dynamic>? ?? const [])
        .map((item) => EvolutionTrigger.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
    children: (json['children'] as List<dynamic>? ?? const [])
        .map((item) => EvolutionNode.fromJson(item as Map<String, dynamic>))
        .toList(),
  );

  EvolutionNode copyWithLocalSprite(String path) =>
      _copyWith(localSpritePath: path);

  EvolutionNode withResolvedTree({
    required String? localSpritePath,
    required List<EvolutionNode> children,
  }) => _copyWith(
    localSpritePath: localSpritePath,
    replaceLocalSpritePath: true,
    children: children,
  );
}

/// One structured evolution condition.
///
/// Mirrors a PokeAPI `evolution_details` entry. Only the fields that were
/// present survive the bundle, so a null means "not part of this condition".
class EvolutionTrigger {
  const EvolutionTrigger({
    this.trigger,
    this.item,
    this.heldItem,
    this.knownMove,
    this.knownMoveType,
    this.location,
    this.partySpecies,
    this.partyType,
    this.tradeSpecies,
    this.minLevel,
    this.minHappiness,
    this.minBeauty,
    this.minAffection,
    this.gender,
    this.relativePhysicalStats,
    this.timeOfDay,
    this.needsOverworldRain = false,
    this.turnUpsideDown = false,
  });

  /// PokeAPI trigger slug: `level-up`, `trade`, `use-item`, `shed`, …
  final String? trigger;
  final String? item;
  final String? heldItem;
  final String? knownMove;
  final String? knownMoveType;
  final String? location;
  final String? partySpecies;
  final String? partyType;
  final String? tradeSpecies;
  final int? minLevel;
  final int? minHappiness;
  final int? minBeauty;
  final int? minAffection;
  final int? gender;
  final int? relativePhysicalStats;
  final String? timeOfDay;
  final bool needsOverworldRain;
  final bool turnUpsideDown;

  /// True for trade evolutions — including 巨钳螳螂-style "trade while holding
  /// an item", which the display string alone cannot distinguish.
  bool get isTrade => trigger == 'trade';

  /// Trade evolutions that additionally require a held item.
  bool get requiresHeldItem => heldItem != null;

  Map<String, dynamic> toJson() => {
    if (trigger != null) 'trigger': trigger,
    if (item != null) 'item': item,
    if (heldItem != null) 'heldItem': heldItem,
    if (knownMove != null) 'knownMove': knownMove,
    if (knownMoveType != null) 'knownMoveType': knownMoveType,
    if (location != null) 'location': location,
    if (partySpecies != null) 'partySpecies': partySpecies,
    if (partyType != null) 'partyType': partyType,
    if (tradeSpecies != null) 'tradeSpecies': tradeSpecies,
    if (minLevel != null) 'minLevel': minLevel,
    if (minHappiness != null) 'minHappiness': minHappiness,
    if (minBeauty != null) 'minBeauty': minBeauty,
    if (minAffection != null) 'minAffection': minAffection,
    if (gender != null) 'gender': gender,
    if (relativePhysicalStats != null)
      'relativePhysicalStats': relativePhysicalStats,
    if (timeOfDay != null) 'timeOfDay': timeOfDay,
    if (needsOverworldRain) 'needsOverworldRain': true,
    if (turnUpsideDown) 'turnUpsideDown': true,
  };

  factory EvolutionTrigger.fromJson(Map<String, dynamic> json) =>
      EvolutionTrigger(
        trigger: json['trigger'] as String?,
        item: json['item'] as String?,
        heldItem: json['heldItem'] as String?,
        knownMove: json['knownMove'] as String?,
        knownMoveType: json['knownMoveType'] as String?,
        location: json['location'] as String?,
        partySpecies: json['partySpecies'] as String?,
        partyType: json['partyType'] as String?,
        tradeSpecies: json['tradeSpecies'] as String?,
        minLevel: (json['minLevel'] as num?)?.toInt(),
        minHappiness: (json['minHappiness'] as num?)?.toInt(),
        minBeauty: (json['minBeauty'] as num?)?.toInt(),
        minAffection: (json['minAffection'] as num?)?.toInt(),
        gender: (json['gender'] as num?)?.toInt(),
        relativePhysicalStats: (json['relativePhysicalStats'] as num?)?.toInt(),
        timeOfDay: json['timeOfDay'] as String?,
        needsOverworldRain: json['needsOverworldRain'] as bool? ?? false,
        turnUpsideDown: json['turnUpsideDown'] as bool? ?? false,
      );
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
    this.l10nVersion,
    this.configVersion,
  });

  static const currentVersion = 2;

  final int version;
  final bool complete;
  final bool preferOffline;
  final String? downloadedAt;
  final int pokemonCount;
  final int moveCount;
  final int sizeBytes;
  final String? l10nVersion;
  final int? configVersion;

  Map<String, dynamic> toJson() => {
    'version': version,
    'complete': complete,
    'preferOffline': preferOffline,
    if (downloadedAt != null) 'downloadedAt': downloadedAt,
    'pokemonCount': pokemonCount,
    'moveCount': moveCount,
    'sizeBytes': sizeBytes,
    if (l10nVersion != null) 'l10nVersion': l10nVersion,
    if (configVersion != null) 'configVersion': configVersion,
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
        l10nVersion: json['l10nVersion'] as String?,
        configVersion: json['configVersion'] as int?,
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
