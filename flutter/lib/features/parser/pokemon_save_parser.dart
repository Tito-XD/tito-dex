import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../models/journey.dart';
import '../../models/parsed_save.dart';
import 'hgss_format.dart';
import 'hgss_parser.dart';

/// Detects and reads the non-Switch main-series save formats represented by
/// TitoDex's game catalog. HGSS keeps its richer party, map and Pokédex parser;
/// the other formats currently provide trustworthy trainer metadata without
/// inventing unsupported fields.
class PokemonSaveParser {
  const PokemonSaveParser();

  static const supportedFileSizes = <int>{
    0x8000, // Gen I / II international
    0x10000, // Gen II Japanese / half-size Gen III
    0x20000, // Gen III
    0x24000, // trimmed BW
    0x26000, // trimmed B2W2
    0x80000, // Gen IV / V
    0x65600, // XY
    0x76000, // ORAS
    0x6BE00, // Sun / Moon
    0x6CC00, // Ultra Sun / Ultra Moon
  };

  bool canParse(Uint8List bytes) => _identify(bytes) != null;

  ParsedSaveSummary parseSummary(
    Uint8List bytes, {
    DateTime? sourceModifiedAt,
  }) {
    final format = _identify(bytes);
    if (format == null) {
      throw const FormatException('Unsupported Pokémon save format.');
    }
    if (format == _SaveFormat.hgss) {
      return const HgssParser().parseSummary(
        bytes,
        sourceModifiedAt: sourceModifiedAt,
      );
    }
    final parsedAt = DateTime.now().toUtc();
    final savedAt = sourceModifiedAt?.toUtc();
    return switch (format) {
      _SaveFormat.gen1International => _parseGen1(
        bytes,
        japanese: false,
        parsedAt: parsedAt,
        savedAt: savedAt,
      ),
      _SaveFormat.gen1Japanese => _parseGen1(
        bytes,
        japanese: true,
        parsedAt: parsedAt,
        savedAt: savedAt,
      ),
      _SaveFormat.gen2GsInternational => _parseGen2(
        bytes,
        crystal: false,
        japanese: false,
        parsedAt: parsedAt,
        savedAt: savedAt,
      ),
      _SaveFormat.gen2CrystalInternational => _parseGen2(
        bytes,
        crystal: true,
        japanese: false,
        parsedAt: parsedAt,
        savedAt: savedAt,
      ),
      _SaveFormat.gen2GsJapanese => _parseGen2(
        bytes,
        crystal: false,
        japanese: true,
        parsedAt: parsedAt,
        savedAt: savedAt,
      ),
      _SaveFormat.gen2CrystalJapanese => _parseGen2(
        bytes,
        crystal: true,
        japanese: true,
        parsedAt: parsedAt,
        savedAt: savedAt,
      ),
      _SaveFormat.gen3 => _parseGen3(bytes, parsedAt, savedAt),
      _SaveFormat.gen4Dp => _parseGen4(
        bytes,
        generalSize: 0xC100,
        trainerOffset: 0x64,
        partyOffset: 0x98,
        fallbackGame: 'DiamondPearl',
        parsedAt: parsedAt,
        savedAt: savedAt,
      ),
      _SaveFormat.gen4Pt => _parseGen4(
        bytes,
        generalSize: 0xCF2C,
        trainerOffset: 0x68,
        partyOffset: 0xA0,
        fallbackGame: 'Platinum',
        parsedAt: parsedAt,
        savedAt: savedAt,
      ),
      _SaveFormat.gen5 => _parseGen5(bytes, parsedAt, savedAt),
      _SaveFormat.gen6Xy => _parseGen6Or7(
        bytes,
        statusOffset: 0x14000,
        nameOffset: 0x48,
        playTimeOffset: 0x01800,
        fallbackGame: 'XY',
        parsedAt: parsedAt,
        sourceSavedAt: savedAt,
      ),
      _SaveFormat.gen6Oras => _parseGen6Or7(
        bytes,
        statusOffset: 0x14000,
        nameOffset: 0x48,
        playTimeOffset: 0x01800,
        fallbackGame: 'ORAS',
        parsedAt: parsedAt,
        sourceSavedAt: savedAt,
      ),
      _SaveFormat.gen7Sm => _parseGen6Or7(
        bytes,
        statusOffset: 0x01200,
        nameOffset: 0x38,
        playTimeOffset: 0x40C00,
        fallbackGame: 'SunMoon',
        parsedAt: parsedAt,
        sourceSavedAt: savedAt,
      ),
      _SaveFormat.gen7Usum => _parseGen6Or7(
        bytes,
        statusOffset: 0x01400,
        nameOffset: 0x38,
        playTimeOffset: 0x41000,
        fallbackGame: 'USUM',
        parsedAt: parsedAt,
        sourceSavedAt: savedAt,
      ),
      _SaveFormat.hgss => throw StateError('handled above'),
    };
  }

