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

## Architecture in one diagram

```
   Human (Ripon)                  GitHub Issue                 Daemon (cron)
       │                              │                             │
       │  play-test                   │                             │
       ├─────────────────►            │                             │
       │                              │                             │
       │  open issue                  │                             │
       │  label: build-request        │                             │
       ├─────────────────────────────►│                             │
       │                              │  hourly poll                │
       │                              │◄────────────────────────────┤
       │                              │                             │
       │                              │  claude -p (Max plan)       │
       │                              │  reads game CLAUDE.md       │
       │                              │  makes targeted change      │
       │                              │  runs build                 │
       │                              │                             │
       │                              │  push branch + open PR      │
       │                              │◄────────────────────────────┤
       │                              │                             │
       │  test PR build                                              │
       │◄─────────────────────────────┤                             │
       │                                                            │
       │  Sahil reviews & merges                                    │
       └────────────────────────────────────────────────────────────┘
```

## How the daemon works

`daemon/stratos-daemon.sh` is the loop. It runs hourly via cron:

1. For each game in `daemon/config.sh`:
   1. `git fetch` + `reset --hard origin/main` the local clone (the daemon never carries local state).
   2. `gh issue list --label build-request --state open` to find work.
   3. For each open issue not already labeled `building` or `done`:
      - Reject if body is >50 lines (too large for automation; comment & skip).
      - Create branch `auto/{game}-issue-{num}-{timestamp}`.
      - Label the issue `building`.
      - Run `claude -p` with a structured prompt that **forces it to read CLAUDE.md first** and then execute the issue.
      - If the working tree changed: push branch, open PR with `Closes #N`, label issue `done`, comment with PR link.
      - If nothing changed: comment on the issue explaining why, remove `building` label, leave `build-request` so a human can intervene.
      - Telegram notification at each transition (if configured).
2. A lockfile (`.daemon.lock`) prevents overlapping runs.
3. Everything goes to `build.log`.

## Rules for daemon Claude sessions

When you (Claude) are invoked by the daemon, you operate under tight constraints:

1. **Read the game repo's `CLAUDE.md` first.** If there is no `CLAUDE.md`, stop. The factory deploys one to every game; its absence means the brain hasn't been deployed yet.
2. **Only do what the issue asks.** No bonus refactors. No "while I'm here" cleanups. No comments or docstrings on code you didn't change.
3. **Conventional commits, one logical change per commit, every message references the issue number** (`fix: arrow rotation snap on touch end #42`).
4. **Hard exclusions** — do not edit:
   - `packages/*` in Arrow Puzzle (cross-game shared kit; needs human review).
   - `android/*` in Bloxplode (native build artifacts).
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
3. Creates the `build-request` / `building` / `done` labels on the repo.
4. Pushes a starter `CLAUDE.md` if none exists, plus the issue template.

## Architecture principles

- **Humans test and document, machines build, humans review.** Anything that violates this is wrong.
- **The factory never holds state.** Every daemon run starts from `origin/main`. There is no local "work in progress" — if it's not in a PR, it doesn't exist.
- **The brain is the contract.** The daemon's Claude session is bound entirely by what is in the game's `CLAUDE.md`. To change daemon behavior on a game, change that game's `CLAUDE.md` and re-run `scripts/deploy-brain.sh`.
- **Small, reviewable PRs.** The 50-line issue cap is a feature, not a limitation. Big requests get split.
- **Failure is loud.** If something breaks, the daemon comments on the issue and pings Telegram. Silence means success.

## The feedback → build → deploy → test loop

1. **Feedback.** Ripon plays the game, finds a thing, files an issue using the `build-request` template.
2. **Build.** Within an hour, the daemon picks it up, makes the change, opens a PR.
3. **Deploy.** Sahil reviews. If good, merges. For Arrow Puzzle, `npm run deploy` ships to GitHub Pages.
4. **Test.** Ripon re-tests on the live build. If wrong, files a new issue with corrections (not a comment on the merged PR — a fresh issue keeps the loop machine-readable).

This loop is the entire system. Everything else is plumbing.

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
│   └── build-request.md                 ← issue template deployed to every game
├── scripts/
│   ├── deploy-brain.sh                  ← push brain + templates to all game repos
│   ├── add-game.sh                      ← onboard a new game repo
│   └── status.sh                        ← dashboard
└── docs/
    └── ripon-guide.md                   ← non-technical guide for the play-tester
```
