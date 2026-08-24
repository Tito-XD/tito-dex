# TitoDex Design System

TitoDex uses a warm, compact, modern-retro trainer-device language that remains readable on Android phones and handheld displays. Its personality should be recognizable without depending on private user information.

**Implementation:** Active design tokens live in `flutter/lib/theme/`. The
pre-Flutter React mock was removed in v0.6.5; values below document the Flutter
implementation rather than a second UI stack. Architecture boundaries live in
[ARCHITECTURE.md](./ARCHITECTURE.md).

## Design Personality

Keywords:

- warm device UI
- modern retro
- sticker UI
- playthrough progress
- compact
- friendly
- companion-like
- soft but sturdy

## Theme and skin names

Theme names are localized labels, not technology claims. Never show a
Chinese/English slash pair in the UI: Chinese locales use the Chinese column;
all other locales currently use the English column until broader localization
lands.

| Identity | 中文 | English | Implementation |
| --- | --- | --- | --- |
| Default sticker language | 训练家手帐 | Trainer's Journal | Base app / built-in classic option |
| Glass-inspired experiment | 固态塑料 | Solid Plastic | Built-in option, adapted from `codex/liquid-glass-ui` |
| Flat native experiment | 扁平贴纸 | Flat UI | `codex/material-ui-native`; built-in option beside 训练家手帐 |

The deliberately playful names describe the perceived texture. In particular,
“Solid Plastic” replaces the earlier Liquid Glass working label, while “Flat
UI” replaces Material 3 as the user-facing name. Internal Flutter `Material`
classes may still be used as implementation primitives.

## Color Direction

Use a blue-gray, cream, and deep-navy base with warm accent colors.

Suggested tokens, aligned with the supplied UI reference:

```css
:root {
  --color-deep-blue: #2f4361;
  --color-slate-blue: #7b91a6;
  --color-sky-blue: #afc7da;
  --color-cream: #f3e4b3;
  --color-coral: #ff8f6a;
  --color-ink: #221f26;
  --color-soft-yellow: #f7d977;
  --color-card: #fff7e6;
  --color-muted-ink: #536273;
}
```

Color usage:

- Cream: app background and card warmth.
- Blue gray: device shell, panels, secondary surfaces.
- Deep navy: text, outlines, top-level contrast.
- Soft yellow: friendly highlights, badge glow.
- Coral: sparing call-to-action accent.
- Mint: success / gentle progress.

## Shape and Surface