  CurrentJourney toJourney(
    ParsedSaveSummary summary, {
    CurrentJourney? existing,
  }) => const HgssParser().toJourney(summary, existing: existing);

  _SaveFormat? _identify(Uint8List bytes) {
    if (!supportedFileSizes.contains(bytes.length)) return null;
    if (_looksLikeGen3(bytes)) return _SaveFormat.gen3;
    if (bytes.length == 0x80000) {
      if (const HgssParser().canParse(bytes)) return _SaveFormat.hgss;
      if (_validGen4(bytes, 0xC100)) return _SaveFormat.gen4Dp;
      if (_validGen4(bytes, 0xCF2C)) return _SaveFormat.gen4Pt;
      if (_looksLikeGen5(bytes)) return _SaveFormat.gen5;
      return null;
    }
    if (bytes.length == 0x24000 || bytes.length == 0x26000) {
      return _looksLikeGen5(bytes) ? _SaveFormat.gen5 : null;
    }
    if (bytes.length == 0x65600 && _hasBeefFooter(bytes)) {
      return _SaveFormat.gen6Xy;
    }
    if (bytes.length == 0x76000 && _hasBeefFooter(bytes)) {
      return _SaveFormat.gen6Oras;
    }
    if (bytes.length == 0x6BE00 && _hasBeefFooter(bytes)) {
      return _SaveFormat.gen7Sm;
    }
    if (bytes.length == 0x6CC00 && _hasBeefFooter(bytes)) {
      return _SaveFormat.gen7Usum;
    }
    if (bytes.length == 0x8000 || bytes.length == 0x10000) {
      if (_validPartyList(bytes, 0x2865, 20)) {
        return _SaveFormat.gen2CrystalInternational;
      }
      if (_validPartyList(bytes, 0x288A, 20)) {
        return _SaveFormat.gen2GsInternational;
      }
      if (_validPartyList(bytes, 0x281A, 30)) {
        return _SaveFormat.gen2CrystalJapanese;
      }
      if (_validPartyList(bytes, 0x283E, 30)) {
        return _SaveFormat.gen2GsJapanese;
      }
      if (_validPartyList(bytes, 0x2F2C, 20)) {
        return _SaveFormat.gen1International;
      }
      if (_validPartyList(bytes, 0x2ED5, 30)) {
        return _SaveFormat.gen1Japanese;
      }
    }
    return null;
  }

  bool _validPartyList(Uint8List bytes, int offset, int maxCount) {
    if (offset + 2 >= bytes.length) return false;
    final count = bytes[offset];
    return count <= 6 &&
        count <= maxCount &&
        offset + 1 + count < bytes.length &&
        bytes[offset + 1 + count] == 0xFF;
  }

  bool _looksLikeGen3(Uint8List bytes) =>
      _gen3Slot(bytes, 0) != null ||
      (bytes.length >= 0x1C000 && _gen3Slot(bytes, 0xE000) != null);

