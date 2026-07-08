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

**Active:** Flutter + Dart (Android-first; Linux handheld and web later).

**Reference:** Capacitor + React + TypeScript + Vite (Phase 2 mock app under `src/`).

TitoDex migrated to Flutter after real-device testing showed WebView limitations and to support future Linux handheld targets. See [Stack Decision](./docs/STACK_DECISION.md) for the full rationale and migration notes.

- **Flutter** for native rendering, cross-platform UI, and platform plugins (file picker, app launcher).
- **Local-first storage** (`shared_preferences` / `drift`) before cloud sync.
- **Dart HGSS parser** with fixture tests against `src/PKMSS.sav`.

## Phase 1 Scope

Phase 1 creates the project documentation and initial architecture direction. It intentionally avoids complex functionality.

Allowed mock data:

- current game: SoulSilver
- current location: Goldenrod City
- badge count: 3
- party summary
- journey timeline entries
- Pokédex search mock entries

Not in Phase 1:

- all-generation save parsers
- cloud sync implementation
- complete encyclopedia data
- emulator automation
- OCR
- complex account systems

## Documentation

Start here:

- [Vision](./VISION.md)
- [Product](./PRODUCT.md)
- [Roadmap](./ROADMAP.md)
- [AI read-first guide](./docs/AI_READFIRST.md)
- [Design system](./docs/DESIGN_SYSTEM.md)
- [UI reference notes](./docs/UI_REFERENCE.md)
- [Architecture](./docs/ARCHITECTURE.md)
- [Stack decision (Flutter migration)](./docs/STACK_DECISION.md)
- [Parser proposal](./docs/PARSER_PROPOSAL.md)
- [Cloud sync proposal](./docs/CLOUD_SYNC_PROPOSAL.md)

## Development

### Flutter (active)

Prerequisites: Flutter stable, Android SDK, Android Studio or CLI device.

```bash
flutter pub get
flutter run          # connected device or emulator
flutter test         # parser and unit tests
```

The Flutter app will live under `lib/` once Phase 0 scaffolding lands. Until then, use the Phase 2 reference below for UI and product shape.

### Phase 2 reference (Capacitor + React)

Frozen mock app for design reference — not the shipping target.

Prerequisites: Node.js 20+, npm, Android SDK.

```bash
npm install
npm run dev          # browser preview at http://localhost:5173
npm run build
npm run cap:sync     # sync into android/ Capacitor shell
```

Fonts are bundled locally (`@fontsource/nunito`). Journey data is still mock-only in this tree (`journeyStore.ts`).

### HGSS save fixture

`src/PKMSS.sav` — 524 288-byte SoulSilver save for parser development. See `docs/PARSER_PROPOSAL.md`.
