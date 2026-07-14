# Cloud Sync Proposal

## Purpose

Cloud sync should protect Tito's journey and make it available across devices. It should not be required for TitoDex to be useful.

TitoDex remains local-first. Cloud sync is optional backup and continuity infrastructure.

## Suggested Platform

- **Cloudflare Worker** for API endpoints
- **D1** for metadata
- **R2** for `.sav` file backups

## Metadata

A sync record should include:

- current game
- play time
- badges
- location
- party
- save hash
- updated time
- optional device/source identifier

Example:

```ts
export type CloudJourneyMetadata = {
  id: string;
  currentGame: 'SoulSilver' | string;
  playTime?: string;
  badges?: number;
  location?: string;
  party?: Array<{
    species: string;
    level?: number;
  }>;
  saveHash: string;
  updatedAt: string;
  sourceDevice?: string;
};
```

## R2 Object Strategy

Store save backups under hash-addressed or journey-addressed keys.

Possible key format:

```txt
users/{userId}/saves/{gameId}/{saveHash}.sav
```

For an early optional-sync implementation, `userId` can remain an opaque private identifier. Avoid introducing a complex account system before product and privacy requirements are defined.

## D1 Tables

Possible minimal schema:

```sql
CREATE TABLE journey_metadata (
  id TEXT PRIMARY KEY,
  current_game TEXT NOT NULL,
  play_time TEXT,
  badges INTEGER,
  location TEXT,
  party_json TEXT,
  save_hash TEXT NOT NULL,
  r2_key TEXT,
  updated_at TEXT NOT NULL,
  source_device TEXT
);
```

## Sync Flow

Manual-first flow:

1. The user chooses backup.
2. App computes save hash.
3. App uploads metadata to Worker.
4. App uploads `.sav` to R2 through Worker or signed upload flow.
5. App records successful backup locally.

Restore flow:

1. App lists synced metadata.
2. The user chooses a backup.
3. App downloads `.sav` if needed.
4. App shows metadata before restore.
5. The user confirms the local save/export action.

## Conflict Strategy

Keep the first version simple:

- compare `saveHash`
- compare `updatedAt`
- show both versions if different
- require explicit confirmation before replacing local state

Do not build automatic complex merge behavior in the first sync prototype.

## Privacy and Safety

Save files are personal. The app should:

- make backups explicit
- show when a save was uploaded
- avoid silent upload in early versions
- support local-only mode
- avoid storing unnecessary personal data

## Non-Goals for Early Cloud Sync

- public profiles
- social sharing
- complex account system
- multi-user organizations
- real-time sync
- automatic merge magic
- dependency on cloud for app startup
