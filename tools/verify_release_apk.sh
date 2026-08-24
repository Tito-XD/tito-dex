#!/usr/bin/env bash
# Verify a TitoDex RG arm64 release APK before commit / GitHub upload.
set -euo pipefail

offline=false
expected_package=""
expected_version_name=""
expected_version_code=""
expected_bundle_version=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --offline) offline=true; shift ;;
    --expected-package) expected_package="${2:?missing package id}"; shift 2 ;;
    --expected-version-name) expected_version_name="${2:?missing version name}"; shift 2 ;;
    --expected-version-code) expected_version_code="${2:?missing version code}"; shift 2 ;;
    --expected-bundle-version) expected_bundle_version="${2:?missing bundle version}"; shift 2 ;;
    --*) echo "ERROR: unknown option: $1" >&2; exit 2 ;;
    *) APK="$1"; shift ;;
  esac
done

APK="${APK:?Usage: verify_release_apk.sh [--offline] [--expected-package ID] [--expected-version-name NAME] [--expected-version-code CODE] [--expected-bundle-version VERSION] path/to/APK}"

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

# The complete v20 archive keeps the Offline APK below this release guard while
# leaving headroom for verified metadata without allowing a universal/debug build.
if "$offline" && (( size_bytes > 145000000 )); then
  echo "ERROR: offline APK larger than expected (>145 MB)." >&2
  exit 1
fi

echo "==> zip integrity"
unzip -t "$APK" >/dev/null

if [[ -n "$expected_package$expected_version_name$expected_version_code" ]]; then
  apkanalyzer="$(command -v apkanalyzer || true)"
  if [[ -z "$apkanalyzer" && -n "${ANDROID_HOME:-}" ]]; then
    apkanalyzer="$(find "$ANDROID_HOME/cmdline-tools" -type f -name apkanalyzer 2>/dev/null | sort -V | tail -n 1)"
  fi
  if [[ ! -x "$apkanalyzer" ]]; then
    echo "ERROR: apkanalyzer is required for manifest expectations." >&2
    exit 1
  fi
  actual_package="$($apkanalyzer manifest application-id "$APK")"
  actual_version_name="$($apkanalyzer manifest version-name "$APK")"
  actual_version_code="$($apkanalyzer manifest version-code "$APK")"
  [[ -z "$expected_package" || "$actual_package" == "$expected_package" ]] || {
    echo "ERROR: application id $actual_package, expected $expected_package" >&2; exit 1;
  }
  [[ -z "$expected_version_name" || "$actual_version_name" == "$expected_version_name" ]] || {
    echo "ERROR: versionName $actual_version_name, expected $expected_version_name" >&2; exit 1;
  }
  [[ -z "$expected_version_code" || "$actual_version_code" == "$expected_version_code" ]] || {
    echo "ERROR: versionCode $actual_version_code, expected $expected_version_code" >&2; exit 1;
  }
  echo "==> manifest $actual_package $actual_version_name ($actual_version_code)"
fi

echo "==> required native libraries (arm64-v8a)"
required=(
  lib/arm64-v8a/libapp.so
  lib/arm64-v8a/libflutter.so
  lib/arm64-v8a/libzstandard_android.so
)
listing=$(unzip -l "$APK")
unexpected_runtime_libs=$(
  echo "$listing" |
    awk '{
      split($4, path, "/")
      if (path[1] == "lib" && path[2] != "arm64-v8a" &&
          (path[3] == "libapp.so" || path[3] == "libflutter.so")) {
        print $4
      }
    }'
)
if [[ -n "$unexpected_runtime_libs" ]]; then
  echo "ERROR: Flutter runtime was built for non-arm64 ABIs:" >&2
  echo "$unexpected_runtime_libs" >&2
  exit 1
fi
# Note: feed $listing to awk via herestrings, never `echo | awk` — awk's
# early exit closes the pipe mid-write and pipefail turns the resulting
# EPIPE on echo into a spurious "missing" failure.
for lib in "${required[@]}"; do
  lib_size=$(awk -v n="$lib" '$4==n {print $1; exit}' <<<"$listing")
  if [[ -z "$lib_size" ]]; then
    echo "ERROR: missing $lib" >&2
    exit 1
  fi
  echo "    OK $lib (${lib_size} bytes uncompressed)"
done

# libflutter.so should be ~11 MB; libapp.so ~7–8 MB
flutter_size=$(awk '$4=="lib/arm64-v8a/libflutter.so" {print $1; exit}' <<<"$listing")
if (( flutter_size < 10000000 )); then
  echo "ERROR: libflutter.so too small ($flutter_size) — incomplete engine." >&2
  exit 1
fi

echo "==> bundled assets spot-check"
for asset in \
  assets/flutter_assets/assets/fixtures/PKMSS.sav \
  assets/flutter_assets/assets/fonts/Nunito-Regular.ttf \
  assets/flutter_assets/AssetManifest.bin; do
  if ! awk -v n="$asset" '$4==n {found=1; exit} END{exit !found}' <<<"$listing"; then
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
    if ! awk -v n="$asset" '$4==n {found=1; exit} END{exit !found}' <<<"$listing"; then
      echo "ERROR: missing $asset" >&2
      exit 1
    fi
    echo "    OK $asset"
  done

  tmp_dir=$(mktemp -d)
  trap 'rm -rf "$tmp_dir"' EXIT
  unzip -p "$APK" assets/flutter_assets/assets/dex/bundle-manifest.json > "$tmp_dir/bundle-manifest.json"
  unzip -p "$APK" assets/flutter_assets/assets/dex/bundle.tar.zst > "$tmp_dir/bundle.tar.zst"
  python3 - "$tmp_dir/bundle-manifest.json" "$expected_bundle_version" <<'PY'
import json
import sys

manifest = json.load(open(sys.argv[1], encoding="utf-8"))
expected_bundle_version = sys.argv[2]
if expected_bundle_version:
    assert str(manifest.get("bundleVersion")) == expected_bundle_version, manifest
assert manifest.get("bundleVersion") >= 7, manifest
assert manifest.get("pokemonCount") == 1025, manifest
assert manifest.get("complete") is True, manifest
assert manifest.get("cdnPrefix") == "v5", manifest
assert "/v5/" in str(manifest.get("archiveUrl", "")), manifest
assert len(str(manifest.get("archiveSha256", ""))) == 64, manifest
PY
  expected_sha=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["archiveSha256"])' "$tmp_dir/bundle-manifest.json")
  actual_sha=$(sha256sum "$tmp_dir/bundle.tar.zst" 2>/dev/null | awk '{print $1}' || shasum -a 256 "$tmp_dir/bundle.tar.zst" | awk '{print $1}')
  if [[ "$actual_sha" != "$expected_sha" ]]; then
    echo "ERROR: bundled Dex archive SHA-256 mismatch." >&2
    exit 1
  fi
  version=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["bundleVersion"])' "$tmp_dir/bundle-manifest.json")
  echo "    OK v${version} manifest and archive SHA-256"
fi

echo "PASS: release APK looks complete."
