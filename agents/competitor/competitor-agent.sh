#!/bin/bash
# ┌──────────────────────────────────────────────────────────────────┐
# │ DEPRECATED — Swarm mode replaces cron-based execution.          │
# │ See CLAUDE.md "Swarm mode" for the current operating model.     │
# │ This script is preserved as documentation and legacy fallback.  │
# └──────────────────────────────────────────────────────────────────┘
# competitor-agent.sh — weekly market intelligence scanner.
#
# Runs Tuesday 00:00 UTC via cron. Invokes `claude -p --effort max` with a
# prompt that tells Claude to web-search the trending-games space and file
# one market-intel issue per active game plus one portfolio summary on the
# factory repo.

set -uo pipefail

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$HOME/.nvm/versions/node/v20.20.0/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FACTORY_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck disable=SC1091
source "$FACTORY_DIR/daemon/config.sh"

LOG="$SCRIPT_DIR/competitor-agent.log"
mkdir -p "$SCRIPT_DIR"
touch "$LOG"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }
die() { log "FATAL: $*"; exit 1; }

for tool in git gh claude jq; do
  command -v "$tool" >/dev/null 2>&1 || die "missing tool: $tool"
done
gh auth status >/dev/null 2>&1 || die "gh CLI not authenticated"

log "================ competitor agent run starting ================"

# Ensure market-intel label exists on each active game repo + the factory
# bash 3.2 (macOS default) lacks `mapfile`, so build the array via while-read.
active_repos=()
while IFS= read -r line; do
  [[ -n "$line" ]] && active_repos+=("$line")
done < <(jq -r '
  .agents[]
  | select(.name == "competitor" and .status == "active")
  | .repos[]
' "$FACTORY_DIR/agents/registry.json" 2>/dev/null)

if [[ ${#active_repos[@]:-0} -eq 0 ]]; then
  log "no active competitor-agent targets, exiting"
  exit 0
fi

for repo in "${active_repos[@]}" "sahilmodi1965/stratos-games-factory"; do
  gh label create "market-intel" \
    --repo "$repo" \
    --color "5319e7" \
    --description "Market intelligence from the weekly competitor agent" \
    >/dev/null 2>&1 || true
done

# Build a single Claude session that covers the whole portfolio
week_tag=$(date -u '+%Y-%m-%d')

# Gather portfolio context for the prompt
portfolio_blurb=""
for repo in "${active_repos[@]}"; do
  local_dir=""
  for entry in "${GAME_REPOS[@]}"; do
    IFS='|' read -r cfg_repo cfg_dir cfg_kind _ _ _ <<< "$entry"
    if [[ "$cfg_repo" == "$repo" ]]; then
      local_dir="$cfg_dir"
      kind="$cfg_kind"
      break
    fi
  done
  portfolio_blurb="${portfolio_blurb}- **${repo}** (${kind:-unknown})"$'\n'
done

prompt_file=$(mktemp -t stratos-competitor-prompt.XXXXXX)
cat > "$prompt_file" <<EOF
You are the Stratos Games Factory **competitor agent**. Your job this week is
to scan the casual/puzzle game market for what's working right now and turn
that signal into concrete, file-level improvement suggestions for our games.

You do NOT write code. You ONLY file GitHub issues via \`gh issue create\`.

# The portfolio

$portfolio_blurb
Factory repo: \`sahilmodi1965/stratos-games-factory\`

# STEP 1 — Scan the market

Use your WebSearch / WebFetch tools to research the following. Cite specific
games by name and link where possible.

- Top trending puzzle games on the Apple App Store this week
- Top trending casual games on the Google Play Store this week
- Notable new mechanics or game features being discussed by game-dev creators
  or puzzle-game reviewers in the last 30 days
- Any specific "daily challenge", "speed run", "endless mode", or
  "meta-progression" patterns that are showing up in multiple trending games

If your searches return nothing credible, say so and stop. Do NOT invent
games, reviews, or trends. An honest empty report is required in that case.

# STEP 2 — Analyze what's working

For each trending pattern you identify, write 1-2 sentences on WHY it works
(what problem it solves for the player). This is the analysis layer and it
goes into the issue bodies.

# STEP 3 — Map to our games

For each active game in the portfolio, propose **exactly 3 specific mechanic
adaptations** inspired by what's trending. Each suggestion must:

- Cite the specific trending game(s) that inspired it
- Reference specific files in our codebase where the change would land
  (e.g. \`games/arrow-puzzle/src/config/difficulty-config.js\` or
  \`www/index.html\` for Bloxplode)
- Be small enough that the builder daemon could plausibly implement it in
  one PR (hint: the daemon caps at 50-line issue bodies)
- NOT require new dependencies, new build steps, or touching
  \`packages/**\`, \`android/**\`, or \`capacitor.config.json\`
- Be CONCRETE — never vague like "add social features" or "improve
  monetization"

# STEP 4 — File the issues

For EACH active game, file exactly ONE issue:

\`\`\`
gh issue create --repo <owner/game-repo> \\
  --label "market-intel" \\
  --title "[market-intel] Week of ${week_tag} — 3 mechanics from trending games" \\
  --body "<the 3 suggestions with citations>"
\`\`\`

Active game repos to file into:
$(printf '  - %s\n' "${active_repos[@]}")

Then file ONE summary issue on the factory repo:

\`\`\`
gh issue create --repo sahilmodi1965/stratos-games-factory \\
  --label "market-intel" \\
  --title "[market-intel] Portfolio scan — week of ${week_tag}" \\
  --body "<cross-portfolio trends + which suggestions look highest-leverage>"
\`\`\`

The summary should identify themes that apply to MULTIPLE games in the
portfolio, not just rehash the per-game suggestions.

# STEP 5 — Report

End with a single paragraph listing every issue you filed (repo + number)
and nothing else.

# Operating principles

- Cite real games by name. Never invent.
- Prefer 3 sharp, specific suggestions over 10 vague ones.
- If a suggestion would touch forbidden paths (\`packages/\`, \`android/\`,
  \`capacitor.config.json\`), rephrase it to land somewhere legal or drop it.
- Market intelligence is judgment fuel for humans. These issues will NOT be
  auto-built — a human triages them and re-files approved ones as
  \`build-request\` if they pass muster.
EOF

log "invoking claude (--effort max, timeout 2400s)"
if command -v gtimeout >/dev/null 2>&1; then
  gtimeout 2400 claude -p --dangerously-skip-permissions --effort max < "$prompt_file" >> "$LOG" 2>&1
else
  claude -p --dangerously-skip-permissions --effort max < "$prompt_file" >> "$LOG" 2>&1
fi
claude_exit=$?
rm -f "$prompt_file"
log "claude exited $claude_exit"

# Count new market-intel issues across repos
new_total=0
for repo in "${active_repos[@]}" "sahilmodi1965/stratos-games-factory"; do
  n=$(gh issue list --repo "$repo" --label "market-intel" --state all --limit 20 \
    --json number,createdAt \
    --jq '[.[] | select((.createdAt | fromdateiso8601) > (now - 3600))] | length' 2>/dev/null || echo 0)
  log "  $repo: $n new market-intel issue(s)"
  new_total=$((new_total + n))
done

log "================ competitor agent run finished ================"
log "  filed $new_total market-intel issue(s) total"

exit 0
