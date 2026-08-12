# Type icons (18 types)

Bundled PNG icons for the APK and current CDN bundle (`v5/type_icons/{type}.png`).
Older rollback prefixes retain their historical copies.

## Source

| Field | Value |
| --- | --- |
| Project | [msikma/pokesprite](https://github.com/msikma/pokesprite) |
| Pinned commit | `c5aaa610ff2acdf7fd8e2dccd181bca8be9fcb3e` |
| Set | `misc/types/gen8/` (Sword/Shield style) |
| Metadata | [data/misc.json → `types`](https://github.com/msikma/pokesprite/blob/c5aaa610ff2acdf7fd8e2dccd181bca8be9fcb3e/data/misc.json) |
| License | [MIT](https://github.com/msikma/pokesprite/blob/c5aaa610ff2acdf7fd8e2dccd181bca8be9fcb3e/license.md) |
| Fetched via | `tools/fetch_pokesprite_type_icons.py` |

PokéSprite has not received major updates since ~2022, but the Gen 8 type icon set is complete (including `fairy`) and stable. Files are **vendored here** so TitoDex does not depend on GitHub availability at build time.

## Refresh

```bash
python3 tools/fetch_pokesprite_type_icons.py
./tools/upload_type_icons.sh   # optional maintainer upload to R2 v5/type_icons/
```

## Alternatives considered

| Source | Notes |
| --- | --- |
| PokeAPI sprites | Has Gen III–IX type icons (`generation-ix/scarlet-violet`, etc.) but older sets omit `fairy`; Gen 3 Colosseum was the previous default |
| pokesprite | Chosen for consistent Gen 8 look across all 18 types |
