import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/companion/battle_math.dart';
import 'package:titodex/features/companion/battle_session.dart';
import 'package:titodex/features/companion/battle_team_analysis.dart';
import 'package:titodex/features/dex/battle_effectiveness.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/features/dex/type_chart.dart';
import 'package:titodex/models/journey.dart';

const summary = PokemonSummary(
  id: 25,
  nameEn: 'Pikachu',
  nameZh: '皮卡丘',
  types: ['electric'],
);
const ability = PokemonAbility(
  nameEn: 'Static',
  nameZh: '静电',
  descriptionZh: '',
);
const detail = PokemonDetail(
  summary: summary,
  genusZh: '',
  heightDm: 4,
  weightHg: 60,
  weaknesses: [],
  resistances: [],
  immunities: [],
  stabSuperEffective: [],
  evolutionChain: null,
  baseStats: PokemonBaseStats(
    hp: 35,
    attack: 55,
    defense: 40,
    specialAttack: 50,
    specialDefense: 50,
    speed: 90,
  ),
  abilities: [ability],
);

void main() {
  test(
    'six independent stats and roles recalculate from shared training inputs',
    () {
      final session = BattleSession();
      addTearDown(session.dispose);
      final attacker = session.attacker;
      attacker.base[BattleStat.attack]!.text = '55';
      attacker.ev[BattleStat.attack]!.text = '252';
      attacker.nature = battleNatures.firstWhere((n) => n.key == 'adamant');
      session.changed();
      expect(attacker.raw[BattleStat.attack]!.text, '117');
      expect(attacker.raw[BattleStat.specialAttack]!.text, '108');
      expect(session.defender.raw[BattleStat.attack]!.text, '120');
      attacker.level.text = '75';
      expect(attacker.raw[BattleStat.attack]!.text, '173');
      expect(session.defender.level.text, '50');
    },
  );

  test(
    'manual raw stats survive tab notifications until their inputs change',
    () {
      final session = BattleSession();
      addTearDown(session.dispose);
      session.attacker.raw[BattleStat.attack]!.selection =
          const TextSelection.collapsed(offset: 1);
      expect(session.attacker.overrides, isEmpty);
      session.attacker.raw[BattleStat.attack]!.text = '222';
      session.changed();
      expect(session.attacker.raw[BattleStat.attack]!.text, '222');
      session.attacker.ev[BattleStat.speed]!.text = '252';
      expect(session.attacker.raw[BattleStat.attack]!.text, '222');
      session.attacker.iv[BattleStat.attack]!.text = '0';
      expect(session.attacker.raw[BattleStat.attack]!.text, '105');
      expect(session.attacker.overrides, isEmpty);
    },
  );

  test('damage receives raw stat and applies ability, item and burn once', () {
    final session = BattleSession();
    addTearDown(session.dispose);
    final attacker = session.attacker;
    attacker.abilitySlug = 'huge-power';
    attacker.heldItem = BattleHeldItem.choiceBand;
    attacker.status = BattleStatusCondition.burn;
    session.changed();
    expect(attacker.raw[BattleStat.attack]!.text, '120');
    expect(attacker.effectiveStat(BattleStat.attack), 180);
    final boosted = estimateDamage(
      level: 50,
      power: 80,
      attack: 120,
      defense: 100,
      defenderHp: 150,
      moveType: 'normal',
      attackerTypes: [],
      defenderTypes: [],
      relationsByType: {},
      category: MoveCategory.physical,
      attackerAbilitySlug: attacker.abilitySlug,
      attackerHeldItem: attacker.heldItem,
      attackerStatus: attacker.status,
    );
    final plain = estimateDamage(
      level: 50,
      power: 80,
      attack: 180,
      defense: 100,
      defenderHp: 150,
      moveType: 'normal',
      attackerTypes: [],
      defenderTypes: [],
      relationsByType: {},
      category: MoveCategory.physical,
    );
    // Burn halves damage after the base +2, not the attack input itself.
    expect(boosted.maxDamage, 64);
    expect(boosted.minDamage, 54);
    expect(plain.maxDamage, 65);
  });

  test(
    'party import maps save IV/EV order, nature, level, and ability',
    () async {
      final draft = BattleCombatant(level: 50);
      addTearDown(draft.dispose);
      const member = PartyMember(
        species: '皮卡丘',
        speciesId: 25,
        level: 70,
        nature: '内敛',
        abilitySlug: 'static',
        status: '麻痹',
        ivs: [1, 2, 3, 4, 5, 6],
        evs: [4, 8, 12, 16, 20, 24],
      );
      await draft.selectPokemon(
        summary,
        member: member,
        loadDetail: (_) async => detail,
        loadAbilities: (_) async => [ability],
      );
      expect(draft.level.text, '70');
      expect(draft.iv[BattleStat.speed]!.text, '4');
      expect(draft.iv[BattleStat.specialAttack]!.text, '5');
      expect(draft.ev[BattleStat.specialDefense]!.text, '24');
      expect(draft.nature.key, 'modest');
      expect(draft.abilitySlug, 'static');
      expect(draft.status, BattleStatusCondition.paralysis);
      expect(draft.partyDefaults, isFalse);
      expect(draft.raw[BattleStat.specialAttack]!.text, '90');
      // Input party objects stay untouched.
      expect(member.ivs, [1, 2, 3, 4, 5, 6]);
      await draft.selectPokemon(
        summary,
        member: const PartyMember(species: '皮卡丘'),
        loadDetail: (_) async => detail,
        loadAbilities: (_) async => [ability],
      );
      expect(draft.level.text, '50');
      expect(draft.iv[BattleStat.specialAttack]!.text, '31');
      expect(draft.ev[BattleStat.specialAttack]!.text, '0');
      expect(draft.nature.key, 'serious');
      expect(draft.partyDefaults, isTrue);
    },
  );

  test(
    'late same-species response cannot replace newer party choice',
    () async {
      final draft = BattleCombatant(level: 50);
      addTearDown(draft.dispose);
      final slow = Completer<PokemonDetail>();
      final first = draft.selectPokemon(
        summary,
        member: const PartyMember(species: '皮卡丘', level: 5),
        loadDetail: (_) => slow.future,
        loadAbilities: (_) async => [ability],
      );
      await draft.selectPokemon(
        summary,
        member: const PartyMember(species: '皮卡丘', level: 80),
        loadDetail: (_) async => detail,
        loadAbilities: (_) async => [ability],
      );
      slow.complete(detail);
      await first;
      expect(draft.level.text, '80');
      await draft.selectPokemon(
        summary,
        loadDetail: (_) async => throw StateError('offline'),
      );
      expect(draft.selectionFailed, isTrue);
      expect(draft.level.text, '80');
      expect(draft.loading, isFalse);
    },
  );

  test(
    'pending selection is harmless after draft disposal or manual identity edit',
    () async {
      final draft = BattleCombatant(level: 50);
      final slow = Completer<PokemonDetail>();
      final pending = draft.selectPokemon(
        summary,
        loadDetail: (_) => slow.future,
        loadAbilities: (_) async => [ability],
      );
      draft.dispose();
      slow.complete(detail);
      await pending;
      final other = BattleCombatant(level: 50);
      addTearDown(other.dispose);
      final pendingOther = other.selectPokemon(
        summary,
        loadDetail: (_) async => detail,
        loadAbilities: (_) async => [ability],
      );
      other.clearIdentity();
      await pendingOther;
      expect(other.pokemonId, isNull);
    },
  );

  test(
    'team counts members, separates resistance and immunity, honors abilities',
    () {
      const relations = {
        'water': TypeDamageRelations(
          doubleDamageTo: {'fire'},
          halfDamageTo: {'water'},
          noDamageTo: {},
        ),
        'ground': TypeDamageRelations(
          doubleDamageTo: {'fire', 'electric'},
          halfDamageTo: {},
          noDamageTo: {'flying'},
        ),
        'fire': TypeDamageRelations(
          doubleDamageTo: {'grass'},
          halfDamageTo: {'water'},
          noDamageTo: {},
        ),
        'electric': TypeDamageRelations(
          doubleDamageTo: {'water'},
          halfDamageTo: {},
          noDamageTo: {'ground'},
        ),
      };
      final analysis = BattleTeamAnalysis(
        [
          const BattleTeamMember(name: 'A', types: ['fire']),
          const BattleTeamMember(
            name: 'B',
            types: ['fire'],
            abilitySlug: 'levitate',
          ),
          const BattleTeamMember(
            name: 'C',
            types: ['water'],
            abilitySlug: 'water-absorb',
          ),
        ],
        relations,
        generation: 9,
      );
      expect(analysis.sharedWeaknesses['water'], 2);
      expect(analysis.sharedWeaknesses.containsKey('ground'), isFalse);
      expect(analysis.immunities['ground'], 1);
      expect(analysis.immunities['water'], 1);
      expect(analysis.resistances.containsKey('water'), isFalse);
      expect(analysis.offensiveBlindSpots, contains('water'));
      expect(analysis.offensiveBlindSpots, isNot(contains('grass')));
      final old = BattleTeamAnalysis(
        [
          const BattleTeamMember(name: 'A', types: ['fairy']),
        ],
        relations,
        generation: 4,
      );
      expect(old.offensiveBlindSpots, isNot(contains('fairy')));
      final empty = BattleTeamAnalysis([], relations, generation: 9);
      expect(empty.offensiveBlindSpots, isEmpty);
    },
  );
}
