#!/usr/bin/env bash
# Upload built dex bundle to Cloudflare R2 via wrangler.
#
# Usage:
#   export CLOUDFLARE_ACCOUNT_ID=...
#   export WRANGLER_R2_BUCKET=titodex-dex   # optional, default titodex-dex
#   ./tools/upload_dex_bundle.sh dist/dex-v5/upload
#   ./tools/upload_dex_bundle.sh dist/dex-v5/upload v3   # optional CDN prefix (default v3)
#
# Requires: wrangler CLI (npm i -g wrangler)

set -euo pipefail

UPLOAD_DIR="${1:-dist/dex-v5/upload}"
CDN_PREFIX="${2:-v3}"
BUCKET="${WRANGLER_R2_BUCKET:-titodex-dex}"

mime_for() {
  case "$1" in
    *.json) echo "application/json" ;;
    *.png) echo "image/png" ;;
    *.zst) echo "application/octet-stream" ;;
    *) echo "application/octet-stream" ;;
  esac
}

if [[ ! -d "$UPLOAD_DIR" ]]; then
  echo "Upload directory not found: $UPLOAD_DIR" >&2
  echo "Run: python tools/build_dex_bundle.py --cdn-base https://dex.example.com" >&2
  exit 1
fi

if ! command -v wrangler >/dev/null 2>&1; then
  echo "wrangler CLI not found. Install: npm i -g wrangler" >&2
  exit 1
fi

put_object() {
  local key="$1"
  local file="$2"
  local content_type="$3"
  echo "→ r2://${BUCKET}/${key}"
  wrangler r2 object put "${BUCKET}/${key}" --file="$file" --content-type="$content_type"
}

put_object "bundle-manifest.json" \
  "$UPLOAD_DIR/bundle-manifest.json" \
  "application/json"

V_PREFIX="$UPLOAD_DIR/$CDN_PREFIX"
if [[ ! -d "$V_PREFIX" ]]; then
  if [[ "$CDN_PREFIX" == "v3" && -d "$UPLOAD_DIR/v2" ]]; then
    echo "Note: $V_PREFIX missing; falling back to upload/v2" >&2
    CDN_PREFIX="v2"
    V_PREFIX="$UPLOAD_DIR/v2"
  else
    echo "Missing bundle directory: $V_PREFIX" >&2
    exit 1
  fi
fi

for file in manifest.json summaries.json types.json moves.json abilities.json bundle.tar.zst; do
  if [[ ! -f "$V_PREFIX/$file" ]]; then
    if [[ "$file" == "abilities.json" ]]; then
      echo "  skip missing abilities.json (pre-v5 bundle)" >&2
      continue
    fi
    echo "Missing $V_PREFIX/$file" >&2
    exit 1
  fi
  put_object "${CDN_PREFIX}/${file}" "$V_PREFIX/$file" "$(mime_for "$file")"
done

for dir in details sprites type_icons; do
  while IFS= read -r file; do
    rel="${file#"$V_PREFIX/"}"
    put_object "${CDN_PREFIX}/${rel}" "$file" "$(mime_for "$file")"
  done < <(find "$V_PREFIX/$dir" -type f | sort)
done

echo ""
echo "Upload complete. Purge CDN cache for /bundle-manifest.json and verify:"
echo "  curl -I https://dex.<domain>/bundle-manifest.json"
echo "  curl -I https://dex.<domain>/${CDN_PREFIX}/sprites/25.png"
