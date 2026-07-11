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

### Required wrapper

Every secondary page must wrap content in:

```dart
TitoFontScale(
  multiplier: 1.0,
  child: /* page body */,
)
```

This keeps any remaining `context.tito` fallbacks at ×1.0 on RG instead of ×1.5.

### Pages on this spec

| Route | Status |
|-------|--------|
| Dex list / detail | ✅ Reference |
| Team | ✅ |
| Journey | ✅ |
| Search | ✅ |
| Settings | ✅ |

### Home dashboard (exception)

The home screen uses **Dashboard Scale** — intentionally larger for glanceability:

- App title ~33px (layout-driven)
- Quick-action labels 20px (`TitoFontScale 2.0`)
- Trainer micro card uses `homeDetailMultiplier` (up to 2.25×)

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
