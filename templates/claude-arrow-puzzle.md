# CLAUDE.md

Single source of truth for AI agents (the Stratos Games Factory daemon, your
own Claude Code session, subagents) and human contributors working in this
repo. Humans should also read `README.md` and `ARCHITECTURE.md`.

## Project

**Arrow Puzzle** — vanilla JS + Vite + Canvas logic puzzle, live at
https://mody-sahariar1.github.io/arrow-puzzle-testing/. Part of the
[Stratos Games Factory](https://github.com/sahilmodi1965/stratos-games-factory).
Levels are **procedurally generated** by `games/arrow-puzzle/src/levels/level-loader.js`
from the `DIFFICULTY` table in `games/arrow-puzzle/src/config/difficulty-config.js`.
There are **no per-level JSON files** — do not invent any.

## Repo layout

- `packages/*` — game-agnostic kits (`@core`, `@game-kit`, `@ui-kit`, `@audio`, `@storage`). Off-limits without human review.
- `games/arrow-puzzle/src/` — game code: `game/`, `levels/`, `rendering/`, `config/`, `ui/`, `styles/`.
- `prototypes/` — frozen pre-refactor reference. Do not edit.
- `docs/` — Vite build output. Never hand-edit, never `git add`.
- `scripts/validate*.js` — `npm run validate` (paths + difficulty schema).

The architectural hard rule: **`packages/*` may NEVER import from `games/*`**. Cross-package signals via `@core/event-bus`. See `ARCHITECTURE.md` for the full module map.

## Autonomous mode (when invoked by the factory daemon)

You are running headless under `claude -p`. The daemon hands you one GitHub issue and expects a clean PR back. Skipping any phase below is how broken PRs happen. Don't.

### Phase 1 — Explore (mandatory before any write)

1. Read this file and `ARCHITECTURE.md` end-to-end. Re-read mid-task if you forget.
2. Read **at least 3 files in the subsystem you're about to touch**:
   - Levels / generator → `games/arrow-puzzle/src/levels/level-loader.js`, `games/arrow-puzzle/src/levels/snake-grower.js`, AND `games/arrow-puzzle/src/config/difficulty-config.js`.
   - Game-loop / state → `games/arrow-puzzle/src/game/game-controller.js` plus the rest of `src/game/`.
   - UI / rendering → `src/ui/` and `src/rendering/`.
3. Trace at least one call path end-to-end. Don't guess at how data flows.

### Phase 2 — Sanity-check the issue's premise

Issue authors are play-testers, not engineers. Their bodies often suggest implementation details that **don't match this codebase** — the canonical example is asking for "level JSON files" when there are none. **Match the existing pattern, or refuse and explain.** Inventing a parallel system on top of the real one is never correct.

### Phase 3 — Implement the smallest possible change

- ONE focused commit per logical change. Conventional commits (`fix:`, `feat:`, `chore:`, `refactor:`, `level:`, `content:`, `perf:`, `style:`, `docs:`).
- **Every commit message must reference `#<issue-number>`** so it auto-links.
- Do not refactor unrelated code. Do not "improve" naming. Do not add docstrings/comments/types to code you didn't change.
- Do not bump dependencies (`package.json` / `package-lock.json`).
- File-size discipline per `ARCHITECTURE.md` §7 (<150 lines target).

### Phase 4 — Verify (mandatory before you stop)

1. Run `npm run build`. If it fails, fix and retry. Iterate as needed — never leave a red build.
2. Run `npm run validate`. Same rule.
3. Run `git status` and `git diff --stat HEAD`. Verify every file is intentional. **Use targeted `git add <named-files>` — never `git add -A` or `git add .`.** The daemon resets `docs/`, `packages/`, and `prototypes/` to HEAD as a safety net but you must not depend on it.

## Hard exclusions (never edit, never stage)

- `packages/**` — cross-game shared kit, requires human review.
- `prototypes/**` — frozen behavioral reference.
- `docs/**` — Vite build output. `npm run build` writes here during your session, but you must NEVER `git add` these files.
- `node_modules/**`, `dist/**`, `build/**`.
- `package.json`, `package-lock.json` — no dependency changes without explicit issue authorization.

## When to refuse (refusing is a successful outcome)

Stop, leave the working tree clean, and explain in your final paragraph if any of:

- The issue is ambiguous and you'd have to guess what "good" looks like.
- The issue's premise contradicts the codebase and you can't find a fitting interpretation.
- The fix requires touching a forbidden path.
- The fix requires a change to `ARCHITECTURE.md` (needs human sign-off).
- You cannot make `npm run build` and `npm run validate` pass after multiple attempts.

The daemon will turn your explanation into an issue comment so a human can refine the request. A clean refusal is far more useful than a broken PR.

## Final-step checklist

- [ ] Read `CLAUDE.md` and `ARCHITECTURE.md` at the start.
- [ ] Read at least 3 files in the relevant subsystem before writing.
- [ ] Every commit references `#<issue-number>`.
- [ ] Nothing in `packages/`, `prototypes/`, or `docs/` is staged.
- [ ] `npm run build` exits 0.
- [ ] `npm run validate` exits 0.
- [ ] `git diff --stat HEAD` shows only files you intentionally touched.
- [ ] Final response is a single paragraph summary. Nothing else.

You have a generous reasoning budget and as many tool turns as you need. Use them.

## Direct contributor mode (Ripon, interns, or anyone using their own Claude Code Pro)

- Push small content / CSS / level / copy fixes directly to `main`.
- Use feature branches for game mechanics or UI structure changes.
- `git pull --rebase origin main` before starting.
- Conventional commits, reference issue numbers when applicable.
- **Never delete `auto/*` branches manually** — the daemon owns them; the cleanup workflow sweeps them weekly.
- If CI fails after your push, fix immediately or `git revert HEAD && git push`.
