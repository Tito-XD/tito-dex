/// Unified type effectiveness for battle tools (generation, abilities, weather, Tera).
library;

import '../../l10n/app_locale.dart';
import 'ability_type_modifiers.dart';
import 'generation_type_chart.dart';
import 'type_chart.dart';

/// Weather / terrain attack-type multipliers (move power, not defensive chart).
const kFieldMoveTypeModifiers = <String, Map<String, double>>{
  'sun': {'fire': 1.5, 'water': 0.5},
  'harsh-sunlight': {'fire': 1.5, 'water': 0.5},
  'rain': {'water': 1.5, 'fire': 0.5},
  'heavy-rain': {'water': 1.5, 'fire': 0.5},
  'sandstorm': {},
  'snow': {},
  'electric': {'electric': 1.3},
  'grassy': {'grass': 1.3},
  'psychic': {'psychic': 1.3},
  'misty': {'dragon': 0.5},
};

const kAbilityMoveTypeConversion = <String, String>{
  'pixilate': 'fairy',
  'aerilate': 'flying',
  'refrigerate': 'ice',
  'galvanize': 'electric',
};

const kAttackerGhostBypassAbilities = {
  'scrappy',
  'mind-s-eye',
  'minds-eye',
  'odor-sleuth',
  'foresight',
};

const kDefenderSuperEffectiveReductionAbilities = {
  'filter',
  'solid-rock',
  'prism-armor',
};

const kAttackerResistDoublingAbilities = {'tinted-lens'};

const kAttackerPhysicalDoubleAbilities = {'huge-power', 'pure-power'};

const kDefenderPhysicalHalvingAbilities = {'fur-coat'};

const kDefenderSpecialHalvingAbilities = {'ice-scales'};

enum BattleHeldItem {
  none,
  lifeOrb,
  choiceBand,
  choiceSpecs,
  expertBelt,
  typeBoost,
}

extension BattleHeldItemLabel on BattleHeldItem {
  String get slug => name;

  String get labelZh => switch (this) {
    BattleHeldItem.none => '无',
    BattleHeldItem.lifeOrb => '生命宝珠',
    BattleHeldItem.choiceBand => '讲究头带',
    BattleHeldItem.choiceSpecs => '讲究眼镜',
    BattleHeldItem.expertBelt => '达人带',
    BattleHeldItem.typeBoost => '属性强化道具',
  };

  String get label => AppLocale.pick(
    zh: labelZh,
    en: switch (this) {
      BattleHeldItem.none => 'None',
      BattleHeldItem.lifeOrb => 'Life Orb',
      BattleHeldItem.choiceBand => 'Choice Band',
      BattleHeldItem.choiceSpecs => 'Choice Specs',
      BattleHeldItem.expertBelt => 'Expert Belt',
      BattleHeldItem.typeBoost => 'Type-boosting item',
    },
  );
}

enum BattleStatusCondition { none, burn, paralysis }

extension BattleStatusConditionLabel on BattleStatusCondition {
  String get labelZh => switch (this) {
    BattleStatusCondition.none => '无',
    BattleStatusCondition.burn => '灼伤',
    BattleStatusCondition.paralysis => '麻痹',
  };

  String get label => AppLocale.pick(
    zh: labelZh,
    en: switch (this) {
      BattleStatusCondition.none => 'None',
      BattleStatusCondition.burn => 'Burn',
      BattleStatusCondition.paralysis => 'Paralysis',
    },
  );
}

enum FieldCondition { none, sun, rain, sandstorm, snow }

extension FieldConditionLabel on FieldCondition {
  String get slug => switch (this) {
    FieldCondition.none => '',
    FieldCondition.sun => 'sun',
    FieldCondition.rain => 'rain',
    FieldCondition.sandstorm => 'sandstorm',
    FieldCondition.snow => 'snow',
  };

  String get labelZh => switch (this) {
    FieldCondition.none => '无',
    FieldCondition.sun => '大晴天',
    FieldCondition.rain => '下雨',
    FieldCondition.sandstorm => '沙暴',
    FieldCondition.snow => '下雪',
  };

  String get label => AppLocale.pick(
    zh: labelZh,
    en: switch (this) {
      FieldCondition.none => 'None',
      FieldCondition.sun => 'Sun',
      FieldCondition.rain => 'Rain',
      FieldCondition.sandstorm => 'Sandstorm',
      FieldCondition.snow => 'Snow',
    },
  );
}

