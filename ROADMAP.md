# TitoDex Roadmap

> **Stack update (July 2026):** Implementation moves to **Flutter**. Phase 2 (Capacitor + React mock) is complete as a reference. See [Stack Decision](./docs/STACK_DECISION.md).

## Phase 1 — Foundation and Direction ✅

Goal: define TitoDex clearly before building complex features.

Deliverables:

- README, vision, product, roadmap
- AI read-first instructions
- design system direction
- architecture proposal
- save parser proposal
- cloud sync proposal

## Phase 2 — Android-first Mock App ✅

Goal: make TitoDex feel like a real companion device with mock data.

Delivered (Capacitor + React — **reference only**):

- responsive dashboard layout
- DeviceShell, Continue Journey card, Trainer Card
- Quick widgets, Team / Journey / Dex / Search / Settings skeletons
- design tokens, local mock data module
- HGSS save fixture: `src/PKMSS.sav`

Known gaps that motivated the Flutter migration:

- WebView tap highlight and “webpage” feel on real Android devices
- `journeyStore` always returns mock data (no persistence)
- Continue button is decorative (no emulator launch)
- Settings shows Phase 2 placeholder copy
- `hgssParser.ts` is a stub

## Phase 0 — Flutter Migration (current)

Goal: establish the Flutter codebase and reach visual parity on the home screen.

Scope:

- Flutter project scaffold (`lib/`, `pubspec.yaml`, `test/`)
- port design tokens from `tokens.css`
- rebuild DeviceShell + home dashboard widgets
- routing + bottom navigation
- Nunito font bundled locally

Out of scope:

- save parser
- cloud sync
- full Settings editing

## Phase A — Native Feel + Local Persistence

Goal: app feels native on Android and remembers journey state.

Scope:

- local journey store (mock template on first launch only)
- editable fields persisted across restarts
- custom splash screen and launcher icon (TitoDex branding)
- system status bar styling (`SystemChrome`)
- Android back: pop routes first, exit on home
- keep DeviceShell; adjust safe areas for phone vs square

## Phase B — Useful Companion

Goal: core interactions are real, not decorative.

Scope:

- **Continue:** first tap → pick installed emulator/game app; remember; launch on later taps
- **Settings:** edit trainer name, game, location, badges, play time; remove dev placeholder text
- journey timeline persistence
- local JSON export / import

## Phase C — HGSS Save Parser

Goal: parse enough SoulSilver / HeartGold save metadata to power Continue Journey.

Scope:

- SAF `.sav` file picker on Android
- HGSS parser in Dart (see `docs/PARSER_PROPOSAL.md`)
- validate against fixture `src/PKMSS.sav`
- compute save hash; detect save changes
- merge parser output into journey state without wiping manual timeline notes

Extract (partial OK):

- current game
- trainer name
- play time
- badges (Johto + Kanto bitmasks)
- party summary
- location (when offset/mapping is reliable)

Non-goals:

- full save editor
- multi-generation parser framework
- PC box management

## Phase 3 — HGSS Context (content)

Goal: make TitoDex useful for HGSS play without network.

Scope:

- HGSS-specific context notes and checklists
- party management (user-entered + parser-fed)
- Dex search scoped to current game context

## Phase 4 — Optional Cloud Sync Prototype

Goal: back up journey metadata and save files safely.

Suggested platform:

- Cloudflare Worker API
- D1 for metadata
- R2 for `.sav` backup blobs

Scope:

- manual backup
- save hash tracking
- updated time
- simple conflict display

Non-goal:

- complex account system
- social features
- automatic cross-device merge magic

## Later Generation Packs

Add generations when Tito actually reaches them:

- Platinum
- Black / White
- Black 2 / White 2
- X / Y
- ORAS
- USUM

Each pack should be small, contextual, and journey-driven.

## Platform Roadmap

| Platform | Phase |
| --- | --- |
| Android phone + RG Rotate | Phase 0–C |
| Linux handheld | After Android home is stable |
| Web companion | After core journey loop works |
