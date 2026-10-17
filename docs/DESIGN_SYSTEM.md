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

| Identity | 中文 | English | Tagline (`taglineFor`) | `AppVisualStyle` / `TitoThemeFamily` |
| --- | --- | --- | --- | --- |
| Default sticker language | 训练家手帐 | Trainer's Journal | 纸贴纸 · 胶带 · 印章 | `classic` / `trainerJournal` |
| Moulded handheld shell | 固态塑料 | Solid Plastic | 半透外壳 · 压铸按键 | `solidPlastic` / `solidPlastic` |
| Colour-block stickers | 扁平贴纸 | Flat UI | 色块 · 大字 · 干脆 | `flatUi` / `flatUi` |

The deliberately playful names describe the perceived texture. In particular,
“Solid Plastic” replaces the earlier Liquid Glass working label, while “Flat
UI” replaces Material 3 as the user-facing name. Internal Flutter `Material`
classes may still be used as implementation primitives. Labels and taglines
live in `flutter/lib/theme/app_visual_style.dart` (`labelFor` / `taglineFor`);
storage values (`classic`, `solid_plastic`, `flat_ui`) never change.

The three themes follow the TitoDex Launcher's visual direction (0.3):

- **训练家手帐** — warm paper (`#fffaf0`) with a thin slate pencil outline
  (`#7c8999`, 1.4px) and slate ink (`#36475b`), on a dotted blue-grey desk with
  faint postmark waves. It keeps the app's hard 0/5 sticker drop and press-down
  physics (a blend, not a replacement). Hero surfaces only add washi tape, a
  -1.4° tilt, dashed inner frames, rubber-stamp date chips and ruled-paper
  sheets. Accent ink `#b0745a` on paper, `#f2c9a8` on the dark desk. Focus is a
  yellow double ring (`#f7d977` + `#ae9562`).
- **固态塑料** — moulded shells: vertical white→tint gradients, a 1.5px inner top
  highlight plus inner bottom darkening, a white rim and a deeper soft drop.
  Hero radius 26. Role tints: trainer lavender `#f6f2ff→#d7cdea`, shelf cyan
  `#ecfafc→#b9dfe7`. Primary round keys are radial die-cast with a specular
  cap. Accent `#3d7f93` (light) / `#b9dfe7` (dark). Focus: white ring + cyan
  glow. All optics are static paint — no live blur in content.
