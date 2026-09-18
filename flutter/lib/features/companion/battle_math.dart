import '../../l10n/app_locale.dart';
import '../../l10n/app_zh.dart';

import '../dex/battle_effectiveness.dart';
import '../dex/type_chart.dart';

enum BattleStat { hp, attack, defense, specialAttack, specialDefense, speed }

extension BattleStatLabel on BattleStat {
  String get labelZh => switch (this) {
    BattleStat.hp => 'HP',
    BattleStat.attack => '攻击',
    BattleStat.defense => '防御',
    BattleStat.specialAttack => '特攻',
    BattleStat.specialDefense => '特防',
    BattleStat.speed => '速度',
  };

  String get label => AppLocale.pick(
    zh: labelZh,
    en: switch (this) {
      BattleStat.hp => 'HP',
      BattleStat.attack => 'Attack',
      BattleStat.defense => 'Defense',
      BattleStat.specialAttack => 'Sp. Atk',
      BattleStat.specialDefense => 'Sp. Def',
      BattleStat.speed => 'Speed',
    },
  );

  String get apiKey => switch (this) {
    BattleStat.hp => 'hp',
    BattleStat.attack => 'attack',
    BattleStat.defense => 'defense',
    BattleStat.specialAttack => 'special-attack',
    BattleStat.specialDefense => 'special-defense',
    BattleStat.speed => 'speed',
  };
}

enum MoveCategory { physical, special }

extension MoveCategoryLabel on MoveCategory {
  String get labelZh => switch (this) {
    MoveCategory.physical => '物理',
    MoveCategory.special => '特殊',
  };

  String get label => AppLocale.pick(
    zh: labelZh,
    en: switch (this) {
      MoveCategory.physical => 'Physical',
      MoveCategory.special => 'Special',
    },
  );
}

class NatureModifier {
  const NatureModifier({
    required this.key,
    required this.labelZh,
    this.boost,
    this.drop,
  });

  final String key;
  final String labelZh;
  final BattleStat? boost;
  final BattleStat? drop;

  String get label {
    if (!AppLocale.instance.isEnglish) {
      return labelZh;
    }
    return '${key[0].toUpperCase()}${key.substring(1)}';
  }
}

const battleNatures = <NatureModifier>[
  NatureModifier(key: 'hardy', labelZh: '勤奋', boost: null, drop: null),
  NatureModifier(
    key: 'lonely',
    labelZh: '怕寂寞',
    boost: BattleStat.attack,
    drop: BattleStat.defense,
  ),
  NatureModifier(
    key: 'brave',
    labelZh: '勇敢',
    boost: BattleStat.attack,
    drop: BattleStat.speed,
  ),
  NatureModifier(
    key: 'adamant',
    labelZh: '固执',
    boost: BattleStat.attack,
    drop: BattleStat.specialAttack,
  ),
  NatureModifier(
    key: 'naughty',
    labelZh: '顽皮',
    boost: BattleStat.attack,
    drop: BattleStat.specialDefense,
  ),
  NatureModifier(
    key: 'bold',
    labelZh: '大胆',
    boost: BattleStat.defense,
    drop: BattleStat.attack,
  ),
  NatureModifier(key: 'docile', labelZh: '坦率', boost: null, drop: null),
  NatureModifier(
    key: 'relaxed',
    labelZh: '悠闲',
    boost: BattleStat.defense,
    drop: BattleStat.speed,
  ),
  NatureModifier(
    key: 'impish',
    labelZh: '淘气',
    boost: BattleStat.defense,
    drop: BattleStat.specialAttack,
  ),
  NatureModifier(
    key: 'lax',
    labelZh: '乐天',
    boost: BattleStat.defense,
    drop: BattleStat.specialDefense,
  ),
  NatureModifier(
    key: 'timid',
    labelZh: '胆小',
    boost: BattleStat.speed,
    drop: BattleStat.attack,
  ),
  NatureModifier(
    key: 'hasty',
    labelZh: '急躁',
    boost: BattleStat.speed,
    drop: BattleStat.defense,
  ),
  NatureModifier(key: 'serious', labelZh: '认真', boost: null, drop: null),
  NatureModifier(
    key: 'jolly',
    labelZh: '爽朗',
    boost: BattleStat.speed,
    drop: BattleStat.specialAttack,
  ),
  NatureModifier(
    key: 'naive',
    labelZh: '天真',
    boost: BattleStat.speed,
    drop: BattleStat.specialDefense,
  ),
  NatureModifier(
    key: 'modest',
    labelZh: '内敛',
    boost: BattleStat.specialAttack,
    drop: BattleStat.attack,
  ),
  NatureModifier(
    key: 'mild',
    labelZh: '慢吞吞',
    boost: BattleStat.specialAttack,
    drop: BattleStat.defense,
  ),
  NatureModifier(
    key: 'quiet',
    labelZh: '冷静',
    boost: BattleStat.specialAttack,
    drop: BattleStat.speed,
  ),
  NatureModifier(key: 'bashful', labelZh: '害羞', boost: null, drop: null),
  NatureModifier(
    key: 'rash',
    labelZh: '马虎',
    boost: BattleStat.specialAttack,
    drop: BattleStat.specialDefense,
  ),
  NatureModifier(
    key: 'calm',
    labelZh: '温和',
    boost: BattleStat.specialDefense,
    drop: BattleStat.attack,
  ),
  NatureModifier(
    key: 'gentle',
    labelZh: '温顺',
    boost: BattleStat.specialDefense,
    drop: BattleStat.defense,
  ),
  NatureModifier(
    key: 'sassy',
    labelZh: '自大',
    boost: BattleStat.specialDefense,
    drop: BattleStat.speed,
  ),
  NatureModifier(
    key: 'careful',
    labelZh: '慎重',
    boost: BattleStat.specialDefense,
    drop: BattleStat.specialAttack,
  ),
  NatureModifier(key: 'quirky', labelZh: '浮躁', boost: null, drop: null),
];

