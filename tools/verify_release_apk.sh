#!/usr/bin/env bash
# Verify a TitoDex RG arm64 release APK before commit / GitHub upload.
set -euo pipefail

APK="${1:?Usage: verify_release_apk.sh path/to/TitoDex-x.y.z-rg-arm64.apk}"

if [[ ! -f "$APK" ]]; then
  echo "ERROR: file not found: $APK" >&2
  exit 1
fi

size_bytes=$(stat -c%s "$APK" 2>/dev/null || stat -f%z "$APK")
size_mb=$((size_bytes / 1024 / 1024))
base="$(basename "$APK")"
is_offline=0
if [[ "$base" == *"-offline-"* ]] || [[ "$base" == *offline* ]]; then
  is_offline=1
fi

echo "==> $APK"
echo "    size: ${size_mb} MB (${size_bytes} bytes)"
if (( is_offline )); then
  echo "    flavor: offline (bundled dex pack)"
fi

# Standard RG arm64 ~19–23 MB. Offline flavor embeds ~40 MB bundle.tar.zst → ~60–75 MB.
if (( size_bytes < 15000000 )); then
  echo "ERROR: APK too small — expected ~20–23 MB (or ~60–75 MB for offline)." >&2
  echo "       Likely truncated copy or build still in progress." >&2
  exit 1
fi

if (( is_offline )); then
  if (( size_bytes < 45000000 )); then
    echo "ERROR: offline APK too small (<45 MB) — bundled dex archive likely missing." >&2
    exit 1
  fi
  if (( size_bytes > 120000000 )); then
    echo "WARN: offline APK larger than expected (>120 MB)." >&2
  fi
elif (( size_bytes > 35000000 )); then
  echo "WARN: APK larger than usual (>35 MB) — check for debug build, universal ABI, or offline assets." >&2
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

if (( is_offline )); then
  echo "==> offline dex assets"
  for asset in \
    assets/flutter_assets/assets/dex/bundle.tar.zst \
    assets/flutter_assets/assets/dex/bundle-manifest.json; do
    if ! echo "$listing" | awk -v n="$asset" '$4==n {found=1; exit} END{exit !found}'; then
      echo "ERROR: missing $asset" >&2
      exit 1
    fi
    echo "    OK $asset"
  done
fi

echo "PASS: release APK looks complete."
