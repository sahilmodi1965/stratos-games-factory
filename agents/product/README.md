# product agent

**Status**: active
**Dispatch**: swarm-inline (runs in Claude Code session when Sahil says "go")
**Label**: `product-data`

## What it does

Analyzes player behavior data and files **data-backed improvement issues** on game repos. Unlike the content agent (ideas from pattern-matching) and the competitor agent (ideas from external trends), the product agent generates ideas from **actual player behavior** in our own games.

## Data sources (priority order)

1. **`analytics-data` issues from Ripon** — Ripon pastes screenshots, CSVs, or text summaries of Firebase Analytics / Play Console data into issues labeled `analytics-data`. This is the primary input.
2. **Firebase CLI** (if available) — pulls analytics directly. Falls back gracefully if not installed.
3. **Game code analysis** — reads level/difficulty config to map analytics data to specific game elements.

## What it produces

For each game, analyzes data for drop-off points, session length patterns, retry spikes, and feature engagement. Files up to **3 issues per game**, each labeled `build-request` + `product-data`, with:
- Raw stats cited in the body
- Specific files and config values to change
- Concrete proposed fix

## Known limitations

- Without `analytics-data` issues from Ripon or Firebase CLI, the agent skips with a suggestion for Ripon to file data.
- During beta testing with very few users, analytics may be noisy — the agent notes low confidence when sample sizes are small.

## Expected impact

Once live, this will become the **highest-leverage agent in the system** because every suggestion comes with hard evidence: "Level 7 has a 12% completion rate vs 68% avg, suggesting the difficulty jump is too steep — fix: reduce blocker count from 4 to 2 in `difficulty-config.js` tier 3." No agent inventing from nothing, no human guessing — just real player data → specific file changes.

## Interaction with other agents

- Builder agent will pick up `product-data` issues if a human re-labels them as `build-request` (same pattern as `market-intel` issues). This preserves the "human is in the loop for what ships" principle.
- Council agent will include product-data findings in its weekly review and may cross-reference them with the factory's own build failures ("did we regress the level we were supposed to fix?").
