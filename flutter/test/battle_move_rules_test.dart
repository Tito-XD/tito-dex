import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/companion/battle_math.dart';
import 'package:titodex/features/companion/battle_move_rules.dart';
import 'package:titodex/features/companion/battle_party_damage.dart';
import 'package:titodex/features/companion/battle_session.dart';
import 'package:titodex/features/dex/battle_effectiveness.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/features/dex/type_chart.dart';

// Cached catalog values deliberately use modern power. Historical rules own it.
CachedMove move(int id) => CachedMove(
  id: id,
  nameEn: 'Move $id',
  nameZh: '$id',
  type: 'normal',
  category: 'physical',
  power: 90,
  generation: 1,
);

const chart = <String, TypeDamageRelations>{
  'normal': TypeDamageRelations(
    doubleDamageTo: {},
    halfDamageTo: {'rock', 'steel'},
    noDamageTo: {'ghost'},
  ),
  'fighting': TypeDamageRelations(
    doubleDamageTo: {'rock', 'normal'},
    halfDamageTo: {},
    noDamageTo: {'ghost'},
  ),
  'ice': TypeDamageRelations(
    doubleDamageTo: {'ground'},
    halfDamageTo: {'water'},
    noDamageTo: {},
  ),
  'electric': TypeDamageRelations(
    doubleDamageTo: {'water'},
    halfDamageTo: {},
    noDamageTo: {'ground'},
  ),
  'ground': TypeDamageRelations(
    doubleDamageTo: {},
    halfDamageTo: {},
    noDamageTo: {'flying'},
  ),
  'water': TypeDamageRelations(
    doubleDamageTo: {},
    halfDamageTo: {},
    noDamageTo: {},
  ),
  'psychic': TypeDamageRelations(
    doubleDamageTo: {},
    halfDamageTo: {},
    noDamageTo: {'dark'},
  ),
  'fairy': TypeDamageRelations(
    doubleDamageTo: {},
    halfDamageTo: {},
    noDamageTo: {},
  ),
};

