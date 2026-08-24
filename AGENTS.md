# AGENTS.md

**Canonical project context for AI agents:** [`docs/AI_CONTEXT.md`](docs/AI_CONTEXT.md) — read it first (current release, architecture, guardrails, build steps).

## Quick facts

- **Active code:** `flutter/` (Flutter + Dart, Chinese UI)
- **Removed:** the pre-Flutter React mock (`src/`) was deleted in the 0.6.5 cleanup; its releases stay on GitHub as historical artifacts
- **Latest release:** v0.9.1 · Lite `0.9.1+179`; Offline `0.9.1-offline+180`
- **Offline data:** CDN bundle v20 live; Offline APK embeds the complete verified v20 reference/gameplay archive (`/v5/`; `/v4/` rollback)
- **Tests:** `cd flutter && flutter test`

## Cloud VM

- Flutter at `~/flutter/bin`; web dev via `flutter run -d chrome`
- APK build needs Android SDK + signing (see [RELEASE_BUILD.md](docs/RELEASE_BUILD.md))
- Dex CDN secrets: [PERMISSIONS.md](docs/PERMISSIONS.md) — never publish CDN URLs in public copy

Everything else (feature status, file map, CDN build, contributor rules) lives in **AI_CONTEXT.md**.
