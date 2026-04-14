# Stratos Games Factory — Roadmap

This is the factory's vision document. It defines the **north star**, the **factory milestones (F-series)**, and the **per-game milestones (G-series)**. The current factory milestone is recorded in `council/MILESTONE` — a one-line file the swarm reads at the start of every `go`.

This file is the single source of truth for milestone definitions. CLAUDE.md references this file but does not duplicate its content.

---

## North star

**Ship real-world working products with correct monetization, correct distribution, and correct compliance.** Not "merge PRs faster". Not "build more features". Real games in real users' hands, on real stores, with ads serving, listings polished, and compliance handled.

The north star has **veto authority over every other rule in the brain**, including the milestone shape itself. If a milestone, an agent, a validator, or any swarm decision works against the north star, the north star wins. Everything else is up for revision; the north star is not.

---

## How the milestone gate works

1. The factory is always in exactly one F-milestone at a time, recorded in `council/MILESTONE`.
2. Every issue in every repo carries a milestone label (F1/F2/F3/F4 for factory issues; G1-G5 for per-game issues).
3. In Step 2 prioritization, the swarm filters every issue by `milestone == current` (or unmilestoned). Future-milestone issues are **invisible** to the pass — not built, not planned, not listed.
4. Unmilestoned issues are reviewed in Step 1 and either tagged or skipped. They are **never** built unmilestoned.

This is the mechanism that prevents drift toward shiny F4 work (federated MCP, multi-harness adapters, genre packs) while F1 (an actual shipped game) is incomplete.

---

## The self-improvement debt clause

A milestone is **not complete** when its outcome holds. A milestone is complete when:

1. The outcome holds (the one-sentence verifiable test passes), **AND**
2. Every gap that surfaced reaching it has been encoded as a permanent factory capability — brain shard, CLAUDE.md rule, council entry, validator, agent prompt, smoke test. **Tribal memory does not count.**

Without (2), the factory ships the milestone, learns ten things, forgets nine of them by the next milestone, and rebuilds them from scratch. The clause is the mechanism that makes the factory monotonically better instead of oscillating.

---

## Council authority to evolve the roadmap

The council (Step 9 weekly review, or a manual `re-shape milestones` invocation) **MAY** re-order, rename, split, or merge milestones — but **ONLY** if doing so moves the factory closer to the north star. The council **MAY NOT** change the north star itself.

Re-shapes update this file and `council/MILESTONE` in the same commit, are logged as `swarm-state` notes, and are surfaced at the top of the next `go`.

---

## F-series — factory milestones

### F1 — One real game, fully shipped

**Outcome:** One game is live and downloadable across web, iOS, and Android. Ads serving. Store listings polished. UA assets approved. Compliance handled. Real humans can install and play it. The factory drove it the entire way.

**Why it matters:** The factory has zero proof today that it can produce a complete product. It can merge PRs. That is not the same thing. Until one game survives the full pipeline from idea → store, every other milestone is theoretical.

**Verifiable in one sentence:** *"A real human can search the App Store / Play Store for the game, download it on a phone, see ads, and play a full round."*

**Self-improvement debt F1 will pay:** store-readiness gates, submission playbook, signing pipeline, smoke verification (boot-verified builds), mobile-viewport CI, ads-account validation, privacy policy generator, compliance checklist. None of these are built speculatively — they get built **because F1 surfaces the need**.

**Issues that belong to F1 (existing):** #9, #30, #33, #34 — plus per-game F1 entry plans tracked on each game repo.

---

### F2 — Multiple games on the same cycle, each measurably better

**Outcome:** Two or more games are progressing through the full pipeline simultaneously, and each new game's quality (smoke-pass rate, regression count, time-to-fix, player-data-back-to-fix loop time) is **measurably better than the previous game's**, with proof in `runs.jsonl`.

**Why it matters:** F1 proves the factory *can* ship one. F2 proves the factory is a *system*, not a one-off. The "measurably better per cycle" clause is what stops F2 from being "we did F1 twice."

**Verifiable in one sentence:** *"Game N+1's pipeline runs faster, breaks less, and ships smoother than Game N's, and we can prove it from runs.jsonl."*

**Self-improvement debt:** genre-pack scaffolding (a new puzzle game inherits monetization from the last puzzle game), per-game baseline metrics (real comparisons require data), trust ladder activation (a shipped game earns relaxed gates), unified read path for swarm-state + council + memory.

**Issues that belong to F2:** #7, #8, #10, #13, #15, #17, #19, #21, #23, #29, #31

---

### F3 — Cadence: one shippable game per week

**Outcome:** The factory sustains a rhythm of one new game crossing G3 (launched + collecting data) per calendar week, for four consecutive weeks.

