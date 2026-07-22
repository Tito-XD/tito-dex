# TitoDex Roadmap

> **Latest release:** [v0.6.9](https://github.com/Tito-XD/tito-dex/releases/tag/v0.6.9) · Lite `0.6.9+91` · Offline `0.6.9-offline+92`.
>
> **Current `main` source baseline:** `0.6.9+91`.

## Recent release history

| Version | Summary |
| --- | --- |
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
| Community Chinese flavor text for older generations | Planned as dex bundle v6 (attribution required) |

## Next priorities

1. **Regression coverage** — expand automated coverage for the aligned trainer-card, team-editor, offline, and flavor-title behavior.
2. **Calculation quality** — expand battle formula coverage, fixtures, and user-facing assumptions.
3. **Save workflow validation** — add real fixtures for supported pre-Switch games and expand format-specific imports.
4. **Distribution polish** — refine splash, install guidance, and release consistency.
5. **Offline maintenance** — keep bundle v5 manifests and Chinese labels current without exposing private service URLs in public copy.

## Active TODO

- [ ] Restore the deep CDN health check: upload the missing Scarlet/Violet Pikachu version sprite or make the probe accept the intentional shared-sprite fallback, so the six-hour cron does not emit false alarms.
- [ ] Restore the production Worker Cron Triggers (currently none are attached): deploy the weekly l10n dispatch and six-hour deep-health schedules declared on `deploy/dex-cdn`, then verify both handlers from Cloudflare's trigger inventory.
- [ ] Create and bind a dedicated TitoDex KV namespace for hot-object caching plus last-probe / last-dispatch state; do not reuse the unrelated `FODI_CACHE` namespace.
- [ ] Reconcile the two Worker-only commits on `deploy/dex-cdn` with `main`, while keeping `deploy/dex-cdn` as the production deployment branch.
- [ ] Refresh the Worker compatibility date and locked Wrangler release, then run a dry-run validation before the next production deployment.
- [ ] Verify whether the legacy `autumn-shape-2b65` Worker still has traffic or an owner; retire it only after that read-only check confirms it is unused.
- [ ] Rebuild and publish the dex bundle with the new exact-version encounter schema; before claiming full modern-game coverage, audit and add attributed redistributable overlays for modern version groups whose upstream encounter tables are empty or not yet verified (BDSP, Legends: Arceus, Scarlet/Violet, Z-A, and Champions).
- [ ] Add persistent caching or bounded concurrency to the full PokeAPI location-area refresh; the current first-run catalog sync is correct but serial and slow.

## Future work

- deeper generation-specific save adapters beyond trainer metadata (more real save fixtures incoming)
- Linux handheld packaging
- hand-drawn artwork for the home quick tiles / entry cards (in progress)
- broader accessibility and controller-navigation validation

> Cloud sync is intentionally **not** planned: TitoDex stays local-first, with journey JSON import/export as the portability path.
