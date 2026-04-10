# content agent

**Status**: active
**Schedule**: weekly, Wednesday 00:00 UTC
**Cost**: one Claude `--effort max` session per game per week

## What it does

Keeps the game content pipeline full. Every Wednesday, for each active game, the agent asks Claude to:

1. Read the game's `CLAUDE.md`.
2. Explore the existing level / content / difficulty code.
3. Understand the format and difficulty curve.
4. Generate **5 new content ideas** that fit the existing patterns — new difficulty variants, new level concepts, new themes, new content types.
5. File each idea as a separate GitHub issue with the `build-request` label on the game's repo.

The `builder` agent (the hourly daemon) picks those issues up and implements them. So every Wednesday morning you effectively get 10 new content ideas queued up that the factory will start building on the next cron tick.

## What the agent does NOT do

- **Never writes code.** Only generates ideas and files issues.
- **Never closes or edits existing issues.** Only creates new ones.
- **Never touches any branch.** It operates purely through the GitHub issues API.
- **Never files duplicate ideas.** The prompt tells Claude to skim recent build-request issues and avoid overlap.

## What data it needs

- Read access to the game's `main` branch (to explore the codebase)
- Write access to file issues on the game's repo (via `gh issue create`)
- `GH_TOKEN` in env (provided by `daemon/config.local.sh`)

## What it outputs

- **Up to 5 new GitHub issues per game** each week, labeled `build-request`.
- **One summary comment** posted on [sahilmodi1965/stratos-games-factory](https://github.com/sahilmodi1965/stratos-games-factory) as an issue comment on a tracking "content agent runs" issue (or filed as a fresh issue with the `content-agent-run` label the first time).
- **A log entry** in `agents/content/content-agent.log` with timestamps and filed issue numbers.

## How ideas get implemented

1. Content agent files issues on Wednesday.
2. Hourly builder daemon picks them up throughout the week (subject to `MAX_ISSUES_PER_REPO_PER_RUN=3`).
3. Each idea becomes a PR within hours of being filed.
4. QA agent runs on each PR.
5. Auto-merge handles safe-path-only PRs; logic PRs wait for human review.
6. By the end of the week, most of that Wednesday batch should be merged.

## Guardrails

- The agent caps at 5 issues per game per run — if Claude tries to file more, the prompt tells it to stop at 5.
- If the agent has already filed more than 10 open `build-request` issues (across all origins) on a game, it skips that game for the week to prevent backlog bloat. The rationale: content shouldn't be queued faster than the builder can process it.
- If `gh auth status` fails, the agent aborts loudly (same preflight as the builder daemon).
