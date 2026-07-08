import 'package:flutter_test/flutter_test.dart';

import 'package:titodex/features/parser/hgss_map_lookup.dart';
import 'package:titodex/features/parser/hgss_parser.dart';
import 'package:titodex/models/journey.dart';
import 'package:titodex/models/parsed_save.dart';

void main() {
  test('map id 76 resolves to Goldenrod City', () {
    expect(locationLabelForMapId(76), 'Goldenrod City');
  });

  test('toJourney preserves customized trainer name on re-import', () {
    const parser = HgssParser();
    final summary = ParsedSaveSummary(
      game: 'SoulSilver',
      trainerName: 'ETeZ',
      playTime: '7:03:41',
      badges: 3,
      maxBadges: 8,
      locationLabel: 'Goldenrod City',
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
    expect(journey.location, 'Goldenrod City');
  });
}
