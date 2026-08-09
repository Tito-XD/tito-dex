# Save Parser Proposal

## Purpose

The save parser helps TitoDex continue Tito's current journey. It is not a save editor and not a multi-generation parser framework.

**Implementation:** `flutter/lib/features/parser/hgss_parser.dart` and `pokemon_save_parser.dart` (Dart). The removed React/TypeScript prototype is historical and has no active parser stub.

## Fixture

| Path | Role |
| --- | --- |
| `flutter/assets/fixtures/PKMSS.sav` | Bundled asset; `flutter test`; Settings → 导入内置 PKMSS.sav |
| `fixtures/PKMSS.sav` | Repo root; `tools/probe_hgss_save.py` |

| Property | Value |
| --- | --- |
| Size | 524 288 bytes |
| Game | Pokémon SoulSilver |
| Verified output | Trainer `ETeZ`, TID `22813`, 3 badges, `7:03:41`, 满金市 (map 76), Quilava Lv27 |

Run tests:

```bash
cd flutter && flutter test test/hgss_parser_test.dart
```

Probe from repo root:

```bash
python3 tools/probe_hgss_save.py fixtures/PKMSS.sav
```

## Active Partition Selection

HGSS retail saves are 524 288 bytes — two `0x40000` partitions. The parser reads the save counter at `0xF618` in each partition and picks the newer block (`HgssParser._activePartition`).

## Parsed Fields (implemented)

Offsets relative to **active partition base**:

| Field | Offset | Format | Output field |
| --- | --- | --- | --- |
| Trainer name (OT) | `0x64`–`0x73` | Gen IV u16 text | `trainerName` |
| Trainer ID | `0x74` | u16 | `tid` |
| Secret ID | `0x76` | u16 | `secretId` |
| Money / trainer gender / language | `0x78`–`0x7D` | u32 + u8 + u8 | journey save metadata |
| Johto badges | `0x7E` | u8 bitmask | combined `badges` count |
| Kanto badges | `0x83` | u8 bitmask | combined `badges` count; `maxBadges=16` |
| Game version | `0x80` | u8 | HeartGold (`7`) / SoulSilver |
| Play time | `0x86`–`0x89` | u16 h, u8 m, u8 s | `playTime` string |
| Party count | `0x94` | u8 | loop bound |
| Party slots | `0x98` + 236×n | encrypted struct | `party[]` |
| Starter species | `0xE44` | u16 | `starterSpeciesId` |
| Map header ID | `0x1234` | u16 | `mapHeaderId` → `locationLabel` |
| Player map X / Y / Z | `0x236E`, `0x2372`, `0x2376` | u16 × 3 | `mapCoordinates` |
| Money held by mother | `0xC0D8` | u32 | `motherMoney` |
| Adventure start / League champion time | `0x34`, `0x3C` | seconds since 2000-01-01 | nullable UTC dates |
| Pokédex flags | small block | bit fields | complete seen / caught ID sets |
| Full file | — | SHA-256 | `saveHash` |

Party decryption (`hgss_format.dart`) now reads:

- personality / checksum block shuffle + Gen IV LCG encryption
- species, nickname, held item, OT IDs, EXP, friendship and ability
- four moves with current PP and PP Ups
- nature, shiny state, gender, egg/form flags, IVs and EVs
- level, current/max HP, status, Attack/Defense/Speed/Sp. Atk/Sp. Def from the party-only battle block
- invalid party count is capped at six with an explicit warning

Location (`hgss_map_lookup.dart` + `hgss_map_list.dart`):

- Map list generated from Project Pokémon data (`tools/generate_hgss_map_list.py`)
- English label → Chinese via `game_zh.dart` (`localizeLocation`)

## Intentionally Not Yet Parsed

| Field | Offset | Notes |
| --- | --- | --- |
| PC boxes | big block from `0xF700` | Requires independently verified big-block selection/checksum handling and more real-save fixtures; do not guess from the small-block active partition |
| Bag pocket UI sync | `0x644` onward | Documented, but not yet useful enough to add to Journey; held items are already synchronized per party member |
| Archive containers | — | Zip backups must be extracted before import |

## Parser Boundary (Dart)

```dart
class HgssParser {
  bool canParse(Uint8List bytes);          // length == 524288
  ParsedSaveSummary parseSummary(Uint8List bytes);
  CurrentJourney toJourney(ParsedSaveSummary summary, {CurrentJourney? existing});
}
```

`ParsedSaveSummary` includes `warnings[]` for partial/degraded fields.

## toJourney Merge Rules

| Rule | Status |
| --- | --- |
| Preserve `trainerName` when `trainerNameCustomized` | ✅ implemented + tested |
| Set `saveTrainerName` from parsed OT | ✅ |
| Localize species / location to Chinese | ✅ |
| **Preserve existing `timeline` entries** | ✅ `_mergeTimeline` keeps manual entries and prepends one “synced from save” entry |
| Preserve `nextReminder` from user | ✅ kept when already set |

Merge behavior: structured fields (location, badges, party, time) come from the parser; a `parsed-<hash8>` timeline entry is prepended; manual notes and the user `nextReminder` are preserved.

## Save Ingest Paths

| Path | Entry | Status |
| --- | --- | --- |
| Settings → import bundled fixture | `rootBundle` → parse → persist | ✅ |
| Settings → pick one save file | Persisted document URI | ✅ |
| Startup auto-load | `SaveSyncService.syncOnStartup` | ✅ |
| Single `.sav` file pick | SAF `ACTION_OPEN_DOCUMENT` | ✅ implemented |
| User drops file into app | — | ❌ |

Single-file sync (`save_sync_service.dart`) re-reads only the persisted document URI, skips an unchanged hash unless forced, parses and merges the result, and stores the last-loaded metadata in preferences.

**Platform note:** uses `dart:io` — works on Android/desktop, not Flutter web.

## Emulator Format Detection

Before parsing unknown files:

| Signal | Action |
| --- | --- |
| `PK` magic | Zip backup — extract inner `.sav` first |
| 524 288 bytes | Try `HgssParser.canParse` |
| `DeSmuME Save` footer after the 512 KiB payload | Strip DeSmuME wrapper |
| Other sizes | Reject with `unsupported_save` message |

## Parser UX (implemented / planned)

| State | UX |
| --- | --- |
| Parsed OK | Snackbar with trainer + party count |
| Partial warnings | Snackbar notes warning count |
| No directory | Settings hint + snackbar on sync |
| No `.sav` found | Snackbar |
| Unchanged save | Snackbar “unchanged” |
| Unsupported size | Snackbar |

## Non-Goals

- all-generation parser framework
- full save editing
- PC box management
- emulator memory reading
- OCR
- automatic emulator launch (separate Continue feature)

## Research References

- [Project Pokémon — HGSS save structure](https://projectpokemon.org/home/docs/gen-4/hgss-save-structure-r76/)
- [Bulbapedia — Generation IV save structure](https://bulbapedia.bulbagarden.net/wiki/Save_data_structure_(Generation_IV))
- `tools/probe_hgss_save.py` — quick CLI validation
- `tools/hgss_map_list.json` — map ID source data

## Maintenance

After offset or decrypt changes:

1. `cd flutter && flutter test`
2. `python3 tools/probe_hgss_save.py fixtures/PKMSS.sav`
3. Manual import on device if party/location regress
