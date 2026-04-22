# Runtime-smoke spec — the contract for `npm run validate`

**Factory-improvement #33** — every game's `npm run validate` MUST depend on a runtime-smoke step that executes the game's primary runtime entry and asserts a positive observable outcome. This is the gate that turned `build-green = feature-working` from hope into enforcement after arrow-puzzle PRs #125 + #126 both shipped green while completely broken.

The smoke runs in CI. It is NOT a bonus test — it is the **validation contract**.

## The four rules

Every runtime-smoke follows these, no exceptions:

1. **Call the runtime entry the player reaches.** If the player touches `generateLevel(N)`, smoke `generateLevel(N)`. Do not smoke `seedFromFixture(FAKE_TIER)` — that's a different code path, and a passing smoke on a different path is a false positive. Reference: arrow-puzzle PR #131 smoked `smokeFill(HAND_PICKED_TIER)`, shipped green, was broken on the real entry.
2. **Pass the runtime arguments.** If in production `getDifficulty(level)` decides the tier, let it decide in the smoke too. Hard-coded `'Moderate'` hides regressions at other tiers.
3. **Assert POSITIVE observable state, never the negation.** `screen.active === 'game'` is fine; `!menu.active` is forbidden — it passes during every screen transition and every error state. Reference: arrow-puzzle PR #139 asserted `!menu.active` and shipped with no game screen at all.
4. **If Node can't reach the runtime entry, promote to Playwright** on the built/preview URL. Do not invent a shim that satisfies the smoke in isolation — a shim that works in Node but not in the browser is the exact failure mode #33 prevents.

## Per-kind pattern

The runtime entry differs by game kind. Pick the pattern that matches:

### Single-player canvas/DOM game (arrow-puzzle, Bloxplode)

**Object-count + density assertions depend on what the game's "object" actually is.** Two patterns:

#### (a) Single-cell objects (one arrow = one cell)

If each game object occupies exactly one board cell, density `= objects / (width × height)` is meaningful and should approach the configured fill ratio for the tier.

```js
// scripts/smoke-runtime.js (Node-executable)
import { generateLevel, getDifficulty } from '../src/level/level-loader.js';

const level = 20;
const tier = getDifficulty(level);
const board = generateLevel(level, tier);

if (!board || !Array.isArray(board.arrows)) {
  console.error('smoke: generateLevel returned no board');
  process.exit(1);
}
if (board.arrows.length < EXPECTED_MIN) {  // tune per game's tier output
  console.error(`smoke: object count ${board.arrows.length} < ${EXPECTED_MIN} (generator regressed)`);
  process.exit(1);
}

const density = board.arrows.length / (board.width * board.height);
if (density < EXPECTED_DENSITY_FLOOR) {  // typically 0.85+ for fill-based generators
  console.error(`smoke: density ${density.toFixed(2)} < ${EXPECTED_DENSITY_FLOOR} (sparse/degenerate)`);
  process.exit(1);
}
```

#### (b) Multi-cell objects (snake-grower arrows, polyominoes, paths)

If each "object" occupies multiple cells (e.g. arrow-puzzle's snake-grower arrows have 2-8 segments each, Bloxplode's tetrominoes have 4 cells), `objects / (width × height)` underreports actual board fill. Use **segment-fill density** instead:

```js
// scripts/smoke-runtime.js — for multi-cell objects
const totalCells = board.width * board.height;
const filledCells = board.arrows.reduce((sum, a) => sum + a.segments.length, 0);
// (or whatever cell-count property the game's object has — count cells, not objects)

if (board.arrows.length < EXPECTED_OBJECT_COUNT_MIN) {
  // object-count regression guard
  console.error(`smoke: object count ${board.arrows.length} < ${EXPECTED_OBJECT_COUNT_MIN}`);
  process.exit(1);
}

const fillDensity = filledCells / totalCells;
if (fillDensity < EXPECTED_FILL_DENSITY) {
  // genuine "is the board mostly filled?" check — typically 0.85+ for dense levels
  console.error(`smoke: fill density ${fillDensity.toFixed(2)} < ${EXPECTED_FILL_DENSITY} (sparse/degenerate board)`);
  process.exit(1);
}

console.log(`smoke OK: L${level} (${tier}) ${board.arrows.length} objects / ${filledCells} cells / density ${fillDensity.toFixed(2)}`);
```

