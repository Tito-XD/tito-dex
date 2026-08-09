import '../../l10n/game_zh.dart';

const _blockPosition = <int>[
  0,
  1,
  2,
  3,
  0,
  1,
  3,
  2,
  0,
  2,
  1,
  3,
  0,
  3,
  1,
  2,
  0,
  2,
  3,
  1,
  0,
  3,
  2,
  1,
  1,
  0,
  2,
  3,
  1,
  0,
  3,
  2,
  2,
  0,
  1,
  3,
  3,
  0,
  1,
  2,
  2,
  0,
  3,
  1,
  3,
  0,
  2,
  1,
  1,
  2,
  0,
  3,
  1,
  3,
  0,
  2,
  2,
  1,
  0,
  3,
  3,
  1,
  0,
  2,
  2,
  3,
  0,
  1,
  3,
  2,
  0,
  1,
  1,
  2,
  3,
  0,
  1,
  3,
  2,
  0,
  2,
  1,
  3,
  0,
  3,
  1,
  2,
  0,
  2,
  3,
  1,
  0,
  3,
  2,
  1,
  0,
  0,
  1,
  2,
  3,
  0,
  1,
  3,
  2,
  0,
  2,
  1,
  3,
  0,
  3,
  1,
  2,
  0,
  2,
  3,
  1,
  0,
  3,
  2,
  1,
  1,
  0,
  2,
  3,
  1,
  0,
  3,
  2,
];

const _speciesNames = <int, String>{
  63: 'Abra',
  96: 'Drowzee',
  155: 'Cyndaquil',
  156: 'Quilava',
  157: 'Typhlosion',
  175: 'Togepi',
  176: 'Togetic',
  179: 'Mareep',
  180: 'Flaaffy',
  181: 'Ampharos',
  447: 'Riolu',
  448: 'Lucario',
};

String speciesNameFor(int speciesId) =>
    _speciesNames[speciesId] ?? 'Species #$speciesId';

int? knownSpeciesIdForLabel(String label) {
  final trimmed = label.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  for (final entry in _speciesNames.entries) {
    if (entry.value.toLowerCase() == trimmed.toLowerCase()) {
      return entry.key;
    }
    if (localizeSpecies(entry.value) == trimmed) {
      return entry.key;
    }
  }

  return null;
}

String decodeGen4Text(List<int> buffer) {
  final chars = <String>[];
  for (var index = 0; index + 1 < buffer.length; index += 2) {
    final code = buffer[index] | (buffer[index + 1] << 8);
    if (code == 0xFFFF) {
      break;
    }
    if (code >= 0x00A2 && code <= 0x00AB) {
      chars.add(String.fromCharCode('0'.codeUnitAt(0) + code - 0x00A2));
    } else if (code >= 0x00AC && code <= 0x00C5) {
      chars.add(String.fromCharCode('A'.codeUnitAt(0) + code - 0x00AC));
    } else if (code >= 0x00C6 && code <= 0x00DF) {
      chars.add(String.fromCharCode('a'.codeUnitAt(0) + code - 0x00C6));
    } else if (code >= 0x0121 && code <= 0x012A) {
      chars.add(String.fromCharCode('0'.codeUnitAt(0) + code - 0x0121));
    } else if (code >= 0x012B && code <= 0x0144) {
      chars.add(String.fromCharCode('A'.codeUnitAt(0) + code - 0x012B));
    } else if (code >= 0x0145 && code <= 0x015E) {
      chars.add(String.fromCharCode('a'.codeUnitAt(0) + code - 0x0145));
    } else if (code == 0x01DE) {
      chars.add(' ');
    } else if (code >= 0x20 && code <= 0x7E) {
      chars.add(String.fromCharCode(code));
    } else {
      chars.add('[$code]');
    }
  }
  return chars.join();
}

