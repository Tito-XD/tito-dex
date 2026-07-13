import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../models/journey.dart';
import '../../models/parsed_save.dart';
import '../../l10n/game_zh.dart';
import 'hgss_format.dart';
import 'hgss_map_lookup.dart';
import 'hgss_pokedex.dart';

const _partitionSize = 0x40000;
const _retailSaveSize = 524288;
const _saveCountOffset = 0xF618;

class HgssParser {
  const HgssParser();

  bool canParse(Uint8List bytes) => bytes.length == _retailSaveSize;

  ParsedSaveSummary parseSummary(Uint8List bytes) {
    if (!canParse(bytes)) {
      throw FormatException('Expected $_retailSaveSize-byte HGSS retail save.');
    }

    final warnings = <String>[];
    final block = _activePartition(bytes);
    final base = block * _partitionSize;

    final trainerName = decodeGen4Text(bytes.sublist(base + 0x64, base + 0x74));
    final tid = readUint16(bytes, base + 0x74);
    final johtoBadges = bytes[base + 0x7E];
    final badgeCount = popcount(johtoBadges);
    final hours = readUint16(bytes, base + 0x86);
    final minutes = bytes[base + 0x88];
    final seconds = bytes[base + 0x89];
    final partyCount = bytes[base + 0x94];
    final mapId = readUint16(bytes, base + 0x1234);
    final pokedex = HgssPokedexFlags.fromPartition(
      bytes.sublist(base, base + _partitionSize),
    );

    if (trainerName.trim().isEmpty) {
      warnings.add('Trainer name could not be decoded cleanly.');
    }

    final party = <ParsedPartyMember>[];
    for (var index = 0; index < partyCount; index++) {
      final start = base + 0x98 + index * 236;
      final slot = bytes.sublist(start, start + 236);
      final slotStats = decryptPartySlotStats(slot);
      final level = slotStats.level ?? 0;
      String? slotWarning;
      if (level > 100) {
        slotWarning = 'Level $level looks invalid — slot may be empty or corrupted.';
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
          warning: slotWarning,
        ),
      );
    }

    return ParsedSaveSummary(
      game: 'SoulSilver',
      trainerName: trainerName.isEmpty ? 'Trainer' : trainerName,
      playTime:
          '${hours.toString()}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
      badges: badgeCount,
      maxBadges: 8,
      locationLabel: locationLabelForMapId(mapId),
      party: party,
      saveHash: sha256.convert(bytes).toString(),
      parsedAt: DateTime.now().toUtc(),
      warnings: warnings,
      tid: tid,
      mapHeaderId: mapId,
      dexCaughtIds: pokedex.caughtIds,
      dexSeenIds: pokedex.seenIds,
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
      text: '已从本地魂银存档同步',
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
          ),
        )
        .toList(growable: false);
    final keepUserParty = existing?.partyUserOverride ?? false;

    return CurrentJourney(
      game: summary.game,
      trainerName:
          preserveTrainerName ? existing!.trainerName : summary.trainerName,
      saveTrainerName: summary.trainerName,
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
    );
  }

  List<JourneyTimelineEntry> _mergeTimeline(
    List<JourneyTimelineEntry> existing,
    JourneyTimelineEntry syncEntry,
  ) {
    final manual =
        existing.where((entry) => !entry.id.startsWith('parsed')).toList();
    return [syncEntry, ...manual];
  }

  String _formatParsedAtLocal(DateTime parsedAt) {
    final local = parsedAt.toLocal();
    return '${local.year}/${local.month}/${local.day} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  int _activePartition(Uint8List bytes) {
    final first = readUint32(bytes, _saveCountOffset);
    final second = readUint32(bytes, _partitionSize + _saveCountOffset);
    return second >= first ? 1 : 0;
  }
}

String encodeJourneyJson(CurrentJourney journey) =>
    jsonEncode(journey.toJson());

CurrentJourney decodeJourneyJson(String source) =>
    CurrentJourney.fromJson(jsonDecode(source) as Map<String, dynamic>);
