# monetization agent (planned)

**Status**: planned
**Schedule (when built)**: weekly, Monday 00:00 UTC (runs after product agent)
**Estimated cost**: one Claude `--effort max` session per game per week + AdMob API calls

## What it will do

Pulls AdMob revenue and ad-serving data each Monday, analyzes it against the product agent's behavior data, and files **ad-placement optimization issues** on the game repo. The goal is to squeeze more revenue per DAU without degrading the player experience that keeps them retaining.

For each game with AdMob integration, every Monday the agent will:

1. Pull the past 7 days of AdMob reports: impressions, eCPM, fill rate, click rate, revenue per placement (interstitial, rewarded, banner).
2. Pull the product agent's output from the same week to cross-reference with retention cohorts.
3. Compute per-placement stats:
   - Revenue per thousand sessions (RPM, broken down by ad format)
   - Impression-to-retention-drop correlation (does showing a rewarded ad at level 5 drop D1 more than at level 10?)
   - Ad frequency cap compliance
4. Identify the top 3 optimization opportunities:
   - Which placement is underperforming on eCPM and why?
   - Where would an additional placement add revenue without hurting retention?
   - Where would REMOVING a placement recover retention more than the revenue it earned?
5. File **1 issue per opportunity**, labeled `monetization-data`.

## When it will run

Monday 00:00 UTC, after the product agent has finished (so it can read the product agent's output from the current run).

## What data it will need

- **AdMob API credentials** (service account JSON), same secure local dir as the product agent's Firebase credentials
- **Read access** to the product agent's output for correlation
- **GitHub write access** to file issues
- Read access to the game's ad placement config (likely in `www/` or wherever AdMob IDs are declared)

## What it will output

- **Up to 3 issues per game** per week, labeled `monetization-data`
- **A weekly ROI summary** on the factory repo: total revenue, RPM trend, and the agent's proposed priority-ordered optimization list
- **Log entries** at `agents/monetization/monetization-agent.log`

## Why this is planned, not active

Same prerequisites as the product agent, plus:

1. **AdMob integration must be live and serving ads.** Bloxplode has `@capacitor-community/admob` installed per `package.json`, but placement ID wiring and revenue reporting are not yet verified.
2. **Product agent must exist first.** The monetization agent reads the product agent's output to correlate ad impressions with retention.
3. **Baseline revenue data.** Without at least 30 days of AdMob data, optimization recommendations would be fitting to noise.

## Guardrails

- The agent never proposes changes that violate AdMob's content policies (e.g. "show another interstitial between levels" when the frequency cap says no).
- The agent never proposes changes that the product data suggests would hurt retention more than the revenue gained. Retention is the goal; ads serve retention, not the other way around.
- All recommendations cite the specific AdMob report fields and the specific product-data findings they're based on.
