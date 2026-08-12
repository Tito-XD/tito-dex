import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../models/journey.dart';
import '../../models/parsed_save.dart';
import '../../l10n/game_zh.dart';
import '../game/game_edition.dart';
import 'hgss_format.dart';
import 'hgss_map_lookup.dart';
import 'hgss_pokedex.dart';

const _partitionSize = 0x40000;
const _retailSaveSize = 524288;
const _generalSize = 0xF628;
const _footerMagic = 0x20060623;
const _footerMagicKorean = 0x20070903;

const _johtoBadgeIds = <String>[
  'zephyr_badge',
  'hive_badge',
  'plain_badge',
  'fog_badge',
  'storm_badge',
  'mineral_badge',
  'glacier_badge',
  'rising_badge',
];

const _kantoBadgeIds = <String>[
  'boulder_badge',
  'cascade_badge',
  'thunder_badge',
  'rainbow_badge',
  'soul_badge',
  'marsh_badge',
  'volcano_badge',
  'earth_badge',
];

class HgssParser {
  const HgssParser();

  bool canParse(Uint8List bytes) {
    if (bytes.length != _retailSaveSize) {
      return false;
    }
    return _validPartition(bytes, 0) || _validPartition(bytes, 1);
  }

  ParsedSaveSummary parseSummary(
    Uint8List bytes, {
    DateTime? sourceModifiedAt,
  }) {
    if (!canParse(bytes)) {
      throw FormatException('Expected $_retailSaveSize-byte HGSS retail save.');
    }

    final warnings = <String>[];
    final block = _activePartition(bytes);
    final base = block * _partitionSize;

    final trainerName = decodeGen4Text(bytes.sublist(base + 0x64, base + 0x74));
    final tid = readUint16(bytes, base + 0x74);
    final secretId = readUint16(bytes, base + 0x76);
    final money = readUint32(bytes, base + 0x78);
    final trainerGender = switch (bytes[base + 0x7C]) {
      0 => '男',
      1 => '女',
      _ => null,
    };
    final language = _languageLabel(bytes[base + 0x7D]);
    final johtoBadges = bytes[base + 0x7E];
    final kantoBadges = bytes[base + 0x83];
    final badgeCount = popcount(johtoBadges) + popcount(kantoBadges);
    final hours = readUint16(bytes, base + 0x86);
    final minutes = bytes[base + 0x88];
    final seconds = bytes[base + 0x89];
    final rawPartyCount = bytes[base + 0x94];
    final partyCount = rawPartyCount.clamp(0, 6);
    final mapId = readUint16(bytes, base + 0x1234);
    final starterSpeciesId = readUint16(bytes, base + 0xE44);
    final mapCoordinates = [
      readUint16(bytes, base + 0x236E),
      readUint16(bytes, base + 0x2372),
      readUint16(bytes, base + 0x2376),
    ];
    final motherMoney = readUint32(bytes, base + 0xC0D8);
    final adventureStartedAt = _gen4DateTime(readUint32(bytes, base + 0x34));
    final leagueChampionAt = _gen4DateTime(readUint32(bytes, base + 0x3C));
    final pokedex = HgssPokedexFlags.fromPartition(
      bytes.sublist(base, base + _partitionSize),
    );

    if (trainerName.trim().isEmpty) {
      warnings.add('Trainer name could not be decoded cleanly.');
    }
    if (rawPartyCount > 6) {
      warnings.add(
        'Party count $rawPartyCount is invalid; read first 6 slots.',
      );
    }

    final party = <ParsedPartyMember>[];
    for (var index = 0; index < partyCount; index++) {
      final start = base + 0x98 + index * 236;
      final slot = bytes.sublist(start, start + 236);
      final slotStats = decryptPartySlotStats(slot);
      final level = slotStats.level ?? 0;
      String? slotWarning;
      if (level > 100) {
        slotWarning =
            'Level $level looks invalid — slot may be empty or corrupted.';
        warnings.add('Party slot ${index + 1}: $slotWarning');
      }
      party.add(
        ParsedPartyMember(
          speciesId: slotStats.speciesId,
          speciesName: speciesNameFor(slotStats.speciesId),
          level: level <= 100 ? level : null,
          currentHp: slotStats.currentHp,
          maxHp: slotStats.maxHp,
          experience: slotStats.experience,
          abilityId: slotStats.abilityId,
          moveIds: slotStats.moveIds,
          nickname: slotStats.nickname,
          heldItemId: slotStats.heldItemId,
          friendship: slotStats.friendship,
          nature: slotStats.nature,
          isShiny: slotStats.isShiny,
          gender: slotStats.gender,
          status: slotStats.status,
          movePp: slotStats.movePp,
          movePpUps: slotStats.movePpUps,
          ivs: slotStats.ivs,
          evs: slotStats.evs,
          battleStats: slotStats.battleStats,
          isEgg: slotStats.isEgg,
          formIndex: slotStats.formIndex,
          warning: slotWarning,
        ),
      );
    }

    final gameVersion = bytes[base + 0x80];
    return ParsedSaveSummary(
      game: gameVersion == 7 ? 'HeartGold' : 'SoulSilver',
      trainerName: trainerName.isEmpty ? 'Trainer' : trainerName,
      playTime:
          '${hours.toString()}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
      badges: badgeCount,
      maxBadges: 16,
      locationLabel: locationLabelForMapId(mapId),
      party: party,
      saveHash: 'v$saveParserRevision:${sha256.convert(bytes)}',
      parsedAt: DateTime.now().toUtc(),
      savedAt: sourceModifiedAt?.toUtc(),
      warnings: warnings,
      tid: tid,
      secretId: secretId,
      money: money <= 999999 ? money : null,
      motherMoney: motherMoney <= 999999 ? motherMoney : null,
      trainerGender: trainerGender,
      language: language,
      starterSpeciesId: starterSpeciesId > 0 && starterSpeciesId <= 493
          ? starterSpeciesId
          : null,
      mapCoordinates: mapCoordinates,
      adventureStartedAt: adventureStartedAt,
      leagueChampionAt: leagueChampionAt,
      mapHeaderId: mapId,
      dexCaughtIds: pokedex.caughtIds,
      dexSeenIds: pokedex.seenIds,
      badgeProgress: {'城都': popcount(johtoBadges), '关都': popcount(kantoBadges)},
      verifiedBadgeIds: [
        ..._badgeIdsFromBits(johtoBadges, _johtoBadgeIds),
        ..._badgeIdsFromBits(kantoBadges, _kantoBadgeIds),
      ],
    );
  }

