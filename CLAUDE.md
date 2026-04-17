# CLAUDE.md — Stratos Games Factory

The brain of the Stratos Games autonomous build factory. If you are an AI agent (Claude Code, a subagent, etc.), this file is the source of truth for *how this repo operates*. Read it before doing anything.

Humans should start at `README.md`, then come here.

## What this repo is

Stratos Games Factory is a **meta-repo**. It does not ship a game. It is the autonomous build pipeline that turns human play-test feedback into shipped game changes for every game in the Stratos Games portfolio.

**Humans test + ship, machines build.** Sahil opens Claude Code in the factory and says **"go"** → the swarm assesses, builds every pending issue, fires inline agents (product / monetization / UA / content / competitor), runs council when due, reports.

## Roles

- **Sahil** — strategist / orchestrator / brain-keeper. Runs `go`. Edits `CLAUDE.md` + `council/*`. Closes factory-improvement issues. Milestone + architecture calls. Takes ad-hoc tasks. **Does NOT review or merge game PRs, does NOT play-test by default** — only when specifically needed.
- **Ripon** — operator / quality gate / executor. Plays games on real devices. Files game issues. **Reviews and merges all auto/\* PRs** after real-device testing. Runs `[secret-onboarding]` end-to-end on every game via his own Claude Code session. Handles store submissions, SDK debugging, MMP attribution. **The factory respects Ripon's review pace:** ≥3 open auto-PRs across the portfolio → swarm pauses new game work until his backlog drains.
- **Factory** (this Claude Code session, any subagent) — reads issues, writes code, opens PRs, reports via `runs.jsonl`. Never handles secrets, never merges its own PRs, never files game issues without user direction.

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

## Brain-vs-game arbitration (#48)

Every pass picks brain work (slow now, fast forever) vs game work (slow each time, no compounding). Walk this tree at the start of Step 3 — pick the first branch that matches, log the choice in `runs.jsonl` as `arbitration_decision` + `arbitration_reason`:

1. **Unencoded F1 gap from prior pass?** Check the last 3 `runs.jsonl` rows for `factory_issues_filed` entries NOT in `brain_edits`/`memory_writes`. If yes → encode now, even if small.
2. **Prior pass shipped game work needing a new brain rule to not regress?** → Encode now (examples: tunables convention, structure smoke, wayfinding stub).
3. **Open F1 factory-improvement that saves >30 min per future pass?** Compounding-ROI check: 30 min × 50 future passes = 25 hours recovered. If factory-improvement wins vs single-shot game PR → build it now.
4. **Open F1 game build-requests?** Build per Step 3 prioritization. Default branch for most passes once brain debt is current.
5. **Nothing pending?** Inline agents (Steps 4-8) + council (Step 9).

`arbitration_decision` is `"brain"` / `"game"` / `"mixed"` / `"review"`. `arbitration_reason` names the matching branch in one sentence. Both are mandatory schema fields per Step 10. Step 9 council aggregates the ratio (healthy band 15-40% brain — see Step 9 for drift response).

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

- Empty `runs.jsonl` → first structured-log run, move on.
- Latest row >7d ago → flag idle swarm.
- `"failed"` non-zero → surface before new work, don't re-attempt silently.
- `decomposition rule fired` in notes → confirm split-issues produced PRs on next pass.

Factory-repo PRs aren't the review surface — this loop is. **Don't skip.** Loop itself broken (missing `runs.jsonl`) IS the regression signal.

**Milestone + council-staleness (always, even scoped):**

```bash
cat council/MILESTONE 2>/dev/null || echo "UNDECLARED"
find council/COUNCIL.md -mtime +7 -print 2>/dev/null | grep -q . && echo "STALE" || echo "fresh"
```

