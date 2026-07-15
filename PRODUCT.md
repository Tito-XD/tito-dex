# TitoDex Product Overview

## Positioning

TitoDex is an offline-first Pokémon journey companion for Android handhelds and phones. Its warm device-like interface is part of the product, while save, Pokédex, and battle features remain clear enough for general use.

| TitoDex provides | Current boundary |
| --- | --- |
| Save-aware progress dashboard | HGSS is the supported save parser |
| Manual trainer, team, and journey data | Not a universal save editor |
| Pokédex and structured reference data | Not a full community wiki mirror |
| Battle matchup and estimate tools | Not a competitive simulator replacement |
| Phone and square-screen layouts | Android arm64 is the primary distribution target |

## Primary user flow

1. Select a game edition and optionally connect a supported save directory.
2. Review location, badges, play time, party, and Pokédex progress on the dashboard.
3. Open the team editor, Pokédex, reference hub, or battle utilities as needed.
4. Continue the game through the configured emulator or return later with local state preserved.

The app also supports manual mode for games without a save parser.

## Current capabilities

- HGSS 512 KB save parser, directory sync, and startup auto-load
- Home, Team, Journey, Dex, Search, and Settings flows
- Manual team editing and journey JSON import/export
- National Pokédex 1–1025 with 23 game editions and 11 regional scopes
- Per-game flavor text, obtain locations, moves, abilities, sprites, and Chinese labels
- Structured reference pages for moves, abilities, natures, egg groups, items, weather, terrain, and status
- Type matchup, stat and damage estimates, blind-spot analysis, team shared weaknesses, and common battle modifiers
- Downloadable offline data pack plus an optional APK-bundled offline build
- Responsive phone, tablet, and square handheld layouts

## Product priorities

### Maintain

- clear resume and progress information on the home screen
- correct game and generation context across data and calculations
- offline behavior with explicit download and update states
- readable interaction patterns for touch and handheld controls
- transparent parser and data limitations

### Improve next

- keep lite and offline packages aligned to the same release source
- expand automated coverage for trainer-card, team-editor, and flavor-title behavior
- refine damage calculation and validation coverage
- add HeartGold title detection and single-file save selection
- improve launcher icon, splash, and distribution polish

### Out of scope for now

- account system and hosted journey sync ([proposal](docs/CLOUD_SYNC_PROPOSAL.md))
- runtime scraping of fan wikis in the app
- full competitive usage rankings or complete simulator parity
- untested multi-generation save editing

## Platform

- **Primary:** Android arm64 phones and RG-class handhelds
- **Secondary:** Flutter web preview for UI smoke testing
- **Future:** Linux handheld support after Android workflows are stable
