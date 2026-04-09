# Ripon's Guide to the Stratos Games Factory

> A non-technical, step-by-step guide for play-testing Stratos games and getting changes built.

Hi Ripon! This is your guide to working with the Stratos Games Factory. You don't need to know how to code. Your job is to **play the games, find what's wrong or what could be better, and tell us in a way the system can understand**. The factory does the rest.

---

## The big picture (in plain words)

```
You play a game  →  You file a "Build Request"  →  Within an hour, the robot fixes it  →  Sahil checks and ships it  →  You play again
```

That's the whole loop. You don't write code. You don't run anything. You just play, observe, and write clear requests.

Three things you need:
1. A computer or phone to play the games on.
2. A GitHub account (free).
3. Optionally, the $20/month Claude Chat subscription to help you write up your feedback clearly.

---

## 1. How to play-test a game build

Each Stratos game has a **live build** you can play in your browser:

| Game | Where to play |
|---|---|
| Arrow Puzzle | https://mody-sahariar1.github.io/arrow-puzzle-testing/ |
| Bloxplode | (mobile build — Sahil will share a link or APK) |

**While you play, look for:**
- 🐛 **Bugs** — anything that doesn't work the way it should. ("The score doesn't go up when I clear a row.")
- 🎯 **Tuning issues** — anything that feels wrong. ("Level 5 is way too hard.", "The combo sound is too quiet.")
- ✨ **Small improvements** — tiny things that would make the game better. ("The Restart button should also be at the top of the screen, not just the bottom.")

**Things to write down as you play:**
- Exactly *what you did* (the steps).
- Exactly *what happened* (what you saw).
- Exactly *what you expected to happen* instead.
- *Where in the game* it happened (level number, screen name, after which action).

The more specific you are, the better the robot can fix it.

> 💡 **Tip:** Take a screenshot or screen recording if you can. You don't need to attach it to the issue, but it helps you remember the exact moment when you write the report.

---

## 2. How to file a Build Request issue

This is the most important skill in the whole loop.

### Step 1: Go to the game's repo

- For Arrow Puzzle: https://github.com/mody-sahariar1/arrow-puzzle-testing
- For Bloxplode: https://github.com/mody-sahariar1/Bloxplode-Beta

Click the **Issues** tab at the top.

### Step 2: Click "New Issue"

You'll see a button that says **"New issue"** on the right side. Click it.

### Step 3: Pick the "Build Request" template

