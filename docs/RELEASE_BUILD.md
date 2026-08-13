# TitoDex RG APK — Release build checklist

**Audience:** maintainers packaging `TitoDex-<ver>-lite-rg-arm64.apk` and `TitoDex-<ver>-offline-rg-arm64.apk`.

A valid **arm64-v8a Lite** APK is about **20–23 MB** on disk; the compact v14
Offline APK is roughly **80 MB**. If a Lite build is only **~7 MB**, the file is
truncated or corrupt (missing `libflutter.so` tail / broken ZIP central
directory) — **do not ship it**.

---

## What must be inside the APK

### Native libraries (`lib/arm64-v8a/`)

| File | ~Size | Purpose |
| --- | --- | --- |
| `libflutter.so` | ~11 MB | Flutter engine |
| `libapp.so` | ~7–8 MB | Compiled Dart AOT (`flutter build apk --release`) |
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
| `assets/game_icons/*.png` | Bundled game icons with per-file provenance in `assets/game_icons/SOURCES.json` |
| `assets/fonts/Nunito-*.ttf` | UI typography (Regular / SemiBold / Bold / ExtraBold) |
| `AssetManifest.bin`, `FontManifest.json`, `NOTICES.Z` | Flutter asset index |

**Lite APK:** users download the complete offline reference pack through **Settings → 下载完整离线资料包** into app documents (`dex_offline/`). It includes the 1025-species dex and forms, evolution chains, moves, abilities, items, Chinese references, maps, images, and app config. The optional Offline APK adds `assets/dex/bundle.tar.zst` and its manifest, then seeds the same pack on first launch.

### Compile-time dex CDN config

Endpoints are baked in at build time (`flutter/lib/features/dex/dex_cdn_config.dart` via `--dart-define` / env). They are **not** shown in UI but are required for online fetch + bundle install.

---

## Prerequisites

1. **Flutter SDK** (stable, matches CI)
2. **Android SDK** — `compileSdk 36`, NDK `28.2.13676358`
3. **Release signing** — `flutter/android/key.properties` + keystore (see `flutter/android/app/build.gradle.kts`). CI/cloud VM must have the same keystore as historical RG builds, or users must uninstall before sideloading a differently signed APK.

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

# Sanity: output should be ~20–23 MB
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

### Fast cloud build (Lite + Offline)

Run the **Android Release APKs** workflow manually with:

- `version` — product version without `v`
- `lite_build_number` — Lite Android versionCode
- `offline_build_number` — a larger Offline versionCode
- `bundle_manifest_url` — the currently published root manifest; CI downloads its selected archive and verifies `bundleVersion>=7`, 1025 species, `/v5/`, completeness, and SHA-256 before embedding it
- `offline_seed_apk_url` — optional previously published Offline APK; when set, CI reuses its embedded manifest/archive and performs the same completeness and SHA-256 checks instead of following the root manifest

The latest published pair is v0.8.14 with Lite versionCode `156` and Offline
versionCode `157`. A later release must use a product version newer than
`0.8.14`, a Lite versionCode greater than `157`, and an even larger Offline
versionCode. v0.8.14 reused the published v0.8.12 Offline asset through
`offline_seed_apk_url` when the compact v14 seed is intentionally unchanged;
Do not seed a new Offline APK from the live v19 archive unless accepting the
larger package is an explicit release decision.

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
certificate rather than checking only cross-variant equality.

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
- [ ] Lite file size **≥ 15 MB** (expect **19–26 MB**); Offline is about **80 MB** with the v14 compact archive (older v13 packages are much larger)
- [ ] `lib/arm64-v8a/libflutter.so` present (~11 MB)
- [ ] `lib/arm64-v8a/libapp.so` present (~7–8 MB)
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
- [ ] Do **not** paste CDN URLs in release notes (see `CLOUDFLARE_DEX_CDN.md`)

---

## Common failures

| Symptom | Cause | Fix |
| --- | --- | --- |
| APK ~7 MB, `unzip -t` fails | Copied APK before `flutter build` finished, or partial git commit | Rebuild; run `verify_release_apk.sh` |
| APK ~40 MB+ | Debug build or universal/multi-ABI APK | Use `flutter build apk --release` only; check `abiFilters` = `arm64-v8a` |
| Install fails on RG | Signature mismatch vs installed build | Uninstall old TitoDex first |
| App opens but dex empty | User has not downloaded offline pack | Settings → 下载完整离线资料包 (not an APK packaging issue) |

---

## v0.4.1 incident (2026-07)

`TitoDex-0.4.1-rg-arm64.apk` was committed at **7.5 MB** with a **broken ZIP** (missing central directory). A clean rebuild from the same source produces **~21 MB** with all native libs. **Use v0.4.2+** or the corrected v0.4.1 asset after fix.

---

## Related docs

- [flutter/README.md](../flutter/README.md) — app layout & offline data
- [AI context](./AI_CONTEXT.md) — agent quick reference
- [CLOUDFLARE_DEX_CDN.md](./CLOUDFLARE_DEX_CDN.md) — dex bundle upload (maintainers)
