/// Unified type effectiveness for battle tools (generation, abilities, weather).
library;

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

/// Attacker abilities that change Normal move type for effectiveness.
const kAbilityMoveTypeConversion = <String, String>{
  'pixilate': 'fairy',
  'aerilate': 'flying',
  'refrigerate': 'ice',
  'galvanize': 'electric',
};

/// Attacker abilities that bypass Ghost immunity (Normal/Fighting).
const kAttackerGhostBypassAbilities = {
  'scrappy',
  'mind-s-eye',
  'odor-sleuth',
  'foresight',
};

/// Defender / attacker abilities that alter final damage (not the 18-type grid).
const kDefenderSuperEffectiveReductionAbilities = {
  'filter',
  'solid-rock',
  'prism-armor',
};

const kAttackerResistDoublingAbilities = {'tinted-lens'};

const kAttackerPhysicalDoubleAbilities = {'huge-power', 'pure-power'};

class BattleEffectivenessInput {
  const BattleEffectivenessInput({
    required this.defenderTypes,
    required this.relationsByType,
    this.defenderAbilitySlug,
    this.attackerAbilitySlug,
    this.generation = 9,
    this.weatherSlug,
    this.terrainSlug,
  });

  final List<String> defenderTypes;
  final Map<String, TypeDamageRelations> relationsByType;
  final String? defenderAbilitySlug;
  final String? attackerAbilitySlug;
  final int generation;
  final String? weatherSlug;
  final String? terrainSlug;

  List<String> get normalizedDefenderTypes =>
      normalizeTypesForGeneration(defenderTypes, generation);

  Map<String, TypeDamageRelations> get generationRelations =>
      typeRelationsForGeneration(relationsByType, generation);
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

void _applyAttackerImmunityBypass(
  Map<String, double> multipliers,
  BattleEffectivenessInput input,
) {
  final slug = input.attackerAbilitySlug;
  if (slug == null) {
    return;
  }
  final defenderTypes = input.normalizedDefenderTypes;

  if (defenderTypes.contains('ghost') &&
      kAttackerGhostBypassAbilities.contains(slug)) {
    for (final attackType in ['normal', 'fighting']) {
      if ((multipliers[attackType] ?? 1) == 0) {
        multipliers[attackType] = 1;
      }
    }
  }

  if (defenderTypes.contains('dark') && slug == 'miracle-eye') {
    if ((multipliers['psychic'] ?? 1) == 0) {
      multipliers['psychic'] = 1;
    }
  }
}

void _applyWonderGuard(Map<String, double> multipliers) {
  for (final key in multipliers.keys.toList()) {
    if ((multipliers[key] ?? 1) < 2) {
      multipliers[key] = 0;
    }
  }
}

Map<String, double> computeBattleTypeMultipliers(BattleEffectivenessInput input) {
  final multipliers = computeDefensiveMultipliers(
    input.normalizedDefenderTypes,
    input.generationRelations,
  );

  applyAbilityTypeModifiers(multipliers, input.defenderAbilitySlug);
  _applyAttackerImmunityBypass(multipliers, input);

  if (input.defenderAbilitySlug == 'wonder-guard') {
    _applyWonderGuard(multipliers);
  }

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
  if (terrain != null && kFieldMoveTypeModifiers.containsKey(terrain)) {
    modifier *= kFieldMoveTypeModifiers[terrain]![moveType] ?? 1.0;
  }
  return modifier;
}

/// Extra damage multiplier from abilities (Filter, Tinted Lens, …).
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

/// Types that resist all of [attackerTypes] STAB (max multiplier < 2 vs single-type).
List<String> computeOffensiveBlindSpots(
  List<String> attackerTypes,
  Map<String, TypeDamageRelations> relationsByType, {
  int generation = 9,
  String? attackerAbilitySlug,
}) {
  final normalizedAttacker =
      normalizeTypesForGeneration(attackerTypes, generation);
  if (normalizedAttacker.isEmpty) {
    return const [];
  }

  final attackTypes = attackTypesForGeneration(generation);
  final blindSpots = <String>[];

  for (final targetType in attackTypes) {
    var bestStab = 0.0;
    for (final stabType in normalizedAttacker) {
      final input = BattleEffectivenessInput(
        defenderTypes: [targetType],
        relationsByType: relationsByType,
        attackerAbilitySlug: attackerAbilitySlug,
        generation: generation,
      );
      final mult = typeMultiplierForBattleMove(stabType, input);
      if (mult > bestStab) {
        bestStab = mult;
      }
    }
    if (bestStab < 2) {
      blindSpots.add(typeNameZh(targetType));
    }
  }

  blindSpots.sort();
  return blindSpots;
}

/// Types that hit [defenderTypes] for ≥2× (weaknesses under current modifiers).
List<String> computeDefensiveBlindSpots(BattleEffectivenessInput input) {
  return computeBattleDefensiveProfile(input).weaknesses;
}

/// Common type-affecting abilities for manual pick (slug → zh label).
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
};

const kManualAttackerAbilityOptions = <String, String>{
  'scrappy': '胆量',
  'mind-s-eye': '精神力之瞳',
  'miracle-eye': '奇迹之眼',
  'tinted-lens': '有色眼镜',
  'pixilate': '妖精皮肤',
  'aerilate': '飞行皮肤',
  'refrigerate': '冰冻皮肤',
  'galvanize': '电气皮肤',
  'huge-power': '大力士',
  'pure-power': '瑜伽之力',
};

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
}