int clampIvEv(int value, int max) => value.clamp(0, max);

int computeBattleStat({
  required BattleStat stat,
  required int base,
  required int level,
  required int iv,
  required int ev,
  required NatureModifier nature,
  String? attackerAbilitySlug,
  bool isPhysicalStat = false,
  BattleHeldItem heldItem = BattleHeldItem.none,
  BattleStatusCondition status = BattleStatusCondition.none,
}) {
  final safeIv = clampIvEv(iv, 31);
  final safeEv = clampIvEv(ev, 252);
  final inner = (2 * base + safeIv + safeEv ~/ 4) * level ~/ 100;

  if (stat == BattleStat.hp) {
    return inner + level + 10;
  }

  var value = inner + 5;
  if (nature.boost == stat) {
    value = (value * 1.1).floor();
  } else if (nature.drop == stat) {
    value = (value * 0.9).floor();
  }

  if (stat == BattleStat.attack && isPhysicalStat) {
    value = applyAttackerAbilityToAttackStat(value, true, attackerAbilitySlug);
    value = applyHeldItemToAttackStat(value, true, heldItem);
    value = applyStatusToAttackStat(value, true, status);
  } else if (stat == BattleStat.specialAttack && !isPhysicalStat) {
    value = applyHeldItemToAttackStat(value, false, heldItem);
  } else if (stat == BattleStat.speed) {
    value = applyStatusToSpeedStat(value, status);
  }

  return value;
}

double typeMultiplierForMove(
  String moveType,
  List<String> defenderTypes,
  Map<String, TypeDamageRelations> relationsByType, {
  String? defenderAbilitySlug,
  String? attackerAbilitySlug,
  int generation = 9,
  bool defenderTerastallized = false,
  String? defenderTeraType,
}) {
  final input = BattleEffectivenessInput(
    defenderTypes: defenderTypes,
    relationsByType: relationsByType,
    defenderAbilitySlug: defenderAbilitySlug,
    attackerAbilitySlug: attackerAbilitySlug,
    generation: generation,
    defenderTerastallized: defenderTerastallized,
    defenderTeraType: defenderTeraType,
  );
  return typeMultiplierForBattleMove(moveType, input);
}

