import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/companion/battle_learnset.dart';
import 'package:titodex/features/companion/battle_session.dart';
import 'package:titodex/features/companion/battle_math.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/models/journey.dart';

const move = CachedMove(
  id: 85,
  nameEn: 'Thunderbolt',
  nameZh: '十万伏特',
  type: 'electric',
  category: 'special',
  power: 90,
);
const detail = PokemonDetail(
  summary: PokemonSummary(
    id: 25,
    nameEn: 'Pikachu',
    nameZh: '皮卡丘',
    types: ['electric'],
  ),
  genusZh: '',
  heightDm: 4,
  weightHg: 60,
  weaknesses: [],
  resistances: [],
  immunities: [],
  stabSuperEffective: [],
  evolutionChain: null,
  moveSets: {
    'scarlet-violet': PokemonMoveSet(
      machine: [PokemonMove(move: move, method: 'machine')],
      tutor: [PokemonMove(move: move, method: 'tutor')],
    ),
  },
);

void main() {
  test('learnset deduplicates methods and never silently borrows a game', () {
    expect(battleLearnset(detail, 'scarlet-violet').map((m) => m.id), [85]);
    expect(battleLearnset(detail, 'heartgold-soulsilver'), isEmpty);
    expect(battleLearnset(null, 'scarlet-violet'), isEmpty);
  });

  test(
    'temporary roster edits are shared, removable, and leave saved party untouched',
    () async {
      final session = BattleSession();
      addTearDown(session.dispose);
      const source = <PartyMember>[];
      final draft = BattleCombatant(level: 50)..pokemonId = 25;
      final entry = BattlePartyEntry(const PartyMember(species: '皮卡丘'), draft, {
        85: move,
      });
      await session.addTeamMember(source, entry);
      var notifications = 0;
      session.addListener(() => notifications++);
      draft.iv[BattleStat.speed]!.text = '12';
      expect(notifications, greaterThan(0));
      expect(
        (await session.partyEntries(
          source,
        )).single.combatant.iv[BattleStat.speed]!.text,
        '12',
      );
      expect(source, isEmpty);
      expect(session.teamCount(source), 1);
      await session.removeTeamMember(source, entry);
      expect(await session.partyEntries(source), isEmpty);
      expect(session.teamCount(source), 0);
    },
  );
}
