# TitoDex Architecture

> Current release: v0.8.19 · Lite `0.8.19+172` · Offline `0.8.19-offline+173` · rich chat-first Journey Assistant with streamed answers, structured collapsed citations, local history management and bundle-grounded multi-source retrieval · live bundle v19 / compact seed v14.
>
> Canonical operational context: [AI_CONTEXT.md](./AI_CONTEXT.md).

## Technology decision

Flutter + Dart under `flutter/` is the only application implementation. The
pre-Flutter React/Capacitor mock was removed in v0.6.5 and survives only in
historical GitHub releases. Flutter was chosen for native Android rendering,
custom device-like UI, single-file save access, emulator handoff, offline
bundle installation and one responsive codebase for phones, square handhelds,
iOS source and web preview. Do not introduce a second application framework.

Android arm64 is the shipping target; web is a limited preview, and iOS signing
and distribution remain separate gates. Persistence stays local, Journey JSON
is the portability path, and parser coverage remains fixture-gated.

## Runtime shape

| Concern | Implementation |
| --- | --- |
| UI | Flutter custom widgets, `DeviceShell`, `TitoPageContainer`, Nunito |
| Routing | `go_router`: Home, Team, Journey, Dex, Search, Settings, reference pages, battle tools and Sleep tools |
| Persistence | `shared_preferences` repositories |
| Save import | One persisted document URI; HGSS rich parser; experimental Gen I–VII metadata adapters |
| Dex data | Installed bundle first when preferred, then versioned CDN, then PokeAPI fallback |
| Offline install | SHA-256 verified zstd/tar bundle into app documents |
| Android native | Save document channel, emulator launcher, foreground download service, dynamic app shortcuts |
| Optional blocker Q&A | Built-in reviewed seed; save-first local fuzzy match; opt-in Workers AI only for unresolved intent; legacy same-signer pack remains read-compatible |

## Main data flow

```text
App bootstrap
  → load journey / edition / UI preferences / app shortcuts
  → optionally re-read the selected save document
  → render Home immediately
  → prepare offline seed/catalog and update prompts in the background
```

```text
Dex request
  → complete preferred local bundle
  → versioned CDN JSON
  → partial local cache
  → PokeAPI fallback where supported
```

The location dex and Journey assistant share `location_index.json`. The home
card uses only the cached summary catalog + location index; the Journey page
loads at most the six party detail records for evolution reminders. Both
resolve the selected exact flavor (or merge paired flavors) without inverting
1025 details on-device.

APK-local `item_version_matrix.json` and `move_version_matrix.json` add
selected-game availability/prices and move-removal gates without requiring a
new CDN bundle. Pinned local constants provide the limited Pokémon Sleep
formula/value helpers; their upstream license and NOTICE ship in APK assets.

The “Ask TitoDex” source preview is a separate, privacy-bounded flow.
`data/journey/progression_hints.json` is canonical; Gradle copies it into the
bundled host asset (with a legacy same-signer companion fallback) and generates a content
manifest. The host APK always carries the reviewed HGSS seed. A legacy optional
pack may override it only after catalog digest, APK identity/signer, provider
contract, protocol/host compatibility, and payload digest validation. See
[EXTENSIONS.md](./EXTENSIONS.md).

The App sends only fields allowed by `data/journey/assistant_api.schema.json`,
including explicit save-field reliability. Deterministic fuzzy matching always
runs first. On a miss/tie, optional BGE-M3 hybrid AI Search may return candidate
IDs, but returned text is discarded and every ID is checked against the same
local audited facts. On a reviewed-corpus miss, a strict scope gate may fetch
bounded PokeAPI, StrategyWiki and Wikidata data. Exact move fields are resolved
for the selected version before use; Qwen composition must pass direct-support
classification, numeric/version guards and a second verification call. Invalid
JSON, timeouts, unsupported versions and unknown conditions return a
local/follow-up state rather than invented guidance. See
[JOURNEY_ASSISTANT.md](./JOURNEY_ASSISTANT.md).

## Active layout

```text
flutter/lib/
  app.dart
  features/
    app_shortcuts/ companion/ dex/ game/ journey/ launcher/ parser/ save/
  pages/
  widgets/
  l10n/
flutter/test/
flutter/integration_test/
tools/
data/l10n/zh/
cloudflare/dex-cdn/
cloudflare/journey-assistant/
data/journey/
data/extensions/
flutter/android/journey-assistant-pack/
```

The React/Capacitor source tree no longer exists.

## Native and platform boundaries

- Android: full save, launcher, notification and app-shortcut support.
- Web: save/launcher native operations are disabled; all routes still own a `Scaffold` for preview stability.
- iOS: imported save files are copied into app documents; emulator launch is unavailable.

## Verification

```bash
cd flutter
flutter analyze --no-pub
flutter test
flutter build web --release
```

CI also runs an Android-emulator integration smoke. Signed APK construction and
physical RG/Android 15 checks follow [RELEASE_BUILD.md](./RELEASE_BUILD.md).
