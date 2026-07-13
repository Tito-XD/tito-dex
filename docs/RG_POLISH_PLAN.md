# RG Polish Plan (0.2.10 → 0.2.25)

Implementation plan from discussion — items 1–9, plus follow-up CDN work.

## Status

| # | Item | Status |
|---|------|--------|
| 1 | Home one-screen: merge continue + map, compress layout, header icons | Done |
| 2 | Double underlines | N/A (not reproduced) |
| 3 | Companion tap-to-cycle, local sprites, no name | Done |
| 4 | Party sprites, evolution chain scroll, compress secondary content | Done |
| 5 | Portrait save sync when directory set | Done |
| 6 | Dex offline via Cloudflare | **Done** — `dex.tito.cafe`, bundle v4 PNG |
| 7 | Per-game emulator launcher | Deferred (new games incoming) |
| 8 | RG D-pad / A·B focus navigation | Done |
| 9 | Remove bottom tab bar | Done (replaced with contextual nav / quick tiles) |

## 1 — Home dashboard

- Square + portrait: no scroll; continue card + party + quick actions only.
- Remove `TrainerCard`, `JourneyTimeline`, `LauncherWidgets` from home (live on secondary routes).
- `ContinueJourneyCard`: tappable location map replaces separate continue button (`mergeContinue`).
- `CityIllustration`: location-aware pixel thumbnail.
- `AppHeader`: remove paw icon beside title.
- `HandheldStatusIcons`: WiFi + battery border/fill use `TitoColors.deepBlue`.

## 3 — Companion

- Cycle `Chikorita` → `Cyndaquil` → `Totodile` on tap.
- Bundle front sprites under `assets/companion/`.
- No speech bubble or species label on home float.

## 4 — Party & evolution

- `PartyMember.speciesId` from HGSS parser for sprite lookup.
- `PartyStrip`: show dex sprite when available; wider mini slots for names.
- `EvolutionChainView`: explicit horizontal scroll + padding.

## 6 — Dex CDN (Jul 2026)

- Worker **`tito-dex`** on **`dex.tito.cafe`** → R2 **`titodex-dex`**
- Bundle **v4**: PNG sprites + type icons; legacy JPEG removed
- **`v2/artwork/{id}.png`** — full-size lazy tier (App tap-to-zoom; future web pokedex)
- App: Settings → CDN bundle download; compile-time defaults in `dex_cdn_config.dart`
- Deploy branch: **`deploy/dex-cdn`**

## 8 — Handheld input

- `HandheldInputShell`: arrow keys / D-pad focus traversal, Enter·A activate, Esc·B back.
- `TitoQuickTile` + header settings: visible focus ring on RG.

## Deferred

- **7** Per-game `EmulatorAppChoice` + ROM path in D1.
- Save-linked dex seen/caught from `.sav`.
- Custom launcher icon / splash.

## Releases

Latest RG APK: [v0.2.25](https://github.com/Tito-XD/tito-dex/releases/tag/v0.2.25) — `releases/TitoDex-0.2.25-rg-arm64.apk` (arm64-v8a, ~22 MB).

**Agents:** same naming as 0.2.1–0.2.11; build with `flutter build apk --release --target-platform android-arm64`. Do **not** use `--split-per-abi` (RG rejects compressed native libs). Details: [AI_CONTEXT.md](./AI_CONTEXT.md) · [flutter/README.md](../flutter/README.md).
