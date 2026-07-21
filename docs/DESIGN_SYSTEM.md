# TitoDex Design System

TitoDex uses a warm, compact, modern-retro trainer-device language that remains readable on Android phones and handheld displays. Its personality should be recognizable without depending on private user information. The original visual reference is documented in [UI Reference Notes](./UI_REFERENCE.md).

**Implementation:** Design tokens live in `src/styles/tokens.css` (React reference) and `flutter/lib/theme/tito_colors.dart` (active). Keep both in sync when changing colors or radii. See [Stack Decision](./STACK_DECISION.md).

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

- `TitoShadows.sticker` (0/5px) on cards and buttons, `.stickerSmall`
  (0/3px) on chips/sprites/bubbles, `.stickerPressed` (0/1px) while held.
- `StickerPressable` wraps interactive stickers: touch-down sinks the
  sticker 3px in ~80ms and squashes the shadow; release springs back.
  `ownShadow: false` gives sink-only physics when the inner `StickerCard`
  already paints the drop, so shadows never double.
- Headings tighten to `letter-spacing: -0.02em` (applies in both modes).
- Toggle off = pure flat stickers; every shadow and press effect gates on
  `retroStyle.enabled` and switches live.

## Typography

Prefer friendly, readable type. Avoid overly futuristic UI fonts.

Guidelines:

- Use compact headings.
- Use strong labels for device-like panels.
- Keep dense information readable on square screens.
- Use `clamp()` for responsive text.

Example:

```css
.title {
  font-size: clamp(1.6rem, 5dvw, 3rem);
  letter-spacing: -0.03em;
}

.card-title {
  font-size: clamp(1rem, 2.8dvw, 1.4rem);
}
```

## Layout System

TitoDex must adapt across:

- RG Rotate square screen
- ordinary Android phones
- tablets
- foldables

Rules:

- mobile first
- use CSS Grid and Flexbox
- use `dvh` / `dvw`
- respect safe areas
- never hard-code the app to `720×720`
- square screens should use available space as a dashboard, not a narrow phone column

Base shell example:

```css
.app-shell {
  min-height: 100dvh;
  padding:
    max(16px, env(safe-area-inset-top))
    max(16px, env(safe-area-inset-right))
    max(16px, env(safe-area-inset-bottom))
    max(16px, env(safe-area-inset-left));
}
```

Dashboard example:

```css
.home-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(min(280px, 100%), 1fr));
  gap: clamp(12px, 2.5dvw, 24px);
}
```

Dex grid example:

```css
.dex-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(132px, 1fr));
  gap: clamp(10px, 2dvw, 18px);
}
```

## Home Screen Composition

The home screen should prioritize:

1. TitoDex title
2. Trainer Card
3. Continue Journey large card
4. Quick widgets
5. Recent journey timeline

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

### Continue Journey Card

The dominant action, inspired by the reference Goldenrod City card: deep-blue framed panel, city illustration area, play-time block, badge progress, and clear Continue affordance.

Core content:

- big card
- current game: SoulSilver
- location: Goldenrod City
- 3 badges
- play time
- party mini chips
- warm accent CTA

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
- Journey
- Dex
- Search

Each widget should look like a friendly sticker or device tile.

### Companion Character

Riolu can be represented initially as:

- placeholder sticker
- silhouette
- small badge icon
- future custom illustration

Avoid depending on copyrighted official art assets unless licensing is clear.

## Supplied Reference Translation

The reference image should be interpreted as a product direction, not a requirement to copy every pixel. Preserve the feeling: warm blue device, cream sticker cards, thick navy outlines, Riolu companion presence, dashboard density, and playful Trainer Card energy.
