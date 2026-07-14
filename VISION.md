# TitoDex Vision

TitoDex is a warm, offline-first companion for Pokémon playthroughs. It should feel like picking up a familiar trainer device: compact, recognizable, and ready to continue from the last save.

## Product outcome

When TitoDex opens, a user should be able to answer three questions quickly:

1. Which game and save are active?
2. What is the current location, party, and progress?
3. Which reference or battle tool is useful next?

The app combines save-aware progress, manual team management, Pokédex data, and battle utilities. It does not aim to reproduce every page of a community wiki or the full scope of a competitive simulator.

## Experience goals

- fast to scan on small and square screens
- useful with or without a supported save file
- reliable when offline after data installation
- consistent across the dashboard, Pokédex, reference pages, and tools
- visually distinctive, playful, and recognizably TitoDex without reducing readability

Visual direction: a modern-retro trainer device using blue-gray, cream, deep navy, sticker-like cards, friendly typography, and small moments of personality. See [docs/DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md).

## Product constraints

- **Playthrough utility first** — prioritize features that help users resume, plan, or understand the selected game.
- **Game-scoped behavior** — respect generation mechanics, edition availability, and regional Pokédex rules.
- **Offline-first delivery** — keep core flows functional from local saves, downloaded data, and APK fallbacks.
- **Incremental save support** — HGSS is the first parser; add other games only with tested, explicit boundaries.
- **Focused reference scope** — link related data and provide useful filters without becoming a general-purpose wiki.

## Expansion order

Save parsing and game-specific features should expand according to demand, test fixtures, and implementation confidence. New game support must define its save format, edition rules, data coverage, and fallback behavior before release.
