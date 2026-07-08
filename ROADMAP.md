# TitoDex Roadmap

> **Active implementation:** `flutter/`. See [Stack Decision](./docs/STACK_DECISION.md) for phase status and gaps.

## Phase 1 — Foundation and Direction ✅

Documentation, vision, product shape, architecture proposals.

## Phase 2 — Android-first Mock App ✅ (reference)

Capacitor + React mock under `src/` — validated layout and DeviceShell design. Frozen; not the shipping target.

## Phase 0 — Flutter Scaffold ✅

| Deliverable | Status |
| --- | --- |
| `flutter/` project with `lib/`, `test/`, platforms | ✅ |
| Theme tokens → `tito_colors.dart` / `tito_theme.dart` | ✅ |
| DeviceShell + home dashboard widgets | ✅ |
| `go_router` + bottom navigation | ✅ |
| Nunito via `google_fonts` | ✅ |

## Phase A — Native Feel + Local Persistence ⚠️

| Deliverable | Status |
| --- | --- |
| `JourneyRepository` — mock on first launch, then prefs | ✅ |
| Persist across restarts | ✅ |
| Custom splash + launcher icon | ❌ |
| `SystemChrome` status bar styling | ❌ |
| Android back — `PopScope` route stack | ❌ |
| DeviceShell safe-area tuning per form factor | ⚠️ basic |

## Phase B — Useful Companion ⚠️

| Deliverable | Status |
| --- | --- |
| Continue → pick emulator app, remember, launch | ❌ stub sheet only |
| Settings — edit trainer display name | ✅ |
| Settings — edit game / location / badges / time | ❌ read-only snapshot |
| Journey timeline user editing | ❌ |
| Journey JSON export / import UI | ❌ helpers exist |

## Phase C — HGSS Save Parser ✅ (core) + extras

| Deliverable | Status |
| --- | --- |
| `HgssParser` — retail 512 KB `.sav` | ✅ |
| Trainer, badges, time, party, map location | ✅ |
| Party level decrypt (stats `0x8C`) | ✅ |
| Map ID → Chinese location (`hgss_map_list`) | ✅ |
| Fixture tests (`PKMSS.sav`) | ✅ 8 tests pass |
| Bundled fixture import (Settings) | ✅ |
| **Save directory auto-sync** (newest `.sav`) | ✅ extra |
| Startup auto-load toggle | ✅ |
| Preserve customized trainer name on re-import | ✅ |
| Merge parser into timeline without wiping notes | ❌ |
| Single-file `.sav` picker | ❌ directory only |
| HeartGold detection | ❌ |

## Next Up (recommended order)

1. **Continue → emulator launcher** — `device_apps` or intent + remembered package
2. **Team / Journey pages** — replace placeholders
3. **Native polish** — splash, icon, status bar, back button
4. **Timeline merge** — parser updates structured fields, keeps manual entries
5. **Dex / Search** — scoped to current game (lower priority than journey loop)
6. **Journey JSON export/import** in Settings

## Phase 3 — HGSS Context Content

HGSS-specific notes, checklists, richer Dex search scoped to current game.

## Phase 4 — Optional Cloud Sync

Cloudflare Worker + D1 + R2 per `docs/CLOUD_SYNC_PROPOSAL.md`. Non-goal for now.

## Later Generation Packs

Platinum → BW → B2W2 → XY → ORAS → USUM when the journey reaches each.

## Platform Roadmap

| Platform | When |
| --- | --- |
| Android (phone + RG Rotate) | Now |
| Linux handheld | After Android journey loop is solid |
| Web companion | After save sync strategy works without `dart:io` |
