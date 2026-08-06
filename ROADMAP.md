# TitoDex Roadmap

> **Latest release:** [v0.8.5](https://github.com/Tito-XD/tito-dex/releases/tag/v0.8.5) · Lite `0.8.5+136` · Offline `0.8.5-offline+137`.
>
> **Current `main` source baseline:** `0.8.5+136`.
>
> Longer-horizon phases: [`docs/PHASED_FEATURE_PLAN.md`](docs/PHASED_FEATURE_PLAN.md). Canonical status: [`docs/AI_CONTEXT.md`](docs/AI_CONTEXT.md).

## Recent release history

| Version | Summary |
| --- | --- |
| **v0.8.5** | Version planning and dex browse scopes: background data-pack downloads with notification progress, exact-version chain completion and wild held-item planning, complete evolution/encounter conditions, region-or-generation dex browsing, local flavor icons, aligned detail tables, form status badges, and Sleep links. Lite and Offline keep the existing v13/v14 data archives |
| **v0.8.2** | Continuous multi-stage data-pack progress for Lite and Offline; compact v14 Offline archive; refreshed HOME-style body icons; local-first offline references |
| **v0.8.1** | Form-aware evolution chains with form sprites; body-style / size filter icons; Offline embeds dex bundle v13 |
| **v0.8.0** | Items hub (542 curated items, category filter, icons) and list animation polish |
| **v0.7.0** | Bundle v6 with complete form records, form-safe exact-version encounters for modern games and DLC, v4→v3→v2 fallback, plus merged iOS platform source |
| **v0.6.9** | Party grid rework (upright cells, sprite-corner level badges, 2×3 / 6×1 by context) and a fixed-row tablet home, validated via the 0.6.9-pre.1 preview |
| **v0.6.8** | Header gradient recolor to a readable dark-top `#5D728A→slateBlue`, cream on-gradient subtitles, slim dex title, square-dashboard polish, doubles spread modifier and stat→damage handoff |
| **v0.6.7** | Retro phase 2 (settings groups, damage hero, dex hero tabs, template-aligned team page) plus hand-drawn tile icons, validated via two previews |
| **v0.6.6.1** | Retro press physics extended to every interactive sticker across the app |
| **v0.6.6** | Retro sticker-feel toggle, generation-scoped quiz, shiny companion with intimacy quotes, crit/screen damage toggles, linked team editing, and bundled type icons |
| **v0.6.5** | Polish batch: save banner scoping, unified dex transitions, search history, settings game card, and Chinese flavor reference |
| **v0.6.2.1** | Full-bleed adaptive launcher icon for system-defined icon shapes |
| **v0.6.2** | Companion sizing and bundled starter animation/cry media |
| **v0.6.1** | Companion 2.0, landscape home, game icons, and header polish |
| **v0.5.51** | Preview fix for deterministic Team, Dex, and Search return motion |
| **v0.5.5** | Single-file saves, native app picker, polished motion, companion interactions, six-slot party card, and silhouette quiz |
| **v0.5.1** | Android-standard route motion and predictive back |
| **v0.5.0** | Precomputed in-memory Dex catalog and responsive filtering |
| **v0.4.99** | Align the complete release source and publish matching lite/offline packages |
| **v0.4.98** | Correct per-game titles in the Pokédex flavor-text carousel |
| **v0.4.97** | Trainer-card name-line copy adjustment |
| **v0.4.96** | Dense trainer-card layout fix for square screens |
| **v0.4.95** | Trainer-card bootstrap, loading panels, team editor, settings cleanup, and download progress controls |
| **v0.4.94** | Compact settings sections and paginated Pokédex filter results |
| **v0.4.93** | Ability fallback, game labels, location coverage, and ability filtering |
| **v0.4.92** | Combined matchup summary card and dynamic dashboard title |
| **v0.4.91** | Attacker selection and ability-aware battle filters |
| **v0.4.85** | Terastal, held items, status effects, defensive abilities, and team shared weaknesses |
| **v0.4.8** | Generation-aware abilities, matchup modifiers, and blind-spot tools |
| **v0.4.7** | Sprite picker, 1–1025 progress, home layout, and avatar crop fix |
| **v0.4.6** | Reference drill-down, sprite fixes, and offline update prompts |
| **v0.4.0** | 23 game editions, 11 regional Pokédex scopes, and segmented search hub |
| **v0.3.0** | National Pokédex 1–1025 and bundle v5 foundation |

Full archive: [docs/RELEASES.md](docs/RELEASES.md).

## Current capability status

| Area | Status |
| --- | --- |
| Flutter application, persistence, routing, and emulator launch | Shipped |
| Single-file save import | Shipped; HGSS has fixture-verified party/map/dex parsing |
| Other pre-Switch save metadata | Experimental; real-save fixture coverage remains incomplete |
| Pokédex 1–1025 and regional/game scopes | Shipped |
| Offline bundle, Chinese catalog, maps, config, and update prompts | Shipped |
| Structured reference hub and Pokédex drill-down | Shipped |
| Matchup, stat/damage estimates, blind spots, modifiers, and team weaknesses | Shipped; calculation depth remains partial |
| APK-bundled offline variant | Available as an optional distribution |
| Standby companion, shiny party surprise, silhouette quiz | Shipped in v0.5.5; companion sizing/media in v0.6.1–v0.6.2 |
| Community Chinese flavor text for older generations | Still planned separately; bundle v6 focuses on forms and encounter locations |

## Next priorities

> Feature-side sequencing (save auto-edition, offline verify, evolution/version
> availability, location index) lives in
> [docs/PHASED_FEATURE_PLAN.md](docs/PHASED_FEATURE_PLAN.md).

Regression coverage has largely landed (58 test files covering trainer-card, home dashboard, offline, flavor-title, and device layouts); a dedicated team-editor test is still missing.

1. **CDN release infrastructure** — create a new bundle-publish workflow with production version pre-checks (v12/v13 workflows are archived; only the v7 workflow remains live, and there is no v14 workflow).
2. **Cloudflare operational audit** — re-audit the dedicated TitoDex KV binding and production cron inventory; retire the legacy `autumn-shape-2b65` Worker only after a read-only check confirms it is unused.
3. **Location tree (Phase 3-2)** — wire the App-side on-demand loader and location-tree page with location completion; `location_index.json` is already built into the bundle.
4. **Save workflow validation** — add real fixtures for supported pre-Switch games (only `PKMSS.sav` exists today) and expand format-specific imports.
5. **Calculation quality** — expand battle formula coverage, fixtures, and user-facing assumptions; stat calc already exposes IV/EV inputs, but depth stays partial.
6. **Accessibility / controller navigation** — current support is minimal (a few Focus hooks plus semantics tests); needs systematic validation.
7. **MechanicsProfile** — precise “alternative evolution path available in the current version” rules (e.g. Feebas beauty in HGSS); code currently only references the future profile.
8. **Offline maintenance** (ongoing) — keep bundle manifests, modern encounter overlays, forms, and Chinese labels current without exposing private service URLs in public copy.

## Active TODO

- [x] Complete the items reference: 542 curated items in Bulbapedia-style groups, zh names (100%) and zh in-game descriptions (99%, PokeAPI `zh-hans` + 52poke fallback), and item icons packed into bundle v11 for full offline display (`/v5/`, CDN-first online). Attribution ships as `ITEMS_ATTRIBUTION.txt`.
- [x] Make deep CDN health derive the active prefix from the manifest and accept a legal default-sprite fallback.
- [x] Reconcile production Worker health, alerts, cron handlers, caching, and fallback semantics into `main`.
- [x] Create and bind a dedicated TitoDex `MANIFEST_KV`; the unrelated `FODI_CACHE` remains untouched.
- [x] Refresh the Worker compatibility date and locked Wrangler release, with a dry-run gate before deployment.
- [x] Re-audit the dedicated TitoDex KV binding and production cron inventory (2026-08-06): `MANIFEST_KV` id matches `wrangler.toml`, `FODI_CACHE` is untouched and unbound, the 6-hour deep-probe cron is live (`lastScheduledProbe` every 6 h), secrets match DEPLOY.md, and the live worker rev matches the repo config.
- [x] Retire the legacy `autumn-shape-2b65` Worker (2026-08-06): audit found a single 2024-04-04 “Automatic migration” deployment with no git source or owner; confirmed unused by the maintainer and deleted via `wrangler delete`.
- [x] Publish exact-version encounter schema with attributed PKHeX overlays for BDSP, Legends: Arceus, Sword/Shield+DLC, Scarlet/Violet+DLC, Z-A, and Mega Dimension; Champions is explicitly not applicable.
- [x] Bound PokeAPI fetch concurrency: dex detail/catalog refresh batches (`summaryBatchSize`) with throttling; the first-run sync is no longer serial.

## Future work

- deeper generation-specific save adapters beyond trainer metadata (more real save fixtures incoming)
- grouped/collapsible cosmetic form controls and battle/team tool handoff for the currently selected form (form/version-aware deep links already shipped)
- curated Z-A / Mega Dimension patches whenever a new form is absent from PokeAPI; partial records must keep unknown stats, locations, and images empty
- broader accessibility and controller-navigation validation

> Cloud sync is intentionally **not** planned: TitoDex stays local-first, with journey JSON import/export as the portability path.
