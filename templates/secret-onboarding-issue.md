# `[secret-onboarding] <game-name>` — issue template

Ripon files one of these per game when the game enters G2 prep. He files it on the **game repo** (not the factory), labels it `secret-onboarding` + `build-request`, and tags it with the game's current G-milestone.

His own Claude Code session, run locally on his machine with his admin token, executes this issue end-to-end using the `gh` CLI. The factory's Claude Code session (Sahil's) never sees the issue body's values — it only sees the structural references that land in the game's code.

Copy the block below into a new issue on the game repo.

---

```markdown
## Tier 1 — service IAM invites
Confirm when Sahil has invited you in each dashboard. Tick each as you accept the invite and log in successfully.

- [ ] Google Play Console — Admin
- [ ] App Store Connect — App Manager
- [ ] Firebase — Editor
- [ ] AdMob — Admin
- [ ] LinkRunner — Team member
- [ ] AppLovin MAX — Team member

## Tier 2 — `gh secret set` on this repo
Sahil provides values via 1Password / direct handoff. You set each via `gh secret set`, confirm via `gh secret list`. **Never paste the value into this issue.**

- [ ] `ANDROID_SIGNING_KEYSTORE_BASE64`
- [ ] `ANDROID_SIGNING_KEY_ALIAS`
- [ ] `ANDROID_SIGNING_KEY_PASSWORD`
- [ ] `ANDROID_SIGNING_STORE_PASSWORD`
- [ ] `APP_STORE_CONNECT_KEY_ID`
- [ ] `APP_STORE_CONNECT_ISSUER_ID`
- [ ] `APP_STORE_CONNECT_KEY_P8`
- [ ] `FIREBASE_SA_JSON`
- [ ] `LINKRUNNER_PROJECT_TOKEN`
- [ ] `LINKRUNNER_SECRET_KEY`
- [ ] `LINKRUNNER_SECRET_ID`
- [ ] `APPLOVIN_MAX_SDK_KEY`
- [ ] _(additional per-game secrets, listed by Sahil in the comment below)_

## Tier 3 — public IDs in code
These ship in the app and are safe in the repo. Paste the values as PR comments on the integration PRs that reference them, not in this issue.

- [ ] AdMob app ID → `AndroidManifest.xml` + Capacitor config
- [ ] AdMob ad unit IDs → game config
- [ ] Firebase web config (apiKey, projectId, appId) → web SDK init

## Verification
- [ ] `gh secret list --repo <owner/repo>` shows all tier-2 entries present
- [ ] **Run `secret-validator.yml` and let the robot confirm** — after every `gh secret set`, fire:
      ```bash
      gh workflow run secret-validator.yml \
        --repo <owner/repo> \
        -f onboarding_issue=<THIS_ISSUE_NUMBER>
      ```
      The workflow will comment on this issue with `✅ present (length N)` / `❌ MISSING` per secret. Values are never logged, only lengths. Workflow exits red if any slot is missing.
- [ ] Every tier-2 secret above shows ✅ in the validator's comment before proceeding
- [ ] You can log in to every tier-1 dashboard and see the game
- [ ] Close this issue with a comment linking to the green validator run

## On leak — rotation / restriction playbook
If any secret above is ever exposed (committed to git, posted in a screenshot, leaked in a log, pasted in chat), follow the emergency rotation steps in [`council/SECRETS.md`](../council/SECRETS.md#emergency-rotation-suspected-or-confirmed-leak) — 5-step protocol (contain → propagate → verify → scrub → document). The "Which secrets map to which response" table tells you whether to rotate or restrict for each key class. Always file a `swarm-state` note on the factory repo as the final step so the incident is durable across sessions.

## Anti-checklist — do NOT do any of these
- [ ] Paste a real secret value into this issue, a PR body, a commit message, or chat
- [ ] Share secrets with the factory Claude Code session (Sahil's main brain) via copy-paste
- [ ] Commit a secret value to the repo, even transiently in a squashed branch
- [ ] Store production keys in your shell history (`history -c` after `gh secret set ... < file`)
- [ ] Grant another collaborator admin without Sahil's explicit approval
```

---

## Why this issue template exists

- **Auditable single source of truth per game** — every key that should exist for a game is listed here; missing-key regressions become visible.
- **Ripon-driven** — his own Claude Code session executes this end-to-end with his own tokens; Sahil isn't the bottleneck once invites are sent.
- **Non-leaky by construction** — the issue body has checkboxes, not values. Values flow out-of-band (Sahil → Ripon → `gh secret set`).
- **Fits the issues-first rule** — no code change without an issue; this issue IS the audit trail for the game's secret inventory.

## What goes in the Sahil-comment that follows issue creation

Sahil adds one comment per issue listing any per-game secrets beyond the tier-2 defaults (e.g., game-specific analytics keys, third-party integrations). He does NOT include values — only key names and a one-line note on where Ripon gets the value (e.g., "1Password `Stratos/arrow-puzzle/admob-api-secret`" or "I'll paste it in a Signal DM").
