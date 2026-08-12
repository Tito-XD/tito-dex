# TitoDex — AI Context (single source of truth)

**Read this first** before editing code, docs, or releases. Human-facing overview: [README.md](../README.md).

| Field | Value |
| --- | --- |
| **Latest release** | [v0.8.13](https://github.com/Tito-XD/tito-dex/releases/tag/v0.8.13) |
| **`main` / lite source** | `0.8.13+154` (`flutter/pubspec.yaml`) |
| **Offline package** | `0.8.13-offline+155` — APK-bundled verified compact v14 archive; updates to live v19 |
| **Journey Assistant** | `1.0.0+1` — optional same-signer content APK; three reviewed HGSS blocker chains |
| **Offline dex bundle** | **v19** live on CDN; Offline APK embeds compact **v14** — 1025 species, 803 form records, complete item text/icons, audited form media, CDN prefix `/v5/`; `/v4/` rollback |
| **UI language** | Simplified Chinese (`flutter/lib/l10n/`) |
| **Primary target** | Android RG handheld (arm64-v8a, SDK 36) |

---

## What this project is

**TitoDex** is a warm, offline-first Pokémon journey companion for Android handhelds and phones. It combines save-aware progress, manual team and journey management, structured Pokédex data, and lightweight battle utilities in a distinctive device-like UI.

- **Resume quickly:** home shows current game, location, party, badges, play time, and actions.
- **Local first:** single-file save import, richer HGSS parsing, offline dex bundle, no runtime 52poke/PokeAPI scraping in the app.
- **Game context first:** edition, generation, and regional scope affect data and calculations.
- **Focused reference:** provide practical depth without reproducing a full community wiki or simulator.

Visual identity: blue-gray + cream + deep navy, sticker cards, `DeviceShell`, bundled Nunito — see [DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md).

---

## Repository layout

| Path | Role |
| --- | --- |
| **`flutter/`** | **Active app** — Flutter + Dart |
| `tools/` | Python: dex bundle build, zh catalog fetch, HGSS save probe |
| `cloudflare/dex-cdn/` | R2 proxy Worker (deploy branch `deploy/dex-cdn`) |
| `cloudflare/journey-assistant/` | Independent optional HGSS blocker-Q&A Worker; trial endpoint deployed with content/Search still disabled |
| `data/journey/` | Canonical progression hints and strict request/data schemas |
| `data/extensions/` | Canonical companion APK catalog and pack-manifest schemas |
| `flutter/android/journey-assistant-pack/` | Independently installable, no-launcher Journey Assistant content APK |
| `data/l10n/zh/` | Master zh catalog (git); copied to bundle + APK assets |
| `releases/` | RG APK binaries (`TitoDex-<ver>-{lite,offline}-rg-arm64.apk`) |
| `fixtures/` | Test saves (e.g. `PKMSS.sav`) |

---

## Current feature status (latest release line: v0.8.13)

> v0.8.13 is the latest published release. Lite downloads live bundle v19 when requested; Offline embeds the verified compact v14 archive and can update to the newer live data. Android signing was rotated; upgrades from v0.8.12 or earlier require export, uninstall, and reinstall.

### Journey & save
- **Shipped in v0.8.13:** independently installable Journey Assistant APK, Journey install CTA, Settings management, configurable Search entry, and three reviewed HGSS blocker chains. Installed provider facts and parsed-save reliability are preferred; local fuzzy matching runs first. AI Search uses BGE-M3 only to retrieve audited `hintId`s; public inference defaults to Workers AI, while DeepSeek requires an explicit private gate. The App reaches R2 catalog/APK, Search, and Gateway only through the Journey Assistant Worker. The strict request excludes raw saves, hashes, trainer/party/financial/coordinate data. See [JOURNEY_ASSISTANT.md](./JOURNEY_ASSISTANT.md) and [EXTENSIONS.md](./EXTENSIONS.md).
- Experimental pre-Switch Gen 1–7 `.sav` metadata recognition; one explicitly selected save file with persisted read permission; optional startup reload. HGSS is fixture-verified and additionally imports party species/level/HP/EXP/ability/four moves, map, both regional badge banks, and Pokédex progress.
- Home / Team / Journey / Settings; native Android installed-app picker and launcher; journey JSON import/export.
- Manual dex marks when save not linked.
- v0.8.8: Android long-press app shortcuts default to Dex + Search and are configurable in Settings (up to three destinations from dex sub-pages, reference catalogs and battle tools); HGSS counts both badge banks, and DeSmuME `.dsv` wrappers are recognized.
- v0.8.8: save import preserves the numeric trainer ID for Journey/Settings; the Journey card shows a lightweight current-location capture reminder, while the Journey page expands nearby uncaught species, party evolution routes, paired-version direct-encounter gaps, and evolution/breeding/trade completion gaps. Unknown locations and merged editions show explicit prompts instead of guessed advice.
- v0.8.9: unknown Android document timestamps no longer become 1970, and the latest Journey event records TitoDex import time. HGSS displays 城都 x/8 + 关都 y/8; parsed ability/moves/EXP flow into Team and can hand a damaging move to quick damage. Manually customized trainer identity remains protected by the existing override rules.
- v0.8.10: HGSS rich sync adds party nicknames, held items, move PP/PP Ups, friendship, nature, shiny/gender/status, IV/EV and battle stats, plus Secret ID, money, trainer gender/language, starter, player coordinates and save milestones. Current/max HP offsets are corrected against the Gen IV party structure. The Team expansion and Journey/Settings read-only summaries expose the imported fields; PC boxes remain deferred until big-block selection is independently fixture-verified.

### Dex (national 1–1025)
- Grid + form-name search; 4-tab detail (简介 / 基本信息 / 获取 / 招式) with a form switcher.
- **23 game editions**, **11 regional dexes**, and persisted G1–G9 debut-generation browse scopes. Primary browse scope intersects with body/color/size/reference filters.
- Offline: CDN pre-built bundle (Settings) or legacy PokeAPI batch.
- Offline APK first install/upgrade shows a blocking local preparation dialog with continuous percentage across read → SHA-256 → decompress → extract → index. Lite and already-ready Offline installs never show it. Settings downloads can be minimized on Android: a `dataSync` foreground service keeps the Dart install active and mirrors the weighted percentage into a notification; returning to Settings restores progress and cancellation controls. Cancelling, swiping the app task away, or an Android 15 service timeout stops native foreground work so stale progress cannot remain in the notification drawer.
- Bundle includes: summaries, precomputed filter catalog, details, all form JSON, selective distinct-form sprites, moves, abilities, **l10n/zh**, **maps**, **config**, and game icons. It does not bulk-copy form artwork.
- **Per-form evolution chains** (bundle v13+): regional / cloak splits prune to the real line (洗翠卡蒂狗 → 洗翠风速狗) with form sprites. Older installs fall back to the in-app `kFormEvolutionTargets` table via `EvolutionNode.filteredForForm`. Offline loading absolutizes `sprites/forms/…` paths on `forms[].evolutionChain`.
- **Per-version artwork picker:** exact front/back/animated availability is generated from a pinned PokeAPI/sprites Git tree (`data/dex/sprite_version_existence.json`). The app intersects real file existence with national-debut caps, so regional subsets such as BDSP/SV do not silently fall back to the default image; synthetic legacy `/sprites/by-version/` URLs are ignored. Per-version media remains online-only.
- **Species filter sheet icons:** body-style chips use original vector creature marks that preserve the recognisable HOME poses and white eyes (`DexShapeIcon`); size chips use relative discs (`DexSizeIcon`); colour stays as swatches. Icons ship in the APK only.
- Per-form exact-version locations preserve `speciesId`, `pokemonId`, `formKey`, `teraType`, `formAmbiguous`, alpha/titan/raid/fixed flags; modern overlays cover BDSP, Legends: Arceus, Sword/Shield+DLC, Scarlet/Violet+DLC, Z-A, and Mega Dimension. Champions is explicitly not applicable.
- Chinese location labels prefer game `zh-Hans` resources for modern overlays, then the maintained catalog; HGSS retains map-id lookup.
- Detail flavor icons are APK-local and precached; evolution alternatives and encounter methods/conditions render from structured bundle fields with Chinese fallbacks. Version planning shows wild held items, paired-version gaps, and chain completion routes. Bundle v16 added 52poke SwSh / BDSP / LA / SV / Z-A held-item coverage: 520 species with held items plus 52 previously missing items (`HELD_ITEMS_ATTRIBUTION.txt`). v0.8.8 applies `MechanicsProfile` gates so unavailable alternative evolution routes do not make a version plan look self-contained.
- v0.8.9: `/dex/locations` uses a compact responsive area grid; tapping an area opens a draggable missing-first encounter sheet and preserves direct dex/form navigation. No interactive map is planned.
- v0.8.10 fix rebuild: the Dex content remains mounted in one stable route layer when the home-card Hero extra disappears on a nested detail push. PageStorage no longer competes with the explicit browse session; detached controllers preserve their last real offset, and async list restoration waits for content extent before applying it.
- Form metadata now reaches the UI consistently: event-only, historical, current-version availability/obtainability, introduction version, incomplete data, and inherited fallback states are all labelled instead of remaining bundle-only flags.

### Items (reference hub → 道具)
- **Full item catalog (bundle v19):** 2130 items across 16 `categoryZh` groups with 2130/2130 Chinese descriptions and 2130/2130 local icons. Shared artwork is explicit: 300 Dynamax Crystals, 100 TRs, 230 type-mapped TMs, 25 TM materials, and other intentional template groups are not counted as unique art. Only `bw-grass-tablecloth` remains an explicitly labelled generic-template fallback. The audit now assigns explicit or inherited-pipeline provenance to every record; no item remains unclassified.
- **Form media catalog (bundle v19):** 1025 species and 803 forms (554 alternates) are audited independently by static, shiny static, animated, shiny animated, and cry availability. Alternate coverage is 548 / 497 / 386 / 386 / 554; 143 have form-specific cries. Six Koraidon/Miraidon ride modes have no separate upstream static artwork and remain named gaps rather than borrowing another mode. `data/dex/form_media_audit.json` is the machine-readable source of truth.
- PokeAPI media uses one pinned `PokeAPI/sprites` commit and a generated exact-file manifest; 52poke art uses MediaWiki `imageinfo` plus successful original-file requests. The app maps catalog records directly to `formKey`, separates normal/shiny and static/animated candidates, caches selected art, and never gives same-ID cosmetic forms the default animation. Cry matching is explicit rather than suffix substring guessing.
- Data source priority: PokeAPI (lowercase `zh-hans`) for names and in-game descriptions, then 52poke for gaps and newer original-resolution bag icons. 52poke original wiki content is CC BY-NC-SA 3.0; official game media found through its file pages retains its underlying rights and must not be blanket-labelled as CC content. Item icons are bundled rather than hotlinked; cries/animations/HOME art remain online and cached on demand.
- Icons: `item-sprites/*.png` ship both as loose `/v5/` CDN objects (online, CDN-first) **and inside `bundle.tar.zst`** (offline). Offline the app rewrites the CDN `spriteUrl` to the local bundle file (`dex_offline/item-sprites/<slug>.png`).
- Build: `tools/build_items_dataset.py` → `tools/enrich_items_52poke.py` / `enrich_items_52poke_search.py` → `tools/patch_dex_bundle_v11_items.py`. The category-filter option list in `flutter/lib/pages/dex/dex_json_reference_page.dart` must stay in sync with the `categoryZh` groups.
- Attribution ships in the bundle as `ITEMS_ATTRIBUTION.txt`.
- v0.8.9 bundles an APK-local item matrix derived from the attributed v19 catalog, official PokeAPI CSV data, and cached 52poke source pages: 1465 items have version-group availability, 18 retain exact paired-version exclusivity, and 1114 have game-scoped prices. Unknown/new-game coverage stays visible as unknown instead of being hidden or assigned a guessed price. A second 833-move matrix filters removed/reintroduced moves by version group; generation gates cover abilities and the smaller mechanics references.

### Search hub
- **常用资料:** moves, abilities, natures, egg groups, items, weather, terrain, status.
- **对战资料:** type matchup, stat calc, quick damage (partial).
- Moves filter by all 18 types; abilities, natures, egg groups, weather, and status expose compact category filters that intersect with text search. Items keep their existing categories; terrain stays ungrouped because it has only four entries.
- Reference → **structured detail** + drill-down to dex filter (move / ability / egg group).
- `/search?q=` deep link supported.
- **Multi-word species search** (`dex_search_terms.dart`). Each whitespace-separated word resolves to one constraint through an alias table (神 / 传说 / legendary all reach the legendary tag); words of different kinds AND. Single-valued kinds (body style, colour, generation, size) OR with each other, because a species holds exactly one of each and ANDing two could only return nothing — that is what lets 「棕 红」 stand in for the orange the in-game palette lacks. Types and tags are genuinely multi-valued and still AND, so 「火 飞行」 means the dual type.
- An alias never suppresses a text match: 「鱼」 resolves to the fish body style **and** still finds 鲤鱼王. Genus is searchable because it rides on the summary.
- **Stackable dex axes** (`DexFilter`): body style × colour (multi-select set) × relative size × generation × tag, intersected with at most one reference drill-down. Size buckets are cut from the real 1025-species height distribution (~19/29/24/16/13 %).
- Body style labels are the canonical 52poke names. The eight species reclassified in Gen VI (绿毛虫 / 独角虫 / 刺尾虫 / 结草儿 / 结草贵妇 / 无壳海兔 / 海兔兽 / 克雷色利亚 — all present in HGSS) match under **both** the current and the pre-Gen VI body style.

### Pokémon Sleep tools
- v0.8.11 replaces the link-only Search section with a reachable `/search/sleep-tools` secondary page while retaining Neroli’s Lab website, guide, and documentation links.
- Offline sleep-score estimation supports same-day and across-midnight sessions and caps at 100 after 8 h 30 min.
- Basic cooking-strength estimation exposes all 19 current ingredient base values, recipe levels 1–70, the recipe-specific bonus input, and weekday/Sunday critical references. It deliberately does not claim to be the full recipe, pot, inventory, team-production, or long-term simulator.
- Formula/value ports are pinned to Neroli’s Lab commit `cb533f240a0551da315151c310b4dbd165091672` under Apache-2.0. The complete license and upstream NOTICE ship in APK assets and are registered in Flutter’s license page. Chinese ingredient names follow the 52Poké Pokémon Sleep ingredient catalog under CC BY-NC-SA 3.0.

### Data → behavior → UI alignment audit (2026-08-08)

| Runtime data | Behavior | Reachable UI |
| --- | --- | --- |
| Parsed save metadata / rich HGSS party records / dex flags | journey merge, progress, edition auto-selection, battle handoff | Home, Team expansion, Journey, Settings, Dex status, quick damage |
| Summaries + `dex_catalog.json` | browse, search, stacked species axes | Dex and Search |
| Per-species details + forms | type/stat/ability/obtain/move/evolution planning | Four detail tabs + form selector |
| `version_availability_index.json` | evolution/breeding/trade missing classification | Dex progress filter + Journey assistant |
| `location_index.json` | selected-version area tree and save-location match | Compact Location Dex grid/sheet + Journey card/page |
| Moves + `move_version_matrix.json`; items + `item_version_matrix.json`; abilities, natures, egg groups, weather, terrain, status | selected-game filtering, scoped prices, reference search/detail and supported species drill-down | Search reference hub, Team assistance, quick damage + configurable app shortcuts |
| `media_catalog_52poke.json` | form-aware art/animation/cry candidates | companion, picker, media resource page |
| `app_config.json` + pinned Sleep formula/value constants | remotely updateable external links plus deterministic offline calculations | Search → Pokémon Sleep section → dedicated secondary page |

`form_media_audit.json`, `item_media_audit_v19.json`, attribution files,
`games.json`, and `types.json` are bundle verification/build provenance rather
than dormant product features; they intentionally have no raw end-user page.
The audit removed unused `DexFilter.natureSlug` / `itemId` states instead of
advertising filters with no implementation. No confirmed runtime feature is
left without a UI entry after this pass.

Human-visible attribution is maintained in root `CREDITS.md`,
`THIRD_PARTY_NOTICES.md`, and Settings → “关于 TitoDex · 数据来源与许可”.
Settings also exposes Flutter's package notices plus the explicitly registered
Nunito OFL and PokéSprite MIT licenses. The always-visible Settings notice states
that TitoDex is an unofficial learning/personal-play tool with no affiliation,
authorization, sponsorship, or endorsement by Nintendo, Creatures, GAME FREAK,
The Pokémon Company, or their affiliates.

**Attribution correction (2026-08-10):** source metadata now uses 52poke's
official CC BY-NC-SA 3.0 site license, PokeAPI/PokeAPI api-data BSD-3-Clause,
and treats PokeAPI/sprites/official media as rights-varying instead of applying
an unsupported blanket Creative Commons claim. Live bundle v19 is immutable and still carries historical
attribution text; publish corrected bundle metadata only under a new bundle
version/object set rather than overwriting v19 objects.

### Latest release-line highlights
- v0.8.13: ships the optional Journey Assistant 1.0.0, save-first local fuzzy matching, audited BGE-M3 retrieval and Workers AI Qwen fallback for three HGSS blocker chains; rotates the Android signer after legacy material was found in public history.
- v0.8.12: enlarges and rebalances the immersive RG home Trainer Card, gives normal handheld Journey metadata two readable lines with a compact fallback, adds small top/bottom optical insets, and consolidates obsolete handoffs, phase plans, UI fragments and one-shot CDN workflows into current canonical documentation plus Git history.
- v0.8.11: adds offline Pokémon Sleep score and basic cooking-strength tools from a pinned Neroli’s Lab commit, bundles its Apache-2.0 license/NOTICE, and completes the attribution correction across 52Poké, PokeAPI/sprites, PokéSprite, Nunito, game icons, generated media metadata, Settings, and public documentation.
- v0.8.10: expands fixture-verified HGSS sync into rich party and trainer data, corrects current/max HP parsing, keeps the Dex route mounted and its return position stable across nested detail navigation, and makes complete data/media credits plus the unofficial-project notice visible in Settings and both READMEs.
- v0.8.9: repairs media resource management and adds retry; makes companion positioning full-screen and smooth; scopes items, prices, moves and mechanics to the selected game/generation; compacts Location Dex into a missing-first drill-down; and connects parsed party abilities/moves/evolution routes to Team and quick damage. HGSS shows separate Johto/Kanto badge progress, Journey sync time is corrected, and exact HeartGold/SoulSilver selection is no longer represented by a hard-coded SoulSilver team heading.
- v0.8.8: completes the three-phase correctness and UI closure: hardened l10n/release source binding, configurable Android app shortcuts, location dex, mechanics-aware evolution planning, improved save parsing and fixture gates, canonical Chinese dex axes, explicit battle assumptions, and a Journey save assistant that connects location, party evolution and exact-version completion data. Runtime data-to-UI alignment is audited and covered by 373 Flutter tests.

Earlier release history belongs in [RELEASES.md](RELEASES.md), [ROADMAP.md](../ROADMAP.md),
GitHub Releases, and Git history; this agent context keeps only the active release line.

### Not shipped / partial
- Beyond the IV/EV inputs already exposed in stat calc: full competitive damage calculator, dedicated IV workflow, usage rankings, and simulator parity.
- More reviewed real-save fixtures beyond the bundled SoulSilver save. The manifest-driven fixture matrix is ready for maintainer-provided saves.

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

**Routing:** `/`, `/team`, `/journey`, `/dex`, `/dex/:id`, Dex sub-routes
(`moves`, `abilities`, `locations`, `quiz`), `/search`, companion tools,
`/search/sleep-tools`, `/search/reference/json`, `/journey/ask`, `/settings`, and Settings
media/companion-position sub-routes.

**Dex offline dir** (`dex_offline/` in app documents): mirrors CDN bundle — see [CLOUDFLARE_DEX_CDN.md](./CLOUDFLARE_DEX_CDN.md).

**Reference-data priority:** a complete/preferred offline install reads `dex_offline/` first and only uses CDN for a missing file; Lite reads CDN first and falls back to any local cache. The Offline APK seed is installed into `dex_offline/` before it is used.

---

## Dex CDN (maintainers)

| CDN prefix | Bundle version | Species |
| --- | --- | --- |
| `/v2/` | v4 | 493 (legacy) |
| `/v3/` | v5 | 1025 (rollback / older clients) |
| `/v4/` | v6 | 1025 + forms + exact-version modern encounters (rollback) |
| `/v5/` | **v19** | current — v13 form evolution + v14 compact archive + v15 zh flavor + v16 held items + v17 full items + v18 online-media catalog + v19 audited form media and complete item text/icons |

Bundle v19 was built with `tools/patch_dex_bundle_v19_items.py`,
`tools/audit_item_media_v19.py`, `tools/verify_dex_v19_items.py`, and the
version-specific `.github/workflows/upload-dex-bundle.yml`. That workflow
requires live v18 as its base and must not be used to republish now that live
production is v19. A future bundle needs a new version-specific workflow with
v19 as the explicit read-only production precondition; stage changed `/v5/`
objects first and switch the root manifest last.

- Config: `flutter/lib/features/dex/dex_cdn_config.dart` (compile-time `TITODEX_DEX_*` env).
- **Do not** paste production CDN URLs in public README / release notes.
- **Bundle version and CDN prefix are decoupled.** Every release since v7 patched in place over the same `/v5/` prefix; immutability applies to individual object keys, not the prefix. Reading `/v5/` as "bundleVersion 7" wrongly implies a new `/v6/` is needed.
- v14 compact-media seed: `python3 tools/patch_dex_bundle_v14_compact_media.py`. It byte-compares all 1,340 `artwork/` files against their `sprites/` peers before removing only the duplicate archive copies; loose online artwork remains in R2. Offline APKs still reuse its verified 54,746,615-byte archive while installed copies can update to live v19.
- Body style / colour / growth rate / habitat Chinese labels are canonical in `data/l10n/zh/dex_axes.json`; Flutter's fallback map is generated from it. New bundle builds persist labels beside slugs, while v19 remains compatible through the APK fallback.
- Release order: upload and verify every immutable `/v5/` object, then update root `bundle-manifest.json` last. Never overwrite or delete `/v4/`. Clients only upgrade when `remote.bundleVersion > local.version`.
- Worker state uses a dedicated `MANIFEST_KV` namespace for hot manifest cache and last health/dispatch records; never bind the unrelated `FODI_CACHE`.
- Secrets: [PERMISSIONS.md](./PERMISSIONS.md) — `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID` (and optional `R2_*` for bulk upload).

---

## Build, test, release (RG APK)

```bash
cd flutter
flutter pub get
flutter test --no-pub           # regression gate
flutter build apk --release --target-platform android-arm64  # ~21 MB Lite / ~80 MB compact Offline
../tools/verify_release_apk.sh build/app/outputs/flutter-apk/app-release.apk
cp build/app/outputs/flutter-apk/app-release.apk ../releases/TitoDex-<ver>-lite-rg-arm64.apk
```

| Rule | Detail |
| --- | --- |
| ABI | arm64-v8a only |
| Filename | `releases/TitoDex-<ver>-{lite,offline}-rg-arm64.apk` |
| SDK | compile/target 36, min 24 |
| Size | ~20–23 MB; verify script must PASS |
| Signing | `flutter/android/key.properties` + upload keystore |

Full checklist: [RELEASE_BUILD.md](./RELEASE_BUILD.md).

Bump `flutter/pubspec.yaml` **before** building. Tag `v<x.y.z>` + GitHub Release with APK asset.

---

## iOS platform (merged source, Android-only distribution)

Same codebase, no diverging fork — `ios/` generated via
`flutter create --platforms=ios --org com.tito .` (bundle id
`com.tito.titodex`). Dart-side platform guards (`Platform.isAndroid` /
`kIsWeb`) keep iOS off the Android-only paths.

- **Save import (iOS)**: `file_picker` grants a short-lived temporary URL, so
  `PlatformSaveDocumentSource` persists a copy under app documents
  (`save_import/`) and re-reads from there; `release()` deletes only that
  copy. No security-scoped bookmark channel yet.
- **Emulator launcher**: iOS cannot enumerate/launch other apps; the entry
  falls through to the existing "模拟器启动目前仅支持 Android" hint.
- **Icons / launch**: `tools/render_ios_icons.py` (Pillow) renders the AppIcon
  set from the Android adaptive-icon vector; launch screen is solid deep blue
  `#2F4361` matching Android.
- **Info.plist**: display name `TitoDex`,
  `NSPhotoLibraryUsageDescription` for trainer-avatar picking (gallery only).
- **Last iOS build verification (2026-07-23, v0.7.0)**: `pod install`,
  `flutter analyze`, 215 Flutter tests, and
  `flutter build ios --no-codesign --release` under Xcode 27 (27.6 MB
  Runner.app). v0.8.13 passes the shared Dart suite, but its iOS no-codesign
  build has not been repeated; generated Pods/build files are not committed.
- Signing, IPA, TestFlight, and App Store distribution are intentionally not
  part of the Android release and require an Apple Developer account.

---

## Cloud agent / VM environment

- **Flutter 3.44+** at `~/flutter/bin` (on PATH in login shells).
- **Web** is the default dev target when no Android SDK; `flutter run -d chrome`.
- **APK builds** require Android SDK + release keystore (may be unavailable in some cloud VMs).
- `flutter pub get` on startup (the old root npm mock was removed in the 0.6.5 cleanup).

Every route owns a `Scaffold`, so Settings, Search and Dex sub-pages participate in web smoke coverage. Android RG remains the real shipping target.

**Known baseline:** `flutter analyze --no-pub` is expected to be clean;
`flutter test --no-pub` is the regression gate.

**Current source verification is recorded per change.** Regression gates are
`flutter analyze --no-pub`, full `flutter test --no-pub`, Python tool tests,
Journey Assistant Worker typecheck/Vitest/dry-run, companion Gradle
check/assemble, signer comparison, and physical-device install/update/uninstall.
Published v0.8.13 artifacts are verified through the Android release workflows;
the optional extension is additionally checked for the same V2 signer as the host.

Optional tooling venv: `~/.venv-titodex-tools` (`tools/dex_bundle_requirements.txt`).

---

## Contributor guardrails

### Do
- Edit **`flutter/lib/`** and **`flutter/test/`** only for product work.
- Default UI copy in **Chinese** (`app_zh.dart`, `game_zh.dart`).
- Write commits and pull requests in **English**. GitHub Release titles and
  bodies are **Simplified Chinese by default**, following `docs/RELEASES.md`;
  keep the standalone English README current instead of duplicating every
  release note bilingually.
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
| [README.md](../README.md) | 中文项目介绍与快速开始（默认） |
| [README.en.md](../README.en.md) | Maintained English project overview |
| [ROADMAP.md](../ROADMAP.md) | Release history & what's next |
| [RELEASES.md](./RELEASES.md) | 中文优先的 GitHub Release 文案规范与近期历史 |
| [ARCHITECTURE.md](./ARCHITECTURE.md) | Technology choice, structure and platform boundaries |
| [RELEASE_BUILD.md](./RELEASE_BUILD.md) | APK checklist |
| [CLOUDFLARE_DEX_CDN.md](./CLOUDFLARE_DEX_CDN.md) | R2 / Worker / bundle layout |
| [PERMISSIONS.md](./PERMISSIONS.md) | GitHub Actions secrets |
| [DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md) | Visual, typography, layout and interaction rules |
| [PARSER_PROPOSAL.md](./PARSER_PROPOSAL.md) | Save parser design |

Completed plans and handoff notes are consolidated into this file, `ROADMAP.md`
and Git history rather than kept as parallel documentation.

---

## Communication

- Product discussions and public Release Notes use **Chinese** by default;
  commits and pull requests use English. The root README is Chinese and links
  to the maintained English edition.
- When unsure between reference breadth and playthrough utility, choose **playthrough utility**.
