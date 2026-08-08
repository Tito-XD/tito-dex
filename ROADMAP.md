# TitoDex Roadmap

> **Latest release:** [v0.8.8](https://github.com/Tito-XD/tito-dex/releases/tag/v0.8.8) · Lite `0.8.8+142` · Offline `0.8.8-offline+143`.
>
> **Current `main`:** v0.8.8 release source. Canonical status: [`docs/AI_CONTEXT.md`](docs/AI_CONTEXT.md).

## Current capability status

| Area | Status |
| --- | --- |
| Android journey companion, routing, persistence and emulator launch | Shipped |
| Configurable Android app-icon shortcuts | Shipped in v0.8.8; defaults to Dex + Search and can expose up to three selected dex, reference or battle-tool destinations |
| Save import | HGSS fixture-verified; Gen I–VII metadata experimental; DeSmuME `.dsv` recognized |
| Pokédex 1–1025, 803 form records and exact-version obtain planning | Shipped |
| Location dex + save assistant | Shipped in v0.8.8; version → area → encounter tree plus Journey capture/evolution/version reminders |
| Offline data | Live bundle v19; compact v14 Offline seed |
| Items | 2130/2130 descriptions and local icons; provenance audit closed |
| Battle tools | Lightweight matchup/stat/damage estimates; assumptions are explicit, simulator parity remains out of scope |
| Controller/accessibility | D-pad A/B routing and semantics coverage; real-device matrix remains ongoing |

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

## Product boundaries

- No interactive map, full wiki mirror, search DSL, usage rankings or competitive simulator.
- No cloud journey sync; JSON import/export is the portability path.
- No invented media for upstream gaps.
- iOS signing/distribution requires a separate product decision.

Full release archive: [docs/RELEASES.md](docs/RELEASES.md). Active phase record: [docs/PHASED_FEATURE_PLAN.md](docs/PHASED_FEATURE_PLAN.md).
