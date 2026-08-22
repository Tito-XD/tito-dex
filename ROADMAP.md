# TitoDex Roadmap

> **Latest release:** [v0.8.20](https://github.com/Tito-XD/tito-dex/releases/tag/v0.8.20) · Lite `0.8.20+174` · Offline `0.8.20-offline+175`.
>
> **Current `main`:** v0.8.20 release baseline with downloadable per-game Journey data packs, stable entity deep links, bundle-grounded retrieval, BGE-M3 AI Search, Tavily and DeepSeek allowlisted search, and Workers AI Qwen. Canonical status: [`docs/AI_CONTEXT.md`](docs/AI_CONTEXT.md).

## Current capability status

| Area | Status |
| --- | --- |
| Android journey companion, routing, persistence and emulator launch | Shipped |
| Configurable Android app-icon shortcuts | Shipped in v0.8.8; defaults to Dex + Search and can expose up to three selected dex, reference or battle-tool destinations |
| Save import | HGSS fixture-verified rich party/trainer/map/dex sync; Gen I–VII metadata experimental; DeSmuME `.dsv` recognized |
| Pokédex 1–1025, 803 form records and exact-version obtain planning | Shipped |
| Location dex + save assistant | Shipped in v0.8.8; version → area → encounter tree plus Journey capture/evolution/version reminders |
| “Ask TitoDex” blocker Q&A | Built into the host; save-first local fuzzy matching, BGE-M3 reviewed retrieval, bounded public sources and Workers AI Qwen with visible connectivity and per-answer execution traces |
| Offline data | Live bundle v19; compact v14 Offline seed |
| Items | 2130/2130 descriptions/icons; 1465 version-scoped items, 18 exact paired-version exclusives and 1114 scoped prices |
| Battle tools | Lightweight matchup/stat/damage estimates; assumptions are explicit, simulator parity remains out of scope |
| Pokémon Sleep | Sleep score and basic cooking-strength estimates ported from a pinned Neroli’s Lab commit; full team/production simulation remains external |
| Controller/accessibility | D-pad A/B routing and semantics coverage; real-device matrix remains ongoing |

## Completed in v0.8.20

- Add optional per-game Journey data packs that can be installed, updated, or removed from Journey only after the assistant has been enabled; failed validation or interrupted replacement retains the previously installed pack.
- Resolve answer entities from the installed runtime data and stable IDs, then open Pokémon, move, ability, and item details directly; ambiguous translated names no longer manufacture a misleading chip.
- Keep V20-ready structured Dex evidence bounded and provenance-aware so local facts remain useful for offline fallback while eligible questions can continue through allowlisted online verification.

## Completed in v0.8.19

- Render streamed and completed Ask TitoDex answers as safe rich text, including headings, emphasis, lists and horizontally scrollable tables.
- Keep citation URLs exclusively inside the existing expandable evidence sheet; clean legacy inline source footers from display and bounded follow-up context.
- Return clean Worker answer bodies alongside structured sources while retaining local deterministic fallback and existing Pokémon/item/move/ability deep links.

## Completed in v0.8.18

- Remove the stray right-angle corner decorations from answer, loading and composer surfaces; present the selected companion as an unboxed sprite with subtle four-point sparkles.
- Refine the light conversation paper, shimmer loading state and compact Pokémon/item/move/ability ActionChips while retaining their Poké Ball, backpack, sparkle and bolt semantics.
- Stream bounded answer deltas only after the Worker has completed its existing evidence and fact verification; keep one-line JSON compatibility and deterministic local fallback.

## Completed in v0.8.17

- Give Ask TitoDex a lighter conversation surface with companion motion, shimmer generation state, natural answer/evidence reveal, and reliable bottom-following scroll.
- Merge online capability, local Q&A count, and selected game into one three-segment control; each segment independently opens connection details, history management, or the existing 23-edition picker.
- Add confirmed local-history compression to the newest 10 entries and full clearing, while preserving the six-entry same-game request-context bound.
- Collapse verification and citations into one expandable source row; keep Pokémon, item, move, and ability deep links as lightweight semantic ActionChips.

## Completed in v0.8.16

- Make the entire assistant an explicit first-use opt-in. Settings discloses network, AI/search and recent-context use before activation; upgraded installs do not inherit the old default-on entry state, and disabled Journey/Search pages reserve no assistant space.
- Stop verified HGSS location from selecting a local blocker unless the question itself contains matching blocker/location language; unresolved and clarification results now continue online.
- Keep the newest 50 Q&A pairs on-device, delete the oldest pair on overflow, show the count in connection status, and send only the latest six same-game pairs as bounded follow-up context.
- Add answer cards that deep-link recognized Pokémon, items, moves, and abilities into their existing TitoDex pages and prefilled reference searches.
- Expand transient Tavily/DeepSeek sources to official, encyclopedia, walkthrough, strategy, and player-guide sites while retaining a server-owned domain list and Pokémon-only scope.
- Run Tavily/fixed-source research and DeepSeek V4 Flash native search concurrently. When both succeed, Qwen separately checks whether the second route corroborates the primary answer without a version/fact conflict and labels the dual-source path only after that check. Trial mode accepts a sourced answer at low confidence when the second verifier lacks citation snippets; it never writes transient text to R2 or AI Search.
- Replace the fixed 4/4 indicator with a complete dynamic list for Worker, Qwen, AI Search, Dex bundle, fixed sources, Tavily, and DeepSeek.

## Completed in v0.8.15

- Compress Ask TitoDex connectivity into a 4/4 indicator and details popup; keep the answer area independently scrollable above a fixed chat composer.
- Keep the selected home companion visible, then animate it with rotating playful lookup messages and shimmer only while a request is running, with reduced-motion support.
- Clear incompatible save location, badge and milestone fields whenever the selected edition changes; SV and BDSP no longer inherit HGSS progress labels.
- Add one bounded Tavily allowlist search after audited/fixed-source misses, then require Qwen composition and a second evidence check before returning an answer.
- Add audited deterministic Violet newcomer and Paradox-Pokémon overviews, while long-tail questions such as encounter locations continue through the allowlisted web route.
- Configure the explicit Cloudflare BYOK alias `TitoDex` without a `default` fallback; keep DeepSeek native search disabled after live evidence-shape validation failed.

## Completed in v0.8.14

- Add a sanitized connection card for Worker, Qwen, AI Search and bounded sources; explicitly show that Brave Search is not connected.
- Label every answer with the actual route, model use, AI Search hit and source providers instead of silently collapsing online failures into a normal no-match.
- Animate the selected home companion with reduced-motion support and stage-accurate waiting messages.
- Expand the reviewed online blocker corpus across supported Gen IV–IX editions while retaining exact game/reliability gates.
- Resolve move values against the selected version, reject unsupported source composition, and run a second Qwen fact-support verification pass.

## Completed in v0.8.13

- Ship the independently installable Journey Assistant 1.0.0, then build its reviewed seed and Ask flow directly into the host so a second APK is no longer required.
- Rotate the Android signing key after legacy signing material was found in public history; v0.8.13 requires a one-time uninstall/reinstall from older releases.

## Completed in v0.8.12

- Rebalance the immersive RG home dashboard: a larger Trainer Card, clearer two-line Journey metadata on normal handheld panels, safe compact fallback, and small top/bottom optical insets.
- Consolidate overlapping product, architecture, design, phase, handoff and CDN documents into current canonical references; remove obsolete one-shot workflows while retaining history in Git.
- Refresh both READMEs, release/build instructions, iOS status, data-source notes and agent context against the v0.8.12 / bundle v19 baseline.

## Completed in v0.8.11

- Add a dedicated Pokémon Sleep secondary page under Search with overnight sleep duration and score estimates.
- Add transparent basic cooking-strength estimates using all 19 current ingredients, recipe levels 1–70, recipe bonus, and weekday/Sunday critical references.
- Pin the ported formulas and values to Neroli’s Lab commit `cb533f2`, bundle its Apache-2.0 license and NOTICE, and correct the in-app/root third-party attribution boundaries.
- Correct 52Poké, PokeAPI/sprites, PokéSprite, Nunito, game-icon and media provenance throughout source metadata, generated audits, Settings, and public documentation.

## Completed in v0.8.10

- Expand HGSS party sync with nicknames, held items, move PP/PP Ups, friendship, nature, shiny/gender/status, IV/EV and battle stats.
- Add reliable trainer money, Secret ID, gender/language, starter, map coordinates and save milestones to Journey persistence and existing UI.
- Correct the Gen IV party block's current/max HP offsets and bump the parser revision for one-time re-import.
- Preserve Dex scope, filter, loaded depth and scroll offset when returning from a detail route.
- Add bilingual data/media Credits and a visible non-affiliation, rights and learning-use notice to Settings and both READMEs.

## Completed in v0.8.9

- Repair the Settings media resource route, make failed catalogs retryable, and keep load failures recoverable.
- Replace the reduced companion-position preview with a full-screen delta-based drag surface that commits once at drag end.
- Scope item availability/prices, moves, abilities and reference mechanics to the selected game/generation, while leaving unsupported future data honestly unknown.
- Turn Location Dex into a compact responsive grid with a draggable missing-first encounter sheet.
- Parse HGSS party EXP, ability and four move IDs; expose team evolution/move/ability assistance and quick-damage handoff.
- Display Johto and Kanto badge progress separately and record Journey activity at actual TitoDex import time.
- Remove the Team page's SoulSilver fallback from visible/current-version state; exact HeartGold and SoulSilver selections now own their label and journey key.

## Completed in v0.8.8

- Repair l10n publication against the exact live bundle version and stop masking fetch failures.
- Verify release package id, version name/code and signer equality before drafting a release.
- Add Android emulator integration smoke to CI.
- Add configurable long-press app shortcuts.
- Add the structured location dex and `MechanicsProfile` evolution-route gates.
- Add a two-level save assistant to the Journey card/page, including nearby uncaught species, party evolution routes, and exact-version completion gaps.
- Count HGSS Johto + Kanto badges, detect HeartGold/SoulSilver and unwrap DeSmuME saves.
- Add a manifest-driven reviewed-save fixture matrix for future maintainer saves.
- Add direct team-editor and handheld D-pad/A-button regression tests.
- Give all v19 item descriptions/icons explicit or derived pipeline provenance.
- Make `data/l10n/zh/dex_axes.json` the canonical shape/colour/growth/habitat label source and generate the Dart fallback.
- Ensure every Flutter route owns a `Scaffold`, including web preview routes.

## Remaining validation / maintenance

1. Add reviewed real-save fixtures as the maintainer completes more versions. Do not promote an experimental adapter to fixture-verified before that.
2. Run the release checklist on a physical RG device and Android 15 phone: Offline first unpack, background notification, cancellation, task removal and service timeout.
3. Refresh upstream form media periodically. Six Koraidon/Miraidon ride-mode static gaps remain intentionally honest until a verified distinct source exists.
4. Keep encounter overlays, item/form audits and Chinese catalogs current through versioned bundle releases.
5. Promote useful trial answers into AI Search only through revision-locked, independently reviewed original facts; keep transient web text out of R2 and APK data.

## Product boundaries

- No interactive map, full wiki mirror, search DSL, usage rankings or competitive simulator.
- No cloud journey sync; JSON import/export is the portability path.
- No invented media for upstream gaps.
- iOS signing/distribution requires a separate product decision.

Full release archive: [docs/RELEASES.md](docs/RELEASES.md). Completed implementation plans were folded into this roadmap and the canonical [AI context](docs/AI_CONTEXT.md); new work should be added here only after a fresh product decision.
