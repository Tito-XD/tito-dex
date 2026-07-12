#!/usr/bin/env bash
# Report dex bundle build progress every 5% (based on details/*.json count).
set -euo pipefail

STAGING="${1:-/workspace/dist/dex-v5/staging/details}"
MAX_ID="${2:-1025}"
LOG="${3:-/tmp/dex-build.log}"
REPORT="${4:-/tmp/dex-build-progress.txt}"

mkdir -p "$(dirname "$REPORT")"
: > "$REPORT"

last_pct=-1
while true; do
  if [[ -d "$STAGING" ]]; then
    count=$(find "$STAGING" -maxdepth 1 -name '*.json' 2>/dev/null | wc -l | tr -d ' ')
  else
    count=0
  fi

  if [[ "$count" -ge "$MAX_ID" ]]; then
    pct=100
  else
    pct=$(( count * 100 / MAX_ID ))
  fi

  # Snap to 5% buckets for reporting
  bucket=$(( (pct / 5) * 5 ))
  if [[ "$bucket" -gt "$last_pct" ]]; then
    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    line="[$ts] BUILD ${bucket}% (${count}/${MAX_ID} species)"
    echo "$line" | tee -a "$REPORT"
    last_pct=$bucket
    if [[ "$bucket" -ge 100 ]]; then
      break
    fi
  fi

  # Also detect build finished via log
  if [[ -f "$LOG" ]] && grep -q "^Done\." "$LOG" 2>/dev/null; then
    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "[$ts] BUILD 100% (${MAX_ID}/${MAX_ID} species) — Done." | tee -a "$REPORT"
    break
  fi

  sleep 30
done
