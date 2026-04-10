# Stratos Games Factory

> **Humans test. AI builds. Games ship.**

[![Builder](https://img.shields.io/badge/builder-active-1f883d?style=flat-square)](agents/README.md)
[![Council](https://img.shields.io/badge/council-active-1f883d?style=flat-square)](council/COUNCIL.md)
[![QA](https://img.shields.io/badge/qa-active-1f883d?style=flat-square)](agents/qa/)
[![Content](https://img.shields.io/badge/content-active-1f883d?style=flat-square)](agents/content/)
[![Competitor](https://img.shields.io/badge/competitor-active-1f883d?style=flat-square)](agents/competitor/)
[![Platform](https://img.shields.io/badge/platform-active-1f883d?style=flat-square)](agents/platform/)
[![Product](https://img.shields.io/badge/product-active-1f883d?style=flat-square)](agents/product/)
[![Monetization](https://img.shields.io/badge/monetization-active-1f883d?style=flat-square)](agents/monetization/)
[![UA](https://img.shields.io/badge/ua-active-1f883d?style=flat-square)](agents/ua/)

An autonomous game studio that runs as a swarm of **9 active agents**. Sahil opens Claude Code, says **"go"**, and the swarm assesses pending work, builds issues, analyzes player data, optimizes monetization, generates content ideas, scans the competition, prepares store listings, and reviews the week — all from a single session.

This repo is the **factory** — not a game. It operates on game repos.

## Games in production

| Game | Repo | Stack | Live URL |
|---|---|---|---|
| **Arrow Puzzle** | [mody-sahariar1/arrow-puzzle-testing](https://github.com/mody-sahariar1/arrow-puzzle-testing) | Vanilla JS + Vite + Canvas | https://mody-sahariar1.github.io/arrow-puzzle-testing/ |
| **Bloxplode** | [mody-sahariar1/Bloxplode-Beta](https://github.com/mody-sahariar1/Bloxplode-Beta) | HTML/CSS/JS in `www/` + Capacitor (Android) | https://mody-sahariar1.github.io/Bloxplode-Beta/ |

Add a new game with one command — see [Adding a game](#adding-a-game).

## Agent roster

The factory is a swarm. Every autonomous behavior is an agent registered in [`agents/registry.json`](agents/registry.json). Adding a new one is a folder + a registry entry.

### Active agents

| Agent | Dispatch | Owns | Reads | Writes |
|---|---|---|---|---|
| [**builder**](daemon/) | swarm (subagent per issue) | implementing build-request issues | `build-request` issues + game CLAUDE.md | branches, PRs, issue labels |
| [**council**](council/) | swarm (inline) | the factory's living memory | `build.log` + closed issues / PRs | `COUNCIL.md`, `archive.md`, council issues |
| [**qa**](agents/qa/) | GitHub Actions (every PR) | cheap visual smoke tests (Playwright) | PR diff + built game | PR comments, screenshot artifacts |
| [**content**](agents/content/) | swarm (inline) | filling the content pipeline | game CLAUDE.md + existing levels | `build-request` + `content-agent` issues |
| [**competitor**](agents/competitor/) | swarm (inline) | market intelligence | trending-game web search | `market-intel` issues |
| [**platform**](agents/platform/) | manual | native APK / IPA build | `main` + Capacitor projects | `release-ready` issues + release artifacts |
| [**product**](agents/product/) | swarm (inline) | player data analysis | `analytics-data` issues + Firebase CLI + game config | `build-request` + `product-data` issues |
| [**monetization**](agents/monetization/) | swarm (inline) | ad placement optimization | game ad integration code + best practices | `build-request` + `monetization-data` issues |
| [**ua**](agents/ua/) | swarm (inline) | store listing assets | game features + release changelog | `ua-assets` issues |

## How the swarm works

```
   Ripon plays a game             Trending market signal       Player telemetry           Native release
        |                                  |                          |                         |
        v                                  v                          v                         v
   +--------------+                 +--------------+           +--------------+          +--------------+
   | build-       |                 | market-      |           | product-     |          |  ship-it     |
   | request      |                 | intel        |           | data         |          |   label      |
   | issue        |                 | issue        |           | issue        |          |              |
   +------+-------+                 +------+-------+           +------+-------+          +------+-------+
          |                                |                         |                        |
          |  Sahil says "go"               |  human triage           |  human triage          |  platform agent
          |  in Claude Code                |                         |                        |
          v                                |                         |                        v
   +--------------+                        |                         |                +--------------+
   | builder      |                        |                         |                | npx cap sync |
   | subagent     |                        |                         |                | gradle build |
   | reads game   |                        |                         |                | release-     |
   | CLAUDE.md    |                        |                         |                | ready issue  |
   +------+-------+                        |                         |                +------+-------+
          v                                v                         v                       v
   +--------------+                +--------------------------------------+         +------------------+
   | auto/* PR    |  <- qa agent -> |  human triage promotes the best      |         | Ripon submits    |
   | + qa smoke   |                 |  market-intel and product-data       |         | to Play /        |
   | + auto-      |                 |  issues to build-request, where      |         | App Store        |
   | merge        |                 |  the builder picks them up too       |         +------------------+
   +------+-------+                 +--------------------------------------+
          |
          v
   +--------------+
   | merged ->    |
   | deployed ->  |
   | live URL     |
   +--------------+
```

The agents only know about each other through **labels on GitHub issues**. There is no shared database, no inter-agent RPC. The swarm orchestrator (Claude Code session) runs them in priority order. Adding an agent adds one folder. Removing one removes one folder. The system scales by addition, not by integration.

## Running the swarm

The primary way to operate the factory:

```bash
# Open Claude Code in the factory directory
cd ~/stratos-games-factory
claude

# Then say "go" — the swarm takes over
```

Claude Code reads `CLAUDE.md`, assesses pending work across all games, and runs each agent in priority order:
1. **Builder** — processes Ripon's build-request issues (highest priority)
2. **Product** — analyzes player data from Ripon's `analytics-data` issues
3. **Monetization** — reviews ad placement config and suggests optimizations
4. **Content** — generates content ideas if none filed in past 7 days
5. **Competitor** — scans market trends if no intel filed in past 7 days
6. **UA** — generates store listing assets when approaching release
7. **Council** — reviews the week if no review in past 7 days

You can also run individual agents: "just run the builder", "run product analysis", "run UA prep", etc.

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
2. Clone every game repo into `~/stratos-games-factory/` if missing.
3. Create the `build-request`, `building`, `done`, `ship-it`, `auto-merged` labels on every game repo.
4. Run `scripts/deploy-brain.sh` to push the brain + workflows + QA assets + PR template + README dashboard into each game repo.
5. Print the agent registry status and dashboard.

## Day-to-day operations

```bash
claude                                     # open Claude Code, say "go" to run the swarm
bash scripts/status.sh                     # rich dashboard: queues, builds, errors, aggregates
bash agents/platform/platform-agent.sh     # run native builds (manual, not part of swarm)
tail -f build.log                          # watch legacy build logs
```

## Adding a game

```bash
bash scripts/add-game.sh owner/repo-name "Short description of the game"
```

This clones the repo, registers it in `daemon/config.sh`, creates the labels, deploys the lean CLAUDE.md + workflows + QA assets + PR template + dashboard, and installs the issue template. After this, the game is live in the swarm on the next "go".

## Adding an agent

```
agents/myagent/
├── README.md         <- what it does, when it runs, what data, what output
└── myagent-agent.sh  <- the script (or reference to GH Actions workflow)
```

Then:
1. Add the agent to `agents/registry.json` with status `active` or `planned` and the appropriate `dispatch` type.
2. Add the agent's logic to the swarm mode section of `CLAUDE.md`.
3. Done. No other code touches the new agent — it interacts via GitHub issues like everyone else.

See [`agents/README.md`](agents/README.md) for the full design rationale.

## Configuration

`daemon/config.sh` is the central config. It defines:

- `GAME_REPOS` — the games every agent operates on (format: `owner/repo|local_dir|kind|branch|build_cmd|forbidden_paths`).
- Limits (issue size cap, max issues per run, claude timeout).
- Filter env vars: `REPO_FILTER`, `ISSUE_FILTER` for one-off manual runs of legacy scripts.

Secrets and per-machine overrides go in `daemon/config.local.sh` (gitignored).

## Repository layout

```
stratos-games-factory/
├── README.md                            <- you are here
├── CLAUDE.md                            <- the swarm brain (read this if you are an AI agent)
│
├── agents/                              <- the agent swarm
│   ├── README.md                        <- agent design rationale
│   ├── registry.json                    <- authoritative agent list
│   ├── qa/                              <- Playwright smoke tests on every PR
│   ├── content/                         <- content idea generator (swarm inline)
│   ├── competitor/                      <- market intelligence scanner (swarm inline)
│   ├── platform/                        <- native APK/IPA builds on release (manual)
│   ├── product/                         <- (planned) Firebase data -> improvement issues
│   ├── monetization/                    <- (planned) AdMob data -> ad-placement optimizations
│   └── ua/                              <- (planned) store listings on release
│
├── daemon/                              <- config + legacy builder scripts
│   ├── stratos-daemon.sh                <- (deprecated) hourly cron loop
│   ├── install.sh                       <- one-shot host setup
│   ├── config.sh                        <- game list, paths, limits (still active)
│   └── config.local.sh                  <- gitignored secrets (GH_TOKEN, telegram, etc.)
│
├── council/                             <- factory self-audit
│   ├── review.sh                        <- (deprecated) cron-based council review
│   ├── COUNCIL.md                       <- living memory
│   └── archive.md                       <- retired entries
│
├── templates/                           <- everything deployed to game repos
│   ├── claude-arrow-puzzle.md           <- lean CLAUDE.md per game
│   ├── claude-bloxplode.md
│   ├── build-request.md                 <- issue template
│   ├── pull_request_template.md         <- PR template
│   ├── readme-dashboard-arrow-puzzle.md <- dashboard injected at top of game README
│   ├── readme-dashboard-bloxplode.md
│   ├── workflows-arrow-puzzle/          <- GitHub Actions for Arrow Puzzle
│   │   ├── ci.yml                       <- npm install + npm run build
│   │   ├── pr-preview.yml               <- deploy PR build to gh-pages /pr/N/
│   │   ├── deploy.yml                   <- mirror main -> gh-pages
│   │   ├── auto-merge.yml               <- merge daemon PRs after CI
│   │   ├── release.yml                  <- ship-it label -> release
│   │   ├── cleanup.yml                  <- weekly auto/* sweep
│   │   └── qa-agent.yml                 <- Playwright smoke test on every PR
│   ├── workflows-bloxplode/             <- same set, customized for Bloxplode
│   ├── qa-assets/                       <- Playwright spec + config per game
│   └── scripts-arrow-puzzle/            <- validate-paths.js, validate-difficulty.js, validate.js
│
├── scripts/
│   ├── deploy-brain.sh                  <- push everything in templates/ into each game repo
│   ├── add-game.sh                      <- onboard a new game
│   └── status.sh                        <- rich dashboard
│
├── brain/                               <- historical reference (no longer load-bearing)
│   ├── arrow-puzzle-autobuilder.md
│   └── bloxplode-claude.md
│
└── docs/
    └── ripon-guide.md                   <- non-technical guide for play-testers
```

## License

Internal Stratos Games tooling. Not open for external contributions yet.
