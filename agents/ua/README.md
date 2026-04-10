# ua (user acquisition) agent (planned)

**Status**: planned
**Schedule (when built)**: on release (triggered by `ship-it` label)
**Estimated cost**: one Claude `--effort max` session per release

## What it will do

Every time a game ships a new release, the UA agent generates the store-listing assets and ASO keywords the release needs. This is the "last mile" between the factory producing a new build and Ripon being able to push that build to the store.

For each release, the agent will:

1. Read the release tag + changelog (from the release workflow's output)
2. Read the game's CLAUDE.md for tone and positioning
3. Generate or regenerate:
   - **App title candidates** (short + long variants, multiple locales)
   - **App subtitle** (iOS) / **short description** (Play)
   - **Full description** (multiple locales)
   - **What's new** section with the changelog summarized in player-facing language
   - **Keyword list** with ASO analysis (volume, difficulty, relevance)
   - **Screenshot captions** (one caption per store screenshot slot)
   - **Promotional text** (iOS) for the 170-char limit
4. Generate or regenerate:
   - **Feature graphic** prompt for a designer (or an image-gen model if we wire one up)
   - **Screenshot overlay** copy (the text that sits on top of gameplay screenshots)
5. File ONE `store-listing` issue per game release with all of the above in the body.
6. If AI image generation is available, also generate draft screenshots as attachments.

## When it will run

Triggered by the `ship-it` label on any issue or PR, or by the release workflow completing on a game repo (via a GitHub Actions `workflow_run` webhook or a self-hosted runner).

## What data it will need

- **Release tag and changelog** (from the release workflow's output)
- **Game metadata** (current store listings, current screenshots) — read from the game repo's `store-listing/` directory when it exists, or bootstrapped from scratch the first time
- **ASO data source** (optional, future: integration with a tool like AppTweak, SensorTower, or Apple's own App Store Connect keyword ranker)
- **Claude with WebSearch** for current keyword trends

## What it will output

- **1 `store-listing` issue per game release** on the game repo, with the full listing package in the body
- **An updated `store-listing/` directory** in the game repo (committed to a `store-listing/<version>` branch, PR opened for review) with:
  - `title.md`, `subtitle.md`, `description.md`, `whats-new.md`, `keywords.md`
  - `screenshots/overlay-copy.md`
  - `locales/<locale>/` for each target locale
- **Log entries** at `agents/ua/ua-agent.log`

## Why this is planned, not active

Three prerequisites:

1. **At least one game must have an existing store listing** to bootstrap from (otherwise the agent has no tone reference). Neither game is in the stores yet.
2. **Locale strategy** needs to be decided — which locales do we care about first?
3. **Designer-in-the-loop** for screenshots. The agent can draft copy, but final visuals need human approval before store submission.

Once any game hits a real ship-it, this agent becomes the immediate next priority because it's the bottleneck between "the factory built a release" and "the release is on the store".

## Non-goals

- The agent will not directly upload to the App Store or Play Store. It files everything as a PR + issue and humans do the upload (same principle as the platform agent).
- The agent will not invent keywords. Every keyword it proposes must be backed by a real ASO data source or a clear justification tied to the game's mechanics.
- The agent will not spam multiple listings per release. One issue, one PR, one review cycle.
