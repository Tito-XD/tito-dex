import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/companion/battle_math.dart';
import 'package:titodex/features/dex/battle_effectiveness.dart';
import 'package:titodex/features/dex/generation_type_chart.dart';
import 'package:titodex/features/dex/type_chart.dart';

void main() {
  final relations = <String, TypeDamageRelations>{
    'grass': const TypeDamageRelations(
      doubleDamageTo: {'water', 'ground', 'rock'},
      halfDamageTo: {
        'fire',
        'grass',
        'poison',
        'flying',
        'bug',
        'dragon',
        'steel',
      },
      noDamageTo: {},
    ),
    'fire': const TypeDamageRelations(
      doubleDamageTo: {'grass', 'ice', 'bug', 'steel'},
      halfDamageTo: {'fire', 'water', 'rock', 'dragon'},
      noDamageTo: {},
    ),
    'normal': const TypeDamageRelations(
      doubleDamageTo: {},
      halfDamageTo: {'rock', 'steel'},
      noDamageTo: {'ghost'},
    ),
    'fighting': const TypeDamageRelations(
      doubleDamageTo: {'normal', 'rock', 'steel', 'ice', 'dark'},
      halfDamageTo: {'poison', 'flying', 'psychic', 'bug', 'fairy'},
      noDamageTo: {'ghost'},
    ),
    'ghost': const TypeDamageRelations(
      doubleDamageTo: {'psychic', 'ghost'},
      halfDamageTo: {'dark'},
      noDamageTo: {'normal', 'fighting'},
    ),
    'steel': const TypeDamageRelations(
      doubleDamageTo: {'ice', 'rock', 'fairy'},
      halfDamageTo: {
        'fire',
        'water',
        'electric',
        'steel',
        'ghost',
        'dark',
      },
      noDamageTo: {},
    ),
  };

  test('sap sipper makes grass immune on water/fairy Azumarill', () {
    final input = BattleEffectivenessInput(
      defenderTypes: const ['water', 'fairy'],
      relationsByType: relations,
      defenderAbilitySlug: 'sap-sipper',
    );
    final multipliers = computeBattleTypeMultipliers(input);
    expect(formatTypeMultiplier(multipliers['grass'] ?? 1), '0');
  });

  test('scrappy lets normal hit ghost', () {
    final input = BattleEffectivenessInput(
      defenderTypes: const ['ghost'],
      relationsByType: relations,
      attackerAbilitySlug: 'scrappy',
    );
    final multipliers = computeBattleTypeMultipliers(input);
    expect(formatTypeMultiplier(multipliers['normal'] ?? 0), '1');
  });

  test('wonder guard only allows super effective hits', () {
    final input = BattleEffectivenessInput(
      defenderTypes: const ['normal'],
      relationsByType: relations,
      defenderAbilitySlug: 'wonder-guard',
    );
    final multipliers = computeBattleTypeMultipliers(input);
    expect(formatTypeMultiplier(multipliers['normal'] ?? 1), '0');
    expect(formatTypeMultiplier(multipliers['fighting'] ?? 1), '2');
  });

  test('gen 4 strips fairy from defender types', () {
    final normalized = normalizeTypesForGeneration(
      const ['water', 'fairy'],
      4,
    );
    expect(normalized, ['water']);
  });

  test('gen 5 steel does not resist ghost', () {
    final gen5 = typeRelationsForGeneration(relations, 5);
    final input = BattleEffectivenessInput(
      defenderTypes: const ['steel'],
      relationsByType: gen5,
      generation: 5,
    );
    final multipliers = computeBattleTypeMultipliers(input);
    expect(formatTypeMultiplier(multipliers['ghost'] ?? 1), '1');
  });

  test('huge power doubles physical attack in damage estimate', () {
    final without = estimateDamage(
      level: 50,
      power: 80,
      attack: 100,
      defense: 100,
      defenderHp: 200,
      moveType: 'water',
      attackerTypes: const ['water'],
      defenderTypes: const ['fire'],
      relationsByType: relations,
      category: MoveCategory.physical,
    );
    final withHuge = estimateDamage(
      level: 50,
      power: 80,
      attack: 100,
      defense: 100,
      defenderHp: 200,
      moveType: 'water',
      attackerTypes: const ['water'],
      defenderTypes: const ['fire'],
      relationsByType: relations,
      attackerAbilitySlug: 'huge-power',
      category: MoveCategory.physical,
    );
    expect(withHuge.maxDamage, greaterThan(without.maxDamage));
  });

  test('filter reduces super effective damage modifier', () {
    final estimate = estimateDamage(
      level: 50,
      power: 90,
      attack: 120,
      defense: 80,
      defenderHp: 150,
      moveType: 'grass',
      attackerTypes: const ['grass'],
      defenderTypes: const ['water', 'ground'],
      relationsByType: relations,
      defenderAbilitySlug: 'filter',
    );
    expect(estimate.extraMultiplier, closeTo(0.75, 0.001));
  });
}