  _Gen3Slot? _gen3Slot(Uint8List bytes, int base) {
    if (base + 14 * 0x1000 > bytes.length) return null;
    final sections = <int, int>{};
    int? saveIndex;
    for (var physical = 0; physical < 14; physical++) {
      final sector = base + physical * 0x1000;
      final id = readUint16(bytes, sector + 0xFF4);
      final signature = readUint32(bytes, sector + 0xFF8);
      if (id > 13 || signature != 0x08012025 || sections.containsKey(id)) {
        return null;
      }
      sections[id] = sector;
      saveIndex ??= readUint32(bytes, sector + 0xFFC);
    }
    return _Gen3Slot(sections: sections, saveIndex: saveIndex ?? 0);
  }

  bool _validGen4(Uint8List bytes, int generalSize) {
    for (final base in const [0, 0x40000]) {
      final end = base + generalSize;
      if (readUint32(bytes, end - 0x0C) != generalSize) continue;
      final magic = readUint32(bytes, end - 0x08);
      if (magic == 0x20060623 || magic == 0x20070903) return true;
    }
    return false;
  }

  bool _looksLikeGen5(Uint8List bytes) {
    if (bytes.length <= 0x1941F) return false;
    return const {20, 21, 22, 23}.contains(bytes[0x1941F]);
  }

  bool _hasBeefFooter(Uint8List bytes) =>
      readUint32(bytes, bytes.length - 0x1F0) == 0x42454546;

  ParsedSaveSummary _parseGen1(
    Uint8List bytes, {
    required bool japanese,
    required DateTime parsedAt,
    required DateTime? savedAt,
  }) {
    final nameOffset = 0x2598;
    final tidOffset = japanese ? 0x25FB : 0x2605;
    final badgesOffset = japanese ? 0x25F8 : 0x2602;
    final timeOffset = japanese ? 0x2CA0 : 0x2CED;
    final hours = bytes[timeOffset] + (bytes[timeOffset + 1] == 0 ? 0 : 256);
    return _baseSummary(
      bytes: bytes,
      game: 'RedBlueYellow',
      trainerName: _decodeGen12(bytes, nameOffset, japanese ? 5 : 7),
      tid: _readUint16Be(bytes, tidOffset),
      hours: hours,
      minutes: bytes[timeOffset + 2],
      seconds: bytes[timeOffset + 3],
      badges: popcount(bytes[badgesOffset]),
      parsedAt: parsedAt,
      savedAt: savedAt,
      warnings: [
        if (japanese) '已识别日版第一世代存档；日文特殊字形可能以占位符显示。',
        '第一世代目前同步训练家、徽章和游戏时间；队伍与地图尚未导入。',
      ],
    );
  }

  ParsedSaveSummary _parseGen2(
    Uint8List bytes, {
    required bool crystal,
    required bool japanese,
    required DateTime parsedAt,
    required DateTime? savedAt,
  }) {
    final timeOffset = japanese ? 0x2034 : (crystal ? 0x2052 : 0x2053);
    final badgesOffset = japanese
        ? (crystal ? 0x23C7 : 0x23C5)
        : (crystal ? 0x23E5 : 0x23E4);
    return _baseSummary(
      bytes: bytes,
      game: crystal ? 'Crystal' : 'GoldSilver',
      trainerName: _decodeGen12(bytes, 0x200B, japanese ? 5 : 7),
      tid: _readUint16Be(bytes, 0x2009),
      hours: _readUint16Be(bytes, timeOffset),
      minutes: bytes[timeOffset + 2],
      seconds: bytes[timeOffset + 3],
      badges: popcount(bytes[badgesOffset]),
      parsedAt: parsedAt,
      savedAt: savedAt,
      warnings: [
        if (japanese) '已识别日版第二世代存档；日文特殊字形可能以占位符显示。',
        '第二世代目前同步训练家、徽章和游戏时间；队伍与地图尚未导入。',
      ],
    );
  }