**Why it matters:** F2 proved repeatability. F3 proves *time scaling*. If shipping is reliable but only quarterly, throughput investments are wasted work. Weekly cadence is what earns them.

**Verifiable in one sentence:** *"For four consecutive weeks, exactly one new game crossed from G1 to G3 each week."*

**Self-improvement debt:** parallel swarm core (Sahil stops being the per-pass bottleneck), sharded brain (context window unlock), factory-as-installable-skill (bus factor below 1), unified workflows-base (no per-game workflow copies), distribution as a tracked workstream.

**Issues that belong to F3:** #11, #12, #14, #28

---

### F4 — Portfolio scale: five new games per week

**Outcome:** The factory creates and ships five new games per week, sustained, with no two of them touched by Sahil's hands.

**Why it matters:** This is the north-star asymptote — the point at which the factory is no longer a game-building helper but a category-defining studio whose marginal cost of game N approaches zero. The exact number is debatable; the order of magnitude is what matters.

**Verifiable in one sentence:** *"Five new games crossed G3 in the past week, none touched by Sahil's hands."*

**Self-improvement debt:** multi-harness adapter (factory not bound to Claude Code), federated MCP (agents independent of one brain), genre packs as drop-in modules, content/competitor/UA pipelines on cadence per game without inline reasoning.

**Issues that belong to F4:** #16, #18

**The gate principle in action:** F4's entire engineering scope is forbidden until F3 is complete. None of the F4 issues get built today — they sit in the queue and wait.

---

## G-series — per-game milestones

Generic template every game inherits. Each game has its own G-pointer. Tracked as GitHub milestones on each game repo.

### G1 — Foundation
**Outcome:** The game is buildable, the architecture supports iteration, the core loop works end-to-end on desktop web. New issues can be built without architectural surgery.
**Verifiable:** *"One full round on desktop with no console errors, and a feature PR can land without rewriting any subsystem."*

### G2 — Distributable beta
**Outcome:** Packaged for web + iOS + Android. Signed builds. Store listings drafted. Ads stubbed in test mode. **Not yet submitted.**
**Verifiable:** *"There is a signed iOS build, a signed Android build, a store-listing draft, and ads serve in test mode — but no real users yet."*

### G3 — Launched beta with real data
**Outcome:** Live in at least one real channel (TestFlight / Play Internal / production). At least 10 real installs. Telemetry flowing back into the factory as `analytics-data` issues.
**Verifiable:** *"Real humans have downloaded the game and at least one `[product]` issue is filed from real telemetry."*

### G4 — First liveops cycle complete
**Outcome:** The factory has ingested real player data, generated a data-backed improvement, shipped it, and observed the change in the *next* round of telemetry. The closed loop is real once.
**Verifiable:** *"Player data → factory issue → shipped fix → measured impact in the next data pull."*

### G5 — Cadence on autopilot
**Outcome:** Product, UA, monetization, content, and competitor agents fire on a fixed cadence per game **without consuming inline tokens** (forked into isolated subagents, not inline). The game has a self-sustaining improvement rhythm.
**Verifiable:** *"For two consecutive weeks, the game received fresh agent-driven improvements without Sahil starting them manually."*

---

## Current state (2026-04-14)

### Factory: F1 (declared)

Every game in the portfolio is being lifted toward the F1 outcome regardless of where it started. The path differs per game; the destination is the same.

### Per-game state

| Game | G-stage | F1 entry path |
|---|---|---|
| **Arrow Puzzle** | G1 (mobile-blank regression blocking G2) | Heal mobile blank → smoke gate → Capacitor wrap → signing → store listing → ads → submission. Has Ripon's real testing rhythm — strongest natural F1 path. |
| **House Mafia** | G1 (sprints rapidly maturing the foundation) | Complete current sprint plan → smoke gate → Capacitor wrap → signing → store listing → ads (currently zero) → privacy policy (Supabase data handling = compliance question) → submission. |
| **Bloxplode** | ~G3 (live on Google Play, awaiting Apple approval) | **Retroactive harmonization only — NO major refactor.** Get Apple approval through, validate ad placements in production (existing #15/#16/#17 monetization issues handled cautiously), confirm privacy policy live, confirm store listing matches UA #18. Maintain working state — fix-around-it only. |

The Bloxplode constraint exists because the game predates the factory pipeline and was built non-architecturally. It works, it's published, and the cost of breaking it through a major refactor exceeds any benefit. Tracked as a swarm-state note for persistence.

### F1 completion criteria (combined)

F1 is complete when **at least one** of the three games has crossed the F1 outcome line — live, downloadable, monetized, compliant, on at least one real store — **AND** the self-improvement debt has been paid (the capabilities surfaced reaching F1 are encoded into the brain). The other two games continue progressing under the same milestone. Once both clauses are satisfied, the factory advances to F2.
