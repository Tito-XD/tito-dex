# TitoDex Architecture

> **Active stack:** Flutter + Dart in `flutter/`. React under `src/` is a frozen design reference.  
> **Latest release:** v0.5.5; **`main` / lite:** `0.5.5+63`; **offline:** `0.5.5-offline+64` · Dex bundle v5 (`/v3/`).
>
> **Full agent context:** [AI_CONTEXT.md](./AI_CONTEXT.md)

**RG APK:** `TitoDex-<ver>-rg-arm64.apk` — arm64-v8a, SDK 36, ~21 MB. See [RELEASE_BUILD.md](./RELEASE_BUILD.md).

## Recommended Stack

**Flutter + Dart** (`flutter/` subdirectory)

| Concern | Choice |
| --- | --- |
| UI | Custom widgets — `DeviceShell`, sticker cards, bundled Nunito |
| Routing | `go_router` — shell route + bottom nav + dex detail |
| Persistence | `shared_preferences` — journey JSON + selected save URI/config |
| Save parsing | `PokemonSaveParser` — experimental Gen 1–7 metadata adapters; fixture-verified HGSS party/map/dex parsing |
| Save sync | `SaveSyncService` + `SaveFileRepository` — one persisted document URI, no directory scan |
| Dex online | `PokeApiClient` + throttle/retry |
| Dex offline | `DexOfflineService` — PokeAPI batch **or** `DexBundleInstaller` (CDN tar.zst) |
| Dex CDN | `DexCdnConfig` — compile-time URLs (not shown in app UI) |
| Artwork | `DexArtworkService` — lazy PNG full-size; local `artwork/` cache on tap |
| File picking | `file_picker` — directory path |
| Hashing | `package:crypto` SHA-256 (saves + bundle integrity) |
| Localization | Static Chinese maps in `lib/l10n/` |

### Legacy reference (Phase 2)

Capacitor + React + TypeScript + Vite — mock UI and tokens in `src/styles/tokens.css`. Not the shipping target.

## Target Devices

| Device | Status |
| --- | --- |
| Android phone / RG Rotate | Primary — `flutter/android/` |
| Linux handheld (future) | `flutter/linux/` scaffold present |
| Web preview | `flutter/web/` — save sync disabled (`dart:io`) |

Constraints:

- lightweight dashboard UI for Unisoc-class hardware
- custom visual language — not Material-default chrome
- **DeviceShell retained** on all form factors
- save access via user-selected directory (SAF-style folder pick), not hard-coded paths

## Architecture Goals

- local first
- Android first (Linux + web follow)
- responsive phone + square layouts
- simple data model
- game-scoped parser (HGSS only for now)
- dex CDN as a shared asset layer for the app and future clients

## Project Shape

### Flutter (active) — `flutter/`

```txt
flutter/
  lib/
    app.dart                      # Bootstrap, GoRouter, save sync hooks
    features/
      dex/                        # PokeAPI, offline cache, CDN installer, artwork
      journey/journey_repository.dart
      parser/                     # HgssParser, map list, Gen IV text/crypto
      save/                       # Single-file SaveSyncService + persisted document URI
      trainer/                    # Avatar service
    l10n/                         # app_zh.dart, game_zh.dart
    models/                       # journey.dart, parsed_save.dart
    navigation/                   # back_navigation, page transitions
    pages/                        # home, dex, detail, search, settings, …
    theme/                        # colors, typography, device_layout
    widgets/                      # DeviceShell, cards, artwork viewer, …
  test/                           # parser, dex CDN, layout, widget smoke
  assets/
    fixtures/PKMSS.sav
    fonts/Nunito-*.ttf
    companion/*.png
  android/ linux/ web/
```

Repo-level tooling & CDN:

```txt
fixtures/PKMSS.sav
releases/TitoDex-<ver>-rg-arm64.apk   # arm64-v8a only; see flutter/README.md
tools/
  build_dex_bundle.py             # CDN bundle v5 builder (+ l10n/maps/config)
  fetch_zh_catalog.py             # PokeAPI zh master catalog
  fetch_52poke_location_zh.py     # Incremental 52poke location labels
  stage_l10n_upload.py            # Stage l10n-only R2 upload
  probe_hgss_save.py
cloudflare/dex-cdn/               # Worker tito-dex → R2 titodex-dex
docs/CLOUDFLARE_DEX_CDN.md
```

### React (frozen reference) — `src/`

```txt
src/                    # Phase 2 mock — design reference only
android/                # Capacitor shell (legacy)
package.json
```

## Data Flow

### App bootstrap (`lib/app.dart`)

