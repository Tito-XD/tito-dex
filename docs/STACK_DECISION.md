# Stack Decision: Flutter Migration

**Status:** Approved (July 2026)  
**Previous stack:** Capacitor + React + TypeScript + Vite  
**New stack:** Flutter + Dart

This document records why TitoDex is moving to Flutter, what stays the same, and what contributors should watch for during migration.

## Summary

TitoDex will be rebuilt on **Flutter** instead of continuing on the Capacitor WebView shell. The Phase 2 React mock app remains in the repository as a **design and product reference** until the Flutter port reaches feature parity on the home screen.

The decision is driven by real-device feedback (“feels like a webpage”), future target platforms (Linux handhelds, web), and native features (save import, emulator launcher) that are awkward in WebView.

## Why We Are Switching

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
5. **Screen set** — Home, Team, Journey, Dex, Search, Settings.
6. **Phase scope** — local persistence before cloud; HGSS parser before multi-generation framework.

## What Carries Over vs. What Gets Rewritten

| Keep (reference or port) | Rewrite in Flutter |
| --- | --- |
| `docs/` product & design direction | All `src/**/*.tsx` → Dart widgets |
| `tokens.css` values | `lib/theme/` |
| `mockJourney` structure | `lib/models/journey.dart` |
| `DeviceShell` layout concept | `lib/widgets/device_shell.dart` |
| `PARSER_PROPOSAL.md` types | `lib/features/parser/` in Dart |
| HGSS fixture `src/PKMSS.sav` | Same bytes; parser tests in `test/` |

The `android/` Capacitor project and `npm` scripts remain until Flutter replaces them for day-to-day builds. Do not delete the React tree until the Flutter home screen is usable on device.

## Migration Phases

```
Phase 0 — Flutter scaffold
  ├── Create Flutter project (e.g. `app/` or repo root `lib/`)
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
  ├── SAF file picker for `.sav`
  ├── HGSS metadata parser (see `PARSER_PROPOSAL.md`)
  └── Drive home screen from parsed summary + manual notes
```

## Important Notes for Contributors

### Repository layout during migration

- **React reference:** `src/`, `package.json`, `android/` (Capacitor) — frozen except critical fixes.
- **Flutter target:** new `lib/`, `pubspec.yaml`, `test/` — active development.
- **Docs:** English for GitHub; chat with Tito in Chinese (`docs/AI_READFIRST.md`).

### Do not

- Start a second framework (React Native, Compose-only rewrite).
- Delete Capacitor sources before Flutter home is demo-ready on Android.
- Build a multi-generation parser framework before HGSS works end-to-end.
- Overwrite manual journey timeline notes when applying parser results.
- Commit personal save files with identifiable trainer data to public repos without Tito’s OK — use fixtures intentionally.

### Do

- Match existing visual language (no default Material chrome as the main look).
- Test on **phone portrait** and **720×720 square** (RG Rotate) early.
- Keep parser output partial-but-honest (`warnings[]` when fields fail).
- Use Android Storage Access Framework for save picking — no hard-coded `/sdcard/` paths.
- Run parser unit tests against `src/PKMSS.sav` before claiming HGSS support.

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

A real SoulSilver save is checked in for parser development:

| Property | Value |
| --- | --- |
| Path | `src/PKMSS.sav` |
| Size | 524 288 bytes (standard NDS HGSS retail size) |
| Game | Pokémon SoulSilver (inferred from filename) |

Early probe (Gen IV small-block offsets, block 0) shows parseable structure:

- Trainer name at `0x64` (Gen IV u16 string — full charset table required)
- Johto badges at `0x7E` (bitmask)
- Kanto badges at `0x83` (bitmask)
- Play time at `0x86`–`0x89` (hours, minutes, seconds)
- Party count at `0x94`

**Parser must:** validate which of the two save blocks is current (footer checksum / counter), then read fields. See [Project Pokémon HGSS save structure](https://projectpokemon.org/home/docs/gen-4/hgss-save-structure-r76/) and `docs/PARSER_PROPOSAL.md`.

Planned relocation: `fixtures/saves/PKMSS.sav` once the Flutter `test/` harness exists.

## Decision Log

| Date | Decision |
| --- | --- |
| Phase 1–2 | Capacitor + React chosen for fast mock and RG Rotate validation |
| Jul 2026 | Real-device test: WebView feel unacceptable for daily use |
| Jul 2026 | Rachel + Tito: prefer cross-platform custom UI → **Flutter** |
| Jul 2026 | `PKMSS.sav` added; HGSS parser prototype approved |
| Jul 2026 | DeviceShell retained; native shell + persistence + launcher prioritized |

## Related Documents

- [Architecture](./ARCHITECTURE.md) — updated project shape and data layers
- [Roadmap](../ROADMAP.md) — phased delivery including Flutter migration
- [Parser proposal](./PARSER_PROPOSAL.md) — HGSS boundary and fixture usage
- [AI read-first](./AI_READFIRST.md) — contributor guardrails
