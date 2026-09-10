# TitoDex RG APK — Release build checklist

**Audience:** maintainers packaging `TitoDex-<ver>-lite-rg-arm64.apk` and `TitoDex-<ver>-offline-rg-arm64.apk`.

Published **v0.9.19** is **29,323,945 bytes (29.32 MB) Lite** and
**95,451,533 bytes (95.45 MB) Offline** (decimal MB). Offline embeds the verified
66,129,008-byte v20 archive. Validate ZIP contents, native runtime, metadata,
signer and archive digest rather than reusing an old fixed-size expectation. If a Lite
build is only **~7 MB**, the file is truncated or corrupt (missing
`libflutter.so` tail / broken ZIP central directory) — **do not ship it**.

---

## What must be inside the APK

### Native libraries (`lib/arm64-v8a/`)

| File | ~Size | Purpose |
| --- | --- | --- |
| `libflutter.so` | ~11.6 MB | Flutter engine |
| `libapp.so` | ~11.9 MB in v0.9.18 | Compiled Dart AOT (`flutter build apk --release`) |
| `libzstandard_android.so` | ~0.5 MB | Offline bundle zstd decompress (`zstandard` package) |
| `libdatastore_shared_counter.so` | tiny | AndroidX DataStore |

Use `--target-platform android-arm64` and **do not use** `--split-per-abi`. Flutter 3.44 may otherwise package `libapp.so` and `libflutter.so` for arm64, armv7, and x86_64 despite the Gradle `abiFilters`. Some plugins may still contribute small helper libraries for other ABIs; verification rejects non-arm64 Flutter runtime libraries and oversized universal APKs. RG sideload also needs **Stored** native libs (`minSdk 24`, `useLegacyPackaging = false`) — see `flutter/android/app/build.gradle.kts`.

The Gradle ABI filter is release-only. Debug builds intentionally retain emulator ABIs for
Android integration tests; release builds and the verifier remain arm64-only.

### Bundled Flutter assets (not the CDN dex bundle)

These ship **inside** the APK via `pubspec.yaml`:

| Asset | Purpose |
| --- | --- |
| `assets/fixtures/PKMSS.sav` | Settings → 导入内置存档 |
| `assets/companion_media/*` | Starter companion GIFs + cries (29 species) |
| `assets/ask_motion/*.png` | 24 starter props, 106,214 bytes; other prop artwork reuses the Dex bundle |
| `assets/game_icons/*.png` | Bundled game icons with per-file provenance in `assets/game_icons/SOURCES.json` |
| `assets/fonts/Nunito-*.ttf` | UI typography (Regular / SemiBold / Bold / ExtraBold) |
| `AssetManifest.bin`, `FontManifest.json`, `NOTICES.Z` | Flutter asset index |

**Lite APK:** users download the complete offline reference pack through **Settings → 下载完整离线资料包** into app documents (`dex_offline/`). It includes the 1025-species dex and forms, evolution chains, moves, abilities, items, Chinese references, maps, images, and app config. The optional Offline APK adds `assets/dex/bundle.tar.zst` and its manifest, then seeds the same pack on first launch.

### Compile-time dex CDN config

Endpoints are baked in at build time (`flutter/lib/features/dex/dex_cdn_config.dart` via `--dart-define` / env). They are **not** shown in UI but are required for online fetch + bundle install.

---

## Prerequisites

1. **Flutter SDK 3.44.6** (pinned in the current CI workflows)
2. **Android SDK** — `compileSdk 36`, NDK `28.2.13676358`
3. **Release signing** — `flutter/android/key.properties` + keystore (see `flutter/android/app/build.gradle.kts`). CI/cloud VM must use the v0.8.13+ release key. Only upgrades from v0.8.12 or earlier require export/uninstall because of the historical signing rotation; never rotate the key during routine packaging.

```properties
# flutter/android/key.properties (not committed)
storePassword=...
keyPassword=...
keyAlias=...
storeFile=/path/to/upload-keystore.jks
```

---

## Build steps

