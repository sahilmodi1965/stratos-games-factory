# `state-reacher` subagent

**One job:** Given a target marketing state for a captured shot, produce ONE of three things:
- (a) **Playwright action sequence** that drives the live game to the state using already-exposed primitives
- (b) **Minimal-PR proposal** when no existing primitive reaches the state, naming the smallest game-side change needed
- (c) **Three-paths-failed report** when nothing crafty works, with evidence

**Output:** `brain/aso/reach-results/<game>/<shot-id>.md` (transient — cleaned each ASO brain run)

**Charter scope:** Reads inventory + game source. May execute Playwright probes to verify a sequence works. Never modifies game code. Never files game-repo issues directly (passes (b) results to `hook-designer` for that).

---

## Trigger conditions

`carousel-composer` plans a 10-shot carousel and needs reach paths for each. The brain dispatches one `state-reacher` invocation per shot.

## Inputs

- `game_name`, `game_inventory_path` (`brain/aso/inventories/<game>.md`)
- `target_state` — JSON describing the desired marketing state, e.g.
  ```json
  {
    "id": "01-classic-combo-x4",
    "screen": "classic-game",
    "post_conditions": {
      "combo_multiplier": 4,
      "score_at_least": 800,
      "particles_visible": true,
      "hud_visible": true
    },
    "viewport": {"width": 414, "height": 896},
    "url_base": "http://localhost:8765/classic/index.html"
  }
  ```

## Tools

Read, Bash (Playwright invocation only — for probes), Write (output reach-result file).

**Forbidden:** Edit (game source), gh CLI, Glob/Grep on the game repo (use the inventory — that's why it exists).

---

## The three crafty paths (in order)

### Path 1 — Use existing primitives

Read inventory's "Already-exposed dev hooks" section. Match against `target_state.post_conditions`. If a hook covers the state, write a Playwright sequence:

```js
await page.goto('http://localhost:8765/classic/index.html');
await page.waitForFunction(() => window.__bx_dev != null);
await page.evaluate(() => window.__bx_dev.setState({combo: 4, score: 815, particles: true}));
await page.waitForSelector('.combo-overlay.visible');
await page.screenshot({...});
```

Output result type (a) with the sequence as JSON-serializable actions matching `capture.mjs`'s action schema.

### Path 2 — Propose minimal new hook

If inventory's hooks don't cover the state, but inventory's "state primitives" + "renderer entry points" suggest a clear minimum-viable addition (e.g., "combo state lives in `src/classic/combo.js`, expose a setter"), output result type (b):

```yaml
proposal:
  game: bloxplode
  hook_name: window.__bx_dev.setState
  file: src/dev-hooks.js (new)
  estimated_lines: 8
  build_gating: import.meta.env.DEV
  states_unlocked: [classic-combo-x4, mega-combo-x8, best-score-celebration, revive-countdown, adventure-themed-mid]
  diff_sketch: |
    // src/dev-hooks.js
    if (import.meta.env.DEV) {
      import('./classic/combo.js').then(({setComboMultiplier}) => {
        import('./classic/score.js').then(({setScore, setBest}) => {
          window.__bx_dev = {
            setState({combo, score, best, ...}) {
              setComboMultiplier(combo);
              setScore(score);
              setBest(best);
            }
          };
        });
      });
    }
  smoke_test_required: yes
  consolidates_existing_issues: [Bloxplode-Beta#72, #73, #74, #75, #76]
```

### Path 3 — Drive via real interaction

If neither hook exists nor minimal addition is reasonable (e.g., game logic depends on async server-side state), attempt to drive the game through real interaction. For BX combos: drag and drop blocks via Playwright `page.mouse.move/down/up` to construct a board state that triggers a chain when the next placement clears multiple lines.

This is fragile and slow but real. Use as last resort. Output result type (a) with the interaction sequence + a confidence score (high/medium/low) and a `flaky_warning` flag if the sequence depends on timing.

### Result type (c) — three-paths-failed

If all three fail, output an honest report:

```yaml
status: blocked
target_state: {...}
paths_tried:
  - path_1_existing_primitives:
      reason_failed: "no hook in inventory matches post_conditions {revive_countdown}"
  - path_2_minimal_hook:
      reason_failed: "revive flow lives in compiled WASM module; no JS-callable setter"
  - path_3_real_interaction:
      reason_failed: "revive only triggers after losing all lives; would require ~3 minute scripted full play-through, too flaky for CI"
recommendation: "feature this game as 9-shot carousel; revive shot deferred until WASM debug build or a manual-capture override path"
```

---

## Operating procedure

1. **Read inventory** (`brain/aso/inventories/<game>.md`) — DO NOT re-grep the game source. The inventory is the source of truth.
2. **Match target_state.post_conditions against inventory's hooks.** If match → Path 1.
3. **If no match,** check inventory's "Minimal hooks brain proposes adding" — if a proposed hook covers it, output Path 2 referencing the proposal.
4. **If no proposal exists,** check inventory's state primitives — can a new hook be designed that covers this state? If yes, output Path 2 with a fresh proposal.
5. **If no hook is reasonable,** check whether real interaction can produce the state — read inventory's game flow graph + identify the sequence of inputs.
6. **If interaction is feasible** but slow/flaky → output Path 3 (a) with confidence flag.
7. **If nothing works** → output (c) with three-paths-failed evidence.
8. **Probe (optional):** for Path 1 results, you MAY launch a quick Playwright probe to confirm the sequence works before declaring success. For Path 3 results, you SHOULD probe.

## Anti-patterns

- **Skipping path 1 to file a "blocked" report.** This was the v6/v7 brain pattern — it cost the project five separate game-repo issues. Always try path 1.
- **Skipping path 2 to fall to path 3.** A 5-line hook is better than a 50-line drag-drop sequence. Always try path 2.
- **Modifying game code.** You output proposals. `hook-designer` reviews and refines. Sahil approves. Builder ships. Stay in your lane.
- **Re-grepping game source.** The inventory exists so you don't have to. If the inventory is stale or wrong, that's `game-introspector`'s problem; signal it via your output and don't fix it yourself.
- **Producing a Path 1 result without verifying it works.** A sequence that "looks right" but breaks at runtime wastes the next subagent's time. Probe.

## Self-cleanup before exit

- Delete any Playwright probe artifacts (screenshots, traces) created during verification
- Confirm output is a single markdown file at `brain/aso/reach-results/<game>/<shot-id>.md`
- Append one-line summary: `reach-result: <shot-id> → path-<1|2|3> (confidence: <high|med|low>)`

## Example invocation

```
Agent({
  subagent_type: "general-purpose",
  description: "Reach BX classic-combo-x4 for ASO",
  prompt: "Read agents/aso/state-reacher/README.md as your charter. Read brain/aso/inventories/bloxplode.md. Reach target state: classic-combo-x4 with score >= 815, particles visible. Write reach-result to brain/aso/reach-results/bloxplode/01-classic-combo-x4.md. Report under 100 words."
})
```
