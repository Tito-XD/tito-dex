# TitoDex Flutter App

Flutter implementation of the TitoDex journey companion. Parent repo: [../README.md](../README.md).

**Latest release:** `0.9.18+204` / `0.9.18-offline+205` · [GitHub Release v0.9.18](https://github.com/Tito-XD/tito-dex/releases/tag/v0.9.18)

**Current `main` package version:** `0.9.18+204`

**AI / agent context:** [../docs/AI_CONTEXT.md](../docs/AI_CONTEXT.md)
## Quick start

```bash
flutter pub get
flutter test          # regression gate
flutter run           # Android device / emulator
flutter run -d chrome # web preview (limited)
```

## Release APK (RG handheld)

Arm64 Flutter runtime, SDK 36. Published v0.9.18 is 29.13 MB Lite / 95.25 MB Offline; small plugin helpers may include other ABIs. Verify contents and signatures rather than relying on a fixed size.

```bash
flutter build apk --release --target-platform android-arm64
cp build/app/outputs/flutter-apk/app-release.apk ../releases/TitoDex-<ver>-lite-rg-arm64.apk
../tools/verify_release_apk.sh ../releases/TitoDex-<ver>-lite-rg-arm64.apk
```

Checklist: [../docs/RELEASE_BUILD.md](../docs/RELEASE_BUILD.md). If a debug signature conflicts, export needed local data before removing that debug install. Normal v0.8.13+ release upgrades preserve data. Contribution checks: [CONTRIBUTING.md](../docs/CONTRIBUTING.md).

## Features

| Area | Notes |
| --- | --- |
| Home / Team / Journey | Trainer/location and completion grids, merged Team overview, collapsible member details, timeline and emulator continue |
| Save import | One selected `.sav`; experimental Gen 1–7 metadata; richer fixture-verified HGSS party/map/dex parsing |
| Android handoff | Native installed-app picker and emulator/game launcher |
| App shortcuts | Long-press launcher icon; defaults to Dex + Search, with up to three configurable dex/reference/tool destinations |
| Companion | Configurable standby Pokémon, six-slot party card, shiny surprise, silhouette quiz |
| Dex 1–1025 | Grid, search, 4-tab detail, 23 editions, regional scope |
| Offline pack | Settings → CDN bundle; l10n/maps/config; update prompts |
| Search hub | Query-first search; reference catalog; battle calculator shell |
| Pokémon Sleep | Offline sleep-score and basic cooking-strength estimates; pinned Neroli’s Lab formulas with bundled Apache-2.0 notices |
| Ask TitoDex | Existing structured resources first, reverse filters, bounded online fallback, leading props and answer-start scroll |
| Updates / introduction | Verified matching-variant APK updates; first-run name/avatar guide; named pinned Home shortcut |
| UI | Chinese/English following system (`lib/l10n/`), three themes, DeviceShell, Nunito, RG layout |

## Navigation

| Route | Screen |
| --- | --- |
| `/` | Home |
| `/team`, `/journey` | Party, timeline |
| `/journey/ask` | Ask TitoDex conversation |
| `/dex/quiz` | Silhouette quiz |
| `/search/reference/json` | Structured reference detail |
| `/dex`, `/dex/:id` | Grid, detail |
| `/dex/moves`, `/dex/abilities` | Encyclopedias |
| `/dex/locations` | Version-scoped location dex and caught completion |
| `/search` | Search |
| `/search/reference` | Quick-reference catalog (moves, items, Sleep, …) |
| `/search/companion` | Battle calc (matchup / stats / damage / blind-spot) |
| `/search/sleep-tools` | Sleep score and basic cooking-strength estimates |
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
  features/app_update/ # GitHub release checks and APK downloads
  features/onboarding/ # first-run eligibility
  features/app_shortcuts/ # launcher shortcuts
  features/extensions/ # reviewed and structured Q&A
  features/dex/       # offline, CDN, filters, data updates
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
  companion_media/
```

## Dependencies (highlights)

`go_router`, `shared_preferences`, `file_picker`, `http`, `zstandard`, `image`, `crypto`

## Not yet / partial

- Full competitive damage/IV workflows and usage rankings
- Real-save fixtures beyond HGSS

Cloud sync is intentionally out: TitoDex stays local-first (journey JSON import/export covers portability).

Parser details: [../docs/PARSER_PROPOSAL.md](../docs/PARSER_PROPOSAL.md)