```bash
cd flutter
flutter pub get
flutter test

# Standard RG arm64 release — NO --split-per-abi
flutter build apk --release --target-platform android-arm64

# Compare with the current release baseline; v0.9.18 Lite is 29.13 MB
ls -lh build/app/outputs/flutter-apk/app-release.apk

# Verify before copy (required)
../tools/verify_release_apk.sh build/app/outputs/flutter-apk/app-release.apk

# Rename & copy
cp build/app/outputs/flutter-apk/app-release.apk \
   ../releases/TitoDex-<ver>-lite-rg-arm64.apk

# Verify again after copy
../tools/verify_release_apk.sh ../releases/TitoDex-<ver>-lite-rg-arm64.apk
```

Update `flutter/pubspec.yaml` `version:` (`x.y.z+build`) **before** building.

### Source and main gate

Follow [CONTRIBUTING.md](CONTRIBUTING.md): push a `code/` branch, pass `Commit authorship` on the exact commit, then fast-forward main. Build from that verified main SHA. The September 10 history cleanup intentionally retained release tags; old artifact records still use their original source SHA. Do not retag or rebuild v0.9.18 for documentation changes.

### Fast cloud build (Lite + Offline)

Run the **Android Release APKs** workflow manually with:

- `version` — product version without `v`
- `lite_build_number` — Lite Android versionCode
- `offline_build_number` — a larger Offline versionCode
- `bundle_manifest_url` — the currently published root manifest; the current workflow requires `bundleVersion==20`, 1025 species, `/v5/`, completeness, and a matching archive SHA-256 before embedding it
- `offline_seed_apk_url` — optional previously published Offline APK; when set, CI reuses its embedded manifest/archive and performs the same completeness and SHA-256 checks instead of following the root manifest

The v0.9.19 pair uses Lite versionCode `206` and Offline `207`. A later pair
needs Lite greater than `207` and an even larger Offline code. Reusing a product
version requires explicit same-tag replacement authorization. Leave
`offline_seed_apk_url` empty to fetch the current v20 manifest/archive, or reuse
a published Offline seed only after the same v20 completeness/digest checks.
v0.9.18 reused the verified v20 archive from v0.9.17 unchanged; never substitute
the historical compact v14 seed.

The workflow analyzes and tests once, then builds the signed Lite and Offline
APKs in parallel. Each artifact is named
`TitoDex-<ver>-<variant>-rg-arm64.apk` and passes the release verifier before
upload. The Offline verifier also checks its embedded manifest and archive
SHA-256 against the selected manifest. Product versions and both Android
versionCodes must always increase monotonically.

Publishing is a separate manual **Publish Verified Android Release** workflow. Supply the
successful build run id, that run's exact source SHA, both build numbers, a full Chinese
`release_title`, a one-sentence Chinese `release_summary`, and a Chinese Markdown
`release_highlights` bullet list based on the exact tag contents. The publisher
refuses runs from another commit or workflow, rechecks package id, versionName and versionCode,
requires Lite and Offline to have the same signer, then creates an annotated tag and a draft
GitHub Release. Configure `ANDROID_SIGNER_SHA256` to pin that signer to the historical release
certificate rather than checking only cross-variant equality. The current publisher also requires legacy compatibility inputs `extension_version=1.0.0` and `extension_build_number=1`; the public App download pair remains Lite and Offline.

After inspecting the draft notes and downloading/verifying both uploaded APKs, publish the draft as stable or prerelease as authorized. In-app updates consume only stable releases with matching `TitoDex-<version>-{lite,offline}-rg-arm64.apk` asset names, uploaded state and GitHub SHA-256 digests. Keep increasing versionCodes and the existing package/signer identity.

Notify the separately maintained TitoDex Web task after publication. Its `src/lib/app-release.ts` must synchronize both `latestAppReleaseFallback` and `appDownloadsFallback`, including exact names, URLs and bytes. The homepage links to `/app#download`; verify both direct APK links after deployment, allowing for Service Worker cache.

### Offline variant