- **扁平贴纸** — solid colour blocks on `#f9f9ff` with `#1a1c20` ink: trainer
  soft-yellow, primary action coral, date pill deep-blue with cream text. No
  shadows anywhere, very large tight numerals, circular icon chips, stadium
  buttons. Focus: a 3.5px ink outline.

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
- thin pencil outlines (Journal), white rims (Plastic), no outline (Flat)
- sticker-like offsets
- badge pills
- panel seams like a small handheld device
- **solid offset sticker shadows are the Journal signature** — a hard
  `0 5px 0` drop with no blur (never Material's soft elevation), plus a
  `0 2px 0 #e4dfd3` paper edge on light cards. Paired with press-down physics
  it reads as a physical handheld key. Plastic uses a deeper soft drop; Flat
  has none.

Surfaces come in three levels (`TitoSurfaceLevel`):

| Level | Use | Journal | Plastic | Flat |
| --- | --- | --- | --- | --- |
| `hero` | 1–3 per screen: trainer card, current shelf / journey | paper + tape + tilt (trainer) or dashed inner frame | role gradient, radius 26 | role colour block |
| `normal` | grouped settings, section cards | paper, slate outline, 0/5 drop + paper edge | moulded tint | `#eceef6` block |
| `dense` | list rows, grid cells, anything repeated | paper, slate outline, 0/3 drop, no decoration | opaque tint, small drop | block, tighter radius |

Tokens are absolute logical px on `TitoSkin` (not halved by
`DeviceLayout.radius`):

| Token | Journal | Plastic | Flat |
| --- | --- | --- | --- |
| `radiusSm / Md / Lg / Hero` | 8 / 11 / 14 / 16 | 10 / 14 / 20 / 26 | 10 / 14 / 18 / 22 |
| `outline`, `outlineWidth` | `#7c8999`, 1.4 | white 78%, 1.1 | none |
| `heroTiltDegrees` | -1.4 | 0 | 0 |
| `headingTracking / displayTracking` (em) | -0.02 / -0.03 | -0.02 / -0.03 | -0.035 / -0.05 |

Performance rules: no new real-time `BackdropFilter` in scrolling content;
Plastic optics are static gradients and painters; tilt and tape only on a few
hero cards, never in lists; dense pages stay solid and opaque.

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
  `retroStyle.enabled` and switches live. `TitoSkin.cardShadow()` and
  `chipShadow` return `null` when it is off, so skinned widgets inherit the
  contract automatically (wrap them in `ListenableBuilder(listenable:
  retroStyle)` if they cache the result).
- Journal outlines are the thinner slate pencil (1.4px) since the launcher
  refresh; the drop and press physics are unchanged.
- Plastic: on = moulded shell with soft drop; off = shell without drop.
- Flat UI never casts a shadow: on = solid colour block, off = outlined
  block (`outlineVariant`, 1.5px). Press physics are a no-op on Flat.

## How to apply the skin

Every `ThemeData` from `buildTitoTheme(style)` registers a `TitoSkin`
extension. Read it with `TitoSkin.of(context)` (falls back to the global
`appVisualStyle` when a test pumps a bare `MaterialApp`). Prefer skin getters
over `appVisualStyle.uses*` branches; branch on `skin.isJournal / isPlastic /
isFlat` only for genuinely different structure.

Primitives (all in `flutter/lib/`):

| Primitive | File | Use |
| --- | --- | --- |
| `TitoSkin.of(context)` | `theme/tito_skin.dart` | tokens: `pageInk`, `pageMutedInk`, `paper`, `ink`, `mutedInk`, `outline`, `accentInkOn(bg)`, `primaryFill`, `chip*`, radii, `heroTint(role)`, `cardShadow()`, `focusRing(r)`, `display(size)`, `heading(size)` |
| `StickerCard.hero(role:)` | `widgets/sticker_card.dart` | trainer / shelf / journey / action hero surfaces; sets ink for its content |
| `StickerCard(variant:)` | same | normal grouped cards |
| `StickerCard.dense()` | same | list rows, grid cells, repeated items |
| `TitoStampChip` | `widgets/tito_chips.dart` | date / status stamp (dashed + tilted on Journal, frosted pill on Plastic, deep-blue block on Flat) |
| `TitoChip` | same | filter / tag chips (`selected`, `tag` luggage shape, `dense`) |
| `TitoRoundKey(tone:)` | same | circular header / action keys (`neutral` or die-cast `action`) |
| `TitoPrimaryButton`, `TitoQuickTile`, `TitoPolaroidQuickTile` | `theme/tito_buttons.dart` | primary CTA and dashboard tiles |
| `TitoDashedFrame`, `TitoDashedBorderPainter` | `widgets/tito_paper.dart` | dashed inner frames / stitched borders |
| `TitoWashiTape` | same | tape strip for a Journal hero (invisible elsewhere) |
| `TitoRuledPaper` | same | sheet / panel body (ruled on Journal, milky on Plastic, plain on Flat) |
| `TitoPageBackground`, `TitoPageContainer` | `widgets/tito_paper.dart`, `widgets/tito_page_container.dart` | page backdrop (desk / moulded / colour blocks) |
| `showTitoModalBottomSheet(ruled:)` | `navigation/tito_page_transition.dart` | skinned sheets; pass `ruled: false` for dense grids |
| `HandheldFocusDecorator`, `TitoFocusRing` | `widgets/handheld_input.dart` | per-theme D-pad focus ring without reflow or remount |
| `StickerSwitch`, `StickerPillToggle`, `StickerGroupLabel`, `StickerIconPlate`, `retroInsetDecoration` | `widgets/retro_forms.dart` | form controls (circular plates on Flat) |
| `AppHeader`, `SecondaryPageScaffold` | `widgets/` | shared chrome; already skinned |

Choosing a level:

- **hero** — at most a few per screen, never inside `ListView.builder`/grids.
  Trainer identity uses `TitoHeroRole.trainer` (the only role with tape and
  tilt on Journal), current team/shelf `shelf`, next stop/journey `journey`
  (dark), primary call-outs `action`.
- **normal** — section and settings cards.
- **dense** — anything repeated or scrolled (Dex grid, move/ability lists,
  team slots). No tilt, tape, dashed frames or blur.

Text directly on the page uses `skin.pageInk` / `skin.pageMutedInk` (cream on
the Journal desk and Plastic shell, ink on Flat). Text inside cards uses
`skin.ink` / `skin.mutedInk`, or `skin.heading()` / `skin.display()` with no
colour so hero tints supply ink. Use `skin.accentInkOn(background)` for the
accent numeral / highlight colour.

### Screenshot harness

```bash
cd flutter
flutter test test/visual/theme_gallery_test.dart --dart-define=TITODEX_THEME_SHOTS=true
```

Writes `flutter/build/theme_shots/<journal|plastic|flat>_<screen>_<480|800>.png`
(primitive galleries `surfaces`, `controls`, `secondary`, `sheet`, `dialog`,
plus app screens `home`, `team`, `dex`, `search`, `settings`) at 480×480 and
800×450 logical. Without the define the galleries run as a ~1s smoke test and
the app screens are skipped. Add a page by extending the route list in the
`app screens` test or adding a gallery widget.

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
