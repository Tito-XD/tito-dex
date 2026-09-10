# App updates, first-run introduction and trainer shortcuts

Release line: v0.9.18, Lite build 204 / Offline build 205. Published artifact sizes, digests, source SHA and CI evidence are recorded in [RELEASES.md](RELEASES.md).

## App updates

- Settings → About contains the installed version/build number, a daily automatic-check switch, manual check, release notes, progress/cancel, and install/retry controls.
- Startup checks `Tito-XD/tito-dex` through GitHub's public `releases/latest` API. It does not send trainer information. Automatic requests are limited to one attempt per 24 hours; manual retry is independent. Checks never download an APK without a user action.
- Only stable tags and the matching Lite/Offline arm64 host asset are eligible. Numerical version comparison handles preview → stable and multi-digit version components. Side-by-side debug packages and devices without arm64 support cannot self-update from production artifacts.
- GitHub's asset URL, state, size and SHA-256 digest are validated. Downloads stream to an app-private cache file; truncation, cancellation and hash mismatch never reach the installer. One fixed APK and partial path bound cache growth.
- Native code rechecks the digest off the UI thread, then validates package identity, current signer, exact version name, variant and strictly increasing versionCode. A narrowly scoped FileProvider passes the APK to the Android system installer. Android's unknown-app-source permission and installation confirmation remain user-controlled; after granting permission, the user returns and taps Continue installation.
- Downloads require the App to remain running. They can be cancelled; interrupted downloads restart on retry. Installation is not automatically opened if the download page is no longer current or the App is backgrounded.
- This is App updating, separate from the existing Dex bundle updater. It requires a first manual installation of an APK containing this code.

## Introduction and identity

- Three short, scrollable pages cover name/avatar, Journey/Team/Dex/Search/Ask, and offline data plus an optional named shortcut.
- The first-run decision is persisted before bootstrap can create any journey state. Existing journey, game selection or offline-prompt preferences bypass the introduction. An interrupted new setup remains eligible; successful save or explicit skip completes it. The last page replaces the older first-run offline prompt.
- Users can revisit the guide from Settings → About. Ask TitoDex still requires its existing online-use consent; the guide does not enable it.
- Explicit names remain user-owned when a save is subsequently imported. Avatar selection reuses the existing cropper and refreshes the file image cache.
- Android application/launcher labels are build-time metadata. A user-confirmed pinned `trainer-home` shortcut instead uses the same name as the App header, for example `小智Dex`. It opens Home on cold/warm launch. Renaming the trainer updates the existing pinned entry without requesting another icon or changing the configured long-press shortcuts. Unsupported launchers fail gracefully.

## Verification

- `flutter test --no-pub test/app_update_test.dart test/onboarding_test.dart test/app_shortcuts_test.dart`
- `flutter analyze --no-pub` and the full Flutter suite.
- Android `:app:compileDebugKotlin` validates the installer, shortcuts, resources and merged manifest.
- Widget checks include all three themes at narrow widths and enlarged English text.
- A physical-device upgrade across two signed releases, permission denial/return, and pin/rename behavior on RG and phone launchers remain device acceptance checks. Unit tests and native compilation do not substitute for those checks.

Primary API references: [GitHub latest release](https://docs.github.com/en/rest/releases/releases#get-the-latest-release), [release asset digests](https://github.blog/changelog/2025-06-03-releases-now-expose-digests-for-release-assets/), [Android pinned shortcuts](https://developer.android.com/develop/ui/compose/system/shortcuts/creating-shortcuts), [application labels](https://developer.android.com/guide/topics/manifest/application-element#label).
