# TitoDex Roadmap

> **Active implementation:** `flutter/`. See [Stack Decision](./docs/STACK_DECISION.md) for phase status and gaps.

## Versioning

| Tag | Meaning |
| --- | --- |
| `v0.1.x` | Phase 2 debug / early APK |
| `v0.2.x` | **Current pre-release** — RG handheld builds (UI polish, offline dex, CDN v4) |
| `v0.2.25` | **Latest** — UI overhaul + PNG CDN bundle + artwork viewer; RG APK arm64-v8a fix ([release](https://github.com/Tito-XD/tito-dex/releases/tag/v0.2.25)) |
| `v1.0.0` | Reserved for **feature-complete** public release (stable offline dex, emulator launch, save workflow, polish) |

Early builds were briefly tagged `v1.0.x` by mistake; they map 1:1 to `v0.2.x` on the same commits.

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

## Phase A — Native Feel + Local Persistence ✅

| Deliverable | Status |
| --- | --- |
| `JourneyRepository` — mock on first launch, then prefs | ✅ |
| Persist across restarts | ✅ |
| Custom splash + launcher icon | ❌ |
| `SystemChrome` status bar styling | ✅ |
| Android back — `PopScope` route stack | ✅ |
| DeviceShell safe-area tuning per form factor | ⚠️ basic |

## Phase B — Useful Companion ✅

| Deliverable | Status |
| --- | --- |
| Continue → pick emulator app, remember, launch | ✅ |
| Settings — edit trainer display name | ✅ |
| Settings — edit game / location / badges / time | ✅ |
| Journey timeline user editing | ⚠️ via JSON import/export |
| Journey JSON export / import UI | ✅ |
| Team + Journey pages | ✅ |

## Phase C — HGSS Save Parser ✅ (core) + extras

| Deliverable | Status |
| --- | --- |
| `HgssParser` — retail 512 KB `.sav` | ✅ |
| Trainer, badges, time, party, map location | ✅ |
| Party level decrypt (stats `0x8C`) | ✅ |
| Map ID → Chinese location (`hgss_map_list`) | ✅ |
| Fixture tests (`PKMSS.sav`) | ✅ |
| Bundled fixture import (Settings) | ✅ |
| **Save directory auto-sync** (newest `.sav`) | ✅ |
| Startup auto-load toggle | ✅ |
| Preserve customized trainer name on re-import | ✅ |
| Merge parser into timeline without wiping notes | ✅ |
| Single-file `.sav` picker | ❌ directory only |
| HeartGold detection | ❌ |
| Save dex seen/caught flags from `.sav` | ❌ |

## Phase D — HGSS Dex (PokeAPI) ✅ core + CDN

Reference: [破壳萌图鉴 / Pocket Gallery](https://eurekaffeine.github.io/pocket-gallery/zh-hans/) detail layout (简介 / 基本信息 / 获取 / 招式).

| Deliverable | Status |
| --- | --- |
| National dex 1–493 browse + search (PokeAPI, zh-Hans) | ✅ |
| Detail: types, height/weight, genus, evolution chain | ✅ |
| Type effectiveness (weak / resist / immune) | ✅ |
| **Detail 4-tab layout** (简介 / 基本信息 / 获取 / 招式) | ✅ |
| **Johto + National dual numbering** | ✅ |
| **Base stats bars + BST total** | ✅ |
| **18-type defensive multiplier grid** (cached type icons) | ✅ |
| **Flavor text carousel** (金/银/水晶/心金/魂银; EN fallback) | ✅ |
| **HGSS move sets** — level-up / TM / egg | ✅ |
| Gender ratio, egg groups, hatch steps (intro tab) | ✅ |
| Offline cache — PokeAPI batch **or CDN bundle v4** | ✅ |
| **PNG sprites** (transparent; legacy JPEG removed from CDN) | ✅ |
| **Tap header sprite → fullscreen artwork** (lazy CDN / PokeAPI) | ✅ |
| Journey party → caught marker on dex cards | ✅ |
| **Cloudflare CDN** `dex.tito.cafe` — Worker + R2 + bundle upload | ✅ |
| Radar chart for base stats | ❌ (bars only for now) |
| Capture locations / encounter tables | ❌ |
| Abilities on detail page | ❌ |
| Save-linked seen/caught on dex grid | ❌ |

## Phase E — Regional & Version Scopes

Cross-filter dex like Pocket Gallery’s **地区图鉴** + per-game move/flavor differences.

| Deliverable | Status |
| --- | --- |
| `DexScope` model (`region`, `versionGroup`, dex id range) | ❌ |
| Johto 251 list view (regional dex browse) | ❌ |
| Version switcher on detail (HGSS default; future SV, Z-A…) | ❌ |
| Scoped offline packs (HGSS / SV / …) | ❌ |
| Settings: default game version for dex | ❌ |

## Phase F — Reference Data (“常用资料”)

Standalone lists — lower priority than journey loop; can live under Search or Settings.

| Deliverable | Status |
| --- | --- |
| Move encyclopedia | ❌ |
| Ability list | ❌ |
| Natures / items / weather / terrain / status | ❌ |
| Interactive maps | ❌ |

## Phase G — Battle Tools (“计算器 / 对战资料”)

Optional; Pocket Gallery strength but out of TitoDex “journey companion” core.

| Deliverable | Status |
| --- | --- |
| Damage calculator | ❌ |
| IV / EV / stat calculators | ❌ |
| Team editor + coverage / blind-spot analysis | ❌ |
| Usage rankings | ❌ |

## Phase 3 — HGSS Context Content

HGSS-specific notes, checklists, richer reminders scoped to current game.

## Phase 4 — Optional Cloud Sync

Cloudflare Worker + D1 + R2 per `docs/CLOUD_SYNC_PROPOSAL.md`. **Dex CDN (R2 only) is live**; journey cloud sync remains non-goal for now.

## Later Generation Packs

When the journey reaches each era, extend Phase E scopes:

| Pack | Focus |
| --- | --- |
| HeartGold | Shared HGSS data; separate title if needed |
| D/P/Pt | Sinnoh 210, Plat forms |
| B/W/B2W2 | Unova dex, seasons |
| XY / ORAS | Mega, Hoenn 211 |
| SM / USUM | Alola dex, Z-Moves |
| Sw/Sh / SV | Dynamax/Tera, DLC dex splits |
| Legends / Z-A | Spin-off mechanics, separate move tables |

## Platform Roadmap

| Platform | When |
| --- | --- |
| Android (phone + RG Rotate) | Now |
| Linux handheld | After Android journey loop is solid |
| Web companion | After save sync strategy works without `dart:io` |

## Recommended Next Steps

1. **Save dex flags** — read caught/seen from `.sav` when parser supports it
2. **Johto 251 regional browse** — filter grid by `original-johto` entries
3. **Abilities** on detail intro/basic tabs
4. **Capture locations** for HGSS (PokeAPI encounter data or curated subset)
5. **Custom launcher icon** + splash polish
6. **`tito.cafe/pokedex` web** — reuse `dex.tito.cafe` CDN URLs + JSON