void main() {
  late BattleSession session;
  setUp(() {
    session = BattleSession();
    for (final side in [session.attacker, session.defender]) {
      side.types = [];
      for (final stat in BattleStat.values) {
        side.raw[stat]!.text = '100';
      }
    }
  });
  tearDown(() => session.dispose());
  test(
    'displayed stats honor historical paralysis and Guts without double burn',
    () {
      final a = session.attacker;
      a.status = BattleStatusCondition.paralysis;
      expect(a.effectiveStat(BattleStat.speed, generation: 6), 25);
      expect(a.effectiveStat(BattleStat.speed, generation: 7), 50);
      a.status = BattleStatusCondition.burn;
      a.abilitySlug = 'guts';
      expect(a.effectiveStat(BattleStat.attack), 150);
    },
  );
  DamageEstimate? run(
    int id, {
    int gen = 9,
    String? weather,
    String? terrain,
    bool spread = false,
  }) => estimatePartyMove(
    attacker: session.attacker,
    defender: session.defender,
    move: move(id),
    relations: chart,
    generation: gen,
    weatherSlug: weather,
    terrainSlug: terrain,
    spread: spread,
  );

  test('Scrappy removes only Ghost immunity, preserving the other type', () {
    final input = BattleEffectivenessInput(
      defenderTypes: ['ghost', 'rock'],
      relationsByType: chart,
      attackerAbilitySlug: 'scrappy',
    );
    final values = computeBattleTypeMultipliers(input);
    expect(values['normal'], .5);
    expect(values['fighting'], 2);
  });
  test(
    'Mold Breaker bypasses Levitate but cannot suppress Prism Armor or weather abilities',
    () {
      session.attacker.abilitySlug = 'mold-breaker';
      session.defender.abilitySlug = 'levitate';
      expect(run(89)!.typeMultiplier, 1);
      expect(
        effectiveDefenderAbility('mold-breaker', 'prism-armor'),
        'prism-armor',
      );
      expect(
        effectiveDefenderAbility('mold-breaker', 'cloud-nine'),
        'cloud-nine',
      );
    },
  );
  test('historical power and category come from generation records', () {
    expect(battleMoveProfile(move(85), 4)!.power, 95);
    expect(battleMoveProfile(move(85), 6)!.power, 90);
    expect(battleMoveProfile(move(85), 9)!.physical, isFalse);
    expect(battleMoveProfile(move(1), 4)!.power, 40);
  });
  test('Psyshock uses special attack against physical defense', () {
    session.attacker.raw[BattleStat.specialAttack]!.text = '200';
    session.defender.raw[BattleStat.specialDefense]!.text = '500';
    expect(run(473)!.maxDamage, 72);
    session.defender.raw[BattleStat.defense]!.text = '200';
    expect(run(473)!.maxDamage, 37);
  });
  test('Body Press and Foul Play use the correct source stat', () {
    session.attacker.raw[BattleStat.defense]!.text = '200';
    expect(run(776)!.maxDamage, 72);
    session.defender.raw[BattleStat.attack]!.text = '200';
    expect(run(492)!.maxDamage, 85);
  });
  test('Freeze Dry overrides only the Water type component', () {
    session.defender.types = ['water', 'ground'];
    expect(run(573)!.typeMultiplier, 4);
    session.defender.terastallized = true;
    session.defender.teraType = 'water';
    expect(run(573)!.typeMultiplier, 2);
  });
  test('Weather Ball uses weather-dependent type and power', () {
    final profile = battleMoveProfile(move(311), 9, weather: 'rain')!;
    expect(profile.type, 'water');
    expect(profile.power, 100);
    expect(battleMoveProfile(move(311), 9, weather: '')!.power, 50);
  });
  test(
    'fixed damage ignores offense boosts, resistance and burn, but respects immunity',
    () {
      session.attacker.heldItem = BattleHeldItem.lifeOrb;
      session.attacker.status = BattleStatusCondition.burn;
      session.attacker.types = ['fighting'];
      expect(run(69)!.minDamage, 50);
      expect(run(69)!.maxDamage, 50);
      session.defender.types = ['ghost'];
      expect(run(69)!.maxDamage, 0);
      expect(run(82)!.maxDamage, 40);
    },
  );
  test(
    'new/original Tera and Adaptability stack correctly in shared estimator',
    () {
      final a = session.attacker;
      a.types = ['water'];
      a.terastallized = true;
      a.teraType = 'normal';
      expect(run(70)!.stabMultiplier, 1.5);
      a.types = ['normal'];
      expect(run(70)!.stabMultiplier, 2);
      a.abilitySlug = 'adaptability';
      expect(run(70)!.stabMultiplier, 2.25);
      a.types = ['water'];
      expect(run(70)!.stabMultiplier, 2);
    },
  );
  test('conversion does not grant STAB without matching attacker type', () {
    session.attacker.abilitySlug = 'pixilate';
    expect(run(70)!.stabMultiplier, 1);
    expect(run(70)!.maxDamage, 44); // 80 * 1.2 power.
    session.attacker.types = ['fairy'];
    expect(run(70)!.stabMultiplier, 1.5);
  });
  test('Facade burn exception starts in generation six', () {
    session.attacker.status = BattleStatusCondition.burn;
    expect(run(263, gen: 5)!.maxDamage, 31);
    expect(run(263, gen: 6)!.maxDamage, 63);
    session.attacker.abilitySlug = 'guts';
    expect(run(263)!.maxDamage, 94);
  });
  test(
    'unsupported moves, HP-dependent abilities and unknown items do not invent damage',
    () {
      for (final id in [68, 3, 90, 284, 153]) {
        expect(run(id), isNull, reason: 'move $id');
      }
      session.attacker.abilitySlug = 'blaze';
      expect(run(70), isNull);
      session.attacker.abilitySlug = null;
      session.defender.unsupportedItem = true;
      expect(run(70), isNull);
    },
  );
  test(
    'Psychic Terrain blocks grounded priority and spread only applies to spread moves',
    () {
      expect(run(98, terrain: 'psychic')!.maxDamage, 0);
      session.defender.types = ['flying'];
      expect(run(98, terrain: 'psychic')!.maxDamage, greaterThan(0));
      expect(run(70, spread: true)!.maxDamage, run(70)!.maxDamage);
      session.defender.types = [];
      expect(run(89, spread: true)!.maxDamage, lessThan(run(89)!.maxDamage));
    },
  );
  test('terrain depends on generation and grounding', () {
    BattleEffectivenessInput input(int gen, List<String> types) =>
        BattleEffectivenessInput(
          defenderTypes: [],
          relationsByType: chart,
          generation: gen,
          attackerTypes: types,
          terrainSlug: 'electric',
        );
    expect(fieldMoveTypeModifier('electric', input(7, ['electric'])), 1.5);
    expect(fieldMoveTypeModifier('electric', input(8, ['electric'])), 1.3);
    expect(fieldMoveTypeModifier('electric', input(9, ['flying'])), 1);
  });
  test('Fluffy uses contact flag even for special attacks', () {
    expect(
      defenderAbilityDamageMultiplier(
        isPhysical: false,
        defenderAbilitySlug: 'fluffy',
        isContactMove: true,
      ),
      .5,
    );
    expect(battleMoveProfile(move(80), 9)!.contact, isTrue); // Petal Dance.
  });
  test(
    'Tera power floor excludes priority and does not multiply Technician twice',
    () {
      session.attacker.terastallized = true;
      session.attacker.teraType = 'normal';
      expect(run(1)!.maxDamage, 42); // floor(28 * 1.5), power raised to 60.
      expect(run(98)!.maxDamage, 28); // Quick Attack keeps power 40.
      session.attacker.abilitySlug = 'technician';
      expect(run(1)!.maxDamage, 42);
    },
  );
}
