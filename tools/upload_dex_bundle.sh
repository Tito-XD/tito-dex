#!/usr/bin/env bash
# Upload built dex bundle to Cloudflare R2 via wrangler.
#
# Usage:
#   export CLOUDFLARE_ACCOUNT_ID=...
#   export WRANGLER_R2_BUCKET=titodex-dex   # optional, default titodex-dex
#   ./tools/upload_dex_bundle.sh dist/dex-v2/upload
#
# Requires: wrangler CLI (npm i -g wrangler)

set -euo pipefail

UPLOAD_DIR="${1:-dist/dex-v2/upload}"
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

V2="$UPLOAD_DIR/v2"
if [[ ! -d "$V2" ]]; then
  echo "Missing v2 directory: $V2" >&2
  exit 1
fi

for file in manifest.json summaries.json types.json moves.json bundle.tar.zst; do
  put_object "v2/${file}" "$V2/${file}" "$(mime_for "$file")"
done

for dir in details sprites type_icons; do
  while IFS= read -r file; do
    rel="${file#"$V2/"}"
    put_object "v2/${rel}" "$file" "$(mime_for "$file")"
  done < <(find "$V2/$dir" -type f | sort)
done

echo ""
echo "Upload complete. Purge CDN cache for /bundle-manifest.json and verify:"
echo "  curl -I https://dex.<domain>/bundle-manifest.json"
echo "  curl -I https://dex.<domain>/v2/sprites/25.png"
