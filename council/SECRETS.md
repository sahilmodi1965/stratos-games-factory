# Secrets & access management — Stratos Games Factory

The factory never handles production secrets. Keys flow **Sahil → Ripon → game** through GitHub-native mechanisms. The Claude Code session writes code that reads env vars; it never materializes the values.

This doc is the operational spec. Scope: how keys get into a game, who retrieves them, how the pattern scales to 5 / 50 / 500 games.

---

## Core rule

**The factory brain never handles secrets.** Not in chat, not in memory files, not in a file any Claude session reads. If a secret materializes in the Claude context window, it is leaked (prompt caching + provider retention = unknown blast radius). This rule is non-negotiable and encoded in CLAUDE.md Architecture principles.

Code that needs a secret references it structurally: `process.env.ADMOB_APP_ID`, `${{ secrets.FIREBASE_SA_JSON }}`, `const key = await op.read("op://…")`. The factory writes and reviews those references. Humans put the values in the backing store.

---

## The 3-tier pattern — GH-native

| Tier | What goes here | Where it lives | Who retrieves | Accepted blast radius on leak |
|---|---|---|---|---|
| **1. Service IAM** | Dashboard access (Play Console, App Store Connect, Firebase, AdMob, LinkRunner, AppLovin) | Each service's own "invite collaborator" | Ripon logs in with his own account — no keys move | N/A — no key to leak |
| **2. GitHub repo secrets** | Everything else. CI signing keys, App Store Connect `.p8`, fastlane tokens, Firebase service account JSON, MMP tokens, AppLovin SDK key, AdMob API credentials | `gh secret set X --repo <game-repo>` | GitHub Actions workflows pull at run time. Ripon triggers via `gh workflow run` from his own Claude Code session. | Rotate the one key + re-run `gh secret set`. ~5 min per secret. |
| **3. Public IDs in code** | AdMob app IDs, ad unit IDs, Firebase web config public keys — values that ship in the app binary and are discoverable by inspection anyway | Committed in repo under per-game config | Anyone with repo access | None — these are not secrets by Google/Apple's own definition |

**Why GH-native:** zero recurring cost, zero third-party dependency, aligns with the issues-first operating model, Ripon can drive it end-to-end from his own Claude Code session via `gh` CLI.

---

## Who does what

**Sahil:**
- Owns the root accounts (AdMob, Firebase, Play Console, App Store Connect, LinkRunner, AppLovin) — the billing relationship lives here.
- Sets repo-level admin access for Ripon on every game repo + the factory repo.
- Files new-game onboarding issues when a game reaches G1 ready for G2 prep.
- Does NOT type keys into chat, memory files, or PRs. Only into the service's own settings UI or `gh secret set` in a terminal Claude can't see.

**Ripon (executor):**
- Has admin on every game repo (own account on `mody-sahariar1/*`, manually-granted on `sahilmodi1965/*`).
- Files per-game `[secret-onboarding]` issues using the template at `templates/secret-onboarding-issue.md`.
- Runs his own Claude Code session locally; his session executes `gh secret set` and `gh workflow run` for signing, uploads, API provisioning.
- When a game integrates a new SDK, he writes the PR that adds the `process.env.X` references; his session pushes the corresponding `gh secret set`.
- Never pastes key values into PR descriptions, issue bodies, or conversation.

**Factory (this Claude Code session, any subagent):**
- Reads and writes code with structural secret references only (`process.env.X`, `${{ secrets.X }}`).
- Reviews that no secret value appears in a diff, an issue, or a PR body before merging.
- If a secret value ever appears in context, flags it immediately and stops work — rotate and investigate.

---

## Per-game onboarding checklist

Ripon runs this once per game when it enters G2 prep. Files as a `[secret-onboarding]` issue on the game repo using the template.

**Service IAM (tier 1) — dashboards:**
- [ ] Google Play Console — Sahil invites Ripon as Admin
- [ ] App Store Connect — Sahil invites Ripon as App Manager
- [ ] Firebase project — Sahil adds Ripon as Editor
- [ ] AdMob — Sahil adds Ripon as Admin on the ad account
- [ ] LinkRunner — Sahil adds Ripon to the team
- [ ] AppLovin MAX — Sahil adds Ripon to the team