State the milestone aloud with north-star framing. `UNDECLARED` → **stop**, ask Sahil to declare. `STALE` (>7d) → **Step 9 runs FIRST before Step 2, regardless of scope** — self-learning loop can't lie dormant. Fresh (<7d) → Step 9 at normal priority. Surface state (e.g., `council: 12d STALE — running Step 9 first`).

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
8. **Observation routing — mandatory.** If you observe any factory gap, missing capability, or behavioral lesson, file the tracked artifact per `council/ROUTING.md` (game issue / factory-improvement / swarm-state / memory) BEFORE ending. Include the artifact URLs in your summary. Never let an observation die in your summary text.
9. **Smoke-test runtime fidelity (#43).** Every test you add/modify MUST: (a) call the runtime entry the player reaches (`generateLevel(N)`, not `smokeFill(HAND_PICKED_TIER)`); (b) pass the runtime args (let `getDifficulty(level)` decide, not hard-coded `'Moderate'`); (c) assert positive state (`screen.active`, `pixelCount > N`), NEVER the negation (`!menu.active` is forbidden — false-positives on every screen transition). If you can't reach the runtime entry from Node, promote to Playwright on the live URL. Reference: PR #131 (wrong tier) + PR #139 (negation assertion) — both shipped green, both broken.
10. **Wayfinding stub for user-facing `[structure]` PRs (#44).** If your work touches `startX()`/`showY()`/`screens.show(...)`/screen-manager for a user-facing surface (tutorial, onboarding, cutscene, win/lose, first-launch), you MUST add a plain DOM text element with a dedicated CSS class (e.g. `.wayfinding-banner`) identifying the feature: `Tutorial 1/3 — tap the highlighted arrow`, `You win!`. Plain `<div>` or `<span>` (NOT canvas, NOT image), visible in the active screen, independent of any sibling polish PR. Forbidden: activating a user-facing feature with zero on-screen text because "polish lands later" (arrow-puzzle #139 — Ripon saw a tutorial board with no UI and concluded the generator was broken).
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

**Polish PR follow-up routing (#46).** A `build-request` filed within 7 days of a polish PR merge, referencing the same feature, is one of three things — classify BEFORE spawning a subagent:

- **Route A — CSS variable tweak.** Body has tweak keywords (`rotation`, `size`, `color`, `padding`, `spacing`, `feel`, `looks`, `too small/big`, `off-center`) AND names no file paths AND proposes ≤1 numeric change. Main thread handles directly: edit the tunables file, commit `polish: <old> → <new> for #<N>`, open a polish-pr-body PR. ~30s. No subagent.
- **Route B — mechanical bug exposed by the polish landing (default).** Body names file paths or identifies a runtime/timing/null-check bug. Standard builder subagent. Example: arrow-puzzle #147 (`layout.resize()` race exposed by #145).
- **Route C — real new feature request.** Treat as a fresh `build-request`; re-runs the decomposition check.

```bash
body=$(gh issue view <N> --repo <repo> --json body -q .body)
keywords='(rotation|size|color|padding|spacing|feel|looks|too small|too big|wrong position|off-center)'
paths='(src/|games/|packages/|\.js|\.ts|\.css)'
if echo "$body" | grep -qiE "$keywords" && ! echo "$body" | grep -qE "$paths"; then route=A; else route=B; fi
```

Manual override: any issue tagged `polish-iteration` → route A. Create label on first use per repo: `gh label create polish-iteration --color a371f7`.

**Inline-agent preamble (Steps 4-8).** All inline agents apply observation routing per `council/ROUTING.md` (no per-step repetition). Three of them (product / monetization / UA) operate in **two modes per game** — strategy mode (G1+, no upstream data needed; files prerequisite issues + a strategy advisory) and data mode (G2+, existing data-driven flow). Strategy mode is the rule that keeps these agents productive from G1 onward — they BUILD the conditions for their own data mode, not skip silently waiting for them. Closes factory-improvement #30.

**Paired `[secret-onboarding]` issue (#52).** Any strategy-mode agent filing a G2/G3 integration build-request requiring tier-2 secrets (AdMob / Firebase / LinkRunner / AppLovin / Capacitor-signing — anything per `council/SECRETS.md`) MUST also file the paired `[secret-onboarding] <game>` issue on the same game repo using `templates/secret-onboarding-issue.md`. Skip only if an open-or-closed one exists: `gh issue list --label secret-onboarding --state all --repo <repo>`. **G-pointer cannot advance past G2 until `[secret-onboarding]` has closed** — Step 9 council surfaces violations.

### Step 4 — Product agent

Pick mode by data availability:

- **Strategy mode (G1+, no analytics).** Game has no `analytics-data` issues AND no analytics SDK (`grep -riE 'firebase|gtag|analytics' <game_dir>/`). File:
  - `[G2] feat: integrate Firebase Analytics` build-request (skip if open).
  - One `[product-strategy]` advisory per game per 30d: event taxonomy + key funnels + drop-off levels to watch when data lands.
- **Data mode (G2+, analytics-data present).** Read open `analytics-data` issues + game's level/difficulty config. Analyze drop-off / session length / retry spikes / engagement. File up to 3 `[product]` build-requests citing raw stats. Close processed `analytics-data` issues with links.

Rules: title `[product]` or `[product-strategy]`. Data-mode suggestions cite numbers ("L8 70% drop-off vs 35% avg"), not feel. ≤50-line body. Never invent data.

```bash
gh label create product-data --color 1d76db 2>/dev/null || true; gh label create product-strategy --color 1d76db 2>/dev/null || true
```

### Step 5 — Monetization agent

**SDK pre-flight (#49):** `grep -riE 'admob|adsense|interstitial|rewarded|banner' <game_dir>/`; also `linkrunner|mmp` and `applovin|max.*mediation`.

- **Strategy mode (G1+, no ad SDK).** File:
  - `[G2] feat: integrate AdMob` build-request (skip if open).
  - `[G3] feat: integrate LinkRunner MMP` and `[G3] feat: integrate AppLovin MAX mediation` (G3 prerequisites).
  - One `[monetization-strategy]` advisory per game per 30d: ad placement plan in this game's loop (interstitial trigger points, rewarded-video opportunities, banner positioning).
- **Data mode (G2+, ad SDK present).** Read existing ad config. Cross-reference best practices: interstitials ≤1/2-3 min at natural break points; rewarded at moments of need; banner bottom only, hidden during play; first impression after 2+ min. File up to 3 `[monetization]` build-requests with current config + citation + concrete change.

Rules: title `[monetization]` or `[monetization-strategy]`. Reference specific files + lines. ≤50-line body. Do NOT touch `android/`, `capacitor.config.json`, or native ad SDK setup — web layer only.

```bash
gh label create monetization-data --color 0d7a3f 2>/dev/null || true; gh label create monetization-strategy --color 0d7a3f 2>/dev/null || true
```

### Step 6 — Content agent

For each game: skip if open `build-request` count ≥ 10. Read 20 most-recent issue titles for dedup. Read game's content/level files. File up to 5 `[content]` build-requests:

```bash
gh label create content-agent --color 0075ca 2>/dev/null || true
gh issue create --repo <repo> --label build-request --label content-agent --milestone <G-stage> \
  --title "[content] <idea>" --body "<What / Where / How body, ≤50 lines>"
```

Rules: concrete + game-genre-appropriate + matches existing architecture. Reference specific files. No duplicates against the recent 20.

### Step 7 — Competitor agent

Covers all games in one pass.

1. WebSearch: top trending puzzle games this week (App Store + Play); notable new mechanics in casual/puzzle in last 30d; daily-challenge / speed-run / endless / meta-progression patterns.
2. For each game, propose 3 specific mechanic adaptations citing the trending game + our codebase files. ≤50-line bodies. No deps, no `packages/`/`android/`/`capacitor.config.json` edits.
3. File one `[market-intel]` per game + one portfolio summary on the factory repo.

```bash
gh label create market-intel --color 5319e7 2>/dev/null || true
```

Rules: cite real games by name. 3 sharp > 10 vague. Honest "no signal" if web returns nothing. Human-triaged, NOT auto-built.

### Step 8 — UA agent

Triggered by `ship-it` label, no `ua-assets` issue in 30d, or `run UA prep`.

**Distribution pre-flight (#49):** `capacitor.config.json`, `android/`/`ios/` projects, AdMob, Firebase.

- **Strategy mode (G1+, no Capacitor).** File `[G2] feat: wrap with Capacitor for Android + iOS` build-request (skip if open). Plus one `[ua-strategy]` advisory per game per 30d: pre-launch positioning (target audience, ASO angle, competitor names to displace, store-listing tone).
- **Data mode (G2+, Capacitor + native projects).** Generate `[ua] Store listing assets` issue: 5 description variants (different angles, 80-char short + 4000-char full each), 5 ASO keyword sets (100 chars / iOS limit each, mix broad + long-tail, competitor names where appropriate), 10 screenshot compositions ordered by impact. If ad SDK / analytics missing, prefix listing with: "Ready to use once SDKs land — do not submit to stores without ads + analytics live."

Rules: title `[ua]` or `[ua-strategy]`. All copy truthful (real features only). Casual mobile-gamer audience. Localization notes flag terms needing translation. Human-reviewed — Sahil/Ripon picks variants.

```bash
gh label create ua-assets --color e3b341 2>/dev/null || true; gh label create ua-strategy --color e3b341 2>/dev/null || true
```

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
7. **Brain-vs-game ratio (#48).** `tail -50 council/runs.jsonl | jq -r '.arbitration_decision // "unset"' | sort | uniq -c`. Compute % brain (treat `mixed` as half-brain). **Healthy band: 15-40%.**
   - <15% brain → file factory-improvement: `council: brain contribution dropped to X% — debt-clause leak`.
   - >40% brain → file factory-improvement: `council: brain contribution rose to X% — F4-drift`.
   - 15-40% → healthy. Note ratio + top 3 `arbitration_reason` values by frequency (reveals which decision-tree branches fire most).
8. **Decomposition trip rate (#47).** `trips=$(tail -50 council/runs.jsonl | jq -r '.decomposition_rule_fired // [] | length' | awk '{s+=$1} END {print s}'); prs=$(tail -50 council/runs.jsonl | jq -r '[.games[]?.prs] | add // 0' | awk '{s+=$1} END {print s}'); echo "$trips/$prs"`. **Healthy band: 10-30%.**
   - <10% → sample 10 most recent build-request bodies. If pre-split cleanly, fine. If heuristic missed real splits, file factory-improvement to tighten.
   - >30% → file factory-improvement to add a pre-splitting checkbox to `templates/build-request.md`.
   - 10-30% → healthy. Surface the latest 5 `decomposition_rule_fired` entries in the weekly review (which split, did both ship?).
9. **Thin-history caveat:** until `runs.jsonl` has 50+ rows, treat aggregation numbers as directional. Don't invent statistical patterns from single occurrences.

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

**`arbitration_decision`** ∈ `"brain"` / `"game"` / `"mixed"` / `"review"`. **`arbitration_reason`** is one sentence naming the matching branch (see Brain-vs-game arbitration section). Both **mandatory** — Step 9 aggregates weekly.

The `factory_delta` block is **mandatory** with all 5 keys present (`memory_writes`, `brain_edits`, `factory_issues_filed`, `factory_issues_closed`, `observations_routed`). Empty arrays are valid; missing keys are not. All-empty = pass consumed without contributing (Step 9 surfaces persistent emptiness as a Known issue).

**Mandatory-field enforcement (#50).** The canonical write path is `scripts/log-run.sh` — it validates required args (`--scope`, `--arbitration-decision`, `--arbitration-reason`, `--notes`) before building the row, and runs a jq schema check on the built row before append. Invalid invocations exit 2 (args) or 3 (schema). Use it on every pass:

```bash
bash scripts/log-run.sh \
  --scope <go-scope> \
  --arbitration-decision brain|game|mixed|review \
  --arbitration-reason "<one sentence naming the matching decision-tree branch>" \
  --notes "<one-line human note>" \
  --game arrow-puzzle:0:0:0:0 --game bloxplode:0:0:0:0 --game house-mafia:0:0:0:0 \
  --brain-edits CLAUDE.md \
  --factory-issues-filed 50,51 --factory-issues-closed 30,45 \
  --observations-routed 2 \
  --swarm-state-seen 35,22 \
  --append
```

Run `bash scripts/log-run.sh --help` for the full arg list. `--append` writes to `council/runs.jsonl`; omit it to emit the row to stdout for review first.

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
- **Brain never handles secrets.** Code references secrets structurally (`process.env.X` / `${{ secrets.X }}`); Ripon sets values via `gh secret set`. Spec: `council/SECRETS.md`; per-game issue template: `templates/secret-onboarding-issue.md`. Any secret value in context → stop, rotate, swarm-state note.

Human-facing onboarding docs (cost model, how to add a new game, file tree, system diagram) live in `README.md`, not here. This brain file is for operational rules only.
