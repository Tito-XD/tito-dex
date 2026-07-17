# TitoDex — AI Context (single source of truth)

**Read this first** before editing code, docs, or releases. Human-facing overview: [README.md](../README.md).

| Field | Value |
| --- | --- |
| **Latest release** | [v0.6.6](https://github.com/Tito-XD/tito-dex/releases/tag/v0.6.6) |
| **`main` / lite source** | `0.6.6+77` (`flutter/pubspec.yaml`) |
| **Offline package** | `0.6.6-offline+78` — APK-bundled dex data |
| **Offline dex bundle** | **v5** — 1025 species, CDN prefix `/v3/` |
| **UI language** | Simplified Chinese (`flutter/lib/l10n/`) |
| **Primary target** | Android RG handheld (arm64-v8a, SDK 36) |

---

## What this project is

**TitoDex** is a warm, offline-first Pokémon journey companion for Android handhelds and phones. It combines save-aware progress, manual team and journey management, structured Pokédex data, and lightweight battle utilities in a distinctive device-like UI.

- **Resume quickly:** home shows current game, location, party, badges, play time, and actions.
- **Local first:** single-file save import, richer HGSS parsing, offline dex bundle, no runtime 52poke/PokeAPI scraping in the app.
- **Game context first:** edition, generation, and regional scope affect data and calculations.
- **Focused reference:** provide practical depth without reproducing a full community wiki or simulator.

Visual identity: blue-gray + cream + deep navy, sticker cards, `DeviceShell`, bundled Nunito — see [DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md), [UI_REFERENCE.md](./UI_REFERENCE.md).

---

## Repository layout

| Path | Role |
| --- | --- |
| **`flutter/`** | **Active app** — Flutter + Dart |
| `tools/` | Python: dex bundle build, zh catalog fetch, HGSS save probe |
| `cloudflare/dex-cdn/` | R2 proxy Worker (deploy branch `deploy/dex-cdn`) |
| `data/l10n/zh/` | Master zh catalog (git); copied to bundle + APK assets |
| `releases/` | RG APK binaries (`TitoDex-<ver>-rg-arm64.apk`) |
| `fixtures/` | Test saves (e.g. `PKMSS.sav`) |

---

## Current feature status (latest release line: v0.6.6)

> `main` matches the v0.6.6 release line. The offline package adds only the bundled dex seed and offline package version.

### Journey & save
- Experimental pre-Switch Gen 1–7 `.sav` metadata recognition; one explicitly selected save file with persisted read permission; optional startup reload. HGSS is fixture-verified and additionally imports party, map, and Pokédex progress.
- Home / Team / Journey / Settings; native Android installed-app picker and launcher; journey JSON import/export.
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
- v0.6.6: generation-scoped silhouette quiz with persisted best streak + adopt-as-companion, shiny companion sessions (Showdown shiny GIFs, disk-cached) with intimacy quote tiers / time-of-day greetings / pat-count persistence, crit + screen toggles and an assumptions note in quick damage, species-linked team editing, bundled official-style type icons, matched transition backdrop, repository cleanup.
- v0.6.5: save-diff banner scoping + dismissal, unified dex transition backdrop and timing (480/380 ms), submit-only recent searches (max 10), prominent current-game card in Settings, matchup grid overflow fix, companion size floor ×0.75, Chinese reference note for untranslated flavor text.
- v0.6.2.1: full-bleed launcher artwork lets Android adaptive-icon masks define the circle, squircle, rounded-square, or square silhouette.
- v0.6.2: companion size control, bundled starter GIF/cry media, and cancellable preload for other companions.
- v0.6.1: companion 2.0, landscape Home, bundled modern game icons, header polish, and Settings cleanup.
- v0.5.51 preview: Home Team and Search routes keep their designed entry/exit edge, while Team, Dex, and Search opt out of predictive-back progress.
- v0.5.5: single-file save import, native Android app picker, experimental Gen 1–7 save metadata, polished route/list motion, six-slot party layout, standby companion, shiny surprises, and silhouette quiz.
- v0.5.1: Android-standard route motion and predictive back; Home Team / Dex / Search cards expand into their matching first-level page, while all other routes use Material transitions.
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
- Broader real-save fixtures and validation beyond HGSS (more real saves incoming from the maintainer).
- Community (52poke) Chinese flavor-text import for older generations — planned as dex bundle v6; attribution (CC BY-NC-SA) is mandatory when it lands.
- Hand-drawn icons for the home quick tiles / entry cards (artwork in progress; the old bottom nav was removed). APK assets only, not on CDN.

> Cloud sync was dropped as a direction (2026-07): TitoDex stays local-first. Journey JSON import/export remains the portability path.

---

## Architecture (Flutter)

```
flutter/lib/
  app.dart                    # GoRouter, bootstrap, offline/update prompts
  features/
    dex/                      # PokeAPI, offline cache, CDN installer, l10n update
    journey/                  # JourneyRepository
    parser/                   # PokemonSaveParser, HgssParser, hgss_map_list
    save/                     # SaveSyncService, SaveFileRepository, document URI source
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
flutter test                    # regression gate; 193 tests
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
- `flutter pub get` on startup (the old root npm mock was removed in the 0.6.5 cleanup).

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
