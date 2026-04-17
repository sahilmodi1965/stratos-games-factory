# Ripon Task List — 2026-04-16

## How this works

**North star:** Ship real-world working products with correct monetization, correct distribution, and correct compliance. Real games in real users' hands, on real stores, with ads serving and data flowing.

**The system:** Two people (Sahil + Ripon) operate a factory that does the engineering of an entire studio. The factory is issue-driven — every observation, bug, idea, or gap becomes a GitHub issue. The swarm (7 autonomous agents) reads those issues, builds code, opens PRs, reviews itself, identifies new gaps, and files new issues. The cycle repeats. No issue = no code change. No data from Ripon = dormant agents.

**How F-milestones and G-milestones work together:**

- **F-series (Factory milestones)** track the factory's own capability: F1 = ship one real game, F2 = ship multiple, F3 = one per week, F4 = five per week. Currently at **F1**.
- **G-series (Game milestones)** track each game's journey to launch: G1 = core loop works, G2 = packaged for stores with ads/analytics stubbed, G3 = submitted + real installs, G4 = liveops from real data, G5 = autopilot. Each game has its own G-pointer.
- **F1 closes when at least one game reaches G3** — a real game on real stores with real users and real revenue.
- **Every G-milestone advancement generates factory lessons** that get encoded as brain rules, memory files, and factory-improvement issues — making the NEXT game's G1→G3 journey faster. This is how 2 people scale to a studio.

**Ripon's role in this system:**

You are the human eye the factory cannot replace. You play games, find bugs, file issues, provide analytics data, integrate native SDKs, submit to stores, and merge PRs. Every task below creates a GitHub issue (or comments on one) that feeds the factory's 7 agents. When you do a task, the factory moves. When you don't, the agents sit idle.

---

## Current game status

