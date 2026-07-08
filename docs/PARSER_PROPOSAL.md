# Save Parser Proposal

## Purpose

The save parser should help TitoDex continue Tito's current journey. It is not a save editor and not a complete all-generation parser project.

The first parser target is **HGSS** (HeartGold / SoulSilver) because TitoDex starts with SoulSilver context and a real fixture is available.

## Fixture

| File | `src/PKMSS.sav` |
| --- | --- |
| Size | 524 288 bytes (standard NDS retail HGSS `.sav`) |
| Game | Pokémon SoulSilver (from filename; confirm in parser via version bytes if needed) |
| Use | Unit tests, offset validation, manual probe scripts |

**Planned path:** `fixtures/saves/PKMSS.sav` when the Flutter `test/` tree exists.

### Early validation (block 0, Gen IV small-block offsets)

Probe scripts should confirm these fields before the Dart parser ships:

| Field | Offset | Format |
| --- | --- | --- |
| Trainer name (OT) | `0x64` | 8 × u16, Gen IV character table |
| Trainer ID | `0x74` | u16 |
| Secret ID | `0x76` | u16 |
| Johto badges | `0x7E` | u8 bitmask |
| Kanto badges | `0x83` | u8 bitmask |
| Play time | `0x86`–`0x89` | u16 hours, u8 min, u8 sec |
| Party count | `0x94` | u8 |

**Important:** HGSS stores two save blocks. The parser must determine which block is current (footer checksum / save counter) before reading fields. Do not assume block 0 is always active.

References:

- [Project Pokémon — HGSS save structure](https://projectpokemon.org/home/docs/gen-4/hgss-save-structure-r76/)
- [Bulbapedia — Generation IV save structure](https://bulbapedia.bulbagarden.net/wiki/Save_data_structure_(Generation_IV))

### Emulator formats

Before parsing, classify the input:

| Signal | Meaning |
| --- | --- |
| `50 4B 03 04` (PK…) | Zip backup — extract first |
| 524 288 bytes, raw | Likely retail NDS `.sav` |
| Tail `|-DESMUME SAVE-|` | DeSmuME `.dsv` wrapper |
| DraStic / melonDS | May use different wrappers — document per source |

## Parser Principle

Parse only what the companion app needs first:

- current game
- trainer name if practical
- play time
- badges
- current location (when mapping exists)
- party summary
- save hash
- updated time / parsed time

Avoid implementing full Pokémon structures, full box editing, or all-generation support at the beginning.

## Proposed Parser Boundary

Dart target (TypeScript reference in Phase 2 `parserTypes.ts`):

```dart
abstract class SaveParser {
  String get gameId;
  Future<bool> canParse(Uint8List input);
  Future<ParsedSaveSummary> parseSummary(Uint8List input);
}

class ParsedSaveSummary {
  final String game;
  final String? trainerName;
  final String? playTime;
  final int? badges;
  final String? location;
  final List<ParsedPartyMember>? party;
  final String saveHash;
  final DateTime parsedAt;
  final List<String> warnings;
}
```

Partial data with explicit `warnings` is better than a broad, fragile parser.

## First Implementation Target

```txt
lib/features/parser/hgss_parser.dart
test/parser/hgss_parser_test.dart
```

Phase 2 stub (reference only): `src/features/parser/hgssParser.ts`

## Save Hash

Every parsed save should produce a hash. The hash is useful for:

- detecting changes
- avoiding duplicate backups
- sync conflict checks
- identifying which metadata belongs to which save snapshot

Use SHA-256 via `package:crypto` in Dart.

## Local File Access

Android flow (Flutter):

1. Tito selects a `.sav` file via Storage Access Framework (`file_picker` or equivalent).
2. TitoDex reads bytes locally — no upload required.
3. TitoDex computes hash and parses summary metadata.
4. TitoDex merges structured fields into the local journey store.
5. Manual timeline notes are preserved unless Tito confirms overwrite.
6. Optional cloud sync backs up metadata and the `.sav` file later.

## Parser UX

The UI should clearly communicate parser confidence:

- parsed successfully
- partial parse
- unsupported save
- modified/unknown format
- backup recommended

Do not silently overwrite user-entered journey notes with parser results. Parser data should update structured fields while preserving Tito's manual journey log.

## Non-Goals

Do not start with:

- all-generation parser framework
- full save editing
- complete Pokémon party internals (EVs, IVs, ribbons)
- PC box management
- emulator memory reading
- automatic emulator launch (launcher is separate — see Stack Decision Continue flow)
- OCR

## Research Notes

- Use `src/PKMSS.sav` as the primary fixture; add anonymized alternates if needed.
- Document verified offsets in code comments with source links.
- Run `flutter test test/parser/` before merging parser changes.
- Location mapping may require a separate HGSS map ID → name table; OK to omit in v1 and leave `location` null with a warning.
