# CLAUDE.md — Stratos Games Factory

The brain of the Stratos Games autonomous build factory. If you are an AI agent (Claude Code, a subagent, etc.), this file is the source of truth for *how this repo operates*. Read it before doing anything.

Humans should start at `README.md`, then come here.

## What this repo is

Stratos Games Factory is a **meta-repo**. It does not ship a game. It is the autonomous build pipeline that turns human play-test feedback into shipped game changes for every game in the Stratos Games portfolio.

The model:

> **Humans test and document. Machines build. Humans review and ship.**

A human (Ripon) plays a game, finds something to fix or improve, and files a GitHub Issue against the *game* repo with the `build-request` label. Sahil opens Claude Code in this directory and says **"go"**. The swarm assesses what needs doing, builds every pending issue, generates content ideas, scans the competition, reviews the week — then reports what it did. Sahil reviews PRs and merges.

## Game portfolio

Currently operated on by the factory:

| Game | Repo | Kind | Status |
|---|---|---|---|
| Arrow Puzzle | `mody-sahariar1/arrow-puzzle-testing` | Vanilla JS + Vite, GitHub Pages | live |
| Bloxplode | `mody-sahariar1/Bloxplode-Beta` | Capacitor (web → Android), `www/` | beta |
| House Mafia | `sahilmodi1965/house-mafia` | Vanilla JS + Vite + Supabase Realtime, GitHub Pages | dev |

Adding a new game is a one-shot: `bash scripts/add-game.sh owner/repo "description"`.

---

## Swarm operating principle: issues first, code second

The swarm NEVER writes code directly from a conversation prompt. Every code change must trace to a GitHub issue.

### When Sahil shares feedback, ideas, or bugs in conversation:
1. Parse them into structured issues
2. Determine the target: stratos-games-factory (engine/architecture) or a specific game repo
3. File each as a GitHub issue with the appropriate label (build-request, factory-improvement, market-intel, etc.)
4. Show Sahil the filed issues for confirmation
5. DO NOT start building until Sahil says "go"

### When Sahil says "go":
1. Show the full queue: all open build-request issues across all games, grouped by repo
2. Show recommended priority order (bugs first, then features by dependency)
3. Wait for Sahil to confirm the queue or adjust priority
4. Only then start building — from issues, never from conversation

### When Sahil says "go" with a specific scope:
- "go arrow-puzzle" — show + build only Arrow Puzzle issues
- "go house-mafia #2-5" — build specific issues
- "go all" — show everything, build everything after confirmation

### What goes where:
- Game bugs, features, content, levels → issue on the game repo
- Factory architecture, agent improvements, workflow fixes → issue on stratos-games-factory
- Monetization, UA, product analysis → issue on the relevant game repo with specialized label

### Swarm-state notes (a special kind of issue)

When the swarm discovers an operational state worth remembering across sessions — a merge bottleneck, a paused initiative, a broken pipeline, a deferred decision, anything the next "go" needs to know about before redoing the same analysis — file it as an issue on `sahilmodi1965/stratos-games-factory` with the `swarm-state` label. These are NOT build requests. They are persistent messages the swarm leaves for its future self.

Every `swarm-state` issue MUST include:
- **Filed:** ISO date so staleness is obvious
- **Why this issue exists:** what the swarm noticed and the analysis behind it
- **When to close:** explicit criteria so future swarm runs (or Sahil) know when the note has served its purpose and can be closed

The swarm checks for open `swarm-state` issues at the start of every Step 1 assess pass and surfaces them before doing any other work. The pattern lets the swarm coordinate with itself across sessions without polluting game-level `build-request` queues, memory files, or this CLAUDE.md.

### The rule that cannot be broken:
If there is no GitHub issue, there is no code change. Period. Every PR references an issue number. Every commit message includes #issue. The GitHub issue tracker IS the project plan.

---

## North star and milestone gate

### The north star

**Ship real-world working products with correct monetization, correct distribution, and correct compliance.** Not "merge PRs faster". Not "build more features". Real games in real users' hands, on real stores, with ads serving, listings polished, and compliance handled.

The north star has **veto authority over every other rule in this file**, including the milestone shape itself. If a milestone, an agent, a validator, or any swarm decision works against the north star, the north star wins. Everything else is up for revision; the north star is not.

### Current milestone

The factory is always in exactly one F-milestone at a time. The current milestone is recorded in `council/MILESTONE` — a single-line file. Read it at the start of every `go`. State it aloud in your first response.

The milestones are defined in detail in `council/ROADMAP.md`:

- **F1** — One real game, fully shipped (multi-format web+iOS+Android, ads, UA, compliance, real users)
- **F2** — Multiple games on the same cycle, each measurably better than the last
- **F3** — Cadence: one shippable game per week
- **F4** — Portfolio scale: five new games per week

Per-game progression is tracked on the G-series (G1 foundation → G5 cadence on autopilot), also defined in `council/ROADMAP.md` and tracked as GitHub milestones on each game repo.

### The milestone gate (binding rule)

In Step 2 prioritization, **filter every issue by its milestone label before any agent fires**. An issue tagged with a future milestone is invisible to the swarm. It does not get built. It does not get planned. It does not get listed. It sits untouched, no matter how appealing or "easy" or tempting.

This is the rule that prevents drift toward shiny F4 work (federated MCP, multi-harness adapters, genre packs) while F1 (an actual shipped game) is incomplete. Most of the architectural backlog is F4. **None of it gets built until F1 is closed.**

Issues without a milestone label are **unmilestoned** — review them in Step 1 and either tag them with a milestone or close them. Never build unmilestoned issues; that is how drift starts.

### The self-improvement debt clause

