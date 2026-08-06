# TitoDex — AI Context (single source of truth)

**Read this first** before editing code, docs, or releases. Human-facing overview: [README.md](../README.md).

| Field | Value |
| --- | --- |
| **Latest release** | [v0.8.5](https://github.com/Tito-XD/tito-dex/releases/tag/v0.8.5) |
| **`main` / lite source** | `0.8.5+136` (`flutter/pubspec.yaml`) |
| **Offline package** | `0.8.5-offline+137` — APK-bundled verified compact v14 archive |
| **Offline dex bundle** | **v13** live on CDN; Offline APK embeds compact **v14** — 1025 species + per-form evolution chains, CDN prefix `/v5/`; `/v4/` rollback |
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

## Current feature status (latest release line: v0.8.5)

> `main` tracks the v0.8.5 release line. Lite downloads live bundle v13 when requested; Offline embeds the byte-identical verified compact v14 archive.

### Journey & save
- Experimental pre-Switch Gen 1–7 `.sav` metadata recognition; one explicitly selected save file with persisted read permission; optional startup reload. HGSS is fixture-verified and additionally imports party, map, and Pokédex progress.
- Home / Team / Journey / Settings; native Android installed-app picker and launcher; journey JSON import/export.
- Manual dex marks when save not linked.

### Dex (national 1–1025)
- Grid + form-name search; 4-tab detail (简介 / 基本信息 / 获取 / 招式) with a form switcher.
- **23 game editions**, **11 regional dexes**, and persisted G1–G9 debut-generation browse scopes. Primary browse scope intersects with body/color/size/reference filters.
- Offline: CDN pre-built bundle (Settings) or legacy PokeAPI batch.
- Offline APK first install/upgrade shows a blocking local preparation dialog with continuous percentage across read → SHA-256 → decompress → extract → index. Lite and already-ready Offline installs never show it. Settings downloads can be minimized on Android: a `dataSync` foreground service keeps the Dart install active and mirrors the weighted percentage into a notification; returning to Settings restores progress and cancellation controls. Cancelling, swiping the app task away, or an Android 15 service timeout stops native foreground work so stale progress cannot remain in the notification drawer.
- Bundle includes: summaries, precomputed filter catalog, details, all form JSON, selective distinct-form sprites, moves, abilities, **l10n/zh**, **maps**, **config**, and game icons. It does not bulk-copy form artwork.
- **Per-form evolution chains** (bundle v13+): regional / cloak splits prune to the real line (洗翠卡蒂狗 → 洗翠风速狗) with form sprites. Older installs fall back to the in-app `kFormEvolutionTargets` table via `EvolutionNode.filteredForForm`. Offline loading absolutizes `sprites/forms/…` paths on `forms[].evolutionChain`.
- **Species filter sheet icons:** body-style chips use original vector creature marks that preserve the recognisable HOME poses and white eyes (`DexShapeIcon`); size chips use relative discs (`DexSizeIcon`); colour stays as swatches. Icons ship in the APK only.
- Per-form exact-version locations preserve `speciesId`, `pokemonId`, `formKey`, `teraType`, `formAmbiguous`, alpha/titan/raid/fixed flags; modern overlays cover BDSP, Legends: Arceus, Sword/Shield+DLC, Scarlet/Violet+DLC, Z-A, and Mega Dimension. Champions is explicitly not applicable.
- Chinese location labels prefer game `zh-Hans` resources for modern overlays, then the maintained catalog; HGSS retains map-id lookup.
- Detail flavor icons are APK-local and precached; evolution alternatives and encounter methods/conditions render from structured bundle fields with Chinese fallbacks. Version planning shows wild held items, paired-version gaps, and chain completion routes. **Wild held items (bundle v16 candidate):** PokeAPI data only reached Gen 7, so 52poke imports add SwSh / BDSP / LA / SV / Z-A coverage — 520 species with held items (was 381), plus 52 previously-missing items added to `items.json` (594 total, CC BY-NC-SA attribution in `HELD_ITEMS_ATTRIBUTION.txt`). Versions without an explicit 52poke rate inherit the item's known rate (default 5%).

### Items (reference hub → 道具)
- **Full item catalog (bundle v17 candidate):** 2130 items across 16 `categoryZh` groups — original 594 + 1536 from PokeAPI (TMs/HMs, Z crystals, mega stones, key items, mail, picnic/cooking, candies, TM materials, Dynamax crystals). zh names 98.8%; 967 bundled sprites; ~55.6 MB archive (+85 KB vs v16). The app filter list in `dex_json_reference_page.dart` is synced to the 16 groups.
- Data source: PokeAPI (list, English name, category, cost, sprite) + Simplified-Chinese in-game descriptions from PokeAPI `zh-hans` flavor, with 52poke (CC BY-NC-SA 4.0) as the fallback for the newest Gen 8/9 items. 100% zh names, 99% zh descriptions.
- Icons: `item-sprites/*.png` ship both as loose `/v5/` CDN objects (online, CDN-first) **and inside `bundle.tar.zst`** (offline). Offline the app rewrites the CDN `spriteUrl` to the local bundle file (`dex_offline/item-sprites/<slug>.png`).
- Build: `tools/build_items_dataset.py` → `tools/enrich_items_52poke.py` / `enrich_items_52poke_search.py` → `tools/patch_dex_bundle_v11_items.py`. The category-filter option list in `flutter/lib/pages/dex/dex_json_reference_page.dart` must stay in sync with the `categoryZh` groups.
- Attribution ships in the bundle as `ITEMS_ATTRIBUTION.txt`.

### Search hub
- **常用资料:** moves, abilities, natures, egg groups, items, weather, terrain, status.
- **对战资料:** type matchup, stat calc, quick damage (partial).
- Reference → **structured detail** + drill-down to dex filter (move / ability / egg group).
- `/search?q=` deep link supported.
- **Multi-word species search** (`dex_search_terms.dart`). Each whitespace-separated word resolves to one constraint through an alias table (神 / 传说 / legendary all reach the legendary tag); words of different kinds AND. Single-valued kinds (body style, colour, generation, size) OR with each other, because a species holds exactly one of each and ANDing two could only return nothing — that is what lets 「棕 红」 stand in for the orange the in-game palette lacks. Types and tags are genuinely multi-valued and still AND, so 「火 飞行」 means the dual type.
- An alias never suppresses a text match: 「鱼」 resolves to the fish body style **and** still finds 鲤鱼王. Genus is searchable because it rides on the summary.
- **Stackable dex axes** (`DexFilter`): body style × colour (multi-select set) × relative size × generation × tag, intersected with at most one reference drill-down. Size buckets are cut from the real 1025-species height distribution (~19/29/24/16/13 %).
- Body style labels are the canonical 52poke names. The eight species reclassified in Gen VI (绿毛虫 / 独角虫 / 刺尾虫 / 结草儿 / 结草贵妇 / 无壳海兔 / 海兔兽 / 克雷色利亚 — all present in HGSS) match under **both** the current and the pre-Gen VI body style.

### Latest release-line highlights
- v0.8.5: Android data-pack downloads can continue in the background with notification progress; exact-version obtain planning and held-item rows land; structured evolution and encounter conditions become visible; the dex gains persisted region/G1–G9 scope selection; flavor icons are local, metadata rows align, form status/attribution/Sleep links are restored, and secondary-page scaling is retired. Bundle v13 and compact Offline v14 remain unchanged.
- v0.8.2: Lite and Offline show continuous weighted progress across manifest/read, download, verification, decompression, extraction and indexing; Offline uses the compact v14 archive (48.7% smaller than v13); offline references load local-first; HOME-style body-filter icons are redrawn for clearer silhouettes.
- v0.8.1: form-aware evolution chains show the matching regional line with form sprites; body-style / size filter chips gain APK-local vector icons; Offline embeds dex bundle v13.
- v0.8.0: curated items hub (542 items, Bulbapedia-style categories, icons) and dex list animation polish.
- v0.7.16: unified game icons — Gen VI+ uses Pokémon HOME game icons, Gen I–V uses DS/3DS launch icons (SteamGridDB), white-2/mega-dimension use Pokémon artwork badges; form sprites in bundle v10 are clear official artwork (were pixelated), offline form caching prefers artwork; predictive-back rework — content stays opaque during the drag, underlying pages stay static, and a gesture-runway clamp keeps the commit fade playing even after a full-edge drag.
- v0.7.15: official single-version icons for secondary flavors (Violet, Shield, Shining Pearl, Y, …) replace generated badges; offline caching stores per-form sprites (`sprites/forms/<key>.png`) so non-default forms keep their art; edge-to-edge shell makes predictive back retract the whole screen with no skyBlue flash; dex route joins the gesture so release fades out; dex enter reveal starts after the shell lands.
- v0.7.14: per-flavor game icons in the edition picker; companion position drag no longer spams SharedPreferences; Dex tab re-entry restores the list fade/slide reveal; predictive-back gesture now moves the Dex content layer together with the shell.
- v0.7.13: merged-vs-flavor game picker with secondary flavor sheet; generated/fallback game icons for older titles; companion draggable position in Settings; simplified Dex Hero entry and one-shot list reveal.
- v0.7.12: reverted detail sprite display to local assets and added shimmer placeholders for network images.
- v0.7.11: restored game description logos and added form artwork CDN support; companion form/shiny selection.
- v0.7.1: restores the verified clear 220×220 default images; adds real form-specific historical sprite sources without inventing missing generations; reduces the form selector to chips; changes exact encounter version selection to a dropdown; pins secondary-page headers and adds quick scroll-to-top to the dex. Bundle v7 reuses v6 encounter/location data byte-for-byte and publishes only corrected media plus form sprite metadata under `/v5/`.
- v0.7.0: searchable form variants replace types, stats, abilities, moves, size, image and locations together; obtain locations can be selected by exact paired version or DLC and remain tied to the selected form without borrowing the default form; bundle v6 publishes all 1025 species plus attributed modern-game encounter overlays under a new immutable prefix with v4→v3→v2 online fallback; iOS platform source is merged and Xcode 27 no-codesign build-verified.
- v0.6.9: party cells go upright (sprite over full-width name) with the level moved onto the sprite corner as a `_PartyLevelBadge` softYellow pill; square `gridMode` lays 2×3 in the save-linked half-width column and 6×1 via `stripMode` in the no-save full-width bar, with cells capped near-square and centered instead of stretching; tablet/tall-landscape home switches to `_WideRowsContent` (intrinsic-height trainer + journey row, party as one capped strip) so the journey card stops ballooning — square handhelds and short landscape phones keep the packed two-column layout.
- v0.6.8: header gradient recolored from light-top skyBlue→slateBlue (1.64:1 title contrast) to dark-top `#5D728A`→slateBlue picked via `docs/mockups/titodex_header_gradient_template.html`; on-gradient subtitles switch from invisible skyBlue to cream through the shared `SecondaryPageSubtitle` (deep-blue-card skyBlue text untouched — it was already readable); dex top bar slims to 「图鉴」 with the game name as subtitle; square dashboard gets a 3×2 party grid, tighter trainer card, journey-card overflow fix, and a stacked layout when no save is linked; quick damage gains the doubles spread ×0.75 toggle and the stat-calc → quick-damage one-shot handoff (`battle_handoff.dart`).
- v0.6.7: Retro phase 2 from the five mock templates — settings group-label pills + StickerSwitch + icon plates, deep-blue damage hero card (oversized percentage, mint/coral HP bar, power slider, engraved fields, pill toggles), dex detail hero header with type-tinted plate + sticker tabs, team page aligned to the mock (inline editor, type pills, dashed empty slots), hand-drawn quick tile icons (`assets/icons/`), responsive dex grid, hold-press physics, pinned damage result, obtain tab follows the selected edition. Cream screen base and weak/resist tinted cells remain intentionally excluded.
- v0.6.6.1: Retro press physics extended to every interactive sticker (dex grid cards, search/reference/team rows, journey card, quiz choices, dex top-bar pills, picker tiles, battle tool rows) via `StickerPressable` with `ownShadow` to avoid doubled shadows; DESIGN_SYSTEM canonizes the solid sticker-shadow signature.
- v0.6.6: Retro sticker-feel toggle (Settings → 界面风格, default on — TitoShadows solid drops, StickerPressable press physics, -0.02em headings), generation-scoped silhouette quiz with persisted best streak + adopt-as-companion, shiny companion sessions (Showdown shiny GIFs, disk-cached) with intimacy quote tiers / time-of-day greetings / pat-count persistence, crit + screen toggles and an assumptions note in quick damage, full-dex team picker with species-linked editing, bundled official-style type icons, drill-down back-hierarchy fixes, toggleable list reveal animations, shiny artwork preview, branded Android 12+ splash, matched transition backdrop, repository cleanup.
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
- Beyond the IV/EV inputs already exposed in stat calc: full competitive damage calculator, dedicated IV workflow, usage rankings, and simulator parity.
- Broader real-save fixtures and validation beyond HGSS (more real saves incoming from the maintainer).
- Community (52poke) Chinese flavor text: 850 species imported plus a maintainer-supplied Gholdengo overview (bundle v15 candidate; CC BY-NC-SA attribution ships as `FLAVOR_ATTRIBUTION.txt` in the archive). All 1025 species now have zh flavor; per-entry zh coverage rose to ~71%. Publish path: `upload-dex-bundle-v15.yml` after v14 goes live.

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

**Reference-data priority:** a complete/preferred offline install reads `dex_offline/` first and only uses CDN for a missing file; Lite reads CDN first and falls back to any local cache. The Offline APK seed is installed into `dex_offline/` before it is used.

---

## Dex CDN (maintainers)

| CDN prefix | Bundle version | Species |
| --- | --- | --- |
| `/v2/` | v4 | 493 (legacy) |
| `/v3/` | v5 | 1025 (rollback / older clients) |
| `/v4/` | v6 | 1025 + forms + exact-version modern encounters (rollback) |
| `/v5/` | **v13** | current — v12 axes + per-form `evolutionChain` (575 forms); items, clear media, form sprites unchanged |

Historical `/v5/` patches on the same prefix: v7 media → v8 form artwork → v9 artwork fallback → v10 clear form art → v11 items → v12 species search axes → **v13 form evolution chains**.

- Config: `flutter/lib/features/dex/dex_cdn_config.dart` (compile-time `TITODEX_DEX_*` env).
- **Do not** paste production CDN URLs in public README / release notes.
- **Bundle version and CDN prefix are decoupled.** Every release since v7 patched in place over the same `/v5/` prefix; immutability applies to individual object keys, not the prefix. Reading `/v5/` as "bundleVersion 7" wrongly implies a new `/v6/` is needed.
- Incremental v12 build: `python3 tools/patch_dex_bundle_v12_species_axes.py` (v11 archive as read-only base).
- Incremental v13 build: `python3 tools/patch_dex_bundle_v13_form_evolution.py` (live v12 archive as read-only base; no PokeAPI). The completed one-shot v12/v13 workflows live under `docs/archive/workflows/`; future releases need a new workflow with the current production version as an explicit precondition.
- v14 compact-media candidate: `python3 tools/patch_dex_bundle_v14_compact_media.py`. It byte-compares all 1,340 `artwork/` files against their `sprites/` peers before removing only the duplicate archive copies; loose online artwork remains in R2. The new archive key is `/v5/bundle-v14.tar.zst`, so publishing it never overwrites the live v13 archive. Local prerelease result: 106,743,740 → 54,746,615 bytes (−48.7%).
- **Slugs ship, labels do not.** Body style / colour / growth rate / habitat ride in the bundle as slugs; their Chinese labels live in `flutter/lib/features/dex/dex_search_terms.dart` (and form-suffix labels in `form_evolution_targets.dart`).
- Release order: upload and verify every immutable `/v5/` object, then update root `bundle-manifest.json` last. Never overwrite or delete `/v4/`. Clients only upgrade when `remote.bundleVersion > local.version`.
- Worker state uses a dedicated `MANIFEST_KV` namespace for hot manifest cache and last health/dispatch records; never bind the unrelated `FODI_CACHE`.
- Secrets: [PERMISSIONS.md](./PERMISSIONS.md) — `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID` (and optional `R2_*` for bulk upload).

---

## Build, test, release (RG APK)

```bash
cd flutter
flutter pub get
flutter test                    # regression gate
flutter build apk --release --target-platform android-arm64  # ~21 MB Lite / ~100+ MB Offline
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
- **Verified 2026-07-23**: `pod install`, `flutter analyze`, 215 Flutter tests,
  and `flutter build ios --no-codesign --release` under Xcode 27 (27.6 MB
  Runner.app). Generated Pods/build files are not committed.
- Signing, IPA, TestFlight, and App Store distribution are intentionally not
  part of the Android release and require an Apple Developer account.

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
| [PHASED_FEATURE_PLAN.md](./PHASED_FEATURE_PLAN.md) | Active three-phase feature plan (supersedes the codex roadmap ideas) |

Legacy handoff docs under `docs/handoff/` are historical — prefer this file for current state.

---

## Communication

- Product discussions use **Chinese** by default; repository artifacts use **English** unless a task requests otherwise.
- When unsure between reference breadth and playthrough utility, choose **playthrough utility**.