List<int> _cryptArray(List<int> data, int seed) {
  final out = List<int>.from(data);
  var currentSeed = seed;
  for (var index = 0; index + 1 < out.length; index += 2) {
    currentSeed = (0x41C64E6D * currentSeed + 0x6073) & 0xFFFFFFFF;
    final xor = (currentSeed >> 16) & 0xFFFF;
    final value = (out[index] | (out[index + 1] << 8)) ^ xor;
    out[index] = value & 0xFF;
    out[index + 1] = (value >> 8) & 0xFF;
  }
  return out;
}

List<int> _shuffleBlocks(List<int> data, int sv) {
  final blocks = <List<int>>[
    for (var block = 0; block < 4; block++)
      data.sublist(block * 32, (block + 1) * 32),
  ];
  final perm = List<int>.generate(4, (index) => index);
  final slotOf = List<int>.generate(4, (index) => index);
  final order = _blockPosition.sublist(sv * 4, sv * 4 + 4);
  for (var index = 0; index < 3; index++) {
    final desired = order[index];
    final swapIndex = slotOf[desired];
    if (swapIndex == index) {
      continue;
    }
    final temp = blocks[index];
    blocks[index] = blocks[swapIndex];
    blocks[swapIndex] = temp;
    final blockAtIndex = perm[index];
    perm[swapIndex] = blockAtIndex;
    slotOf[blockAtIndex] = swapIndex;
  }
  return blocks.expand((block) => block).toList();
}

class PartySlotStats {
  const PartySlotStats({
    required this.speciesId,
    this.level,
    this.currentHp,
    this.maxHp,
    this.experience,
    this.abilityId,
    this.moveIds = const [],
    this.nickname,
    this.heldItemId,
    this.friendship,
    this.nature,
    this.isShiny = false,
    this.gender,
    this.status,
    this.movePp = const [],
    this.movePpUps = const [],
    this.ivs = const [],
    this.evs = const [],
    this.battleStats = const {},
    this.isEgg = false,
    this.formIndex = 0,
  });

  final int speciesId;
  final int? level;
  final int? currentHp;
  final int? maxHp;
  final int? experience;
  final int? abilityId;
  final List<int> moveIds;
  final String? nickname;
  final int? heldItemId;
  final int? friendship;
  final String? nature;
  final bool isShiny;
  final String? gender;
  final String? status;
  final List<int> movePp;
  final List<int> movePpUps;
  final List<int> ivs;
  final List<int> evs;
  final Map<String, int> battleStats;
  final bool isEgg;
  final int formIndex;
}

(int speciesId, int level) decryptPartySlot(List<int> raw) {
  final stats = decryptPartySlotStats(raw);
  return (stats.speciesId, stats.level ?? 0);
}

