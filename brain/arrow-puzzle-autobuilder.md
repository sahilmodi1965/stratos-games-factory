<!-- STRATOS-AUTOBUILDER:BEGIN -->
## Stratos autobuilder rules (factory-managed — do not hand-edit)

This section is appended to `CLAUDE.md` by the [Stratos Games Factory](https://github.com/sahilmodi1965/stratos-games-factory). It tells the daemon's headless `claude -p` session how to behave when it picks up a `build-request` issue against this repo. Everything between the BEGIN/END markers is owned by the factory and will be re-deployed when `scripts/deploy-brain.sh` runs.

### When you are invoked by the Stratos daemon

You are running non-interactively under `claude -p`. You have one job: process a single GitHub issue (the daemon will tell you which one in the prompt) and either open a clean change set or refuse with a reason.

### Hard rules (zero exceptions)

1. **Never edit `packages/*`.** That kit is shared across every Stratos game. Any change there needs a human reviewer. If the issue genuinely requires a packages change, refuse and explain.
2. **Never edit `prototypes/`.** It is frozen behavioral reference.
3. **Never edit `docs/` by hand.** It is the build output. To update `docs/`, run `npm run build`.
4. **Never add a `dist/` folder.** GitHub Pages serves from `docs/`.
5. **Never break the rule from the original `CLAUDE.md`** above this marker — `packages/*` does not import from `games/*`. Read it again if you forgot.
6. **Run `npm run build` as your final action.** If it fails, fix or revert until it passes. A red build is never acceptable.

### Scope discipline

- The issue describes ONE thing. Do that one thing.
- Do not refactor surrounding code. Do not "improve" naming. Do not add comments to code you didn't change.
- Do not add features that weren't requested. If you have an idea, it does not belong in this PR.
- Files should still aim for <150 lines per `ARCHITECTURE.md` §7. If your change pushes a file over, prefer a focused split over a sprawling file — but only if the split is genuinely cohesive.

### Commits

- Conventional commits: `fix:`, `feat:`, `chore:`, `refactor:`, `style:`, `perf:`, `docs:`.
- One logical change per commit. Multiple commits in one PR is fine and often correct.
- Every commit message must reference the issue number (e.g. `fix: arrow rotation snap on touch end #42`) so GitHub auto-links it.

### When to refuse

Refuse (do nothing, leave the working tree clean, and explain in your final summary) if any of these are true:

- The issue is ambiguous and you would have to guess what "good" looks like.
- The fix requires touching `packages/*`.
- The fix requires architectural change documented in `ARCHITECTURE.md` (which would need a human's sign-off).
- You cannot make `npm run build` pass after your change.
- The issue asks for visual/UX changes you cannot verify without running a browser.

Refusing is a successful outcome. The daemon will turn your explanation into an issue comment.

### Final-step checklist before you stop

- [ ] Every commit references `#<issue-number>`.
- [ ] No edits inside `packages/`, `prototypes/`, or `docs/`.
- [ ] `npm run build` exits 0.
- [ ] Your final response is a single paragraph summarizing the change (or the refusal).
<!-- STRATOS-AUTOBUILDER:END -->
