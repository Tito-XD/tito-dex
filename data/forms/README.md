# Curated form overrides

`overrides.json` is reserved for forms that are absent from PokeAPI. A form is
only promoted from `pendingForms` into `forms` after every supplied field has a
verifiable source and its own redistributable offline images.

Required fields for an active override:

- `formKey`, `speciesId`, Chinese and English names;
- independently verified battle fields (never copied from the default form);
- `availableVersionGroups`, `obtainableVersionGroups`, and availability flags;
- `dataCompleteness` plus field-scoped sources;
- dedicated sprite and artwork files under the form asset directories.

As checked on 2026-07-22, every Z-A and Mega Dimension Mega Evolution listed in
`resolvedByPokeApi` has a live PokeAPI Pokémon endpoint and is linked from its
species `varieties` array. The normal builder therefore owns those records and
their PokeAPI/sprites provenance; no curated override is active. A future form
returns to `pendingForms` if upstream removes it or a newly announced form lacks
independent battle data and redistributable offline art.
