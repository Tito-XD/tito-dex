/// Type effectiveness helpers with Chinese labels.
library;

import 'package:flutter/material.dart';

import 'ability_type_modifiers.dart';

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

String? typeEnForZh(String labelZh) {
  for (final entry in typeNamesZh.entries) {
    if (entry.value == labelZh) {
      return entry.key;
    }
  }
  return null;
}

/// Friendly symbol per type — icon + Chinese label combo (52poke style).
///
/// PokeAPI's `type` sprites only ship English *name* badges
/// (`name_icon`), so TitoDex draws its own sticker-style symbols instead.
IconData typeIconData(String type) => switch (type) {
      'normal' => Icons.circle_outlined,
      'fire' => Icons.local_fire_department,
      'water' => Icons.water_drop,
      'electric' => Icons.bolt,
      'grass' => Icons.grass,
      'ice' => Icons.ac_unit,
      'fighting' => Icons.sports_mma,
      'poison' => Icons.science,
      'ground' => Icons.terrain,
      'flying' => Icons.air,
      'psychic' => Icons.psychology,
      'bug' => Icons.bug_report,
      'rock' => Icons.diamond,
      'ghost' => Icons.blur_on,
      'dragon' => Icons.cyclone,
      'dark' => Icons.dark_mode,
      'steel' => Icons.shield,
      'fairy' => Icons.auto_awesome,
      _ => Icons.help_outline,
    };

Color typeTileColor(String type) => switch (type) {
      'normal' => const Color(0xFFD8D3C3),
      'fire' => const Color(0xFFF5A26F),
      'water' => const Color(0xFF7CB7FF),
      'electric' => const Color(0xFFF7D977),
      'grass' => const Color(0xFF8ED081),
      'ice' => const Color(0xFF9BE7E6),
      'fighting' => const Color(0xFFE07B62),
      'poison' => const Color(0xFFC68FD9),
      'ground' => const Color(0xFFE6C07A),
      'flying' => const Color(0xFFB8C8F0),
      'psychic' => const Color(0xFFFF8CB3),
      'bug' => const Color(0xFFB5D06A),
      'rock' => const Color(0xFFC9B48A),
      'ghost' => const Color(0xFF9F8AC8),
      'dragon' => const Color(0xFF7B8CFF),
      'dark' => const Color(0xFF9B8B7D),
      'steel' => const Color(0xFFB0C0CF),
      'fairy' => const Color(0xFFFFA9D6),
      _ => const Color(0xFFB8D8F0),
    };

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
  Map<String, TypeDamageRelations> relationsByType, {
  String? defenderAbilitySlug,
}) {
  final multipliers = computeDefensiveMultipliersWithAbility(
    defenderTypes: defenderTypes,
    relationsByType: relationsByType,
    defenderAbilitySlug: defenderAbilitySlug,
  );

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

/// Per attack-type multiplier when hitting [defenderTypes] (0, 0.25, 0.5, 1, 2, 4).
Map<String, double> computeDefensiveMultipliers(
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

  return multipliers;
}

Map<String, double> computeDefensiveMultipliersWithAbility({
  required List<String> defenderTypes,
  required Map<String, TypeDamageRelations> relationsByType,
  String? defenderAbilitySlug,
}) {
  final multipliers = computeDefensiveMultipliers(defenderTypes, relationsByType);
  applyAbilityTypeModifiers(multipliers, defenderAbilitySlug);
  return multipliers;
}

String formatTypeMultiplier(double multiplier) {
  if (multiplier == 0) {
    return '0';
  }
  if (multiplier <= 0.25) {
    return '1/4';
  }
  if (multiplier <= 0.5) {
    return '1/2';
  }
  if (multiplier >= 4) {
    return '4';
  }
  if (multiplier >= 2) {
    return '2';
  }
  return '1';
}

/// Stable display order for the 18-type effectiveness grid.
const typeGridOrder = <String>[
  'normal',
  'fire',
  'water',
  'electric',
  'grass',
  'ice',
  'fighting',
  'poison',
  'ground',
  'flying',
  'psychic',
  'bug',
  'rock',
  'ghost',
  'dragon',
  'dark',
  'steel',
  'fairy',
];

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