**Keys to set via `gh secret set` (tier 2):**
- [ ] `ANDROID_SIGNING_KEYSTORE_BASE64` — base64-encoded keystore file
- [ ] `ANDROID_SIGNING_KEY_ALIAS`
- [ ] `ANDROID_SIGNING_KEY_PASSWORD`
- [ ] `ANDROID_SIGNING_STORE_PASSWORD`
- [ ] `APP_STORE_CONNECT_KEY_ID` + `APP_STORE_CONNECT_ISSUER_ID` + `APP_STORE_CONNECT_KEY_P8` (the .p8 contents)
- [ ] `FIREBASE_SA_JSON` — full service account JSON (base64 or raw — workflow decides)
- [ ] `ADMOB_API_SECRET` (if using AdMob reporting API)
- [ ] `LINKRUNNER_API_TOKEN`
- [ ] `APPLOVIN_MAX_SDK_KEY` (this one is arguably tier 3 — ships in app, but safer in a secret)

**Public-ish IDs that go in code (tier 3):**
- [ ] AdMob app ID — in `AndroidManifest.xml` / Capacitor config
- [ ] AdMob ad unit IDs — in game config file
- [ ] Firebase web config (`apiKey`, `projectId`, `appId` — Google confirms these are safe client-side)

**Verification the onboarding worked:**
- [ ] `gh secret list --repo <game-repo>` shows all tier-2 secrets present
- [ ] A trivial workflow (e.g. `release-dry-run.yml`) that reads each secret and logs its length (NEVER the value) succeeds
- [ ] Ripon can sign in to every tier-1 dashboard and see the game

---

## Scalability