  ParsedSaveSummary _parseGen3(
    Uint8List bytes,
    DateTime parsedAt,
    DateTime? savedAt,
  ) {
    final slots = <_Gen3Slot>[
      if (_gen3Slot(bytes, 0) case final slot?) slot,
      if (_gen3Slot(bytes, 0xE000) case final slot?) slot,
    ]..sort((a, b) => b.saveIndex.compareTo(a.saveIndex));
    final small = slots.first.sections[0]!;
    final frlgKey = readUint32(bytes, small + 0xF20);
    final emeraldKey = readUint32(bytes, small + 0xAC);
    final game = _meaningfulKey(frlgKey)
        ? 'FireRedLeafGreen'
        : (_meaningfulKey(emeraldKey) ? 'Emerald' : 'RubySapphire');
    return _baseSummary(
      bytes: bytes,
      game: game,
      trainerName: _decodeGen3(bytes, small, 7),
      tid: readUint16(bytes, small + 0xA),
      hours: readUint16(bytes, small + 0xE),
      minutes: bytes[small + 0x10],
      seconds: bytes[small + 0x11],
      badges: 0,
      parsedAt: parsedAt,
      savedAt: savedAt,
      warnings: const ['第三世代目前同步训练家和游戏时间；具体配对版本、徽章、队伍与地图尚未导入。'],
    );
  }

  bool _meaningfulKey(int value) => value != 0 && value != 0xFFFFFFFF;

  ParsedSaveSummary _parseGen4(
    Uint8List bytes, {
    required int generalSize,
    required int trainerOffset,
    required int partyOffset,
    required String fallbackGame,
    required DateTime parsedAt,
    required DateTime? savedAt,
  }) {
    final partition = _activeGen4Partition(bytes, generalSize);
    final base = partition * 0x40000;
    final trainer = base + trainerOffset;
    final version = bytes[trainer + 0x1C];
    final game = switch (version) {
      10 => 'Diamond',
      11 => 'Pearl',
      12 => 'Platinum',
      _ => fallbackGame,
    };
    final party = <ParsedPartyMember>[];
    final count = bytes[base + partyOffset - 4].clamp(0, 6);
    for (var index = 0; index < count; index++) {
      final start = base + partyOffset + index * 236;
      final stats = decryptPartySlotStats(bytes.sublist(start, start + 236));
      if (stats.speciesId <= 0 || stats.speciesId > 493) continue;
      party.add(
        ParsedPartyMember(
          speciesId: stats.speciesId,
          speciesName: speciesNameFor(stats.speciesId),
          level: stats.level,
          currentHp: stats.currentHp,
          maxHp: stats.maxHp,
          experience: stats.experience,
        ),
      );
    }
    return _baseSummary(
      bytes: bytes,
      game: game,
      trainerName: decodeGen4Text(bytes.sublist(trainer, trainer + 16)),
      tid: readUint16(bytes, trainer + 0x10),
      hours: readUint16(bytes, trainer + 0x22),
      minutes: bytes[trainer + 0x24],
      seconds: bytes[trainer + 0x25],
      badges: popcount(bytes[trainer + 0x1A]),
      party: party,
      parsedAt: parsedAt,
      savedAt: savedAt,
      warnings: const ['第四世代 DP/Pt 已同步训练家、徽章、时间与队伍；地图和图鉴进度尚未导入。'],
    );
  }

  int _activeGen4Partition(Uint8List bytes, int generalSize) {
    bool valid(int base) {
      final end = base + generalSize;
      return readUint32(bytes, end - 0x0C) == generalSize;
    }

    if (!valid(0)) return 1;
    if (!valid(0x40000)) return 0;
    final counter = generalSize - 0x14;
    final aMajor = readUint32(bytes, counter);
    final bMajor = readUint32(bytes, 0x40000 + counter);
    if (aMajor != bMajor) return bMajor > aMajor ? 1 : 0;
    return readUint32(bytes, 0x40000 + counter + 4) >=
            readUint32(bytes, counter + 4)
        ? 1
        : 0;
  }

