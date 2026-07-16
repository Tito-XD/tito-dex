# TitoDex Roadmap

> **Latest release:** [v0.5.5](https://github.com/Tito-XD/tito-dex/releases/tag/v0.5.5) · Lite `0.5.5+63` · Offline `0.5.5-offline+64`.
>
> **Latest preview:** [v0.5.51](https://github.com/Tito-XD/tito-dex/releases/tag/v0.5.51) · Lite `0.5.51+65` · Offline `0.5.51-offline+66`.
>
> **Current `main` source baseline:** `0.5.51+65`.

## Recent release history

| Version | Summary |
| --- | --- |
| **v0.5.51** | Preview fix for deterministic Team, Dex, and Search return motion |
| **v0.5.5** | Single-file saves, native app picker, polished motion, companion interactions, six-slot party card, and silhouette quiz |
| **v0.5.1** | Android-standard route motion and predictive back |
| **v0.5.0** | Precomputed in-memory Dex catalog and responsive filtering |
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
| Single-file save import | Shipped; HGSS has fixture-verified party/map/dex parsing |
| Other pre-Switch save metadata | Experimental; real-save fixture coverage remains incomplete |
| Pokédex 1–1025 and regional/game scopes | Shipped |
| Offline bundle, Chinese catalog, maps, config, and update prompts | Shipped |
| Structured reference hub and Pokédex drill-down | Shipped |
| Matchup, stat/damage estimates, blind spots, modifiers, and team weaknesses | Shipped; calculation depth remains partial |
| APK-bundled offline variant | Available as an optional distribution |
| Journey cloud sync | Proposal only |
| Standby companion, shiny party surprise, silhouette quiz | Shipped in v0.5.5 |

## Next priorities

1. **Regression coverage** — expand automated coverage for the aligned trainer-card, team-editor, offline, and flavor-title behavior.
2. **Calculation quality** — expand battle formula coverage, fixtures, and user-facing assumptions.
3. **Save workflow validation** — add real fixtures for supported pre-Switch games and expand format-specific imports.
4. **Distribution polish** — finalize launcher icon, splash, install guidance, and release consistency.
5. **Offline maintenance** — keep bundle v5 manifests and Chinese labels current without exposing private service URLs in public copy.

## Future work

- deeper generation-specific save adapters beyond trainer metadata
- Linux handheld packaging
- optional hosted sync after privacy, conflict, and account requirements are defined
- broader accessibility and controller-navigation validation
