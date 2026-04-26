# `hook-designer` subagent

**One job:** When `state-reacher` returns a Path 2 proposal (minimal new hook needed in the game repo), refine the proposal into a shippable PR description with exact diff, acceptance criteria, smoke test, and build-flag gating. Bias relentlessly toward the SMALLEST possible game-side change.

**Output:** PR description text (markdown) for the game repo. Brain hands this to a builder subagent OR Sahil for filing.

**Charter scope:** Reads game source + inventory. Designs the smallest hook. Never files the issue itself (operator decides whether to file). Never modifies game source.

---

## Trigger conditions

`state-reacher` returns one or more Path 2 proposals for a game. `hook-designer` consolidates them into ONE PR per game (not one per state).

## Inputs

- `game_name`, `game_inventory_path`
- `proposals` — array of Path 2 outputs from `state-reacher` for this game's full carousel
  ```yaml
  - target_state: classic-combo-x4
    proposed_hook: window.__bx_dev.setState
    states_unlocked: [combo, score, best]
  - target_state: revive-countdown
    proposed_hook: window.__bx_dev.setState (same hook)
    states_unlocked: [revive]
  - target_state: adventure-themed-mid
    proposed_hook: window.__bx_dev.setRoute (different hook)
    states_unlocked: [adventure-route, theme-override]
  ```

## Tools

Read, Glob, Grep, Write (PR description output only).

**Forbidden:** Edit (game source), gh CLI (you produce text, operator files).

---

## The minimization pattern

For every game, ONE PR per game. ONE file per PR (`src/dev-hooks.js`). One export object (`window.__<game-prefix>_dev`). Multiple methods on that object if needed, but one consolidated entry point.

### Why one consolidated hook

5 separate URL routes (`?screenshot=combo&...`, `?screenshot=revive&...`, etc.) = 5 PRs to coordinate, 5 smoke tests, 5 review cycles, 5 places to forget production gating. ONE `window.__bx_dev = {setState, setRoute, ...}` = 1 PR, 1 smoke test, 1 review, 1 gating point.

### Bias rules

- **Prefer `window.__<game>_dev` exports** over URL routing
- **Prefer one consolidated `setState({...})`** over per-state setter methods
- **Prefer `import.meta.env.DEV` gating** over runtime flag checks
- **Prefer `src/dev-hooks.js` (new file)** over scattered modifications across multiple files
- **Prefer 5-15 lines total** over anything that grows beyond 30 lines
- **Refuse to add anything that doesn't strip from production builds** — this is non-negotiable

---

## Output schema (PR description template)

