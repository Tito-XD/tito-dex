[简体中文](README.md) | **English**

# TitoDex

[TitoDex website](https://titodex.pages.dev) · [Web Pokédex](https://titodex.pages.dev/pokedex) · [1025 MV collages](https://titodex.pages.dev/1025)

The website connects the app project and releases with browser-based reference tools and collage browsing. It is maintained separately from the Android app in this repository.

**TitoDex** is a warm, offline-first Pokémon **journey companion** for Android handhelds and phones. It brings save progress, team and journey management, a 1–1025 Pokédex, Chinese reference data, and lightweight battle utilities into one compact, device-like interface.

It is designed to make returning to a playthrough feel immediate: see where the journey paused, check the current team, and open the right reference tool without losing the character of a dedicated trainer device. TitoDex does not try to replace a full community wiki or competitive simulator.

| Channel | Version | Notes |
| --- | --- | --- |
| Lite APK | [v0.9.19](https://github.com/Tito-XD/tito-dex/releases/tag/v0.9.19) · App `0.9.19+206` | Lighter Trainer’s Journal and on-demand companion animations; on-demand v20 data |
| Offline APK | [v0.9.19](https://github.com/Tito-XD/tito-dex/releases/tag/v0.9.19) · App `0.9.19-offline+207` | The same updated UI with the complete verified v20 bundle embedded |
| Journey Assistant | Built in | Structured-data-first answers, 50 local Q&A pairs, and category-aware prop motion |

> Deprecated artifacts named `TitoDex-1.0.x-*` belong to the frozen pre-Flutter mock prototype. They remain available only for historical reference and are not newer than the current Flutter release.

Dex data: live and Offline bundles **v20** · 1025 species · 803 form records · verified move, ability, item, and gameplay projections · audited static, animated, shiny, and cry media.

> **Unofficial project notice:** TitoDex is a non-commercial tool intended only for learning and personal gameplay assistance. It is not affiliated with, authorized by, sponsored by, or endorsed by Nintendo, Creatures, GAME FREAK, The Pokémon Company, or their affiliates. Names, characters, images, audio, and trademarks belong to their respective owners. See [CREDITS.md](CREDITS.md) for full sources, licenses, and media credits.

## Highlights

- **Unified Dex filtering** — search, regional dex, debut generation, journey-only browsing, types, appearance, abilities, moves and egg groups share one sheet and can intersect; optional form display preserves form identity.
- **Shared detail context** — themed sheets below the header select form, merged reference context, exact game and DLC scope. Obtain methods, evolution conditions and moves share that selection.
- **Consistent themes** — each theme owns its corners, outlines, shadows, sheets and selection states. Small images use static placeholders; slow image and reference reads use a pale ball rotating in place. Long descriptions grow with their content.
- **Clearer layouts and lighter loading** — separate query and reference browsing, switch among four battle tools, and inspect a six-slot Team board. Shared data reads, background decoding and lazy lists reduce first-open work.
- **System language** — Chinese and English UI follow the OS or Android per-app language without an in-app switch. Available English entity names are used; untranslated reference prose retains its original language.

- **30th anniversary logos** — open a Pokémon image to switch to anniversary artwork and choose its official logo variants. The catalog preserves 1324 entries: 1025 base graphics and 299 additional files. Verified forms match automatically; unknown forms remain explicitly unmatched and can be chosen manually. Images load online only on demand and never alter the original form, shiny selection, or Dex data.
- **Three built-in themes** — Trainer's Journal, Solid Plastic, and Flat UI persist across launches; production installs still default to Trainer's Journal. Navigation and content reveals adapt to each theme and respect reduced-motion settings.
- **Playthrough dashboard** — current game, location, party, badges, play time, and quick actions.
- **Journey details** — Ask sits directly below current location. Trainer facts and same-generation counterpart encounter gaps use compact grids; other uncaught species open as a Dex filter. Party evolution lives in Team.
- **Ask TitoDex** — off by default, with explicit network and context consent. Supported evolution, move/ability reverse lookup, intersected filters, items and other existing resources use deterministic queries whose results cannot be overwritten by the model; remaining questions use bounded source retrieval. The latest 50 Q&A pairs stay on-device, with at most six same-game pairs used for follow-ups. Raw saves and trainer/party data are never uploaded. Leading answer props follow the question category and stop on its subject; long answers retain their starting reading position. Expand evidence on demand and open entities by stable IDs.
- **Save-aware journeys** — one selected `.sav` file with persisted access; experimental Gen 1–7 metadata recognition, while HGSS syncs party nicknames, held items, moves/PP, abilities, EXP, friendship, natures, shiny state, IVs/EVs, battle stats, map/coordinates, money, trainer metadata, both badge banks, and Pokédex progress.
- **Pokédex 1–1025** — searchable forms, regional or G1–G9 scopes, body-style / colour / size filters, form-aware evolution chains, exact game and DLC obtain methods, moves, abilities, and selective form media.
- **Location Dex** — a compact selected-version area grid with caught completion and a missing-first encounter sheet.
- **Reference hub** — moves, abilities, natures, egg groups, items, weather, terrain, and status; item availability/prices, moves, and mechanics follow the selected game and generation.
- **Party assistance** — one grid combines edition, count, average level, base stats, type coverage and weaknesses. Expand or collapse member details for moves, abilities and evolution, with direct damage-tool handoff.
- **Battle utilities** — type matchup, stat and damage estimates, blind-spot analysis, abilities, items, weather, terrain, status, and Terastal modifiers with explicit assumptions.
- **Pokémon Sleep utilities** — offline sleep-score and basic cooking-strength estimates with overnight duration, 19 ingredients, recipe levels 1–70, and recipe bonus; formulas are pinned to Neroli’s Lab with its Apache-2.0 license bundled in the app.
- **Introduction and trainer shortcuts** — first-run guidance sets name/avatar and introduces features; existing users skip it and Settings can replay it. A pinned Home shortcut uses the trainer name and follows renames; the application label stays TitoDex. Up to three configurable long-press destinations remain separate.
- **Native Android handoff** — select an installed emulator or game app and resume from TitoDex.
- **Offline-first data** — downloadable Dex bundle with Chinese labels, maps, configuration, icons, and list sprites; the Offline APK starts from a verified local seed.
- **Handheld layouts** — phones, tablets, square screens, and controller focus navigation.

Companion animation choices now include Paraíso game collections and explicitly mapped ShinyHunters samples. The app bundles a small URL index and downloads only the confirmed choice; the first catalog covers 546 species, with exact form and color matching. Trainer’s Journal uses lighter outlines, paper edges, photo/tape details and ruled records while retaining existing font sizes and bundled fonts.

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
| Dex data | Pre-built bundle v20 with v5 → v4 → v3 → v2 fallback and APK asset fallbacks |
| UI language | Simplified Chinese by default; English follows OS / Android per-app language, with source-language fallback for untranslated data |

Details: [Architecture](docs/ARCHITECTURE.md)

## Install

Download **`TitoDex-0.9.19-lite-rg-arm64.apk`** or **`TitoDex-0.9.19-offline-rg-arm64.apk`** from [GitHub Releases](https://github.com/Tito-XD/tito-dex/releases). Both target arm64-v8a Android devices. v0.9.19 upgrades directly from v0.8.13 and later production or public preview builds; Android signing was rotated in v0.8.13, so v0.8.12 or earlier still requires export, uninstall, and reinstall.

The Lite APK downloads v20 data from Settings when requested. The larger Offline APK embeds the complete v20 bundle and prepares it on first launch.

Since v0.9.18, Settings supports updates: startup checks stable GitHub releases at most once per 24 hours, matches the installed Lite/Offline variant, and downloads only on user request before verification and Android installation. Earlier versions need one manual upgrade. Keep the App running during APK downloads. Direct downloads: [Lite · 29.32 MB](https://github.com/Tito-XD/tito-dex/releases/download/v0.9.19/TitoDex-0.9.19-lite-rg-arm64.apk), [Offline · 95.45 MB](https://github.com/Tito-XD/tito-dex/releases/download/v0.9.19/TitoDex-0.9.19-offline-rg-arm64.apk), or the [website download page](https://titodex.pages.dev/app#download).

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

Contribution and required commit checks: [CONTRIBUTING.md](docs/CONTRIBUTING.md).

## Documentation

| Document | Contents |
| --- | --- |
| [AI context](docs/AI_CONTEXT.md) | Current source and release state, architecture, and guardrails |
| [Roadmap](ROADMAP.md) | Release history and next work |
| [Architecture](docs/ARCHITECTURE.md) | Technology choice, data flow, and platform boundaries |
| [Journey Q&A](docs/JOURNEY_ASSISTANT.md) | Reviewed hints, privacy and bounded retrieval |
| [Structured answers](docs/ASK_STRUCTURED_DATA.md) | Existing resource queries and fact ownership |
| [Updates and introduction](docs/APP_UPDATE_AND_ONBOARDING.md) | App updates, trainer identity and shortcuts |
| [Contribution workflow](docs/CONTRIBUTING.md) | Attribution checks and history migration |
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
