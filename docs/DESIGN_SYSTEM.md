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

- Cream: app background and card warmth. Trainer's Journal paper is a
  slightly lighter cream (`#FFF9ED`) than the shared card token.
- Blue gray: device shell, panels, secondary surfaces.
- Deep navy: text and top-level contrast. Trainer's Journal outlines use a
  softer gray-blue (`#7C8999`) instead of near-black ink.
- Soft yellow: friendly highlights, badge glow.
- Coral: sparing call-to-action accent.
- Mint: success / gentle progress.

## Shape and Surface

- rounded cards
- sticker-like offsets
- badge pills
- panel seams like a small handheld device
- **Trainer's Journal** uses a thin gray-blue outline and a short paper-edge
  shadow. **Solid Plastic** keeps moulded blurred depth. **Flat UI** keeps
  soft Material elevation. Journal press-down is a 1px sink; Plastic keeps
  the 3px physical key press.

Tokens (`flutter/lib/theme/tito_colors.dart` and
`flutter/lib/theme/trainer_journal.dart`, values are what ships):

| Token | Value | Use |
| --- | ---: | --- |
| `TitoRadii.sm` | 8 | chips, pills, tabs, badges, segmented buttons, list tiles |
| `TitoRadii.md` | 12 | buttons, text fields, menus, snack bars |
| `TitoRadii.lg` | 16 | cards; sheets and dialogs in Trainer's Journal |
| `TitoRadii.xl` | 28 | sheets and dialogs in Solid Plastic / Flat UI |
| `TitoBorders.card` | 2.0 | Flat UI / historical card outline |
| `TitoBorders.element` | 1.5 | Flat UI / historical small-control outline |
| `TitoBorders.journalCard` | 1.25 | Trainer's Journal cards, buttons, fields, sheets, dialogs |
| `TitoBorders.journalElement` | 0.85 | Trainer's Journal chips, badges, small controls |
| `TitoBorders.journalHairline` | 0.75 | Trainer's Journal empty-slot dashes |
| `TitoBorders.glass` | 1.1 | Solid Plastic light hairline (`LiquidGlassSurface`) |

Radii are fixed on every device: `DeviceLayout.rSm/rMd/rLg` are plain
pass-throughs and must not halve on the handheld. Never write a literal outline
width in a widget — pick the token that matches the surface size. Font sizes
stay on the existing `TitoTypography` / `DeviceLayout` rules in every theme;
Trainer's Journal only remaps weight and the shared ink/muted colours.

Shadow recipes are per theme and never mixed:

| Theme | Recipe | Cards / buttons | Chips / sprites | Pressed |
| --- | --- | --- | --- | --- |
| Trainer's Journal | `TrainerJournalShadows` — hard, no blur | paper lip `0 2px` + faint `0 3px`; controls `0 2px` | none | `0 1px 0` |
| Solid Plastic | `SolidPlasticShadows` — moulded, blurred | `0 8px 16px` + `0 2px 3px` | `0 5px 11px` | `0 2px 7px` |
| Flat UI | `TitoShadows` — soft Material elevation (**Flat UI only**) | `0 2px 8px` | `0 1px 4px` | `0 1px 3px` |

Stock Material surfaces (`AlertDialog`, bottom sheets, `Divider`, chips,
menus, segmented buttons, list tiles, checkbox/radio) are styled purely by the
`ThemeData` built in `tito_theme.dart` for each style. Do not re-style them at
call sites: a plain `AlertDialog`, `showModalBottomSheet` (drag handle on) and
`Divider()` already look right in every theme.

## Selection colours

| Control | Selected colour | Notes |
| --- | --- | --- |
| Single choice drawn as segments / tabs / custom method chips | `softYellow` | one active option at a time (`SegmentedButton`, battle-calc mode chips, detail move-method chips, stats toggle) |
| Any Material chip (`FilterChip`, `ChoiceChip`, `InputChip`) and toggles | `mint` | `ChipThemeData` is shared by every chip class, so single-choice chip groups (weather, terrain, status…) also select in mint — do not fight it with local `selectedColor` |
| Detail bottom tabs | type colour tint | intentional exception: the tab bar is the species' colour identity |
| Flat UI (all of the above) | `colorScheme.secondaryContainer` | Material semantics, no cream/yellow |

Coral is reserved for destructive actions, warnings and the primary CTA — never
as a selection highlight.

## Text tokens

