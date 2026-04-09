<!-- STRATOS-AUTOBUILDER:BEGIN -->
## Stratos autobuilder rules (factory-managed — do not hand-edit)

This section is appended to `CLAUDE.md` by the [Stratos Games Factory](https://github.com/sahilmodi1965/stratos-games-factory). It tells the daemon's headless `claude -p` session AND any direct human contributor (Ripon, interns) how to operate in this repo. Everything between the BEGIN/END markers is owned by the factory and will be re-deployed when `scripts/deploy-brain.sh` runs.

### When you are invoked by the Stratos daemon

You are running non-interactively under `claude -p`. You have one job: process a single GitHub issue (the daemon will tell you which one in the prompt) and either open a clean change set or refuse with a reason.

#### Hard rules (zero exceptions)

1. **Never edit `packages/*`.** That kit is shared across every Stratos game. Any change there needs a human reviewer. If the issue genuinely requires a packages change, refuse and explain.
2. **Never edit `prototypes/`.** It is frozen behavioral reference.
3. **Never edit `docs/` by hand.** It is the build output. To update `docs/`, run `npm run build`.
4. **Never add a `dist/` folder.** GitHub Pages serves from `gh-pages` branch (mirrored from `docs/` by the factory's deploy workflow).
5. **Never break the rule from the original `CLAUDE.md`** above this marker — `packages/*` does not import from `games/*`.
6. **Run `npm run build` as your final action.** If it fails, fix or revert until it passes. A red build is never acceptable.

#### Scope discipline

- The issue describes ONE thing. Do that one thing.
- Do not refactor surrounding code. Do not "improve" naming. Do not add comments to code you didn't change.
- Do not add features that weren't requested. If you have an idea, it does not belong in this PR.
- Files should still aim for <150 lines per `ARCHITECTURE.md` §7. If your change pushes a file over, prefer a focused split over a sprawling file — but only if the split is genuinely cohesive.

#### Commits

- Conventional commits: `fix:`, `feat:`, `chore:`, `refactor:`, `style:`, `perf:`, `docs:`, `content:`, `level:`.
- One logical change per commit. Multiple commits in one PR is fine and often correct.
- Every commit message must reference the issue number (e.g. `fix: arrow rotation snap on touch end #42`) so GitHub auto-links it.

#### When to refuse

Refuse (do nothing, leave the working tree clean, and explain in your final summary) if any of these are true:

- The issue is ambiguous and you would have to guess what "good" looks like.
- The fix requires touching `packages/*`.
- The fix requires architectural change documented in `ARCHITECTURE.md` (which would need a human's sign-off).
- You cannot make `npm run build` pass after your change.
- The issue asks for visual/UX changes you cannot verify without running a browser.

Refusing is a successful outcome. The daemon will turn your explanation into an issue comment.

#### Final-step checklist before you stop

- [ ] Every commit references `#<issue-number>`.
- [ ] No edits inside `packages/`, `prototypes/`, or `docs/`.
- [ ] `npm run build` exits 0.
- [ ] Your final response is a single paragraph summarizing the change (or the refusal).

---

### Direct contributor mode

Ripon and interns use their own Claude Code ($20 Pro plan) to push directly to this repo. **This is expected and encouraged** — the daemon and direct pushes coexist by design. Rules:

- **Push small changes** (content tweaks, asset updates, level data, config tweaks, copy edits, simple bug fixes) directly to `main`. Don't open a PR for a one-line CSS fix.
- **Use feature branches** for anything that changes game mechanics, rendering, or UI structure. Open a PR for review.
- **Always pull before pushing**: `git pull --rebase origin main`. The daemon may have just opened auto branches; rebasing keeps history clean.
- **Use conventional commits**: `fix:`, `feat:`, `chore:`, `content:`, `level:`. Reference an issue number when one exists.
- **Never delete `auto/*` branches manually.** The daemon owns them and the cleanup workflow sweeps them weekly.
- **If CI fails after your push, fix it immediately or revert**: `git revert HEAD && git push`. Don't leave `main` red.
- **Auto-merged PRs** ship instantly. Treat the live URL (https://mody-sahariar1.github.io/arrow-puzzle-testing/) as production at all times.

### Priority of work (for play-testers)

If you are a human play-tester (Ripon or an intern), your job is **NOT to write code**. Your job is, in priority order:

1. **Play the game obsessively.** Find every tiny thing — bugs, awkward feels, missing polish, level pacing, sound, animation timing.
2. **File detailed issues** for everything. Use the `Build Request` template. One thing per issue. The daemon picks them up hourly.
3. **Use your own Claude Code ($20 Pro) for quick 2-minute fixes** if you want — color tweaks, copy edits, level number changes. Push directly to main.
4. **Test every PR preview.** When the daemon comments with a preview URL, click it, play the change, comment with your verdict (works / still wrong / new issue).
5. **Test every auto-merged change** on the live URL within an hour of the merge.
6. **Add levels and content** — as many as you can. Levels live in `games/arrow-puzzle/src/levels/`. Each is a small JSON file. Adding a level is auto-mergeable.
7. **When the game feels ready for a release**, talk to Sahil and add the `ship-it` label to a tracking issue or PR. That triggers the production release workflow.

What you should NOT spend time on:
- Refactoring engine code (that's the daemon's job, with Sahil's review).
- Making the build pipeline "better" (the factory owns it).
- Anything in `packages/` (cross-game shared kit, off-limits).
<!-- STRATOS-AUTOBUILDER:END -->
