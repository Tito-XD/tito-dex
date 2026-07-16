# Stack Decision: Flutter Migration

**Status:** Approved · **Flutter app shipping target:** `flutter/` subdirectory (July 2026)  
**Previous stack:** Capacitor + React + TypeScript + Vite  
**New stack:** Flutter + Dart

This document records why TitoDex moved to Flutter, what remains from the previous stack, and what contributors should watch for.

## Summary

TitoDex is built on **Flutter** in the `flutter/` directory. The Phase 2 React mock under `src/` remains a **design reference** for layout and tokens. Flutter drives the home screen from real save data when one `.sav` file or the bundled fixture is configured.

The decision was driven by real-device feedback (“feels like a webpage”), future target platforms (Linux handhelds, web), and native features (save import, emulator launcher) that are awkward in WebView.

## Current Implementation Status

**Latest release:** v0.4.99 · Lite `0.4.99+52` · Offline `0.4.99-offline+53` · Offline bundle **v5** (1025 species, `/v3/`)

| Phase | Goal | Status |
| --- | --- | --- |
| **0 — Scaffold** | Flutter project, theme, DeviceShell, routing | ✅ |
| **A — Persistence** | Local journey store, back handling | ⚠️ Custom icon/splash pending |
| **B — Companion** | Emulator launcher, Settings, JSON I/O | ✅ |
| **C — HGSS parser** | Parse `.sav`, drive home | ✅ |
| **D — Dex + CDN** | 1025 species, offline bundle, artwork | ✅ |
| **E — Scopes** | Game editions, regional dexes | ✅ |
| **F — Reference** | Encyclopedia + dex filters | ✅ v0.4.6 |
| **G — Battle tools** | Matchup, stat/damage estimates, blind spots, modifiers | ⚠️ Shipped, formula depth partial |

See [AI_CONTEXT.md](./AI_CONTEXT.md) for the full feature matrix and [ROADMAP.md](../ROADMAP.md) for what's next.

### Shipped highlights (v0.4.x)

- National dex **1–1025**, CDN bundle v5, zh catalog in `l10n/`
- 23 game editions, 11 regional dexes, `DexScope`
- Search hub: encyclopedia + battle tools; reference → dex filter
- Offline update prompts; incremental l10n download; weekly sync workflow
- RG APK ~21 MB, `flutter test` ~115 cases

### Not yet

- Custom launcher icon; HeartGold detection; single `.sav` picker
- Full competitive damage/IV workflows, usage rankings, journey cloud sync

### Navigation (current)

| Route | Screen |
| --- | --- |
| Home, Team, Journey, Dex, Search, Settings | All shipped in Flutter |

### Known parser behavior gaps

- `toJourney()` prepends a sync entry and **keeps** manual timeline rows (`id` not starting with `parsed`).
- Customized trainer display name **is** preserved when `trainerNameCustomized` is true (tested).
- Game is hardcoded to `SoulSilver`; Gen IV trainer names outside ASCII decode as `[code]` fragments.
- Save sync uses `dart:io` — directory auto-load is **Android/desktop only**, not web.

## Why We Switched

### 1. WebView feel on Android

On a real Android phone, the Capacitor build felt like “98% webpage” rather than an app:

| Symptom | Root cause in Phase 2 code |
| --- | --- |
| Blue/gray tap flash | WebView default tap highlight; `QuickWidget` used `<Link>` (`<a>`) without `-webkit-tap-highlight-color` |
| No native press feedback | No Material ripple; CSS `:active` states not applied consistently |
| Scroll / text selection “web” behavior | WebView defaults (`user-select`, overscroll) |
| Fonts and rendering | WebView text pipeline differs from Skia/Impeller |

These can be patched in CSS, but they do not remove the WebView ceiling. Native rendering was the right long-term fix.

### 2. Future platforms Capacitor does not cover

Product direction includes:

- **Android phones and RG Rotate** (current)
- **Linux handhelds** (e.g. future RG DS–class devices with a Linux OS)
- **Web** (companion dashboard in a browser later)

Capacitor targets mobile WebView shells. It does **not** target Linux desktop/handheld. **Flutter** is a first-class citizen on Android, Linux, and Web with one UI codebase.

### 3. Custom-drawn UI fits Flutter

TitoDex is not a Material-default app. It is a warm “trainer device” with:

- `DeviceShell` bezel and sticker cards
- Custom color tokens (`tokens.css`)
- Dashboard layout tuned for square and phone viewports

The UI is already self-drawn. Porting design tokens and layout logic to Flutter Widgets is a straight translation, not a redesign.

### 4. Native features need real platform APIs