PartySlotStats decryptPartySlotStats(List<int> raw) {
  final slot = List<int>.from(raw);
  final personality =
      slot[0] | (slot[1] << 8) | (slot[2] << 16) | (slot[3] << 24);
  final checksum = slot[6] | (slot[7] << 8);
  final sv = (personality >> 13) & 31;
  final encrypted = _cryptArray(slot.sublist(8, 136), checksum);
  final decrypted = _shuffleBlocks(encrypted, sv);
  final speciesId = decrypted[0] | (decrypted[1] << 8);
  // Relative to the decrypted payload (the PK4 file's 0x08 header removed):
  // EXP is at 0x08, ability at 0x0D, and Block B's four moves at 0x20–0x27.
  // The old EXP offset 0x04 was the OT ID and produced plausible-looking but
  // incorrect progress values.
  final experience = readUint32(decrypted, 8);
  final abilityId = decrypted[13];
  final heldItemId = readUint16(decrypted, 2);
  final friendship = decrypted[12];
  final rawMoveIds = <int>[
    for (final offset in const [32, 34, 36, 38]) readUint16(decrypted, offset),
  ];
  final validMoveIndexes = <int>[
    for (var index = 0; index < rawMoveIds.length; index++)
      if (rawMoveIds[index] > 0 && rawMoveIds[index] <= 467) index,
  ];
  final moveIds = [for (final index in validMoveIndexes) rawMoveIds[index]];
  final movePp = [for (final index in validMoveIndexes) decrypted[40 + index]];
  final movePpUps = [
    for (final index in validMoveIndexes) decrypted[44 + index],
  ];
  final ivBits = readUint32(decrypted, 48);
  final ivs = [
    for (var index = 0; index < 6; index++) (ivBits >> (index * 5)) & 0x1F,
  ];
  final evs = decrypted.sublist(16, 22);
  final identity = decrypted[56];
  final isNicknamed = ivBits & (1 << 31) != 0;
  final decodedNickname = decodeGen4Text(decrypted.sublist(64, 86)).trim();
  final otId = readUint16(decrypted, 4);
  final otSecretId = readUint16(decrypted, 6);
  final shinyValue =
      otId ^ otSecretId ^ (personality & 0xFFFF) ^ (personality >> 16);

  final stats = _cryptArray(slot.sublist(136, 236), personality);
  // HGSS party stats: level @ +4, current HP @ +6, max HP @ +8.
  final level = stats[4];
  final currentHp = readUint16(stats, 6);
  final maxHp = readUint16(stats, 8);

  final validLevel = level > 0 && level <= 100 ? level : null;
  final validHp = maxHp > 0 && currentHp >= 0 && currentHp <= maxHp
      ? (currentHp: currentHp, maxHp: maxHp)
      : null;

  return PartySlotStats(
    speciesId: speciesId,
    level: validLevel,
    currentHp: validHp?.currentHp,
    maxHp: validHp?.maxHp,
    experience: experience > 0 && experience < 2000000 ? experience : null,
    abilityId: abilityId > 0 ? abilityId : null,
    moveIds: moveIds,
    nickname: isNicknamed && decodedNickname.isNotEmpty
        ? decodedNickname
        : null,
    heldItemId: heldItemId == 0 ? null : heldItemId,
    friendship: friendship,
    nature: _natureNamesZh[personality % 25],
    isShiny: shinyValue < 8,
    gender: identity & 0x04 != 0
        ? '无性别'
        : identity & 0x02 != 0
        ? '雌性'
        : '雄性',
    status: _partyStatusLabel(stats[0]),
    movePp: movePp,
    movePpUps: movePpUps,
    ivs: ivs,
    evs: evs,
    battleStats: {
      '攻击': readUint16(stats, 10),
      '防御': readUint16(stats, 12),
      '速度': readUint16(stats, 14),
      '特攻': readUint16(stats, 16),
      '特防': readUint16(stats, 18),
    },
    isEgg: ivBits & (1 << 30) != 0,
    formIndex: identity >> 3,
  );
}

const _natureNamesZh = <String>[
  '勤奋',
  '怕寂寞',
  '勇敢',
  '固执',
  '顽皮',
  '大胆',
  '坦率',
  '悠闲',
  '淘气',
  '乐天',
  '胆小',
  '急躁',
  '认真',
  '爽朗',
  '天真',
  '内敛',
  '慢吞吞',
  '冷静',
  '害羞',
  '马虎',
  '温和',
  '温顺',
  '自大',
  '慎重',
  '浮躁',
];

String? _partyStatusLabel(int value) {
  if (value & 0x80 != 0) return '剧毒';
  if (value & 0x07 != 0) return '睡眠';
  if (value & 0x08 != 0) return '中毒';
  if (value & 0x10 != 0) return '灼伤';
  if (value & 0x20 != 0) return '冰冻';
  if (value & 0x40 != 0) return '麻痹';
  return null;
}

/// Exposed for fixture/debug tooling.
List<int> decryptPartyStatsBlock(List<int> raw) {
  final slot = List<int>.from(raw);
  final personality =
      slot[0] | (slot[1] << 8) | (slot[2] << 16) | (slot[3] << 24);
  return _cryptArray(slot.sublist(136, 236), personality);
}

int popcount(int value) {
  var count = 0;
  while (value != 0) {
    count += value & 1;
    value >>= 1;
  }
  return count;
}

int readUint32(List<int> data, int offset) =>
    data[offset] |
    (data[offset + 1] << 8) |
    (data[offset + 2] << 16) |
    (data[offset + 3] << 24);

int readUint16(List<int> data, int offset) =>
    data[offset] | (data[offset + 1] << 8);
