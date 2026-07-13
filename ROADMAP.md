# TitoDex Roadmap

> **Active implementation:** `flutter/`. See [Stack Decision](./docs/STACK_DECISION.md) for phase status and gaps.

## Versioning

| Tag | Meaning |
| --- | --- |
| `v0.1.x` | Phase 2 debug / early APK |
| `v0.2.x` | **Current pre-release** — RG handheld builds (UI polish, offline dex, CDN v4) |
| `v0.3.0` | National dex **1–1025**, offline bundle **v5**, `DexScope` multi-game browse, radar chart, move/ability encyclopedia ([release](https://github.com/Tito-XD/tito-dex/releases/tag/v0.3.0)) |
| `v0.2.28` | Dex detail UI + typography + battle companion tools ([release](https://github.com/Tito-XD/tito-dex/releases/tag/v0.2.28)) |
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
| **Save dex seen/caught flags from `.sav`** | ✅ |

## Phase D — HGSS Dex (PokeAPI) ✅ core + CDN v5 expansion

Reference: [破壳萌图鉴 / Pocket Gallery](https://eurekaffeine.github.io/pocket-gallery/zh-hans/) detail layout (简介 / 基本信息 / 获取 / 招式).

| Deliverable | Status |
| --- | --- |
| National dex **1–493** browse + search (PokeAPI, zh-Hans) | ✅ v0.2.28 |
| National dex **1–1025** browse + offline CDN pack | 🚧 v0.3.0 |
| Detail: types, height/weight, genus, evolution chain | ✅ |
| Type effectiveness (weak / resist / immune) | ✅ |
| **Detail 4-tab layout** (简介 / 基本信息 / 获取 / 招式) | ✅ |
| **Johto + National dual numbering** | ✅ |
| **Base stats bars + BST total** | ✅ |
| **Radar chart for base stats** | 🚧 (bars shipped; radar chart v0.3.0) |
| **18-type defensive multiplier grid** (cached type icons) | ✅ |
| **Flavor text carousel** (金/银/水晶/心金/魂银; EN fallback) | ✅ |
| **HGSS move sets** — level-up / TM / egg | ✅ |
| Gender ratio, egg groups, hatch steps (intro tab) | ✅ |
| Offline cache — PokeAPI batch **or CDN bundle** | ✅ |
| **PNG sprites** (transparent; legacy JPEG removed from CDN) | ✅ |
| **Tap header sprite → fullscreen artwork** (lazy CDN / PokeAPI) | ✅ |
| Journey party → caught marker on dex cards | ✅ |
| **Cloudflare dex CDN** — Worker + R2 + bundle upload | ✅ |
| **CDN bundle v4** (`/v2/`, 493 species) — production on v0.2.28 | ✅ |
| **CDN bundle v5** (`/v3/`, 1025 species; `abilities`, `obtainLocations`, `pokedexNumbers`) | 🚧 v0.3.0 |
| **Capture locations / encounter tables** | ✅ (detail tab + CDN v5) |
| **Abilities on detail page** | ✅ (detail tab + CDN v5) |
| **Save-linked seen/caught on dex grid** | ✅ (save flags + party markers) |

## Phase E — Regional & Version Scopes

Cross-filter dex like Pocket Gallery’s **地区图鉴** + per-game move/flavor differences.

| Deliverable | Status |
| --- | --- |
| `DexScope` model (`DexGameVersion` + `DexRegionalScope`) | 🚧 (model in `dex_scope.dart`; UI wiring v0.3.0) |
| Johto 251 list view (regional dex browse) | ✅ |
| Kanto 151 regional browse | ✅ |
| Version switcher on detail (HGSS default; SV / SwSh move sets in CDN v5) | 🚧 |
| Scoped offline packs (HGSS / SV / …) | 🚧 |
| Settings: default game version for dex | 🚧 |

### Planned UX — Dex list (Tito confirmed, not implemented)

**Remove the horizontal game-edition bar from the dex list page.** Browse by **regional pokedex only** (全国 + 10 regional dexes via bottom-sheet picker).

| Keep on dex list | Move elsewhere |
| --- | --- |
| Regional scope tab + picker (`_region`) | Global `GameEdition` — detail page, Search battle tools, Settings / home |
| Journey tab | Obtain locations & move sets per game (detail tabs) |

**Rationale (2026-07):** Game chip and region picker overlap — tapping a game forces `_region` to that edition’s default regional dex, but picking 全国 does not reset the game. Two controls on one axis confuses users. List view = *which dex*; detail view = *which game’s data*.

**Implementation notes (when batching with other dex UX):**

- Remove `_DexGameEditionBar` from `dex_page.dart`.
- Stop syncing `_region = edition.defaultRegionalPokedex` on game tap in list context.
- Title bar: prefer region label or plain「图鉴」, not「图鉴 · {game}``.
- Init: do not force `_region` from saved game on open — or default list to 全国 unless user last picked a region (TBD with other changes).
- Global `gameEditionRepository` still updated from home / detail / settings.

### Planned UX — Detail obtain tab (Tito confirmed, not implemented)

**Obtain locations must show human-readable place names**, not raw IDs like `301` / `823`.

| Current | Problem |
| --- | --- |
| `ObtainLocationEntry.areaLabelZh` displayed as-is | CDN / PokeAPI slugs with no label fall back to slug or bare number |
| `encounterAreaLabelsZh` in `dex_game_scope.dart` | ~20 HGSS slug entries only (routes, a few dungeons) |
| `hgss_map_list.dart` + `locationLabelForMapId()` | Used for **save parser** map @0x1234, **not** wired to obtain tab |

**Planned fix (batch with other detail UX):**

- Add / extend **encounter location mapping** (HGSS first): PokeAPI `location-area` slug → 中文名; numeric IDs → name via lookup table.
- Reuse or align with Project Pokémon HGSS map list where IDs match in-game map indices.
- Bundle build (`tools/build_dex_bundle.py` → `encounter_area_label_zh`) should bake `areaLabelZh` at build time so offline bundle is self-contained.
- Display fallback: never show bare number without 「未知地点 #N」+ optional debug slug.

### Planned UX — Detail moves tab (Tito confirmed, not implemented)

**Remove the top horizontal game-edition chip bar on the Moves tab.** Game selection moves inline to the scope line.

| Current | Planned |
| --- | --- |
| `_MoveGameEditionBar` — 23-game horizontal scroll above method filters | **Remove** |
| Static text `以下招式范围：心金/魂银 (HGSS)` | **Tappable** — opens game picker (bottom sheet or dropdown, same pattern as regional dex picker) |
| Method chips (等级 / 学习器 / 蛋 / 教学) | Unchanged, stays below scope line |

**Rationale:** Same as dex list — long chip row wastes vertical space on RG; one line with picker is enough. Game filter belongs on the scope label, not a separate row.

**Code touchpoints (when implementing):** `pokemon_detail_page.dart` → `_movesSections`, `_MoveGameEditionBar`; `app_zh.dart` → `dexMovesScope`.

## Phase F — Reference Data (“常用资料”)

Standalone lists — lower priority than journey loop; can live under Search or Settings.

| Deliverable | Status |
| --- | --- |
| Move encyclopedia | 🚧 (`moves.json` in bundle; browse UI v0.3.0) |
| Ability list | 🚧 (`abilities.json` in CDN v5; browse UI v0.3.0) |
| Natures / items / weather / terrain / status | ❌ |
| Interactive maps | ❌ |

## Phase G — Battle Tools (“计算器 / 对战资料”)

Optional; Pocket Gallery strength but out of TitoDex “journey companion” core.

| Deliverable | Status |
| --- | --- |
| **Search companion panel** (type matchup, stat calc, quick damage) | ⚠️ **Partial ✅** — shipped v0.2.28 on Search page |
| Full damage calculator | ❌ |
| IV / EV / stat calculators (beyond basic stat calc) | 🚧 |
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
| Sw/Sh / SV | Dynamax/Tera, DLC dex splits — move sets in CDN v5 |
| Legends / Z-A | Spin-off mechanics, separate move tables |

## Platform Roadmap

| Platform | When |
| --- | --- |
| Android (phone + RG Rotate) | Now |
| Linux handheld | After Android journey loop is solid |
| Web companion | After save sync strategy works without `dart:io` |

## Recommended Next Steps (post-v0.3.0)

1. **Ship bundle v5** — build with `--max-id 1025`, upload to private CDN, flip app defaults to bundle v5
2. **Wire `DexScope` in UI** — game version switcher on detail; default scope in Settings
3. **Radar chart** for base stats on detail (replace or complement bars)
4. **Move / ability encyclopedia** — browse `moves.json` + `abilities.json` from Search or Settings
5. **Custom launcher icon** + splash polish
6. **Full battle tools** — team coverage, richer damage calc (build on v0.2.28 Search companion panel)
7. **`tito.cafe/pokedex` web** — reuse v3 JSON + assets from private dex CDN
