# Type icons (18 types)

Bundled PNG icons for CDN offline bundle (`v3/type_icons/{type}.png`).

## Source

| Field | Value |
| --- | --- |
| Project | [msikma/pokesprite](https://github.com/msikma/pokesprite) |
| Set | `misc/types/gen8/` (Sword/Shield style) |
| Metadata | [data/misc.json → `types`](https://raw.githubusercontent.com/msikma/pokesprite/master/data/misc.json) |
| License | [MIT](https://github.com/msikma/pokesprite/blob/master/LICENSE) |
| Fetched via | `tools/fetch_pokesprite_type_icons.py` |

PokéSprite has not received major updates since ~2022, but the Gen 8 type icon set is complete (including `fairy`) and stable. Files are **vendored here** so TitoDex does not depend on GitHub availability at build time.

## Refresh

```bash
python3 tools/fetch_pokesprite_type_icons.py
./tools/upload_type_icons.sh   # optional: push to R2 v3/type_icons/
```

## Alternatives considered

| Source | Notes |
| --- | --- |
| PokeAPI sprites | Has Gen III–IX type icons (`generation-ix/scarlet-violet`, etc.) but older sets omit `fairy`; Gen 3 Colosseum was the previous default |
| pokesprite | Chosen for consistent Gen 8 look across all 18 types |
