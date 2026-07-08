import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/type_chart.dart';

void main() {
  final relations = <String, TypeDamageRelations>{
    'fire': const TypeDamageRelations(
      doubleDamageTo: {'grass', 'ice', 'bug', 'steel'},
      halfDamageTo: {'fire', 'water', 'rock', 'dragon'},
      noDamageTo: {},
    ),
    'water': const TypeDamageRelations(
      doubleDamageTo: {'fire', 'ground', 'rock'},
      halfDamageTo: {'water', 'grass', 'dragon'},
      noDamageTo: {},
    ),
    'grass': const TypeDamageRelations(
      doubleDamageTo: {'water', 'ground', 'rock'},
      halfDamageTo: {'fire', 'grass', 'poison', 'flying', 'bug', 'dragon', 'steel'},
      noDamageTo: {},
    ),
    'electric': const TypeDamageRelations(
      doubleDamageTo: {'water', 'flying'},
      halfDamageTo: {'electric', 'grass', 'dragon'},
      noDamageTo: {'ground'},
    ),
    'ground': const TypeDamageRelations(
      doubleDamageTo: {'fire', 'electric', 'poison', 'rock', 'steel'},
      halfDamageTo: {'grass', 'bug'},
      noDamageTo: {'flying'},
    ),
    'flying': const TypeDamageRelations(
      doubleDamageTo: {'grass', 'fighting', 'bug'},
      halfDamageTo: {'electric', 'rock', 'steel'},
      noDamageTo: {},
    ),
    'normal': const TypeDamageRelations(
      doubleDamageTo: {},
      halfDamageTo: {'rock', 'steel'},
      noDamageTo: {'ghost'},
    ),
    'ghost': const TypeDamageRelations(
      doubleDamageTo: {'psychic', 'ghost'},
      halfDamageTo: {'dark'},
      noDamageTo: {'normal'},
    ),
    'psychic': const TypeDamageRelations(
      doubleDamageTo: {'fighting', 'poison'},
      halfDamageTo: {'psychic', 'steel'},
      noDamageTo: {},
    ),
    'poison': const TypeDamageRelations(
      doubleDamageTo: {'grass', 'fairy'},
      halfDamageTo: {'poison', 'ground', 'rock', 'ghost'},
      noDamageTo: {},
    ),
    'fighting': const TypeDamageRelations(
      doubleDamageTo: {'normal', 'rock', 'steel', 'ice', 'dark'},
      halfDamageTo: {'poison', 'flying', 'psychic', 'bug', 'fairy'},
      noDamageTo: {'ghost'},
    ),
  };

  test('single-type weaknesses and resistances', () {
    final profile = computeDefensiveProfile(['fire'], relations);
    expect(profile.weaknesses, contains('水'));
    expect(profile.resistances, contains('火'));
    expect(profile.resistances, contains('草'));
    expect(profile.immunities, isEmpty);
  });

  test('dual-type combines multipliers', () {
    final profile = computeDefensiveProfile(['grass', 'poison'], relations);
    expect(profile.weaknesses, contains('火'));
    expect(profile.weaknesses, contains('飞行'));
    expect(profile.weaknesses, contains('超能力'));
  });

  test('ground immunity to electric', () {
    final profile = computeDefensiveProfile(['ground'], relations);
    expect(profile.immunities, contains('电'));
  });

  test('stab super effective lists offensive strengths', () {
    final stab = computeStabSuperEffective(['water', 'flying'], relations);
    expect(stab, contains('草'));
    expect(stab, contains('格斗'));
    expect(stab, contains('地面'));
  });
}
