#!/usr/bin/env bash
# Regenerates design/sketches/*.png from prototype.html with headless Chrome.
# Usage: design/capture.sh [output-dir]
set -euo pipefail

cd "$(dirname "$0")/.."
OUT="${1:-design/sketches}"
PORT="${PORT:-8765}"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
PROFILE="$(mktemp -d)"
mkdir -p "$OUT"

python3 -m http.server "$PORT" --bind 127.0.0.1 >/dev/null 2>&1 &
SERVER=$!
trap 'kill $SERVER 2>/dev/null; rm -rf "$PROFILE"' EXIT
sleep 1

BASE="http://127.0.0.1:$PORT/design/prototype.html?shot=1&time=21:37"

# Headless Chrome can stay alive after writing the file, so each shot is time-boxed.
shot() {
  local name="$1" size="$2" query="$3"
  rm -f "$OUT/$name.png"
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=2 \
    --user-data-dir="$PROFILE/$name" --window-size="$size" --virtual-time-budget=1500 \
    --screenshot="$OUT/$name.png" "$BASE&$query" >/dev/null 2>&1 &
  local pid=$!
  for _ in $(seq 1 40); do
    [ -s "$OUT/$name.png" ] && break
    sleep 0.25
  done
  sleep 0.3
  kill "$pid" 2>/dev/null || true
  [ -s "$OUT/$name.png" ] && echo "ok   $name" || echo "FAIL $name"
}

SQ=480,480
LAND=800,450
shot home-journal   $SQ   "theme=journal"
shot home-plastic   $SQ   "theme=plastic&wall=dusk"
shot home-flat      $SQ   "theme=flat&wall=coast"
shot home-photo     $SQ   "theme=journal&wall=photo&reveal=.7"
shot home-panel     $SQ   "theme=journal&tpl=panel"
shot home-quiet     $SQ   "theme=plastic&tpl=quiet"
shot home-pad       $SQ   "theme=journal&input=pad"
shot coach          $SQ   "theme=journal&view=coach"
shot shelf-menu     $SQ   "theme=journal&view=pop"
shot trainer-edit   $SQ   "theme=flat&wall=coast&view=trainer"
shot library        $SQ   "theme=journal&view=lib"
shot library-search $SQ   "theme=plastic&wall=dusk&view=search"
shot picker         $SQ   "theme=flat&view=picker"
shot edit-layout    $SQ   "theme=journal&view=edit&sel=shelf"
shot edit-look      $SQ   "theme=plastic&wall=dusk&view=look"
shot edit-wall      $SQ   "theme=flat&wall=coast&view=wall"
shot settings       $SQ   "theme=journal&view=settings"
shot land-home      $LAND "orient=land&theme=flat&wall=coast"
shot land-edit      $LAND "orient=land&theme=journal&view=edit&sel=trainer"
shot land-look      $LAND "orient=land&theme=plastic&wall=dusk&view=look"
