# TitoDex third-party notices

This index complements [CREDITS.md](CREDITS.md). It does not grant rights in
Pokémon names, characters, artwork, game icons, sprites, audio, or trademarks.
Those rights remain with their respective rights holders.

## Licenses bundled in the app

| Component | Use | License text |
| --- | --- | --- |
| Nunito | Bundled UI font | [`flutter/assets/licenses/nunito-OFL.txt`](flutter/assets/licenses/nunito-OFL.txt) |
| PokéSprite | Vendored Gen 8 type icons | [`flutter/assets/licenses/pokesprite-MIT.txt`](flutter/assets/licenses/pokesprite-MIT.txt) |
| Neroli’s Lab | Ported Pokémon Sleep sleep-score and cooking formulas plus ingredient values, pinned at `cb533f240a0551da315151c310b4dbd165091672` | [`flutter/assets/licenses/nerolis-lab-Apache-2.0.txt`](flutter/assets/licenses/nerolis-lab-Apache-2.0.txt) and [`nerolis-lab-NOTICE.txt`](flutter/assets/licenses/nerolis-lab-NOTICE.txt) |

TitoDex registers these files with Flutter's `LicenseRegistry`. Settings →
“查看开源许可证” displays them together with the notices registered by Flutter
and Dart packages. Release APKs also contain Flutter's generated `NOTICES.Z`.

## Data and generated artifacts

- PKHeX-derived encounter data and its generator are covered separately by
  [`data/encounters/PKHEX_LICENSE.md`](data/encounters/PKHEX_LICENSE.md).
- 52Poké-derived original wiki content uses CC BY-NC-SA 3.0. Bundle-specific
  item, flavor-text, and held-item attribution files retain the exact source
  pages used by each build.
- PokeAPI and PokeAPI/api-data are BSD-3-Clause. PokeAPI/sprites is treated as
  a media index with upstream credits and varying underlying rights, not as a
  blanket CC-BY-licensed media collection.
- Game-icon provenance is recorded per output in
  [`flutter/assets/game_icons/SOURCES.json`](flutter/assets/game_icons/SOURCES.json).

## TitoDex source-code license

No repository-wide source-code license has been selected yet. Third-party
licenses above apply only to their respective components and do not grant a
license to TitoDex's original source code. The project owner must explicitly
choose a source-code license before describing TitoDex itself as open source.
