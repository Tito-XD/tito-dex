# TitoDex iOS platform — status & constraints

**Audience:** maintainers / agents working on the `feature/ios-platform` branch.

Last updated: 2026-07-21.

## Current status

iOS support lives on the **`feature/ios-platform`** branch, rebased onto `main` at **v0.6.9 (`0dad858`, build 91)**. Branch commits:

| Commit | What it does |
|---|---|
| scaffolding | Initial iOS platform scaffolding (`flutter/ios/`) |
| pods | CocoaPods integration (`Podfile`, `Podfile.lock`, `Runner.xcworkspace`) |
| Xcode 27 fixes | Fixes to make the build work under **Xcode 27 beta** |
| shell adaptation | iOS renders the real native shell instead of the web preview frame (see below) |

**Verified on 2026-07-21 against v0.6.9:** `flutter analyze` clean, `flutter test` 205 passing, `flutter build ios --no-codesign` succeeds under Xcode 27 beta (27.5 MB Runner.app). Signing / TestFlight / device runs still pending.

## iOS shell & layout adaptation (v0.6.9 rebase)

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

The v0.6.7–v0.6.9 feature work itself (retro forms, party grid, tablet rows,
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

Android Flutter builds are the primary release target. New `main` changes are
validated and shipped on Android **first**; only after that do we rebase this
branch and re-verify the iOS build. After rebasing, rebuild under Xcode 27 and
push with `--force-with-lease`.

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
