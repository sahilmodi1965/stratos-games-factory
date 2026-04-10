# Stratos Games Factory

> **Humans test. AI builds. Games ship.**

[![Builder](https://img.shields.io/badge/builder-active-1f883d?style=flat-square)](agents/README.md)
[![Council](https://img.shields.io/badge/council-active-1f883d?style=flat-square)](council/COUNCIL.md)
[![QA](https://img.shields.io/badge/qa-active-1f883d?style=flat-square)](agents/qa/)
[![Content](https://img.shields.io/badge/content-active-1f883d?style=flat-square)](agents/content/)
[![Competitor](https://img.shields.io/badge/competitor-active-1f883d?style=flat-square)](agents/competitor/)
[![Platform](https://img.shields.io/badge/platform-active-1f883d?style=flat-square)](agents/platform/)
[![Product](https://img.shields.io/badge/product-planned-8957e5?style=flat-square)](agents/product/)
[![Monetization](https://img.shields.io/badge/monetization-planned-8957e5?style=flat-square)](agents/monetization/)
[![UA](https://img.shields.io/badge/ua-planned-8957e5?style=flat-square)](agents/ua/)

An autonomous game studio that runs as a swarm of small agents. Each agent has one job, talks to the others through GitHub issues, and stays out of everyone else's way. The factory currently runs **6 active agents** and has **3 more on the spec board**.

This repo is the **factory** — not a game. It operates on game repos.

## Games in production

| Game | Repo | Stack | Live URL |
|---|---|---|---|
| **Arrow Puzzle** | [mody-sahariar1/arrow-puzzle-testing](https://github.com/mody-sahariar1/arrow-puzzle-testing) | Vanilla JS + Vite + Canvas | https://mody-sahariar1.github.io/arrow-puzzle-testing/ |
| **Bloxplode** | [mody-sahariar1/Bloxplode-Beta](https://github.com/mody-sahariar1/Bloxplode-Beta) | HTML/CSS/JS in `www/` + Capacitor (Android) | https://mody-sahariar1.github.io/Bloxplode-Beta/ |

Add a new game with one command — see [Adding a game](#adding-a-game).

## Agent roster

The factory is a swarm. Every autonomous behavior is an agent registered in [`agents/registry.json`](agents/registry.json). Adding a new one is a folder + a registry entry + (if it needs a schedule) one cron line.

### Active agents

| Agent | Schedule | Owns | Reads | Writes |
|---|---|---|---|---|
| [**builder**](daemon/) | hourly | the autonomous-build loop | `build-request` issues + game CLAUDE.md | branches, PRs, issue labels |
| [**council**](council/) | Sunday 00:00 | the factory's living memory | `build.log` + closed issues / PRs | `COUNCIL.md`, `archive.md`, council issues |
| [**qa**](agents/qa/) | every PR | cheap visual smoke tests (Playwright) | PR diff + built game | PR comments, screenshot artifacts |
| [**content**](agents/content/) | Wednesday 00:00 | filling the content pipeline | game CLAUDE.md + existing levels | `build-request` + `content-agent` issues |
| [**competitor**](agents/competitor/) | Tuesday 00:00 | market intelligence | trending-game web search | `market-intel` issues |
| [**platform**](agents/platform/) | on `ship-it` | native APK / IPA build | `main` + Capacitor projects | `release-ready` issues + release artifacts |

### Planned agents (specs in their READMEs, scripts not built yet)

| Agent | When | Will own | Spec |
|---|---|---|---|
| [**product**](agents/product/) | Monday 00:00 | data-backed improvement issues from Firebase Analytics + Crashlytics | [`agents/product/README.md`](agents/product/README.md) |
| [**monetization**](agents/monetization/) | Monday 00:00 | AdMob revenue optimization issues | [`agents/monetization/README.md`](agents/monetization/README.md) |
| [**ua**](agents/ua/) | on release | localized store listings, ASO keywords, screenshot copy | [`agents/ua/README.md`](agents/ua/README.md) |

## How the swarm works

```
   Ripon plays a game             Trending market signal       Player telemetry           Native release
        │                                  │                          │                         │
        ▼                                  ▼                          ▼                         ▼
   ┌─────────────┐                  ┌─────────────┐           ┌─────────────┐          ┌─────────────┐
   │ build-      │                  │ market-     │           │ product-    │          │  ship-it    │
   │ request     │                  │ intel       │           │ data        │          │   label     │
   │ issue       │                  │ issue       │           │ issue       │          │             │
   └──────┬──────┘                  └──────┬──────┘           └──────┬──────┘          └──────┬──────┘
          │                                │                         │                        │
          │  builder agent (hourly)        │  human triage           │  human triage          │  platform agent
          │  picks it up                   │                         │                        │
          ▼                                │                         │                        ▼
   ┌─────────────┐                         │                         │                ┌─────────────┐
   │ Claude reads│                         │                         │                │ npx cap sync│
   │ CLAUDE.md,  │                         │                         │                │ gradle build│
   │ implements  │                         │                         │                │ release-    │
   │             │                         │                         │                │ ready issue │
   └──────┬──────┘                         │                         │                └──────┬──────┘
          ▼                                ▼                         ▼                       ▼
   ┌─────────────┐                ┌─────────────────────────────────────┐         ┌─────────────────┐
   │ auto/* PR   │  ← qa agent →  │  human triage promotes the best     │         │ Ripon submits  │
   │ + qa smoke  │                │  market-intel and product-data      │         │ to Play /       │
   │ + auto-     │                │  issues to build-request, where     │         │ App Store       │
   │ merge       │                │  the builder picks them up too      │         └─────────────────┘
   └──────┬──────┘                └─────────────────────────────────────┘
          │
          ▼
   ┌─────────────┐
   │ merged →    │
   │ deployed →  │
   │ live URL    │
   └─────────────┘
```

The agents only know about each other through **labels on GitHub issues**. There is no shared database, no inter-agent RPC, no orchestrator. Adding an agent adds one folder. Removing one removes one folder. The system scales by addition, not by integration.

## The weekly rhythm

| Day | Agent | What happens |
|---|---|---|
| **Monday** | _(product + monetization, when built)_ | Cohort retention + ad RPM analysis files data-backed improvement issues |
| **Tuesday** | competitor | Web search for trending puzzle/casual games, files `market-intel` issues |
| **Wednesday** | content | Generates 5 content ideas per game, files `build-request` issues |
| **Thursday-Saturday** | builder + qa + auto-merge | Drains the build queue, ships safe-path PRs |
| **Sunday** | council | Reviews the week, prunes COUNCIL.md, files architectural improvement issues |
| **Hourly, every day** | builder | Picks up `build-request` issues from any source and ships PRs |
| **On every PR** | qa | Playwright smoke test, screenshot artifact, PR comment |
| **On `ship-it` label** | platform | Native build, files `release-ready` issue with APK/AAB links |

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
5. Install all active-agent crons (builder hourly, council Sunday, competitor Tuesday, content Wednesday).
6. Print the agent registry status.
7. Print the dashboard.

## Day-to-day operations

```bash
bash scripts/status.sh                     # rich dashboard: queues, builds, errors, aggregates
bash daemon/stratos-daemon.sh              # run the builder manually
bash council/review.sh                     # run the weekly council manually
bash agents/content/content-agent.sh       # run the content agent manually
bash agents/competitor/competitor-agent.sh # run the competitor agent manually
bash agents/platform/platform-agent.sh     # run native builds
tail -f build.log                          # watch the builder
tail -f agents/content/content-agent.log   # watch any agent
```

## Adding a game

```bash
bash scripts/add-game.sh owner/repo-name "Short description of the game"
```

This clones the repo, registers it in `daemon/config.sh`, creates the labels, deploys the lean CLAUDE.md + workflows + QA assets + PR template + dashboard, and installs the issue template. After this, the game is live in the factory loop on the next cron tick.

## Adding an agent

```
agents/myagent/
├── README.md         ← what it does, when it runs, what data, what output
└── myagent-agent.sh  ← the script (or, for passive agents, a reference to the GH Actions workflow)
```

Then:
1. Add the agent to `agents/registry.json` with status `active` or `planned`.
2. If it needs a cron, add a line to `daemon/install.sh` and re-run install.
3. Done. No other code touches the new agent — it interacts via GitHub issues like everyone else.

See [`agents/README.md`](agents/README.md) for the full design rationale.

## Configuration

`daemon/config.sh` is the central config. It defines:

- `GAME_REPOS` — the games every agent operates on (format: `owner/repo|local_dir|kind|branch|build_cmd|forbidden_paths`).
- Cron-friendly limits (issue size cap, max issues per run, claude timeout).
- Filter env vars: `REPO_FILTER`, `ISSUE_FILTER` for one-off manual runs.

Secrets and per-machine overrides go in `daemon/config.local.sh` (gitignored).

## Repository layout

```
stratos-games-factory/
├── README.md                            ← you are here
├── CLAUDE.md                            ← the brain (read this if you are an AI agent)
│
├── agents/                              ← the agent swarm
│   ├── README.md                        ← agent design rationale
│   ├── registry.json                    ← authoritative agent list
│   ├── qa/                              ← Playwright smoke tests on every PR
│   ├── content/                         ← weekly content idea generator
│   ├── competitor/                      ← weekly market intelligence scanner
│   ├── platform/                        ← native APK/IPA builds on release
│   ├── product/                         ← (planned) Firebase data → improvement issues
│   ├── monetization/                    ← (planned) AdMob data → ad-placement optimizations
│   └── ua/                              ← (planned) store listings on release
│
├── daemon/                              ← the original "builder" agent (predates agents/)
│   ├── stratos-daemon.sh                ← hourly cron loop
│   ├── install.sh                       ← one-shot host setup
│   ├── config.sh                        ← game list, paths, limits
│   └── config.local.sh                  ← gitignored secrets (GH_TOKEN, telegram, etc.)
│
├── council/                             ← the original "council" agent (predates agents/)
│   ├── review.sh                        ← weekly self-audit
│   ├── COUNCIL.md                       ← living memory
│   └── archive.md                       ← retired entries
│
├── templates/                           ← everything deployed to game repos
│   ├── claude-arrow-puzzle.md           ← lean CLAUDE.md per game
│   ├── claude-bloxplode.md
│   ├── build-request.md                 ← issue template
│   ├── pull_request_template.md         ← PR template
│   ├── readme-dashboard-arrow-puzzle.md ← dashboard injected at top of game README
│   ├── readme-dashboard-bloxplode.md
│   ├── workflows-arrow-puzzle/          ← GitHub Actions for Arrow Puzzle
│   │   ├── ci.yml                       ← npm install + npm run build
│   │   ├── pr-preview.yml               ← deploy PR build to gh-pages /pr/N/
│   │   ├── deploy.yml                   ← mirror main → gh-pages
│   │   ├── auto-merge.yml               ← merge daemon PRs after CI
│   │   ├── release.yml                  ← ship-it label → release
│   │   ├── cleanup.yml                  ← weekly auto/* sweep
│   │   └── qa-agent.yml                 ← Playwright smoke test on every PR
│   ├── workflows-bloxplode/             ← same set, customized for Bloxplode
│   ├── qa-assets/                       ← Playwright spec + config per game
│   └── scripts-arrow-puzzle/            ← validate-paths.js, validate-difficulty.js, validate.js
│
├── scripts/
│   ├── deploy-brain.sh                  ← push everything in templates/ into each game repo
│   ├── add-game.sh                      ← onboard a new game
│   └── status.sh                        ← rich dashboard
│
├── brain/                               ← historical reference (no longer load-bearing)
│   ├── arrow-puzzle-autobuilder.md
│   └── bloxplode-claude.md
│
└── docs/
    └── ripon-guide.md                   ← non-technical guide for play-testers
```

## License

Internal Stratos Games tooling. Not open for external contributions yet.
