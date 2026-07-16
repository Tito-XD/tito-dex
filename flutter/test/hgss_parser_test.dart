import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titodex/features/parser/hgss_parser.dart';
import 'package:titodex/features/parser/hgss_format.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses bundled PKMSS.sav fixture', () async {
    final bytes = await rootBundle.load('assets/fixtures/PKMSS.sav');
    final parser = const HgssParser();
    final data = bytes.buffer.asUint8List();

    expect(parser.canParse(data), isTrue);

    final summary = parser.parseSummary(data);
    expect(summary.game, 'SoulSilver');
    expect(summary.trainerName, 'Tito');
    expect(summary.tid, 22813);
    expect(summary.badges, 3);
    expect(summary.playTime, '7:03:41');
    expect(summary.party, isNotEmpty);
    expect(summary.party.first.speciesName, 'Quilava');
    expect(summary.party.first.level, 27);
    expect(summary.party.first.currentHp, isNotNull);
    expect(summary.party.first.maxHp, isNotNull);
    expect(summary.party.first.maxHp!, greaterThan(0));
    expect(summary.party[1].speciesName, 'Togepi');
    expect(summary.party[1].level, 6);
    expect(summary.locationLabel, '满金市');
    expect(summary.mapHeaderId, 76);
    expect(summary.saveHash, isNotEmpty);
    expect(summary.dexCaughtIds, containsAll([156, 175]));
    expect(summary.dexSeenIds.length, 46);
    expect(summary.dexSeenIds, containsAll(summary.dexCaughtIds));
  });

  test('decodes Gen IV full-width and half-width trainer characters', () {
    expect(
      decodeGen4Text(const [0xBF, 0, 0xCE, 0, 0xD9, 0, 0xD4, 0, 0xFF, 0xFF]),
      'Tito',
    );
    expect(
      decodeGen4Text(const [0x3E, 1, 0x4D, 1, 0x58, 1, 0x53, 1, 0xFF, 0xFF]),
      'Tito',
    );
  });

  test('uses source save time for the journey timeline', () async {
    final bytes = await rootBundle.load('assets/fixtures/PKMSS.sav');
    const parser = HgssParser();
    final savedAt = DateTime.utc(2026, 7, 15, 9, 30);
    final summary = parser.parseSummary(
      bytes.buffer.asUint8List(),
      sourceModifiedAt: savedAt,
    );

    expect(summary.savedAt, savedAt);
    final timelineEntry = parser.toJourney(summary).timeline.first;
    expect(timelineEntry.at, contains('2026/7/15'));
    expect(timelineEntry.text, contains('心金/魂银'));
  });
}
