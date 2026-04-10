#!/bin/bash
# platform-agent.sh — native / multi-platform build agent.
#
# Usage:
#   bash agents/platform/platform-agent.sh                    # all active platform targets
#   bash agents/platform/platform-agent.sh bloxplode          # just Bloxplode
#   bash agents/platform/platform-agent.sh arrow-puzzle       # just Arrow Puzzle
#
# Runs locally on Sahil's Mac (or any host with the right SDKs). Not a cron
# job — triggered manually or by a future self-hosted runner on ship-it.

set -uo pipefail

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$HOME/.nvm/versions/node/v20.20.0/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FACTORY_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck disable=SC1091
source "$FACTORY_DIR/daemon/config.sh"

LOG="$SCRIPT_DIR/platform-agent.log"
mkdir -p "$SCRIPT_DIR"
touch "$LOG"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }
die() { log "FATAL: $*"; exit 1; }

for tool in git gh jq npx; do
  command -v "$tool" >/dev/null 2>&1 || die "missing tool: $tool"
done
gh auth status >/dev/null 2>&1 || die "gh CLI not authenticated"

log "================ platform agent run starting ================"

TARGET_SLUG="${1:-}"

# bash 3.2 (macOS default) lacks `mapfile`, so build the array via while-read.
active_repos=()
while IFS= read -r line; do
  [[ -n "$line" ]] && active_repos+=("$line")