enum TerrainCondition { none, electric, grassy, psychic, misty }

extension TerrainConditionLabel on TerrainCondition {
  String get slug => switch (this) {
    TerrainCondition.none => '',
    TerrainCondition.electric => 'electric',
    TerrainCondition.grassy => 'grassy',
    TerrainCondition.psychic => 'psychic',
    TerrainCondition.misty => 'misty',
  };

  String get labelZh => switch (this) {
    TerrainCondition.none => '无',
    TerrainCondition.electric => '电气场地',
    TerrainCondition.grassy => '青草场地',
    TerrainCondition.psychic => '精神场地',
    TerrainCondition.misty => '薄雾场地',
  };

  String get label => AppLocale.pick(
    zh: labelZh,
    en: switch (this) {
      TerrainCondition.none => 'None',
      TerrainCondition.electric => 'Electric Terrain',
      TerrainCondition.grassy => 'Grassy Terrain',
      TerrainCondition.psychic => 'Psychic Terrain',
      TerrainCondition.misty => 'Misty Terrain',
    },
  );
}

class BattleEffectivenessInput {
  const BattleEffectivenessInput({
    required this.defenderTypes,
    required this.relationsByType,
    this.defenderAbilitySlug,
    this.attackerAbilitySlug,
    this.generation = 9,
    this.weatherSlug,
    this.attackerTypes = const [],
    this.terrainSlug,
    this.defenderTerastallized = false,
    this.defenderTeraType,
    this.attackerTerastallized = false,
    this.attackerTeraType,
  });

  final List<String> defenderTypes;
  final Map<String, TypeDamageRelations> relationsByType;
  final String? defenderAbilitySlug;
  final String? attackerAbilitySlug;
  final int generation;
  final String? weatherSlug;
  final List<String> attackerTypes;
  final String? terrainSlug;
  final bool defenderTerastallized;
  final String? defenderTeraType;
  final bool attackerTerastallized;
  final String? attackerTeraType;

  List<String> get normalizedDefenderTypes =>
      normalizeTypesForGeneration(defenderTypes, generation);

  List<String> get effectiveDefenderTypes {
    if (defenderTerastallized &&
        defenderTeraType != null &&
        defenderTeraType!.isNotEmpty &&
        generation >= 9) {
      return [defenderTeraType!];
    }
    return normalizedDefenderTypes;
  }

  Map<String, TypeDamageRelations> get generationRelations =>
      typeRelationsForGeneration(relationsByType, generation);

  bool get supportsTerastal => generation >= 9;
}

String effectiveMoveType(String moveType, String? attackerAbilitySlug) {
  if (attackerAbilitySlug == null) {
    return moveType;
  }
  final converted = kAbilityMoveTypeConversion[attackerAbilitySlug];
  if (converted != null && moveType == 'normal') {
    return converted;
  }
  return moveType;
}

bool hasStab(String moveType, List<String> attackerTypes) =>
    attackerTypes.contains(moveType);

bool ignoresDefenderAbility(String? attacker, String? defender) =>
    const {'mold-breaker', 'teravolt', 'turboblaze'}.contains(attacker) &&
    const {
      'sap-sipper',
      'thick-fat',
      'levitate',
      'flash-fire',
      'water-absorb',
      'volt-absorb',
      'lightning-rod',
      'storm-drain',
      'motor-drive',
      'earth-eater',
      'well-baked-body',
      'heatproof',
      'water-bubble',
      'dry-skin',
      'fluffy',
      'purifying-salt',
      'wonder-guard',
      'filter',
      'solid-rock',
      'fur-coat',
      'ice-scales',
      'battle-armor',
      'shell-armor',
      'soundproof',
      'bulletproof',
      'multiscale',
      'sturdy',
      'unaware',
      'marvel-scale',
      'ice-face',
      'disguise',
      'tera-shell',
      'grass-pelt',
      'wind-rider',
      'punk-rock',
    }.contains(defender);

String? effectiveDefenderAbility(String? attacker, String? defender) =>
    ignoresDefenderAbility(attacker, defender) ? null : defender;

bool battleGrounded(List<String> types, String? ability) =>
    !types.contains('flying') && ability != 'levitate';

