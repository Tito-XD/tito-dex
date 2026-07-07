# TitoDex Design System

TitoDex should feel like a warm Pokémon companion device, not a generic Android application. The current UI north star is captured in [UI Reference Notes](./UI_REFERENCE.md).

## Design Personality

Keywords:

- warm device UI
- modern retro
- sticker UI
- trainer journey
- compact
- friendly
- companion
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
- soft shadows, not heavy Material elevation

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

Feels like the reference card: cream surface, deep-blue text, companion portrait/sticker, trainer identity, and badge emblem. It should feel personal rather than like an account profile.

Core content:

- Tito name
- current game
- companion Riolu
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