Upcoming features are easier with Flutter plugins than custom Capacitor Java plugins:

| Feature | Flutter approach |
| --- | --- |
| Local journey persistence | `shared_preferences`, `drift`, or `isar` |
| Custom splash / icon / status bar | `flutter_native_splash`, `flutter_launcher_icons`, `SystemChrome` |
| Android back button | `PopScope` — pop route stack, exit on home |
| Continue → launch emulator | `device_apps` / intent launcher; remember choice in preferences |
| Pick `.sav` via SAF | `file_picker` or platform channel |
| HGSS save parser | Dart `typed_data` + fixture tests |

### 5. Why not Jetpack Compose?

Compose is excellent for **Android-only** apps. TitoDex also targets Linux handhelds and eventual web. Compose Multiplatform is newer and narrower than Flutter for this product’s roadmap.

Rachel’s Compose suggestion was correct for a phone-only path. The agreed direction is **cross-platform with custom UI** → Flutter.

## What We Are Keeping

These decisions are **unchanged** by the stack switch:

1. **DeviceShell stays** — the device bezel is part of TitoDex’s identity; rebuild it in Flutter, optionally tighten margins on tall phone screens.
2. **Product principles** — Continue First, Local First, Companion not Encyclopedia (see `VISION.md`, `PRODUCT.md`).
3. **Design tokens** — colors, radii, shadows, Nunito typography; translate `tokens.css` → `ThemeData` / custom constants.
4. **Mock data shape** — `mockJourney.ts` fields map directly to Dart models.
5. **Screen set** — Home, Team, Journey, Settings (Dex/Search later); DeviceShell on all targets.
6. **Phase scope** — local persistence before cloud; HGSS parser before multi-generation framework.

## What Carries Over vs. What Gets Rewritten

| Keep (reference or port) | Rewrite in Flutter |
| --- | --- |
| `docs/` product & design direction | All `src/**/*.tsx` → Dart widgets |
| `tokens.css` values | `flutter/lib/theme/` |
| `mockJourney` structure | `flutter/lib/models/journey.dart` |
| `DeviceShell` layout concept | `flutter/lib/widgets/device_shell.dart` |
| `PARSER_PROPOSAL.md` types | `flutter/lib/features/parser/` |
| HGSS fixture | `fixtures/PKMSS.sav`, `flutter/assets/fixtures/PKMSS.sav` |

The root `android/` Capacitor project and `npm` scripts remain as legacy reference. **Do not delete** the React tree yet; Flutter still lacks Dex/Search and emulator launch.

## Migration Phases

```
Phase 0 — Flutter scaffold                    ✅
Phase A — Native feel + persistence           ⚠️ icon/splash pending
Phase B — Useful companion                    ✅
Phase C — Save parser + single-file sync       ✅
Phase D — Dex + Cloudflare CDN v5 (1025)        ✅ v0.3.0+
Phase D+ — l10n/config bundle decoupling       ✅ v0.4.5+
Phase F/G — Reference filters + battle tools     ✅ partial v0.4.6
Next    — Ship CDN v5, DexScope UI, radar chart, reference lists, web pokedex
```

Original phase definitions (for planning):

```
Phase 0 — Flutter scaffold
  ├── flutter/ project with lib/, test/, pubspec.yaml
  ├── Port theme tokens + Nunito font
  ├── Rebuild DeviceShell + Home dashboard
  └── Wire routing + bottom navigation

Phase A — Native feel + persistence
  ├── Local journey store (mock template on first launch)
  ├── Splash, launcher icon, status bar, back button
  └── Keep DeviceShell; tune safe areas per form factor

Phase B — Useful companion
  ├── Continue: first tap → pick emulator app; remember; launch
  ├── Settings: edit trainer / game / location / badges / time
  └── Journey JSON import / export

Phase C — Save parser
  ├── Directory or file pick for `.sav`
  ├── HGSS metadata parser (see `PARSER_PROPOSAL.md`)
  └── Drive home screen from parsed summary + manual notes
```

## Important Notes for Contributors

### Repository layout during migration

- **React reference:** `src/`, `package.json`, root `android/` (Capacitor) — frozen.
- **Flutter active:** `flutter/lib/`, `flutter/test/`, `flutter/pubspec.yaml`.
- **Fixtures:** `fixtures/PKMSS.sav`, `flutter/assets/fixtures/PKMSS.sav`.
- **Tools:** `tools/probe_hgss_save.py`, `tools/hgss_map_list.json`, `tools/generate_hgss_map_list.py`.
- **Docs:** English for repository artifacts; Chinese for product discussions unless requested otherwise. Agent context: [`docs/AI_CONTEXT.md`](./AI_CONTEXT.md).

