# competitor agent

**Status**: active
**Schedule**: weekly, Tuesday 00:00 UTC
**Cost**: one Claude `--effort max` session per run (with web search enabled)

## What it does

Scans the casual / puzzle game market each week and files evidence-backed market intelligence on each Stratos game. Every Tuesday the agent asks Claude to:

1. Search the web for trending puzzle games on the App Store and Play Store this week.
2. Search for trending casual game mechanics being discussed in game-dev communities.
3. Identify 3-5 concrete mechanics that are clearly working right now.
4. For each active Stratos game, propose **3 specific mechanic adaptations** that fit the existing architecture of that game.
5. File one `market-intel` issue per game with the findings.
6. File a summary issue on the factory repo with the cross-portfolio view.

## What makes a good suggestion

Not: *"add social features"*, *"add more levels"*, *"make it more engaging"*.

Yes: *"Add a 7-day daily-challenge streak with a fuse-burning timer per level, like [specific game] does in their 'Daily Pulse' mode — fits our existing `SPEED_ROUNDS` scaffold in `difficulty-config.js` and only needs one new HUD element."*

The agent is told to cite specific games by name and specific files in our codebase where the idea would land.

## When it runs

Tuesday 00:00 UTC via cron. Deliberately scheduled **before** the content agent (Wednesday) so the human team has a day to triage market-intel findings and decide which ones the content agent should explicitly target.

## What data it needs

- Web search access (available with Claude Max plan)
- Write access to file issues on the game repos and the factory repo (via `gh issue create`)
- `GH_TOKEN` in env (provided by `daemon/config.local.sh`)

## What it outputs

Per run, the agent files:

- **1 issue per active game** on that game's repo, labeled `market-intel`. Title: `[market-intel] Week of YYYY-MM-DD — 3 mechanics from trending games`. Body contains the 3 specific suggestions with citations.
- **1 summary issue** on `sahilmodi1965/stratos-games-factory`, labeled `market-intel`. Title: `[market-intel] Portfolio scan — week of YYYY-MM-DD`. Body contains the cross-portfolio trends and which suggestions the agent thinks are most impactful.
- **A log entry** in `agents/competitor/competitor-agent.log`.

## Why the suggestions are issues, not PRs

Market intelligence is a **human judgment call**. The agent does not file `build-request` issues for these suggestions — it files `market-intel` issues. A human (Sahil, Ripon) triages them, decides which are worth pursuing, and re-files the chosen ones as `build-request` issues. This keeps the auto-build pipeline focused on concrete, approved work and keeps marketing speculation in a separate queue.

## Guardrails

- If the agent cannot find credible trending-game data in its searches, it files ZERO issues and logs "no signal this week". An honest silence is more valuable than invented recommendations.
- The agent never cites games that don't exist in real app stores.
- The agent never proposes mechanics that would require bumping dependencies or introducing new build steps.
