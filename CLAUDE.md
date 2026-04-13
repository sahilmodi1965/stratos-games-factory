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

### Step 2 — Prioritize

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

**Before anything else — classify the issue (structure vs polish):**

An issue can contain two kinds of work:

- **Mechanical** — levels, save keys, controller hooks, route wiring, config fields, game logic, event handlers. Text-specifiable, unambiguous, survives review unchanged.
- **Subjective** — pixel placement, rotation angles, timing curves, color feel, copy tone, animation easing, aspect-ratio choices. Requires a human eye to judge; prose specs are lossy.

**If an issue contains both, split it before building.** This is the rule that exists to stop the tutorial saga (arrow-puzzle PRs #75/#80/#85 were all closed because mechanical scaffolding was bundled with visual polish the human eye rejected — every closure threw away working structural code).

**Detection heuristic.** An issue is a candidate for splitting if its body contains **mechanical markers** (`save.set`, `controller`, `level`, `boot`, `startX`, config field names, file paths under `src/`) AND **more than 2 subjective markers** from: `rotate(`, `transform`, `padding`, `font-size`, `animation`, `ease`, `opacity`, `scale(`, `translate`, "feel", "looks", "polish", "aspect ratio", "instead of X use Y".

**Split procedure when the rule fires:**

1. File a new `build-request` issue titled `[structure] <original title>` containing ONLY the mechanical parts, plus a no-op placeholder for the subjective piece (e.g., "tutorial runs but with no hand overlay yet — polish tracked separately").
2. File a second `build-request` issue titled `[polish] <original title>` containing ONLY the subjective piece. Its body uses the polish-PR feedback template (see factory-improvement #27), exposes knobs as CSS variables where possible, and ships in small iterations via PR comments, **never closed-and-refiled**.
3. Comment on the original issue linking to both and close it as superseded.
4. Build the `[structure]` issue immediately this pass. Leave `[polish]` for the next pass (or for Ripon to iterate).
5. **Record the trip in `runs.jsonl`** (Step 10): add `"decomposition_rule_fired":[{"original":<N>,"structure":<N1>,"polish":<N2>}]` to this pass's row so the feedback loop in Step 1 can show it to Sahil on the next go. This is how we verify the rule is working without requiring anyone to read the code.

**If the issue is purely mechanical or purely subjective, do not split — build as-is.** Most issues are one or the other.

**The rule's acceptance test:** if you are about to build an issue whose body contains both a `startTutorial(` method spec AND a `rotate(135deg)` CSS instruction, you are looking at a split candidate — not a build candidate. Stop and file the two replacement issues.

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

**Spawn a subagent** using the Agent tool. The subagent prompt must include:
- The full path to the game repo
- The issue number, title, and body
- Instruction to read the game repo's `CLAUDE.md` first and follow its rules exactly
- The build command to run as final step (if any)
- The forbidden paths (do not edit or `git add` these)
- Instruction to use conventional commits referencing the issue number
- Instruction to end with a one-paragraph summary of what changed (or why it refused)

Example subagent prompt:
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
```

**Important:** The `build_cmd` and `forbidden_paths` come from `daemon/config.sh` and are **different per game**. Do not hardcode `npm run build` — some games have no build step (e.g., Bloxplode serves raw www/).

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

   **For `[polish]`-prefixed issues** — use the canonical polish template at `templates/polish-pr-body.md`. Substitute `<ISSUE>`, `<PREVIEW_URL>` (the PR-preview URL for this PR, derived from the preview workflow), and `<TUNABLES_FILE>` (the path to the CSS variables file, e.g. `games/arrow-puzzle/src/styles/tutorial-tunables.css`). Do NOT open a polish PR with a plain body — the template instructs Ripon how to respond (and, critically, to NOT close-and-refile). This is the mechanism that stops the tutorial-saga pattern.

   **For every other issue** — use the standard body:
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

**CSS variable tunables convention (for `[polish]` issues):** the builder subagent MUST expose every visual knob (rotation angles, sizes, offsets, animation timings, colors) as CSS variables in a single tunables file at `games/<game>/src/styles/<feature>-tunables.css`. Iteration on polish PRs happens by editing that one file — never by modifying source code. Ripon's feedback ("rotate 150, not 135") maps directly to a 1-line edit. This is the other half of the anti-saga mechanism: if the visual is off, the fix is always a single CSS value change, not a rebuild.

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
4. File `council`-labeled issues on `sahilmodi1965/stratos-games-factory` for actionable improvements.
5. Commit and push COUNCIL.md changes.
6. If the week was uneventful, say so honestly — don't invent recommendations.

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

**2. Append one structured row to `council/runs.jsonl`** with the same numbers so future councils (and the per-game baseline metrics from factory-improvement #21) can reason from data, not prose. Minimal schema v1:

```json
{"ts":"<ISO8601>","scope":"<go_scope>","agents":["builder","content"],"games":{"arrow-puzzle":{"issues":3,"prs":3,"failed":0,"skipped":0},"bloxplode":{"issues":0,"prs":0,"failed":0,"skipped":0}},"swarm_state_seen":[6,32],"notes":"<one-line human note>"}
```

Append with:
```bash
echo '<one-line json>' >> council/runs.jsonl
```

One row per "go", no exceptions. If the swarm was interrupted mid-pass, log what completed with `"notes":"interrupted after builder"`. Do NOT rewrite prior rows — append only. The file is consumed by council weekly review (Step 9) and by the per-game baseline metrics script (factory-improvement #21) once that ships.

Commit `council/runs.jsonl` as part of the pass (or separately if no other changes landed). Don't let the log drift out of git.

---

## System architecture

```
                ┌─────────────────────── Stratos Games Factory ──────────────────────┐
                │                                                                      │
   Ripon plays  │                          ┌──────────────┐                            │
   the live URL │                          │ Claude Code  │ (Sahil says "go")          │
       │        │                          │    swarm     │                            │
       │ files  │                          └──────┬───────┘                            │
       │ issue  │                                 │                                    │
       ▼        │        ┌────────────────────────┼────────────────────┐               │
   ┌──────────┐ │        │                        │                    │               │
   │ GH Issue │─┼──▶ builder           content           competitor   │               │
   │ build-   │ │   (subagent per    (inline, files    (inline, web   │               │
   │ request  │ │    issue, opens     build-request     search, files │               │
   └──────────┘ │    PRs)             issues)           market-intel) │               │
                │        │                                             │               │
                │        ▼                                             │               │
                │   ┌─────────┐  PR  ┌────────────┐ ┌──────────────┐  │               │
                │   │   PR    │─────▶│ pr-preview │ │  ci.yml      │  │               │
                │   │ auto/*  │      │ → /pr/N/   │ │ npm build    │  │               │
                │   └────┬────┘      └─────┬──────┘ └──────┬───────┘  │               │
                │        │                 │               │ success  │               │
                │        │                 │ comment URL   ▼          │               │
                │        │                 └──────────▶ ┌──────────┐  │               │
                │        │                              │ auto-    │  │               │
                │        │                              │ merge    │  │               │
                │        │                              └────┬─────┘  │               │
                │        │  not safe → human review          │ safe   │               │
                │        │         ◄─────────────────────────┘        │               │
                │        ▼                                            │               │
                │   ┌──────────┐  push to main   ┌──────────┐        │               │
                │   │  merged  │ ──────────────▶ │ deploy   │        │               │
                │   └──────────┘                 └──────────┘   council (inline,     │
                │                                               reviews the week,    │
                │   Ripon adds `ship-it` label   ┌──────────┐   updates COUNCIL.md)  │
                │           ─────────────────▶   │ release  │        │               │
                │                                └──────────┘        │               │
                └────────────────────────────────────────────────────────────────────┘
```

Key facts:
- **Sahil opens Claude Code, says "go"** — the swarm runs all 9 agents in priority order.
- The **builder** spawns subagents (one per issue) for context isolation.
- **Product, monetization, content, competitor, UA, council** all run inline — they file issues, not code.
- The **product agent** reads Ripon's `analytics-data` issues and turns raw stats into actionable `build-request` issues.
- The **UA agent** generates store listing variants when a game approaches release.
- **Auto-merge** ships safe-path-only PRs (CSS, JSON, content, levels, MD) instantly. Logic-touching PRs (.js/.ts/.html) wait for human review.
- The **`ship-it` label** triggers production release on issues OR PRs.
- **QA agent** runs as GitHub Actions (Playwright) on every PR — zero Claude tokens.
- All workflows are **deployed by `scripts/deploy-brain.sh`** from `templates/workflows-<game>/`.

## Rules for builder subagent sessions

When you (Claude) are spawned as a builder subagent, you operate under tight constraints:

1. **Read the game repo's `CLAUDE.md` first.** If there is no `CLAUDE.md`, stop. The factory deploys one to every game; its absence means the brain hasn't been deployed yet.
2. **Only do what the issue asks.** No bonus refactors. No "while I'm here" cleanups. No comments or docstrings on code you didn't change.
3. **Conventional commits, one logical change per commit, every message references the issue number** (`fix: description #42`).
4. **Hard exclusions** — do not edit the `forbidden_paths` listed in `daemon/config.sh` for this game, or anything the game's CLAUDE.md flags as off-limits.
5. **Run the build command** from `daemon/config.sh` (`build_cmd` field) as the final step. If the game has no build command (empty field), skip this. If the build fails, fix or revert until it passes. Never push a broken build.
6. **If you cannot do the task safely, do nothing.** Output a one-paragraph explanation of why. The swarm will turn that into an issue comment so a human can clarify.

## Adding a new game (for future interns)

The flow for onboarding a new intern with a new game:

1. **Intern creates a GitHub repo** for their game in their own account or under `mody-sahariar1`.
2. **Intern adds `sahilmodi1965` as a collaborator** with write access. (Required so the swarm can push.)
3. On Sahil's machine:
   ```bash
   cd ~/stratos-games-factory
   bash scripts/add-game.sh owner/their-repo "Short description of the game"
   ```
   This clones the repo, registers it in `config.sh`, creates labels, deploys a starter `CLAUDE.md` and the issue template.
4. **Sahil writes a real `CLAUDE.md`** for the new game (the starter is just a placeholder). Or have Claude write it interactively. Then commit and re-run `scripts/deploy-brain.sh` to deploy the autobuilder section + workflows.
5. **Intern files issues, plays, tests.** The swarm builds them when Sahil says "go".
6. **Intern can also push directly** with their own $20 Claude Code Pro plan for quick fixes. The "Direct contributor mode" rules in the deployed `CLAUDE.md` are their guide.
7. **First release**: when the game feels ready, add the `ship-it` label and the release workflow takes over.

This is the entire onboarding for a new collaborator. No new infrastructure, no new accounts, no new keys.

## Cost model

The factory is designed to run at fixed cost regardless of how many games or interns it serves:

- **Sahil**: $200/mo Claude Code Max plan — powers the swarm and Sahil's own architecture work.
- **Each collaborator (Ripon, interns)**: $20/mo Claude Code Pro plan + $20/mo Claude Chat (claude.ai) for feedback structuring. Total: $40/mo per person.
- **Infrastructure**: $0. GitHub Pages (free for public repos), GitHub Actions (free tier covers everything we run), no API keys, no Vercel, no AWS, no databases.

The math: 1 Sahil + 2 interns + 5 games still costs ~$280/mo total. Adding a 6th game costs $0. Adding a 3rd intern costs $40/mo. The system scales by adding people, not infrastructure.

## How to add a new game

```bash
bash scripts/add-game.sh owner/new-game "Short description"
```

This:
1. Clones the repo into `~/stratos-games-factory/<repo-name>/`.
2. Appends an entry to `daemon/config.sh`.
3. Creates the `build-request` / `building` / `done` / `ship-it` / `auto-merged` labels on the repo.
4. Pushes a starter `CLAUDE.md` if none exists, plus the issue template.
5. Note: workflow templates are per-game (`templates/workflows-<game>/`). New games of arbitrary structure need a workflow set written for them — clone `workflows-arrow-puzzle/` or `workflows-bloxplode/` as a starting point.

## Architecture principles

- **Humans test and document, machines build, humans review.** Anything that violates this is wrong.
- **The factory never holds state.** Every swarm run starts from `origin/main`. There is no local "work in progress" — if it's not in a PR, it doesn't exist.
- **The brain is the contract.** The builder subagent is bound entirely by what is in the game's `CLAUDE.md`. To change builder behavior on a game, change that game's `CLAUDE.md` and re-run `scripts/deploy-brain.sh`.
- **Swarm and direct-push coexist.** The swarm resets to `origin/main` before each issue and rebases after. Humans don't need to coordinate — the swarm adapts.
- **Small, reviewable PRs.** The 50-line issue cap is a feature. Big requests get split.
- **Auto-merge ships safe changes instantly.** Anything touching .js/.ts/.html waits for review. The line between data and logic is the line between auto-merge and manual review.
- **Failure is loud.** If something breaks, the swarm comments on the issue. Silence means success.
- **Zero infrastructure.** GitHub Pages + GitHub Actions + Claude Code on a Mac. That's the entire stack.

## Legacy: cron-based daemon (deprecated)

The original daemon (`daemon/stratos-daemon.sh`) ran hourly via cron and invoked `claude -p` headlessly. The agent shell scripts (`agents/content/content-agent.sh`, `agents/competitor/competitor-agent.sh`, `council/review.sh`) followed the same pattern. These scripts are preserved as documentation but are deprecated in favor of swarm mode. See each script's header comment.

To re-enable cron (not recommended): `bash daemon/install.sh --with-cron`

## Files in this repo

```
stratos-games-factory/
├── CLAUDE.md                            ← you are here (the swarm brain)
├── README.md                            ← human entry point
├── daemon/
│   ├── stratos-daemon.sh                ← (deprecated) cron-based builder loop
│   ├── install.sh                       ← one-shot setup
│   └── config.sh                        ← game list, paths, limits (still active)
├── brain/
│   ├── arrow-puzzle-autobuilder.md      ← appended to Arrow Puzzle CLAUDE.md
│   └── bloxplode-claude.md              ← full CLAUDE.md for Bloxplode
├── templates/
│   ├── build-request.md                 ← issue template deployed to every game
│   ├── workflows-arrow-puzzle/          ← GitHub Actions for Arrow Puzzle
│   │   ├── ci.yml                       ← npm install + npm run build
│   │   ├── pr-preview.yml               ← deploy PR build to gh-pages /pr/N/
│   │   ├── deploy.yml                   ← mirror main/docs to gh-pages root
│   │   ├── auto-merge.yml               ← merge daemon PRs after CI (safe paths only)
│   │   ├── release.yml                  ← ship-it label → tag + GitHub Release
│   │   └── cleanup.yml                  ← weekly auto/* branch sweep
│   └── workflows-bloxplode/             ← same set, customized for Bloxplode (no build, www/)
├── agents/
│   ├── registry.json                    ← authoritative agent list
│   ├── content/content-agent.sh         ← (deprecated) cron-based content agent
│   ├── competitor/competitor-agent.sh   ← (deprecated) cron-based competitor agent
│   ├── qa/                              ← Playwright smoke tests (GitHub Actions, still active)
│   └── platform/platform-agent.sh       ← native build agent (manual, still active)
├── council/
│   ├── review.sh                        ← (deprecated) cron-based council review
│   ├── COUNCIL.md                       ← living memory
│   └── archive.md                       ← retired entries
├── scripts/
│   ├── deploy-brain.sh                  ← push brain + workflows + labels to all game repos
│   ├── add-game.sh                      ← onboard a new game repo
│   └── status.sh                        ← rich dashboard
└── docs/
    └── ripon-guide.md                   ← non-technical guide for the play-tester
```
