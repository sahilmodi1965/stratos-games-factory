#!/bin/bash
# content-agent.sh — weekly content idea generator.
#
# Runs Wednesday 00:00 UTC via cron. For each active game in the registry:
#   1. Sync the local clone to origin/main.
#   2. Optionally skip if the game already has >10 open build-request issues.
#   3. Invoke `claude -p --effort max` in the game repo with a prompt that
#      tells it to read CLAUDE.md, explore the content/level subsystem, and
#      file up to 5 new build-request issues via the gh CLI itself.
#   4. Log the run to agents/content/content-agent.log.
#
# The agent never writes code. It only reads and files issues. The hourly
# builder daemon picks up the issues on its next tick.

set -uo pipefail

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$HOME/.nvm/versions/node/v20.20.0/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FACTORY_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck disable=SC1091
source "$FACTORY_DIR/daemon/config.sh"

LOG="$SCRIPT_DIR/content-agent.log"
mkdir -p "$SCRIPT_DIR"
touch "$LOG"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"
}

die() {
  log "FATAL: $*"
  exit 1
}

for tool in git gh claude jq; do
  command -v "$tool" >/dev/null 2>&1 || die "missing tool: $tool"
done

gh auth status >/dev/null 2>&1 || die "gh CLI not authenticated"

log "================ content agent run starting ================"

MAX_OPEN_BUILD_REQUESTS=10

# Read active content-agent targets from registry.json
if ! command -v jq >/dev/null 2>&1; then
  die "jq not available"
fi

# bash 3.2 (macOS default) lacks `mapfile`, so build the array via while-read.
active_repos=()
while IFS= read -r line; do
  [[ -n "$line" ]] && active_repos+=("$line")
