# Save Parser Proposal

## Purpose

The save parser should help TitoDex continue Tito's current journey. It is not a save editor and not a complete all-generation parser project.

The first parser target should be HGSS because TitoDex starts with SoulSilver / HeartGold-SoulSilver context.

## Parser Principle

Parse only what the companion app needs first:

- current game
- trainer name if practical
- play time
- badges
- current location
- party summary
- save hash
- updated time / parsed time

Avoid implementing full Pokémon structures, full box editing, or all-generation support at the beginning.

## Proposed Parser Boundary

```ts
export type SaveParser<GameId extends string = string> = {
  gameId: GameId;
  canParse(input: ArrayBuffer): Promise<boolean> | boolean;
  parseSummary(input: ArrayBuffer): Promise<ParsedSaveSummary>;
};

export type ParsedSaveSummary = {
  game: string;
  trainerName?: string;
  playTime?: string;
  badges?: number;
  location?: string;
  party?: ParsedPartyMember[];
  saveHash: string;
  parsedAt: string;
  warnings?: string[];
};

export type ParsedPartyMember = {
  species: string;
  level?: number;
  nickname?: string;
};
```

## First Implementation Target

Start with one focused parser:

```txt
src/features/parser/hgssParser.ts
```

It should be allowed to return partial data and warnings. A partial, trustworthy summary is better than a broad, fragile parser.

## Save Hash

Every parsed save should produce a hash. The hash is useful for:

- detecting changes
- avoiding duplicate backups
- sync conflict checks
- identifying which metadata belongs to which save snapshot

Use a stable digest such as SHA-256 when available.

## Local File Access

Future Android flow:

1. Tito selects a `.sav` file.
2. TitoDex reads it locally through a Capacitor file picker or Android storage integration.
3. TitoDex computes hash and parses summary metadata.
4. TitoDex stores summary locally.
5. Optional cloud sync backs up metadata and the `.sav` file.

## Parser UX

The UI should clearly communicate parser confidence:

- parsed successfully
- partial parse
- unsupported save
- modified/unknown format
- backup recommended

Do not silently overwrite user-entered journey notes with parser results. Parser data should update structured fields while preserving Tito's manual journey log.

## Non-Goals

Do not start with:

- all-generation parser framework
- full save editing
- complete Pokémon party internals
- PC box management
- emulator memory reading
- automatic emulator launch
- OCR

## Research Notes

When parser implementation begins, use small verified save fixtures and document offsets carefully. Parser research should be source-cited in code comments where appropriate, but the product should remain focused on the Continue Journey experience.