**How to tell which pattern applies:** does each object have an `arrowCount`/`length`/`segments` property > 1, or a `width × height` shape? If yes, use (b). Reference: arrow-puzzle PR #193 (issue #169) — first single-player smoke in the factory. Subagent had to deviate from this spec's pre-2026-04-22 single-formula version because the literal `arrows.length / (board.width * board.height)` returned 0.29 on snake-grower output, not the `>= 0.9` the spec asserted. Per-kind formula is now the canonical guidance.

### Multiplayer realtime game (house-mafia)

```js
// scripts/smoke-runtime.js
import { createRoom, joinRoom } from '../src/room.js';

const { code, connection } = await createRoom({ host: 'smoke-host' });

if (!/^[A-Z0-9]{6}$/.test(code)) {
  console.error(`smoke: invalid room code ${code}`);
  process.exit(1);
}
if (connection.readyState !== 1 /* OPEN */) {
  console.error(`smoke: websocket not open (readyState ${connection.readyState})`);
  process.exit(1);
}

// Positive assertion on the gameplay side: a joined client should see the host.
const joined = await joinRoom(code, { player: 'smoke-p2' });
if (!joined.players.includes('smoke-host')) {
  console.error('smoke: joined client cannot see host');
  process.exit(1);
}

console.log(`smoke OK: room ${code} created, host visible to joiner`);
connection.close();
```

### Bootable bundle + canvas rendering (stretch)

If the generator passes but the canvas never paints (see arrow-puzzle PR #126 which rendered zero arrows despite a valid generator), a second Playwright-based smoke catches it:

```js
// tests/e2e/smoke-boot.spec.js — already standard per templates/qa-assets/*/tests/e2e/smoke.spec.js
test('boot paints non-zero arrows', async ({ page }) => {
  await page.goto('/');
  await page.waitForSelector('#game.active', { timeout: 10_000 });
  const arrowCount = await page.evaluate(() => document.querySelectorAll('.arrow').length);
  expect(arrowCount).toBeGreaterThan(0);
});
```

## Wiring into `npm run validate`

Add to the game's `package.json`:

```json
{
  "scripts": {
    "smoke:runtime": "node scripts/smoke-runtime.js",
    "validate": "npm run smoke:runtime && npm run build && npm run test"
  }
}
```

Order matters — `smoke:runtime` runs FIRST because a broken runtime entry is the cheapest regression to catch and the most expensive to miss.

## What the smoke does NOT replace

- **Playwright e2e** (`templates/qa-assets/<game>/tests/e2e/smoke.spec.js`) — still runs on every PR via the `qa-agent.yml` workflow. The runtime-smoke is a cheaper check that runs locally and in `npm run validate`; Playwright is the browser-layer gate.
- **Unit tests** — still required for individual functions. The runtime-smoke is an **integration** gate, not a unit gate.
- **Ripon's device test** — still required. The smoke reduces the load on his review time, it doesn't eliminate it.

## Verification that the smoke actually catches regressions

Every runtime-smoke implementation PR MUST include a commit that demonstrates the smoke flips red when the runtime entry breaks:

1. Land the smoke passing on current main
2. In a local branch, introduce a simulated regression (e.g. `throw new Error()` in `generateLevel`)
3. Run `npm run validate` — it must exit non-zero with a clear error line
4. Revert the simulated regression
5. Re-run `npm run validate` — it must pass

Paste the before/after output in the PR description. The smoke is only worth shipping if it actually catches its target failure mode.

## Source

Filed from arrow-puzzle PRs #125 + #126 post-mortem. Brain rule encoded in CLAUDE.md Step 3 rule 11 on 2026-04-20. Per-game implementations filed as build-requests on each game repo.
