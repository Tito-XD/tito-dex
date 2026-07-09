# TitoDex

TitoDex is a personal Pokémon journey companion app: **Tito + Pokédex**, but not a Pokémon encyclopedia.

It is designed as a warm companion device for Tito's own Pokémon playthroughs, starting with **Pokémon SoulSilver / HeartGold-SoulSilver context** and expanding only when the journey reaches later games.

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

See [Stack Decision](./docs/STACK_DECISION.md) for why we migrated and what is implemented today.

| Layer | Technology |
| --- | --- |
| UI | Flutter widgets, `DeviceShell`, sticker cards, Nunito via `google_fonts` |
| Routing | `go_router` — Home, Team, Journey, Settings |
| Persistence | `shared_preferences` — journey JSON + save-directory config |
| Save parsing | Dart `HgssParser` — retail 512 KB `.sav` |
| Save sync | Directory watch — newest `.sav` by mtime, startup auto-load |
| Localization | Simplified Chinese UI (`lib/l10n/`) — static maps, no ARB yet |

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
- [Cloud sync proposal](./docs/CLOUD_SYNC_PROPOSAL.md)
- [Cloudflare dex CDN setup](./docs/CLOUDFLARE_DEX_CDN.md)

## Development

### Flutter app (active)

```bash
cd flutter
flutter pub get
flutter run -d chrome      # web preview
flutter run                # connected Android device / emulator
flutter test               # parser, map lookup, save scanner, widget smoke
```

**First launch:** loads mock journey from `CurrentJourney.mock()` unless a saved journey exists in preferences.

**Import test save:** Settings → 旅程数据 → 导入内置 PKMSS.sav

**Auto-sync from emulator folder:** Settings → 存档目录 → pick a folder containing `.sav` files → enable 启动时自动加载. On startup, TitoDex picks the newest 524 288-byte `.sav` and refreshes the home screen.

Probe a save file from the command line:

```bash
python3 tools/probe_hgss_save.py fixtures/PKMSS.sav
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
