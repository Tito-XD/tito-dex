# TitoDex Typography

## Dex Typography Spec (secondary pages)

Established from the Pokédex list/detail screens (v0.2.23+). This is the **comfort baseline** for all secondary routes on RG handheld.

### Tokens (`SecondaryTypography`)

| Tier | px | Token | Typical use |
|------|-----|-------|-------------|
| Page title | **22.5** | `onGradient.title` | `← 图鉴 · 心金` app bar |
| Section | **15** | `onCard.h15` / `onGradient.h15` | 「图鉴描述」「种族值」 |
| Body | **14** | `onCard.body14` | Flavor text, paths, notes |
| Meta / emphasis | **14** | `onCard.meta14` | Counts, stat values, tab titles |
| Small / team | **12** | `small12` / `team12` | Bottom tabs, HP/EXP row, hints |

All values are **fixed logical pixels** — they do not multiply by `handheldUiScale` (1.5×).

### Route behavior

Secondary routes use `SecondaryTypography` for the shared 22.5 / 15 / 14 /
12px hierarchy. Remaining `context.tito` fallbacks also resolve at the fixed
secondary-page size, so no route-level font wrapper is required.

`TitoFontScale` was retired for v0.8.5. Page chrome, layout dimensions, and body
type must not share an inherited multiplier.

### Pages on this spec

| Route | Status |
|-------|--------|
| Dex list / detail | ✅ Reference |
| Team | ✅ |
| Journey | ✅ |
| Search | ✅ |
| Settings | ✅ |
| Companion tools (type matchup / stat calc / quick damage) | ✅ |

### Home dashboard (exception)

The home screen uses **Dashboard Scale** — intentionally larger for glanceability:

- App title ~33px (layout-driven)
- Quick-action labels use their explicit compact / regular tile sizes
- Trainer micro card uses `homeDetailMultiplier` (up to 2.25×)
- Dashboard cards that keep the larger legacy visual use explicit
  `context.titoHome` tokens

Do **not** force Dex Spec onto the home dashboard.

### Legacy migration map

When replacing `context.tito` on secondary pages:

| Old token | New token |
|-----------|-----------|
| `cardTitle` / `cardSectionTitle` | `onCard.h15` |
| `cardBody` / `cardBodyStrong` / `cardBodyEmphasis` | `onCard.body14` (+ weight) |
| `cardMuted` / `caption` | `onCard.small12` + `mutedInk` |
| `cardLabel` | `onCard.team12` + `mutedInk` |
| `cardValue` | `onCard.meta14` |
| `pageSubtitleOnGradient` | `onGradient.body14` or `small12` |