A milestone is **not complete** when its outcome holds. A milestone is complete when:

1. The outcome holds (the one-sentence verifiable test in `council/ROADMAP.md` passes), **AND**
2. Every gap that surfaced reaching it has been encoded as a permanent factory capability — brain shard, CLAUDE.md rule, council entry, validator, agent prompt, smoke test. **Tribal memory does not count.**

Without (2), the factory ships the milestone, learns ten things, forgets nine of them by the next milestone, and rebuilds them from scratch. The clause is the mechanism that makes the factory monotonically better.

### Council authority over milestone shape

The council (Step 9 weekly review or a manual `re-shape milestones` invocation) **MAY** re-order, rename, split, or merge milestones — but **ONLY** if doing so moves the factory closer to the north star. The council **MAY NOT** change the north star itself. If a re-shape happens, update `council/ROADMAP.md` and `council/MILESTONE` in the same commit, log it as a `swarm-state` note, and surface it at the top of the next `go`.

---

## Observation routing — every gap becomes a tracked artifact

**Every agent follows the routing matrix in [`council/ROUTING.md`](council/ROUTING.md) when it observes a problem the factory should fix or remember. Never let an observation die in conversation.** Produce a tracked artifact, every time.

The matrix maps observation types to destinations: game bug → game issue (G-milestone) · factory gap → factory-improvement issue (F-milestone) · persistent state → swarm-state note · behavioral lesson → memory file · metric regression → council + factory-improvement.

Read `council/ROUTING.md` for the full matrix and enforcement principles. This rule binds every agent — main thread, builder subagent, inline agents, council. The Step 3 subagent prompt template enforces it explicitly (rule 8); Steps 4-8 inline agents enforce it via their "Observation routing — mandatory" rule; Step 9 council converts insights into tracked artifacts per entry type; Step 10 audits routing before logging the pass.

This is the single mechanism that makes the factory self-learning without requiring an orchestrator agent.

---

## Brain-vs-game arbitration (factory-improvement #48)

Every pass faces a tradeoff: invest tool budget in a brain edit (slow now, fast forever) or ship game work (slow each time, no compounding). Prior to this rule, the tradeoff was made by per-pass agent instinct with no audit trail. This section makes the decision explicit, logged, and monitored.

### The decision tree

At the start of Step 3 builder prioritization — BEFORE any game work or factory-improvement build — walk this tree and pick the first branch that matches:

1. **Is there an unencoded F1 gap from the prior pass?** Check `factory_delta` in the last 3 `runs.jsonl` rows for `factory_issues_filed` entries that are NOT also in `brain_edits` or `memory_writes`. If an issue was filed but never encoded into CLAUDE.md / memory, it is in an unencoded state. **Encode it now, before any game build**, even if the rule is small. Log the edit in this pass's `brain_edits`.

2. **Did the prior pass ship game work that requires a new brain rule to not regress?** Examples: the polish PR shipped a CSS tunables convention (brain must encode "all visual knobs go in tunables file"); a structure PR shipped without a smoke (brain must encode "structure PRs must ship with a smoke"); a feature shipped without a wayfinding element (brain must encode the wayfinding stub rule). If yes, encode the rule now, even if it's small. Log in `brain_edits`.

3. **Is there an open factory-improvement issue tagged F1 that would save >30 minutes per future pass?** This is the compounding-ROI check. A brain edit that saves 30 minutes × 50 future passes = 25 hours of recovered context. Compare against the single-shot ROI of shipping one game PR. If the factory-improvement wins, build it now. Log in `brain_edits` + `factory_issues_closed`.

4. **Are there open game build-requests in the F1 milestone gate?** Build them in the order the existing Step 3 prioritization specifies. This is the default branch for most passes once brain debt is current.

5. **No game work pending either?** Run the inline agents (Steps 4-8) and council (Step 9). Use the pass for review work that Step 9 would do anyway.

**Log the decision in this pass's `runs.jsonl` row** with two new fields:
- `arbitration_decision`: one of `"brain"`, `"game"`, `"mixed"`, `"review"`
- `arbitration_reason`: one sentence naming the branch that matched and why

### Healthy brain:game ratio

Over the last 50 passes (weekly review window), a healthy F1 cycle runs **20-30% brain work, 70-80% game work**. The Step 9 council reads `arbitration_decision` across the window and reports:
- `<15% brain` → council files a factory-improvement noting the factory may be shipping without encoding (the self-improvement debt clause is leaking).
- `>40% brain` → council files a factory-improvement noting the factory may be refactoring instead of shipping (the F4-trap — building the factory while F1 slips).
- `15-40%` → healthy, no action.

The council's job is to detect drift in either direction before it shows up in F1 progress. Persistent imbalance is a leading indicator of misaligned arbitration, not a lagging indicator of missed milestones.

### Why this rule exists

Today's arbitration is implicit: milestone gate pressure (both compete equally), self-improvement debt clause (forced encoding at milestone-end, not per-pass), and per-pass agent judgment (instinct). The gap: filing a tracked artifact is enforced, **encoding the rule is not**. A session can ship 5 game PRs, route 5 observations, and end with zero brain work — and the current `factory_delta` accounting can't tell whether that was the right tradeoff or whether the factory is drifting. This rule makes the decision visible per pass, logged for audit, and aggregated weekly for drift detection.

---

## Swarm mode

This is the primary way to operate the factory. When Sahil opens Claude Code in this directory and says **"go"**, **"run the swarm"**, **"what needs doing"**, or similar — you ARE the swarm. You do not invoke `claude -p`. You do not run shell scripts. You are the autonomous build factory.

### Step 1 — Assess state

Run the dashboard:

```bash
bash scripts/status.sh
```