| Game | G-stage | What works | What's blocking the next G | North star distance |
|---|---|---|---|---|
| **Bloxplode** | **G2 → G3** | Live on Play Store. AdMob in test mode. Firebase analytics live. Capacitor Android working. | LinkRunner MMP dashboard broken on iOS. AppLovin MAX delayed. Apple submission pending. | Closest to F1 exit — needs 3 distribution fixes |
| **Arrow Puzzle** | **G1 → G2** | Live on web. Tutorial polished. Dense generator working. 5 Playwright smoke tests. | Not packaged for mobile. No ads. No analytics code. No store listing. | Needs Capacitor wrap before anything else |
| **House Mafia** | **G1** | Multiplayer works. Dev mode works. Pass & Play works. | 3 core-loop bugs (#113 timer, #114 host migration, #115 sound). PR #117 draft in flight. | Furthest — core loop must stabilize first |

---

## Priority task list

Every row is an issue. Every issue feeds an agent. Every agent output creates more issues. The system improves itself while keeping the brain, factory, and codebase lean — maximum engineering from 2 people.

### Tier 0 — Distribution blockers (only Ripon can do these)

These are real-world gates the factory cannot build code for. Native SDK integrations, store submissions, dashboard verifications. Unblocks: F1 exit.

| Priority | Game | Task | Issue | G-gate | Agents unlocked |
|---|---|---|---|---|---|
| 0a | Bloxplode | Debug LinkRunner MMP on iOS — Xcode logs confirm it fires but dashboard shows nothing. Check bundle ID, API key, sandbox/production toggle. Contact LinkRunner support if needed. | [Bloxplode #21](https://github.com/mody-sahariar1/Bloxplode-Beta/issues/21) | G3 | UA agent (can verify attribution) |
| 0b | Bloxplode | Fix AppLovin MAX issues — resolve whatever is causing the delay. MAX mediation is the promotion-readiness gate. | [Bloxplode #22](https://github.com/mody-sahariar1/Bloxplode-Beta/issues/22) | G3 | Monetization agent (can optimize mediation) |
| 0c | Bloxplode | Follow up on Apple submission — is it rejected, pending, or in limbo? Comment the status. | [factory #35](https://github.com/sahilmodi1965/stratos-games-factory/issues/35) | G3 | UA agent (needs both stores live) |
| 0d | Arrow Puzzle | Wrap with Capacitor — `npx cap init + add android + add ios`. Unblocks ALL native integrations. | [Arrow Puzzle #150](https://github.com/mody-sahariar1/arrow-puzzle-testing/issues/150) | G2 | Builder (can integrate AdMob, Firebase) |
| 0e | Arrow Puzzle | Integrate Firebase Analytics — registered but no code. 4 events: session_start, level_complete, tutorial_complete, level_fail. | [Arrow Puzzle #151](https://github.com/mody-sahariar1/arrow-puzzle-testing/issues/151) | G2 | Product agent (can analyze player data) |

### Tier 1 — Data that unlocks dormant agents

The product agent has **never fired** for any game. The monetization agent can only review Bloxplode. These tasks provide the data that wakes them up.

| Priority | Game | Task | Issue | G-gate | Agents unlocked |
|---|---|---|---|---|---|
| 1a | Bloxplode | Paste Firebase Analytics data — session lengths, level completion rates, daily installs, ad impressions, crash reports. Screenshot the dashboard. | [Bloxplode #20](https://github.com/mody-sahariar1/Bloxplode-Beta/issues/20) | G3 | **Product agent (first ever fire)** |
| 1b | Bloxplode | Verify ads in production — Play Store version, play 3+ minutes. Did banner appear? Did interstitial fire? Screenshot. | [Bloxplode #15](https://github.com/mody-sahariar1/Bloxplode-Beta/issues/15) | G3 | Monetization agent (verify real performance) |
| 1c | House Mafia | Paste play-test session data — how many players, which phase broke, what happened, how long, did you finish a round. | [House Mafia #119](https://github.com/mody-sahariar1/house-mafia/issues/119) | G1 | Product agent (prioritize bug fixes) |
| 1d | Arrow Puzzle | Paste any analytics data (once Firebase is integrated) or structured play-test notes. | [Arrow Puzzle #149](https://github.com/mody-sahariar1/arrow-puzzle-testing/issues/149) | G2 | Product agent |

### Tier 2 — Play-test + file bugs (feeds the Builder agent)

The builder agent is the most important agent. It runs on `build-request` issues that Ripon files from play-testing. No bugs filed = no code built.

| Priority | Game | Task | Issue | G-gate | Agents unlocked |
|---|---|---|---|---|---|
| 2a | Arrow Puzzle | Merge PR #148 (arrowhead direction + step 0 layout fix). Test on phone with `?reset=1` first. | [PR #148](https://github.com/mody-sahariar1/arrow-puzzle-testing/pull/148) | G1 | Content agent (clears queue to <10) |
| 2b | Arrow Puzzle | Play through tutorial + 30 levels on phone after merge. Report anything off: arrow sizes, hand position, banner, difficulty curve. | File as `build-request` | G1 | Builder agent |
| 2c | Arrow Puzzle | Play in landscape mode on iPad. Does layout adjust? Arrows clipped? Banner readable? | File as `build-request` if broken | G1 | Builder agent |
| 2d | House Mafia | Run 4-player `?dev=1` session (4 tabs). Walk through: lobby → night → discuss → vote → results. Note which phase breaks. | Comment on [#119](https://github.com/mody-sahariar1/house-mafia/issues/119) | G1 | Builder agent |
| 2e | House Mafia | Test Pass & Play mode — single-device full round. Night → discuss → vote → elimination → reveal. | File as `build-request` if broken | G1 | Builder agent |
| 2f | Bloxplode | Play 10 adventure levels on Play Store version. Note difficulty curve, crashes, ad timing (too frequent? too early?). | File observations on existing issues | G3 | Monetization agent |

### Tier 3 — Store readiness (feeds the UA agent)

The UA agent generates store listing variants, ASO keywords, and screenshot compositions. But it needs real screenshots from Ripon and a privacy policy before any store submission.

| Priority | Game | Task | Issue | G-gate | Agents unlocked |
|---|---|---|---|---|---|
| 3a | Arrow Puzzle | Take 10 gameplay screenshots at different levels (tutorial with hand, easy boards, dense boards). | Comment on [#47](https://github.com/mody-sahariar1/arrow-puzzle-testing/issues/47) | G2 | UA agent (screenshot compositions) |
| 3b | Arrow Puzzle | Write 2-sentence "what is this game" description in your own words. | Comment on [#47](https://github.com/mody-sahariar1/arrow-puzzle-testing/issues/47) | G2 | UA agent (description variants) |
| 3c | Bloxplode | Write privacy policy — what data collected, what ads SDK does, no login, no personal data. Even 1 paragraph works. | File as `build-request` | G3 | Compliance gate (store requirement) |
| 3d | House Mafia | Write privacy policy — Supabase room data, presence tracking, data persistence after game ends. | File as `build-request` | G2 | Compliance gate |

### Tier 4 — Content ideas (feeds the Content agent)

The content agent generates level ideas and feature proposals. It auto-fires when `build-request` count is <10. Ripon can also seed it with his own ideas.

| Priority | Game | Task | Issue | G-gate | Agents unlocked |
|---|---|---|---|---|---|
| 4a | Arrow Puzzle | File 2-3 feature ideas: daily challenge mode? speed run timer? undo button? color themes? difficulty selector? | File as `build-request` | G1-G2 | Content agent (human-seeded ideas) |
| 4b | House Mafia | File multiplayer UX ideas: spectator chat? emoji reactions? role-reveal animations? custom room names? | File as `build-request` | G1 | Content agent |
| 4c | Bloxplode | File level design ideas: new block types? grid shapes? power-ups? boss levels? endless mode? | File as `build-request` | G3 | Content agent |

### Tier 5 — Team scaling (from 1-1 action items)

| Priority | Task | Why |
|---|---|---|
| 5a | Create intern onboarding document — SSH setup, GitHub workflow, terminal prompts, testing process | Lamia, Ridhima, Sooraj, Bhabi need this before they can contribute |
| 5b | 10 one-time pastable terminal prompts for interns | From the 1-1: prompting and debugging practice |
| 5c | Show publishing a terminal project to GitHub (full cycle mini-project) | SSH connection, remote-first workflow, sharable link |

---

## How the cycle works (the flywheel)

```
Ripon plays game → finds bug/gap → files issue on GitHub
                                         ↓
                              Sahil says "go"
                                         ↓
                    Factory reads issues → builds code → opens PRs
                                         ↓
                    Ripon reviews PR → merges or comments feedback
                                         ↓
                    Factory agents fire (content/competitor/UA/product/monetization)
                              → identify more gaps → file more issues
                                         ↓
                    Council reviews the week → encodes lessons into brain
                              → brain makes next cycle smarter
                                         ↓
                              Game advances G1 → G2 → G3
                                         ↓
                        F1 closes when first game hits G3
                                         ↓
                    Factory uses encoded lessons to ship game 2 faster (F2)
```

**Every issue Ripon files is a turn of this flywheel.** The factory does the engineering. The brain remembers the lessons. The council monitors the health. Two people, one system, studio-level output.

---

## What "done" looks like for F1

F1 closes when **one game** passes this checklist:

- [ ] Live on web (GitHub Pages) ← Bloxplode ✅, Arrow Puzzle ✅
- [ ] Live on Google Play with signed APK ← Bloxplode ✅
- [ ] Live on Apple App Store ← Bloxplode ⏳ (pending)
- [ ] AdMob ads serving real impressions ← Bloxplode ⏳ (test mode)
- [ ] AppLovin MAX mediation live ← Bloxplode ❌ (issues)
- [ ] LinkRunner MMP dashboard-verified ← Bloxplode ❌ (iOS broken)
- [ ] Firebase Analytics events flowing ← Bloxplode ✅
- [ ] Privacy policy published ← All games ❌
- [ ] 10+ real installs ← Bloxplode ❓ (need data from Ripon)
- [ ] UA store listing reviewed ← Bloxplode ⏳

**Bloxplode is 5 checkboxes away from closing F1.** Three of those (Apple, AppLovin, LinkRunner) are Tier 0 — only Ripon can unblock them. That's why Tier 0 is the highest priority.
