# monetization agent

**Status**: active
**Dispatch**: swarm-inline (runs in Claude Code session when Sahil says "go")
**Label**: `monetization-data`

## What it does

Reviews ad placement configuration in game code, cross-references with casual game monetization best practices, and files **ad-placement optimization issues**. Currently targets Bloxplode (the only game with ad integration). Skips games with no ad integration.

## How it works

1. Reads the game's codebase for ad integration code (AdMob config, placement triggers, frequency logic).
2. Cross-references with best practices: interstitial timing (not mid-action, natural break points), rewarded video placement (at moments of player need), banner positioning (bottom only, never overlapping UI), session pacing (first ad after 2+ min engagement).
3. Files up to **3 optimization issues per game**, each labeled `build-request` + `monetization-data`.

## Known limitations

- If no ad integration exists in a game, the agent skips it.
- Without live AdMob revenue data, recommendations are based on code review + best practices rather than actual performance metrics.

## Guardrails

- The agent never proposes changes that violate AdMob's content policies (e.g. "show another interstitial between levels" when the frequency cap says no).
- The agent never proposes changes that the product data suggests would hurt retention more than the revenue gained. Retention is the goal; ads serve retention, not the other way around.
- All recommendations cite the specific AdMob report fields and the specific product-data findings they're based on.
