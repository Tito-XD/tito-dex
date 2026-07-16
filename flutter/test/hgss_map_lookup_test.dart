import 'package:flutter_test/flutter_test.dart';

import 'package:titodex/features/parser/hgss_map_lookup.dart';
import 'package:titodex/features/parser/hgss_parser.dart';
import 'package:titodex/l10n/game_zh.dart';
import 'package:titodex/models/journey.dart';
import 'package:titodex/models/parsed_save.dart';

void main() {
  test('map id 76 resolves to 满金市', () {
    expect(locationLabelForMapId(76), '满金市');
  });

  test('localizes species and interior hints', () {
    expect(localizeSpecies('Quilava'), '火岩鼠');
    expect(
      localizeLocation('Goldenrod City · Pokémon Center'),
      '满金市 · 宝可梦中心',
    );
    expect(localizeGame('SoulSilver'), '宝可梦 魂银');
  });

  test('toJourney preserves customized trainer name on re-import', () {
    const parser = HgssParser();
    final summary = ParsedSaveSummary(
      game: 'SoulSilver',
      trainerName: 'ETeZ',
      playTime: '7:03:41',
      badges: 3,
      maxBadges: 8,
      locationLabel: '满金市',
      party: [],
      saveHash: 'abc',
      parsedAt: DateTime.utc(2026, 1, 1),
    );

    final existing = CurrentJourney.mock().copyWith(
      trainerName: 'Tito',
      trainerNameCustomized: true,
      saveTrainerName: 'ETeZ',
    );

    final journey = parser.toJourney(summary, existing: existing);
    expect(journey.trainerName, 'Tito');
    expect(journey.saveTrainerName, 'ETeZ');
    expect(journey.location, '满金市');
  });

  test('toJourney merges timeline instead of wiping manual entries', () {
    const parser = HgssParser();
    final summary = ParsedSaveSummary(
      game: 'SoulSilver',
      trainerName: 'ETeZ',
      playTime: '7:03:41',
      badges: 3,
      maxBadges: 8,
      locationLabel: '满金市',
      party: [],
      saveHash: 'deadbeef',
      parsedAt: DateTime.utc(2026, 1, 1),
    );

    final existing = CurrentJourney.mock();
    final journey = parser.toJourney(summary, existing: existing);

    expect(journey.timeline.first.text, contains('心金/魂银'));
    expect(
      journey.timeline.any((entry) => entry.text == '抵达满金市'),
      isTrue,
    );
    expect(journey.nextReminder, existing.nextReminder);
  });

  test('toJourney preserves user-edited party when partyUserOverride is set', () {
    const parser = HgssParser();
    final summary = ParsedSaveSummary(
      game: 'SoulSilver',
      trainerName: 'ETeZ',
      playTime: '7:03:41',
      badges: 3,
      maxBadges: 8,
      locationLabel: '桔梗市',
      party: const [
        ParsedPartyMember(
          speciesId: 25,
          speciesName: 'Pikachu',
          level: 30,
        ),
      ],
      saveHash: 'abc123',
      parsedAt: DateTime.utc(2026, 1, 1),
    );

    final existing = CurrentJourney.mock().copyWith(
      partyUserOverride: true,
      party: const [
        PartyMember(
          species: '火岩鼠',
          speciesId: 156,
          level: 99,
          userEdited: true,
        ),
      ],
      saveSyncedParty: const [
        PartyMember(species: '皮卡丘', speciesId: 25, level: 10),
      ],
    );

    final journey = parser.toJourney(summary, existing: existing);

    expect(journey.party.first.speciesId, 156);
    expect(journey.party.first.level, 99);
    expect(journey.saveSyncedParty.first.speciesId, 25);
    expect(journey.partyUserOverride, isTrue);
    expect(journey.location, '桔梗市');
  });

  test('toJourney replaces party when partyUserOverride is false', () {
    const parser = HgssParser();
    final summary = ParsedSaveSummary(
      game: 'SoulSilver',
      trainerName: 'ETeZ',
      playTime: '7:03:41',
      badges: 3,
      maxBadges: 8,
      locationLabel: '满金市',
      party: const [
        ParsedPartyMember(
          speciesId: 25,
          speciesName: 'Pikachu',
          level: 30,
        ),
      ],
      saveHash: 'abc123',
      parsedAt: DateTime.utc(2026, 1, 1),
    );

    final existing = CurrentJourney.mock().copyWith(
      partyUserOverride: false,
      party: const [
        PartyMember(species: '火岩鼠', speciesId: 156, level: 99),
      ],
    );

    final journey = parser.toJourney(summary, existing: existing);

    expect(journey.party.first.speciesId, 25);
    expect(journey.saveSyncedParty.first.speciesId, 25);
    expect(journey.partyUserOverride, isFalse);
  });
}
