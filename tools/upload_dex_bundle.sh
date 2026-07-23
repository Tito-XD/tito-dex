#!/usr/bin/env bash
# Two-phase R2 upload wrapper. Versioned objects are uploaded and verified
# before bundle-manifest.json is updated.

set -euo pipefail

UPLOAD_DIR="${1:-dist/dex-v6/upload}"
CDN_PREFIX="${2:-v4}"

exec python3 tools/upload_dex_bundle_r2.py \
  "$UPLOAD_DIR" \
  --cdn-prefix "$CDN_PREFIX" \
  --phase all
