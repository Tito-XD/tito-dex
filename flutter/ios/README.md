# TitoDex iOS platform — status & constraints

**Audience:** maintainers / agents working on the `feature/ios-platform` branch.

Last updated: 2026-07-20.

## Current status

iOS support lives on the **`feature/ios-platform`** branch (3 commits ahead of `main` at `f15c095`):

| Commit | What it does |
|---|---|
| `18420e6` | Initial iOS platform scaffolding (`flutter/ios/`) |
| `e488df8` | CocoaPods integration (`Podfile`, `Podfile.lock`, `Runner.xcworkspace`) |
| `f8cebb8` | Fixes to make the build work under **Xcode 27 beta** |

**The app builds successfully under Xcode 27 beta.** No signing, App Store / TestFlight, or device-run work has been done yet.

## Upstream sync — deliberately paused

`origin/main` has moved ahead to **v0.6.7 / build 85** (`b1c1877`, "Retro phase 2": team page rework, responsive dex grid, quick-tile icons, `retro_forms.dart`, etc.). This branch has **not** been rebased onto it on purpose:

> Android Flutter builds are the primary release target. New `main` changes are validated and shipped on Android **first**; only after that do we rebase this branch and re-verify the iOS build.

When the time comes, the rebase is expected to be clean — the v0.6.7 diff touches zero files that this branch touches (verified with `git diff --name-only`). After rebasing, rebuild under Xcode 27 and push with `--force-with-lease`.

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

1. Ship v0.6.7 on Android; rebase this branch onto the new `main` and re-verify the build.
2. Run on simulator / physical device.
3. Bundle ID, signing, and team configuration.
4. App icons and launch screen assets.
5. TestFlight pipeline.