- rounded cards
- chunky borders
- sticker-like offsets
- badge pills
- panel seams like a small handheld device
- **solid offset sticker shadows are the signature** — a hard `0 5px 0` drop
  with no blur (never Material's soft elevation). Paired with press-down
  physics it reads as a physical handheld key.

Suggested tokens:

```css
:root {
  --radius-sm: 10px;
  --radius-md: 16px;
  --radius-lg: 24px;
  --radius-xl: 32px;
  --outline-thick: 3px;
  --outline-thin: 2px;
  --shadow-sticker: 0 5px 0 rgba(24, 40, 59, 0.22);
  --shadow-soft: 0 12px 32px rgba(24, 40, 59, 0.14);
}
```

### Retro sticker feel (Flutter implementation)

Settings → 界面风格 → **Retro 贴纸手感** (default on) drives the whole
package through `retroStyle`:

- `TrainerJournalShadows.sticker` (0/5px) on cards and buttons, `.stickerSmall`
  (0/3px) on chips/sprites/bubbles, `.stickerPressed` (0/1px) while held.
- `StickerPressable` wraps interactive stickers: touch-down sinks the
  sticker 3px in ~80ms and squashes the shadow; release springs back.
  `ownShadow: false` gives sink-only physics when the inner `StickerCard`
  already paints the drop, so shadows never double.
- Headings tighten to `letter-spacing: -0.02em` (applies in both modes).
- Toggle off = pure flat stickers; every shadow and press effect gates on
  `retroStyle.enabled` and switches live.

## Typography

Bundled Nunito and `SecondaryTypography` provide the fixed comfort baseline for
secondary routes. These sizes do not multiply by `handheldUiScale`:

| Tier | px | Token | Typical use |
| --- | ---: | --- | --- |
| Page title | 22.5 | `onGradient.title` | Secondary app bars |
| Section | 15 | `onCard.h15` / `onGradient.h15` | Card headings |
| Body | 14 | `onCard.body14` | Descriptions and paths |
| Meta | 14 | `onCard.meta14` | Counts, values and tabs |
| Small | 12 | `small12` / `team12` | Hints, HP/EXP and compact labels |

Dex, Team, Journey, Search, Settings and battle/Sleep tools use this hierarchy.
The Home dashboard intentionally stays larger for glanceability: its title is
layout-driven near 33 px, quick tiles own explicit sizes, and trainer details
may use `homeDetailMultiplier`. `TitoFontScale` is retired; layout dimensions
and body type must not share an inherited multiplier.

## Layout and system UI

| Device | System UI | Header status | Home composition |
| --- | --- | --- | --- |
| Handheld panel around 1:1 / 3:4 / 4:3 | Immersive | TitoDex Wi-Fi/battery | Square or short-landscape dashboard |
| Regular phone/tablet | Native status/navigation bars | OS chrome | Portrait stack or wide rows |

`DeviceLayout`, `SystemUiCoordinator` and `DeviceShell` own that split. Regular
phones must not use immersive sticky. Web keeps the mock device frame for
preview only. The handheld gradient remains full bleed, while page content
keeps a small 6 px top/bottom optical inset because immersive mode removes the
system status and gesture-bar safe areas.

`HomeDashboardBody` has three explicit compositions:

| Composition | Condition | Shape |
| --- | --- | --- |
| Portrait | Non-square portrait | trainer → journey → party → quick actions |
| Horizontal | Square or landscape under 560 px tall | trainer/journey beside party |
| Wide rows | Non-square landscape at least 560 px tall | natural-height top row plus capped party strip |

`PartyStrip` always renders six slots: portrait uses 3×2 horizontal cells,
save-linked square/short landscape uses 2×3 upright cells, and no-save/wide-row
layouts use a centered 6×1 strip. Callers select the mode explicitly rather
than inferring it from width. The header game pill opens the 3–4 column edition
grid and always retains a text fallback for missing icons.

## Home Screen Composition

The home screen should prioritize:

1. TitoDex title
2. Trainer Card
3. Journey status card when the selected game has save-linked support
4. Six-slot party card
5. Team / Dex / Search quick widgets

Square screens may show these as a dashboard with multiple panels visible at once. Phone portrait can stack them.

## Component Direction

### Trainer Card

Use a cream surface, deep-blue text, avatar or companion illustration, trainer identity, and concise progress metadata. It should feel specific to the current journey rather than like a generic account profile.

Core content:

- trainer display name
- current game
- avatar or companion illustration
- badge strip
- soft yellow or blue-gray panel

On normal RG panels the compact Trainer Card uses a slightly taller frame and
larger avatar/type; only the minimum 360 px compatibility layout keeps the
short micro height.

### Journey Card

The save-linked journey entry is a compact deep-blue status block rather than a
literal “continue game” button. It opens Journey detail; emulator launch is a
separate action there and in Settings. Manual/dex-only editions omit the card.
On the narrow RG half-column, badge progress owns one line and play time plus
the save-assistant summary own a second line; do not concatenate all metadata
into one truncated row.

Core content:

- localized current location and selected game context
- play time and separate regional badge progress where available
- latest save-assistant reminder / nearby-capture summary
- clear secondary-page affordance

### Party Card

Six slots, always all six — filled members and empty slots share the same cell frame so the card reads as a device's party screen rather than a variable-length list. Empty cells stay muted with a dashed-feeling low-alpha border and a plus glyph.

Cells are **upright**: sprite on top, name centered below across the full cell width. The name gets the whole width because the level is not a text line — it rides on the sprite.

**Level badge.** The level sits on the sprite's bottom-right corner as a small softYellow pill with an ink outline, the same visual family as journey badge pills. This is the general pattern for a short numeric qualifier attached to an image: put it on the artwork, not in the text stack. It buys back a whole text line, which goes to the sprite.

Rules:

- badge type scales with the sprite (roughly a quarter of sprite size, floored around 7.5 px so it stays legible on the square handheld)
- no badge when the value is unknown — never render a placeholder dash
- sprite size derives from the cell, never a fixed constant; cells that would stretch (a card given more height than it needs) cap near-square and center instead

### Quick Widgets

Small chunky buttons:

- Team
- Dex
- Search

Each widget should look like a friendly sticker or device tile.

### Companion Character

The companion is user-selectable and may use static, animated, shiny and cry
media where the audited catalog has an explicit candidate. Missing form media
must remain missing rather than silently borrowing another form. Source and
rights boundaries are maintained in `CREDITS.md` and the in-app credits page.

## Supplied Reference Translation

The reference image should be interpreted as a product direction, not a requirement to copy every pixel. Preserve the feeling: warm blue device, cream sticker cards, thick navy outlines, companion presence, dashboard density, and playful Trainer Card energy.
