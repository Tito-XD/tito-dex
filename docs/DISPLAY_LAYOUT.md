# Display & system UI layout

## Current layout rule

| Device aspect | Examples | System UI | Custom Wi‑Fi/battery | Home layout |
| --- | --- | --- | --- | --- |
| **Handheld panel** ~1:1, 3:4, 4:4 | RG Rotate, RG35XX square modes | **Immersive** (no system bars) | **Yes** (`HandheldStatusIcons`) | Square dashboard (`useSquareDashboard`) |
| **Other** (phone 19.5:9, tablet, …) | Regular Android phone | **Normal** status + navigation bars | **No** — use OS chrome | Portrait scroll layout |

## Implementation

- `DeviceLayout.isHandheldPanelSize(Size)` — aspect in either orientation
- `DeviceLayout.useHandheldChrome(context)` — native + handheld panel
- `SystemUiCoordinator` — sets `SystemUiMode` from current window size
- `DeviceShell` — `_HandheldNativeShell` vs `_RegularNativeShell` (SafeArea)
- `AppHeader` — `HandheldStatusIcons` only when `useHandheldChrome`

**Not fullscreen app** on regular phones — do not use immersive sticky; show system status and nav bars.

Web preview keeps mock phone frame + decorative status strip (dev only).

## Home game version picker

- Tap header game pill → **`showGameEditionGridPicker`** (3–4 column grid, name labels)
- Game **icons** — use bundled assets when available; grid cells retain a text fallback
- Fix: use **route `BuildContext`** for bottom sheet (not `TitoDexApp` state context above `MaterialApp`)
