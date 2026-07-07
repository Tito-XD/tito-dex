# TitoDex Roadmap

## Phase 1 — Foundation and Direction

Goal: define TitoDex clearly before building complex features.

Deliverables:

- README
- vision document
- product document
- roadmap
- AI read-first instructions
- design system direction
- architecture proposal
- save parser proposal
- cloud sync proposal

Recommended next implementation step after this phase:

- scaffold Capacitor + React + TypeScript + Vite app
- create responsive mock home dashboard
- use hard-coded SoulSilver data
- validate layout on RG Rotate-style square screens, phone, tablet, and foldable-like viewport sizes
- keep the UI lightweight for Android 12 / Unisoc-class handheld hardware
- only consider React Native, Flutter, or Kotlin Compose if target-device testing exposes concrete Capacitor/WebView limitations

## Phase 2 — Android-first Mock App

Goal: make TitoDex feel like a real companion device with mock data.

Scope:

- Capacitor Android project
- React component shell
- design tokens
- responsive dashboard layout
- Continue Journey card
- Trainer Card
- Quick widgets
- mock Team / Journey / Dex / Search screens
- local mock data module

Out of scope:

- real save parsing
- cloud sync
- complete Pokédex

## Phase 3 — Local Data and HGSS Context

Goal: make TitoDex useful for HGSS play without depending on network access.

Scope:

- local storage model
- editable current journey state
- HGSS-specific context notes
- party management as user-entered data
- journey timeline persistence
- local data export/import

## Phase 4 — Save Parser Prototype

Goal: parse enough HGSS save metadata to power Continue Journey.

Scope:

- read selected `.sav` file locally
- compute save hash
- extract safe metadata only
- current game
- trainer name if practical
- play time if practical
- badges if practical
- location if practical
- party summary if practical

Non-goal:

- perfect full save editor
- multi-generation parser framework

## Phase 5 — Optional Cloud Sync Prototype

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
