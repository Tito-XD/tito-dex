# Display & system UI layout

## Current layout rule

| Device aspect | Examples | System UI | Custom Wi‑Fi/battery | Home layout |
| --- | --- | --- | --- | --- |
| **Handheld panel** ~1:1, 3:4, 4:4 | RG Rotate, RG35XX square modes | **Immersive** (no system bars) | **Yes** (`HandheldStatusIcons`) | Square dashboard (`useSquareDashboard`) |
| **Other** (phone 19.5:9, tablet, …) | Regular Android phone | **Normal** status + navigation bars | **No** — use OS chrome | Portrait scroll, or horizontal when landscape (below) |

## Home composition

`HomeDashboardBody` picks one of three compositions:

| Composition | Condition | Shape |
| --- | --- | --- |
| `_PortraitHomeLayout` | portrait, non-square | Scrolling stack: trainer → journey → party → quick actions, capped at 520 px |
| `_HorizontalHomeLayout` two-column | square dashboard, or landscape under 560 px tall | Left column trainer + journey, right column party; no-save falls back to two stacked full-width bars |
| `_WideRowsContent` | landscape ≥ 560 px tall and not square (tablets) | Fixed rows: equal-height trainer + journey row, then one capped party strip, centered above the quick bar |

The tablet case is separate because a full-height two-column split balloons its cards — the journey card stretches to half the screen and the party grid drifts. Rows keep both at their natural size.

## Implementation

- `DeviceLayout.isHandheldPanelSize(Size)` — aspect in either orientation
- `DeviceLayout.useHandheldChrome(context)` — native + handheld panel
- `SystemUiCoordinator` — sets `SystemUiMode` from current window size
- `DeviceShell` — `_HandheldNativeShell` vs `_RegularNativeShell` (SafeArea)
- `AppHeader` — `HandheldStatusIcons` only when `useHandheldChrome`

**Not fullscreen app** on regular phones — do not use immersive sticky; show system status and nav bars.

Web preview keeps mock phone frame + decorative status strip (dev only).

## Party card slot grids

`PartyStrip` always shows six slots; the arrangement is declared by the caller, not inferred from constraints (a tablet's half column is wider than a handheld's full bar, so width alone can't tell them apart):

| Caller flags | Columns × rows | Used by |
| --- | --- | --- |
| `compact` only | 3 × 2, horizontal cells | Portrait home |
| `gridMode` | 2 × 3, upright cells | Square/landscape home, save linked (half-width column) |
| `gridMode` + `stripMode` | 6 × 1, upright cells | Square/landscape home without a save, and the tablet row layout |

Upright cells stack sprite over a full-width name and pin the level to the sprite corner as a badge (see DESIGN_SYSTEM). Sprites scale with cell size rather than a fixed value; strip cells cap near-square and center in leftover height instead of stretching.

## Home game version picker

- Tap header game pill → **`showGameEditionGridPicker`** (3–4 column grid, name labels)
- Game **icons** — use bundled assets when available; grid cells retain a text fallback
- Fix: use **route `BuildContext`** for bottom sheet (not `TitoDexApp` state context above `MaterialApp`)
