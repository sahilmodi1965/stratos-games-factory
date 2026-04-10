# product agent (planned)

**Status**: planned
**Schedule (when built)**: weekly, Monday 00:00 UTC
**Estimated cost**: one Claude `--effort max` session per game per week + Firebase API calls

## What it will do

Pulls raw player telemetry from Firebase Analytics and Crashlytics each Monday, analyzes it with Claude, and files **data-backed improvement issues** on the game repo. Unlike the content agent (which generates ideas from pattern-matching) and the competitor agent (which generates ideas from external trends), the product agent generates ideas from **actual player behavior** in our own games.

For each game with Firebase integration, every Monday the agent will:

1. Pull the past 7 days of Firebase Analytics events (`level_start`, `level_complete`, `level_fail`, `ad_shown`, `ad_clicked`, `session_start`, `session_end`).
2. Pull the past 7 days of Crashlytics issues (stack traces, affected users, affected devices).
3. Compute cohort stats: D1 retention, D7 retention, avg session length, levels completed per session, retry rate per level, ad impressions per session.
4. Identify the top 3 friction points:
   - Which level has the worst completion rate?
   - Which level has the highest rage-quit (retry-then-leave) rate?
   - Which crash is affecting the most users?
5. File **1 issue per friction point**, labeled `product-data`, with the raw stats in the body + a proposed fix.

## When it will run

Monday 00:00 UTC via cron. Deliberately BEFORE the competitor agent (Tuesday) and content agent (Wednesday) so the product-data findings inform what those agents prioritize for the rest of the week.

## What data it will need

- **Firebase Analytics read access** via a service account JSON key (stored outside the repo at `~/.config/stratos/firebase-sa.json` or similar, gitignored)
- **Crashlytics API access** via the same service account
- **GitHub write access** to file issues (via the existing `GH_TOKEN` in `config.local.sh`)
- Read access to the game repos to cross-reference level IDs with `difficulty-config.js` or equivalent

## What it will output

- **Up to 3 issues per game** per week, labeled `product-data`.
- **A weekly summary issue** on the factory repo summarizing cross-portfolio player-behavior trends.
- **Log entries** at `agents/product/product-agent.log`.

## Why this is planned, not active

Three prerequisites before this can ship:

1. **Firebase integration must exist in at least one Stratos game**. Bloxplode already has `@capacitor-firebase/crashlytics` installed per `package.json`, but Analytics initialization + event instrumentation is not yet verified.
2. **Service account + API key management** needs a secure local secrets dir that cron can read but isn't in the repo.
3. **Enough player traffic** that the weekly cohort stats are statistically meaningful. During beta testing with 10 users, this agent would produce noise.

The council will flag when the data is ready by counting how many events-per-week the factory sees. When that number is high enough, we'll build the agent.

## Expected impact

Once live, this will become the **highest-leverage agent in the system** because every suggestion comes with hard evidence: "Level 7 has a 12% completion rate vs 68% avg, suggesting the difficulty jump is too steep — fix: reduce blocker count from 4 to 2 in `difficulty-config.js` tier 3." No agent inventing from nothing, no human guessing — just real player data → specific file changes.

## Interaction with other agents

- Builder agent will pick up `product-data` issues if a human re-labels them as `build-request` (same pattern as `market-intel` issues). This preserves the "human is in the loop for what ships" principle.
- Council agent will include product-data findings in its weekly review and may cross-reference them with the factory's own build failures ("did we regress the level we were supposed to fix?").