### Do not

- Start a second framework (React Native, Compose-only rewrite).
- Delete Capacitor sources before Flutter home is demo-ready on Android.
- Build a multi-generation parser framework before HGSS works end-to-end.
- Overwrite manual journey timeline notes when applying parser results.
- Commit user save files containing identifiable trainer data to public repositories — use reviewed fixtures only.

### Do

- Match existing visual language (no default Material chrome as the main look).
- Test on **phone portrait** and **720×720 square** (RG Rotate) early.
- Keep parser output partial-but-honest (`warnings[]` when fields fail).
- Use Android Storage Access Framework for save picking — no hard-coded `/sdcard/` paths.
- Run `cd flutter && flutter test` against `assets/fixtures/PKMSS.sav` before claiming HGSS support.

### Performance (RG Rotate / Unisoc class)

- Prefer static layouts and light animations.
- Avoid heavy blur and large uncompressed assets.
- Lazy-load Dex data; home screen stays lean.

### WebView issues (historical — for context only)

If maintaining the React build temporarily:

```css
-webkit-tap-highlight-color: transparent;
```

Replace navigation `<a>` tiles with `<button>` + router `navigate()` where tap flash matters. This is a band-aid, not the product direction.

## HGSS Save Fixture

Real SoulSilver saves checked in for parser development and tests:

| Path | Role |
| --- | --- |
| `fixtures/PKMSS.sav` | Repo-root copy for `tools/probe_hgss_save.py` |
| `flutter/assets/fixtures/PKMSS.sav` | Bundled asset; `flutter test` + Settings import |
| `src/PKMSS.sav` | Original upload (legacy) |

| Property | Value |
| --- | --- |
| Size | 524 288 bytes (retail NDS HGSS) |
| Game | Pokémon SoulSilver |
| Active partition | Chosen via save counter at `0xF618` (partition size `0x40000`) |

**Verified parse output** (`flutter/test/hgss_parser_test.dart`):

- Trainer: `ETeZ` · TID `22813` · 3 Johto badges
- Play time: `7:03:41`
- Location: 满金市 (map header ID `76`)
- Party: Quilava Lv27, Togepi Lv6, …

**Offsets used in Dart parser** (relative to active partition base):

| Field | Offset |
| --- | --- |
| Trainer name (OT) | `0x64`–`0x73` (Gen IV u16 text) |
| TID | `0x74` |
| Johto badges | `0x7E` (bitmask → popcount) |
| Play time | `0x86`–`0x89` |
| Party count | `0x94` |
| Party slots | `0x98` + 236 × n (decrypted; level from stats `0x8C`) |
| Map header ID | `0x1234` → `hgss_map_list.dart` |

References: [Project Pokémon HGSS save structure](https://projectpokemon.org/home/docs/gen-4/hgss-save-structure-r76/), `docs/PARSER_PROPOSAL.md`.

## Decision Log

| Date | Decision |
| --- | --- |
| Phase 1–2 | Capacitor + React chosen for fast mock and RG Rotate validation |
| Jul 2026 | Real-device test: WebView feel unacceptable for daily use |
| Jul 2026 | Rachel + Tito: prefer cross-platform custom UI → **Flutter** |
| Jul 2026 | `PKMSS.sav` added; HGSS parser prototype approved |
| Jul 2026 | DeviceShell retained; native shell + persistence + launcher prioritized |
| Jul 2026 | Flutter app in `flutter/` — parser, persistence, save sync, zh UI shipped |
| Jul 2026 | Save-directory auto-load on startup added (newest `.sav` by mtime) |
| Jul 2026 | Dex UI + offline cache + RG handheld polish (v0.2.20–0.2.23) |
| Jul 2026 | **Cloudflare dex CDN** live — `dex.tito.cafe`, bundle v4 PNG, Worker `tito-dex` |
| Jul 2026 | **v0.2.28** — typography spec, save dex flags, battle companion tools on Search |
| Jul 2026 | **Dex v5 expansion (planned v0.3.0)** — national 1–1025, CDN `/v3/` bundle v5, `DexScope` |
| Jul 2026 | **RG APK packaging** — SDK 36, `abiFilters arm64-v8a`, project upload keystore; uninstall before upgrade from local builds |

## Related Documents

- [Architecture](./ARCHITECTURE.md) — updated project shape and data layers
- [Roadmap](../ROADMAP.md) — phased delivery including Flutter migration
- [Parser proposal](./PARSER_PROPOSAL.md) — HGSS boundary and fixture usage
- [AI context](./AI_CONTEXT.md) — single source for agents (replaces scattered read-first notes)
