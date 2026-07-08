# TitoDex Flutter App

Personal Pokémon journey companion — Flutter implementation.

Parent repo docs: [../README.md](../README.md) · [Stack decision](../docs/STACK_DECISION.md) · [Architecture](../docs/ARCHITECTURE.md)

## Quick start

```bash
flutter pub get
flutter test
flutter run -d chrome    # web
flutter run              # Android (from flutter/android/)
```

## What works today

| Feature | Status |
| --- | --- |
| Home dashboard | Trainer card, continue card, party, timeline, reminder |
| DeviceShell + bottom nav | Home / Team / Journey / Settings |
| Journey persistence | `shared_preferences` JSON |
| HGSS parser | Retail 512 KB `.sav` — trainer, badges, time, party, map location |
| Save directory sync | Pick folder → auto-load newest `.sav` on startup |
| Settings | Trainer display name, save folder, fixture import, reset mock |
| Chinese UI | `lib/l10n/app_zh.dart`, `game_zh.dart` |
| Tests | Parser fixture, map lookup, save scanner, app boot smoke |

## Not yet implemented

- Continue → launch emulator app (bottom sheet is a stub)
- Team / Journey page content (placeholders)
- Dex / Search screens (React mock had these; Flutter uses Settings in nav)
- Custom splash / launcher icon / Android back stack polish
- Journey JSON export/import UI
- Full manual editing of location, badges, play time in Settings
- HeartGold detection, Kanto badges, per-file SAF picker
- Cloud sync

## Project layout

```txt
lib/
  app.dart                 # Bootstrap, router, save sync orchestration
  main.dart
  features/
    journey/               # JourneyRepository
    parser/                # HgssParser, map list, Gen IV text/crypto
    save/                  # SaveSyncService, SaveScanner, directory prefs
  l10n/                    # Chinese UI + game strings
  models/                  # CurrentJourney, ParsedSaveSummary
  pages/                   # home_page, settings_page
  theme/                   # tito_colors, tito_theme
  widgets/                 # device_shell, cards, bottom nav
test/                      # hgss_parser_test, save_scanner_test, …
assets/fixtures/PKMSS.sav
```

## Dependencies

- `go_router` — navigation
- `shared_preferences` — local storage
- `file_picker` — save directory selection
- `crypto` — SHA-256 save hash
- `google_fonts` — Nunito

## Save sync flow

1. User picks a directory in Settings (e.g. emulator save folder).
2. `SaveScanner` recursively finds `.sav` files of exactly 524 288 bytes.
3. Newest file by modification time is parsed.
4. If path + mtime unchanged since last sync, skip (unless forced).
5. `HgssParser.toJourney()` updates home screen; customized trainer name is preserved.

## Parser notes

See [Parser proposal](../docs/PARSER_PROPOSAL.md). Run `flutter test test/hgss_parser_test.dart` after parser changes.

Probe script (repo root):

```bash
python3 ../tools/probe_hgss_save.py ../fixtures/PKMSS.sav
```