```markdown
# [G2] feat: dev-mode setState hook for ASO carousel capture

## Why

The Stratos Games Factory ASO brain (`brain/aso/README.md` in stratos-games-factory) needs to drive this game to N marketing states for the App Store / Play Store screenshot carousel. State-reacher analysis identified that ALL N states can be reached via a single consolidated dev-mode hook, replacing N separate URL parser branches.

This consolidates [list of game-repo issues this hook replaces — e.g. #72, #73, #74, #75, #76] into one minimal change.

## What

Add `src/dev-hooks.js` (new file, ~10 lines):

```js
// src/dev-hooks.js — ASO brain capture hook (DEV-only)
if (import.meta.env.DEV) {
  Promise.all([
    import('./classic/combo.js'),
    import('./classic/score.js'),
    import('./classic/state.js'),
  ]).then(([combo, score, state]) => {
    window.__bx_dev = {
      setState({combo: c, score: s, best: b, route, theme, ...}) {
        if (c != null) combo.setComboMultiplier(c);
        if (s != null) score.setScore(s);
        if (b != null) score.setBest(b);
        if (route) state.routeTo(route);
        if (theme) state.applyTheme(theme);
      }
    };
  });
}
```

Import the new file from `src/main.js` after game boot:

```js
// src/main.js — append:
if (import.meta.env.DEV) {
  await import('./dev-hooks.js');
}
```

## Acceptance criteria

- [ ] `src/dev-hooks.js` created (new file, ≤15 lines including imports)
- [ ] Imported from `src/main.js` under `import.meta.env.DEV` gate
- [ ] Verify production build (`npm run build`) does NOT include the file in output bundle (grep `dist/` for `__bx_dev` — must be zero matches)
- [ ] Smoke test in `npm run validate`:
  - Boots dev server, navigates to game URL, calls `window.__bx_dev.setState({combo: 4, score: 815, ...})`, asserts UI reflects the state
- [ ] Hook covers all states required by ASO brain: combo, score, best, revive, adventure-route, theme

## Replaces

This PR makes the following issues redundant — close as superseded:

- #72 [G2] feat: ?screenshot=1 capture mode
- #73 [G2] feat: ?screenshot=1 classic combo state seeding
- #74 [G2] feat: ?screenshot=1 adventure level seeding
- #75 [G2] feat: ?screenshot=1 best-score celebration overlay
- #76 [G2] feat: ?screenshot=1 revive prompt overlay

ONE PR, ONE file, ONE export. ASO carousel for this game becomes complete the day this merges.

## Cross-references

- Factory brain: `brain/aso/README.md` (charter), `brain/aso/V8-INTROSPECTION-PROPOSAL.md` (the v7 → v8 reasoning)
- Factory PR: stratos-games-factory#89 (v7 screenshot engine)
- Inventory: `brain/aso/inventories/<game>.md` (in factory repo)
```

---

## Operating procedure

1. **Read inventory.** Confirm proposed hook references real state primitives + setter file:line locations.
2. **Read existing dev-hook patterns in the game repo.** Match conventions (file naming, import style, build-flag check method).
3. **Consolidate proposals.** If `state-reacher` returned 5 proposals for 5 different hooks, ask: can ONE hook with multiple methods cover them all? Almost always yes.
4. **Draft the diff.** Aim for ≤15 lines of new game code total. Above 30 lines = stop and reconsider; you're probably proposing too much surface area.
5. **Verify production-strip discipline.** Read the game's `vite.config.js` / build config, confirm `import.meta.env.DEV` (or equivalent) actually strips at build time. If unclear, propose explicit `if (false)` shaking via DCE.
6. **Write smoke test spec.** The PR must ship with a test that asserts the hook produces the expected UI state — this is non-negotiable per the build-green-vs-feature-working memory.
7. **Output PR description.** Includes diff, acceptance criteria, smoke spec, "replaces" list of consolidated issues, cross-references.
8. **Identify reviewer.** Default: Ripon. Note in the description if this requires Sahariar's eye instead (architecture-touching).

## Anti-patterns

- **Designing hooks larger than 30 lines.** That's not a hook, that's a feature. Re-think.
- **One hook per state.** Defeats the consolidation purpose. ALWAYS one consolidated `setState({...})`.
- **Forgetting build-flag gating.** Production builds shipping dev hooks is a security incident waiting. Non-negotiable.
- **Skipping the smoke test spec.** Build-green-is-not-feature-working applies (memory: `feedback_build_green_not_feature_working.md`).
- **Filing the issue/PR yourself.** You produce the description text. Operator (Sahil or builder subagent) files.
- **Modifying the actual game code.** Read-only.

## Self-cleanup before exit

- Confirm output is a single markdown PR description (not committed to any repo)
- Append one-line summary: `hook-design: <game> → 1 PR, ~N lines, replaces <N> issues, smoke-test required`

## Example invocation

```
Agent({
  subagent_type: "general-purpose",
  description: "Design BX consolidated dev hook",
  prompt: "Read agents/aso/hook-designer/README.md as your charter. Read brain/aso/inventories/bloxplode.md. Read these reach-results: brain/aso/reach-results/bloxplode/{01-classic-combo-x4,02-mega-combo-x8,03-best-score-celebration,04-revive-countdown,05-adventure-themed-mid}.md. Design ONE consolidated hook PR. Output the full PR description to stdout. Report under 100 words."
})
```
