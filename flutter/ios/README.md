# TitoDex iOS platform — status & constraints

**Audience:** maintainers / agents working on the shared Flutter source.

Last updated: 2026-07-23.

## Current status

iOS support is merged into **`main`** for v0.7.0. The original platform branch supplied:

| Commit | What it does |
|---|---|
| scaffolding | Initial iOS platform scaffolding (`flutter/ios/`) |
| pods | CocoaPods integration (`Podfile`, `Podfile.lock`, `Runner.xcworkspace`) |
| Xcode 27 fixes | Fixes to make the build work under **Xcode 27 beta** |
| shell adaptation | iOS renders the real native shell instead of the web preview frame (see below) |

**Verified on 2026-07-23 against v0.7.0:** `pod install`, `flutter analyze`, 215 Flutter tests, and `flutter build ios --no-codesign --release` succeed under Xcode 27 beta (27.6 MB Runner.app). Pods and generated files were cleaned afterward. Signing / TestFlight / device runs remain intentionally outside the 0.7.0 Android release.

## iOS shell & layout adaptation (merged for v0.7.0)

`DeviceLayout.isNativeTarget` previously meant Android/Linux only, so iOS fell
through to `_PreviewShell` — the web preview frame (520 px card, fake status
strip). Fixed:

- **`isNativeTarget` now includes iOS** — iPhone/iPad get `_RegularNativeShell`
  (deepBlue backdrop + real `SafeArea`) and the same handheld typography/UI
  scale as Android phones.
- **New `DeviceLayout.isHandheldPlatform` (Android/Linux only)** gates
  `useHandheldChrome` and `SystemUiCoordinator`'s immersive-sticky mode.
  Rationale: iPads are ~4:3 panels and would otherwise be misdetected as RG
  handhelds and lose their status bar / safe areas. iPads still get the square
  dashboard *layout* (aspect-based), just not the immersive *chrome*.
- **`statusBarBrightness: Brightness.dark`** added to the two
  `SystemUiOverlayStyle` constructions that lacked it (`main.dart`,
  `system_ui_coordinator.dart`) — iOS ignores `statusBarIconBrightness`
  (Android-only) and reads background brightness instead.

The v0.6.7–v0.7.0 feature work itself (retro forms, party grid, tablet rows,
battle handoff, …) is pure widget/layout code — no platform channels, no new
plugins — and needed no per-platform changes. `battery_plus` /
`connectivity_plus` (header Wi-Fi/battery icons) support iOS and the service
already falls back on errors.

## Things to check at first device run

- Status bar: white text over the deepBlue strip on notched iPhones.
- iPad: square dashboard layout **with** visible status bar (not immersive).
- Pokémon detail page: Android tints the system nav bar warm-white to match
  the page's bottom bar; on iPhone the home-indicator area stays deepBlue —
  acceptable, but note the seam if it looks off.
- Save import via `file_picker` (copies into `save_import/` under app
  documents), photo-library avatar picking (`NSPhotoLibraryUsageDescription`).

## Upstream sync policy

Android Flutter builds remain the primary release target. iOS now shares
`main` directly: platform-sensitive changes must keep `flutter analyze` and the
full Flutter suite green, then repeat `pod install` and the no-codesign Xcode
build before an Android release is tagged.

## Xcode 27 beta workarounds — do not remove

`Podfile`'s `post_install` hook carries three workarounds. **Do not touch them unless you have confirmed the Xcode / pod versions no longer need them.**

1. **Deployment target forced to iOS 15.0** (Runner and every pod).
   Xcode 27 rejects deployment targets below 15.0, and several older pods still declare 9.0–13.0.

2. **`zstandard_ios`'s "Remove synced zstd" script phase is deleted.**
   That phase is positioned `:any`, and under Xcode 27's parallel scheduling it races with compilation and deletes its own zstd source files mid-build.

3. **Explicit Clang modules disabled for all pods** (`CLANG_ENABLE_EXPLICIT_MODULES = NO`).
   Explicit modules are the Xcode 27 default, but they break `TOCropViewController`'s headers with `redefinition` errors during `PrecompileModule`.

## Building

```sh
cd flutter
flutter pub get
cd ios && pod install && cd ..
flutter build ios --no-codesign   # or open ios/Runner.xcworkspace in Xcode
```

Always open **`Runner.xcworkspace`**, not `Runner.xcodeproj`.

## Next steps (rough order)

1. Run on simulator / physical device (see "Things to check" above).
2. Bundle ID, signing, and team configuration.
3. App icons and launch screen assets (icon set already rendered via `tools/render_ios_icons.py`).
4. TestFlight pipeline.
