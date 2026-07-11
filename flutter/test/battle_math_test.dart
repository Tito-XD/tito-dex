import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/companion/battle_math.dart';
import 'package:titodex/features/dex/type_chart.dart';

void main() {
  final relations = <String, TypeDamageRelations>{
    'ice': const TypeDamageRelations(
      doubleDamageTo: {'ground', 'flying', 'grass', 'dragon'},
      halfDamageTo: {'fire', 'water', 'ice', 'steel'},
      noDamageTo: {},
    ),
    'ground': const TypeDamageRelations(
      doubleDamageTo: {'fire', 'electric', 'poison', 'rock', 'steel'},
      halfDamageTo: {'grass', 'bug'},
      noDamageTo: {'flying'},
    ),
  };

  test('computeBattleStat applies nature boost and drop', () {
    const lonely = NatureModifier(
      key: 'lonely',
      labelZh: '怕寂寞',
      boost: BattleStat.attack,
      drop: BattleStat.defense,
    );
    final attack = computeBattleStat(
      stat: BattleStat.attack,
      base: 165,
      level: 50,
      iv: 31,
      ev: 252,
      nature: lonely,
    );
    expect(attack, greaterThan(200));
  });

  test('estimateDamage reports guaranteed ohko on super effective ice vs ground', () {
    final estimate = estimateDamage(
      level: 50,
      power: 120,
      attack: 238,
      defense: 150,
      defenderHp: 207,
      moveType: 'ice',
      attackerTypes: const ['psychic', 'ice'],
      defenderTypes: const ['ground'],
      relationsByType: relations,
    );

    expect(estimate.stabMultiplier, 1.5);
    expect(estimate.typeMultiplier, 2);
    expect(estimate.minDamage, greaterThan(207));
    expect(estimate.verdictZh, '稳秒杀');
  });

  test('estimateDamage reports tank risk when max exceeds hp', () {
    final estimate = estimateDamage(
      level: 50,
      power: 90,
      attack: 120,
      defense: 80,
      defenderHp: 150,
      moveType: 'fighting',
      attackerTypes: const ['fighting'],
      defenderTypes: const ['normal'],
      relationsByType: relations,
    );

    expect(estimate.tankVerdictZh, isNot('完全免疫或无伤'));
  });
}
