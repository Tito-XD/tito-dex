import 'dart:typed_data';

/// National dex count for HGSS (Gen IV).
const hgssNationalDexCount = 493;

/// HGSS retail save Pokédex flag offsets (active general block, partition-relative).
const hgssPokedexOwnedOffset = 0x12BC;
const hgssPokedexSeenOffset = 0x12FC;
const hgssPokedexFlagBytes = 62;

/// Parses national dex #1–493 caught/seen bitmasks from an HGSS general block slice.
class HgssPokedexFlags {
  const HgssPokedexFlags({
    required this.caughtIds,
    required this.seenIds,
  });

  final Set<int> caughtIds;
  final Set<int> seenIds;

  static HgssPokedexFlags fromPartition(Uint8List partition) {
    if (partition.length < hgssPokedexSeenOffset + hgssPokedexFlagBytes) {
      return const HgssPokedexFlags(caughtIds: {}, seenIds: {});
    }

    final caught = _parseFlagBytes(
      partition,
      hgssPokedexOwnedOffset,
      hgssPokedexFlagBytes,
    );
    final seen = _parseFlagBytes(
      partition,
      hgssPokedexSeenOffset,
      hgssPokedexFlagBytes,
    );

    // Caught implies seen in UI even if the seen bit is unset.
    seen.addAll(caught);

    return HgssPokedexFlags(caughtIds: caught, seenIds: seen);
  }

  static Set<int> _parseFlagBytes(
    Uint8List partition,
    int offset,
    int length,
  ) {
    final ids = <int>{};
    for (var index = 0; index < hgssNationalDexCount; index++) {
      final byteIndex = index ~/ 8;
      if (byteIndex >= length) {
        break;
      }
      final bit = index % 8;
      if ((partition[offset + byteIndex] & (1 << bit)) != 0) {
        ids.add(index + 1);
      }
    }
    return ids;
  }
}
