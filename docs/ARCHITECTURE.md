# TitoDex Architecture

> Current release: v0.8.9 · Lite `0.8.9+144` · Offline `0.8.9-offline+145` · live bundle v19 / compact seed v14.
>
> Canonical operational context: [AI_CONTEXT.md](./AI_CONTEXT.md).

## Runtime shape

| Concern | Implementation |
| --- | --- |
| UI | Flutter custom widgets, `DeviceShell`, `TitoPageContainer`, Nunito |
| Routing | `go_router`: Home, Team, Journey, Dex, Search, Settings and secondary tools |
| Persistence | `shared_preferences` repositories |
| Save import | One persisted document URI; HGSS rich parser; experimental Gen I–VII metadata adapters |
| Dex data | Installed bundle first when preferred, then versioned CDN, then PokeAPI fallback |
| Offline install | SHA-256 verified zstd/tar bundle into app documents |
| Android native | Save document channel, emulator launcher, foreground download service, dynamic app shortcuts |

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
new CDN bundle. Future bundle builds also persist move debut/version metadata.

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
```

The React/Capacitor source tree no longer exists.

## Native and platform boundaries

- Android: full save, launcher, notification and app-shortcut support.
- Web: save/launcher native operations are disabled; all routes still own a `Scaffold` for preview stability.
- iOS: imported save files are copied into app documents; emulator launch is unavailable.

## Verification

```bash
cd flutter
flutter test
flutter build web --release
```

CI also runs an Android-emulator integration smoke. Signed APK construction and
physical RG/Android 15 checks follow [RELEASE_BUILD.md](./RELEASE_BUILD.md).
