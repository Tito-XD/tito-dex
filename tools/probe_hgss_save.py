#!/usr/bin/env python3
"""Quick HGSS save probe — validates retail .sav and prints journey metadata."""

from __future__ import annotations

import struct
import sys
from pathlib import Path

PARTITION_SIZE = 0x40000
SAVE_COUNT_OFFSET = 0xF618
JOHTO_BADGE_NAMES = [
    "Zephyr",
    "Hive",
    "Plain",
    "Fog",
    "Storm",
    "Mineral",
    "Glacier",
    "Rising",
]

BLOCK_POSITION = [
    0, 1, 2, 3, 0, 1, 3, 2, 0, 2, 1, 3, 0, 3, 1, 2, 0, 2, 3, 1, 0, 3, 2, 1, 1, 0, 2, 3, 1, 0, 3, 2,
    2, 0, 1, 3, 3, 0, 1, 2, 2, 0, 3, 1, 3, 0, 2, 1, 1, 2, 0, 3, 1, 3, 0, 2, 2, 1, 0, 3, 3, 1, 0, 2,
    2, 3, 0, 1, 3, 2, 0, 1, 1, 2, 3, 0, 1, 3, 2, 0, 2, 1, 3, 0, 3, 1, 2, 0, 2, 3, 1, 0, 3, 2, 1, 0,
    0, 1, 2, 3, 0, 1, 3, 2, 0, 2, 1, 3, 0, 3, 1, 2, 0, 2, 3, 1, 0, 3, 2, 1, 1, 0, 2, 3, 1, 0, 3, 2,
]

SPECIES = {
    63: "Abra",
    96: "Drowzee",
    155: "Cyndaquil",
    156: "Quilava",
    157: "Typhlosion",
    175: "Togepi",
    176: "Togetic",
    447: "Riolu",
    448: "Lucario",
}


def decode_gen4_name(buf: bytes) -> str:
    chars: list[str] = []
    for i in range(0, len(buf), 2):
        code = struct.unpack_from("<H", buf, i)[0]
        if code == 0xFFFF:
            break
        if 0xBB <= code <= 0xD4:
            chars.append(chr(ord("A") + code - 0xBB))
        elif 0xD5 <= code <= 0xEE:
            chars.append(chr(ord("a") + code - 0xD5))
        elif 0xEF <= code <= 0xF8:
            chars.append(chr(ord("0") + code - 0xEF))
        else:
            chars.append(f"[{code:04x}]")
    return "".join(chars)


def crypt_array(data: bytes, seed: int) -> bytes:
    out = bytearray(data)
    for i in range(0, len(out), 2):
        seed = (0x41C64E6D * seed + 0x6073) & 0xFFFFFFFF
        xor = (seed >> 16) & 0xFFFF
        value = struct.unpack_from("<H", out, i)[0] ^ xor
        struct.pack_into("<H", out, i, value)
    return bytes(out)


def shuffle_blocks(data: bytes, sv: int) -> bytes:
    blocks = [bytearray(data[i * 32 : (i + 1) * 32]) for i in range(4)]
    perm = list(range(4))
    slot_of = list(range(4))
    order = BLOCK_POSITION[sv * 4 : sv * 4 + 4]
    for i in range(3):
        desired = order[i]
        j = slot_of[desired]
        if j == i:
            continue
        blocks[i], blocks[j] = blocks[j], blocks[i]
        block_at_i = perm[i]
        perm[j] = block_at_i
        slot_of[block_at_i] = j
    return b"".join(blocks)


def decrypt_party_slot(raw: bytes) -> tuple[int, int]:
    personality = struct.unpack_from("<I", raw, 0)[0]
    checksum = struct.unpack_from("<H", raw, 6)[0]
    sv = (personality >> 13) & 31
    encrypted = crypt_array(raw[8:136], checksum)
    decrypted = shuffle_blocks(encrypted, sv)
    species = struct.unpack_from("<H", decrypted, 0)[0]
    level = raw[0x84]
    return species, level


def active_partition(data: bytes) -> int:
    counts = [
        struct.unpack_from("<I", data, block * PARTITION_SIZE + SAVE_COUNT_OFFSET)[0]
        for block in (0, 1)
    ]
    return 1 if counts[1] >= counts[0] else 0


def probe(path: Path) -> None:
    data = path.read_bytes()
    if len(data) != 524288:
        print(f"Unexpected size: {len(data)} bytes (expected 524288)")
        sys.exit(1)

    block = active_partition(data)
    base = block * PARTITION_SIZE
    name = decode_gen4_name(data[base + 0x64 : base + 0x74])
    tid = struct.unpack_from("<H", data, base + 0x74)[0]
    johto = data[base + 0x7E]
    badges = [JOHTO_BADGE_NAMES[i] for i in range(8) if johto & (1 << i)]
    hours = struct.unpack_from("<H", data, base + 0x86)[0]
    minutes = data[base + 0x88]
    seconds = data[base + 0x89]
    party_count = data[base + 0x94]
    map_id = struct.unpack_from("<H", data, base + 0x1234)[0]

    print(f"File: {path.name}")
    print(f"Format: HGSS retail 512 KB")
    print(f"Active partition: {block}")
    print(f"Trainer: {name}")
    print(f"TID: {tid}")
    print(f"Johto badges ({len(badges)}/8): {', '.join(badges) or '(none)'}")
    print(f"Play time: {hours}:{minutes:02d}:{seconds:02d}")
    print(f"Map header id: {map_id}")
    print(f"Party ({party_count}):")
    for index in range(party_count):
        slot = data[base + 0x98 + index * 236 : base + 0x98 + (index + 1) * 236]
        species, level = decrypt_party_slot(slot)
        label = SPECIES.get(species, f"Species #{species}")
        warn = " (suspicious level)" if level > 100 else ""
        print(f"  {index + 1}. {label} Lv{level}{warn}")


if __name__ == "__main__":
    target = Path(sys.argv[1] if len(sys.argv) > 1 else "fixtures/PKMSS.sav")
    probe(target)