  CurrentJourney toJourney(
    ParsedSaveSummary summary, {
    CurrentJourney? existing,
  }) {
    final preserveTrainerName = existing?.trainerNameCustomized ?? false;
    final syncId = summary.saveHash.length >= 8
        ? summary.saveHash.substring(0, 8)
        : summary.saveHash;
    final syncEntry = JourneyTimelineEntry(
      id: 'parsed-$syncId',
      text: '已从本地${gameEditionFromJourneyGame(summary.game).labelZh}存档同步',
      // This event describes the TitoDex import, so its timestamp is the
      // import time. The previous file-modified timestamp could be stale,
      // unavailable, or supplied as zero by an Android document provider.
      at: _formatParsedAtLocal(summary.parsedAt),
    );

    final parsedParty = summary.party
        .map(
          (member) => PartyMember(
            species: localizeSpecies(member.speciesName),
            speciesId: member.speciesId,
            level: member.level,
            currentHp: member.currentHp,
            maxHp: member.maxHp,
            experience: member.experience,
            abilityId: member.abilityId,
            moveIds: member.moveIds,
            nickname: member.nickname,
            heldItemId: member.heldItemId,
            friendship: member.friendship,
            nature: member.nature,
            isShiny: member.isShiny,
            gender: member.gender,
            status: member.status,
            movePp: member.movePp,
            movePpUps: member.movePpUps,
            ivs: member.ivs,
            evs: member.evs,
            battleStats: member.battleStats,
            isEgg: member.isEgg,
            formIndex: member.formIndex,
          ),
        )
        .toList(growable: false);
    final keepUserParty = existing?.partyUserOverride ?? false;

    return CurrentJourney(
      game: summary.game,
      trainerName: preserveTrainerName
          ? existing!.trainerName
          : summary.trainerName,
      saveTrainerName: summary.trainerName,
      saveTrainerId: summary.tid,
      saveTrainerSecretId: summary.secretId,
      saveMoney: summary.money,
      saveMotherMoney: summary.motherMoney,
      saveTrainerGender: summary.trainerGender,
      saveLanguage: summary.language,
      saveStarterSpeciesId: summary.starterSpeciesId,
      saveMapCoordinates: summary.mapCoordinates,
      saveAdventureStartedAt: summary.adventureStartedAt,
      saveLeagueChampionAt: summary.leagueChampionAt,
      trainerNameCustomized: preserveTrainerName,
      trainerAvatarPath: existing?.trainerAvatarPath,
      trainerAvatarCustomized: existing?.trainerAvatarCustomized ?? false,
      location: summary.locationLabel,
      badges: summary.badges,
      maxBadges: summary.maxBadges,
      playTime: summary.playTime,
      companion: existing?.companion ?? 'Cyndaquil',
      party: keepUserParty ? existing!.party : parsedParty,
      saveSyncedParty: parsedParty,
      partyUserOverride: keepUserParty,
      timeline: _mergeTimeline(existing?.timeline ?? const [], syncEntry),
      nextReminder: existing?.nextReminder ?? '继续城都地区的旅程',
      saveDexCaughtIds: summary.dexCaughtIds.toList()..sort(),
      saveDexSeenIds: summary.dexSeenIds.toList()..sort(),
      saveDexHash: summary.saveHash,
      manualDexSeenIds: existing?.manualDexSeenIds ?? const [],
      manualDexCaughtIds: existing?.manualDexCaughtIds ?? const [],
      badgeProgress: summary.badgeProgress,
      verifiedBadgeIds: summary.verifiedBadgeIds,
    );
  }

