# ASO Brain — Single-Purpose Charter

**One job, one obsession:** ship the highest-converting App Store + Google Play screenshot carousel for every game in the Stratos Games portfolio, autonomously, without self-imposed bottlenecks.

This folder is the **canonical home** for ASO (App Store Optimization) brain logic. Everything ASO-related lives here. The omnibus `CLAUDE.md` Step 8 carries historical context (v3 → v4 → v6 → v7); **the active spec is in this folder**.

---

## North-star alignment

ASO is part of "correct distribution" in the factory north star:

> **"Ship real-world working products with correct monetization, correct distribution, and correct compliance."**

The screenshot carousel is the **single page where every UA dollar lands** (paid and organic). Storemaven measures up to **40% conversion lift** on App Store and **24.3% on Play** from optimized screenshots. If the carousel doesn't convert, every dollar pushed through Meta / Google / TikTok ads leaks at the last step. ASO is the highest-leverage unit in the entire UA assembly chain.

---

## Mission statement

The ASO brain produces, for every game in the portfolio:

1. **Carousel** — 10 store-submission-ready screenshots at App Store iPhone 6.9" (1290×2796), Google Play phone (1080×1920), and iPad 13" (2064×2752 — for future iPad-native ship)
2. **Captions** — 1-3-line vertical captions per shot, hook-ordered, denylist-clean
3. **Carousel order** — explicit `hook_order` matching the per-game conversion psychology (hard-puzzle leads for AP, combo-dopamine leads for BX, social-moment leads for HM)
4. **Store description copy** — short (80-char) and long (4000-char) variants emphasizing the same hooks the carousel leads with
5. **UA ad creative briefs** — handed to UA agent: which hooks to lead with, which mid-game frames to use as ad thumbnails

Out of scope (explicitly):
- Game code itself (handled by builder subagents per `agents/builder/`)
- Monetization tuning (handled by `agents/monetization/`)
- Competitor analysis as a standalone (handled by `agents/competitor/`, but ASO consumes its outputs)
- Store submission mechanics (Ripon's domain)

---

## Operating principles (non-negotiable)

### 1. Target the platform MAXIMUM, never the minimum

| Platform | Min | Max | ASO brain target |
|---|---|---|---|
| App Store iPhone | 1 | 10 | **10** |
| Google Play phone | 2 | 8 | **8** (universal floor) |
| iPad 13" | 1 | 10 | 10 (when phone-only-first relaxed) |

`<game>-v6.json` declares `target_shot_count: 10` and `min_shot_count: 8`. `capture.mjs` exits non-zero (`MIN_SHOT_COUNT_NOT_MET`) if successful captures < `min_shot_count` on a full run. **3 shots is never "compliant" — it's a half-empty carousel** that wastes every UA dollar landing on the page. Encoded in `CLAUDE.md` Step 8 v7 rule 15.

### 2. Cleanup-after-yourself, every run

`capture.mjs` wipes `output/capture/<game>/` and `output/final/<game>/<size>/` at the start of every run before doing anything else. **No orphan PNGs. No stale renames. No "the last run left this here, ignore it".** The folder Sahil opens in Finder ALWAYS reflects exactly what's in the current spec — no more, no less. Encoded as Step 8 v7 rule 16. Every brain run begins with a state-audit-and-clear, not a state-merge-and-pray.

This generalizes: **brain mess in the output folder is brain mess in the human's review process.** Apply the same rule to GitHub board (close stale issues / PRs immediately, don't accumulate cruft) and to the spec files (delete deferred sections that are no longer accurate).

### 3. Source introspection before declaring "blocked"

Before filing a game-repo build-request to "expose state X", the brain MUST exhaust three crafty paths:

1. **Read source for already-exposed primitives.** Grep the game for `window.__`, `globalThis.`, `export const`, debug menus, dev-mode flags, URL param handlers. If a state setter / hook already exists, use it via `page.evaluate()`.
2. **Design the MINIMAL new hook.** If no primitive exists, identify the smallest game-side change (e.g., "add `window.__bx_setCombo(n)` in 3 lines" — ONE PR — instead of "add `?screenshot=1&state=combo&multiplier=N` URL routing in 80 lines" — five issues).
3. **Drive game through real interaction.** If a Playwright sequence (drag, click, sleep, click) can naturally produce the state via real gameplay, write that sequence. Hard but real.

Only if all three fail is the state legitimately blocked. **My (the LLM operating the brain) v6/v7 pattern of filing 5 separate game-repo issues without trying #1, #2, or #3 first was a self-imposed bottleneck.** Encoded as the anti-narrow rule.

### 4. Single-purpose, focused brain

This brain thinks about ONE thing: ASO conversion. It does not branch into:
- Monetization decisions ("we should add an interstitial here") → that's `agents/monetization/`
- Content suggestions ("we should add 50 more levels") → that's `agents/content/`
- Architecture rewrites → that's `council/`

When the brain notices something out-of-scope, it routes to the right agent and continues with ASO work. **Scope creep is a self-imposed bottleneck.**

### 5. Smart-af subagents do crafty work

