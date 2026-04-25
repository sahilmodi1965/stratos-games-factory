#!/usr/bin/env bash
# run.sh — one-shot: capture (Phase A) + compose (Phase B) for one game.
#
# Usage:
#   GAME_URL=http://localhost:5173/ bash scripts/store-screenshots/run.sh arrow-puzzle
#   GAME_URL=http://localhost:5173/ bash scripts/store-screenshots/run.sh arrow-puzzle --comps 1,2,5
#   GAME_URL=http://localhost:5173/ bash scripts/store-screenshots/run.sh arrow-puzzle --sizes ios-6.5
#
# The engine never starts the game's dev server. Start it yourself:
#   cd arrow-puzzle-testing/games/arrow-puzzle && npm run dev

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

if [[ $# -lt 1 ]]; then
  echo "usage: bash run.sh <game> [--comps a,b] [--sizes s1,s2]"; exit 1
fi
GAME="$1"; shift

CAPTURE_ARGS=("$GAME")
COMPOSE_ARGS=("$GAME")
while [[ $# -gt 0 ]]; do
  case "$1" in
    --comps) CAPTURE_ARGS+=("--comps" "$2"); COMPOSE_ARGS+=("--comps" "$2"); shift 2 ;;
    --sizes) COMPOSE_ARGS+=("--sizes" "$2"); shift 2 ;;
    --url)   CAPTURE_ARGS+=("--url" "$2"); shift 2 ;;
    *) echo "unknown arg: $1"; exit 2 ;;
  esac
done

if [[ ! -d node_modules/playwright ]]; then
  echo "[run.sh] installing engine deps (one-time)…"
  npm install --silent
fi
if [[ ! -d "$HOME/Library/Caches/ms-playwright" ]]; then
  echo "[run.sh] installing chromium (one-time)…"
  npx playwright install chromium
fi

echo "[run.sh] Phase A — capture"
node capture.mjs "${CAPTURE_ARGS[@]}"
echo "[run.sh] Phase B — compose"
node compose.mjs "${COMPOSE_ARGS[@]}"

echo "[run.sh] done. final → $DIR/output/final/$GAME/"
