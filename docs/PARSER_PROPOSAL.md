# Save Parser Proposal

## Purpose

The save parser helps TitoDex continue Tito's current journey. It is not a save editor and not a multi-generation parser framework.

**Implementation:** `flutter/lib/features/parser/hgss_parser.dart` (Dart). Phase 2 TypeScript stub `src/features/parser/hgssParser.ts` remains a null placeholder.

## Fixture

| Path | Role |
| --- | --- |
| `flutter/assets/fixtures/PKMSS.sav` | Bundled asset; `flutter test`; Settings → 导入内置 PKMSS.sav |
| `fixtures/PKMSS.sav` | Repo root; `tools/probe_hgss_save.py` |
| `src/PKMSS.sav` | Legacy upload path |

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
| Johto badges | `0x7E` | u8 bitmask | `badges` (popcount) |
| Play time | `0x86`–`0x89` | u16 h, u8 m, u8 s | `playTime` string |
| Party count | `0x94` | u8 | loop bound |
| Party slots | `0x98` + 236×n | encrypted struct | `party[]` |
| Map header ID | `0x1234` | u16 | `mapHeaderId` → `locationLabel` |
| Full file | — | SHA-256 | `saveHash` |

Party decryption (`hgss_format.dart`):

- Personality / checksum shuffle + AES-like crypt
- Level from decrypted stats block offset `0x8C` (not met level `0x84`)
- Level > 100 → warning, level nulled (empty slot)

Location (`hgss_map_lookup.dart` + `hgss_map_list.dart`):

- Map list generated from Project Pokémon data (`tools/generate_hgss_map_list.py`)
- English label → Chinese via `game_zh.dart` (`localizeLocation`)

## Not Yet Parsed

| Field | Offset | Notes |
| --- | --- | --- |
| Kanto badges | `0x83` | Documented in probe script; not in Dart parser |
| HeartGold vs SoulSilver | — | Game hardcoded `SoulSilver` |
| Nicknames, moves, IVs, PC boxes | — | Out of scope |
| Non-retail formats | — | DeSmuME `.dsv`, zip backups — classify first |

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
| **Preserve existing `timeline` entries** | ❌ **TODO** — currently replaces with single parsed entry |
| Preserve `nextReminder` from user | ❌ overwrites with default zh string |

When fixing timeline merge: update structured fields (location, badges, party, time) from parser; append or update a “synced from save” entry; do not delete manual notes.

## Save Ingest Paths

| Path | Entry | Status |
| --- | --- | --- |
| Settings → import bundled fixture | `rootBundle` → parse → persist | ✅ |
| Settings → pick one save file | Persisted document URI | ✅ |
| Startup auto-load | `SaveSyncService.syncOnStartup` | ✅ |
| Single `.sav` file pick | SAF file mode | ❌ planned |
| User drops file into app | — | ❌ |

Directory sync (`save_sync_service.dart`):

1. Recursively scan for `.sav` files of exactly 524 288 bytes.
2. Pick newest by modification time.
3. Skip if same path + mtime as last sync (unless forced).
4. Parse and persist; store last-loaded metadata in prefs.

**Platform note:** uses `dart:io` — works on Android/desktop, not Flutter web.

## Emulator Format Detection

Before parsing unknown files:

| Signal | Action |
| --- | --- |
| `PK` magic | Zip backup — extract inner `.sav` first |
| 524 288 bytes | Try `HgssParser.canParse` |
| `|-DESMUME SAVE-|` tail | Strip DeSmuME wrapper |
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
