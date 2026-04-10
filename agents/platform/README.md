# platform agent

**Status**: active
**Schedule**: manual or on `ship-it` label (NOT cron)
**Cost**: zero Claude tokens

## What it does

Handles the native / multi-platform build steps that can't happen in CI on Ubuntu. This agent runs on Sahil's Mac (because it needs Xcode / Android SDK) and is triggered either manually (`bash agents/platform/platform-agent.sh bloxplode`) or by GitHub Actions calling back to a self-hosted runner when the `ship-it` label is applied.

For each game it supports, the agent:

1. `git pull` the latest `main`.
2. For **web-only games** (Arrow Puzzle): run `npm run build`, verify `docs/` is current. GitHub Pages deployment happens via the existing `deploy.yml` workflow, so this step is just a correctness check.
3. For **Capacitor + Android games** (Bloxplode):
   - `npm install`
   - `npx cap sync android` — copies `www/` into the Android project, refreshes plugin bindings.
   - If the Android SDK is available: `cd android && ./gradlew assembleRelease` to build a signed APK (or `bundleRelease` for an AAB).
   - If the Android SDK is NOT available: log a clear "please build in Android Studio" instruction and continue.
4. For **future Capacitor + iOS games**:
   - `npx cap sync ios`
   - If Xcode is available: `xcodebuild archive -workspace ...` and export the archive.
5. Files a `release-ready` issue on the game repo listing:
   - The release tag being built
   - The artifact filename(s)
   - The SHA of the commit being shipped
   - A "next steps" checklist for Ripon (upload to Play Console, App Store Connect, etc.)
6. Uploads any produced APK/AAB/IPA to the GitHub Release (if one exists for the tag).

## When it runs

**NOT scheduled.** The platform agent runs in one of two ways:

- **Manually**: `bash agents/platform/platform-agent.sh <game-slug>` from Sahil's Mac.
- **On `ship-it` label**: when the release workflow in the game repo runs and creates a release tag, it writes a `release-ready` trigger file or opens a GitHub issue that Sahil's local cron watcher picks up. (Self-hosted runners are a future improvement; for now, Sahil runs the command manually when he sees the release issue from the release workflow.)

## What data it needs

- A local clone of the game repo at the factory's expected path
- `npm`, `node`, `npx cap` available in PATH
- For Android: Android SDK + gradle wrapper (`./gradlew`) in the project
- For iOS: Xcode + `xcodebuild` in PATH
- `gh` authenticated (provided by `daemon/config.local.sh`)

## What it outputs

- **One `release-ready` issue per game build**, on the game's repo. Label: `release-ready` (the agent creates the label if it doesn't exist).
- **Artifact uploads** to the GitHub Release for the current tag (via `gh release upload`).
- **A log entry** in `agents/platform/platform-agent.log`.

## Ripon's handoff

When the agent files a `release-ready` issue, Ripon's next steps are in the issue body:

1. Download the APK/AAB from the release page.
2. Upload to Google Play Console (internal testing track first).
3. Fill in the release notes (pulled from the changelog the release workflow generated).
4. Verify Crashlytics and AdMob are initializing correctly via the test release.
5. Promote to production after 24h of clean telemetry.

## Why this is separate from the release workflow

The `release.yml` workflow in each game repo handles everything GitHub Actions can do: tagging, changelog, gh-pages deploy, GitHub Release creation. But native builds require local SDKs and signing keys that don't belong in GitHub Actions. The platform agent is the "last mile" that takes over once the web side of the release is done.

## Future: self-hosted runner

Once we have a self-hosted macOS runner with the keychain unlocked and Android SDK installed, the platform agent can move into GitHub Actions as a workflow triggered by the same `ship-it` label. Until then, it stays as a local script.
