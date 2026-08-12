import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titodex/features/parser/hgss_parser.dart';
import 'package:titodex/features/parser/hgss_format.dart';
import 'package:titodex/models/journey.dart';

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
    expect(summary.maxBadges, 16);
    expect(summary.playTime, '7:03:41');
    expect(summary.party, isNotEmpty);
    expect(summary.party.first.speciesName, 'Quilava');
    expect(summary.party.first.level, 27);
    expect(summary.party.first.currentHp, isNotNull);
    expect(summary.party.first.maxHp, isNotNull);
    expect(summary.party.first.maxHp!, greaterThan(0));
    expect(
      summary.party.first.currentHp!,
      lessThanOrEqualTo(summary.party.first.maxHp!),
    );
    expect(summary.party[1].speciesName, 'Togepi');
    expect(summary.party[1].level, 6);
    expect(summary.party.first.abilityId, 66);
    expect(summary.party.first.moveIds, [172, 15, 108, 52]);
    expect(summary.party.first.experience, 16005);
    expect(summary.party.first.friendship, inInclusiveRange(0, 255));
    expect(summary.party.first.nature, isNotEmpty);
    expect(summary.party.first.ivs, hasLength(6));
    expect(summary.party.first.ivs, everyElement(inInclusiveRange(0, 31)));
    expect(summary.party.first.evs, hasLength(6));
    expect(summary.party.first.movePp, hasLength(4));
    expect(summary.party.first.movePpUps, hasLength(4));
    expect(summary.party.first.battleStats.keys.toSet(), {
      '攻击',
      '防御',
      '速度',
      '特攻',
      '特防',
    });
    expect(summary.secretId, isNotNull);
    expect(summary.money, inInclusiveRange(0, 999999));
    expect(summary.motherMoney, inInclusiveRange(0, 999999));
    expect(summary.trainerGender, anyOf('男', '女'));
    expect(summary.language, isNotEmpty);
    expect(summary.starterSpeciesId, 155);
    expect(summary.mapCoordinates, hasLength(3));
    expect(summary.badgeProgress, {'城都': 3, '关都': 0});
    expect(summary.verifiedBadgeIds, [
      'zephyr_badge',
      'hive_badge',
      'plain_badge',
    ]);
    expect(summary.locationLabel, '满金市');
    expect(summary.mapHeaderId, 76);
    expect(summary.saveHash, isNotEmpty);
    expect(summary.dexCaughtIds, containsAll([156, 175]));
    expect(summary.dexSeenIds.length, 46);
    expect(summary.dexSeenIds, containsAll(summary.dexCaughtIds));

    final journey = parser.toJourney(summary);
    final restored = CurrentJourney.fromJson(journey.toJson());
    expect(restored.saveTrainerSecretId, summary.secretId);
    expect(restored.saveMoney, summary.money);
    expect(restored.saveStarterSpeciesId, 155);
    expect(restored.party.first.ivs, summary.party.first.ivs);
    expect(restored.party.first.battleStats, summary.party.first.battleStats);
    expect(restored.verifiedBadgeIds, summary.verifiedBadgeIds);
  });

  test('counts Johto and Kanto badge banks', () async {
    final fixture = await rootBundle.load('assets/fixtures/PKMSS.sav');
    final bytes = Uint8List.fromList(fixture.buffer.asUint8List());
    bytes[0x83] = 0x01;
    bytes[0x40000 + 0x83] = 0x01;

    final summary = const HgssParser().parseSummary(bytes);
    expect(summary.badges, 4);
    expect(summary.maxBadges, 16);
    expect(summary.badgeProgress, {'城都': 3, '关都': 1});
    expect(summary.verifiedBadgeIds, contains('boulder_badge'));
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

  test('uses TitoDex import time for the journey timeline', () async {
    final bytes = await rootBundle.load('assets/fixtures/PKMSS.sav');
    const parser = HgssParser();
    final savedAt = DateTime.utc(2026, 7, 15, 9, 30);
    final summary = parser.parseSummary(
      bytes.buffer.asUint8List(),
      sourceModifiedAt: savedAt,
    );

    expect(summary.savedAt, savedAt);
    final timelineEntry = parser.toJourney(summary).timeline.first;
    final parsedLocal = summary.parsedAt.toLocal();
    expect(
      timelineEntry.at,
      contains('${parsedLocal.year}/${parsedLocal.month}/${parsedLocal.day}'),
    );
    expect(timelineEntry.at, isNot(contains('2026/7/15')));
    expect(timelineEntry.text, contains('心金/魂银'));
  });
}
