# TitoDex Flutter App

Personal Pokémon journey companion — Flutter implementation.

**Version:** `0.2.25+27` · [GitHub Release](https://github.com/Tito-XD/tito-dex/releases/tag/v0.2.25)

Parent repo docs: [../README.md](../README.md) · [Stack decision](../docs/STACK_DECISION.md) · [Architecture](../docs/ARCHITECTURE.md) · [Dex CDN](../docs/CLOUDFLARE_DEX_CDN.md)

## Quick start

```bash
flutter pub get
flutter test
flutter run -d chrome    # web preview
flutter run              # Android device / emulator
```

## Build release APK (RG handheld)

Same as working 0.2.11 / local 0.2.23: **arm64-v8a only**, ~20 MB, `TitoDex-<ver>-rg-arm64.apk`.

```bash
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk ../releases/TitoDex-<ver>-rg-arm64.apk
```

`android/app/build.gradle.kts`: `compileSdk/targetSdk 36`, `minSdk 24`, `abiFilters arm64-v8a`, release keystore in `android/key.properties`. No `--split-per-abi`.

**Upgrade:** uninstall any locally-built 0.2.x before sideloading (CI keystore ≠ your machine debug key).

Requires Android SDK (`flutter doctor --android-licenses`).

## What works today

| Feature | Status |
| --- | --- |
| Home dashboard | Trainer card, continue + map, party, quick actions, companion sticker |
| DeviceShell + bottom nav | Home / Team / Journey / Dex / Search / Settings |
| Handheld polish | RG square layout, D-pad focus, status icons, typography scale |
| Journey persistence | `shared_preferences` JSON |
| HGSS parser | Retail 512 KB `.sav` — trainer, badges, time, party, map location |
| Save directory sync | Pick folder → auto-load newest `.sav` on startup |
| Emulator launcher | Continue → pick / remember / launch Android emulator app |
| **National dex 1–493** | Browse, search, 4-tab detail (简介 / 基本信息 / 获取 / 招式) |
| Type chart + HGSS moves | Weak/resist/immune, level/TM/egg move sets |
| Offline dex | PokeAPI batch download **or** one-tap **CDN bundle v4** |
| **PNG sprites** | Transparent thumbnails; tap header sprite → fullscreen artwork (lazy CDN/PokeAPI) |
| Settings | Trainer name, save folder, fixture import, journey JSON, dex cache |
| Chinese UI | `lib/l10n/app_zh.dart`, `game_zh.dart`, bundled Nunito |
| Tests | Parser, dex CDN config, save sync, device layout, typography, widget smoke |

## Navigation

| Route | Screen |
| --- | --- |
| `/` | Home |
| `/team` | Party |
| `/journey` | Timeline |
| `/dex` | National dex grid |
| `/dex/:id` | Pokémon detail (4 tabs) |
| `/search` | Search + quick filters |
| `/settings` | Save sync, dex offline, journey tools |

## Dex offline data

Two ways to populate `dex_offline/`:

1. **CDN bundle (recommended on RG)** — Settings → 图鉴离线包 → downloads `bundle.tar.zst` from `dex.tito.cafe`, verifies SHA256, extracts to app documents.
2. **PokeAPI batch** — legacy per-species download with throttle/retry (Settings).

Config defaults in `lib/features/dex/dex_cdn_config.dart`:

```dart
TITODEX_DEX_CDN_BASE=https://dex.tito.cafe
TITODEX_DEX_BUNDLE_URL=https://dex.tito.cafe/v2/bundle.tar.zst
TITODEX_DEX_BUNDLE_VERSION=4
```

Local layout matches CDN bundle (`lib/features/dex/dex_cache_store.dart`):

```txt
dex_offline/
├── manifest.json
├── summaries.json
├── types.json
├── moves.json
├── details/{id}.json
├── sprites/{id}.png      # 220px thumbnails
├── type_icons/{type}.png
└── artwork/{id}.png      # lazy — only after tap-to-zoom
```

## Project layout

```txt
lib/
  app.dart                 # Bootstrap, GoRouter, save sync
  features/
    dex/                   # PokeAPI client, offline cache, CDN installer, artwork
    journey/               # JourneyRepository
    parser/                # HgssParser, map list, Gen IV text/crypto
    save/                  # SaveSyncService, SaveScanner
    trainer/               # Avatar crop / persist
  l10n/                    # Chinese UI + game strings
  models/                  # CurrentJourney, ParsedSaveSummary
  navigation/              # Back stack helpers, page transitions
  pages/                   # home, dex, detail, search, settings, …
  theme/                   # colors, typography, device layout
  widgets/                 # DeviceShell, cards, artwork viewer, …
test/
assets/
  fixtures/PKMSS.sav
  fonts/Nunito-*.ttf
  companion/*.png
```

## Dependencies (highlights)

- `go_router` — navigation
- `shared_preferences` — local storage
- `file_picker` — save directory selection
- `http` — PokeAPI + CDN download
- `zstandard` — bundle.tar.zst decompress
- `image` — PNG sprite processing
- `crypto` — SHA-256 bundle integrity

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

## Not yet implemented

- Custom launcher icon / splash polish
- HeartGold detection, Kanto badges, save dex seen/caught flags
- Single-file `.sav` picker (directory only today)
- Journey cloud sync ([proposal](../docs/CLOUD_SYNC_PROPOSAL.md))
- Capture locations / abilities on dex detail