int computeBaseDamage({
  required int level,
  required int power,
  required int attack,
  required int defense,
}) {
  if (power <= 0 || attack <= 0 || defense <= 0 || level <= 0) {
    return 0;
  }
  final scaled = ((2 * level ~/ 5 + 2) * power * attack) ~/ defense;
  return scaled ~/ 50 + 2;
}

class DamageEstimate {
  const DamageEstimate({
    required this.minDamage,
    required this.maxDamage,
    required this.minPercent,
    required this.maxPercent,
    required this.verdictZh,
    required this.tankVerdictZh,
    required this.typeMultiplier,
    required this.stabMultiplier,
    required this.extraMultiplier,
  });

  final int minDamage;
  final int maxDamage;
  final double minPercent;
  final double maxPercent;
  final String verdictZh;
  final String tankVerdictZh;
  final double typeMultiplier;
  final double stabMultiplier;
  final double extraMultiplier;
}

DamageEstimate estimateDamage({
  required int level,
  required int power,
  required int attack,
  required int defense,
  required int defenderHp,
  required String moveType,
  required List<String> attackerTypes,
  required List<String> defenderTypes,
  required Map<String, TypeDamageRelations> relationsByType,
  String? defenderAbilitySlug,
  String? attackerAbilitySlug,
  int generation = 9,
  String? weatherSlug,
  String? terrainSlug,
  MoveCategory category = MoveCategory.physical,
  bool defenderTerastallized = false,
  String? defenderTeraType,
  bool attackerTerastallized = false,
  String? attackerTeraType,
  BattleHeldItem attackerHeldItem = BattleHeldItem.none,
  String? typeBoostItemType,
  BattleStatusCondition attackerStatus = BattleStatusCondition.none,
  bool isContactMove = false,
  bool isCriticalHit = false,
  bool defenderScreened = false,
  bool isSpreadMove = false,
  double otherMultiplier = 1,
  bool ignoreBurn = false,
  bool usesPhysicalDefense = false,
  bool teraPowerFloorEligible = false,
}) {
  final isPhysical = category == MoveCategory.physical;
  final groundingAbility = defenderAbilitySlug;
  defenderAbilitySlug = effectiveDefenderAbility(
    attackerAbilitySlug,
    defenderAbilitySlug,
  );
  final effectiveType = effectiveMoveType(moveType, attackerAbilitySlug);
  final effectiveTypes =
      defenderTerastallized && generation >= 9 && defenderTeraType != null
      ? [defenderTeraType]
      : defenderTypes;

  var effectiveAttack = applyAttackerAbilityToAttackStat(
    attack,
    isPhysical,
    attackerAbilitySlug,
  );
  effectiveAttack = applyHeldItemToAttackStat(
    effectiveAttack,
    isPhysical,
    attackerHeldItem,
  );
  if (attackerAbilitySlug == 'guts' &&
      isPhysical &&
      attackerStatus != BattleStatusCondition.none) {
    effectiveAttack = (effectiveAttack * 1.5).floor();
  }
  if (attackerAbilitySlug == 'water-bubble' && effectiveType == 'water') {
    effectiveAttack *= 2;
  }
  final halfAttack =
      (defenderAbilitySlug == 'thick-fat' &&
          const {'fire', 'ice'}.contains(effectiveType)) ||
      (const {'heatproof', 'water-bubble'}.contains(defenderAbilitySlug) &&
          effectiveType == 'fire') ||
      (defenderAbilitySlug == 'purifying-salt' && effectiveType == 'ghost');
  if (halfAttack) {
    effectiveAttack = (effectiveAttack / 2).floor().clamp(1, 99999);
  }
  var effectiveDefense = defense;
  if ((isPhysical || usesPhysicalDefense) &&
      defenderAbilitySlug == 'fur-coat') {
    effectiveDefense *= 2;
  }
  if (!(isPhysical || usesPhysicalDefense) &&
      generation >= 4 &&
      weatherSlug == 'sandstorm' &&
      effectiveTypes.contains('rock')) {
    effectiveDefense = (effectiveDefense * 1.5).floor();
  }
  if ((isPhysical || usesPhysicalDefense) &&
      generation >= 9 &&
      weatherSlug == 'snow' &&
      effectiveTypes.contains('ice')) {
    effectiveDefense = (effectiveDefense * 1.5).floor();
  }
  var effectivePower = power;
  if (moveType == 'normal' &&
      kAbilityMoveTypeConversion.containsKey(attackerAbilitySlug)) {
    effectivePower = (effectivePower * (generation == 6 ? 1.3 : 1.2)).round();
  }
  if (attackerAbilitySlug == 'technician' && power <= 60) {
    effectivePower = (effectivePower * 1.5).floor();
  }
  if (generation >= 9 &&
      attackerTerastallized &&
      teraPowerFloorEligible &&
      attackerTeraType == effectiveType &&
      effectivePower < 60) {
    effectivePower = 60;
  }

  final stab = terastalStabMultiplier(
    moveType: moveType,
    attackerTypes: attackerTypes,
    generation: generation,
    attackerAbilitySlug: attackerAbilitySlug,
    attackerTerastallized: attackerTerastallized,
    attackerTeraType: attackerTeraType,
  );

  final input = BattleEffectivenessInput(
    defenderTypes: defenderTypes,
    relationsByType: relationsByType,
    defenderAbilitySlug: groundingAbility,
    attackerAbilitySlug: attackerAbilitySlug,
    generation: generation,
    weatherSlug: weatherSlug,
    attackerTypes: attackerTypes,
    terrainSlug: terrainSlug,
    defenderTerastallized: defenderTerastallized,
    defenderTeraType: defenderTeraType,
    attackerTerastallized: attackerTerastallized,
    attackerTeraType: attackerTeraType,
  );
  final effectiveMove = effectiveMoveType(moveType, attackerAbilitySlug);
  final type = typeMultiplierForBattleMove(moveType, input);
  final fieldMod = fieldMoveTypeModifier(effectiveMove, input);
  final weatherMod =
      kFieldMoveTypeModifiers[weatherSlug]?[effectiveMove] ?? 1.0;
  final terrainMod = weatherMod == 0 ? 1.0 : fieldMod / weatherMod;
  // Terrain, type-boosting items and Dry Skin change power, not final damage.
  final powerItem =
      attackerHeldItem == BattleHeldItem.typeBoost &&
          typeBoostItemType == effectiveType
      ? 1.2
      : 1.0;
  final drySkin = defenderAbilitySlug == 'dry-skin' && effectiveType == 'fire'
      ? 1.25
      : 1.0;
  effectivePower =
      (effectivePower * terrainMod * powerItem * drySkin * otherMultiplier)
          .floor();
  final base = computeBaseDamage(
    level: level,
    power: effectivePower,
    attack: effectiveAttack,
    defense: effectiveDefense,
  );
  final rawType = typeMultiplierForMove(
    moveType,
    defenderTypes,
    relationsByType,
    attackerAbilitySlug: attackerAbilitySlug,
    generation: generation,
    defenderTerastallized: defenderTerastallized,
    defenderTeraType: defenderTeraType,
  );
  final abilityMod = abilityDamageMultiplier(
    typeMultiplier: rawType,
    defenderAbilitySlug: defenderAbilitySlug,
    attackerAbilitySlug: attackerAbilitySlug,
  );
  final defenderMod = defenderAbilityDamageMultiplier(
    isPhysical: isPhysical,
    defenderAbilitySlug: defenderAbilitySlug == 'fur-coat'
        ? null
        : defenderAbilitySlug,
    isContactMove: isContactMove,
  );
  final itemMod = heldItemDamageMultiplier(
    heldItem: attackerHeldItem,
    typeMultiplier: rawType,
    moveType: effectiveType,
    typeBoostItemType: typeBoostItemType,
  );
  final damageType = type == 0 ? 0.0 : rawType;
  final fluffyFire = defenderAbilitySlug == 'fluffy' && effectiveType == 'fire'
      ? 2.0
      : 1.0;
  // Critical hits: ×2 before Gen 6, ×1.5 since — and they bypass screens.
  isCriticalHit =
      isCriticalHit &&
      !const {'battle-armor', 'shell-armor'}.contains(defenderAbilitySlug);
  final critMod = isCriticalHit ? (generation >= 6 ? 1.5 : 2.0) : 1.0;
  final screenMod =
      defenderScreened && !isCriticalHit && attackerAbilitySlug != 'infiltrator'
      ? 0.5
      : 1.0;
  // Doubles: a move hitting multiple targets takes the ×0.75 spread
  // modifier (Gen 3+). Crits do not bypass it.
  final spreadMod = isSpreadMove ? (generation == 3 ? .5 : .75) : 1.0;
  final burnMod =
      isPhysical &&
          attackerStatus == BattleStatusCondition.burn &&
          !const {'guts', 'water-bubble'}.contains(attackerAbilitySlug) &&
          !ignoreBurn
      ? .5
      : 1.0;
  final extra =
      fieldMod *
      abilityMod *
      defenderMod *
      itemMod *
      critMod *
      screenMod *
      spreadMod *
      otherMultiplier *
      burnMod *
      (isCriticalHit && attackerAbilitySlug == 'sniper' ? 1.5 : 1.0);
  // Apply random roll before STAB/type; round between stages rather than
  // flooring one giant product. This remains an estimate for unmodelled states.
  int roll(int random) {
    if (type == 0 || base <= 0) return 0;
    var damage = (base * spreadMod).floor();
    damage = (damage * weatherMod).floor();
    damage = (damage * critMod).floor();
    damage = damage * random ~/ 100;
    damage = (damage * stab).floor();
    damage = (damage * damageType).floor();
    damage = (damage * burnMod).floor();
    damage =
        (damage *
                abilityMod *
                defenderMod *
                (itemMod / powerItem) *
                screenMod *
                fluffyFire *
                (isCriticalHit && attackerAbilitySlug == 'sniper' ? 1.5 : 1.0))
            .floor();
    return damage < 1 ? 1 : damage;
  }

  final minDamage = roll(85);
  final maxDamage = roll(100);
  final safeHp = defenderHp <= 0 ? 1 : defenderHp;
  final minPercent = minDamage / safeHp * 100;
  final maxPercent = maxDamage / safeHp * 100;

  return DamageEstimate(
    minDamage: minDamage,
    maxDamage: maxDamage,
    minPercent: minPercent,
    maxPercent: maxPercent,
    verdictZh: _offenseVerdict(minDamage, maxDamage, safeHp),
    tankVerdictZh: _tankVerdict(minDamage, maxDamage, safeHp),
    typeMultiplier: type,
    stabMultiplier: stab,
    extraMultiplier: extra,
  );
}

