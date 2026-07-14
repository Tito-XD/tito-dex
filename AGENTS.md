# AGENTS.md

**Canonical project context for AI agents:** [`docs/AI_CONTEXT.md`](docs/AI_CONTEXT.md) — read it first (current release, architecture, guardrails, build steps).

## Quick facts

- **Active code:** `flutter/` (Flutter + Dart, Chinese UI)
- **Frozen:** `src/` (React mock — do not extend)
- **Latest standard release:** v0.4.98 · App `0.4.98+51`; **`main` baseline:** `0.4.94+47`
- **Optional distribution:** v0.4.97-offline · Dex bundle v5 (1025 species, `/v3/`)
- **Tests:** `cd flutter && flutter test` (~115 passing)

## Cloud VM

- Flutter at `~/flutter/bin`; web dev via `flutter run -d chrome`
- APK build needs Android SDK + signing (see [RELEASE_BUILD.md](docs/RELEASE_BUILD.md))
- Dex CDN secrets: [PERMISSIONS.md](docs/PERMISSIONS.md) — never publish CDN URLs in public copy

Everything else (feature status, file map, CDN build, contributor rules) lives in **AI_CONTEXT.md**.
