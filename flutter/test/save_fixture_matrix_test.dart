import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/parser/pokemon_save_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every reviewed save fixture matches its declared metadata', () async {
    final source = await rootBundle.loadString(
      'assets/fixtures/save_fixture_manifest.json',
    );
    final manifest = jsonDecode(source) as Map<String, dynamic>;
    expect(manifest['schemaVersion'], 1);
    final fixtures = (manifest['fixtures'] as List<dynamic>).cast<Map>();
    expect(fixtures, isNotEmpty);

    for (final raw in fixtures) {
      final fixture = Map<String, dynamic>.from(raw);
      final data = await rootBundle.load(fixture['asset'] as String);
      final summary = const PokemonSaveParser().parseSummary(
        data.buffer.asUint8List(),
      );
      expect(summary.game, fixture['game'], reason: fixture['asset'] as String);
      expect(
        summary.trainerName,
        fixture['trainerName'],
        reason: fixture['asset'] as String,
      );
      expect(summary.badges, fixture['badges']);
      expect(summary.locationLabel, fixture['locationLabel']);
      expect(
        summary.party.map((member) => member.speciesId),
        containsAll((fixture['partySpeciesIds'] as List<dynamic>).cast<int>()),
      );
    }
  });
}
