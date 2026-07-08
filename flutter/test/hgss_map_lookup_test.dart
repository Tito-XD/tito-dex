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
}
