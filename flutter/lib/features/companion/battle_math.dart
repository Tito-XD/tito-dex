import '../dex/ability_type_modifiers.dart';
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
}

const battleNatures = <NatureModifier>[
  NatureModifier(key: 'hardy', labelZh: '勤奋', boost: null, drop: null),
  NatureModifier(key: 'lonely', labelZh: '怕寂寞', boost: BattleStat.attack, drop: BattleStat.defense),
  NatureModifier(key: 'brave', labelZh: '勇敢', boost: BattleStat.attack, drop: BattleStat.speed),
  NatureModifier(key: 'adamant', labelZh: '固执', boost: BattleStat.attack, drop: BattleStat.specialAttack),
  NatureModifier(key: 'naughty', labelZh: '顽皮', boost: BattleStat.attack, drop: BattleStat.specialDefense),
  NatureModifier(key: 'bold', labelZh: '大胆', boost: BattleStat.defense, drop: BattleStat.attack),
  NatureModifier(key: 'docile', labelZh: '坦率', boost: null, drop: null),
  NatureModifier(key: 'relaxed', labelZh: '悠闲', boost: BattleStat.defense, drop: BattleStat.speed),
  NatureModifier(key: 'impish', labelZh: '淘气', boost: BattleStat.defense, drop: BattleStat.specialAttack),
  NatureModifier(key: 'lax', labelZh: '乐天', boost: BattleStat.defense, drop: BattleStat.specialDefense),
  NatureModifier(key: 'timid', labelZh: '胆小', boost: BattleStat.speed, drop: BattleStat.attack),
  NatureModifier(key: 'hasty', labelZh: '急躁', boost: BattleStat.speed, drop: BattleStat.defense),
  NatureModifier(key: 'serious', labelZh: '认真', boost: null, drop: null),
  NatureModifier(key: 'jolly', labelZh: '爽朗', boost: BattleStat.speed, drop: BattleStat.specialAttack),
  NatureModifier(key: 'naive', labelZh: '天真', boost: BattleStat.speed, drop: BattleStat.specialDefense),
  NatureModifier(key: 'modest', labelZh: '内敛', boost: BattleStat.specialAttack, drop: BattleStat.attack),
  NatureModifier(key: 'mild', labelZh: '慢吞吞', boost: BattleStat.specialAttack, drop: BattleStat.defense),
  NatureModifier(key: 'quiet', labelZh: '冷静', boost: BattleStat.specialAttack, drop: BattleStat.speed),
  NatureModifier(key: 'bashful', labelZh: '害羞', boost: null, drop: null),
  NatureModifier(key: 'rash', labelZh: '马虎', boost: BattleStat.specialAttack, drop: BattleStat.specialDefense),
  NatureModifier(key: 'calm', labelZh: '温和', boost: BattleStat.specialDefense, drop: BattleStat.attack),
  NatureModifier(key: 'gentle', labelZh: '温顺', boost: BattleStat.specialDefense, drop: BattleStat.defense),
  NatureModifier(key: 'sassy', labelZh: '自大', boost: BattleStat.specialDefense, drop: BattleStat.speed),
  NatureModifier(key: 'careful', labelZh: '慎重', boost: BattleStat.specialDefense, drop: BattleStat.specialAttack),
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
  return value;
}

double typeMultiplierForMove(
  String moveType,
  List<String> defenderTypes,
  Map<String, TypeDamageRelations> relationsByType, {
  String? defenderAbilitySlug,
}) {
  final multipliers = computeDefensiveMultipliersWithAbility(
    defenderTypes: defenderTypes,
    relationsByType: relationsByType,
    defenderAbilitySlug: defenderAbilitySlug,
  );
  return multipliers[moveType] ?? 1;
}

bool hasStab(String moveType, List<String> attackerTypes) =>
    attackerTypes.contains(moveType);

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
  });

  final int minDamage;
  final int maxDamage;
  final double minPercent;
  final double maxPercent;
  final String verdictZh;
  final String tankVerdictZh;
  final double typeMultiplier;
  final double stabMultiplier;
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
  double otherMultiplier = 1,
}) {
  final base = computeBaseDamage(
    level: level,
    power: power,
    attack: attack,
    defense: defense,
  );
  final stab = hasStab(moveType, attackerTypes) ? 1.5 : 1.0;
  final type = typeMultiplierForMove(
    moveType,
    defenderTypes,
    relationsByType,
    defenderAbilitySlug: defenderAbilitySlug,
  );
  final modifier = stab * type * otherMultiplier;
  final minDamage = (base * modifier * 0.85).floor();
  final maxDamage = (base * modifier).floor();
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
  );
}

String _offenseVerdict(int minDamage, int maxDamage, int hp) {
  if (maxDamage <= 0) {
    return '无伤害';
  }
  if (minDamage >= hp) {
    return '稳秒杀';
  }
  if (maxDamage >= hp) {
    return '可能秒杀';
  }
  if (maxDamage * 2 >= hp) {
    return '可能两招击杀';
  }
  return '伤害偏低';
}

String _tankVerdict(int minDamage, int maxDamage, int hp) {
  if (maxDamage <= 0) {
    return '完全免疫或无伤';
  }
  if (minDamage >= hp) {
    return '扛不住（必倒）';
  }
  if (maxDamage >= hp) {
    return '有风险（可能被秒）';
  }
  if (maxDamage * 2 >= hp) {
    return '较危险（两招可能倒）';
  }
  return '大概率能扛住';
}