done < <(jq -r '
  .agents[]
  | select(.name == "platform" and .status == "active")
  | .repos[]
' "$FACTORY_DIR/agents/registry.json" 2>/dev/null)

if [[ ${#active_repos[@]:-0} -eq 0 ]]; then
  log "no active platform targets, exiting"
  exit 0
fi

# Ensure release-ready label exists on each active repo
for repo in "${active_repos[@]}"; do
  gh label create "release-ready" --repo "$repo" \
    --color "0e8a16" \
    --description "Native build complete, artifacts ready for store upload" \
    >/dev/null 2>&1 || true
done

process_repo() {
  local repo="$1"
  local local_dir="" kind=""

  for entry in "${GAME_REPOS[@]}"; do
    IFS='|' read -r cfg_repo cfg_dir cfg_kind _ _ _ <<< "$entry"
    if [[ "$cfg_repo" == "$repo" ]]; then
      local_dir="$cfg_dir"
      kind="$cfg_kind"
      break
    fi
  done

  if [[ -z "$local_dir" ]]; then
    log "  $repo not found in GAME_REPOS, skipping"
    return 0
  fi

  # Skip if user specified a slug filter
  if [[ -n "$TARGET_SLUG" ]]; then
    lc_slug=$(printf '%s' "$TARGET_SLUG" | tr 'A-Z' 'a-z')
    lc_dir=$(printf '%s' "$local_dir" | tr 'A-Z' 'a-z')
    case "$lc_dir" in
      *"$lc_slug"*) ;;
      *) log "  $repo does not match slug '$TARGET_SLUG', skipping"; return 0 ;;
    esac
  fi

  local clone_path="$FACTORY_DIR/$local_dir"
  log "── processing $repo (kind=$kind, dir=$clone_path)"

  if [[ ! -d "$clone_path/.git" ]]; then
    log "  no local clone at $clone_path, skipping"
    return 0
  fi

  cd "$clone_path"
  git fetch origin main >> "$LOG" 2>&1 || { log "  git fetch failed"; return 1; }
  git checkout main >> "$LOG" 2>&1 || true
  git reset --hard origin/main >> "$LOG" 2>&1

  local head_sha
  head_sha=$(git rev-parse --short HEAD)
  local latest_tag
  latest_tag=$(git tag --list 'v*' --sort=-version:refname | head -1)
  [[ -z "$latest_tag" ]] && latest_tag="(no tag)"

  local artifacts=""
  local notes=""

  case "$kind" in
    web)
      log "  [web] verifying build output"
      if [[ -f package.json ]] && grep -q '"build"' package.json; then
        if npm install --no-audit --no-fund >> "$LOG" 2>&1 && \
           npm run build >> "$LOG" 2>&1; then
          log "  ✓ npm run build succeeded"
          notes="Web build output is current in \`docs/\`. GitHub Pages deploys automatically via the deploy.yml workflow on every push to main. No additional action needed unless you want a forced re-deploy."
        else
          log "  ✗ npm run build failed"
          notes="⚠️ \`npm run build\` failed locally during the platform agent run. Investigate before promoting this tag."
        fi
      else
        notes="No \`npm run build\` script. Nothing to do for web-only release."
      fi
      ;;
    capacitor)
      log "  [capacitor] syncing native project"
      if [[ ! -f package.json ]]; then
        log "  no package.json at repo root, skipping"
        return 0
      fi
      npm install --no-audit --no-fund >> "$LOG" 2>&1 || log "  npm install warning (continuing)"

      if npx cap sync android >> "$LOG" 2>&1; then
        log "  ✓ cap sync android succeeded"
      else
        log "  ✗ cap sync android failed — check Capacitor installation"
        notes="❌ \`npx cap sync android\` failed. Fix locally and re-run the platform agent."
      fi

      # Try gradle if available
      if [[ -f android/gradlew ]] && [[ -n "${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}" ]]; then
        log "  attempting ./gradlew assembleRelease"
        if (cd android && ./gradlew assembleRelease) >> "$LOG" 2>&1; then
          local apk
          apk=$(find android/app/build/outputs -type f -name '*-release*.apk' 2>/dev/null | head -1)
          if [[ -n "$apk" ]]; then
            log "  ✓ APK built: $apk"
            artifacts="- \`$(basename "$apk")\` ($(du -h "$apk" | awk '{print $1}'))"
            # Upload to release if the tag exists
            if [[ "$latest_tag" != "(no tag)" ]]; then
              if gh release view "$latest_tag" --repo "$repo" >/dev/null 2>&1; then
                gh release upload "$latest_tag" "$apk" --repo "$repo" --clobber >> "$LOG" 2>&1 \
                  && log "  ✓ uploaded $apk to release $latest_tag" \
                  || log "  ⚠ failed to upload APK"
              fi
            fi
          fi
        else
          log "  ✗ gradle build failed"
          notes="${notes}
❌ \`./gradlew assembleRelease\` failed. Open \`android/\` in Android Studio and investigate."
        fi
      else
        log "  Android SDK not detected (ANDROID_HOME/ANDROID_SDK_ROOT not set), skipping gradle"
        notes="${notes}
⚠️ Android SDK not found in environment. To build the APK locally:
\`\`\`
cd ${local_dir}
npx cap open android   # opens Android Studio
# In Android Studio: Build → Generate Signed Bundle/APK
\`\`\`"
      fi

      # iOS path (skipped if no ios project)
      if [[ -d ios ]] && command -v xcodebuild >/dev/null 2>&1; then
        log "  attempting xcodebuild archive"
        # Stub: xcodebuild archive requires a scheme and workspace name;
        # this is a placeholder for when iOS project is added.
        log "  iOS archive: scheme/workspace config needed, skipping"
      fi
      ;;
    *)
      log "  unknown kind '$kind', skipping"
      return 0
      ;;
  esac

  # File the release-ready issue
  local body_file
  body_file=$(mktemp -t stratos-platform-release.XXXXXX)
  cat > "$body_file" <<EOF
## Release-ready: $repo @ \`$head_sha\` (tag: $latest_tag)

The platform agent has completed the native build step for this commit.
Review the artifacts below and proceed with store submission when ready.

### Artifacts

${artifacts:-_(no native artifacts produced this run — see notes)_}

### Notes

$notes

### Next steps (Ripon)

1. Download the artifact(s) from the [release page](https://github.com/$repo/releases/tag/$latest_tag) (if they were uploaded).
2. **Android**: upload the APK/AAB to Google Play Console → Internal testing track first.
3. **iOS** (future): upload the IPA to App Store Connect → TestFlight.
4. Fill in "What's new" release notes (changelog is on the release page).
5. Verify Crashlytics and AdMob initialize correctly in the test build.
6. Promote to production after 24h of clean telemetry.

🤖 Filed by the Stratos Games Factory platform agent.
EOF

  gh issue create --repo "$repo" \
    --label "release-ready" \
    --title "[release-ready] $latest_tag — native artifacts ready" \
    --body-file "$body_file" >> "$LOG" 2>&1 && log "  ✓ filed release-ready issue" \
    || log "  ⚠ failed to file release-ready issue"
  rm -f "$body_file"
}

for repo in "${active_repos[@]}"; do
  process_repo "$repo"
done

log "================ platform agent run finished ================"
exit 0