void _applyWonderGuard(Map<String, double> multipliers) {
  for (final key in multipliers.keys.toList()) {
    if ((multipliers[key] ?? 1) < 2) {
      multipliers[key] = 0;
    }
  }
}

Map<String, double> computeBattleTypeMultipliers(
  BattleEffectivenessInput input,
) {
  final multipliers = <String, double>{};
  for (final attackType in input.generationRelations.keys) {
    var value = 1.0;
    for (final defenseType in input.effectiveDefenderTypes) {
      if (defenseType == 'ghost' &&
          const ['normal', 'fighting'].contains(attackType) &&
          kAttackerGhostBypassAbilities.contains(input.attackerAbilitySlug)) {
        continue;
      }
      value *=
          computeDefensiveMultipliers([
            defenseType,
          ], input.generationRelations)[attackType] ??
          1;
    }
    multipliers[attackType] = value;
  }
  final ability = effectiveDefenderAbility(
    input.attackerAbilitySlug,
    input.defenderAbilitySlug,
  );
  // Lightning Rod / Storm Drain only gained their immunities in Gen V.
  if (!(input.generation < 5 &&
      const {'lightning-rod', 'storm-drain'}.contains(ability))) {
    applyAbilityTypeModifiers(multipliers, ability);
  }
  if (ability == 'wonder-guard') _applyWonderGuard(multipliers);

  if (input.generation < 6) {
    for (final fairy in kTypesIntroducedGen6) {
      multipliers.remove(fairy);
    }
  }

  return multipliers;
}

DefensiveProfile computeBattleDefensiveProfile(BattleEffectivenessInput input) {
  final multipliers = computeBattleTypeMultipliers(input);
  final weaknesses = <String>[];
  final resistances = <String>[];
  final immunities = <String>[];

  for (final entry in multipliers.entries) {
    if (entry.value >= 2) {
      weaknesses.add(typeNameZh(entry.key));
    } else if (entry.value == 0) {
      immunities.add(typeNameZh(entry.key));
    } else if (entry.value <= 0.5) {
      resistances.add(typeNameZh(entry.key));
    }
  }

  weaknesses.sort();
  resistances.sort();
  immunities.sort();

  return DefensiveProfile(
    weaknesses: weaknesses,
    resistances: resistances,
    immunities: immunities,
  );
}

double typeMultiplierForBattleMove(
  String moveType,
  BattleEffectivenessInput input,
) {
  final effectiveType = effectiveMoveType(moveType, input.attackerAbilitySlug);
  final multipliers = computeBattleTypeMultipliers(input);
  return multipliers[effectiveType] ?? 1;
}

double fieldMoveTypeModifier(String moveType, BattleEffectivenessInput input) {
  var modifier = 1.0;
  final weather = input.weatherSlug;
  if (weather != null && kFieldMoveTypeModifiers.containsKey(weather)) {
    modifier *= kFieldMoveTypeModifiers[weather]![moveType] ?? 1.0;
  }
  final terrain = input.terrainSlug;
  if (input.generation >= 6 && terrain != null) {
    final atkTypes =
        input.attackerTerastallized &&
            input.generation >= 9 &&
            input.attackerTeraType != null
        ? [input.attackerTeraType!]
        : input.attackerTypes;
    final attackGrounded = battleGrounded(atkTypes, input.attackerAbilitySlug);
    final defenseGrounded = battleGrounded(
      input.effectiveDefenderTypes,
      input.defenderAbilitySlug,
    );
    if (terrain == 'misty' && moveType == 'dragon' && defenseGrounded) {
      modifier *= .5;
    }
    if (attackGrounded &&
        ((terrain == 'electric' && moveType == 'electric') ||
            (terrain == 'grassy' && moveType == 'grass') ||
            (terrain == 'psychic' &&
                input.generation >= 7 &&
                moveType == 'psychic'))) {
      modifier *= input.generation < 8 ? 1.5 : 1.3;
    }
  }
  return modifier;
}

double abilityDamageMultiplier({
  required double typeMultiplier,
  required String? defenderAbilitySlug,
  required String? attackerAbilitySlug,
}) {
  var modifier = 1.0;

  if (typeMultiplier >= 2 &&
      defenderAbilitySlug != null &&
      kDefenderSuperEffectiveReductionAbilities.contains(defenderAbilitySlug)) {
    modifier *= 0.75;
  }

  if (typeMultiplier > 0 &&
      typeMultiplier <= 0.5 &&
      attackerAbilitySlug != null &&
      kAttackerResistDoublingAbilities.contains(attackerAbilitySlug)) {
    modifier *= 2;
  }

  return modifier;
}

