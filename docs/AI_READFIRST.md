# AI Read First: TitoDex

Future AI contributors must read this document before working on TitoDex.

## Stack and Migration (July 2026)

TitoDex is migrating from **Capacitor + React** to **Flutter + Dart**.

Read [Stack Decision](./STACK_DECISION.md) before starting implementation work.

Key points:

- The React app under `src/` is a **design reference** — do not add major features there.
- New UI, persistence, parser, and platform code go in **Flutter** (`lib/`, `test/`).
- **DeviceShell stays** — rebuild in Flutter; it is intentional product identity.
- Real Android testing showed WebView limitations; native rendering is the fix.
- Future targets include Linux handhelds and web; Flutter covers all three.

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

- **Flutter + Dart** for app UI, routing, persistence, parser, and platform adapters
- **Phase 2 React tree** — reference only for tokens, layout, and component naming
- Parser tests against `src/PKMSS.sav` before claiming HGSS support

## Phase 1 Guardrails

Allowed:

- documentation
- Flutter scaffolding and widget port from Phase 2 reference
- mock data for SoulSilver, Goldenrod City, party, journey timeline, Dex search
- HGSS parser prototype against `src/PKMSS.sav`

Do not build yet:

- all-generation parser
- cloud sync implementation
- complete encyclopedia
- OCR
- complex account system

Do not:

- add major features to the Capacitor/React tree
- switch to another framework (Compose-only, React Native) without explicit approval
