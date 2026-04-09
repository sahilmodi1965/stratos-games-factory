# Stratos Games Factory

> **Humans test. AI builds. Games ship.**

An autonomous build pipeline for the Stratos Games portfolio. Play-testers file GitHub Issues describing what to fix or improve. An hourly cron daemon picks them up, runs Claude Code against the right game repo, and opens a PR. A human reviewer merges.

This repo is the **factory** — not a game. It operates on game repos.

## Games it currently builds

| Game | Repo | Build target |
|---|---|---|
| **Arrow Puzzle** | [mody-sahariar1/arrow-puzzle-testing](https://github.com/mody-sahariar1/arrow-puzzle-testing) | GitHub Pages (web) |
| **Bloxplode** | [mody-sahariar1/Bloxplode-Beta](https://github.com/mody-sahariar1/Bloxplode-Beta) | Capacitor (Android) |

Adding a new game takes one command — see [Add a new game](#add-a-new-game).

## How it works

```
Ripon plays → files build-request issue → daemon (hourly cron) → claude -p → PR → Sahil merges → ships
```

1. A human play-tester (Ripon) finds something — a bug, a tuning tweak, a small feature — and opens a GitHub Issue on the game's repo using the **Build Request** template.
2. They label it `build-request` (the template does this automatically).
3. Within an hour, the Stratos daemon running on Sahil's MacBook picks it up. It runs Claude Code in print mode (`claude -p`), bound by the game's `CLAUDE.md`, with the issue body as the brief.
4. Claude makes the smallest possible change, runs the build, and the daemon pushes a branch and opens a PR that closes the issue.
5. Sahil (or any reviewer) reviews and merges. For Arrow Puzzle, GitHub Pages ships automatically from `docs/`.
6. Ripon re-tests. If something is still wrong, **a new issue** — not a PR comment — keeps the loop machine-readable.

The whole loop is documented in [`CLAUDE.md`](CLAUDE.md). Non-technical guide for play-testers in [`docs/ripon-guide.md`](docs/ripon-guide.md).

## Architecture principles

- **Humans test and document, machines build, humans review.** Each role is clear and unmixed.
- **The factory holds no state.** Every daemon run starts from `origin/main`. Nothing lives in the daemon's working tree between runs.
- **The brain is the contract.** The daemon's Claude session is bound entirely by what is in the game's `CLAUDE.md`. To change behavior, change the brain and re-deploy.
- **Small, reviewable PRs.** Issues over 50 lines get bounced back as too large.
- **Failure is loud.** Daemon comments on issues and pings Telegram. Silence = success.

## Setup (one-time, on the host machine)

Requirements: `git`, `gh` (authenticated), `claude` (Claude Code CLI, authenticated to a Max plan), `jq`, `node`.

```bash
cd ~
git clone https://github.com/sahilmodi1965/stratos-games-factory.git
cd stratos-games-factory
bash daemon/install.sh
```

`install.sh` will:
1. Verify dependencies.
2. Clone both game repos into `~/stratos-games-factory/` if missing.
3. Create the `build-request`, `building`, `done` labels on every game repo.
4. Run `scripts/deploy-brain.sh` to push the brain + issue templates into each game repo.
5. Install the hourly cron job.
6. Print a status summary.

## Day-to-day

```bash
bash scripts/status.sh             # dashboard: open issues, recent PRs, daemon health
bash daemon/stratos-daemon.sh      # run the daemon manually (instead of waiting for cron)
tail -f build.log                  # watch the daemon work
```

## Add a new game

```bash
bash scripts/add-game.sh owner/repo-name "Short description of the game"
```

This clones the repo, registers it in `daemon/config.sh`, creates the labels, deploys a starter brain, and installs the issue template. After this, the game is live in the factory loop on the next cron tick.

## Configuration

`daemon/config.sh` is the central config. It defines:

- `GAME_REPOS` — the games the daemon operates on.
- `TELEGRAM_BOT_TOKEN` / `TELEGRAM_CHAT_ID` — optional notifications. Override in `daemon/config.local.sh` (gitignored).
- Paths and limits (issue size cap, timeouts).

## Repository layout

```
stratos-games-factory/
├── CLAUDE.md                            # the brain — read this if you are an AI agent
├── README.md                            # ← you are here
├── daemon/
│   ├── stratos-daemon.sh                # hourly cron loop
│   ├── install.sh                       # one-shot host setup
│   └── config.sh                        # game list, telegram, paths
├── brain/
│   ├── arrow-puzzle-autobuilder.md      # appended to Arrow Puzzle CLAUDE.md
│   └── bloxplode-claude.md              # full CLAUDE.md for Bloxplode
├── templates/
│   └── build-request.md                 # issue template deployed to every game
├── scripts/
│   ├── deploy-brain.sh                  # push brain + templates to all game repos
│   ├── add-game.sh                      # onboard a new game
│   └── status.sh                        # dashboard
└── docs/
    └── ripon-guide.md                   # non-technical guide for play-testers
```

## License

Internal Stratos Games tooling. Not open for external contributions yet.
