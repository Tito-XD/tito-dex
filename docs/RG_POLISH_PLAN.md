# RG Polish Plan (0.2.10)

Implementation plan from discussion — items 1–9.

## Status

| # | Item | Status |
|---|------|--------|
| 1 | Home one-screen: merge continue + map, compress layout, header icons | Done |
| 2 | Double underlines | N/A (not reproduced) |
| 3 | Companion tap-to-cycle, local sprites, no name | Done |
| 4 | Party sprites, evolution chain scroll, compress secondary content | Done |
| 5 | Portrait save sync when directory set | Done |
| 6 | Dex offline via Cloudflare | Deferred (user configuring CF) |
| 7 | Per-game emulator launcher | Deferred (new games incoming) |
| 8 | RG D-pad / A·B focus navigation | Done |
| 9 | Remove bottom tab bar | Done |

## 1 — Home dashboard

- Square + portrait: no scroll; continue card + party + quick actions only.
- Remove `TrainerCard`, `JourneyTimeline`, `LauncherWidgets` from home (live on secondary routes).
- `ContinueJourneyCard`: tappable location map replaces separate continue button (`mergeContinue`).
- `CityIllustration`: location-aware pixel thumbnail; ready for CF/R2 cached PNGs later.
- `AppHeader`: remove paw icon beside title.
- `HandheldStatusIcons`: WiFi + battery border/fill use `TitoColors.deepBlue`.

## 3 — Companion

- Cycle `Chikorita` → `Cyndaquil` → `Totodile` on tap.
- Bundle front sprites under `assets/companion/`.
- No speech bubble or species label on home float.

## 4 — Party & evolution

- `PartyMember.speciesId` from HGSS parser for sprite lookup.
- `PartyStrip`: show dex sprite when available; wider mini slots for names.
- `EvolutionChainView`: explicit horizontal scroll + padding (already scrollable; polish clipping).

## 8 — Handheld input

- `HandheldInputShell`: arrow keys / D-pad focus traversal, Enter·A activate, Esc·B back.
- `TitoQuickTile` + header settings: visible focus ring on RG.

## Deferred

- **6** Dex CDN bundle (Worker + R2) after CF account ready.
- **7** Per-game `EmulatorAppChoice` + ROM path in D1.
