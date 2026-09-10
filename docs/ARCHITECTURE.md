# TitoDex Architecture

> Current release: v0.9.18 · Lite `0.9.18+204` · Offline `0.9.18-offline+205` · App updates, onboarding, trainer shortcuts and structured-data-first answers · live bundle v20 embedded by Offline.
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
| Android native | Save document channel, emulator launcher, Dex foreground download service, verified APK installer, long-press and pinned trainer shortcuts |
| App update | GitHub stable release → matching variant → user download → SHA-256/package/signer/version validation → system installer |
| First run | Persisted introduction eligibility; existing installs bypass; name/avatar, features and offline setup |
| Optional Q&A | Reviewed local hints; deterministic structured resource queries; bounded online fallback with final fact protection; legacy pack read compatibility |

## Main data flow

```text
App bootstrap
  → decide and persist first-run eligibility before creating journey state
  → load journey / edition / UI preferences / app shortcuts
  → optionally re-read the selected save document
  → show first-run introduction when eligible; otherwise Home
  → prepare offline seed/catalog (one-time blocking progress when Offline needs extraction)
  → check App updates at startup when enabled and at least 24 hours since the last attempt
```

```text
Dex request
  → complete preferred local bundle
  → versioned CDN JSON
  → partial local cache
  → PokeAPI fallback where supported
```

The location dex and Journey assistant share `location_index.json`. The home
card uses only the cached summary catalog + location index. Journey shows
location and counterpart completion grids; Team owns party/evolution details.
The location views resolve the selected exact flavor (or merge paired flavors) without inverting
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

The App sends only fields allowed by `data/journey/assistant_api.schema.json`, including explicit save-field reliability and at most six same-game conversation pairs. Local reviewed matching runs first. Supported queries then resolve existing Dex/reference data, including move/ability reverse lookup and intersections, by stable IDs and bounded reads. Unknown version coverage remains explicit.

Remaining questions can use reviewed AI Search candidate IDs and bounded fixed-source/Tavily/DeepSeek retrieval. Retrieved prose is transient and never becomes a new bundle fact. Qwen composition and verification are followed by `enforceFinalFacts`, which restores executed structured results before semantic blocks are produced. Open-ended answers are not automatically labelled verified. UI evidence and entity links use the same IDs; leading props animate through stages and stop on the subject, while the answer grows below its starting reading position. See [ASK_STRUCTURED_DATA.md](ASK_STRUCTURED_DATA.md) and [JOURNEY_ASSISTANT.md](JOURNEY_ASSISTANT.md).

Journey no longer exposes the optional pack download entry. Legacy protocol/data loading remains compatible. App APK updating is separate; see [APP_UPDATE_AND_ONBOARDING.md](APP_UPDATE_AND_ONBOARDING.md).

## Active layout

```text
flutter/lib/
  app.dart
  features/
    app_shortcuts/ app_update/ onboarding/ companion/ dex/ game/
    journey/ extensions/ launcher/ parser/ save/
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

- Android: full save, launcher, Dex download notifications, verified APK installation and app-shortcut support. APK downloads require the App to remain running; they do not use the Dex foreground download service.
- Web: save/launcher native operations are disabled; all routes still own a `Scaffold` for preview stability.
- iOS: imported save files are copied into app documents; emulator launch, APK updates and pinned Android shortcuts are unavailable. The last no-codesign build is v0.7.0; v0.9.18 has no new iOS device/build claim.

## Verification

```bash
cd flutter
flutter analyze --no-pub
flutter test
flutter build web --release
```

CI also runs an Android-emulator integration smoke. Signed APK construction and
physical RG/Android 15 checks follow [RELEASE_BUILD.md](./RELEASE_BUILD.md).
