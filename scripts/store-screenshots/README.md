# Store-screenshot generation engine

Two-phase pipeline that turns each game's `[ua] Store listing assets` issue
(Step 8 UA agent output) into submission-grade marketing screenshots for the
App Store and Play Store, with no manual capture.

Filed as factory-improvement #88 on `sahilmodi1965/stratos-games-factory`,
F1-milestone gate — see issue body for the spec this implements.

## Usage

```bash
# one-time install
cd scripts/store-screenshots && npm install && npx playwright install chromium

# generate everything for arrow-puzzle (assumes Vite dev server is running)
GAME_URL=http://localhost:5173/ bash scripts/store-screenshots/run.sh arrow-puzzle

# generate a subset — comps 1, 2, 5 only
GAME_URL=http://localhost:5173/ bash scripts/store-screenshots/run.sh arrow-puzzle --comps 1,2,5

# regenerate Phase B only (after editing template/marketing.html)
node scripts/store-screenshots/compose.mjs arrow-puzzle
```

The engine never starts the game's dev server itself — that's the operator's
job. AP and house-mafia both use Vite (`npm run dev` in each game repo);
Bloxplode runs from `www/` via any static server.

## Two phases

**Phase A — `capture.mjs`** boots headless Chromium at the game's native
viewport, drives it into each composition's deterministic state via
`localStorage` seeds + scripted clicks, and screenshots the rendered region.
Output: `output/raw/<game>/<comp-id>.png` (one file per composition).

**Phase B — `compose.mjs`** renders `template/marketing.html` at the target
device size (iOS 6.5" 1284×2778, Play 1080×2400) with the raw frame from
Phase A as the centerpiece, layered with caption + sub + brand gradient +
device frame + glow. Output: `output/final/<game>/<viewport>/<id>.png`.

## Compositions

Each game's compositions are declared as data in
`compositions/<game>.json` — id, caption, sub, gradient, save-state,
click sequence, target screen. The 10 comps per game come straight from the
game's `[ua]` issue (AP #206, BX #62, HM #12).

To add a new composition: add an entry to the JSON. No code changes needed.

## Output

- `output/raw/` — Phase A frames, gitignored
- `output/final/` — Phase B finals, gitignored (regenerable from raw)
- `output/hero/` — curated hero shots committed to the repo so Sahil + Ripon
  can review without running the engine. Updated by hand.

## Brain rules respected

- The engine never edits game code — only reads the deployed game via HTTP.
- It never holds state — each run starts from a fresh browser context.
- Game-specific state-injection lives in `compositions/<game>.json`, not in
  branching `if (game === '...')` code. Add a game = add a JSON file.