double defenderAbilityDamageMultiplier({
  required bool isPhysical,
  required String? defenderAbilitySlug,
  bool isContactMove = false,
}) {
  var modifier = 1.0;
  if (defenderAbilitySlug == null) {
    return modifier;
  }
  if (isPhysical &&
      kDefenderPhysicalHalvingAbilities.contains(defenderAbilitySlug)) {
    modifier *= 0.5;
  }
  if (!isPhysical &&
      kDefenderSpecialHalvingAbilities.contains(defenderAbilitySlug)) {
    modifier *= 0.5;
  }
  if (isContactMove && defenderAbilitySlug == 'fluffy') {
    modifier *= 0.5;
  }
  return modifier;
}

int applyAttackerAbilityToAttackStat(
  int attack,
  bool isPhysical,
  String? attackerAbilitySlug,
) {
  if (isPhysical &&
      attackerAbilitySlug != null &&
      kAttackerPhysicalDoubleAbilities.contains(attackerAbilitySlug)) {
    return attack * 2;
  }
  return attack;
}

int applyHeldItemToAttackStat(
  int attack,
  bool isPhysical,
  BattleHeldItem heldItem,
) {
  return switch (heldItem) {
    BattleHeldItem.choiceBand when isPhysical => (attack * 1.5).floor(),
    BattleHeldItem.choiceSpecs when !isPhysical => (attack * 1.5).floor(),
    _ => attack,
  };
}

int applyStatusToAttackStat(
  int attack,
  bool isPhysical,
  BattleStatusCondition status,
) {
  if (isPhysical && status == BattleStatusCondition.burn) {
    return attack ~/ 2;
  }
  return attack;
}

int applyStatusToSpeedStat(
  int speed,
  BattleStatusCondition status, {
  int generation = 9,
}) {
  if (status == BattleStatusCondition.paralysis) {
    return speed ~/ (generation < 7 ? 4 : 2);
  }
  return speed;
}

double heldItemDamageMultiplier({
  required BattleHeldItem heldItem,
  required double typeMultiplier,
  required String moveType,
  String? typeBoostItemType,
}) {
  return switch (heldItem) {
    BattleHeldItem.lifeOrb => 1.3,
    BattleHeldItem.expertBelt when typeMultiplier >= 2 => 1.2,
    BattleHeldItem.typeBoost
        when typeBoostItemType != null && typeBoostItemType == moveType =>
      1.2,
    _ => 1.0,
  };
}

/// Tera adds 0.5 STAB; Adaptability follows the current Tera type only.
double terastalStabMultiplier({
  required String moveType,
  required List<String> attackerTypes,
  required int generation,
  String? attackerAbilitySlug,
  bool attackerTerastallized = false,
  String? attackerTeraType,
}) {
  final effective = effectiveMoveType(moveType, attackerAbilitySlug);
  final normalized = normalizeTypesForGeneration(attackerTypes, generation);
  final original = normalized.contains(effective);
  final tera =
      attackerTerastallized && generation >= 9 && attackerTeraType != null;
  final sameTera = tera && effective == attackerTeraType;
  var stab = original ? 1.5 : 1.0;
  if (sameTera) stab += .5;
  if (attackerAbilitySlug == 'adaptability' && (tera ? sameTera : original)) {
    stab += sameTera && original ? .25 : .5;
  }
  return stab;
}

/// Best STAB multiplier an attacker can reach against a single-type defender.
double bestStabMultiplierAgainstDefender({
  required List<String> attackerTypes,
  required String defenderSingleType,
  required Map<String, TypeDamageRelations> relationsByType,
  required int generation,
  String? attackerAbilitySlug,
  bool attackerTerastallized = false,
  String? attackerTeraType,
}) {
  final candidates = <String>{
    ...normalizeTypesForGeneration(attackerTypes, generation),
    if (attackerTerastallized && attackerTeraType != null) attackerTeraType,
  };

  var best = 0.0;
  for (final moveType in candidates) {
    final input = BattleEffectivenessInput(
      defenderTypes: [defenderSingleType],
      relationsByType: relationsByType,
      attackerAbilitySlug: attackerAbilitySlug,
      generation: generation,
    );
    final typeMult = typeMultiplierForBattleMove(moveType, input);
    final stab = terastalStabMultiplier(
      moveType: moveType,
      attackerTypes: attackerTypes,
      generation: generation,
      attackerAbilitySlug: attackerAbilitySlug,
      attackerTerastallized: attackerTerastallized,
      attackerTeraType: attackerTeraType,
    );
    final combined = typeMult * stab;
    if (combined > best) {
      best = combined;
    }
  }
  return best;
}

