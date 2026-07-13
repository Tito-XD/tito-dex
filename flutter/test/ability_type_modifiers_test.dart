import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/companion/battle_math.dart';
import 'package:titodex/features/dex/ability_type_modifiers.dart';
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
    'ice': const TypeDamageRelations(
      doubleDamageTo: {'grass', 'ground', 'flying', 'dragon'},
      halfDamageTo: {'fire', 'water', 'ice', 'steel'},
      noDamageTo: {},
    ),
  };

  test('sap sipper makes grass immune on water/fairy Azumarill', () {
    final withoutAbility = computeDefensiveMultipliersWithAbility(
      defenderTypes: const ['water', 'fairy'],
      relationsByType: relations,
    );
    expect(formatTypeMultiplier(withoutAbility['grass'] ?? 1), '2');

    final withSapSipper = computeDefensiveMultipliersWithAbility(
      defenderTypes: const ['water', 'fairy'],
      relationsByType: relations,
      defenderAbilitySlug: 'sap-sipper',
    );
    expect(formatTypeMultiplier(withSapSipper['grass'] ?? 1), '0');

    final profile = computeDefensiveProfile(
      const ['water', 'fairy'],
      relations,
      defenderAbilitySlug: 'sap-sipper',
    );
    expect(profile.immunities, contains('草'));
    expect(profile.weaknesses, isNot(contains('草')));
  });

  test('thick fat halves fire and ice on top of type chart', () {
    final withoutAbility = computeDefensiveMultipliersWithAbility(
      defenderTypes: const ['normal'],
      relationsByType: relations,
    );
    expect(formatTypeMultiplier(withoutAbility['fire'] ?? 1), '1');
    expect(formatTypeMultiplier(withoutAbility['ice'] ?? 1), '1');

    final withThickFat = computeDefensiveMultipliersWithAbility(
      defenderTypes: const ['normal'],
      relationsByType: relations,
      defenderAbilitySlug: 'thick-fat',
    );
    expect(formatTypeMultiplier(withThickFat['fire'] ?? 1), '1/2');
    expect(formatTypeMultiplier(withThickFat['ice'] ?? 1), '1/2');
  });

  test('estimateDamage uses defender ability modifier', () {
    final estimate = estimateDamage(
      level: 50,
      power: 80,
      attack: 100,
      defense: 100,
      defenderHp: 150,
      moveType: 'grass',
      attackerTypes: const ['grass'],
      defenderTypes: const ['water', 'fairy'],
      relationsByType: relations,
      defenderAbilitySlug: 'sap-sipper',
    );

    expect(estimate.typeMultiplier, 0);
    expect(estimate.maxDamage, 0);
    expect(estimate.tankVerdictZh, '完全免疫或无伤');
  });

  test('abilitySlugFromNameEn normalizes PokeAPI slugs', () {
    expect(abilitySlugFromNameEn('Sap Sipper'), 'sap-sipper');
    expect(abilitySlugFromNameEn('Thick Fat'), 'thick-fat');
    expect(abilitySlugFromNameEn('Huge Power'), 'huge-power');
  });
}