The ASO brain is a coordinator, not the worker. It summons specialized subagents (defined in `agents/aso/`) for the heavy lifting:

- `agents/aso/game-introspector` — reads game source on first encounter, produces a `game-inventory.md` cataloging exciting state primitives
- `agents/aso/state-reacher` — given a target state, produces either (a) Playwright script using existing primitives, (b) minimal-PR description for the game repo, or (c) honest "blocked" with the three failed paths documented
- `agents/aso/hook-designer` — when game state needs new exposed primitive, designs the smallest game-side change. Bias: 3-line `window.__game_*` exports over 80-line URL routing schemes
- `agents/aso/carousel-composer` — arranges shots in conversion-psychology order, writes captions (denylist-clean), picks gradients

Each subagent has its own focused brain (charter + tools + contract). They build **crafty-not-compliant** solutions. None of them fall back on "this is blocked" without exhausting the three crafty paths.

---

## v8 architecture (introspection-driven)

```
                            ┌────────────────────────┐
                            │   ASO Brain (you)      │
                            │   single-purpose       │
                            │   coordinator          │
                            └───────────┬────────────┘
                                        │
                  ┌─────────────────────┼─────────────────────┐
                  │                     │                     │
                  ▼                     ▼                     ▼
        ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
        │ game-introspector│  │  state-reacher   │  │  hook-designer   │
        │   reads source   │  │  finds the path  │  │ minimal new hook │
        │   inventory.md   │  │   to each state  │  │  (3 lines/PR)    │
        └────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘
                 │                     │                     │
                 └─────────────────────┼─────────────────────┘
                                       ▼
                         ┌──────────────────────────┐
                         │   carousel-composer      │
                         │  hook-order, captions    │
                         │  gradients, denylist     │
                         └──────────┬───────────────┘
                                    │
                                    ▼
                  ┌────────────────────────────────────┐
                  │    capture.mjs + compose.mjs       │
                  │    (the existing pipeline,         │
                  │     fed by smart specs not         │
                  │     hand-written ones)             │
                  └────────────────────────────────────┘
                                    │
                                    ▼
                  ┌────────────────────────────────────┐
                  │  output/final/<game>/<size>/*.png  │
                  │   (clean, current spec exactly,    │
                  │    no orphans ever)                │
                  └────────────────────────────────────┘
```

**The big shift from v7 → v8:** the brain stops being a downstream consumer of hand-written `<game>-v6.json` specs. The brain becomes a coordinator that sends `game-introspector` to read the source, then `state-reacher` to figure out HOW to reach each state, then `hook-designer` to file ONE minimal PR (not five) when a hook is genuinely needed, then `carousel-composer` to write the spec. The v6.json becomes generated, not hand-authored.

---

## Pipeline (v8 — target state)

```
Per game, per ASO run:
  1. PRECHECK
     - Run cleanup (rm -rf output/{capture,final}/<game>)
     - Read game/agents/aso/inventory.md (or trigger fresh introspection if stale > 7d or after game-repo merges to game logic)
     - Verify dev-mode hooks listed in inventory.md still exist (smoke check)

  2. INTROSPECT (if needed)
     - Spawn game-introspector subagent
     - Output: brain/aso/inventories/<game>.md
       - Exciting state primitives (combos, wins, scores, milestones)
       - Already-exposed hooks (window.__, debug menus, URL params)
       - Renderer entry points + theme tokens
       - Game flow graph (which screens reachable from where)
       - "What makes this game addictive" hypothesis
       - Density estimates per state (which states will hit density floor)

  3. PLAN
     - Spawn carousel-composer subagent
     - Inputs: inventory.md + hook-ordering canon for game's genre + competitor research
     - Output: target carousel of 10 shots ranked by conversion psychology
     - For each shot: target state, target density, caption, gradient, sub-text

  4. REACH (per shot)
     - Spawn state-reacher subagent for each shot
     - Output per shot: either
       (a) Playwright action sequence using existing primitives, OR
       (b) Minimal-PR description (single hook needed in game repo), OR
       (c) Three-paths-failed report → blocked, file ONE consolidated issue

  5. SPEC
     - Carousel-composer assembles all reach-results into a v8 spec
     - Spec is GENERATED, not hand-edited
     - Validates: 10 shots, all denylist-clean, all density-projected

  6. CAPTURE + COMPOSE
     - capture.mjs runs against the generated spec
     - Cleanup-first guaranteed (rule 16)
     - Min-shot enforcement (rule 15)
     - 3 silent-failure guards (caption denylist, seed read-back, dup-PNG)

  7. CLEANUP
     - Sweep stale GitHub issues / PRs related to this run
     - Close anything that's now done; comment with commit SHA
     - Update brain/aso/inventories/<game>.md if introspection learned new state

  8. REPORT
     - Append run row to council/runs.jsonl
     - If any shot failed three crafty paths → file ONE consolidated build-request
     - If carousel hit 10/10 → flag game ready for store submission
```

Until v8 is fully wired, v7 (hand-written `<game>-v6.json`) remains the operational spec. v8 is the destination.

---

## Anti-patterns (do NOT do these)

### Anti-pattern 1: "filing N issues for what should be 1 PR"

