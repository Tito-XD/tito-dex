# TitoDex — AI Context (single source of truth)

**Read this first** before editing code, docs, or releases. Human-facing overview: [README.md](../README.md).

| Field | Value |
| --- | --- |
| **Latest release** | [v0.5.0](https://github.com/Tito-XD/tito-dex/releases/tag/v0.5.0) |
| **`main` / lite** | `0.5.0+54` (`flutter/pubspec.yaml`) |
| **Offline package** | `0.5.0-offline+55` — APK-bundled dex data |
| **Offline dex bundle** | **v5** — 1025 species, CDN prefix `/v3/` |
| **UI language** | Simplified Chinese (`flutter/lib/l10n/`) |
| **Primary target** | Android RG handheld (arm64-v8a, SDK 36) |

---

## What this project is

**TitoDex** is a warm, offline-first Pokémon journey companion for Android handhelds and phones. It combines save-aware progress, manual team and journey management, structured Pokédex data, and lightweight battle utilities in a distinctive device-like UI.

- **Resume quickly:** home shows current game, location, party, badges, play time, and actions.
- **Local first:** HGSS save parsing, offline dex bundle, no runtime 52poke/PokeAPI scraping in the app.
- **Game context first:** edition, generation, and regional scope affect data and calculations.
- **Focused reference:** provide practical depth without reproducing a full community wiki or simulator.

Visual identity: blue-gray + cream + deep navy, sticker cards, `DeviceShell`, bundled Nunito — see [DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md), [UI_REFERENCE.md](./UI_REFERENCE.md).

---

## Repository layout

| Path | Role |
| --- | --- |
| **`flutter/`** | **Active app** — Flutter + Dart |
| `src/` | **Frozen** React/Vite design reference — do not add features |
| `tools/` | Python: dex bundle build, zh catalog fetch, HGSS save probe |
| `cloudflare/dex-cdn/` | R2 proxy Worker (deploy branch `deploy/dex-cdn`) |
| `data/l10n/zh/` | Master zh catalog (git); copied to bundle + APK assets |
| `releases/` | RG APK binaries (`TitoDex-<ver>-rg-arm64.apk`) |
| `fixtures/` | Test saves (e.g. `PKMSS.sav`) |

---

## Current feature status (latest release line: v0.5.0)

> `main` includes the v0.5.0 release line. The offline package adds only the bundled dex seed and offline package version.

### Journey & save
- HGSS retail 512 KB `.sav` parser; directory sync (newest by mtime); startup auto-load.
- Home / Team / Journey / Settings; emulator launcher; journey JSON import/export.
- Manual dex marks when save not linked.

### Dex (national 1–1025)
- Grid + search; 4-tab detail (简介 / 基本信息 / 获取 / 招式).
- **23 game editions**, **11 regional dexes**, `DexScope` filters.
- Offline: CDN pre-built bundle (Settings) or legacy PokeAPI batch.
- Bundle includes: summaries, precomputed filter catalog, details, sprites, moves, abilities, **l10n/zh**, **maps**, **config**, game icons.
- Chinese location labels via zh catalog; HGSS map id lookup.

### Search hub
- **常用资料:** moves, abilities, natures, egg groups, items, weather, terrain, status.
- **对战资料:** type matchup, stat calc, quick damage (partial).
- Reference → **structured detail** + drill-down to dex filter (move / ability / egg group).
- `/search?q=` deep link supported.

### Latest release-line highlights
- v0.5.0: precomputed Dex catalog keeps list, search, and reference filters in memory; home no longer blocks on a looping bootstrap bar.
- v0.4.99: source-line consolidation and aligned lite/offline packages.
- v0.4.98: per-game titles in the flavor-text carousel for paired editions.
- v0.4.95–v0.4.97: trainer-card bootstrap and square layout, loading panels, team editor improvements, download progress/cancel, and copy cleanup.
- v0.4.94: compact Settings sections and paginated dex filter results.
- v0.4.93: ability fallback, game labels, obtain-location coverage, and ability filters.
- v0.4.85: Terastal, held items, status, defensive abilities, and team shared weaknesses.
- v0.4.8: generation-aware matchup modifiers and offensive/defensive blind-spot tools.

### Not shipped / partial
- Full competitive damage calculator, IV-specific workflow, usage rankings, and simulator parity.
- Journey cloud sync ([CLOUD_SYNC_PROPOSAL.md](./CLOUD_SYNC_PROPOSAL.md)).
- Custom launcher icon; HeartGold title detection; single-file `.sav` picker.
- Nav hand-drawn icons: **APK assets only**, not on CDN.

---

## Architecture (Flutter)

```
flutter/lib/
  app.dart                    # GoRouter, bootstrap, offline/update prompts
  features/
    dex/                      # PokeAPI, offline cache, CDN installer, l10n update
    journey/                  # JourneyRepository
    parser/                   # HgssParser, hgss_map_list
    save/                     # SaveSyncService, SaveScanner
    companion/                # Battle math, type relations
    game/                     # GameEdition, regional dex
  config/app_config.dart      # Offline-first app configuration
  l10n/                       # app_zh.dart, game_zh.dart, zh_catalog.dart
  pages/                      # home, dex, search, settings, companion tools
  widgets/                    # DeviceShell, dex_reference_detail, …
```

**Routing:** `/`, `/team`, `/journey`, `/dex`, `/dex/:id`, `/search`, `/settings`, companion sub-routes under `/search/companion/*`.

**Dex offline dir** (`dex_offline/` in app documents): mirrors CDN bundle — see [CLOUDFLARE_DEX_CDN.md](./CLOUDFLARE_DEX_CDN.md).

**Load order for reference data:** `dex_offline/` → APK `assets/` fallback.

---

## Dex CDN (maintainers)

| CDN prefix | Bundle version | Species |
| --- | --- | --- |
| `/v2/` | v4 | 493 (legacy) |
| `/v3/` | v5 | 1025 (current) |

- Config: `flutter/lib/features/dex/dex_cdn_config.dart` (compile-time `TITODEX_DEX_*` env).
- **Do not** paste production CDN URLs in public README / release notes.
- Build: `python3 tools/build_dex_bundle.py --cdn-base "$TITODEX_DEX_CDN_BASE" --output dist/dex-v5 --max-id 1025`
- Secrets: [PERMISSIONS.md](./PERMISSIONS.md) — `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`.

---

## Build, test, release (RG APK)

```bash
cd flutter
flutter pub get
flutter test                    # regression gate; baseline is approximately 115 tests
flutter build apk --release --target-platform android-arm64  # ~21 MB
../tools/verify_release_apk.sh build/app/outputs/flutter-apk/app-release.apk
cp build/app/outputs/flutter-apk/app-release.apk ../releases/TitoDex-<ver>-rg-arm64.apk
```

| Rule | Detail |
| --- | --- |
| ABI | arm64-v8a only |
| Filename | `releases/TitoDex-<ver>-rg-arm64.apk` |
| SDK | compile/target 36, min 24 |
| Size | ~20–23 MB; verify script must PASS |
| Signing | `flutter/android/key.properties` + upload keystore |

Full checklist: [RELEASE_BUILD.md](./RELEASE_BUILD.md).

Bump `flutter/pubspec.yaml` **before** building. Tag `v<x.y.z>` + GitHub Release with APK asset.

---

## Cloud agent / VM environment

- **Flutter 3.44+** at `~/flutter/bin` (on PATH in login shells).
- **Web** is the default dev target when no Android SDK; `flutter run -d chrome`.
- **APK builds** require Android SDK + release keystore (may be unavailable in some cloud VMs).
- Root `npm install` + `flutter pub get` on startup.

**Web caveat:** Settings / Search / Dex sub-pages may hit `No Material widget found` on web (missing Scaffold in some scaffolds). Real target is Android RG. Home / Team / Journey work on web for smoke tests.

**Known baseline:** `flutter analyze` may report pre-existing infos; `flutter test` is the regression gate.

Optional tooling venv: `~/.venv-titodex-tools` (`tools/dex_bundle_requirements.txt`).

---

## Contributor guardrails

### Do
- Edit **`flutter/lib/`** and **`flutter/test/`** only for product work.
- Default UI copy in **Chinese** (`app_zh.dart`, `game_zh.dart`).
- GitHub artifacts (commits, PRs, releases) in **English** unless user asks otherwise.
- Prefer small, focused diffs; match existing patterns.
- Run `flutter test` before pushing.

### Do not
- Add features to `src/` (React mock).
- Runtime-fetch 52poke/PokeAPI for zh catalog in the app.
- Put hand-drawn nav icons on CDN (APK assets only).
- Expand TitoDex into a full wiki mirror or competitive simulator without an explicit product decision.
- Overwrite manual journey timeline on save import without merge rules ([PARSER_PROPOSAL.md](./PARSER_PROPOSAL.md)).
- Publish private CDN base URLs in user-facing copy.

---

## Localization

- UI: `lib/l10n/app_zh.dart`
- Game terms / locations: `lib/l10n/game_zh.dart`
- Zh catalog runtime: `lib/l10n/zh_catalog.dart` (offline l10n first)
- No ARB / locale switching yet

---

## Human documentation index

| Doc | Purpose |
| --- | --- |
| [README.md](../README.md) | Project intro, quick start |
| [VISION.md](../VISION.md) | Product feeling & philosophy |
| [PRODUCT.md](../PRODUCT.md) | Feature positioning |
| [ROADMAP.md](../ROADMAP.md) | Release history & what's next |
| [RELEASES.md](./RELEASES.md) | Standardized GitHub Release copy archive |
| [ARCHITECTURE.md](./ARCHITECTURE.md) | Technical structure |
| [STACK_DECISION.md](./STACK_DECISION.md) | Why Flutter; migration notes |
| [RELEASE_BUILD.md](./RELEASE_BUILD.md) | APK checklist |
| [CLOUDFLARE_DEX_CDN.md](./CLOUDFLARE_DEX_CDN.md) | R2 / Worker / bundle layout |
| [PERMISSIONS.md](./PERMISSIONS.md) | GitHub Actions secrets |
| [DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md) | Colors, typography |
| [PARSER_PROPOSAL.md](./PARSER_PROPOSAL.md) | Save parser design |
| [JOURNEY_PROFILE_PLAN.md](./JOURNEY_PROFILE_PLAN.md) | Journey UX plans |

Legacy handoff docs under `docs/handoff/` are historical — prefer this file for current state.

---

## Communication

- Product discussions use **Chinese** by default; repository artifacts use **English** unless a task requests otherwise.
- When unsure between reference breadth and playthrough utility, choose **playthrough utility**.
