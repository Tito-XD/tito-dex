# TitoDex RG APK — Release build checklist

**Audience:** maintainers / Cloud Agents packaging `TitoDex-<ver>-lite-rg-arm64.apk` and `TitoDex-<ver>-offline-rg-arm64.apk`.

A valid **arm64-v8a release** APK is about **20–23 MB** on disk. If you see **~7 MB**, the file is **truncated or corrupt** (missing `libflutter.so` tail / broken ZIP central directory) — **do not ship it**.

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

### Bundled Flutter assets (not the CDN dex bundle)

These ship **inside** the APK via `pubspec.yaml`:

| Asset | Purpose |
| --- | --- |
| `assets/fixtures/PKMSS.sav` | Settings → 导入内置存档 |
| `assets/companion_media/*` | Starter companion GIFs + cries (29 species) |
| `assets/game_icons/*.png` | Official HOME game icons (Gen VI+) |
| `assets/fonts/Nunito-*.ttf` | UI typography (Regular / SemiBold / Bold / ExtraBold) |
| `AssetManifest.bin`, `FontManifest.json`, `NOTICES.Z` | Flutter asset index |

**Lite APK:** users download the 1025-species dex pack through **Settings → 下载预打包图鉴包** into app documents (`dex_offline/`). The optional Offline APK adds `assets/dex/bundle.tar.zst` and its manifest, then seeds the same pack on first launch.

### Compile-time dex CDN config

Endpoints are baked in at build time (`flutter/lib/features/dex/dex_cdn_config.dart` via `--dart-define` / env). They are **not** shown in UI but are required for online fetch + bundle install.

---

## Prerequisites

1. **Flutter SDK** (stable, matches CI)
2. **Android SDK** — `compileSdk 36`, NDK `27.0.12077973`
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
- `bundle_manifest_url` — the already-published v7 root manifest; CI downloads its archive and verifies `bundleVersion=7`, 1025 species, `/v5/`, completeness, and SHA-256 before embedding it

For v0.7.1 use `version=0.7.1`, Lite build `95`, and Offline build `96`. The workflow analyzes and tests once, then builds the signed Lite and Offline APKs in parallel. Each artifact is named `TitoDex-<ver>-<variant>-rg-arm64.apk` and passes the release verifier before upload. The Offline verifier also checks its embedded v7 manifest and archive SHA-256.

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
- [ ] Lite file size **≥ 15 MB** (expect **19–23 MB**); Offline is about **100–110 MB** with the v7 archive
- [ ] `lib/arm64-v8a/libflutter.so` present (~11 MB)
- [ ] `lib/arm64-v8a/libapp.so` present (~7–8 MB)
- [ ] `lib/arm64-v8a/libzstandard_android.so` present
- [ ] `assets/flutter_assets/assets/fixtures/PKMSS.sav` present
- [ ] Offline only: archive and manifest present under `assets/flutter_assets/assets/dex/`
- [ ] Nunito fonts present under `assets/flutter_assets/assets/fonts/`
- [ ] GitHub Release asset uploaded **after** local verify (same bytes as `releases/` copy)
- [ ] Do **not** paste CDN URLs in release notes (see `CLOUDFLARE_DEX_CDN.md`)

---

## Common failures

| Symptom | Cause | Fix |
| --- | --- | --- |
| APK ~7 MB, `unzip -t` fails | Copied APK before `flutter build` finished, or partial git commit | Rebuild; run `verify_release_apk.sh` |
| APK ~40 MB+ | Debug build or universal/multi-ABI APK | Use `flutter build apk --release` only; check `abiFilters` = `arm64-v8a` |
| Install fails on RG | Signature mismatch vs installed build | Uninstall old TitoDex first |
| App opens but dex empty | User has not downloaded offline pack | Settings → 下载预打包图鉴包 (not an APK packaging issue) |

---

## v0.4.1 incident (2026-07)

`TitoDex-0.4.1-rg-arm64.apk` was committed at **7.5 MB** with a **broken ZIP** (missing central directory). A clean rebuild from the same source produces **~21 MB** with all native libs. **Use v0.4.2+** or the corrected v0.4.1 asset after fix.

---

## Related docs

- [flutter/README.md](../flutter/README.md) — app layout & offline data
- [AI context](./AI_CONTEXT.md) — agent quick reference
- [CLOUDFLARE_DEX_CDN.md](./CLOUDFLARE_DEX_CDN.md) — dex bundle upload (maintainers)