`status.sh` is the single source of truth for the factory's operational state. It reads `daemon/config.sh` for the game list, pulls swarm-state notes, PR backlogs, pending build-requests, stuck `building` labels, agent freshness, council recency, and outputs a structured view plus a **suggested focus** line. It also auto-detects paused games from swarm-state notes (any note whose body mentions a game and the word "paused"/"dormant") and skips them.

**Do not re-run the raw `gh issue list` / `gh pr list` loops that `status.sh` replaces.** If the script fails, fix it — do not fall back to 12 ad-hoc `gh` calls, that is how issues get missed (see issue #25 for why).

**After running `status.sh`, surface to Sahil:**

1. Any open swarm-state notes, with the "When to close" criteria from each body — ask whether to act on them, work around them, or proceed normally. **Do not silently re-run analysis a swarm-state note already documents** — that is the entire point of the pattern.
2. The dashboard output verbatim (the dashboard already has the structure Sahil expects).
3. Your own recommended action plan on top of the suggested-focus line (which agents to run, in what order, whether to drain a backlog first).

Paused games shown as `⏸ PAUSED` in the dashboard MUST be skipped in Steps 2–9. They count as state-only reads, not action targets.

**Feedback loop — every "go" verifies the previous "go" left the factory healthy:**

After running `status.sh`, read the last 3 rows of `council/runs.jsonl` and surface them to Sahil as a mini health check:

```bash
tail -3 council/runs.jsonl 2>/dev/null | jq -r '"  \(.ts | split("T")[0]) \(.scope // "all") — \(.games | to_entries | map("\(.key):\(.value.prs)p/\(.value.issues)i") | join(" ")) notes=\(.notes // "")"' || echo "  (no prior runs logged)"
```

Report these three rows at the top of your state summary as **"Prior runs"** — this is the swarm's self-check:

- If `runs.jsonl` is empty → this is the first structured-log run, note it and move on.
- If the latest row is from > 7 days ago → flag it; the swarm has been idle.
- If a row says `"failed":` with a non-zero number → surface the failure before doing new work; don't silently re-attempt.
- If a row's `notes` mentions `decomposition rule fired` → confirm on the next pass that the split-issues produced PRs; don't lose track.

Sahil does not review PRs on the factory repo — this feedback loop is how drift becomes visible without code review. **Do not skip this.** If the loop itself is broken (e.g., `runs.jsonl` missing), that IS the signal that something regressed — report it loudly.

**Read the current milestone:**

```bash
cat council/MILESTONE 2>/dev/null || echo "UNDECLARED"
```

State the current milestone aloud at the top of your assess summary, alongside the north-star statement: *"Factory is in F1 — ship one real game across web/iOS/Android with ads, UA, and compliance."* If `MILESTONE` is missing or returns `UNDECLARED`, **stop the swarm** and ask Sahil to declare a milestone before any other work. The milestone gate (Step 2) cannot run without a declared milestone.

**Check council staleness — ALWAYS, even on scoped passes:**

```bash
find council/COUNCIL.md -mtime +7 -print 2>/dev/null | grep -q . && echo "STALE" || echo "fresh"
```

If `COUNCIL.md` is >7 days old, **Step 9 council review is mandatory this pass and runs FIRST, before Step 2**, regardless of scope. The self-learning loop cannot lie dormant — if the council has not distilled `runs.jsonl` into lessons in over a week, the next pass MUST run it before anything else. This prevents the factory from forgetting what it learned.

If `COUNCIL.md` is fresh (<7 days), Step 9 fires only at its normal Step 2 priority. Surface the staleness state in your assess summary (e.g., `council: 4 days old (fresh)` or `council: 12 days STALE — running Step 9 first`).

### Step 2 — Prioritize

**Apply the milestone gate before ranking agents.** For the factory repo and every game repo, fetch open issues and filter to those whose milestone matches the current `council/MILESTONE` value, OR which carry no milestone at all. Issues tagged with future milestones (e.g. F2/F3/F4 when current is F1, or G3/G4/G5 when the game's pointer is at G1) are **invisible** to this pass — do not list them, do not build them, do not plan around them.

**Tagging is mandatory, not optional.** If an unmilestoned issue is encountered, **tag it before any build action** using the quick reference below. Issues with no milestone are not buildable — and any new issue the swarm files during the pass MUST include `--milestone <name>` on `gh issue create`. Never file or build unmilestoned. That is how drift starts.

The milestone gate is the rule that keeps the factory on the north star. F4-class work (federated MCP, multi-harness, genre packs) is forbidden until F1 closes — no matter how appealing.

**Milestone definitions live in `council/ROADMAP.md`.** Quick decision rule: bias to the **earliest** milestone when unclear (G1 over G2, F1 over F2) — earlier milestones are the gate; later ones wait. Swarm-state notes (label `swarm-state`) do not need a milestone.

Work in this order (highest priority first):

1. **BUILDER** — always first. Process any open `build-request` issues not already labeled `building` or `done`.
2. **PRODUCT** — if there are open `analytics-data` issues from Ripon, or no `product-data` issues filed in the past 7 days, analyze player data and file improvement issues.
3. **MONETIZATION** — if no `monetization-data` issues filed in the past 7 days, review ad placement and file optimization issues.
4. **CONTENT** — if no `content-agent` issues filed in the past 7 days, generate new content ideas.
5. **COMPETITOR** — if no `market-intel` issues filed in the past 7 days, scan the market.
6. **UA** — if a `ship-it` label was recently applied, or if no `ua-assets` issues filed in the past 30 days, generate store listing assets.
7. **COUNCIL** — if no council review commit in the past 7 days, review the week.

Skip any agent whose work is already fresh. If there's nothing to do, say so.

### Step 3 — Builder agent

For each open `build-request` issue (up to 5 per session to avoid context exhaustion):

**Decomposition rule — split structure vs polish before building.** An issue contains **mechanical** work (levels, save keys, controllers, config, game logic — text-specifiable) and/or **subjective** work (pixel placement, rotation angles, timing curves, copy tone — needs human eye). If it contains both, split before building. This exists to stop the tutorial saga (arrow-puzzle PRs #75/#80/#85 all closed because mechanical scaffolding was bundled with visual polish the human eye rejected).

**Detection heuristic.** Split if body contains mechanical markers (`save.set`, `level`, `src/` paths) AND >2 subjective markers (`rotate(`, `transform`, `padding`, `animation`, `ease`, "feel", "looks", "polish", "aspect ratio", "instead of X use Y"). **Never split wiring-heavy issues** — mechanical half modifying `boot()`/`init()`/`tick()`/`render()`, or adding a dep to a file already on the boot path. The polish split cannot isolate wiring risk. Build one-shot with a boot-smoke asserting a canonical post-boot entity renders (e.g. `.arrow` pixels).

**Split procedure.** File `[structure] <title>` (mechanical) + `[polish] <title>` (subjective, using `templates/polish-pr-body.md` with CSS-variable tunables per factory-improvement #27, **never closed-and-refiled**). Comment on original linking both, close as superseded. Build `[structure]` this pass; leave `[polish]` for next. Record `"decomposition_rule_fired":[{"original":<N>,"structure":<N1>,"polish":<N2>,"smoked":<bool>}]` in `runs.jsonl` — `smoked:false` is the council-flagged wiring-gap failure mode.

**Before the subagent:**
1. Parse the game's config from `daemon/config.sh` to get: `owner/repo`, `local_dir`, `default_branch`, `build_cmd`, `forbidden_paths`.
2. Label the issue `building`: `gh issue edit <N> --repo <owner/repo> --add-label building`
3. Prepare the game repo:
   ```bash
   cd ~/stratos-games-factory/<local_dir>/
   git fetch origin <default_branch>
   git checkout <default_branch>
   git reset --hard origin/<default_branch>
   git clean -fd
   ```
4. Create the branch: `git checkout -b auto/<game>-issue-<N>-$(date +%s)`

**Spawn a subagent** using the Agent tool with this prompt template:
```
You are working in the game repo at /Users/sahilmodi/stratos-games-factory/<local_dir>/.
You are on branch auto/<game>-issue-<N>-<timestamp>.

Implement this GitHub issue:
  Repo: <owner/repo>
  Issue: #<N>
  Title: <title>
  Body: <body>

RULES:
1. Read CLAUDE.md in this repo FIRST. Follow its rules exactly.
2. Only do what the issue asks. No bonus refactors or cleanups.
3. Conventional commits, reference the issue: "fix: description #<N>"
4. Do NOT edit these paths: <forbidden_paths from config.sh, comma-separated>
5. <if build_cmd is non-empty>: Run "<build_cmd>" as final step. Fix until it passes.
   <if build_cmd is empty>: No build step for this game. Just verify your changes are correct.
6. If you cannot implement safely, make no changes and explain why.
7. End with one paragraph summarizing what you changed.
8. **Observation routing — mandatory.** If during your work you observe any factory gap, missing capability, broken validator, or behavioral lesson the factory should remember, file it as the appropriate tracked artifact BEFORE ending. Read the routing matrix at `/Users/sahilmodi/stratos-games-factory/council/ROUTING.md` — it maps observation types to destinations (game issue / factory-improvement / swarm-state / memory). **Never let an observation die in your summary text.** Include the routed artifact URLs in your final summary.
9. **Smoke-test runtime fidelity (factory-improvement #43).** If your work adds or modifies any test (Playwright, Vitest, validate-script smoke, anything), the test MUST: (a) call the same runtime entry point the player reaches — `generateLevel(N)` not `smokeFill(HAND_PICKED_TIER)`, the real `boot()` path not a synthetic helper; (b) pass the same arguments the runtime uses — let `getDifficulty(level)` decide the tier, not a hard-coded `DIFFICULTY.find(t => t.label === 'Moderate')`; (c) assert the *positive* state that should exist (`#screen-game.classList.contains('active')`, arrow-pixel count > 400, `result.arrowCount` inside an observed band), NEVER the negation of what should not exist (`!menu.classList.contains('active')` is forbidden — it false-positives on every screen transition). If your test cannot reach the runtime entry point from a Node harness, promote it to Playwright and open the live URL — do not write a partial-signature helper smoke. The 2026-04-15 #131 + #139 dual regression is the canonical failure this rule prevents: both smokes were green; both PRs shipped broken because both tests were one step removed from the player's path.
10. **Wayfinding stub for user-facing `[structure]` PRs (factory-improvement #44).** If the issue you are building is the `[structure]` half of a decomposed user-facing feature (tutorial, onboarding, cutscene, level intro, win/lose screen, settings flow, first-launch UX) — detected by your work touching `startX()`, `showY()`, `screens.show(...)`, screen-manager calls, or controller-flow for a user-facing surface — you MUST add a plain DOM text element with a dedicated CSS class (e.g., `.wayfinding-banner`, `.tutorial-step-label`) that identifies the feature unambiguously to a human observer. Examples: `Tutorial 1/3 — tap the highlighted arrow`, `Loading next level…`, `You win!`. The wayfinding element is a plain `<div>` or `<span>` with text content (NOT canvas, NOT an image), positioned visibly inside the active screen, independent of any sibling polish PR — if the polish PR's hand overlay or animation breaks, the wayfinding element must still render. The sibling `[polish]` PR replaces or restyles it via the CSS tunables file. **Forbidden antipattern:** activating a user-facing feature with zero on-screen text on the reasoning that "the polish PR will add the UI" — the polish PR may never land, the structure PR may sit on main for hours or days looking broken, and Ripon will conclude the game itself is broken (arrow-puzzle #139 was exactly this — tutorial boot gate re-enabled with no visual signal, users saw sparse boards and concluded the generator was broken when the tutorial was actually running correctly).
```

**After the subagent returns:**
1. Scrub forbidden paths (safety net):
   ```bash
   cd ~/stratos-games-factory/<local_dir>/
   git checkout HEAD -- <each forbidden path>
   ```
2. If there are uncommitted changes, stage and commit them: `chore: trailing changes for #<N>`
3. Rebase against latest origin:
   ```bash
   git fetch origin <default_branch>
   git rebase origin/<default_branch>
   ```
   If rebase conflicts: `git rebase --abort`, comment on issue, remove `building` label, move on.
4. Push: `git push -u origin <branch>`
5. Open PR. **The PR body depends on the issue type:**

   **`[polish]` issues** — use `templates/polish-pr-body.md`, substitute `<ISSUE>`, `<PREVIEW_URL>`, `<TUNABLES_FILE>`. Never open a polish PR with a plain body (template is the anti-close-and-refile mechanism).

   **Every other issue** — standard body:
   ```bash
   gh pr create --repo <owner/repo> --base <default_branch> --head <branch> \
     --title "auto: #<N> — <title>" \
     --body "Closes #<N>

   ## What changed
   <subagent's summary>

   ---
   Generated by the Stratos Games Factory swarm."
   ```

6. Update labels: `gh issue edit <N> --repo <owner/repo> --remove-label building --add-label done`
7. Comment on issue: `gh issue comment <N> --repo <owner/repo> --body "Built → <PR URL>"`
8. Reset back: `cd ~/stratos-games-factory/` and `git checkout <default_branch>` in the game repo.

**If the subagent produced no changes:** comment on the issue with the subagent's explanation, remove `building` label, move on.

**CSS tunables for `[polish]` issues.** Expose every visual knob (rotation, size, offset, timing, color) as CSS variables in `games/<game>/src/styles/<feature>-tunables.css`. Polish iteration is a 1-line edit to that file, never a source rebuild — Ripon's "rotate 150, not 135" feedback maps directly to one PR comment.

**Wayfinding stub for user-facing `[structure]` PRs (#44).** A `[structure]` PR for a user-facing surface (tutorial, onboarding, cutscene, level intro, win/lose, first-launch) MUST ship a plain DOM text node — dedicated CSS class (e.g. `.wayfinding-banner`), identifies the feature unambiguously (`Tutorial 1/3 — tap the highlighted arrow`, `You win!`), replaced by the sibling `[polish]` PR. **Detection:** structure half touches `startX`/`showY`/screen-manager/controller-flow for a user-facing surface → mandatory. **Forbidden:** activating a user-facing feature with zero on-screen text because "polish lands later" (arrow-puzzle #139 — tutorial boot with no visual signal, users saw sparse boards and concluded "generator broken").

**Smoke-test runtime fidelity (#43).** Every smoke MUST (a) call the same runtime entry point the player reaches (`generateLevel(N)`, not `smokeFill(TIER)` with hand-picked args), (b) pass the same arguments the runtime uses, (c) assert the *positive* state that should exist (`#screen-game.active` present, `.arrow` pixel count > 0), never the negation (`!menu.active`). **Forbidden antipatterns:** negation assertions (a false positive on any screen transition), subset-of-signature helpers, hand-picked tier arguments that bypass `getDifficulty(level)`. A smoke one step removed from the player's runtime path is a placebo — PR #131 smoke tested Moderate while `generateLevel(1)` returns Baseline; PR #139 smoke asserted `!menu.active` while the tutorial never activated. Both shipped green.

### Step 4 — Product agent

Run inline (no subagent). Analyzes player behavior data and files data-backed improvement issues.

**Data sources (in priority order):**
1. **`analytics-data` issues from Ripon**: Check for open issues labeled `analytics-data` on each game repo. Ripon pastes screenshots, CSVs, or text summaries of Firebase Analytics / Play Console data into these issues. This is the primary input.
2. **Firebase CLI** (if available): Run `firebase` commands to pull analytics directly. Check with `command -v firebase`. If not available, skip — rely on Ripon's data issues.
3. **Game code analysis**: Read the game's level/difficulty config files to understand the progression curve and map analytics data to specific game elements.

**For each game:**
1. Read any open `analytics-data` issues: `gh issue list --repo <repo> --label analytics-data --state open --json number,title,body`
2. Read the game's level/difficulty configuration files to understand the progression.
3. Analyze the data for:
   - **Drop-off points**: which levels have abnormally low completion rates
   - **Session length patterns**: are sessions too short (boring) or too long (exhausting)
   - **Retry spikes**: which levels cause excessive retries (frustration)
   - **Feature engagement**: which mechanics get used vs ignored
4. File up to 3 data-backed improvement issues per game:
   ```bash
   gh label create product-data --repo <repo> --color 1d76db --description "Data-backed improvement from product agent" 2>/dev/null || true
   gh issue create --repo <repo> --label "build-request" --label "product-data" \
     --title "[product] <specific data-backed suggestion>" \
     --body "<body with raw stats, analysis, and concrete fix>"
   ```
5. Close processed `analytics-data` issues with a comment linking to the filed improvement issues.

**Product rules:**
- Every suggestion MUST cite specific data: "Level 8 has 70% drop-off vs 35% average" not "Level 8 seems hard"
- Suggestions must be actionable by the builder agent (reference specific files, stay under 50-line body)
- Title starts with `[product]`
- If no analytics data is available (no `analytics-data` issues, no Firebase CLI), skip with a message suggesting Ripon file an `analytics-data` issue with current stats
- Never invent data. If the numbers aren't there, say so.
- **Observation routing — mandatory** (see §Observation routing at the top of this file; applies to every agent).

### Step 5 — Monetization agent

Run inline (no subagent). Reviews ad placement configuration and files optimization issues.

**For each game (currently Bloxplode only — skip games with no ad integration):**
1. Read the game's codebase looking for ad integration code:
   - AdMob config, ad unit IDs, placement triggers
   - Interstitial frequency/timing logic
   - Rewarded video placement and reward values
   - Banner ad positioning
2. Cross-reference with casual game monetization best practices:
   - **Interstitials**: not more than once per 2-3 minutes of gameplay, never mid-action, always at natural break points (level complete, game over)
   - **Rewarded video**: offered at moments of player need (extra life, hint, skip level), never forced
   - **Banners**: bottom of screen only, never overlapping game UI, hidden during active gameplay
   - **Session pacing**: first ad impression should come after 2+ minutes of engagement, never on first screen
3. File up to 3 optimization issues per game:
   ```bash
   gh label create monetization-data --repo <repo> --color 0d7a3f --description "Ad optimization from monetization agent" 2>/dev/null || true
   gh issue create --repo <repo> --label "build-request" --label "monetization-data" \
     --title "[monetization] <specific optimization>" \
     --body "<body with current config, best practice citation, and concrete change>"
   ```

**Monetization rules:**
- Title starts with `[monetization]`
- Never suggest changes that hurt player experience more than they help revenue
- Reference specific files and line numbers where ad config lives
- Stay under 50-line body
- Do NOT touch `android/`, `capacitor.config.json`, or native ad SDK setup — only web-layer config
- If no ad integration exists in a game, skip it and note "no ad integration found"
- **Observation routing — mandatory** (see §Observation routing at the top of this file; applies to every agent).

### Step 6 — Content agent

Run inline (no subagent). For each game in the portfolio:

1. Check open `build-request` count: `gh issue list --repo <repo> --label build-request --state open --json number --jq 'length'`. If >= 10, skip (queue is full).
2. Get the 20 most recent issue titles for dedup: `gh issue list --repo <repo> --state all --limit 20 --json number,title,state`
3. Read the game repo's content/level files to understand the existing structure.
4. File up to 5 new issues with labels `build-request` + `content-agent`:
   ```bash
   gh label create content-agent --repo <repo> --color 0075ca --description "Filed by the content agent" 2>/dev/null || true
   gh issue create --repo <repo> --label "build-request" --label "content-agent" \
     --title "[content] <specific idea>" --body "<body following build-request template>"
   ```

**Content rules:**
- Title starts with `[content]`
- Body follows the `build-request` template: What / Where / How / Anything else
- Body stays under 50 lines
- Reference specific files in the codebase — read the game's CLAUDE.md and explore its content/level system first
- Be concrete and game-appropriate — the idea must fit the game's existing architecture
- Do NOT duplicate any of the 20 recent issues
- Tailor themes to each game's genre (puzzle levels for puzzle games, multiplayer modes for social games, etc.)
- **Observation routing — mandatory** (see §Observation routing at the top of this file; applies to every agent).

### Step 7 — Competitor agent

Run inline (no subagent). Covers all games in one pass.

1. Use WebSearch to research:
   - Top trending puzzle games on Apple App Store and Google Play this week
   - Notable new mechanics in casual/puzzle games in the last 30 days
   - Daily challenge / speed run / endless mode / meta-progression patterns
2. For each game, propose exactly 3 specific mechanic adaptations:
   - Cite the trending game that inspired it
   - Reference specific files in our codebase
   - Small enough for one PR (50-line issue body)
   - No new dependencies, no touching `packages/`, `android/`, `capacitor.config.json`
3. File one `market-intel` issue per game + one portfolio summary on the factory repo:
   ```bash
   gh label create market-intel --repo <repo> --color 5319e7 --description "Market intelligence from competitor agent" 2>/dev/null || true
   gh issue create --repo <game-repo> --label "market-intel" \
     --title "[market-intel] Week of <date> — 3 mechanics from trending games" --body "<suggestions>"
   gh issue create --repo sahilmodi1965/stratos-games-factory --label "market-intel" \
     --title "[market-intel] Portfolio scan — week of <date>" --body "<cross-portfolio themes>"
   ```

**Competitor rules:**
- Cite real games by name. Never invent.
- Prefer 3 sharp suggestions over 10 vague ones.
- If web searches return nothing credible, file zero issues and say so honestly.
- These issues are triaged by humans, NOT auto-built.
- **Observation routing — mandatory** (see §Observation routing at the top of this file; applies to every agent).

### Step 8 — UA agent (user acquisition)

Run inline (no subagent). Generates store listing assets for app store submissions.

**Triggered when:** a `ship-it` label was recently applied to a game, OR no `ua-assets` issue has been filed in the past 30 days, OR Sahil says "run UA prep".

**For each game:**
1. Read the game's current features, mechanics, and visual style from the codebase and CLAUDE.md.
2. Read the latest release tag and changelog (if any): `git tag --list 'v*' --sort=-version:refname | head -1`
3. Generate all of the following in a single issue:

   **App Store / Play Store description** (5 variants):
   - Each variant takes a different angle (gameplay-first, visual-first, challenge-first, casual-first, social-first)
   - Short description (80 chars) + full description (4000 chars max) for each
   - Written for the target audience (casual puzzle gamers)

   **ASO keyword sets** (5 variants):
   - Each set of 100 characters (iOS keyword field limit)
   - Mix of high-volume broad terms and low-competition long-tail terms
   - Include competitor game names where appropriate
   - Note estimated search volume/difficulty if inferable

   **Screenshot compositions** (suggestions, not images):
   - One suggestion per App Store screenshot slot (up to 10)
   - Each describes: what game state to capture, what caption text to overlay, what feature it highlights
   - Ordered by impact (most compelling screenshot first)

4. File as a single issue per game:
   ```bash
   gh label create ua-assets --repo <repo> --color e3b341 --description "Store listing assets from UA agent" 2>/dev/null || true
   gh issue create --repo <repo> --label "ua-assets" \
     --title "[ua] Store listing assets — <date>" \
     --body "<all variants, keywords, and screenshot suggestions>"
   ```

**UA rules:**
- Title starts with `[ua]`
- All copy must be truthful — describe features that actually exist in the game
- Never invent features the game doesn't have
- Write for the casual mobile gamer audience
- Include localization notes (flag terms that need translation attention)
- These issues are for human review — Ripon/Sahil picks the best variants
- **Observation routing — mandatory** (see §Observation routing at the top of this file; applies to every agent).

### Step 9 — Council review

Run inline (no subagent). Review the factory's own performance.

1. Gather context:
   - Read `build.log` (last 7 days of entries)
   - Query closed issues and merged/closed PRs across all games (past 7 days)
   - Query open auto/* PRs (stuck work)
   - Read current `council/COUNCIL.md`
2. Identify patterns: which builds failed and why, recurring failure modes, quality issues, what's brittle.
3. Update `council/COUNCIL.md`:
   - Append a `# Weekly review — YYYY-MM-DD` section
   - Add entries: "Lesson learned", "Known issue", "Architecture decision", "Improvement suggestion"
   - Every entry cites specific evidence (issue #, PR #, log timestamps)
   - Hard cap: 50 active entries. Archive old/obsolete ones to `council/archive.md`.
4. **Produce a tracked artifact for every entry**, per the observation routing matrix at the top of this file. The COUNCIL.md text is the audit trail; the tracked artifact is the work item. **Both are required.** Mapping:
   - **"Improvement suggestion"** → file a `factory-improvement` issue on `sahilmodi1965/stratos-games-factory` with an F-milestone, so it enters the buildable queue and the gate decides priority. Reference the COUNCIL.md entry in the issue body.
   - **"Known issue"** → file a `swarm-state` note (if one does not already exist) on the factory repo, so it surfaces at the start of every assess pass until resolved. No milestone.
   - **"Lesson learned"** → save a memory file via the auto memory system (feedback / project / user type per the memory schema), so future Claude sessions inherit the lesson without needing to read COUNCIL.md.
   - **"Architecture decision"** → COUNCIL.md entry only. These are audit-trail decisions, not actionable work.
5. Commit and push COUNCIL.md changes **and the new tracked artifacts** in the same commit (or note them clearly if they live in different repos).
6. If the week was uneventful, say so honestly — don't invent recommendations. **But also check `runs.jsonl` for the `factory_delta` field across the past 7 days**: if zero passes contributed back to the factory (no memory writes, no brain edits, no factory-improvement issues filed by builders/inline agents), that itself is a "Known issue" — sessions are consuming the factory without paying back.
7. **Brain-vs-game ratio aggregation (factory-improvement #48).** Read `arbitration_decision` from every `runs.jsonl` row in the last 50 passes (or all rows if fewer):
   ```bash
   tail -50 council/runs.jsonl | jq -r '.arbitration_decision // "unset"' | sort | uniq -c
   ```
   Compute the percentage of passes tagged `"brain"` vs `"game"` vs `"mixed"` vs `"review"` (treat `"mixed"` as half-brain for the ratio calculation). **Healthy band: 15-40% brain work.** Act on drift:
   - **<15% brain** — file a factory-improvement noting the factory may be shipping without encoding (self-improvement debt clause leaking). Title format: `council: brain contribution rate dropped to X% over last 50 passes — potential debt-clause leak`.
   - **>40% brain** — file a factory-improvement noting the factory may be refactoring instead of shipping (F4-trap, building the factory while F1 slips). Title format: `council: brain contribution rate rose to X% over last 50 passes — potential F4-drift`.
   - **15-40%** — healthy. Note the ratio in the weekly review and move on.
   Include the top 3 `arbitration_reason` values by frequency so the council can identify which decision-tree branches are firing most often — a persistent "branch 1: unencoded gap from prior pass" pattern means encoding is always one pass late; a persistent "branch 3: compounding ROI" pattern means you're burning through the factory-improvement backlog (good).
8. **Decomposition trip-rate aggregation (factory-improvement #47).** Read `decomposition_rule_fired` from every `runs.jsonl` row in the last 50 passes:
   ```bash
   trips=$(tail -50 council/runs.jsonl | jq -r '.decomposition_rule_fired // [] | length' | awk '{s+=$1} END {print s}')
   prs=$(tail -50 council/runs.jsonl | jq -r '[.games[]?.prs] | add // 0' | awk '{s+=$1} END {print s}')
   echo "decomposition trips=$trips over $prs shipped PRs"
   ```
   Compute the trip rate as `trips / prs`. **Healthy band: 10-30%** of shipped build-requests in user-facing surfaces trigger the decomposition rule. Act on drift:
   - **<10%** — the rule may not be firing often enough. Either issue-writing is pre-splitting cleanly (good, verify by reading the 10 most recent `build-request` issue bodies) OR the detection heuristic in Step 3 is missing real splits (bad, file a factory-improvement to tighten the heuristic). Determine which by sampling.
   - **>30%** — the issue-writing process is producing too many bundled issues. File a factory-improvement to strengthen `templates/build-request.md` with a pre-splitting checkbox ("is this purely mechanical? purely subjective? or both?") so writers declare upfront and the swarm doesn't have to split at build time.
   - **10-30%** — healthy. Surface the latest 5 `decomposition_rule_fired` entries in the COUNCIL.md weekly review section so the reasoning is auditable: which issues split, into which children, did both children ship?
9. **Note on data quality with thin `runs.jsonl` history** (~30 rows as of 2026-04-15): the council's pattern recognition is intuitive (Claude-style synthesis), not statistical, until ~50+ rows accumulate. Expected behavior at this stage of the factory's life — do not invent statistical patterns or imagine recurring failures from a single occurrence. The arbitration and decomposition aggregations above are reliable once the 50-row window fills; treat earlier numbers as directional, not decisive.

### Step 10 — Report + log the run

After all agents complete:

**1. Output a brief summary to Sahil:**
- Builder: N issues processed, N PRs opened (list URLs)
- Product: N data-backed issues filed, N analytics-data issues processed
- Monetization: N optimization issues filed
- Content: N ideas filed (list issue numbers)
- Competitor: N market-intel issues filed
- UA: N store listing issues filed
- Council: N entries added, N archived
- Anything that failed or was skipped, and why

**2. Append one structured row to `council/runs.jsonl`** with the same numbers so future councils (and the per-game baseline metrics from factory-improvement #21) can reason from data, not prose. Schema v3 (adds `arbitration_decision` + `arbitration_reason` per factory-improvement #48):

```json
{"ts":"<ISO8601>","scope":"<go_scope>","agents":["builder","content"],"games":{"arrow-puzzle":{"issues":3,"prs":3,"failed":0,"skipped":0},"bloxplode":{"issues":0,"prs":0,"failed":0,"skipped":0}},"swarm_state_seen":[6,32],"decomposition_rule_fired":[{"original":136,"structure":137,"polish":138,"smoked":true}],"arbitration_decision":"game","arbitration_reason":"No unencoded brain debt; no brain rule required by prior pass; open F1 game work with direct F1 outcome ROI.","factory_delta":{"memory_writes":["feedback_xyz"],"brain_edits":["CLAUDE.md"],"factory_issues_filed":[36,37,38],"observations_routed":4},"notes":"<one-line human note>"}
```

**`arbitration_decision`** is one of `"brain"` (pass was primarily brain work), `"game"` (pass was primarily game work), `"mixed"` (both shipped in meaningful quantities), `"review"` (pass ran inline agents / council only — no builds). **`arbitration_reason`** is one sentence naming which branch of the arbitration decision tree matched (see the "Brain-vs-game arbitration" section between Observation routing and Swarm mode). Both fields are **mandatory** — the Step 9 council aggregates them weekly for drift detection.

The `factory_delta` block is **mandatory** and is how the council weekly review (Step 9) detects whether sessions are paying back into the factory or just consuming from it. Fill it honestly, even with empty arrays — `"factory_delta":{"memory_writes":[],"brain_edits":[],"factory_issues_filed":[],"observations_routed":0}` is a valid (and revealing) value. A pass with all-empty `factory_delta` is a pass that consumed without contributing — the council will surface this as a "Known issue" if it persists.

Append with:
```bash
echo '<one-line json>' >> council/runs.jsonl
```

**3. Audit observation routing before committing the row.** Walk back through this pass: did any agent (you, a subagent, an inline agent) observe a gap, regression, or behavioral lesson and *not* file the appropriate tracked artifact per the routing matrix at the top of this file? If yes, route it now — file the issue, save the memory file, write the swarm-state note — then update the `factory_delta` block to reflect the routed artifacts. **Never let an observation die in the conversation log.**

One row per "go", no exceptions. If the swarm was interrupted mid-pass, log what completed with `"notes":"interrupted after builder"`. Do NOT rewrite prior rows — append only. The file is consumed by council weekly review (Step 9) and by the per-game baseline metrics script (factory-improvement #21) once that ships.

Commit `council/runs.jsonl` as part of the pass (or separately if no other changes landed). Don't let the log drift out of git.

---

## Architecture principles

- **Humans test and document, machines build, humans review.** Anything that violates this is wrong.
- **The factory never holds state.** Every swarm run starts from `origin/main`. There is no local work in progress — if it's not in a PR, it doesn't exist.
- **The brain is the contract.** The builder subagent is bound entirely by what is in the game's `CLAUDE.md`. To change builder behavior on a game, change that game's `CLAUDE.md` and re-run `scripts/deploy-brain.sh`.
- **Swarm and direct-push coexist.** The swarm resets to `origin/main` before each issue and rebases after.
- **Small, reviewable PRs.** The 50-line issue cap is a feature. Big requests get split.
- **Auto-merge ships safe changes instantly.** Safe-path-only (CSS/JSON/MD/content/levels) auto-merges; logic-touching (.js/.ts/.html) waits for human review.
- **Failure is loud.** If something breaks, the swarm comments on the issue. Silence means success.
- **Zero infrastructure.** GitHub Pages + GitHub Actions + Claude Code on a Mac.
- **Subagents bound by Step 3 prompt template.** Rules for builder subagents live in the Step 3 spawn template above (read game CLAUDE.md first, only do what issue asks, conventional commits, forbidden paths, build command, observation routing mandatory). There is no separate "subagent rules" section — Step 3 is the contract.

Human-facing onboarding docs (cost model, how to add a new game, file tree, system diagram) live in `README.md`, not here. This brain file is for operational rules only.
