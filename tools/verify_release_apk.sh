#!/usr/bin/env bash
# Verify a TitoDex RG arm64 release APK before commit / GitHub upload.
set -euo pipefail

offline=false
if [[ "${1:-}" == "--offline" ]]; then
  offline=true
  shift
fi

APK="${1:?Usage: verify_release_apk.sh [--offline] path/to/TitoDex-x.y.z-rg-arm64.apk}"

if [[ ! -f "$APK" ]]; then
  echo "ERROR: file not found: $APK" >&2
  exit 1
fi

size_bytes=$(stat -c%s "$APK" 2>/dev/null || stat -f%z "$APK")
size_mb=$((size_bytes / 1024 / 1024))

echo "==> $APK"
echo "    size: ${size_mb} MB (${size_bytes} bytes)"

# RG arm64 release builds are ~19–23 MB. Anything under 15 MB is almost certainly truncated.
if (( size_bytes < 15000000 )); then
  echo "ERROR: APK too small — expected ~20–23 MB for arm64-v8a release." >&2
  echo "       Likely truncated copy or build still in progress." >&2
  exit 1
fi

if ! "$offline" && (( size_bytes > 35000000 )); then
  echo "ERROR: standard APK larger than expected (>35 MB) — likely debug or universal ABI." >&2
  exit 1
fi

if "$offline" && (( size_bytes > 100000000 )); then
  echo "ERROR: offline APK larger than expected (>100 MB)." >&2
  exit 1
fi

echo "==> zip integrity"
unzip -t "$APK" >/dev/null

echo "==> required native libraries (arm64-v8a)"
required=(
  lib/arm64-v8a/libapp.so
  lib/arm64-v8a/libflutter.so
  lib/arm64-v8a/libzstandard_android.so
)
listing=$(unzip -l "$APK")
unexpected_runtime_libs=$(
  echo "$listing" |
    awk '$4 ~ /^lib\/[^/]+\/(libapp|libflutter)\.so$/ && $4 !~ /^lib\/arm64-v8a\// {print $4}'
)
if [[ -n "$unexpected_runtime_libs" ]]; then
  echo "ERROR: Flutter runtime was built for non-arm64 ABIs:" >&2
  echo "$unexpected_runtime_libs" >&2
  exit 1
fi
for lib in "${required[@]}"; do
  lib_size=$(echo "$listing" | awk -v n="$lib" '$4==n {print $1; exit}')
  if [[ -z "$lib_size" ]]; then
    echo "ERROR: missing $lib" >&2
    exit 1
  fi
  echo "    OK $lib (${lib_size} bytes uncompressed)"
done

# libflutter.so should be ~11 MB; libapp.so ~7–8 MB
flutter_size=$(echo "$listing" | awk '$4=="lib/arm64-v8a/libflutter.so" {print $1; exit}')
if (( flutter_size < 10000000 )); then
  echo "ERROR: libflutter.so too small ($flutter_size) — incomplete engine." >&2
  exit 1
fi

echo "==> bundled assets spot-check"
for asset in \
  assets/flutter_assets/assets/fixtures/PKMSS.sav \
  assets/flutter_assets/assets/fonts/Nunito-Regular.ttf \
  assets/flutter_assets/AssetManifest.bin; do
  if ! echo "$listing" | awk -v n="$asset" '$4==n {found=1; exit} END{exit !found}'; then
    echo "ERROR: missing $asset" >&2
    exit 1
  fi
  echo "    OK $asset"
done

if "$offline"; then
  echo "==> bundled offline Dex data"
  for asset in \
    assets/flutter_assets/assets/dex/bundle-manifest.json \
    assets/flutter_assets/assets/dex/bundle.tar.zst; do
    if ! echo "$listing" | awk -v n="$asset" '$4==n {found=1; exit} END{exit !found}'; then
      echo "ERROR: missing $asset" >&2
      exit 1
    fi
    echo "    OK $asset"
  done
fi

echo "PASS: release APK looks complete."