  ParsedSaveSummary _parseGen5(
    Uint8List bytes,
    DateTime parsedAt,
    DateTime? savedAt,
  ) {
    const player = 0x19400;
    final version = bytes[player + 0x1F];
    final game = switch (version) {
      20 => 'White',
      21 => 'Black',
      22 => 'White2',
      23 => 'Black2',
      _ => 'BlackWhite',
    };
    final embeddedSavedAt = _decodeGen5SaveDate(
      readUint32(bytes, player + 0x28),
    );
    return _baseSummary(
      bytes: bytes,
      game: game,
      trainerName: _decodeUtf16(bytes, player + 4, 16),
      tid: readUint16(bytes, player + 0x14),
      hours: readUint16(bytes, player + 0x24),
      minutes: bytes[player + 0x26],
      seconds: bytes[player + 0x27],
      badges: 0,
      parsedAt: parsedAt,
      savedAt: embeddedSavedAt?.toUtc() ?? savedAt,
      warnings: const ['已读取第五世代存档内的最后保存日期；徽章、队伍与地图尚未导入。'],
    );
  }

  DateTime? _decodeGen5SaveDate(int packed) {
    final year = 2000 + (packed & 0x7F);
    final month = (packed >> 7) & 0xF;
    final day = (packed >> 11) & 0x1F;
    final hour = (packed >> 16) & 0x1F;
    final minute = (packed >> 21) & 0x3F;
    return _checkedDate(year, month, day, hour, minute);
  }

  ParsedSaveSummary _parseGen6Or7(
    Uint8List bytes, {
    required int statusOffset,
    required int nameOffset,
    required int playTimeOffset,
    required String fallbackGame,
    required DateTime parsedAt,
    required DateTime? sourceSavedAt,
  }) {
    final version = bytes[statusOffset + 4];
    final game = switch (version) {
      24 => 'X',
      25 => 'Y',
      26 => 'AlphaSapphire',
      27 => 'OmegaRuby',
      30 => 'Sun',
      31 => 'Moon',
      32 => 'UltraSun',
      33 => 'UltraMoon',
      _ => fallbackGame,
    };
    final embeddedSavedAt = _decodePackedSaveDate(
      readUint32(bytes, playTimeOffset + 4),
    );
    return _baseSummary(
      bytes: bytes,
      game: game,
      trainerName: _decodeUtf16(bytes, statusOffset + nameOffset, 0x1A),
      tid: readUint16(bytes, statusOffset),
      hours: readUint16(bytes, playTimeOffset),
      minutes: bytes[playTimeOffset + 2],
      seconds: bytes[playTimeOffset + 3],
      badges: 0,
      parsedAt: parsedAt,
      savedAt: embeddedSavedAt?.toUtc() ?? sourceSavedAt,
      warnings: const ['已读取存档内最后保存日期；徽章、队伍与地图尚未导入。'],
    );
  }

  DateTime? _decodePackedSaveDate(int packed) {
    final year = packed & 0xFFF;
    final month = (packed >> 12) & 0xF;
    final day = (packed >> 16) & 0x1F;
    final hour = (packed >> 21) & 0x1F;
    final minute = (packed >> 26) & 0x3F;
    return _checkedDate(year, month, day, hour, minute);
  }

  DateTime? _checkedDate(int year, int month, int day, int hour, int minute) {
    if (year < 2000 ||
        year > 2200 ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31 ||
        hour > 23 ||
        minute > 59) {
      return null;
    }
    final value = DateTime(year, month, day, hour, minute);
    return value.year == year && value.month == month && value.day == day
        ? value
        : null;
  }

