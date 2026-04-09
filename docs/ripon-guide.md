# Ripon's Guide to the Stratos Games Factory

> A non-technical, step-by-step guide for play-testing Stratos games and shipping changes through the autonomous build factory.

Hi Ripon! This is your guide to working with the Stratos Games Factory. You don't need to know how to code. Your job is to **play the games, find what's wrong or what could be better, file clear requests, and test what comes back**. The factory does the rest.

The system is designed so a single play-tester can drive **3-4 full feedback-build-test cycles per day**, every day, indefinitely. That cadence is what makes the games actually get good.

---

## The big picture

```
You play  →  You file Build Requests  →  Daemon builds (1h)  →  PR previews  →  Auto-merge or review  →  You test live  →  Repeat
```

You don't write code. You don't run anything (mostly). You just play, observe, write clear requests, and test the results.

You need:
1. A computer or phone to play the games on.
2. A GitHub account.
3. Optionally, the $20/month Claude Pro subscription (claude.ai) to help structure feedback AND a $20/month Claude Code Pro plan if you want to push tiny fixes yourself.

---

## Your daily rhythm — target: 3-4 iterations per day

### Morning iteration (1 of 3-4)

1. **Open the live game URL on your phone.**
   - Arrow Puzzle: https://mody-sahariar1.github.io/arrow-puzzle-testing/
   - Bloxplode: https://mody-sahariar1.github.io/Bloxplode-Beta/ (or whatever Sahil shares)
2. **Play 10-15 minutes.** Don't rush. Try to play normally, the way a real player would.
3. **Note everything.** Bugs, awkward feels, missing polish, UI issues, timing problems, sound problems, level pacing.
4. **Open GitHub Issues** on the relevant game's repo and use the **Build Request** template.
5. **File 2-3 issues** — be specific, one thing per issue. (Details on how to write a great one below.)
6. **Wait ~1 hour.** The hourly daemon will pick them up. You'll get notifications via:
   - GitHub email/web notifications
   - Telegram (if Sahil has set up the bot)
7. **Click the preview URL** in the daemon's comment on each issue. Test the change on your phone.
8. **Comment your verdict** on the PR: works / still wrong / partial / introduced a new issue.

### Midday iteration (2 of 3-4)

Repeat steps 1-8 but focus on a different aspect of the game (e.g., morning was bug hunting → midday is level pacing or audio polish).

### Afternoon iteration (3 of 3-4)

Repeat. By now several PRs may have auto-merged. Test them on the **live URL** (not the preview URL — the merged ones are now in production).

### Evening iteration (4 of 3-4, optional)

Quick fixes only. Anything tiny that bugged you during the day — open Claude Code, fix it yourself, push directly. No need to wait for the daemon.

### End of day

- Review all open PRs. Add comments where the daemon's work was wrong or right.
- Look at the day's `auto-merged` count — that's how many improvements shipped today.
- If the game feels solid this week, talk to Sahil about adding the `ship-it` label to a tracking issue or PR. That triggers production release.

---

## How to file a great Build Request

This is the most important skill in the whole loop. The quality of the request determines the quality of the build.

### Step 1: Go to the game's repo

- Arrow Puzzle: https://github.com/mody-sahariar1/arrow-puzzle-testing
- Bloxplode: https://github.com/mody-sahariar1/Bloxplode-Beta

Click **Issues** → **New issue** → pick the **Build Request** template.

### Step 2: Be SPECIFIC

The single biggest mistake is being too vague. Compare:

| ❌ Vague | ✅ Specific |
|---|---|
| "Arrows are broken" | "Level 12, third row from the top, the right arrow overlaps the blocker on Samsung A54 in landscape mode" |
| "Combo feels off" | "When I clear a 4-row combo on level 7, the combo counter shows '×3' instead of '×4'" |
| "Make the menu nicer" | "On the main menu, the 'Try Again' button is 32px tall — bump it to 60px so it's tappable on mobile" |
| "Add levels" | "Add a level that teaches the diagonal-arrow mechanic — should feel like a tutorial moment, 6×6 grid, no blockers, 2-star easy" |

**Always include device info** when reporting bugs:
- Phone model (Samsung A54, iPhone 12, Pixel 7…)
- OS version (Android 13, iOS 17…)
- Browser (Chrome, Safari, Samsung Internet)
- Orientation (portrait/landscape)

**For features**, describe what the player should *experience*, not how to code it.

**For levels**, describe the *feel* and *purpose*, not the exact grid coordinates. Let the daemon figure out the layout.

**One issue per theme.** Don't mix bug reports with feature requests. Don't bundle 5 bugs into one issue. The daemon caps issues at 50 lines and works best with a single, focused ask.

### Step 3: Submit

Click **Submit new issue**. The label `build-request` is added automatically. You don't need to add it yourself.

---

## What the labels mean

| Label | Color | Meaning |
|---|---|---|
| `build-request` | green | You filed a request. The daemon will pick it up next hour. |
| `building` | yellow | Daemon is working on it RIGHT NOW. |
| `done` | purple | Daemon finished and opened a PR. Look for a comment with the link. |
| `auto-merged` | violet | The PR was small/safe and merged automatically. **Live now.** |
| `ship-it` | green | Production release triggered. |

---

## How to know when something shipped

Three states matter:

1. **`auto-merged` label = live on the main URL.** Go test it now on the live site, not the preview URL. Auto-merge happens within minutes after CI passes for safe-path-only changes (CSS, JSON, content, levels — no JS/HTML).
2. **Open PR (not auto-merged) = waiting for review.** A preview URL is available in the PR's comments — test it there. When Sahil merges, it ships.
3. **`ship-it` label = production release tagged.** A new GitHub Release is created, the version is bumped, and (for Bloxplode) a new APK rebuild is scheduled on Sahil's Mac.

