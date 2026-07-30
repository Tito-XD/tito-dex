# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Read first

**`docs/AI_CONTEXT.md` is the single source of truth** — current release, full feature status, CDN state, and guardrails live there. `AGENTS.md` is the short entry point. This file is only the fast summary; when the two disagree, `docs/AI_CONTEXT.md` wins.

## What this is

**TitoDex** — an offline-first Pokémon journey companion for Android RG handhelds (arm64-v8a, SDK 36). Save-aware progress, manual team/journey management, offline Pokédex (1025 species), and lightweight battle utilities. UI is **Simplified Chinese**; local-first with no runtime PokeAPI/52poke scraping in the app.

The only active app code is **`flutter/`** (Flutter + Dart). The old React mock (`src/`) was deleted in the 0.6.5 cleanup.

## Commands

All app work happens in `flutter/`:

```bash
cd flutter
flutter pub get
flutter test                              # regression gate — run before pushing
flutter test test/<file>_test.dart        # single test file
flutter test --name "<substring>"         # single test by name
flutter analyze                           # may report pre-existing infos; test is the real gate
flutter run -d chrome                     # web smoke target when no Android SDK
flutter build apk --release --target-platform android-arm64   # ~21 MB, arm64 only
../tools/verify_release_apk.sh build/app/outputs/flutter-apk/app-release.apk
```

Bump `flutter/pubspec.yaml` **before** building. Full APK checklist: `docs/RELEASE_BUILD.md`.

`tools/` holds Python for the dex-bundle build / zh-catalog fetch / HGSS save probe (optional venv `~/.venv-titodex-tools`, `tools/dex_bundle_requirements.txt`).

## Architecture

```
flutter/lib/
  app.dart              # GoRouter, bootstrap, offline/update prompts
  features/
    dex/                # PokeAPI, offline cache, CDN installer, l10n update
    journey/            # JourneyRepository
    parser/             # PokemonSaveParser, HgssParser, hgss_map_list
    save/               # SaveSyncService, SaveFileRepository, document URI source
    companion/          # Battle math, type relations
    game/               # GameEdition, regional dex
  config/app_config.dart
  l10n/                 # app_zh.dart, game_zh.dart, zh_catalog.dart
  pages/  widgets/      # DeviceShell, dex_reference_detail, home/dex/search/settings
```

- **Routes:** `/`, `/team`, `/journey`, `/dex`, `/dex/:id`, `/search`, `/settings`, plus `/search/companion/*`. `/search?q=` deep link supported.
- **Reference-data load order:** app-documents `dex_offline/` (mirrors the CDN bundle) → APK `assets/` fallback.
- **Game context is first-class:** edition / generation / regional `DexScope` drive which data and calculations apply.

## Dex CDN (maintainers)

Bundle version and CDN prefix are **decoupled** — every release since v7 has patched in place over `/v5/`, so a new prefix is not needed for new fields (see `docs/CLOUDFLARE_DEX_CDN.md`).

R2-proxy Worker lives in `cloudflare/dex-cdn/` (deploy branch `deploy/dex-cdn`); config in `flutter/lib/features/dex/dex_cdn_config.dart` (compile-time `TITODEX_DEX_*` env). Bundles are immutable per prefix (`/v5/` current, `/v4/` rollback). Release order: upload+verify every immutable object, update root `bundle-manifest.json` **last**, never overwrite `/v4/`. Worker uses the dedicated `MANIFEST_KV` namespace — never bind the unrelated `FODI_CACHE`. Details: `docs/CLOUDFLARE_DEX_CDN.md`, secrets in `docs/PERMISSIONS.md`.

## Guardrails

- Edit **`flutter/lib/`** and **`flutter/test/`** only for product work; prefer small focused diffs matching existing patterns.
- Default UI copy in **Chinese** (`app_zh.dart`, `game_zh.dart`); GitHub artifacts (commits, PRs, releases) in **English** unless asked otherwise.
- **Never** paste production CDN URLs into README / release notes / user-facing copy.
- No runtime 52poke/PokeAPI fetches for the zh catalog in the app; hand-drawn nav icons ship as APK assets only, never on CDN.
- **Bundles carry slugs, the app carries labels.** Anything a user reads (body style, colour, growth rate, habitat names) belongs in `flutter/lib/l10n/` or `dex_search_terms.dart`, never baked into the bundle — `/v5/` objects are immutable, so a label typo there costs a full republish.
- **Searchable fields live on the summary.** Search reads `summaries.json` only; putting a searchable field in `details/<id>.json` means walking 1025 files. That is why `genusZh` and `heightDm` are duplicated onto the summary.
- Don't expand TitoDex into a full wiki mirror or competitive simulator without an explicit product decision.
- Don't overwrite the manual journey timeline on save import without the merge rules in `docs/PARSER_PROPOSAL.md`.
- When torn between reference breadth and playthrough utility, choose **playthrough utility**.
