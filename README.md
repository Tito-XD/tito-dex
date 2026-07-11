# TitoDex

TitoDex is a personal Pokémon journey companion app: **Tito + Pokédex**, but not a Pokémon encyclopedia.

It is designed as a warm companion device for Tito's own Pokémon playthroughs, starting with **Pokémon SoulSilver / HeartGold-SoulSilver context** and expanding only when the journey reaches later games.

**Current release:** [v0.3.0](https://github.com/Tito-XD/tito-dex/releases/tag/v0.3.0) · App `0.3.0+31` · Dex CDN bundle **v5** (`/v3/`) (`/v2/`)

**Next (planned v0.3.0):** National dex **1–1025**, CDN bundle **v5** at `dex.tito.cafe/v3/`, **`DexScope`** multi-game regional browse

## Product North Star

**Continue First.**

When Tito opens TitoDex, the first thing should be the current journey:

- current game
- current location
- badges
- play time
- party snapshot
- recent journey notes
- quick access to useful local references

TitoDex should feel less like a wiki and more like a small trainer device that says: “Welcome back. Here is where we were.”

## Core Principles

1. **Continue First** — the home screen prioritizes continuing the current journey.
2. **Game Context First** — show information relevant to the currently played game.
3. **Local First** — offline-first and local data first.
4. **Companion, not Encyclopedia** — focus on play assistance, not replacing 52Poké, Bulbapedia, or Serebii.
5. **Iterative** — begin with HGSS, then adapt for Pt, BW, B2W2, XY, ORAS, USUM as Tito reaches them.
6. **Do not over-engineer** — first make a delightful companion, not a universal platform.

## Stack

**Active:** Flutter + Dart (`flutter/`)

**Reference:** Capacitor + React + TypeScript + Vite (`src/`, root `android/`)

See [Stack Decision](./docs/STACK_DECISION.md) for migration history and current feature status.

| Layer | Technology |
| --- | --- |
| UI | Flutter widgets, `DeviceShell`, sticker cards, bundled **Nunito** |
| Routing | `go_router` — Home, Team, Journey, Dex, Search, Settings |
| Persistence | `shared_preferences` — journey JSON + save-directory config |
| Save parsing | Dart `HgssParser` — retail 512 KB `.sav` |
| Save sync | Directory watch — newest `.sav` by mtime, startup auto-load |
| Dex data | PokeAPI + **Cloudflare CDN** offline bundle (`dex.tito.cafe`; v4 `/v2/` today, v5 `/v3/` planned) |
| Dex scope | National **1–493** shipped; **1–1025** + `DexScope` (HGSS / Johto / Kanto / SV move sets) in v0.3.0 |
| Dex sprites | **PNG** thumbnails + lazy-loaded full **artwork** |
| Localization | Simplified Chinese UI (`lib/l10n/`) |

## Releases (RG handheld APK)

Pre-built Android APKs live under [`releases/`](releases/) and on [GitHub Releases](https://github.com/Tito-XD/tito-dex/releases).

| File | Use |
| --- | --- |
| `TitoDex-0.2.28-rg-arm64.apk` | **RG Rotate** — arm64-v8a (~23 MB; SDK 36) |

Build locally:

```bash
cd flutter
flutter pub get
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk ../releases/TitoDex-<ver>-rg-arm64.apk
```

**Sideload:** uninstall any locally-built 0.2.x first (CI signing key differs). See [flutter/README.md](flutter/README.md).

## Dex CDN (production)

| Item | Value |
| --- | --- |
| Base URL | `https://dex.tito.cafe` |
| Offline bundle (production) | `https://dex.tito.cafe/v2/bundle.tar.zst` — bundle **v4**, 493 species |
| Offline bundle (v0.3.0) | `https://dex.tito.cafe/v3/bundle.tar.zst` — bundle **v5**, **1025** species |
| Bundle versions | **v4** `/v2/` (current APK) · **v5** `/v3/` (planned; adds `abilities`, `obtainLocations`, `pokedexNumbers`) |
| Worker branch | `deploy/dex-cdn` |

App compile-time defaults (`flutter/lib/features/dex/dex_cdn_config.dart`):

```bash
TITODEX_DEX_CDN_BASE=https://dex.tito.cafe
TITODEX_DEX_BUNDLE_URL=https://dex.tito.cafe/v2/bundle.tar.zst   # v0.3.0 → /v3/bundle.tar.zst
TITODEX_DEX_BUNDLE_VERSION=4                                     # v0.3.0 → 5
```

Setup & upload: [Cloudflare Dex CDN](./docs/CLOUDFLARE_DEX_CDN.md)

## Documentation

Start here:

- [Vision](./VISION.md)
- [Product](./PRODUCT.md)
- [Roadmap](./ROADMAP.md)
- [AI read-first guide](./docs/AI_READFIRST.md)
- [Design system](./docs/DESIGN_SYSTEM.md)
- [UI reference notes](./docs/UI_REFERENCE.md)
- [Architecture](./docs/ARCHITECTURE.md)
- [Stack decision](./docs/STACK_DECISION.md)
- [Parser proposal](./docs/PARSER_PROPOSAL.md)
- [Cloud sync proposal](./docs/CLOUD_SYNC_PROPOSAL.md) *(not implemented)*
- [Cloudflare dex CDN setup](./docs/CLOUDFLARE_DEX_CDN.md)
- [RG polish plan](./docs/RG_POLISH_PLAN.md)

## Development

### Flutter app (active)

```bash
cd flutter
flutter pub get
flutter test
flutter run -d chrome      # web preview
flutter run                # connected Android device / emulator
```

**First launch:** loads mock journey from `CurrentJourney.mock()` unless a saved journey exists in preferences.

**Import test save:** Settings → 旅程数据 → 导入内置 PKMSS.sav

**Dex offline pack:** Settings → 图鉴离线包 → 从 CDN 下载（production: `dex.tito.cafe` bundle v4 at `/v2/`; v0.3.0 targets v5 at `/v3/`, 1025 species)

**Auto-sync from emulator folder:** Settings → 存档目录 → pick a folder containing `.sav` files → enable 启动时自动加载. On startup, TitoDex picks the newest 524 288-byte `.sav` and refreshes the home screen.

Probe a save file from the command line:

```bash
python3 tools/probe_hgss_save.py fixtures/PKMSS.sav
```

Build dex CDN bundle:

```bash
pip install -r tools/dex_bundle_requirements.txt
# Production v4 (493, /v2/) — current APK default
python3 tools/build_dex_bundle.py --cdn-base https://dex.tito.cafe --output dist/dex-v4 --max-id 493
# v0.3.0 v5 (1025, /v3/)
python3 tools/build_dex_bundle.py --cdn-base https://dex.tito.cafe --output dist/dex-v5 --max-id 1025
```

### HGSS save fixtures

| Path | Purpose |
| --- | --- |
| `fixtures/PKMSS.sav` | Repo-root copy for scripts |
| `flutter/assets/fixtures/PKMSS.sav` | Bundled asset for tests + Settings import |
| `src/PKMSS.sav` | Original upload (legacy path) |

Fixture expectations (active save block): trainer `ETeZ`, TID `22813`, 3 Johto badges, play time `7:03:41`, location 满金市 (map ID 76), party includes Quilava Lv27 and Togepi Lv6.

### React mock (legacy Phase 2 — frozen)

Design reference only. Do not add features here.

```bash
npm install
npm run dev                # http://localhost:5173
npm run cap:sync           # sync into root android/ Capacitor shell
```

Journey data in React is still mock-only (`journeyStore.ts` always returns `mockJourney`).
