import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titodex/features/parser/hgss_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses bundled PKMSS.sav fixture', () async {
    final bytes = await rootBundle.load('assets/fixtures/PKMSS.sav');
    final parser = const HgssParser();
    final data = bytes.buffer.asUint8List();

    expect(parser.canParse(data), isTrue);

    final summary = parser.parseSummary(data);
    expect(summary.game, 'SoulSilver');
    expect(summary.trainerName, 'ETeZ');
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
}
