# AGENTS.md

**Canonical project context for AI agents:** [`docs/AI_CONTEXT.md`](docs/AI_CONTEXT.md) — read it first (current release, architecture, guardrails, build steps).

## Quick facts

- **Active code:** `flutter/` (Flutter + Dart, Chinese UI)
- **Frozen:** `src/` (React mock — do not extend)
- **Current release:** v0.4.94 · App `0.4.94+47` · Dex bundle v5 (1025 species, `/v3/`)
- **Offline APK experiment:** `0.4.94-offline+48` — [docs/APK_BUNDLED_OFFLINE_PLAN.md](docs/APK_BUNDLED_OFFLINE_PLAN.md)
- **Tests:** `cd flutter && flutter test` (~115 passing)

## Cloud VM

- Flutter at `~/flutter/bin`; web dev via `flutter run -d chrome`
- APK build needs Android SDK + signing (see [RELEASE_BUILD.md](docs/RELEASE_BUILD.md))
- Dex CDN secrets: [PERMISSIONS.md](docs/PERMISSIONS.md) — never publish CDN URLs in public copy

Everything else (feature status, file map, CDN build, contributor rules) lives in **AI_CONTEXT.md**.
