# CLAUDE.md — Stratos Games Factory

The brain of the Stratos Games autonomous build factory. If you are an AI agent (Claude Code, a subagent, the daemon's `claude -p` session, etc.), this file is the source of truth for *how this repo operates*. Read it before doing anything.

Humans should start at `README.md`, then come here.

## What this repo is

Stratos Games Factory is a **meta-repo**. It does not ship a game. It is the autonomous build pipeline that turns human play-test feedback into shipped game changes for every game in the Stratos Games portfolio.

The model:

> **Humans test and document. Machines build. Humans review and ship.**

A human (initially Ripon) plays a game, finds something to fix or improve, and files a GitHub Issue against the *game* repo with the `build-request` label. An hourly cron job on Sahil's MacBook (the **daemon**) wakes up, sees the issue, runs Claude Code against that game's repo with the issue body as the brief, opens a PR, and notifies us. Sahil reviews and merges.

The daemon uses Sahil's Claude Code Max plan, so build cost is fixed.

## Game portfolio

Currently operated on by the factory:

| Game | Repo | Kind | Status |
|---|---|---|---|
| Arrow Puzzle | `mody-sahariar1/arrow-puzzle-testing` | Vanilla JS + Vite, GitHub Pages | live |
| Bloxplode | `mody-sahariar1/Bloxplode-Beta` | Capacitor (web → Android), `www/` | beta |

Adding a new game is a one-shot: `bash scripts/add-game.sh owner/repo "description"`.

## System architecture (the full pipeline)

The factory is the daemon PLUS a set of GitHub Actions workflows deployed into every game repo. They form a single end-to-end pipeline:

```
                ┌─────────────────────── Stratos Games Factory ──────────────────────┐
                │                                                                      │
   Ripon plays  │                              ┌──────────┐                            │
   the live URL │                              │  daemon  │ (hourly cron, Sahil's Mac) │
       │        │                              └────┬─────┘                            │
       │ files  │                                   │                                  │
       │ issue  │                                   │ claude -p (Max plan)             │
       ▼        │                                   ▼                                  │
   ┌──────────┐ │   ┌─────────┐  PR  ┌────────────┐ ┌──────────────┐                   │
   │ GH Issue │─┼──▶│   PR    │─────▶│ pr-preview │ │  ci.yml      │                   │
   │ build-   │ │   │ auto/*  │      │ → /pr/N/   │ │ npm build    │                   │
   │ request  │ │   └────┬────┘      └─────┬──────┘ └──────┬───────┘                   │
   └──────────┘ │        │                 │               │ on success                │
                │        │                 │ comment URL   ▼                           │
                │        │                 └──────────▶ ┌────────────┐                 │
                │        │                              │ auto-merge │ (safe paths     │
                │        │                              │  workflow  │  only: no .js/  │
                │        │                              └─────┬──────┘  .ts/.html)     │
                │        │                                    │                        │
                │        │  not safe → human review           │ safe → merge + label   │
                │        │           ◄────────────────────────┘                        │
                │        ▼                                                             │
                │   ┌──────────┐  push to main   ┌──────────┐                          │
                │   │  merged  │ ──────────────▶ │ deploy   │ → gh-pages root          │
                │   └──────────┘                 └──────────┘                          │
                │                                                                      │
                │   Ripon adds `ship-it` label   ┌──────────┐                          │
                │           ─────────────────▶   │ release  │ → tag, GitHub Release    │
                │                                └──────────┘                          │
                │                                                                      │
                │   Weekly Sunday 00:00 UTC      ┌──────────┐                          │
                │           ─────────────────▶   │ cleanup  │ → prune merged + stale   │
                │                                └──────────┘    auto/* branches       │
                └──────────────────────────────────────────────────────────────────────┘
```

Key facts:
- The **daemon** runs hourly on Sahil's MacBook using his Claude Code Max plan.
- **Ripon and interns** push directly using their own $20 Claude Code Pro plans. Both paths coexist.
- **Auto-merge** ships safe-path-only PRs (CSS, JSON, content, levels, MD) instantly. Logic-touching PRs (.js/.ts/.html) wait for human review.
- The **`ship-it` label** triggers production release on issues OR PRs.
- All workflows are **deployed by `scripts/deploy-brain.sh`** from `templates/workflows-<game>/` — so the factory owns them and re-deploys on every change.

## How the daemon works

`daemon/stratos-daemon.sh` is the loop. It runs hourly via cron:

1. For each game in `daemon/config.sh`:
   1. `git fetch` + `reset --hard origin/main` the local clone (the daemon never carries local state).
   2. Ensure all factory labels exist on the repo (idempotent).
   3. `gh issue list --label build-request --state open` to find work.
   4. For each open issue not already labeled `building` or `done`:
      - Reject if body is >50 lines (too large for automation; comment & skip).
      - **Refetch + reset to origin/main** (catch concurrent human pushes).
      - **Recent-commit dedup**: if the issue title's significant words overlap heavily (3+) with any commit subject from the last 24h, close the issue with a comment ("looks already addressed").
      - Create branch `auto/{game}-issue-{num}-{timestamp}`, label issue `building`.
      - Run `claude -p` with a structured prompt that **forces it to read CLAUDE.md first** and then execute the issue.
      - **Merge-conflict detection**: after Claude commits, refetch and `git rebase origin/main`. If the rebase conflicts, abort, comment on the issue, remove `building`, and leave the issue open for the next run.
      - If the working tree changed and the rebase succeeded: push branch, open PR with `Closes #N`, label issue `done`, comment with PR link.
      - If nothing changed: comment on the issue explaining why, remove `building` label.
      - Telegram notification at each transition (if configured).
2. A lockfile (`.daemon.lock`) prevents overlapping runs.
3. Everything goes to `build.log`.

## Adding a new game (for future interns)

The flow for onboarding a new intern with a new game:

1. **Intern creates a GitHub repo** for their game in their own account or under `mody-sahariar1`.
2. **Intern adds `sahilmodi1965` as a collaborator** with write access. (Required so the daemon can push.)
3. On Sahil's machine:
   ```bash
   cd ~/stratos-games-factory
   bash scripts/add-game.sh owner/their-repo "Short description of the game"
   ```
   This clones the repo, registers it in `config.sh`, creates labels, deploys a starter `CLAUDE.md` and the issue template.
4. **Sahil writes a real `CLAUDE.md`** for the new game (the starter is just a placeholder). Or have Claude write it interactively. Then commit and re-run `scripts/deploy-brain.sh` to deploy the autobuilder section + workflows.
5. **Intern files issues, plays, tests.** The daemon builds them on Sahil's Max plan during hourly runs.
6. **Intern can also push directly** with their own $20 Claude Code Pro plan for quick fixes. The "Direct contributor mode" rules in the deployed `CLAUDE.md` are their guide.
7. **First release**: when the game feels ready, add the `ship-it` label and the release workflow takes over.

This is the entire onboarding for a new collaborator. No new infrastructure, no new accounts, no new keys.

## Cost model

The factory is designed to run at fixed cost regardless of how many games or interns it serves:

- **Sahil**: $200/mo Claude Code Max plan — powers the daemon's autonomous builds AND Sahil's own architecture work.
- **Each collaborator (Ripon, interns)**: $20/mo Claude Code Pro plan + $20/mo Claude Chat (claude.ai) for feedback structuring. Total: $40/mo per person.
- **Infrastructure**: $0. GitHub Pages (free for public repos), GitHub Actions (free tier covers everything we run), no API keys, no Vercel, no AWS, no databases.
- **No external services** of any kind. No third-party CI. No artifact storage. No custom domains. No external monitoring.

The math: 1 Sahil + 2 interns + 5 games still costs ~$280/mo total. Adding a 6th game costs $0. Adding a 3rd intern costs $40/mo. The system scales by adding people, not infrastructure.

## Rules for daemon Claude sessions

When you (Claude) are invoked by the daemon, you operate under tight constraints:

1. **Read the game repo's `CLAUDE.md` first.** If there is no `CLAUDE.md`, stop. The factory deploys one to every game; its absence means the brain hasn't been deployed yet.
2. **Only do what the issue asks.** No bonus refactors. No "while I'm here" cleanups. No comments or docstrings on code you didn't change.
3. **Conventional commits, one logical change per commit, every message references the issue number** (`fix: arrow rotation snap on touch end #42`).
4. **Hard exclusions** — do not edit:
   - `packages/*` in Arrow Puzzle (cross-game shared kit; needs human review).
   - `android/*` and `capacitor.config.json` in Bloxplode (native build artifacts).
   - `prototypes/`, `docs/` (built artifacts), or anything the game's CLAUDE.md flags as off-limits.
5. **Run the build as the final step** (`npm run build` for Arrow Puzzle). If it fails, fix or revert until it passes. Never push a broken build.
6. **If you cannot do the task safely, do nothing.** Output a one-paragraph explanation of why. The daemon will turn that into an issue comment so a human can clarify.

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
- **The factory never holds state.** Every daemon run starts from `origin/main`. There is no local "work in progress" — if it's not in a PR, it doesn't exist.
- **The brain is the contract.** The daemon's Claude session is bound entirely by what is in the game's `CLAUDE.md`. To change daemon behavior on a game, change that game's `CLAUDE.md` and re-run `scripts/deploy-brain.sh`.
- **Daemon and direct-push coexist.** The daemon detects concurrent human pushes via fetch-per-issue, recent-commit dedup, and merge-conflict abort. Humans don't need to coordinate — the daemon adapts.
- **Small, reviewable PRs.** The 50-line issue cap is a feature. Big requests get split.
- **Auto-merge ships safe changes instantly.** Anything touching .js/.ts/.html waits for review. The line between data and logic is the line between auto-merge and manual review.
- **Failure is loud.** If something breaks, the daemon comments on the issue and pings Telegram. Silence means success.
- **Zero infrastructure.** GitHub Pages + GitHub Actions + a Mac running cron. That's the entire stack.

## Files in this repo

```
stratos-games-factory/
├── CLAUDE.md                            ← you are here
├── README.md                            ← human entry point
├── daemon/
│   ├── stratos-daemon.sh                ← the cron loop
│   ├── install.sh                       ← one-shot setup
│   └── config.sh                        ← game list, telegram config, paths
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
├── scripts/
│   ├── deploy-brain.sh                  ← push brain + workflows + labels to all game repos
│   ├── add-game.sh                      ← onboard a new game repo
│   └── status.sh                        ← rich dashboard
└── docs/
    └── ripon-guide.md                   ← non-technical guide for the play-tester
```
