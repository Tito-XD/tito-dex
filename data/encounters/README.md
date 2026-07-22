# Encounter overlays

PokeAPI currently leaves some modern version groups without encounter rows. Files in this directory can add verified, redistributable per-version data without changing the upstream response parser.

Each `<version>.json` file must contain source attribution and exact-version entries:

```json
{
  "schemaVersion": 3,
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
        "formKey": "pikachu-gmax",
        "isDefaultForm": false,
        "teraType": null,
        "isAlpha": false,
        "isTitan": false,
        "isTotem": false,
        "isRaid": true,
        "isFixedEncounter": false,
        "formAmbiguous": false,
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
- For form-known rows, encounter map keys are PokeAPI Pokémon entity IDs (or `pokemon:<id>`), and `pokemonId + speciesId + formKey` connect directly to the form catalog.
- If a source identifies only the species, use a `species:<id>` bucket, omit `pokemonId`/`formKey`, and set `formAmbiguous: true`; never silently assign it to the default form.
- `teraType` is encounter state, not a generated form. `isAlpha`, `isTitan`, `isTotem`, `isRaid`, and `isFixedEncounter` likewise describe the encounter unless the source also identifies a real PokeAPI variety.
- `source.name`, `source.url`, and `source.license` are mandatory. Do not import a guide or database whose terms do not permit redistribution.
- `areaSlug` is mandatory; use a stable English kebab-case slug. `areaLabelZh` should be official Simplified Chinese when available.
- Overlay rows replace the same `version + Pokémon + areaSlug` row from PokeAPI and otherwise extend it.
- `rateKind` is `percentage`, `weight`, `guaranteed`, or `unknown`. Preserve modern-game raw weights in `rateValue`; `maxChance` remains only as the legacy UI-compatible percentage field.
- Run `tools/audit_encounter_coverage.py` against the rebuilt bundle before publishing.
- Run `tools/audit_pokeapi_encounter_source.py <pokeapi data/v2/csv>` to verify encounter foreign keys, TitoDex area IDs/slugs, and version-group-to-region joins against the same upstream revision.
