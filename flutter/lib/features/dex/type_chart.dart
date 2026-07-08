/// Type effectiveness helpers with Chinese labels.
library;

const typeNamesZh = <String, String>{
  'normal': '一般',
  'fire': '火',
  'water': '水',
  'electric': '电',
  'grass': '草',
  'ice': '冰',
  'fighting': '格斗',
  'poison': '毒',
  'ground': '地面',
  'flying': '飞行',
  'psychic': '超能力',
  'bug': '虫',
  'rock': '岩石',
  'ghost': '幽灵',
  'dragon': '龙',
  'dark': '恶',
  'steel': '钢',
  'fairy': '妖精',
};

String typeNameZh(String type) => typeNamesZh[type] ?? type;

/// Defensive profile: how incoming attack types interact with [defenderTypes].
class DefensiveProfile {
  const DefensiveProfile({
    required this.weaknesses,
    required this.resistances,
    required this.immunities,
  });

  final List<String> weaknesses;
  final List<String> resistances;
  final List<String> immunities;
}

/// Cached damage relations for one attack type from PokeAPI.
class TypeDamageRelations {
  const TypeDamageRelations({
    required this.doubleDamageTo,
    required this.halfDamageTo,
    required this.noDamageTo,
  });

  final Set<String> doubleDamageTo;
  final Set<String> halfDamageTo;
  final Set<String> noDamageTo;
}

DefensiveProfile computeDefensiveProfile(
  List<String> defenderTypes,
  Map<String, TypeDamageRelations> relationsByType,
) {
  final multipliers = <String, double>{};

  for (final attackType in typeNamesZh.keys) {
    var multiplier = 1.0;
    for (final defenderType in defenderTypes) {
      final relations = relationsByType[attackType];
      if (relations == null) {
        continue;
      }
      if (relations.noDamageTo.contains(defenderType)) {
        multiplier = 0;
        break;
      }
      if (relations.doubleDamageTo.contains(defenderType)) {
        multiplier *= 2;
      } else if (relations.halfDamageTo.contains(defenderType)) {
        multiplier *= 0.5;
      }
    }
    multipliers[attackType] = multiplier;
  }

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

/// Offensive profile: types that [attackerTypes] hit for super-effective damage.
List<String> computeStabSuperEffective(
  List<String> attackerTypes,
  Map<String, TypeDamageRelations> relationsByType,
) {
  final effective = <String>{};

  for (final attackType in attackerTypes) {
    final relations = relationsByType[attackType];
    if (relations == null) {
      continue;
    }
    for (final target in relations.doubleDamageTo) {
      effective.add(typeNameZh(target));
    }
  }

  final sorted = effective.toList()..sort();
  return sorted;
}

TypeDamageRelations parseTypeDamageRelations(Map<String, dynamic> json) {
  Set<String> names(String key) {
    final list = json[key] as List<dynamic>? ?? const [];
    return list
        .map((item) => (item as Map<String, dynamic>)['name'] as String)
        .toSet();
  }

  return TypeDamageRelations(
    doubleDamageTo: names('double_damage_to'),
    halfDamageTo: names('half_damage_to'),
    noDamageTo: names('no_damage_to'),
  );
}