You should see a list of templates. Pick **"Build Request"**. (If you only see a blank issue form, it means the template hasn't been deployed yet — tell Sahil.)

### Step 4: Fill in the template

The template has five sections. Here's how to fill each one:

#### "What's wrong / what should change?"
One or two sentences. Plain language. Examples:
- "The arrow on the top-right of the puzzle doesn't rotate when I tap it."
- "The combo counter resets to zero between rounds, but it should keep counting."
- "The 'Try Again' button is too small on phones."

#### "Where in the game does this happen?"
Tell us *where*. Examples:
- "Main menu"
- "Level 12"
- "After I clear a 4-row combo"
- "Settings → Audio screen"

#### "How should it look / behave instead?"
What's the *right* behavior? Be specific. If it involves a number (timer, score, count, color), say the exact number you want.
- "It should rotate 90 degrees clockwise like all the other arrows."
- "The combo counter should keep going up across rounds, only resetting on game over."
- "The 'Try Again' button should be at least 60 pixels tall on phones."

#### "How to reproduce (if it's a bug)"
Number the steps. Skip this section if it's a tweak, not a bug.
1. Open the game.
2. Start a new puzzle.
3. Tap the top-right arrow.
4. Notice it does not rotate.

#### "Anything else?"
Optional. Add screenshots, video links, or anything else useful.

### Step 5: Submit

Click **"Submit new issue"**. The label `build-request` is added automatically by the template. **You don't need to add it yourself.** If you don't see the label after submitting, add it manually by clicking the gear icon next to "Labels" on the right and selecting `build-request`.

That's it! The robot will see it within an hour.

---

## 3. What the labels mean

You'll see three labels on issues. Here's what each one means:

| Label | Color | Meaning |
|---|---|---|
| `build-request` | green | You filed a request. The robot will pick it up on the next hourly run. |
| `building` | yellow | The robot is working on it RIGHT NOW. Don't edit the issue while this is on. |
| `done` | purple | The robot finished and opened a Pull Request. Look for a comment with the PR link. |

If your issue still has `build-request` after a few hours and nothing has happened, ping Sahil — the daemon may not be running.

---

## 4. How to check if the build ran

After you file an issue, here's what to look for over the next hour:

1. **Within an hour**, you should see a comment from "🤖 Stratos daemon" on your issue.
2. The comment will say one of three things:
   - **"build complete → [PR link]"** — Success! The robot made the change. Click the link to see the PR.
   - **"ran but produced no changes"** — The robot tried but couldn't figure out what to do. There will be an explanation. Go back and rewrite your issue more clearly, or open a new one.
   - **"this request is too large"** — Your issue had more than 50 lines. Split it into smaller issues — one thing per issue.
3. If the issue is now labeled `done` and there's a PR link, you're ready for step 5.

---

## 5. How to test the PR build on staging

When the robot opens a Pull Request, the change isn't live yet. It's waiting for Sahil to review and merge.

For **Arrow Puzzle**, Sahil can deploy a preview build for you to test before merging. Just comment on the PR: *"Can I get a preview build to test?"* Sahil will reply with a link.

After Sahil merges the PR:
- For **Arrow Puzzle**, it usually goes live on the same URL within a few minutes.
- For **Bloxplode**, Sahil will rebuild the Android app and share a new APK or test link.

**Always re-test after the merge** — sometimes the fix doesn't quite match what you wanted. That's okay. That's why we play-test.

---

## 6. What to do if the build is wrong

If you test the merged change and it's still not right:

**Open a NEW issue.** Don't comment on the old one or on the PR. The robot only reads new issues with the `build-request` label, so a fresh issue is the only way to put another item in the build queue.

In the new issue, you can reference the old one:
- *"This is a follow-up to #42. After that change, the arrow rotates, but it now skips the animation. The animation should still play."*

Then submit. The loop runs again.

---

## 7. Using Claude Chat to structure your feedback

If you have the $20/month Claude Chat subscription (claude.ai), you can use it as a writing assistant. It will not file the issue for you — but it can help you turn rough thoughts into a clear Build Request.

**How to use it:**

1. Open claude.ai.
2. Start a new chat. Type:

   > I'm play-testing a web game called Arrow Puzzle. I want you to help me write a clear Build Request for the Stratos Games Factory. The format has these sections: "What's wrong", "Where in the game", "How it should behave", "How to reproduce", "Anything else". I'll describe what I saw, and you'll turn it into a properly-formatted Build Request that's under 50 lines. Keep each section short. Ready?

3. Describe what you saw in your own words. Don't worry about being neat.
4. Claude will reply with a properly-formatted Build Request.
5. Read it back to make sure it's accurate. If not, tell Claude what to change.
6. Copy-paste the result into the GitHub issue template.

**Important:** Always read what Claude wrote *before* you submit. Claude can sometimes invent details that you didn't actually see. You are the source of truth — Claude is just a writing helper.

---

## Quick reference card

| I want to... | Do this |
|---|---|
| Report a bug | Open an issue → Build Request template → fill all sections → submit |
| Suggest a tweak | Same as above, skip "How to reproduce" |
| Check if my issue is being built | Look at the labels: green = waiting, yellow = building, purple = done |
| See the fix | Click the PR link in the daemon's comment on your issue |
| Re-test after a merge | Reload the game URL or get the new APK from Sahil |
| Report that the fix didn't work | Open a NEW issue (not a comment) and reference the old one |
| Get help writing the issue | Use Claude Chat at claude.ai with the prompt above |

---

## When to ping a human (Sahil)

The robot handles most things, but ping Sahil directly if:

- Your issue still has `build-request` after several hours (daemon may be down).
- The robot keeps refusing the same issue (you may need to break it into smaller pieces, and Sahil can help).
- The fix in the PR is going in the wrong direction repeatedly (you and Sahil should talk it through).
- You spot something dangerous (data loss, security, broken sign-in) — those need a human, not the robot.

---

That's everything. The system is designed to make your feedback matter — every issue you file becomes a real change in the game, usually within hours. Have fun play-testing!

— The Stratos Games Factory