Temporarily use the `x.y.z-offline+build` version and include `assets/dex/` in `pubspec.yaml`; build with the same arm64 command. Its archive must contain `dex_catalog.json` so the seeded package can serve list, search, and reference filters without building indices after a tap.

```bash
flutter build apk --release --target-platform android-arm64
../tools/verify_release_apk.sh --offline build/app/outputs/flutter-apk/app-release.apk
cp build/app/outputs/flutter-apk/app-release.apk \
   ../releases/TitoDex-<ver>-offline-rg-arm64.apk
```

Restore the Lite `version:` and remove the `assets/dex/` entry before committing the normal source configuration; retain the offline archive only through the release asset.

---

## Post-build checklist

- [ ] `unzip -t releases/TitoDex-*-rg-arm64.apk` → **No errors**
- [ ] Lite file size within the verifier bounds (**15–35 MB**; v0.9.18 is **29.13 MB**); Offline is materially larger because it embeds v20, so verify the archive size and SHA-256 against the selected manifest instead of assuming the historical ~80 MB v14 size
- [ ] `lib/arm64-v8a/libflutter.so` present (~11.6 MB)
- [ ] `lib/arm64-v8a/libapp.so` present (~11.9 MB in v0.9.18)
- [ ] `lib/arm64-v8a/libzstandard_android.so` present
- [ ] Fresh-install Offline APK shows the one-time local unpack percentage, reaches 100%, then does not show it again on the next launch
- [ ] Lite Settings download can be minimized; Android requests notification permission, shows the same weighted percentage in a foreground-service notification, and completes while the app is backgrounded
- [ ] Cancelling a background download removes its progress notification; swiping TitoDex away or an Android 15 `dataSync` timeout stops the service and leaves a non-ongoing explanation instead of stale progress
- [ ] `assets/flutter_assets/assets/fixtures/PKMSS.sav` present
- [ ] Offline only: archive and manifest present under `assets/flutter_assets/assets/dex/`
- [ ] Nunito fonts present under `assets/flutter_assets/assets/fonts/`
- [ ] GitHub Release asset uploaded **after** local verify (same bytes as `releases/` copy)
- [ ] Publisher run is bound to the successful build run's exact `head_sha`; package metadata and signer checks pass
- [ ] Release title, opening summary, headings and filenames follow `docs/RELEASES.md`; public copy is Chinese-first
- [ ] App APK updater: matching variant, digest failure/cancel, unknown-source permission return, system confirmation and upgrade across signed versions; keep this device gate distinct from the Dex background-download checks
- [ ] First-run migration/replay and trainer shortcut pin/rename checked on target launchers; document any untested device behavior
- [ ] Web release metadata and both direct download links synchronized
- [ ] Do **not** paste CDN URLs in release notes (see `CLOUDFLARE_DEX_CDN.md`)

---

## Common failures

| Symptom | Cause | Fix |
| --- | --- | --- |
| APK ~7 MB, `unzip -t` fails | Copied APK before `flutter build` finished, or partial git commit | Rebuild; run `verify_release_apk.sh` |
| APK ~40 MB+ | Debug build or universal/multi-ABI APK | Use `flutter build apk --release` only; check `abiFilters` = `arm64-v8a` |
| Install fails on RG | Check signer, package id, Android version and versionCode | Preserve data; use the same release signer and a greater code. Export before uninstalling only an incompatible legacy/debug install |
| App opens but dex empty | User has not downloaded offline pack | Settings → 下载完整离线资料包 (not an APK packaging issue) |

---

## v0.4.1 incident (2026-07)

`TitoDex-0.4.1-rg-arm64.apk` was committed at **7.5 MB** with a **broken ZIP** (missing central directory). A clean rebuild from the same source produces **~21 MB** with all native libs. **Use v0.4.2+** or the corrected v0.4.1 asset after fix.

---

## Related docs

- [flutter/README.md](../flutter/README.md) — app layout & offline data
- [AI context](./AI_CONTEXT.md) — agent quick reference
- [CLOUDFLARE_DEX_CDN.md](./CLOUDFLARE_DEX_CDN.md) — dex bundle upload (maintainers)
