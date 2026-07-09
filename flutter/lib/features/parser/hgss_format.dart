import '../../l10n/game_zh.dart';

const _blockPosition = <int>[
  0, 1, 2, 3, 0, 1, 3, 2, 0, 2, 1, 3, 0, 3, 1, 2, 0, 2, 3, 1, 0, 3, 2, 1, 1, 0, 2, 3, 1, 0, 3, 2,
  2, 0, 1, 3, 3, 0, 1, 2, 2, 0, 3, 1, 3, 0, 2, 1, 1, 2, 0, 3, 1, 3, 0, 2, 2, 1, 0, 3, 3, 1, 0, 2,
  2, 3, 0, 1, 3, 2, 0, 1, 1, 2, 3, 0, 1, 3, 2, 0, 2, 1, 3, 0, 3, 1, 2, 0, 2, 3, 1, 0, 3, 2, 1, 0,
  0, 1, 2, 3, 0, 1, 3, 2, 0, 2, 1, 3, 0, 3, 1, 2, 0, 2, 3, 1, 0, 3, 2, 1, 1, 0, 2, 3, 1, 0, 3, 2,
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
    if (code >= 0xBB && code <= 0xD4) {
      chars.add(String.fromCharCode('A'.codeUnitAt(0) + code - 0xBB));
    } else if (code >= 0xD5 && code <= 0xEE) {
      chars.add(String.fromCharCode('a'.codeUnitAt(0) + code - 0xD5));
    } else if (code >= 0xEF && code <= 0xF8) {
      chars.add(String.fromCharCode('0'.codeUnitAt(0) + code - 0xEF));
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
  });

  final int speciesId;
  final int? level;
  final int? currentHp;
  final int? maxHp;
  final int? experience;
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
  final experience = readUint32(decrypted, 4);

  final stats = _cryptArray(slot.sublist(136, 236), personality);
  // HGSS party stats: level @ +4, max HP @ +6, current HP @ +8.
  final level = stats[4];
  final maxHp = readUint16(stats, 6);
  final currentHp = readUint16(stats, 8);

  final validLevel = level > 0 && level <= 100 ? level : null;
  final validHp = maxHp > 0 && currentHp >= 0 && currentHp <= maxHp + 999
      ? (currentHp: currentHp, maxHp: maxHp)
      : null;

  return PartySlotStats(
    speciesId: speciesId,
    level: validLevel,
    currentHp: validHp?.currentHp,
    maxHp: validHp?.maxHp,
    experience: experience > 0 && experience < 2000000 ? experience : null,
  );
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
