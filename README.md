# TitoDex

**TitoDex** is a warm, offline-first Pokémon **journey companion** for Android handhelds and phones. It brings save progress, team and journey management, a 1–1025 Pokédex, Chinese reference data, and lightweight battle utilities into one compact, device-like interface.

It is built to make returning to a playthrough feel immediate and familiar: see where the journey paused, check the current team, and open the right reference tool without losing the character of a dedicated trainer device. It does not aim to replace a full community wiki or competitive simulator.

| Channel | Version | Notes |
| --- | --- | --- |
| Lite APK | [v0.6.2](https://github.com/Tito-XD/tito-dex/releases/tag/v0.6.2) · App `0.6.2+71` | arm64-v8a, about 23 MB |
| Offline APK | [v0.6.2](https://github.com/Tito-XD/tito-dex/releases/tag/v0.6.2) · App `0.6.2-offline+72` | Bundles the current dex pack, about 64 MB |
| `main` source baseline | App `0.6.2+71` | Standby companion 2.0, landscape dashboard, bundled game icons |

> Deprecated legacy artifacts named `TitoDex-1.0.x-*` belong to the frozen pre-Flutter mock prototype. They are retained only for history and are not newer than the current Flutter release.

Offline dex bundle: **v5** · 1025 species · 23 game editions.

## Highlights

- **Playthrough dashboard** — current game, location, party, badges, play time, and quick actions
- **Save-aware journeys** — one selected `.sav` file with persisted access; experimental Gen 1–7 metadata import and richer HGSS party/map/dex parsing
- **Native Android handoff** — choose an installed emulator or game app and resume from TitoDex
- **Companion touches** — a height-scaled animated standby Pokémon with quotes and cries, a six-slot party card, rare shiny surprises, and a silhouette quiz
- **Pokédex 1–1025** — search, regional scopes, per-game flavor text, obtain data, moves, abilities, and sprites
- **Reference hub** — moves, abilities, natures, egg groups, items, weather, terrain, and status
- **Battle utilities** — type matchup, stat and damage estimates, blind-spot analysis, abilities, items, weather, terrain, status, and Terastal modifiers
- **Offline-first data** — downloadable dex bundle with Chinese labels, maps, config, icons, and list sprites
- **Handheld layouts** — phone, tablet, and square-screen dashboard support with controller focus navigation

## Product principles

1. **Resume quickly** — show the information needed to continue a playthrough.
2. **Respect game context** — filter data and tools by the selected title and generation.
3. **Work offline** — prefer local saves, cached reference data, and bundled fallbacks.
4. **Stay focused** — provide practical reference depth without duplicating a full wiki.
5. **Scale across devices** — support Android phones and compact handheld displays.

## Stack

| Layer | Choice |
| --- | --- |
| App | **Flutter + Dart** (`flutter/`) |
| Reference mock | Capacitor + React (`src/` — frozen) |
| Routing | `go_router` — Home, Team, Journey, Dex, Search, Settings |
| Persistence | `shared_preferences` + offline `dex_offline/` |
| Save | Single document URI + Gen 1–7 metadata recognition; full HGSS party/map/dex parser |
| Dex data | Pre-built bundle v5 with APK asset fallbacks |
| UI language | Simplified Chinese |

Details: [Architecture](docs/ARCHITECTURE.md) · [Stack decision](docs/STACK_DECISION.md)

## Install

Download **`TitoDex-0.6.2-lite-rg-arm64.apk`** or **`TitoDex-0.6.2-offline-rg-arm64.apk`** from [GitHub Releases](https://github.com/Tito-XD/tito-dex/releases). Both target arm64-v8a Android devices. If Android reports a signature conflict with a locally built debug package, uninstall that package before installing the release APK.

The standard APK can download the offline data pack from Settings. The optional offline APK includes the same core data and seeds it on first launch.

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
| [Vision](VISION.md) | Product goals and boundaries |
| [Product](PRODUCT.md) | Audience, feature set, and priorities |
| [Roadmap](ROADMAP.md) | Release history and next work |
| [Flutter app](flutter/README.md) | App development notes |
| [Design system](docs/DESIGN_SYSTEM.md) | Visual and interaction tokens |
| [Release build](docs/RELEASE_BUILD.md) | APK checklist |
| [Release history](docs/RELEASES.md) | Standardized GitHub Release notes |

## HGSS test save

The bundled fixture `PKMSS.sav` is available for parser and import testing. Expected fields include three badges, Goldenrod City, and a party containing Quilava and Togepi.

```bash
python3 tools/probe_hgss_save.py fixtures/PKMSS.sav
```
