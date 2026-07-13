# TitoDex Product Notes

## Positioning

TitoDex is a **journey companion** for Pokémon playthroughs on a handheld (primarily RG / Android).

| It is | It is not |
| --- | --- |
| Journey dashboard & trainer card | Full Pokédex / wiki |
| Local save helper (HGSS) | Universal save manager |
| Lightweight reference (moves, types, items) | Competitive battle platform |
| Warm device UI | Material-default Android app |

## Primary user story

When I open TitoDex, I see my **current journey** — game, location, badges, party, recent notes — so I can continue without re-orienting.

## Home screen (north star)

1. Trainer card (name, game, companion sprite)  
2. Continue journey card (location, badges, play time, party snapshot)  
3. Quick access — Team, Journey, Dex, Search  
4. Recent timeline / reminders  

Reference: [docs/UI_REFERENCE.md](docs/UI_REFERENCE.md)

## Shipped (v0.4.6)

- HGSS save parser + directory sync + seen/caught on dex grid  
- National dex **1–1025**, CDN offline bundle v5, 23 game editions, regional filters  
- Detail tabs: flavor, stats, obtain locations, moves per game  
- Search hub: encyclopedia (moves, abilities, natures, items, weather, …) with **dex drill-down filters**  
- Battle tools (partial): type matchup, stat calc, quick damage  
- Chinese catalog in bundle `l10n/`; update prompts + incremental l10n sync  
- RG release APK pipeline (~21 MB arm64)

## Priorities

### Must have
- Continue journey as dominant home action  
- Current game context on important surfaces  
- Offline-first dex & reference where possible  
- Distinct visual language (DeviceShell, sticker cards)

### Should have next
- Blind-spot / coverage analysis for teams  
- Richer damage calc; IV tools (lower priority)  
- Launcher icon & splash polish  
- HeartGold detection, single-file save pick  

### Out of scope (for now)
- Account system, OCR, journey cloud sync ([proposal](docs/CLOUD_SYNC_PROPOSAL.md))  
- Usage rankings, full Showdown parity  
- Runtime scraping of fan wikis in the app  

## Platform

- **Now:** Android (phone + RG Rotate), arm64 APK  
- **Later:** Linux handheld, optional web companion (save sync needs `dart:io` strategy)