---

## Testing PR previews

Every PR gets its own preview URL automatically:

- Arrow Puzzle: `https://mody-sahariar1.github.io/arrow-puzzle-testing/pr/<NUMBER>/`
- Bloxplode: `https://mody-sahariar1.github.io/Bloxplode-Beta/pr/<NUMBER>/`

The PR will have a comment from `github-actions[bot]` with the exact link. **Click it on your phone**, play through the change, and comment your verdict on the PR:

- ✅ "Works as expected, ready to merge"
- ⚠️ "Partial — fixes the rotation but the animation is now skipped"
- ❌ "Doesn't fix it — still happens on Samsung A54"
- 🆕 "Introduced a new issue — score now resets between rounds (filing as #N)"

If the change is wrong, **file a NEW issue** describing the new problem. Don't comment on the PR or the original issue — the daemon only reads new issues with the `build-request` label.

---

## Using your own Claude Code for quick fixes

You have a $20/month Claude Code Pro plan. Use it for:

- Color tweaks ("make the combo counter red instead of orange")
- Copy/text edits ("change 'Try again' to 'One more')
- Adding levels (describe the feel, Claude writes the level JSON)
- Tiny CSS fixes (button sizes, padding, spacing)
- Adjusting numeric tuning (timer values, score multipliers)

### How

```bash
# One-time setup (Sahil will help)
git clone https://github.com/mody-sahariar1/arrow-puzzle-testing.git
cd arrow-puzzle-testing

# Each time:
git pull --rebase origin main          # ALWAYS pull first
claude                                  # opens interactive Claude Code
# describe what you want — Claude reads CLAUDE.md and follows the rules
git status                              # see what changed
git add <files>
git commit -m "fix: bump 'Try Again' button to 60px #issue-num"
git push origin main                    # push directly
```

**Rules** (also in the repo's `CLAUDE.md` under "Direct contributor mode"):
- Always `git pull --rebase` before starting.
- Never delete `auto/*` branches manually.
- Use conventional commits (`fix:`, `feat:`, `chore:`, `content:`, `level:`).
- If CI fails after your push, fix it immediately or `git revert HEAD && git push`.

For anything bigger than a small tweak, file a Build Request and let the daemon handle it.

---

## Using Claude Chat to structure feedback

You also have the $20/month Claude Pro subscription (claude.ai). Use it as a writing assistant for filing better Build Requests.

**Prompt to start with:**

> I'm play-testing a web game called Arrow Puzzle. I want you to help me write a clear Build Request for the Stratos Games Factory. The format has these sections: "What's wrong", "Where in the game", "How it should behave", "How to reproduce", "Anything else". I'll describe what I saw, and you'll turn it into a properly-formatted Build Request that's under 50 lines. Keep each section short. Always ask me for the device info if I haven't included it. Ready?

Then describe what you saw in your own words. Claude turns it into a properly-formatted issue you can paste into GitHub.

**Important:** Always read what Claude wrote *before* you submit. Claude can sometimes invent details you didn't actually see. You are the source of truth — Claude is just a writing helper.

---

## After ship-it: distribution workflow

When a release is tagged (someone added the `ship-it` label and the release workflow ran), your job shifts to distribution:

1. **Pull latest main** in your local clone.
2. **Web (Arrow Puzzle, Bloxplode web preview):** already live on GitHub Pages — just verify by hitting the URL.
3. **Android (Bloxplode):**
   ```bash
   cd Bloxplode-Beta
   git pull
   npx cap sync android
   npx cap open android
   ```
   Then in Android Studio: **Build → Generate Signed Bundle/APK**, sign with the keystore Sahil shared, upload the AAB to Google Play Console.
4. **iOS (when iOS project is added):** similar — `npx cap sync ios`, open Xcode, archive, upload to App Store Connect.
5. **Update store listing:** screenshots from the new build, what's-new text from the changelog in the GitHub Release.
6. **Monitor for 48 hours:** crash reports in Crashlytics, store reviews, your own play-tests on the live build.

---

## Quick reference card

| I want to... | Do this |
|---|---|
| Report a bug | Open an issue → Build Request template → fill all sections (with device info) → submit |
| Suggest a tweak | Same as above, skip "How to reproduce" |
| Add a level idea | Describe the feel and purpose, not the layout. Daemon writes the JSON. |
| Check if my issue is being built | Look at the labels: green=waiting, yellow=building, purple=done |
| See the fix | Click the preview URL in the daemon's PR comment |
| Test the merged version | Open the live URL (not the preview) — auto-merged means live |
| Report the fix didn't work | Open a NEW issue, reference the old one's number |
| Make a tiny fix yourself | `git pull --rebase` → `claude` → fix → `git push` |
| Trigger a production release | Talk to Sahil, add the `ship-it` label to a tracking issue/PR |

---

## When to ping Sahil directly (not the daemon)

The daemon handles most things. But ping Sahil for:

- Issues stuck on `build-request` for >2 hours (daemon may be down).
- Daemon keeps refusing the same issue (it's probably ambiguous or out-of-scope).
- Repeated wrong-direction fixes (you and Sahil should talk it through).
- Anything dangerous: data loss, broken sign-in, security, payment.
- Native app issues (gestures, store listing, signing) — those need a human, not the daemon.
- Whenever the game *feels* ready for `ship-it` — that's a judgment call you and Sahil make together.

---

That's everything. The system is designed so every issue you file becomes a real change in the game, usually within the same hour. If you're filing 5-10 detailed issues a day and testing every PR that comes back, the games will get visibly better every single day.

— The Stratos Games Factory
