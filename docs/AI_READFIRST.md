# AI Read First: TitoDex

Future AI contributors must read this document before working on TitoDex.

## Stack and Migration (July 2026)

TitoDex runs on **Flutter + Dart** in the `flutter/` directory.

Read [Stack Decision](./STACK_DECISION.md) before starting implementation work.

Key points:

- The React app under `src/` is a **frozen design reference** — do not add features there.
- All new work goes in **`flutter/lib/`** and **`flutter/test/`**.
- **DeviceShell stays** — it is intentional product identity.
- **Chinese UI** is the default (`lib/l10n/app_zh.dart`, `game_zh.dart`).
- HGSS parser and save-directory sync are **implemented** — check status table in Stack Decision before assuming gaps.
- Flutter nav: **Home, Team, Journey, Dex, Search, Settings** — Dex + Search shipped in v0.2.x.
- **Dex offline bundle** — production bundle **v4** (493 species); app default **v5** (1025 species; `abilities`, `obtainLocations`, `pokedexNumbers`).
- **DexScope** — 11 regional dexes + bottom-sheet picker shipped (v0.4.1); **dex list game bar removal planned** (see ROADMAP Phase E).

## RG APK Release (agents)

When building or publishing RG handheld APKs:

| Rule | Detail |
| --- | --- |
| **ABI** | **arm64-v8a only** (`ndk.abiFilters`) — RG Rotate / Unisoc |
| **Filename** | `releases/TitoDex-<ver>-rg-arm64.apk` |
| **SDK** | `compileSdk = 36`, `targetSdk = 36`, `minSdk = 24` (matches working 0.2.11 / local 0.2.23) |
| **Build** | `flutter build apk --release` (no `--split-per-abi`, no `--target-platform`) |
| **Signing** | `android/key.properties` + `titodex-upload.keystore` (committed; not per-machine debug) |
| **Native libs** | `.so` must be **Stored** (`useLegacyPackaging = false`, `minSdk 24`) |
| **Upgrade** | User must **uninstall** locally-built 0.2.x before sideloading CI APK (signature differs) |

Full build notes: [flutter/README.md](../flutter/README.md).

## Dex list UX (planned — do not implement until batched)

Tito confirmed: **remove game-edition filter from the dex list**; regional pokedex picker is enough.

- **List page:** `_region` only (全国 / 城都 / … / 帕底亚). No `_DexGameEditionBar`.
- **Game version stays** on detail (moves / obtain / flavor), home, Search battle tools, Settings.
- **Why:** game tap resets region but region pick does not reset game — confusing dual control.
- **Track:** [ROADMAP.md](../ROADMAP.md) → Phase E → “Planned UX — Dex list”.

## Detail page UX (planned — batch with dex list changes)

### Obtain tab — location names

Tito confirmed: raw IDs like `301` / `823` in「出现地点」are unusable. Need **encounter location mapping table** (HGSS first).

- Existing partial slug map: `dex_game_scope.dart` → `encounterAreaLabelsZh`
- Existing HGSS map list (save parser): `hgss_map_list.dart` — not used for obtain display yet
- Fix at bundle build + app display fallback; see ROADMAP Phase E → “Detail obtain tab”

### Moves tab — inline game picker

Tito confirmed: remove top `_MoveGameEditionBar` chip scroll; make **`以下招式范围：{game}`** tappable to pick game version (bottom sheet). Saves vertical space on RG.

## Journey / trainer / team (planned — batch separately)

See **[JOURNEY_PROFILE_PLAN.md](./JOURNEY_PROFILE_PLAN.md)**.

- Fix **avatar** in **Settings** (broken; home-only tap today)
- Settings: trainer name + avatar editable; journey fields **read-only from save**
- NS/mobile global game → no save sync; hide **Continue** + **Journey**; home quick tiles **4→3**
- Team: manual party edit + **aggregate team stats** card

## Communication Defaults

- Default communication with Tito should be in **Chinese**.
- GitHub collaboration artifacts should be in **English** by default:
  - Issue titles and bodies
  - PR titles and bodies
  - commit messages
  - merge commits
  - release notes

## What TitoDex Is

TitoDex is Tito's personal Pokémon companion device.

It is for continuing Tito's own Pokémon journey, beginning with SoulSilver / HGSS context. It should feel warm, compact, and companion-like.

## What TitoDex Is Not

TitoDex is **not** a Pokémon encyclopedia.

Do not turn it into a replacement for 52Poké, Bulbapedia, Serebii, or any complete Pokédex/wiki site. Encyclopedia completeness is not the goal.

## Core Principles

### Continue First

The home screen should prioritize continuing the journey. The first and most important surface is the current playthrough: game, location, badges, play time, party, and recent notes.

### Local First

TitoDex should work offline and prefer local data. Cloud sync, if added, is optional backup/sync infrastructure rather than the product's center.

### Game Context First

Show information for the current game first. Avoid generic all-generation views unless they directly support the current journey.

### Companion, Not Encyclopedia

Build features that help Tito play, remember, and enjoy the journey. Avoid broad database work unless it supports a concrete journey use case.

### Iterative

Start with HGSS. Add later games only when Tito reaches them. Do not design a giant all-generation system in advance.

### Do Not Over-Design

Prefer simple, useful, local, understandable architecture. Avoid premature abstractions, large frameworks, parser systems for every generation, or complex account models in early phases.

## Design Direction

TitoDex is not a normal Android app. It is “Tito's Pokémon device.”

Visual keywords:

- warm device UI
- modern retro
- sticker UI
- blue gray
- cream
- soft yellow
- deep navy
- compact
- friendly
- companion
- trainer journey

Design language:

- blue gray + cream + deep navy
- small coral-orange or warm accents
- thick outlines
- sticker feeling
- badge feeling
- widget dashboard
- rounded cards
- Riolu as companion character
- Trainer Card feeling
- avoid a strong Material Design flavor
- follow the supplied UI reference notes in `docs/UI_REFERENCE.md` for the current north-star look

## Responsive Requirements

- mobile first
- grid dashboard for square / wide viewports
- `clamp()`-style scaling in Flutter (`MediaQuery`, responsive padding)
- safe-area / `SafeArea` inset support
- no fixed `720×720` layout
- Dex grid should use flexible columns (`GridView`, `SliverGrid`)
- square screens (RG Rotate) use dashboard layout and should fill space well
- **DeviceShell** retained on all form factors unless explicitly changed

## Implementation Stack

- **Flutter + Dart** — `flutter/lib/`, active development
- **Phase 2 React** — `src/`, frozen reference for tokens and layout
- **Parser tests** — `cd flutter && flutter test` with `assets/fixtures/PKMSS.sav`
- **Save sync** — directory-based on Android; do not assume web support without replacing `dart:io`

## Localization

- Default UI language: **Simplified Chinese** (`app_zh.dart`)
- Game strings (locations, species): `game_zh.dart`
- No `intl` ARB / locale switching yet — do not introduce English-only UI strings on primary surfaces without Tito's OK

## Phase 1 Guardrails

Allowed:

- documentation
- Flutter features in `flutter/`
- HGSS parser improvements and fixture tests
- Chinese copy updates in `lib/l10n/`

Do not build yet:

- all-generation parser
- journey cloud sync implementation (dex CDN is done; see `CLOUDFLARE_DEX_CDN.md`)
- complete encyclopedia
- OCR
- complex account system

Do not:

- add features to `src/` (Capacitor/React)
- switch frameworks without explicit approval
- overwrite manual journey timeline on save import without implementing merge rules in `PARSER_PROPOSAL.md`
