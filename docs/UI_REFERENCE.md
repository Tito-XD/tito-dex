# UI Reference Notes

These notes preserve the original visual reference for TitoDex and document the design anchors that remain relevant to the Flutter implementation.

## Overall Impression

TitoDex should feel like a warm Pokémon trainer device, with a blue handheld shell and sticker-like panels. The UI should be personal in character, playful, readable, and efficient on phones and square handheld screens rather than relying on default Material presentation.

The reference combines three product forms:

1. **Phone app** — portrait layout with status bar, top app bar, trainer card, Continue Journey card, party row, quick actions, and bottom navigation.
2. **Square / handheld dashboard** — device-frame layout optimized for RG Rotate-like screens, with Continue Journey, Current Party, and large quick tiles visible at once.
3. **Launcher / home widgets** — small glanceable cards showing current game, location, play time, badges, and companion presence.

## Visual Anchors

Use these as design anchors:

- TitoDex wordmark with its small paw/device motif.
- Deep blue header and navigation surfaces.
- Cream cards with thick navy outlines.
- Slate-blue device shell / panel background.
- Soft yellow badge accents.
- Coral-orange Dex/action accent.
- Sticker tape, star stickers, badge stickers, and soft drop shadows.
- City illustration panel for Continue Journey, initially Goldenrod City.
- Optional companion sticker or lightweight status illustration.

## Reference Palette

The supplied reference labels this palette:

- Deep Blue: `#2F4361`
- Slate Blue: `#7B91A6`
- Sky Blue: `#AFC7DA`
- Cream: `#F3E4B3`
- Coral: `#FF8F6A`
- Ink: `#221F26`

Project tokens may adapt these slightly for readability, but the feel should remain close to the reference.

## Icon Style

Icons should be simple, rounded, outlined, and friendly. Use navy outlines with minimal fills. Preferred icon motifs:

- paw
- open book
- storage / box
- magnifying glass
- badge
- gear
- Poké Ball-inspired Dex symbol

Avoid thin generic system icons that make the app feel too much like default Android.

## Home Screen Layout Targets

### Phone Portrait

Stacked order:

1. Top status / app bar
2. Trainer Card
3. Continue Journey card
4. Current Party row
5. Quick action tiles
6. Bottom navigation

### Square / RG Rotate Dashboard

Use a dashboard layout instead of simply scaling phone portrait:

- Continue Journey card on the left or dominant area.
- Current Party panel on the right.
- Quick action tiles along the lower row.
- A companion sticker may sit outside or overlap the device panel edge when space allows.

### Launcher Widgets

Design small glanceable variants:

- current game + location + play time
- compact Continue card
- TitoDex mini trainer card
- badge progress card

## Main Screen Concepts

The reference includes initial concepts for:

- Continue
- Team
- Dex
- Journey
- Search

These screens should keep the same card, outline, badge, and sticker language. Do not let secondary screens drift into generic list screens.

## Interaction and Motion Direction

Potential later motion:

- page transition between Dex / Journey with small card-slide motion
- device sound feedback for scan/tap moments
- lightweight companion or status animation
- badge sparkle / unlock animation

Motion should be light and delightful, not heavy or distracting.

## Implementation Notes

When Phase 2 UI begins:

- create reusable tokens for the reference palette
- create card, tile, badge, and sticker primitives first
- build the Home screen before secondary pages
- verify square layout early
- reserve space for illustration/sticker assets even if placeholders are used
- avoid copyrighted official art unless licensing is clear; use placeholders or custom art direction instead
