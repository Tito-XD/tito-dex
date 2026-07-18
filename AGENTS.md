# AGENTS.md

**Canonical project context for AI agents:** [`docs/AI_CONTEXT.md`](docs/AI_CONTEXT.md) — read it first (current release, architecture, guardrails, build steps).

## Quick facts

- **Active code:** `flutter/` (Flutter + Dart, Chinese UI)
- **Removed:** the pre-Flutter React mock (`src/`) was deleted in the 0.6.5 cleanup; its releases stay on GitHub as historical artifacts
- **Latest release:** v0.6.6.1 · Lite `0.6.6.1+79`; Offline `0.6.6.1-offline+80`
- **Offline data:** Dex bundle v5 (1025 species, `/v3/`)
- **Tests:** `cd flutter && flutter test` (198 passing)

## Cloud VM

- Flutter at `~/flutter/bin`; web dev via `flutter run -d chrome`
- APK build needs Android SDK + signing (see [RELEASE_BUILD.md](docs/RELEASE_BUILD.md))
- Dex CDN secrets: [PERMISSIONS.md](docs/PERMISSIONS.md) — never publish CDN URLs in public copy

Everything else (feature status, file map, CDN build, contributor rules) lives in **AI_CONTEXT.md**.
