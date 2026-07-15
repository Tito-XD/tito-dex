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

**Do not use** `--split-per-abi` or `--target-platform` flags that drop libs. RG sideload needs **Stored** native libs (`minSdk 24`, `useLegacyPackaging = false`) — see `flutter/android/app/build.gradle.kts`.

### Bundled Flutter assets (not the CDN dex bundle)

These ship **inside** the APK via `pubspec.yaml`:

| Asset | Purpose |
| --- | --- |
| `assets/fixtures/PKMSS.sav` | Settings → 导入内置存档 |
| `assets/companion/*.png` | Home companion sprites (HGSS starters) |
| `assets/fonts/Nunito-*.ttf` | UI typography (Regular / SemiBold / Bold / ExtraBold) |
| `AssetManifest.bin`, `FontManifest.json`, `NOTICES.Z` | Flutter asset index |

**Not bundled in APK:** the 1025-species dex offline pack — users download via **Settings → 下载预打包图鉴包** into app documents (`dex_offline/`).

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
flutter build apk --release

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

---

## Post-build checklist

- [ ] `unzip -t releases/TitoDex-*-rg-arm64.apk` → **No errors**
- [ ] File size **≥ 15 MB** (expect **19–23 MB**)
- [ ] `lib/arm64-v8a/libflutter.so` present (~11 MB)
- [ ] `lib/arm64-v8a/libapp.so` present (~7–8 MB)
- [ ] `lib/arm64-v8a/libzstandard_android.so` present
- [ ] `assets/flutter_assets/assets/fixtures/PKMSS.sav` present
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
