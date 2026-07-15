# TitoDex Roadmap

> **Latest release:** [v0.4.99](https://github.com/Tito-XD/tito-dex/releases/tag/v0.4.99) · Lite `0.4.99+52` · Offline `0.4.99-offline+53`.
>
> **Current `main` source baseline:** `0.4.99+52`.

## Recent release history

| Version | Summary |
| --- | --- |
| **v0.4.99** | Align the complete release source and publish matching lite/offline packages |
| **v0.4.98** | Correct per-game titles in the Pokédex flavor-text carousel |
| **v0.4.97** | Trainer-card name-line copy adjustment |
| **v0.4.96** | Dense trainer-card layout fix for square screens |
| **v0.4.95** | Trainer-card bootstrap, loading panels, team editor, settings cleanup, and download progress controls |
| **v0.4.94** | Compact settings sections and paginated Pokédex filter results |
| **v0.4.93** | Ability fallback, game labels, location coverage, and ability filtering |
| **v0.4.92** | Combined matchup summary card and dynamic dashboard title |
| **v0.4.91** | Attacker selection and ability-aware battle filters |
| **v0.4.85** | Terastal, held items, status effects, defensive abilities, and team shared weaknesses |
| **v0.4.8** | Generation-aware abilities, matchup modifiers, and blind-spot tools |
| **v0.4.7** | Sprite picker, 1–1025 progress, home layout, and avatar crop fix |
| **v0.4.6** | Reference drill-down, sprite fixes, and offline update prompts |
| **v0.4.0** | 23 game editions, 11 regional Pokédex scopes, and segmented search hub |
| **v0.3.0** | National Pokédex 1–1025 and bundle v5 foundation |

Full archive: [docs/RELEASES.md](docs/RELEASES.md).

## Current capability status

| Area | Status |
| --- | --- |
| Flutter application, persistence, routing, and emulator launch | Shipped |
| HGSS save parsing and directory sync | Shipped, game-specific limitations documented |
| Pokédex 1–1025 and regional/game scopes | Shipped |
| Offline bundle, Chinese catalog, maps, config, and update prompts | Shipped |
| Structured reference hub and Pokédex drill-down | Shipped |
| Matchup, stat/damage estimates, blind spots, modifiers, and team weaknesses | Shipped; calculation depth remains partial |
| APK-bundled offline variant | Available as an optional distribution |
| Journey cloud sync | Proposal only |
| Additional save parsers | Not started |

## Next priorities

1. **Regression coverage** — expand automated coverage for the aligned trainer-card, team-editor, offline, and flavor-title behavior.
2. **Calculation quality** — expand battle formula coverage, fixtures, and user-facing assumptions.
3. **Save workflow polish** — add HeartGold detection and single-file `.sav` selection.
4. **Distribution polish** — finalize launcher icon, splash, install guidance, and release consistency.
5. **Offline maintenance** — keep bundle v5 manifests and Chinese labels current without exposing private service URLs in public copy.

## Future work

- additional generation-specific save adapters
- Linux handheld packaging
- optional hosted sync after privacy, conflict, and account requirements are defined
- broader accessibility and controller-navigation validation
