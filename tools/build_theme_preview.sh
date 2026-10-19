#!/usr/bin/env bash
# Side-by-side RG pre-release. Does not install or modify the production app.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT/flutter"
export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17}"
export ANDROID_HOME="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"
export GRADLE_OPTS="${GRADLE_OPTS:-} -Dorg.gradle.daemon=false"
export TITODEX_APPLICATION_ID=com.tito.titodex.themepreview
export TITODEX_APP_LABEL='TitoDex 主题预览'
export TITODEX_VERSION_NAME_SUFFIX=''
PREVIEW_VERSION=0.9.6-motion.2
PREVIEW_BUILD_NUMBER=194
FLUTTER_BIN="${FLUTTER_BIN:-/opt/homebrew/share/flutter/bin/flutter}"
BUILD_TOOLS="${ANDROID_BUILD_TOOLS:-$ANDROID_HOME/build-tools/36.0.0}"
PREVIEW_KEYSTORE="${PREVIEW_KEYSTORE:-$HOME/.android/debug.keystore}"
OUT="$ROOT/flutter/build/theme-preview"
mkdir -p "$OUT"
test -f "$PREVIEW_KEYSTORE"
touch "$OUT/build-start"
"$FLUTTER_BIN" build apk --release --no-pub --target-platform android-arm64 \
  --build-name="$PREVIEW_VERSION" --build-number="$PREVIEW_BUILD_NUMBER"
SOURCE="$ROOT/flutter/build/app/outputs/flutter-apk/app-release.apk"
test "$SOURCE" -nt "$OUT/build-start"
APK="$OUT/TitoDex-$PREVIEW_VERSION-theme-preview-rg-arm64.apk"
# A development certificate deliberately identifies this as a local preview.
"$BUILD_TOOLS/apksigner" sign --ks "$PREVIEW_KEYSTORE" --ks-key-alias androiddebugkey \
  --ks-pass pass:android --key-pass pass:android --out "$APK" "$SOURCE"
"$BUILD_TOOLS/apksigner" verify --verbose "$APK"
bash "$ROOT/tools/verify_release_apk.sh" --expected-package "$TITODEX_APPLICATION_ID" \
  --expected-version-name "$PREVIEW_VERSION" --expected-version-code "$PREVIEW_BUILD_NUMBER" "$APK"
echo "Preview APK: $APK"