| Where the text sits | Token |
| --- | --- |
| Page level, directly on the shell / gradient | `SecondaryTypography.onPage(context)` (theme-aware) |
| Deep card (deepBlue, slate, gradient fills) | `SecondaryTypography.onGradient` (cream) |
| Cream / sky / mint card | `SecondaryTypography.onCard` (ink) |

`onGradient` is a fixed cream and does not adapt to Flat UI; use `onPage` for
anything that is not inside a deep card.

## Loading indicators

| Situation | Widget |
| --- | --- |
| Determinate progress (downloads, installs, sync) | `TitoProgressBar` |
| Whole section / page waiting | `TitoLoadingPanel` or `TitoPokeballLoading` |
| Image / sprite placeholder | `TitoSkeletonBox` |

No bare `CircularProgressIndicator` in feature code.

## Theme-blind components are bugs

Every shared widget must branch on `appVisualStyle` (`usesTrainerJournal`,
`usesSolidPlastic`, `usesFlatUi`) — `widgets/sticker_card.dart` is the
reference implementation. A component that hard-codes cream cards, ink borders
or hard shadows will look wrong in Solid Plastic and Flat UI; a component that
reads only `Theme.of(context).colorScheme` loses the sticker language in
Trainer's Journal. Fix the component, do not special-case the caller.

### Retro sticker feel (Flutter implementation)

Settings → 界面风格 → **Retro 贴纸手感** (default on) drives the whole
package through `retroStyle`:

- `TrainerJournalShadows.sticker` (paper lip) on cream cards, `.control`
  (0/2px) on buttons and quick tiles, `.stickerSmall` empty on chips/sprites,
  `.stickerPressed` (0/1px) while held. Solid Plastic swaps in
  `SolidPlasticShadows`; Flat UI uses `TitoShadows`.
- `StickerPressable` wraps interactive stickers: Journal sinks 1px in ~80ms;
  Solid Plastic keeps the 3px physical key. `ownShadow: false` gives
  sink-only physics when the inner `StickerCard` already paints the drop.
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
Trainer's Journal remaps Nunito weights one step lighter (body Regular 400,
labels SemiBold 600, titles Bold 700) because the bundled files have no
Medium cut. Sizes stay the same in every theme.
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

### Loading feedback

First-open reads should reuse cached data and avoid eager hidden-page or full-list construction. Ordinary image cells retain static placeholders. Slow image slots and section loads use one pale white Poké Ball rotating in place, with constant opacity and no shimmer; a faint outline keeps it visible on light surfaces. Shared loaders wait 160 ms before appearing and disappear as soon as content is ready. Respect reduced motion and stop tickers in hidden battle tools. Measured download progress and the Assistant's semantic response animation keep their own behavior. See [FIRST_OPEN_LOADING.md](./FIRST_OPEN_LOADING.md).

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

The reference image should be interpreted as a product direction, not a requirement to copy every pixel. Preserve the feeling: warm blue device, cream sticker cards, companion presence, dashboard density, and playful Trainer Card energy. Trainer's Journal now uses thinner gray-blue outlines and a paper lip instead of chunky near-black ink.


### Compact fact grids and answer progress (0.9.17)

Journey and Team facts share `TitoFactGrid` / `TitoFactTile`: 8px row/column
spacing, `TitoRadii.sm`, 10px cell padding, 12px label and 14px value separated
by 6px. Cells grow to their content. The requested column count is an upper
bound; the minimum 84px cell width scales with system text size. Trainer's
Journal fact tiles use a pale fill with no outline. Flat keeps
`TitoBorders.element` and Plastic uses `TitoBorders.glass` for the light edge.
Flat text uses the semantic on-surface colours.

Native answer progress uses an 18px prop in a 26px leading lane, with the
12px progress label aligned to the answer's leading edge. Loading rotates
only semantically related props, while completion holds the original subject.
Idle prompts keep their separate inline word transitions. Primary buttons
wrap long labels within available width without shrinking accessibility text.

### Setup and update surfaces (0.9.18)

First-run guidance reuses the App theme, existing avatar cropper and responsive
scrollable content; it is replayable from Settings without enabling Ask consent.
The companion Settings icon uses the same outlined Poké Ball family as other
icons. App-update progress and actions live in Settings → About. Custom form
and exact-game/DLC choice sheets retain themed spacing, selection and large-text
behavior; Android installer and launcher confirmation remain system surfaces.