List<String> computeOffensiveBlindSpots(
  List<String> attackerTypes,
  Map<String, TypeDamageRelations> relationsByType, {
  int generation = 9,
  String? attackerAbilitySlug,
  bool attackerTerastallized = false,
  String? attackerTeraType,
}) {
  final normalizedAttacker = normalizeTypesForGeneration(
    attackerTypes,
    generation,
  );
  if (normalizedAttacker.isEmpty &&
      !(attackerTerastallized && attackerTeraType != null)) {
    return const [];
  }

  final attackTypes = attackTypesForGeneration(generation);
  final blindSpots = <String>[];

  for (final targetType in attackTypes) {
    final best = bestStabMultiplierAgainstDefender(
      attackerTypes: attackerTypes,
      defenderSingleType: targetType,
      relationsByType: relationsByType,
      generation: generation,
      attackerAbilitySlug: attackerAbilitySlug,
      attackerTerastallized: attackerTerastallized,
      attackerTeraType: attackerTeraType,
    );
    if (best < 2) {
      blindSpots.add(typeNameZh(targetType));
    }
  }

  blindSpots.sort();
  return blindSpots;
}

List<String> computeDefensiveBlindSpots(BattleEffectivenessInput input) {
  return computeBattleDefensiveProfile(input).weaknesses;
}

/// Shared weaknesses appearing on at least [minMembers] party Pokémon.
List<String> computeTeamSharedWeaknesses(
  Iterable<List<String>> memberTypesList,
  Map<String, TypeDamageRelations> relationsByType, {
  int generation = 9,
  int minMembers = 2,
}) {
  final counts = <String, int>{};
  for (final types in memberTypesList) {
    final input = BattleEffectivenessInput(
      defenderTypes: types,
      relationsByType: relationsByType,
      generation: generation,
    );
    for (final weakness in computeBattleDefensiveProfile(input).weaknesses) {
      counts[weakness] = (counts[weakness] ?? 0) + 1;
    }
  }
  final shared =
      counts.entries
          .where((entry) => entry.value >= minMembers)
          .map((entry) => entry.key)
          .toList()
        ..sort();
  return shared;
}

const kManualDefensiveAbilityOptions = <String, String>{
  'sap-sipper': '食草',
  'thick-fat': '厚脂肪',
  'levitate': '漂浮',
  'flash-fire': '引火',
  'water-absorb': '储水',
  'volt-absorb': '蓄电',
  'lightning-rod': '避雷针',
  'storm-drain': '引水',
  'motor-drive': '电气引擎',
  'earth-eater': '食土',
  'well-baked-body': '焦香之躯',
  'heatproof': '耐热',
  'water-bubble': '水泡',
  'dry-skin': '干燥皮肤',
  'fluffy': '毛茸茸',
  'purifying-salt': '洁净之盐',
  'wonder-guard': '神奇守护',
  'filter': '过滤',
  'solid-rock': '坚硬岩石',
  'prism-armor': '棱镜装甲',
  'fur-coat': '毛皮大衣',
  'ice-scales': '冰鳞粉',
};

const kManualAttackerAbilityOptions = <String, String>{
  'scrappy': '胆量',
  'mind-s-eye': '精神力之瞳',
  'tinted-lens': '有色眼镜',
  'pixilate': '妖精皮肤',
  'aerilate': '飞行皮肤',
  'refrigerate': '冰冻皮肤',
  'galvanize': '电气皮肤',
  'huge-power': '大力士',
  'pure-power': '瑜伽之力',
  'mold-breaker': '破格',
  'adaptability': '适应力',
  'guts': '毅力',
  'technician': '技术高手',
};

String defaultTeraTypeFor(List<String> types, int generation) {
  final normalized = normalizeTypesForGeneration(types, generation);
  return normalized.isNotEmpty ? normalized.first : 'normal';
}