  List<String> _badgeIdsFromBits(int bits, List<String> ids) => [
    for (var index = 0; index < ids.length; index++)
      if ((bits & (1 << index)) != 0) ids[index],
  ];

  List<JourneyTimelineEntry> _mergeTimeline(
    List<JourneyTimelineEntry> existing,
    JourneyTimelineEntry syncEntry,
  ) {
    final manual = existing
        .where((entry) => !entry.id.startsWith('parsed'))
        .toList();
    return [syncEntry, ...manual];
  }

  String _formatParsedAtLocal(DateTime parsedAt) {
    final local = parsedAt.toLocal();
    return '${local.year}/${local.month}/${local.day} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  DateTime? _gen4DateTime(int seconds) {
    if (seconds <= 0) return null;
    return DateTime.utc(2000).add(Duration(seconds: seconds));
  }

  String _languageLabel(int value) => switch (value) {
    1 => '日文',
    2 => '英文',
    3 => '法文',
    4 => '意大利文',
    5 => '德文',
    7 => '西班牙文',
    8 => '韩文',
    _ => '未知（$value）',
  };

  int _activePartition(Uint8List bytes) {
    final firstValid = _validPartition(bytes, 0);
    final secondValid = _validPartition(bytes, 1);
    if (!firstValid) return 1;
    if (!secondValid) return 0;

    final counterOffset = _generalSize - 0x14;
    final firstMajor = readUint32(bytes, counterOffset);
    final firstMinor = readUint32(bytes, counterOffset + 4);
    final secondMajor = readUint32(bytes, _partitionSize + counterOffset);
    final secondMinor = readUint32(bytes, _partitionSize + counterOffset + 4);
    if (secondMajor != firstMajor) {
      return secondMajor > firstMajor ? 1 : 0;
    }
    return secondMinor >= firstMinor ? 1 : 0;
  }

  bool _validPartition(Uint8List bytes, int partition) {
    final footer = partition * _partitionSize + _generalSize;
    final storedSize = readUint32(bytes, footer - 0x0C);
    final magic = readUint32(bytes, footer - 0x08);
    return storedSize == _generalSize &&
        (magic == _footerMagic || magic == _footerMagicKorean);
  }
}

String encodeJourneyJson(CurrentJourney journey) =>
    jsonEncode(journey.toJson());

CurrentJourney decodeJourneyJson(String source) =>
    CurrentJourney.fromJson(jsonDecode(source) as Map<String, dynamic>);
