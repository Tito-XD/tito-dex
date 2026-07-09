# TitoDex Product Notes

## Positioning

TitoDex is a personal companion app for Tito's Pokémon journeys.

It is:

- a journey dashboard
- a trainer card
- a local save companion
- a lightweight game-context helper
- a warm device UI

It is not:

- a Pokémon encyclopedia
- a Bulbapedia / 52Poké / Serebii replacement
- a competitive battle database
- a universal save manager in Phase 1
- a public social network

## Primary User Story

As Tito, when I open TitoDex, I want to immediately see my current Pokémon journey so I can continue playing without re-orienting myself manually.

## Home Screen Structure

The supplied UI reference is the current north star: a deep-blue and cream companion device with a Trainer Card, Goldenrod City Continue Journey card, party panel, quick action tiles, launcher widgets, and Riolu encouragement sticker.


The first home screen should include:

1. **TitoDex title**
2. **Trainer Card**
   - trainer name
   - current generation / game
   - companion character, initially Riolu
3. **Continue Journey card**
   - current game: SoulSilver
   - current location: Goldenrod City
   - badge progress: 3 badges
   - play time
   - party summary
4. **Quick widgets**
   - Team
   - Journey
   - Dex
   - Search
5. **Recent timeline**
   - short journey notes
   - next reminder
   - optional local checklist items

## Phase 1 Mock Data

Phase 1 can hard-code:

```ts
const currentJourney = {
  game: 'SoulSilver',
  location: 'Goldenrod City',
  badges: 3,
  playTime: '18:42',
  party: ['Quilava', 'Riolu', 'Flaaffy', 'Togepi'],
  timeline: [
    'Reached Goldenrod City',
    'Won Hive Badge',
    'Added Riolu as companion',
  ],
};
```

Mock data is acceptable because the immediate goal is product shape and feeling, not save parser completeness.

## Product Priorities

### Must Have

- Continue Journey as the dominant home action.
- Current game context visible everywhere important.
- Responsive Android-first layout.
- Local-first data assumptions.
- Visual language distinct from Material Design defaults.

### Should Have

- Trainer Card feeling.
- Riolu companion presence.
- Compact widget dashboard.
- **HGSS national dex 1–493** with offline CDN bundle (`dex.tito.cafe` v4).
- Journey timeline.

### Could Have Later

- Save dex seen/caught flags from `.sav`.
- Local backup browsing.
- Journey cloud sync (dex CDN is live; see `CLOUDFLARE_DEX_CDN.md`).
- Route notes.
- Game-specific checklists.
- Generation-specific data packs.
- Web companion at `tito.cafe/pokedex` (reuse CDN assets).

### Should Not Have in Phase 1

- full Pokédex encyclopedia (beyond HGSS 493 scope)
- all-game parser abstraction
- account system
- OCR
- large public content ingestion

### Shipped (v0.2.25)

- Save parser integration (HGSS retail `.sav`)
- Emulator launcher (Continue → pick / remember app)
- Mock Dex → **real offline dex** with PNG sprites + artwork viewer
