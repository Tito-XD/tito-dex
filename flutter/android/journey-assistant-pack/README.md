# Journey Assistant companion APK

This Android application module builds the optional TitoDex Journey Assistant
content pack. It has no activity or launcher entry. It exports one immutable
`ContentProvider`, protected by a signature-level permission, so only a TitoDex
host signed with the same certificate can read it.

## Package contract

- Package ID: `com.tito.titodex.extension.journeyassistant`
- Provider authority: `com.tito.titodex.extension.journeyassistant.provider`
- Required permission: `com.tito.titodex.permission.READ_EXTENSION_PACK`
- Manifest URI: `content://com.tito.titodex.extension.journeyassistant.provider/manifest`
- Data URI: `content://com.tito.titodex.extension.journeyassistant.provider/files/progression_hints.json`

The host reads each URI with `ContentResolver.openInputStream`. Querying either
URI exposes only `OpenableColumns.DISPLAY_NAME` and `OpenableColumns.SIZE`.
Insert, update, delete, unknown paths, traversal attempts, and every mode other
than `r` are rejected. URI grants are disabled.

The generated `extension_manifest.json` has this protocol-v1 shape:

```json
{
  "protocolVersion": 1,
  "extensionId": "journey_assistant",
  "contentVersion": 1,
  "minHostVersion": "0.8.13",
  "packageId": "com.tito.titodex.extension.journeyassistant",
  "capabilities": ["progression_hints"],
  "games": ["heartgold", "soulsilver"],
  "locales": ["zh-Hans"],
  "files": [{
    "path": "progression_hints.json",
    "sizeBytes": 7118,
    "sha256": "<64 lowercase hex characters>",
    "contentType": "application/json"
  }]
}
```

Values derived from the canonical data (content version, games, size, and
digest) are regenerated at build time. In general the manifest contains
`protocolVersion`,
`extensionId`, `contentVersion`, `minHostVersion`, package identity,
capabilities, games, locales, and each payload's path, byte size, content type,
and SHA-256. The host derives the documented provider URI from each approved
path. The host
must reject an unsupported protocol/host version, unexpected package or
authority, unknown capability/file, signing-certificate mismatch, size mismatch,
or digest mismatch before importing data into its own storage.

## Authoritative data

`data/journey/progression_hints.json` remains the only facts source. The Gradle
task `prepareJourneyAssistantPackAssets` copies it byte-for-byte into generated
APK assets and derives the manifest from its `datasetVersion`, game list, byte
size, and digest. `verifyJourneyAssistantPackAssets` then byte-compares the copy
and recomputes the digest before Android packaging. Do not add a hand-maintained
copy under this module.

## Build and test

From `flutter/android`:

```bash
./gradlew :journey-assistant-pack:testDebugUnitTest
./gradlew :journey-assistant-pack:verifyJourneyAssistantPackAssets
./gradlew :journey-assistant-pack:assembleJourneyAssistantPack
```

The APK is written below
`flutter/build/journey-assistant-pack/outputs/apk/release/`. Release signing reads
the same `flutter/android/key.properties` used by the TitoDex host; debug builds
use Android's normal debug signing key. Do not distribute an unsigned release
build, and never put CDN URLs or signing secrets in this module.
