# TitoDex Flutter App

Flutter implementation of the TitoDex journey companion. Parent repo: [../README.md](../README.md).

**Latest release:** `0.6.2.1+73` / `0.6.2.1-offline+74` · [GitHub Release v0.6.2.1](https://github.com/Tito-XD/tito-dex/releases/tag/v0.6.2.1)

**Current `main` package version:** `0.6.2+73`

**AI / agent context:** [../docs/AI_CONTEXT.md](../docs/AI_CONTEXT.md)

## Quick start

```bash
flutter pub get
flutter test          # 187 tests
flutter run           # Android device / emulator
flutter run -d chrome # web preview (limited)
```

## Release APK (RG handheld)

arm64-v8a only, approximately 23 MB for the standard APK, SDK 36.

```bash
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk ../releases/TitoDex-<ver>-rg-arm64.apk
../tools/verify_release_apk.sh ../releases/TitoDex-<ver>-rg-arm64.apk
```

Checklist: [../docs/RELEASE_BUILD.md](../docs/RELEASE_BUILD.md). Uninstall local debug builds before sideloading CI APK.

## Features

| Area | Notes |
| --- | --- |
| Home / Team / Journey | Trainer card, party, timeline, emulator continue |
| Save import | One selected `.sav`; experimental Gen 1–7 metadata; richer fixture-verified HGSS party/map/dex parsing |
| Android handoff | Native installed-app picker and emulator/game launcher |
| Companion | Configurable standby Pokémon, six-slot party card, shiny surprise, silhouette quiz |
| Dex 1–1025 | Grid, search, 4-tab detail, 23 editions, regional scope |
| Offline pack | Settings → CDN bundle; l10n/maps/config; update prompts |
| Search hub | Structured reference + battle tools; reference → dex filters |
| UI | Chinese (`lib/l10n/`), DeviceShell, Nunito, RG layout |

## Navigation

| Route | Screen |
| --- | --- |
| `/` | Home |
| `/team`, `/journey` | Party, timeline |
| `/dex`, `/dex/:id` | Grid, detail |
| `/dex/moves`, `/dex/abilities` | Encyclopedias |
| `/search` | Search + hub |
| `/search/companion/*` | Type matchup, stat calc, damage |
| `/settings` | Save, offline pack, journey tools |

## Offline dex layout

After installing the CDN bundle (`dex_offline/`):

```txt
manifest.json, summaries.json, moves.json, abilities.json, …
l10n/zh/          # Chinese labels (preferred over APK assets)
maps/, config/    # HGSS map list, app config
details/, sprites/, type_icons/, game_icons/
```

Config: compile-time env in `lib/features/dex/dex_cdn_config.dart` (not shown in UI).

## Project layout

```txt
lib/
  app.dart
  features/dex/       # offline, CDN, filters, updates
  features/parser/    # HgssParser
  features/save/      # SaveSyncService
  features/companion/ # battle tools
  config/             # AppConfig (Sleep links, etc.)
  l10n/
  pages/
  widgets/
test/
assets/
  fixtures/PKMSS.sav
  l10n/zh/            # APK fallback catalog
  config/
  companion/
```

## Dependencies (highlights)

`go_router`, `shared_preferences`, `file_picker`, `http`, `zstandard`, `image`, `crypto`

## Not yet / partial

- Custom launcher icon / splash  
- HeartGold detection; single-file `.sav` picker  
- Full competitive damage/IV workflows and usage rankings
- Journey cloud sync  

Parser details: [../docs/PARSER_PROPOSAL.md](../docs/PARSER_PROPOSAL.md)