1. `JourneyRepository.load()` — prefs or `CurrentJourney.mock()`.
2. `SaveSyncService.syncOnStartup()` — if auto-load is enabled and a file is selected, re-read that exact `.sav` URI.
3. If sync updated journey → persist.
4. Render `HomePage` with current journey.

### Single-file save sync

```txt
User picks one .sav document (Settings)
  → Android persists read permission for that document URI
  → SaveFileRepository persists URI, display name, and auto-load flag
  → SaveSyncService re-reads only that URI
  → skip if the parsed hash is unchanged (unless force)
  → PokemonSaveParser.parseSummary() → toJourney(existing: …)
  → JourneyRepository.save()
```

### Dex offline (CDN path)

```txt
Settings → download CDN bundle
  → GET bundle-manifest.json (short TTL)
  → GET bundle.tar.zst + SHA256 verify
  → zstd decompress → dex_offline/ layout
  → manifest.complete=true, preferOffline=true
```

Sprites are **PNG** thumbnails in bundle; full **artwork** fetched lazily on tap (`v2/artwork/{id}.png` or PokeAPI fallback) into `dex_offline/artwork/`.

### Journey model highlights

- `trainerName` — display name (may be customized)
- `saveTrainerName` — raw decoded OT from last parse
- `trainerNameCustomized` — when true, re-import preserves display name
- `timeline`, `party`, `location`, `badges`, `playTime` — from mock or parser

## Data Layers

### 1. Default seed

`CurrentJourney.mock()` — Chinese SoulSilver sample data used when no saved state exists.

### 2. Local journey store

`JourneyRepository` — JSON in `shared_preferences`.

### 3. Save parser adapter

`ParsedSaveSummary` → `toJourney()` merges into `CurrentJourney`.

**Limitations today:**

- SoulSilver only; game string hardcoded
- Johto badges only (Kanto `0x83` not read)
- Partial Gen IV charset; ASCII trainer names only decode cleanly
- Retail 524 288 bytes only

See `PARSER_PROPOSAL.md` for full boundary.

### 4. Dex CDN layer (live)

R2 bucket `titodex-dex` behind Worker `tito-dex`. See `CLOUDFLARE_DEX_CDN.md` (maintainers).

### 5. Journey cloud sync

Not implemented. See `CLOUD_SYNC_PROPOSAL.md`.

## UI Routing

| Route | Screen | Status |
| --- | --- | --- |
| `/` | Home — trainer, continue, party, quick actions | ✅ |
| `/team` | Party list | ✅ |
| `/journey` | Timeline | ✅ |
| `/dex` | National dex grid | ✅ |
| `/dex/:id` | Detail — 4 tabs | ✅ |
| `/search` | Search | ✅ |
| `/settings` | Save sync, dex offline, journey tools | ✅ |

**Continue button:** picks / remembers emulator app and launches on subsequent taps.

## Responsive Strategy

- `DeviceShell` wraps all routes
- `DeviceLayout` — phone vs RG square vs compact handheld
- `HandheldInputShell` — D-pad / keyboard focus on RG
- `SafeArea` for notches and system bars
- Test at 360×780 phone and 720×720 square (RG Rotate)

## Native Boundaries

| Adapter | Location | Notes |
| --- | --- | --- |
| Journey prefs | `journey_repository.dart` | |
| Selected save file prefs | `save_file_repository.dart` | |
| Directory pick | `file_picker` in `app.dart` | |
| Save file read | `save_sync_service.dart` | `dart:io` — not on web |
| Parser | `hgss_parser.dart` | pure Dart |
| Dex bundle | `dex_bundle_installer.dart` | HTTP + zstd + tar |

## Testing

```bash
cd flutter && flutter test
```

| Test | Covers |
| --- | --- |
| `hgss_parser_test.dart` | Full PKMSS fixture |
| `dex_cdn_config_test.dart` | CDN URLs, manifest parsing |
| `device_layout_test.dart` | RG square / compact |
| `save_sync_test.dart` | Persisted URI, startup reload, clear permission, legacy-directory cleanup |
| `widget_test.dart` | App boot loading shell |

Manual: Settings single-file save selection on Android; CDN bundle download on RG; sideload `TitoDex-*-rg-arm64.apk` (verify `.so` are Stored with `unzip -lv`).

## Related Documents

- [Stack Decision](./STACK_DECISION.md) — status table, gaps, decision log
- [Flutter README](../flutter/README.md) — dev quick start
- [Cloudflare Dex CDN](./CLOUDFLARE_DEX_CDN.md) — R2 layout, build, deploy
- [Parser Proposal](./PARSER_PROPOSAL.md) — HGSS offsets and limits
- [Design System](./DESIGN_SYSTEM.md) — tokens ported to `tito_colors.dart`
