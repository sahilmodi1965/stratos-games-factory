# ua (user acquisition) agent

**Status**: active
**Dispatch**: swarm-inline (runs in Claude Code session when Sahil says "go" or "run UA prep")
**Label**: `ua-assets`

## What it does

Generates store listing assets for app store submissions. Triggered when a `ship-it` label is applied, when no `ua-assets` issue has been filed in the past 30 days, or when Sahil says "run UA prep".

For each game, generates:
- **5 App Store description variants** (gameplay-first, visual-first, challenge-first, casual-first, social-first)
- **5 ASO keyword sets** (100 chars each, mix of high-volume and long-tail)
- **Screenshot composition suggestions** (what game state to capture, caption text, which feature to highlight)

Files everything as a single `ua-assets` issue per game for human review.

## What it reads

- Game features and mechanics from the codebase and CLAUDE.md
- Latest release tag and changelog (if any)
- Current game state for accurate feature descriptions

## Non-goals

- The agent will not directly upload to the App Store or Play Store. It files everything as a PR + issue and humans do the upload (same principle as the platform agent).
- The agent will not invent keywords. Every keyword it proposes must be backed by a real ASO data source or a clear justification tied to the game's mechanics.
- The agent will not spam multiple listings per release. One issue, one PR, one review cycle.
