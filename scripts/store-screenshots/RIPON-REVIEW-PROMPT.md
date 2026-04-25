# Ripon's Claude Code review prompt

Sahil — copy everything between the `--- BEGIN ---` and `--- END ---` markers below
and paste it as a single message into Ripon's Claude Code session. The prompt is
self-contained: his Claude does the whole review walkthrough, captures structured
feedback, posts it to factory PR #89, confirms the URL.

After each round of feedback, the factory rebuilds the brain, regenerates all 30
PNGs, force-pushes the per-game review PRs (BX #71, HM #125, and a fresh AP
review PR), and you re-paste this same prompt to Ripon for round 2. Loop until
he says "ready to merge" on factory PR #89.

---

## --- BEGIN ---

You're helping me (Ripon — operator at Stratos Games) review 30 store-listing screenshots that the factory's new screenshot brain just generated for our 3 games: Arrow Puzzle, Bloxplode, house-mafia.

The **brain itself** is in DRAFT on factory PR https://github.com/sahilmodi1965/stratos-games-factory/pull/89 — it's gated on my review before merge. The same brain produced all 30 screenshots, so my feedback shapes every game's listing at once.

### Where the PNGs live

| Game | Repo | Where |
|---|---|---|
| Arrow Puzzle | `mody-sahariar1/arrow-puzzle-testing` | `main` branch, `store-assets/ios-6.5/` + `store-assets/play-1080x2400/` (PR #222 auto-merged via CI before draft conversion — that's fine, it's still review-only until brain merges) |
| Bloxplode | `mody-sahariar1/Bloxplode-Beta` | DRAFT PR #71, `store-assets/ios-6.5/` + `store-assets/play-1080x2400/` |
| house-mafia | `mody-sahariar1/house-mafia` | DRAFT PR #125, `store-assets/ios-6.5/` + `store-assets/play-1080x2400/` |

### What I need you to do — start here

**Step 1.** Ask me: "Where are your local clones? Default is `~/stratos-games-factory/{arrow-puzzle-testing, Bloxplode-Beta, house-mafia}/`. Confirm or tell me the actual paths."

**Step 2.** For each game in order (AP → BX → HM), pull latest:

```bash
# AP (already on main)
cd <ap-clone> && git fetch origin --quiet && git checkout main --quiet && git pull --quiet

# BX (draft review PR #71)
cd <bx-clone> && git fetch origin --quiet && gh pr checkout 71 --repo mody-sahariar1/Bloxplode-Beta

# HM (draft review PR #125)
cd <hm-clone> && git fetch origin --quiet && gh pr checkout 125 --repo mody-sahariar1/house-mafia
```

**Step 3.** Walk me through all 30 shots. For each game, show iOS 6.5" first (5 shots), then Play 1080×2400 (5 shots). Use your `Read` tool on the PNG path so I see the image inline. After each shot, ask me these 4 questions and capture my answers:

1. **Visual quality** — 1 to 5. (1 = reject, 5 = "this could ship today as a paid ad")
2. **Per-store compliance** — anything Apple App Store or Google Play reviewers might reject? Examples: text obscured by safe-area, fake screenshots that aren't real functionality, copy that promises features the app doesn't have, padding/margins outside store-mandated zones, anything misleading.
3. **Caption + sub copy** — does the headline land? Is the sub-line truthful + specific? Suggest a rewrite if it doesn't work.
4. **Specific tweaks** — concrete: "rotate the device 5°" / "make the gradient darker" / "the explosion is too small for the canvas" / "this scene doesn't match what we actually show in-game". Be specific so the factory can act on it.

**Step 4.** When all 30 are reviewed, compile **one** markdown using this exact structure:

```markdown
## Ripon's review — round <N>
**Date:** <YYYY-MM-DD>
**Brain PR:** sahilmodi1965/stratos-games-factory#89

### Cross-cutting (applies to all/most shots — fix at the brain level)
- <e.g. "Hero captions are too small at iOS 6.5" — bump to 14% of viewport width">
- <e.g. "Device frame radius reads dated — go thinner border + sharper corners">
- <e.g. "Brand strip 'BY STRATOS GAMES' is barely legible on dark backgrounds">

### Arrow Puzzle (10 shots)

#### 01 Mid-Expert puzzle (iOS 6.5")
- **Quality:** 4/5
- **Compliance:** none
- **Copy:** "Tap. Flip. Solve." reads great; sub is solid
- **Tweaks:** Make the puzzle board denser — Level 80 should look harder than this

#### 02 Daily streak (iOS 6.5")
...

(repeat for each of the 30 shots — all 5 iOS + all 5 Play per game)

### Bloxplode (10 shots)
...

### house-mafia (10 shots)
...

### My recommendation
- [ ] Ready to merge factory PR #89
- [x] Needs another pass — top 3 priorities: <list>
```

**Step 5.** Save the markdown to `~/ripon-review-round-1.md` and post it as a comment on factory PR #89:

```bash
gh pr comment 89 --repo sahilmodi1965/stratos-games-factory --body-file ~/ripon-review-round-1.md
```

The command will print a URL. **Tell me the URL** so I confirm it landed before we wrap.

### Important style notes

- Don't summarize my answers back to me before I'm done — I just want to look at each PNG, drop my reaction, move on. Pace matters.
- If a shot is broken (file missing, won't open, distorted), flag it explicitly in the markdown — don't skip silently.
- If you notice something I should care about that I didn't mention (e.g. a typo in copy I missed, a clear compliance flag), add a 5th line "**Claude noticed:**" under that shot. I'll review and either keep or strip.
- Cross-cutting goes FIRST in the markdown. The factory acts on cross-cutting fixes before per-shot tweaks.
- After posting the comment, exit. Don't try to merge anything, don't push branches, don't open new PRs.

### Background, in case I ask

The brain is **scenes-as-HTML** (not live-game capture) — each shot is a standalone HTML+CSS+SVG file under `scripts/store-screenshots/scenes/<game>/<id>.html` that visually reproduces a real game state. The factory renders each scene through a marketing template (`template/marketing.html`) at exact store viewports. It's ~10× faster than driving the live game and lets us mock states the live game doesn't easily emit. App Store + Play Store both explicitly allow this provided the scenes represent real functionality, which they do.

Now: start with **Step 1** — ask me where my repos are.

## --- END ---
