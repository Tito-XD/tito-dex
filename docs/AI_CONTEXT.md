# TitoDex — AI Context (single source of truth)

**Read this first** before editing code, docs, or releases. Human-facing overview: [README.md](../README.md).

| Field | Value |
| --- | --- |
| **Latest release** | [v0.9.5](https://github.com/Tito-XD/tito-dex/releases/tag/v0.9.5) |
| **`main` / lite source** | `0.9.5+189` (`flutter/pubspec.yaml`) |
| **Offline package** | `0.9.5-offline+190` — APK-bundled verified v20 archive |
| **Journey Assistant** | Built into the host APK with three offline HGSS chains; reviewed online blockers also cover DPPt, BW/BW2, XY, ORAS, SM/USUM, SWSH, BDSP, PLA and SV; legacy 1.0.0 content APK remains read-compatible |
| **Offline dex bundle** | **v20** live on CDN and embedded in the Offline APK — 1025 species, 803 form records, complete item text/icons, audited form media, verified reference/gameplay projections, CDN prefix `/v5/`; `/v4/` rollback |
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
| `cloudflare/journey-assistant/` | Independent optional Journey blocker-Q&A Worker; AI Search uses an audited exact-version allowlist |
| `data/journey/` | Canonical progression hints and strict request/data schemas |
| `data/extensions/` | Legacy companion APK catalog and pack-manifest schemas kept for 1.0.0 compatibility |
| `flutter/android/journey-assistant-pack/` | Legacy no-launcher Journey Assistant 1.0.0 content APK |
| `data/l10n/zh/` | Master zh catalog (git); copied to bundle + APK assets |
| `releases/` | RG APK binaries (`TitoDex-<ver>-{lite,offline}-rg-arm64.apk`) |
| `fixtures/` | Test saves (e.g. `PKMSS.sav`) |

---

## Current feature status (latest release line: v0.9.5)

> v0.9.5 uses Lite versionCode 189 and Offline versionCode 190. Lite downloads the current live bundle when requested; Offline embeds the verified v20 archive so its newer reference and gameplay data are available immediately. It upgrades directly from v0.8.13 onward, including the public Liquid Glass preview. Android signing was rotated in v0.8.13; upgrades from v0.8.12 or earlier still require export, uninstall, and reinstall.

### Journey & save
- **Current v0.9.5 rebuild:** keeps the matte Solid Plastic surface and sprite-only forward Hero, but removes the Dex-only predictive-back observer and full-page edge slide. Every Pokémon detail entry now stays inside Flutter's standard Material predictive-back wrapper; Sprite Heroes do not participate in interactive edge gestures, so Dex, Search and Ask TitoDex share one return behavior and cancel/commit cannot strand the page or artwork halfway.
- **v0.9.4:** keeps the live Dex grid inside the route Hero subtree so the real card Sprite expands into an exactly aligned detail canvas on device, then hands off to the loaded header without a blank skeleton or geometry jump. Dex detail predictive back visibly shrinks, rounds and follows the swipe edge; Team/Search side routes carry their opaque background with the slide instead of flashing it before entry. Ask TitoDex pins changing companion copy to one leading edge and removes duplicate heading sparkles.
- **v0.9.3:** keeps one Pokémon Sprite alive throughout the Dex card-to-detail Hero flight, prefetches detail data before navigation, and preserves the previous artwork until a new form image has decoded. Secondary reference pages paint opaque shells before bounded local reads; Team rows render on the first frame with immediate Sprite fallbacks. Ask TitoDex uses one continuous-corner status family and a finer semantic reveal cadence.
- **v0.9.1:** keeps the three persistent themes and modern Ask TitoDex semantics from v0.9.0, while correcting visible motion edges: the Home Dex icon no longer stretches into the page, card-to-detail transitions move the creature sprite itself, selected form or edition artwork replaces the stable viewer sprite, secondary lists use a shorter bounded settle, rotating assistant copy crossfades without overlap, and the save-aware status surface stays pill-shaped while badge context arrives.
- **Current v0.9.0:** ships three persistent built-in themes with Trainer's Journal as the first-install default, theme-aware navigation motion, restrained Solid Plastic optics, and a modern Ask TitoDex surface. The latest App and Worker use verified semantic blocks rather than legacy answer deltas: progress is shown while sources are retrieved and checked, then summary, prose, bullets, tables, warnings, or clarification choices reveal in place. Request IDs, exact-game context and semantic reset prevent stale or cross-version answers from reappearing.
- **v0.8.20 baseline retained in v0.9.0:** Journey Assistant and three HGSS blocker chains are built into the host APK, but the entire feature defaults off. First activation happens only in Settings after a disclosure covering network access, AI/search and bounded recent conversation context; upgraded installs do not inherit the earlier default-on entry state. While disabled, Journey and Search build no assistant entry or spacer. After consent, local deterministic facts still run first, and Journey can manage one signed, catalog-pinned optional data pack for the selected game; failed or cancelled replacement keeps the prior pack. The App keeps the newest 50 Q&A pairs locally, sends at most six same-game pairs for follow-ups, and presents online status, local history and selected game as three independent compact controls. History management can explicitly compact local storage to the newest 10 entries or clear it after confirmation; the game control opens the existing 23-edition picker and rebuilds isolated Assistant context. Answers use a refined light conversation surface without stray corner marks, an unboxed companion with four-point sparkles, smoother shimmer motion, and bottom-following scroll; verified answers progressively reveal only after the Worker evidence pass completes; verification plus citations collapse into one expandable row. Recognized Pokémon, items, moves and abilities resolve against installed runtime data and stable IDs before their Poké Ball/backpack/sparkle/bolt ActionChips open existing details; ambiguous labels do not create a guessed target. The encyclopedia/guide allowlist remains one connection capability while Worker/Qwen/AI Search/Dex bundle/Tavily/DeepSeek stay individually observable. The complete possible-source list lives in Settings Credits. A save location alone no longer selects an unrelated blocker, and selected-game changes physically clear incompatible save context. On a local miss—or a V20 Dex fact whose provenance requires online verification—the Worker can combine exact-version Dex-bundle facts, BGE-M3 reviewed retrieval, fixed PokeAPI/StrategyWiki/Wikidata evidence, Tavily and DeepSeek V4 Flash allowlisted search, with Workers AI Qwen as the public composer/verifier. A V20 deterministic answer remains the offline fallback; it is replaced only when the allowlisted pass returns real online evidence. Chinese Tavily retrieval first attempts 52Poké alone; only a missing or unsupported primary answer falls back to the remaining allowlisted encyclopedias and guide sites, and final output stays Simplified Chinese. When both live routes succeed, a separate Qwen pass labels them as dual-source only if the DeepSeek result materially corroborates the primary evidence chain without a version/fact conflict. The explicit broad-answer trial can return sourced low-confidence material when a second evidence pass is incomplete for selected-game gameplay, but general franchise questions require verified citation support; Pokémon-only scope, fixed domains, bounded payloads, and deterministic failure fallback remain enforced. The strict request excludes raw saves, hashes, trainer/party/financial/coordinate data. See [JOURNEY_ASSISTANT.md](./JOURNEY_ASSISTANT.md) and [EXTENSIONS.md](./EXTENSIONS.md).
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
- **Bundle v20 live:** a byte-preserving v19 base plus pinned reference/gameplay overlays. It keeps 1025 species and adds complete serving projections for 937 moves, 373 abilities and 2130 items, 1025 bounded per-species gameplay shards, and 256 bounded held-item slug-index buckets. App catalogs remain the aggregate source of truth; the Worker reads only strict per-entity/per-species projections. All 4748 objects passed complete SHA-256 readback before the guarded v19-bound root-manifest cutover and public CDN verification; see [DEX_BUNDLE_V20.md](./DEX_BUNDLE_V20.md).
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
an unsupported blanket Creative Commons claim. The preserved v19 object set still carries historical
attribution text; live v20 adds corrected metadata without overwriting v19 objects.

### Latest release-line highlights
- v0.9.5 rebuild: keeps matte Solid Plastic and sprite-only forward entry, removes the competing Dex-specific edge-slide controller, and routes all Pokémon details through the standard Material predictive-back transition without interactive Hero flights.
- v0.9.4: keeps Dex grid Heroes discoverable on device, expands the exact card Sprite into a geometry-aligned detail header, restores expressive predictive back, removes the side-page background flash, and keeps rotating Ask TitoDex copy pinned without duplicate sparkles.
- v0.9.3: turns the Dex Sprite into one continuous shared element, removes blank detail/artwork replacement frames, keeps reference and Team first paint stable, and unifies the expandable Ask TitoDex status pill with its save-context badges.
- v0.9.2: gives Dex details a dedicated stationary-list shared-element route, preserves the populated grid through real Android predictive-back start/update/commit events, and moves Team detail/index reads behind a lightweight shell and one bounded reveal with shared per-party data.
- v0.9.1: keeps pixel artwork proportional during the Home-to-Dex expansion, moves the actual creature sprite between list and detail, removes stale artwork beneath selected forms, smooths secondary-list settling, crossfades assistant waiting copy without overlap, and keeps the save-aware status bar pill-shaped.
- v0.8.20: adds catalog-pinned per-game Journey data downloads with atomic replacement, resolves answer entities from installed runtime data and stable IDs, opens move/ability/item details directly, and keeps V20 structured facts eligible for allowlisted online verification while retaining deterministic offline fallback.
- v0.8.19: renders streamed and completed assistant Markdown as safe headings, emphasis, lists and horizontally scrollable tables; keeps citation URLs exclusively in the expandable evidence sheet; cleans legacy inline source footers from display and follow-up context; and makes the Worker return clean answer bodies alongside structured sources.
- v0.8.18: removes stray right-angle decorations, frees the companion sprite from its box, refines the paper/shimmer/action-chip styling, and progressively streams bounded verified answer deltas while preserving legacy JSON responses and deterministic local fallback.
- v0.8.17: gives Ask TitoDex a lighter modern conversation surface with companion/shimmer/reveal motion and compact expandable citations; replaces stacked status cards with three independent connection/history/game controls, adds confirmed local history compression/clearing and in-page edition switching, and preserves Poké Ball/backpack/sparkle/bolt entity ActionChips.
- v0.8.16: makes the entire assistant a disclosed opt-in with no disabled-page placeholder; fixes save-location answer hijacking, broadens Dex-bundle and allowlisted Tavily/DeepSeek retrieval, keeps 50 local Q&A pairs with six-pair same-game follow-up context, automatically follows the newest question and answer, exposes grouped active connections with full source Credits, and adds entity deep links.
- v0.8.15: compacts Ask TitoDex into a chat-first layout with a 4/4 status popup and companion search motion; isolates selected-game save context; adds Tavily allowlist retrieval and audited Violet newcomer/Paradox answers while retaining Qwen evidence verification and deterministic fallback.
- v0.8.14: makes Ask TitoDex observable with a connection card, per-answer route/model/source chips and companion waiting motion; expands reviewed multi-game retrieval and hardens bounded-source Qwen answers with exact-version move values, support gating and a second verification pass.
- v0.8.13 rebuild (versionCodes 158/159): embeds Journey Assistant and its reviewed HGSS seed in the host, removes the second-APK feature gate, and retains legacy 1.0.0 read compatibility.
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
| `/v5/` | **v20** | current — v19 audited form media and complete item text/icons + v20 reference/gameplay projections and bounded Worker shards |

Bundle v19 was built with `tools/patch_dex_bundle_v19_items.py`,
`tools/audit_item_media_v19.py`, `tools/verify_dex_v19_items.py`, and the
version-specific `.github/workflows/upload-dex-bundle.yml`. That workflow
requires live v18 as its base and must not be used to republish now that live
production is v20. The v20 path
`.github/workflows/release-dex-bundle-v20.yml` published the current bundle: it
bound the approved live v19 manifest/archive/staging to a frozen candidate,
fully read back every versioned `/v5/` object, then switched and publicly
verified the root manifest in a separate protected phase. Its rollback workflow
restores only the saved v19 root manifest and never deletes objects or touches `/v4/`.

- Config: `flutter/lib/features/dex/dex_cdn_config.dart` (compile-time `TITODEX_DEX_*` env).
- **Do not** paste production CDN URLs in public README / release notes.
- **Bundle version and CDN prefix are decoupled.** Every release since v7 patched in place over the same `/v5/` prefix; immutability applies to individual object keys, not the prefix. Reading `/v5/` as "bundleVersion 7" wrongly implies a new `/v6/` is needed.
- Historical v14 compact-media seed: `python3 tools/patch_dex_bundle_v14_compact_media.py`. It byte-compares all 1,340 `artwork/` files against their `sprites/` peers before removing only the duplicate archive copies; loose online artwork remains in R2. v0.9.0 no longer reuses that seed: the Offline APK embeds the current verified v20 archive.
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
flutter build apk --release --target-platform android-arm64  # ~21 MB Lite; Offline size follows the verified v20 archive
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
  Runner.app). v0.8.19 passes the shared Dart suite, but its iOS no-codesign
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
Journey Assistant Worker typecheck/Vitest/dry-run, bundled-data byte equality,
legacy companion Gradle checks, and physical-device host update tests.
Published v0.9.5 artifacts are verified through the Android release workflows;
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
| [DEX_BUNDLE_V20.md](./DEX_BUNDLE_V20.md) | v19-read-only v20 build, protected publication, provenance and stable entity-index contract |
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