  ParsedSaveSummary _baseSummary({
    required Uint8List bytes,
    required String game,
    required String trainerName,
    required int tid,
    required int hours,
    required int minutes,
    required int seconds,
    required int badges,
    required DateTime parsedAt,
    required DateTime? savedAt,
    List<ParsedPartyMember> party = const [],
    List<String> warnings = const [],
  }) => ParsedSaveSummary(
    game: game,
    trainerName: trainerName.trim().isEmpty ? 'Trainer' : trainerName,
    playTime:
        '$hours:${minutes.clamp(0, 59).toString().padLeft(2, '0')}:${seconds.clamp(0, 59).toString().padLeft(2, '0')}',
    badges: badges,
    maxBadges: 8,
    locationLabel: '未知地点',
    party: party,
    saveHash: 'v$saveParserRevision:${sha256.convert(bytes)}',
    parsedAt: parsedAt,
    savedAt: savedAt,
    warnings: warnings,
    tid: tid,
  );

  String _decodeGen12(Uint8List bytes, int offset, int length) {
    final out = StringBuffer();
    for (var index = 0; index < length; index++) {
      final code = bytes[offset + index];
      if (code == 0x50) break;
      if (code >= 0x80 && code <= 0x99) {
        out.writeCharCode('A'.codeUnitAt(0) + code - 0x80);
      } else if (code >= 0xA0 && code <= 0xB9) {
        out.writeCharCode('a'.codeUnitAt(0) + code - 0xA0);
      } else if (code >= 0xF6 && code <= 0xFF) {
        out.writeCharCode('0'.codeUnitAt(0) + code - 0xF6);
      } else if (code == 0x7F) {
        out.write(' ');
      } else {
        out.write('[$code]');
      }
    }
    return out.toString();
  }

  String _decodeGen3(Uint8List bytes, int offset, int length) {
    final out = StringBuffer();
    for (var index = 0; index < length; index++) {
      final code = bytes[offset + index];
      if (code == 0xFF) break;
      if (code >= 0xA1 && code <= 0xAA) {
        out.writeCharCode('0'.codeUnitAt(0) + code - 0xA1);
      } else if (code >= 0xBB && code <= 0xD4) {
        out.writeCharCode('A'.codeUnitAt(0) + code - 0xBB);
      } else if (code >= 0xD5 && code <= 0xEE) {
        out.writeCharCode('a'.codeUnitAt(0) + code - 0xD5);
      } else if (code == 0x00) {
        out.write(' ');
      } else {
        out.write('[$code]');
      }
    }
    return out.toString();
  }

  String _decodeUtf16(Uint8List bytes, int offset, int byteLength) {
    final out = StringBuffer();
    for (var index = 0; index + 1 < byteLength; index += 2) {
      final code = readUint16(bytes, offset + index);
      if (code == 0 || code == 0xFFFF) break;
      if (code >= 0xFF10 && code <= 0xFF19) {
        out.writeCharCode('0'.codeUnitAt(0) + code - 0xFF10);
      } else if (code >= 0xFF21 && code <= 0xFF3A) {
        out.writeCharCode('A'.codeUnitAt(0) + code - 0xFF21);
      } else if (code >= 0xFF41 && code <= 0xFF5A) {
        out.writeCharCode('a'.codeUnitAt(0) + code - 0xFF41);
      } else {
        out.writeCharCode(code);
      }
    }
    return out.toString();
  }

  int _readUint16Be(Uint8List bytes, int offset) =>
      (bytes[offset] << 8) | bytes[offset + 1];
}

enum _SaveFormat {
  gen1International,
  gen1Japanese,
  gen2GsInternational,
  gen2CrystalInternational,
  gen2GsJapanese,
  gen2CrystalJapanese,
  gen3,
  gen4Dp,
  gen4Pt,
  hgss,
  gen5,
  gen6Xy,
  gen6Oras,
  gen7Sm,
  gen7Usum,
}

class _Gen3Slot {
  const _Gen3Slot({required this.sections, required this.saveIndex});

  final Map<int, int> sections;
  final int saveIndex;
}
