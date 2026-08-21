[简体中文](README.md) | **English**

# TitoDex

**TitoDex** is a warm, offline-first Pokémon **journey companion** for Android handhelds and phones. It brings save progress, team and journey management, a 1–1025 Pokédex, Chinese reference data, and lightweight battle utilities into one compact, device-like interface.

It is designed to make returning to a playthrough feel immediate: see where the journey paused, check the current team, and open the right reference tool without losing the character of a dedicated trainer device. TitoDex does not try to replace a full community wiki or competitive simulator.

| Channel | Version | Notes |
| --- | --- | --- |
| Lite APK | [v0.8.18](https://github.com/Tito-XD/tito-dex/releases/tag/v0.8.18) · App `0.8.18+170` | Streamed verified answers, polished chat UI, and local history management |
| Offline APK | [v0.8.18](https://github.com/Tito-XD/tito-dex/releases/tag/v0.8.18) · App `0.8.18-offline+171` | Embeds compact v14 Dex data and Journey Assistant |
| Journey Assistant | Built in | Connection details, 50 local Q&A pairs, companion motion, and multi-source search |

> Deprecated artifacts named `TitoDex-1.0.x-*` belong to the frozen pre-Flutter mock prototype. They remain available only for historical reference and are not newer than the current Flutter release.

Dex data: live bundle **v19** / Offline APK compact seed **v14** · 1025 species · 803 form records · audited static, animated, shiny, and cry media · complete item descriptions and icons.

> **Unofficial project notice:** TitoDex is a non-commercial tool intended only for learning and personal gameplay assistance. It is not affiliated with, authorized by, sponsored by, or endorsed by Nintendo, Creatures, GAME FREAK, The Pokémon Company, or their affiliates. Names, characters, images, audio, and trademarks belong to their respective owners. See [CREDITS.md](CREDITS.md) for full sources, licenses, and media credits.

## Highlights

- **Playthrough dashboard** — current game, location, party, badges, play time, and quick actions.
- **Save assistant** — nearby uncaught Pokémon, current-location capture reminders, party evolution routes, paired-version direct-encounter gaps, and evolution/breeding/trade completion advice.
- **Ask TitoDex** — the entire assistant is off by default. Its first Settings activation discloses network access, AI retrieval, and bounded context; Journey and Search reserve no entry space before consent. Once enabled, the selected version, compatible save context, and reviewed local facts still run first, and save location alone can no longer hijack an unrelated question. Unresolved questions can use BGE-M3 AI Search, the Dex bundle, fixed public sources, Tavily, and DeepSeek native search; when both live routes succeed, Qwen performs an additional conflict/corroboration check. The modern conversation page stores the latest 50 Q&A pairs locally and sends at most six same-game pairs for follow-ups. Three compact controls separately open connection details, local history management (compact or clear with confirmation), and the 23-edition picker. Verified answers progressively reveal after the evidence pass; verification and citations share one expandable row, while Pokémon, item, move, and ability links retain their lightweight semantic chips. Raw saves and trainer/party data are never uploaded.
- **Save-aware journeys** — one selected `.sav` file with persisted access; experimental Gen 1–7 metadata recognition, while HGSS syncs party nicknames, held items, moves/PP, abilities, EXP, friendship, natures, shiny state, IVs/EVs, battle stats, map/coordinates, money, trainer metadata, both badge banks, and Pokédex progress.
- **Pokédex 1–1025** — searchable forms, regional or G1–G9 scopes, body-style / colour / size filters, form-aware evolution chains, exact game and DLC obtain methods, moves, abilities, and selective form media.
- **Location Dex** — a compact selected-version area grid with caught completion and a missing-first encounter sheet.
- **Reference hub** — moves, abilities, natures, egg groups, items, weather, terrain, and status; item availability/prices, moves, and mechanics follow the selected game and generation.
- **Party assistance** — inspect moves, abilities, and next evolutions, then hand a party member and damaging move directly to the quick damage tool.
- **Battle utilities** — type matchup, stat and damage estimates, blind-spot analysis, abilities, items, weather, terrain, status, and Terastal modifiers with explicit assumptions.
- **Pokémon Sleep utilities** — offline sleep-score and basic cooking-strength estimates with overnight duration, 19 ingredients, recipe levels 1–70, and recipe bonus; formulas are pinned to Neroli’s Lab with its Apache-2.0 license bundled in the app.
- **Android shortcuts** — long-press the app icon for Dex and Search by default; Settings can customize up to three secondary destinations.
- **Native Android handoff** — select an installed emulator or game app and resume from TitoDex.
- **Offline-first data** — downloadable Dex bundle with Chinese labels, maps, configuration, icons, and list sprites; the Offline APK starts from a verified local seed.
- **Handheld layouts** — phones, tablets, square screens, and controller focus navigation.

## Product principles

1. **Resume quickly** — show what is needed to continue a playthrough.
2. **Respect game context** — filter data and mechanics by the selected title and generation.
3. **Work offline** — prefer local saves, cached reference data, and bundled fallbacks.
4. **Stay focused** — provide practical reference depth without duplicating a full wiki.
5. **Scale across devices** — support Android phones and compact handheld displays.

## Stack

| Layer | Choice |
| --- | --- |
| App | **Flutter + Dart** (`flutter/`) |
| Routing | `go_router` — Home, Team, Journey, Dex, Search, Settings |
| Persistence | `shared_preferences` + offline `dex_offline/` |
| Save | Single document URI + Gen 1–7 metadata recognition; full HGSS party/map/dex parser |
| Dex data | Pre-built bundle v19 with v5 → v4 → v3 → v2 fallback and APK asset fallbacks |
| UI language | Simplified Chinese |

Details: [Architecture](docs/ARCHITECTURE.md)

## Install

Download **`TitoDex-0.8.18-lite-rg-arm64.apk`** or **`TitoDex-0.8.18-offline-rg-arm64.apk`** from [GitHub Releases](https://github.com/Tito-XD/tito-dex/releases). Both target arm64-v8a Android devices. v0.8.18 upgrades directly from v0.8.13–v0.8.17; Android signing was rotated in v0.8.13, so v0.8.12 or earlier still requires export, uninstall, and reinstall.

The Lite APK downloads the offline data pack from Settings when requested. The Offline APK includes the same core data and prepares its bundled seed on first launch.

## Development

```bash
cd flutter
flutter pub get
flutter test
flutter run              # device / emulator
flutter run -d chrome    # limited web preview
```

Build and release instructions: [docs/RELEASE_BUILD.md](docs/RELEASE_BUILD.md)

Maintainer references: [Dex bundle and CDN](docs/CLOUDFLARE_DEX_CDN.md) · [Repository permissions](docs/PERMISSIONS.md)

## Documentation

| Document | Contents |
| --- | --- |
| [AI context](docs/AI_CONTEXT.md) | Current source and release state, architecture, and guardrails |
| [Roadmap](ROADMAP.md) | Release history and next work |
| [Architecture](docs/ARCHITECTURE.md) | Technology choice, data flow, and platform boundaries |
| [Journey blocker assistant](docs/JOURNEY_ASSISTANT.md) | Save-first fuzzy matching, privacy contract, AI Search/DeepSeek, and deployment gates |
| [Legacy Android extension compatibility](docs/EXTENSIONS.md) | 1.0.0 compatibility protocol and migration to bundled host data |
| [Flutter app](flutter/README.md) | App development notes |
| [Design system](docs/DESIGN_SYSTEM.md) | Visual, typography, layout, and interaction rules |
| [Release build](docs/RELEASE_BUILD.md) | APK checklist |
| [Release notes](docs/RELEASES.md) | Chinese-first GitHub Release copy rules and history |
| [Data sources and credits](CREDITS.md) | Data, media, licenses, and unofficial-project notice |
| [Third-party notices](THIRD_PARTY_NOTICES.md) | Bundled fonts, icons, package notices, and rights boundaries |

## HGSS test save

The bundled `PKMSS.sav` fixture is available for parser and import testing. Expected fields include three badges, Goldenrod City, and a party containing Quilava and Togepi.

```bash
python3 tools/probe_hgss_save.py fixtures/PKMSS.sav
```
