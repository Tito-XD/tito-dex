#!/usr/bin/env bash
# CDN-only pipeline: build 1025 → upload v3 → verify assets. Reports every 90s.
set -euo pipefail

PROGRESS=/tmp/cdn-pipeline-progress.txt
STATUS=/tmp/cdn-status.txt
BUILD_LOG=/tmp/dex-build-resume.log
STAGING=/workspace/dist/dex-v5/staging
DETAILS="$STAGING/details"
UPLOAD=/workspace/dist/dex-v5/upload
MAX_ID=1025
CDN=https://dex.tito.cafe
POLL_SECS=90

log() {
  local msg="$1"
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $msg" | tee -a "$PROGRESS"
}

count_details() {
  if [[ -d "$DETAILS" ]]; then
    find "$DETAILS" -maxdepth 1 -name '*.json' | wc -l | tr -d ' '
  else
    echo 0
  fi
}

pct_of() {
  python3 - <<PY "$1" "$MAX_ID"
import sys
count, total = int(sys.argv[1]), int(sys.argv[2])
print(f"{count * 100 / total:.1f}")
PY
}

report_build() {
  local count phase
  count=$(count_details)
  local pct
  pct=$(pct_of "$count")
  if [[ -f "$BUILD_LOG" ]] && grep -q "^Done\." "$BUILD_LOG"; then
    phase="BUILD"
    count=$MAX_ID
    pct="100.0"
  elif [[ -f /tmp/dex-upload.log ]]; then
    phase="UPLOAD"
    count=$(grep -c '^→' /tmp/dex-upload.log 2>/dev/null || echo 0)
    pct="?"
  elif [[ -f /tmp/cdn-verify.log ]]; then
    phase="CDN-VERIFY"
    count=$(grep -c ' OK$' /tmp/cdn-verify.log 2>/dev/null || echo 0)
    pct="?"
  else
    phase="BUILD"
  fi
  local line="[$phase] ${pct}% — ${count}/${MAX_ID} species details"
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $line" | tee -a "$PROGRESS" > "$STATUS"
}

wait_build() {
  while true; do
    report_build
    if [[ -f "$BUILD_LOG" ]] && grep -q "^Done\." "$BUILD_LOG"; then
      log "BUILD 100.0% (${MAX_ID}/${MAX_ID}) — complete"
      return 0
    fi
    sleep "$POLL_SECS"
  done
}

upload_bundle() {
  log "UPLOAD starting → R2 titodex-dex/v3/"
  cd /workspace
  source ~/.venv-titodex-tools/bin/activate
  if python3 tools/upload_dex_bundle_r2.py dist/dex-v5/upload --cdn-prefix v3 --resume 2>&1 | tee -a /tmp/dex-upload.log; then
    local files
    files=$(grep -c '^→' /tmp/dex-upload.log || echo 0)
    log "UPLOAD done — ${files} objects"
  else
    log "UPLOAD FAILED — see /tmp/dex-upload.log"
    exit 1
  fi
}

verify_cdn() {
  : > /tmp/cdn-verify.log
  log "CDN-VERIFY starting"

  local required=(
    "/bundle-manifest.json"
    "/v3/manifest.json"
    "/v3/summaries.json"
    "/v3/moves.json"
    "/v3/abilities.json"
    "/v3/games.json"
    "/v3/natures.json"
    "/v3/egg_groups.json"
    "/v3/status_conditions.json"
    "/v3/weather.json"
    "/v3/terrains.json"
    "/v3/items.json"
    "/v3/types.json"
    "/v3/details/1.json"
    "/v3/details/25.json"
    "/v3/details/493.json"
    "/v3/details/1025.json"
    "/v3/sprites/1.png"
    "/v3/sprites/25.png"
    "/v3/sprites/1025.png"
    "/v3/artwork/25.png"
    "/v3/type_icons/fire.png"
    "/v3/bundle.tar.zst"
  )

  local ok=0 total=${#required[@]}
  for path in "${required[@]}"; do
    local code size
    code=$(curl -sS -o /dev/null -w "%{http_code}" "${CDN}${path}" || echo "000")
    if [[ "$code" == "200" ]]; then
      ok=$((ok + 1))
      echo "${path} OK" >> /tmp/cdn-verify.log
    else
      echo "${path} FAIL ${code}" >> /tmp/cdn-verify.log
      log "CDN miss ${path} HTTP ${code}"
    fi
    local pct
    pct=$(python3 -c "print(f'{$ok * 100 / $total:.1f}')")
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [CDN-VERIFY] ${pct}% — ${ok}/${total} endpoints" | tee -a "$PROGRESS" > "$STATUS"
    sleep 2
  done

  # Schema spot-checks: images/stats/flavor/abilities/obtain
  local detail
  detail=$(curl -sS "${CDN}/v3/details/25.json")
  python3 - <<'PY' "$detail" | tee -a /tmp/cdn-verify.log
import json, sys
d = json.loads(sys.argv[1])
checks = {
  "summary": bool(d.get("summary")),
  "baseStats": bool(d.get("baseStats")),
  "abilities": len(d.get("abilities") or []) > 0,
  "flavorEntries": len(d.get("flavorEntries") or []) > 0,
  "obtainLocationsByGame": bool(d.get("obtainLocationsByGame")),
  "moveSets": bool(d.get("moveSets")),
  "baseHappiness": d.get("baseHappiness") is not None,
  "captureRate": d.get("captureRate") is not None,
}
for k, v in checks.items():
    print(f"schema/{k}: {'OK' if v else 'MISSING'}")
PY

  local manifest
  manifest=$(curl -sS "${CDN}/bundle-manifest.json")
  local bv pc url
  bv=$(echo "$manifest" | python3 -c "import sys,json; print(json.load(sys.stdin).get('bundleVersion'))")
  pc=$(echo "$manifest" | python3 -c "import sys,json; print(json.load(sys.stdin).get('pokemonCount'))")
  url=$(echo "$manifest" | python3 -c "import sys,json; print(json.load(sys.stdin).get('archiveUrl'))")
  log "CDN manifest bundleVersion=${bv} pokemonCount=${pc} url=${url}"

  if [[ "$bv" == "5" && "$pc" == "1025" && "$url" == *"/v3/"* && "$ok" -ge $((total - 1)) ]]; then
    log "CDN-VERIFY 100.0% — all required assets online"
  else
    log "CDN-VERIFY incomplete — ${ok}/${total} endpoints OK"
    exit 1
  fi
}

main() {
  wait_build
  upload_bundle
  sleep 15
  verify_cdn
  log "CDN PIPELINE COMPLETE"
}

main "$@"
