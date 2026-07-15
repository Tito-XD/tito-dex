#!/usr/bin/env bash
# Stage the current CDN offline pack into flutter/assets/dex/ for *-offline APKs.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/flutter/assets/dex"
if [[ -z "${TITODEX_DEX_CDN_BASE:-}" ]]; then
  echo "ERROR: TITODEX_DEX_CDN_BASE is required." >&2
  exit 2
fi
CDN_BASE="${TITODEX_DEX_CDN_BASE%/}"
UA="TitoDex-offline-builder/1.0"

mkdir -p "$OUT" /tmp/titodex-dex-stage
curl -fsSL -A "$UA" "$CDN_BASE/bundle-manifest.json" -o /tmp/titodex-dex-stage/bundle-manifest.json

ARCHIVE_URL="$(python3 -c 'import json; print(json.load(open("/tmp/titodex-dex-stage/bundle-manifest.json"))["archiveUrl"])')"
curl -fsSL -A "$UA" "$ARCHIVE_URL" -o "$OUT/bundle.tar.zst"

python3 - "$OUT" <<'PY'
import json, hashlib, pathlib, sys
out = pathlib.Path(sys.argv[1])
meta = json.loads(pathlib.Path("/tmp/titodex-dex-stage/bundle-manifest.json").read_text())
path = out / "bundle.tar.zst"
digest = hashlib.sha256(path.read_bytes()).hexdigest()
expected = meta["archiveSha256"].lower()
if digest != expected:
    raise SystemExit(f"SHA-256 mismatch: expected {expected}, got {digest}")
sidecar = {
    "bundleVersion": meta["bundleVersion"],
    "pokemonCount": meta["pokemonCount"],
    "archiveSha256": expected,
    "archiveSizeBytes": meta["archiveSizeBytes"],
    "publishedAt": meta.get("publishedAt"),
    "l10nVersion": meta.get("l10nVersion"),
    "configVersion": meta.get("configVersion"),
    "assetPath": "assets/dex/bundle.tar.zst",
}
(out / "bundle-manifest.json").write_text(json.dumps(sidecar, indent=2) + "\n")
print(f"Staged {path} ({path.stat().st_size} bytes), sha256 OK")
PY
