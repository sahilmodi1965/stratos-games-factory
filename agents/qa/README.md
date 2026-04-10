# qa agent

**Status**: active
**Schedule**: every PR (GitHub Actions trigger)
**Cost**: zero Claude tokens

## What it does

Runs a Playwright smoke test on every pull request to catch the class of failures our structural validators can't see:

- Page fails to load at all (asset path broken, 404s, JS parse error)
- Console errors during startup (the thing our seeded council lesson "Vite preview path bug" was about)
- Main game container missing from the DOM
- Blank page with empty title

If any assertion fails, the workflow exits non-zero and the PR is blocked. If everything passes, the workflow uploads a full-page screenshot as an artifact and posts a comment on the PR with the screenshot inlined.

This is deliberately the **cheapest** visual QA we can run: no gameplay replay, no vision model, no action framework. It only catches "the game definitely didn't load". The council will recommend escalating to more expensive QA if and when the data shows it's needed.

## When it runs

On every `pull_request` event (`opened`, `synchronize`, `reopened`) to `main` in either game repo.

## What data it needs

None from outside the PR. It:

1. Checks out the PR's head SHA
2. Runs `npm install` + (for Arrow Puzzle) `npm run build`
3. Starts a local static HTTP server via Playwright's `webServer` config
4. Runs the Playwright spec against that local URL
5. Takes a screenshot, uploads it, comments on the PR

## What it outputs

- **On pass**: A PR comment `QA passed — screenshot attached` with the full-page screenshot inlined. Workflow exits 0. Auto-merge and other workflows proceed normally.
- **On fail**: The workflow exits non-zero with the failing assertion's error message. The PR cannot be merged until the failure is fixed. The screenshot (even from a failing run) is still uploaded as an artifact so humans can see what the page looked like when it broke.

## Files

- `specs/arrow-puzzle.spec.js` — Playwright spec for Arrow Puzzle (reference copy; the deployed version lives at `tests/e2e/smoke.spec.js` in the game repo).
- `specs/bloxplode.spec.js` — same for Bloxplode.
- `playwright.config.js` — reference config; the deployed version is per-game because the `webServer.command` differs (`vite preview` vs `http-server www`).

The workflow itself is `templates/workflows-<game>/qa-agent.yml` and is deployed into each game repo's `.github/workflows/` by `scripts/deploy-brain.sh`.

## Why zero Claude tokens

This is the "pure code" lane. If a check can be expressed as a deterministic assertion, it shouldn't burn tokens. The qa agent owns everything that fits that shape. The builder agent owns everything that requires judgment. The two don't overlap.