done < <(jq -r '
  .agents[]
  | select(.name == "content" and .status == "active")
  | .repos[]
' "$FACTORY_DIR/agents/registry.json" 2>/dev/null)

if [[ ${#active_repos[@]:-0} -eq 0 ]]; then
  log "no active content-agent targets in registry, exiting"
  exit 0
fi

total_filed=0
total_skipped=0

for repo in "${active_repos[@]}"; do
  log "── processing $repo"

  # Find the local clone
  local_dir=""
  for entry in "${GAME_REPOS[@]}"; do
    IFS='|' read -r cfg_repo cfg_dir _ _ _ _ <<< "$entry"
    if [[ "$cfg_repo" == "$repo" ]]; then
      local_dir="$cfg_dir"
      break
    fi
  done
  if [[ -z "$local_dir" ]]; then
    log "  skipping $repo: not found in GAME_REPOS"
    total_skipped=$((total_skipped + 1))
    continue
  fi

  clone_path="$FACTORY_DIR/$local_dir"
  if [[ ! -d "$clone_path/.git" ]]; then
    log "  skipping $repo: no local clone at $clone_path"
    total_skipped=$((total_skipped + 1))
    continue
  fi

  cd "$clone_path"
  git fetch origin main >> "$LOG" 2>&1 || { log "  git fetch failed, skipping"; continue; }
  git checkout main >> "$LOG" 2>&1 || true
  git reset --hard origin/main >> "$LOG" 2>&1

  # Backlog check: don't flood a repo that's already saturated
  open_count=$(gh issue list --repo "$repo" --label "build-request" --state open --json number --jq 'length' 2>/dev/null || echo 0)
  if [[ "$open_count" -ge "$MAX_OPEN_BUILD_REQUESTS" ]]; then
    log "  skipping $repo: already has $open_count open build-request issues (cap $MAX_OPEN_BUILD_REQUESTS)"
    total_skipped=$((total_skipped + 1))
    continue
  fi

  room=$(( MAX_OPEN_BUILD_REQUESTS - open_count ))
  target=$(( room > 5 ? 5 : room ))
  log "  $open_count open build-request issues; filing up to $target new ones"

  # Capture the most recent 20 issue titles so Claude can avoid dupes
  recent_titles=$(gh issue list --repo "$repo" --state all --limit 20 --json number,title,state \
    --jq '.[] | "#\(.number) [\(.state)] \(.title)"' 2>/dev/null || echo "")

  prompt_file=$(mktemp -t stratos-content-prompt.XXXXXX)
  cat > "$prompt_file" <<EOF
You are the Stratos Games Factory **content agent**. Your job this week is to
generate fresh content ideas for the game in this repository and file them as
GitHub issues. You do NOT write code. You ONLY file issues.

# STEP 1 — Read the brain

Read \`CLAUDE.md\` in this repo end-to-end. Follow its conventions when writing
issue bodies (same file paths, same vocabulary, same refusal criteria).

# STEP 2 — Explore the content subsystem

Use your tools to list and read files under the game's content/level/difficulty
directory. For Arrow Puzzle, that is \`games/arrow-puzzle/src/levels/\`,
\`games/arrow-puzzle/src/config/difficulty-config.js\`, and the game's state
code at \`games/arrow-puzzle/src/game/game-controller.js\`. For Bloxplode,
that is everything under \`www/\`.

**Understand the existing format and difficulty curve before you suggest
anything.** If you can't see how a new idea fits into the existing structure,
don't file it.

# STEP 3 — Check for duplicates

Here are the 20 most recent issues (any state) on this repo:

---
${recent_titles}
---

Do NOT propose anything that overlaps with these. If an open build-request
issue already covers your idea, skip it.

# STEP 4 — File up to ${target} new issues

File up to ${target} new content-idea issues via \`gh issue create\`. The cap is
strict — stop at ${target}, even if you have more ideas.

Each issue MUST:

1. Be filed with \`gh issue create --repo ${repo} --label "build-request" --label "content-agent"\`
   (create the \`content-agent\` label first with \`gh label create\` if it does not
   exist; color \`0075ca\`, description "Filed by the weekly content agent")
2. Have a clear title starting with "[content]" e.g.
   "[content] Add a 3-arrow tutorial level introducing the rotate mechanic"
3. Have a body that follows the existing \`build-request\` template structure:
   - "What's wrong / what should change?"
   - "Where in the game does this happen?"
   - "How should it look / behave instead?"
   - "Anything else?"
4. Stay under 50 lines in the body (the builder daemon's hard cap on issue size).
5. Reference specific files in the codebase where the idea fits.
6. Be a GENUINE creative suggestion, not a vague wish. Example GOOD:
   "A 4x4 level where only 3 of 8 arrows are tappable (others are blockers),
   testing pure planning without rotation pressure". Example BAD: "more
   levels please".

Good content idea themes for Arrow Puzzle:
- New difficulty variants (tighter grids, more blockers, timed rounds)
- Tutorial-style single-mechanic levels
- Pattern-based sets (symmetrical, cascading, deadlock-near-miss)
- New visual themes that reuse existing mechanics

Good content idea themes for Bloxplode:
- New level sets that emphasize combo mechanics
- Daily-challenge-style seeded levels
- Speed rounds / timed modes
- New block type ideas that fit the existing rendering

# STEP 5 — Report

At the very end, output a single paragraph summarizing: how many issues you
filed, their numbers, and a one-line reason for each. Nothing else.

If you decide the existing codebase is not ready for more content (e.g. the
level system is in flux), file ZERO issues and explain why in your summary.
A clean "no ideas this week" is better than 5 bad ideas.
EOF

  log "  invoking claude (--effort max, timeout 1800s)"
  if command -v gtimeout >/dev/null 2>&1; then
    gtimeout 1800 claude -p --dangerously-skip-permissions --effort max < "$prompt_file" >> "$LOG" 2>&1
  else
    claude -p --dangerously-skip-permissions --effort max < "$prompt_file" >> "$LOG" 2>&1
  fi
  claude_exit=$?
  rm -f "$prompt_file"
  log "  claude exited $claude_exit"

  # Count how many issues were actually created since this run started
  # (anything labeled content-agent in the past hour)
  new_count=$(gh issue list --repo "$repo" --label "content-agent" --state all --limit 20 \
    --json number,createdAt \
    --jq '[.[] | select((.createdAt | fromdateiso8601) > (now - 3600))] | length' 2>/dev/null || echo 0)
  log "  filed $new_count new content-agent issue(s) this run"
  total_filed=$((total_filed + new_count))
done

log "================ content agent run finished ================"
log "  filed: $total_filed  |  skipped: $total_skipped"

exit 0
