# Encounter overlays

PokeAPI currently leaves some modern version groups without encounter rows. Files in this directory can add verified, redistributable per-version data without changing the upstream response parser.

Each `<version>.json` file must contain source attribution and exact-version entries:

```json
{
  "schemaVersion": 2,
  "version": "scarlet",
  "versionGroup": "scarlet-violet",
  "source": {
    "name": "Source name",
    "url": "https://example.test/source",
    "license": "SPDX id or exact redistribution terms"
  },
  "encounters": {
    "10180": [
      {
        "speciesId": 25,
        "formSlug": "pikachu-gmax",
        "isDefaultForm": false,
        "areaSlug": "south-province-area-two",
        "areaLabelZh": "南第2区",
        "minLevel": 8,
        "maxLevel": 12,
        "maxChance": 20,
        "rateKind": "percentage",
        "rateValue": 20,
        "methods": ["overworld"],
        "conditions": []
      }
    ]
  }
}
```

Rules:

- One file represents one exact game version, not a paired version group.
- Encounter map keys are PokeAPI Pokémon entity IDs, not National Pokédex species IDs. Every row is normalized with `pokemonId`; `speciesId`, `formSlug`, and `isDefaultForm` connect it to the separate form catalog.
- `source.name`, `source.url`, and `source.license` are mandatory. Do not import a guide or database whose terms do not permit redistribution.
- `areaSlug` is mandatory; use a stable English kebab-case slug. `areaLabelZh` should be official Simplified Chinese when available.
- Overlay rows replace the same `version + Pokémon + areaSlug` row from PokeAPI and otherwise extend it.
- `rateKind` is `percentage`, `weight`, `guaranteed`, or `unknown`. Preserve modern-game raw weights in `rateValue`; `maxChance` remains only as the legacy UI-compatible percentage field.
- Run `tools/audit_encounter_coverage.py` against the rebuilt bundle before publishing.
- Run `tools/audit_pokeapi_encounter_source.py <pokeapi data/v2/csv>` to verify encounter foreign keys, TitoDex area IDs/slugs, and version-group-to-region joins against the same upstream revision.