String _offenseVerdict(int minDamage, int maxDamage, int hp) {
  if (maxDamage <= 0) {
    return AppZh.damageNone;
  }
  if (minDamage >= hp) {
    return AppZh.damageGuaranteedKo;
  }
  if (maxDamage >= hp) {
    return AppZh.damagePossibleKo;
  }
  if (maxDamage * 2 >= hp) {
    return AppZh.damagePossible2hko;
  }
  return AppZh.damageLow;
}

String _tankVerdict(int minDamage, int maxDamage, int hp) {
  if (maxDamage <= 0) {
    return AppZh.tankImmune;
  }
  if (minDamage >= hp) {
    return AppZh.tankGuaranteedKo;
  }
  if (maxDamage >= hp) {
    return AppZh.tankPossibleKo;
  }
  if (maxDamage * 2 >= hp) {
    return AppZh.tankPossible2hko;
  }
  return AppZh.tankLikelySurvives;
}

DamageEstimate fixedDamageEstimate(
  int damage,
  int defenderHp,
  double effectiveness,
) {
  final value = effectiveness == 0 ? 0 : damage;
  final hp = defenderHp > 0 ? defenderHp : 1;
  return DamageEstimate(
    minDamage: value,
    maxDamage: value,
    minPercent: value / hp * 100,
    maxPercent: value / hp * 100,
    verdictZh: _offenseVerdict(value, value, hp),
    tankVerdictZh: _tankVerdict(value, value, hp),
    typeMultiplier: effectiveness,
    stabMultiplier: 1,
    extraMultiplier: 1,
  );
}
