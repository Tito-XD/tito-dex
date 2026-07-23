#!/usr/bin/env bash
# Upload pokesprite type icons to Cloudflare R2 (v5/type_icons/).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICON_DIR="${1:-$ROOT/data/assets/type_icons}"

if [[ ! -d "$ICON_DIR" ]]; then
  echo "ERROR: icon dir not found: $ICON_DIR" >&2
  echo "Run: python3 tools/fetch_pokesprite_type_icons.py" >&2
  exit 1
fi

cd "$ROOT/cloudflare/dex-cdn"
npm ci --silent 2>/dev/null || npm ci

WR="npx wrangler r2 object put --remote"

count=0
for f in "$ICON_DIR"/*.png; do
  base=$(basename "$f")
  $WR "titodex-dex/v5/type_icons/$base" \
    --file="$f" \
    --content-type=image/png
  count=$((count + 1))
done

echo "Uploaded $count type icons to titodex-dex/v5/type_icons/"
