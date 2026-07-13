# TitoDex

TitoDex is a personal Pokémon journey companion app: **Tito + Pokédex**, but not a Pokémon encyclopedia.

It is designed as a warm companion device for Tito's own Pokémon playthroughs, starting with **Pokémon SoulSilver / HeartGold-SoulSilver context** and expanding only when the journey reaches later games.

**Current release:** [v0.4.2](https://github.com/Tito-XD/tito-dex/releases/tag/v0.4.2) · App `0.4.2+34` · Offline dex bundle **v5** (1025 species, 23 game editions)

**Shipped in v0.4.0:** Global **GameEdition** (23 games), **11 regional dexes**, detail tabs (flavor / obtain / moves per game), search hub (搜索 · 常用资料 · 对战资料)

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
| Dex data | PokeAPI + **pre-built offline bundle** (downloaded from Settings; v5, 1025 species) |
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
../tools/verify_release_apk.sh ../releases/TitoDex-<ver>-rg-arm64.apk
```

**Required APK contents & size checks:** [docs/RELEASE_BUILD.md](docs/RELEASE_BUILD.md) (~20–23 MB arm64; run `tools/verify_release_apk.sh` before commit).

**Sideload:** uninstall any locally-built 0.2.x first (CI signing key differs). See [flutter/README.md](flutter/README.md).

## Dex offline bundle

Pre-built dex bundle endpoints are configured at compile time (not shown in the app UI). See `flutter/lib/features/dex/dex_cdn_config.dart` and maintainer docs: [Cloudflare Dex CDN](./docs/CLOUDFLARE_DEX_CDN.md).

| Item | Notes |
| --- | --- |
| Bundle **v4** | 493 species (legacy) |
| Bundle **v5** | **1025** species (current app default) |
| Worker branch | `deploy/dex-cdn` |

Setup & upload: [Cloudflare Dex CDN](./docs/CLOUDFLARE_DEX_CDN.md) (maintainers — use your private `--cdn-base`, do not publish URLs in public copy)

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

**Dex offline pack:** Settings → 图鉴离线包 → 下载预打包图鉴包 (bundle v5, 1025 species)

**Auto-sync from emulator folder:** Settings → 存档目录 → pick a folder containing `.sav` files → enable 启动时自动加载. On startup, TitoDex picks the newest 524 288-byte `.sav` and refreshes the home screen.

Probe a save file from the command line:

```bash
python3 tools/probe_hgss_save.py fixtures/PKMSS.sav
```

Build dex offline bundle (maintainers — set `--cdn-base` via env, do not commit public URLs):

```bash
pip install -r tools/dex_bundle_requirements.txt
python3 tools/build_dex_bundle.py --cdn-base "$TITODEX_DEX_CDN_BASE" --output dist/dex-v5 --max-id 1025
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
