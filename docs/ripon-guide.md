# Ripon's Guide to the Stratos Games Factory

> A non-technical guide for play-testing Stratos games, reading the dashboard, testing PRs, and working with the agent swarm. You don't need to know any code.

The factory runs a **swarm of 9 active agents** that do most of the work. Your job is the part agents can't do: actually playing the game, judging whether it feels right, and making the human calls that decide what ships. Sahil opens Claude Code, says "go", and the swarm builds everything you've filed. This guide shows you how to work with that system.

---

## The big picture

```
You play the game        Swarm generates content ideas
       |                              |
       |                              v
       |            Swarm scans market trends
       |                              |
       |                              v
       |  Issues land in the build queue
       |                  |
       v                  v
File a build-request → Sahil says "go" → swarm builds it →
QA agent runs Playwright → PR comment + screenshot →
Auto-merge OR you review → Merged → Live URL → You re-test
```

You don't need to think about the agents most of the time. They run when Sahil kicks off the swarm, and they file issues. You just play, test, and judge.

---

## The dashboard (top of every game repo's README)

Open either game's repo on GitHub. The very first thing you'll see is a row of badges and a status table. Here's what each one means.

**Arrow Puzzle**: https://github.com/mody-sahariar1/arrow-puzzle-testing
**Bloxplode**: https://github.com/mody-sahariar1/Bloxplode-Beta

### The badges, left to right

| Badge | What it shows | Click it to... |
|---|---|---|
| **Play** / **Web preview** | The live game URL | Open the game in your browser |
| **release** | The latest version tag | See all releases and their changelogs |
| **build requests** (green count) | How many things humans (and agents) are asking for | See the list of open requests |
| **PRs** (purple count) | How many changes are waiting for review | See the list of open PRs |
| **CI** (green/red) | Did the last build pass? | See CI history |
| **QA** (green/red) | Did the last Playwright smoke test pass? | See QA history |
| **last commit** | When the repo was last updated | See recent commits |

If any badge is **red**, click it. That's the system telling you something needs attention.

### The status table

Below the badges, a small table gives you the live URL, a one-click link to file a new build request, and shortcuts to issues / PRs / actions. Use this as your starting point every day.

---

## Your daily rhythm

Target: **3-4 iterations per day, every day**. The agents fill the build queue around you, but only you can do the play-testing.

### Morning iteration (1 of 3-4)

