# TitoDex Architecture

> **Active stack:** Flutter + Dart in `flutter/`. Capacitor + React under `src/` is a frozen design reference. See [Stack Decision](./STACK_DECISION.md) for migration rationale and current feature status.

## Recommended Stack

**Flutter + Dart** (`flutter/` subdirectory)

| Concern | Choice |
| --- | --- |
| UI | Custom widgets — `DeviceShell`, sticker cards, Nunito via `google_fonts` |
| Routing | `go_router` — shell route + bottom nav |
| Persistence | `shared_preferences` — journey JSON + save-directory config |
| Save parsing | `HgssParser` — retail 512 KB NDS `.sav` |
| Save sync | `SaveSyncService` + `SaveScanner` — directory watch, newest file by mtime |
| File picking | `file_picker` — directory path (not single-file yet) |
| Hashing | `package:crypto` SHA-256 |
| Localization | Static Chinese maps in `lib/l10n/` |

### Legacy reference (Phase 2)

Capacitor + React + TypeScript + Vite — mock UI and tokens in `src/styles/tokens.css`. Not the shipping target.

## Target Devices

| Device | Status |
| --- | --- |
| Android phone / RG Rotate | Primary — `flutter/android/` |
| Linux handheld (future) | `flutter/linux/` scaffold present |
| Web preview | `flutter/web/` — save sync disabled (`dart:io`) |

Constraints:

- lightweight dashboard UI for Unisoc-class hardware
- custom visual language — not Material-default chrome
- **DeviceShell retained** on all form factors
- save access via user-selected directory (SAF-style folder pick), not hard-coded paths

## Architecture Goals

- local first
- Android first (Linux + web follow)
- responsive phone + square layouts
- simple data model
- game-scoped parser (HGSS only for now)
- cloud sync as optional later adapter

## Project Shape

### Flutter (active) — `flutter/`

```txt
flutter/
  lib/
    app.dart                      # Bootstrap, GoRouter, save sync hooks
    main.dart
    features/
      journey/journey_repository.dart
      parser/
        hgss_parser.dart          # Parse + toJourney
        hgss_format.dart          # Gen IV text, party decrypt
        hgss_map_lookup.dart
        hgss_map_list.dart        # Generated map table
      save/
        save_sync_service.dart
        save_scanner.dart
        save_directory_repository.dart
        save_types.dart
    l10n/
      app_zh.dart                 # UI strings
      game_zh.dart                # Location/species zh maps
    models/
      journey.dart
      parsed_save.dart
    pages/
      home_page.dart
      settings_page.dart
    theme/
      tito_colors.dart
      tito_theme.dart
    widgets/
      device_shell.dart
      tito_bottom_nav.dart
      trainer_card.dart
      continue_journey_card.dart
      party_summary.dart
      sticker_card.dart
  test/
    hgss_parser_test.dart
    hgss_map_lookup_test.dart
    save_scanner_test.dart
    widget_test.dart
  assets/fixtures/PKMSS.sav
  android/ linux/ web/
```

Repo-level tooling:

```txt
fixtures/PKMSS.sav
tools/
  probe_hgss_save.py
  generate_hgss_map_list.py
  hgss_map_list.json
```

### React (frozen reference) — `src/`

```txt
src/                    # Phase 2 mock — design reference only
android/                # Capacitor shell (legacy)
package.json
```

## Data Flow

### App bootstrap (`lib/app.dart`)

1. `JourneyRepository.load()` — prefs or `CurrentJourney.mock()`.
2. `SaveSyncService.syncOnStartup()` — if auto-load enabled and directory set, parse newest `.sav`.
3. If sync updated journey → persist.
4. Render `HomePage` with current journey.

### Save directory sync

```txt
User picks directory (Settings)
  → SaveDirectoryRepository persists path + auto-load flag
  → SaveScanner.findNewestSave() — recursive, 524288-byte .sav only
  → skip if same path+mtime (unless force)
  → HgssParser.parseSummary() → toJourney(existing: …)
  → JourneyRepository.save()
```

### Journey model highlights

- `trainerName` — display name (may be customized)
- `saveTrainerName` — raw decoded OT from last parse
- `trainerNameCustomized` — when true, re-import preserves display name
- `timeline`, `party`, `location`, `badges`, `playTime` — from mock or parser

## Data Layers

### 1. Mock seed

`CurrentJourney.mock()` — Chinese SoulSilver template on first launch.

### 2. Local journey store

`JourneyRepository` — JSON in `shared_preferences`.

Helpers on `HgssParser`: `encodeJourneyJson` / `decodeJourneyJson` (export/import UI not wired yet).

### 3. Save parser adapter

`ParsedSaveSummary` → `toJourney()` merges into `CurrentJourney`.

**Limitations today:**

- SoulSilver only; game string hardcoded
- Johto badges only (Kanto `0x83` not read)
- Timeline replaced on import (merge TODO)
- Partial Gen IV charset; ASCII trainer names only decode cleanly
- Retail 524 288 bytes only

See `PARSER_PROPOSAL.md` for full boundary.

### 4. Cloud sync adapter

Not implemented. See `CLOUD_SYNC_PROPOSAL.md`.

## UI Routing

| Route | Screen | Status |
| --- | --- | --- |
| `/` | Home — trainer, continue, party, timeline | ✅ |
| `/team` | Team | Placeholder |
| `/journey` | Journey | Placeholder |
| `/settings` | Trainer, save folder, journey snapshot | ✅ |

React mock also had `/dex` and `/search` — not ported yet.

**Continue button:** opens bottom sheet stub; emulator launch is Phase B.

## Responsive Strategy

- `DeviceShell` wraps all routes
- `ListView` / `Column` home layout; grid dashboard on wider viewports
- `SafeArea` for notches and system bars
- Test at 360×780 phone and 720×720 square (RG Rotate)

## Native Boundaries

| Adapter | Location | Notes |
| --- | --- | --- |
| Journey prefs | `journey_repository.dart` | |
| Save directory prefs | `save_directory_repository.dart` | |
| Directory pick | `file_picker` in `app.dart` | |
| Save file read | `save_sync_service.dart` | `dart:io` — not on web |
| Parser | `hgss_parser.dart` | pure Dart |

## Testing

```bash
cd flutter && flutter test
```

| Test | Covers |
| --- | --- |
| `hgss_parser_test.dart` | Full PKMSS fixture |
| `hgss_map_lookup_test.dart` | Map ID 76 → 满金市, trainer name preservation |
| `save_scanner_test.dart` | Newest-by-mtime, size filter |
| `widget_test.dart` | App boot loading shell |

Manual: Settings import, directory sync on Android device with emulator save folder.

## Related Documents

- [Stack Decision](./STACK_DECISION.md) — status table, gaps, decision log
- [Flutter README](../flutter/README.md) — dev quick start
- [Parser Proposal](./PARSER_PROPOSAL.md) — HGSS offsets and limits
- [Design System](./DESIGN_SYSTEM.md) — tokens ported to `tito_colors.dart`