Onboarding cost per new game: ~15 minutes (stays constant, doesn't compound).

| Scale | Tier 1 invites total | Tier 2 secrets total | Manual work per game |
|---|---|---|---|
| 1 game | 6 | ~10 | 15 min |
| 5 games | 30 invites (but mostly click-through) | ~50 secrets (scoped per repo, auto-isolated) | 15 min each |
| 50 games | 300 invites | ~500 secrets | 15 min each |
| 500 games | 3000 invites | ~5000 secrets | 15 min each, OR: automate tier 1 invites via service APIs when tooling exists |

Breaks at the 50+ scale ONLY for tier 1 (invite fatigue). At that point, evaluate moving AdMob / Firebase / Play / App-Store ownership from personal accounts to an **organization**, which gives bulk team management. That migration belongs to F4, not before.

GitHub secrets and service IAM both scale at $0/month incremental. No per-game cost.

---

## Rotation

### Planned rotation (no incident)

A clean, scheduled rotation — nothing is known to be leaked.

1. Generate new value in the source service (AdMob, Firebase, AppLovin, LinkRunner, etc.)
2. `gh secret set X --repo <game> < new-value.txt` on every repo that references the secret
3. Invalidate the old value in the source service (revoke / delete the old credential)
4. Re-trigger any workflow that uses the secret (`gh workflow run release-dry-run.yml`) and confirm green
5. No git history action — nothing was committed

### Emergency rotation (suspected or confirmed leak)

Follow this in order. Do not shortcut.

**Step 1 — Contain (within 15 minutes of detection).**
- Decide: **rotate** (preferred) or **restrict** (fallback). Rotation invalidates the leaked value entirely; restriction scopes the leaked value so it's useless without matching context.
- **Firebase Web API keys** — GCP allows scoping to bundle ID + HTTP referrer via *APIs & Services → Credentials → API restrictions*. A restricted Firebase Web API key is safe even when public (Google explicitly treats these as client-safe when restricted). **Prefer restriction over rotation for Firebase Web API keys** — rotation cascades to every client build.
- **Service account JSON, signing keystores, `.p8` keys, MMP tokens, AppLovin SDK keys** — **always rotate**, never restrict. These are true bearer credentials.
- **AdMob API secret, LinkRunner token** — **always rotate**.

**Step 2 — Propagate (within 30 minutes).**
- List every repo referencing the secret: `for r in $(git config --get remote.origin.url 2>/dev/null; ls ~/stratos-games-factory/*/); do grep -l "<SECRET_NAME>" ...; done` or consult `daemon/config.sh` for the portfolio list.
- `gh secret set <SECRET_NAME> --repo <each-repo> < new-value.txt`
- Verify: `gh secret list --repo <each-repo> | grep <SECRET_NAME>` shows updated `Updated` timestamp.

**Step 3 — Verify (within 60 minutes).**
- Re-run the canonical workflow that uses the secret (`gh workflow run <name>.yml`). Wait for green.
- Spot-check one real build (Android signing, iOS upload) — rotation breaks builds silently if any workflow step references an un-updated secret name.

**Step 4 — Scrub git history (only if committed).**
- If the value landed in a commit: `git filter-repo --replace-text <(echo '<value>==><REDACTED>')` + force-push. This is disruptive (rewrites history, breaks open PRs, invalidates all local clones). Prefer accepting the rotation cost over filter-repo unless the value was pushed to a public repo.
- If the value was only pasted in an issue/PR body/comment on GitHub: `gh api --method DELETE` the comment, then rotate anyway (cached in webhook deliveries, Search index, notification emails).

**Step 5 — Document (always).**
- File a `swarm-state` note on `sahilmodi1965/stratos-games-factory` labeled `swarm-state` with body:
  - **Filed:** ISO date
  - **Incident:** what leaked, how it was discovered
  - **Action taken:** rotated / restricted / scrubbed
  - **Why this note exists:** future-self must see the pattern on the next incident
  - **When to close:** 30 days post-rotation with no recurrence
- The note is durable incident memory — future-Claude reads it at the start of every assess pass.

### Which secrets map to which response

| Secret class | On leak: rotate or restrict? | Cascade cost |
|---|---|---|
| Firebase Web API key (`apiKey` in web config) | **Restrict** (GCP scope to bundle/referrer) | Low — no client rebuild |
| Firebase SA JSON (`FIREBASE_SA_JSON`) | **Rotate** | Medium — re-run CI |
| Android signing keystore (`ANDROID_SIGNING_*`) | **Rotate** — but coordinate; a rotated signing key means Play Store upload key rotation via App Signing by Google Play (otherwise next update is rejected) | High — coordinate with Play Console |
| App Store Connect `.p8` (`APP_STORE_CONNECT_KEY_P8`) | **Rotate** — generate new in App Store Connect | Medium |
| AdMob API secret (`ADMOB_API_SECRET`) | **Rotate** | Low |
| LinkRunner API token (`LINKRUNNER_API_TOKEN`) | **Rotate** | Low |
| AppLovin SDK key (`APPLOVIN_MAX_SDK_KEY`) | **Rotate** | Medium — client rebuild required |

### Historical precedent

Arrow Puzzle Firebase Web API key was once committed to the game repo. Restricted via GCP *API restrictions* (bundle ID + HTTPS referrer) rather than rotated, on the reasoning that restricted Firebase Web API keys are documented as client-safe. That response is the pattern codified above for this key class. Source: arrow-puzzle issue #151 (Firebase Analytics integration, G2 omnibus PR #166). The key itself still appears in git history — accepted cost, given the restriction makes the value inert.

---

## Pre-commit guardrail (follow-up factory-improvement, not part of #51)

Belt-and-suspenders to prevent accidental commits of real key values: add a lightweight `gitleaks` or `trufflehog` pre-commit hook to each game repo via husky. Scans the diff for known secret patterns (AWS keys, Firebase SA shape, private key PEM blocks). Blocks commit if found. Filed as a follow-up if this pattern holds up in practice.

---

## When a service has no GH-native equivalent

Some keys don't fit cleanly into tier 2 — e.g., a passphrase Ripon types into Xcode's signing UI interactively, or a TOTP backup code. For those:

1. Prefer to regenerate on demand (not all keys need to persist).
2. If persistence is required, use a personal password manager (macOS Keychain, Bitwarden free tier on Ripon's machine) — explicitly scoped to the individual, NOT shared.
3. Document in `[secret-onboarding]` issue which keys are "Ripon-local-only" so Sahil doesn't expect to find them in repo secrets.

Shared password manager (1Password Teams at $20/month) is a supported escape hatch if this category grows. Until then, keep tier 2 wide and this escape hatch narrow.