1. **Open the live game URL** on your phone (badge -> Play).
2. **Play 10-15 minutes.** Just play normally, the way a real player would.
3. **Note everything weird**: bugs, awkward moments, anything that feels off, missing polish, audio issues, animation glitches.
4. **Open the repo's Issues tab**, click "New issue", pick the **Build Request** template.
5. **File 2-3 build requests**, one per concern. (One thing per issue. Don't bundle.)
6. **Ping Sahil** when you've filed a batch — he'll run the swarm and your issues get built.

### Midday iteration (2 of 3-4)

Same as morning, but focus on a different layer (level pacing instead of bugs, or audio instead of UI). Also: **test any PR previews from this morning's batch** (every PR comments with a preview URL).

### Afternoon iteration (3 of 3-4)

Repeat. By now several PRs may have **auto-merged** (look for the `auto-merged` label). Test those on the LIVE URL (not the preview URL) — they're already shipped.

### Evening (optional)

Quick fixes only. Anything tiny that bugged you today — open Claude Code, fix it, push directly. Or just file the issue and let Sahil's next swarm run handle it.

### End of day

Click the badges row on each game's README. If any badge is red, investigate. Look at the day's `auto-merged` count — that's how many improvements shipped today. Look at the open PRs queue — anything that's been waiting >24h needs your eyes.

---

## How to file a great Build Request

This is the most important skill in the whole loop. The quality of the request determines the quality of the build.

1. **Click the dashboard's "file a build request" link** (or Issues tab -> New issue -> Build Request template).
2. **Be specific.** Compare:
   - Bad: "Arrows are broken" -> Good: "Level 12, third row from the top, the right arrow overlaps the blocker on Samsung A54 in landscape"
   - Bad: "Combo feels off" -> Good: "After clearing a 4-row combo on level 7, the counter shows x3 instead of x4"
   - Bad: "Make it nicer" -> Good: "Bump the 'Try Again' button from 32px to 60px so it's tappable on phones"
3. **Always include device info** when reporting bugs: phone model, OS version, browser, orientation.
4. **For features**, describe what the player should *experience*, not how to code it.
5. **For levels**, describe the *feel* (not the grid coordinates) — let the builder figure out the layout.
6. **One issue per theme.** Don't mix bug reports with feature requests.
7. **Submit.** The `build-request` label is added automatically. Sahil's next swarm run picks it up.

## How to file analytics data

The **product agent** turns your player data into concrete improvement issues. Here's how to feed it:

1. Open Firebase Analytics or Play Console for the game.
2. Take screenshots or export CSV of key metrics: level completion rates, session lengths, drop-off points.
3. File an issue on the game repo with the `analytics-data` label.
4. Paste the screenshots or data into the issue body with any notes ("Level 8 seems to lose everyone").
5. The product agent reads this and files specific improvement issues like "Level 8 has 70% drop-off — reduce blocker count."

---

## How to test a PR

When the builder agent finishes a build, it opens a PR. Every PR follows the **same template**, so testing is always the same checklist.

### Step-by-step

1. **Open the PR** (badge -> Open PRs -> click into the one you want to test).
2. **Wait for the QA badge.** The QA agent runs automatically and posts:
   - **QA passed** = the smoke test ran cleanly. Safe to proceed.
   - **QA failed** = the page didn't load or crashed. Don't bother testing manually — it needs a fix first.
3. **Look for the PR Preview comment.** A bot comments with a URL like `https://mody-sahariar1.github.io/<game>/pr/<num>/`. **Open it on your phone.**
4. **Run the testing checklist** in the PR template:
   - [ ] Game loads without errors (white screen = failure)
   - [ ] Main menu appears and Play is clickable
   - [ ] Start a game — does the new feature/fix work as described?
   - [ ] Play 3 levels — no regressions on existing mechanics?
   - [ ] Check on mobile (real phone, not just desktop responsive mode)
5. **Comment your verdict** on the PR:
   - "Works as expected, ready to merge"
   - "Partial — fixes the rotation but the animation is now skipped"
   - "Doesn't fix it, still happens on Samsung A54"
   - "Introduced a new issue — score now resets between rounds (filing as #N)"
6. **If it's wrong**, file a NEW issue (not a comment) describing the new problem.

### Device checklist

The PR template includes this — work through each on a real device when you can:
- [ ] Chrome desktop
- [ ] Safari iOS
- [ ] Chrome Android
- [ ] Samsung Internet

---

## What each agent does (in simple terms)

The factory has 9 agents working alongside you. You don't need to manage any of them — they run when Sahil says "go" and they file GitHub issues that show up in the dashboard.

| Agent | What it does | Where its output appears |
|---|---|---|
| **builder** | Picks up `build-request` issues and turns them into PRs | New PRs in the dashboard |
| **product** | Reads your `analytics-data` issues and files data-backed improvements | New issues with `product-data` label |
| **monetization** | Reviews ad placement code and suggests optimizations | New issues with `monetization-data` label |
| **content** | Suggests 5 new level / content ideas per game | New issues with `content-agent` label |
| **competitor** | Searches for trending puzzle games and files mechanic suggestions | New issues with `market-intel` label |
| **ua** | Generates store listing descriptions, keywords, and screenshot ideas | New issues with `ua-assets` label |
| **council** | Reviews the week's factory activity and updates the factory's memory | New issues with `council` label on the factory repo |
| **qa** | Runs a Playwright smoke test on every PR, takes a screenshot | PR comments + screenshot artifacts |
| **platform** | Builds the Android APK when Sahil flips `ship-it` | New issue with `release-ready` label |

---

## The labels glossary

| Label | Meaning | Who creates it |
|---|---|---|
| `build-request` | Something to build (bug fix, feature, content) | You, or the content/product/competitor agents |
| `building` | Builder is working on it RIGHT NOW | Builder agent (auto-removed when done) |
| `done` | Builder opened a PR | Builder agent |
| `auto-merged` | PR was small/safe and merged automatically | Auto-merge workflow |
| `analytics-data` | Player data for the product agent to analyze | You (file manually with data/screenshots) |
| `product-data` | Data-backed improvement from the product agent | Product agent |
| `monetization-data` | Ad optimization suggestion | Monetization agent |
| `market-intel` | Competitor agent suggestion (waiting for human triage) | Competitor agent |
| `content-agent` | Content agent suggestion (also has `build-request`) | Content agent |
| `ua-assets` | Store listing assets for app store submission | UA agent |
| `release-ready` | Native build done, ready for store submission | Platform agent |
| `council` | Architectural improvement suggestion | Council agent |
| `ship-it` | Trigger a production release | You (apply this manually when the game is ready) |

---

## Using your own Claude Code for quick fixes

You have a $20/month Claude Code Pro plan. Use it for:

- Quick polish: fix a color, adjust spacing, tweak text
- Adding levels (describe the feel, Claude writes the JSON or extends the procedural config)
- Tiny CSS fixes (button sizes, padding, spacing)
- Adjusting numeric tuning (timer values, score multipliers)

```bash
git pull --rebase origin main           # ALWAYS pull first
claude                                  # opens interactive Claude Code
# describe what you want — Claude reads CLAUDE.md and follows the rules
git add <specific-files>                # NOT git add -A
git commit -m "fix: bump 'Try Again' button to 60px #issue-num"
git push origin main                    # push directly
```

**Rules:**
- Always `git pull --rebase` before starting.
- Never delete `auto/*` branches manually.
- Use conventional commits and reference issue numbers.
- If CI or QA fails after your push, fix it immediately or `git revert HEAD && git push`.

For anything bigger than a small tweak, file a build-request and let the swarm handle it.

---

## Quick reference card

| I want to... | Do this |
|---|---|
| See if anything needs my attention | Look at the badges on the game repo README |
| File a bug | Click "file a build request" on the dashboard |
| Share player analytics | File an issue with `analytics-data` label + paste data |
| Test a PR | Wait for QA pass, click the preview URL in the bot's comment |
| Test a merged change | Open the live URL (NOT the preview URL) |
| Report a regression | File a NEW issue, reference the old one |
| Make a tiny fix yourself | `git pull --rebase` -> `claude` -> fix -> push |
| Trigger a release | Add the `ship-it` label to a tracking issue |
| See trending market suggestions | Look at the game repo's `market-intel` labeled issues |
| See content agent ideas | Look at the game repo's `content-agent` labeled issues |
| See store listing assets | Look at the game repo's `ua-assets` labeled issues |
| See product improvement ideas | Look at the game repo's `product-data` labeled issues |

---

## When to ping Sahil directly

The agents handle most things. Ping Sahil for:

- Issues stuck on `build-request` for a while — he needs to run the swarm.
- A PR fails QA repeatedly with the same error.
- Anything dangerous: data loss, broken sign-in, payment, security.
- Native APK / store submission questions.
- Whenever the game *feels* ready for `ship-it` — that's a judgment call you and Sahil make together.

---

The system is built so every issue you file becomes a real change in the game. File 5-10 specific issues, Sahil runs the swarm, and the games get visibly better every single day.

— The Stratos Games Factory