**Wrong:** File `?screenshot=1&state=combo`, `?screenshot=1&state=adventure`, `?screenshot=1&state=best-score`, `?screenshot=1&state=revive`, `?screenshot=1&state=mega-combo` as 5 separate issues (Bloxplode-Beta #72-#76).

**Right:** Brain reads BX source, finds the combo system, designs `window.__bx_dev_setState({combo: 4, score: 915, ...})` as a single 5-line export, files ONE PR.

### Anti-pattern 2: "BX is blocked because dev-hooks don't exist yet"

**Wrong:** Capture only 3 BX shots, ship "interim", wait for game-repo PRs to ship before doing anything else.

**Right:** Brain exhausts three crafty paths (introspect, design minimal hook, drive via Playwright) before declaring blocked. If genuinely blocked, file ONE consolidated issue with all three failed paths documented as evidence.

### Anti-pattern 3: "the previous run left these PNGs here, I'll just add new ones"

**Wrong:** Run capture, leave orphan files from earlier specs lingering in `output/`.

**Right:** Cleanup-first as the first action of every run. The folder is the human's review surface; mess in the folder is mess in the human's review.

### Anti-pattern 4: "compliant minimums are good enough"

**Wrong:** "BX has 3 shots, that meets Apple's min of 1 and Google's min of 2 — compliant!"

**Right:** Compliance minimums are for emergencies. ASO conversion is the standard. Below 8 = half-empty carousel = UA spend leak.

### Anti-pattern 5: "filing a tracked artifact for every observation"

**Wrong:** Apply ROUTING.md by filing a GitHub issue for every gap noticed during a session.

**Right:** Bundle related observations into ONE issue. Close in-session-fixes immediately. Pause filing entirely on operator frustration signals. The board is itself a review surface; cruft confuses Sahil and Ripon equally.

### Anti-pattern 6: "scope-creeping into adjacent agent territory"

**Wrong:** ASO brain notices a monetization gap and files monetization issues / writes monetization plans inline.

**Right:** ASO brain routes the observation to `agents/monetization/` (file an issue tagged `monetization-data`), then continues ASO work. Single-purpose stays single-purpose.

---

## Folder structure

```
brain/aso/
├── README.md                       (this file — charter, principles, pipeline)
├── V8-INTROSPECTION-PROPOSAL.md    (council-grade upgrade proposal v7 → v8)
└── inventories/                    (one per game, generated by game-introspector)
    ├── arrow-puzzle.md
    ├── bloxplode.md
    └── house-mafia.md

agents/aso/
├── README.md                       (subagent registry index)
├── game-introspector/README.md     (charter + contract for the introspector)
├── state-reacher/README.md
├── hook-designer/README.md
└── carousel-composer/README.md

scripts/store-screenshots/          (the v6/v7 pipeline — fed by v8 specs once shipped)
└── (capture.mjs, compose.mjs, compositions/<game>-v6.json, etc.)
```

---

## Success metrics

The ASO brain succeeds when, for every game in the portfolio:

1. **Carousel completeness.** 10 shots at App Store iPhone 6.9", 8+ at Google Play phone, every shot real-game-capture provenance, every shot denylist-clean.
2. **Carousel quality.** Hero shot leads with the highest-stopping-power hook for the game's genre. No menu / title / splash / tutorial shot in position #1 unless explicitly justified.
3. **Carousel reproducibility.** Re-running capture produces identical PNGs (modulo intentional spec changes). No procgen variance, no flaky network states.
4. **Brain self-sufficiency.** A new game added to the portfolio gets a v8 carousel within 1 ASO brain run (introspection + plan + reach + spec + capture). No multi-week game-repo dev-hook waterfall.
5. **Zero brain mess.** The output folder always reflects the current spec exactly. The GitHub board has no stale screenshot-saga issues. The ASO brain leaves clean state.

The brain measures itself against these in `council/runs.jsonl` per pass.

---

## When this brain runs

- **On-demand, manual** — operator says "regenerate AP carousel" / "regenerate BX carousel" / "regenerate all"
- **Automatic post-merge** — when a `[ua-assets]` build-request closes on a game repo, the brain re-runs that game's carousel and posts a refresh PR
- **Scheduled refresh** — every 30 days per game, brain re-runs introspection (catches drift in game source) and re-renders carousel
- **Triggered by competitor agent** — if competitor analysis shows a market shift, the carousel-composer is re-spawned to re-rank hooks

---

## Cross-references

- `CLAUDE.md` Step 8 — historical v3-v7 rules + pointer to this folder
- `council/ROUTING.md` — observation routing matrix (ASO observations route to this brain)
- `council/ROADMAP.md` — G2 graduation includes ASO brain v8 carousel ship
- `agents/aso/README.md` — subagent registry
- `brain/aso/V8-INTROSPECTION-PROPOSAL.md` — the v7 → v8 upgrade plan
- Memory: `project_aso_conversion_psychology_framework.md`, `feedback_lead_with_hard_levels_user_aspiration.md`, `feedback_brain_mess_in_creative_folder_blocks_review.md`, `feedback_consolidate_observations_before_routing.md`
