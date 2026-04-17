#!/bin/bash
# config.sh — central configuration for the Stratos Games Factory daemon.
#
# Format for GAME_REPOS entries:
#   "<owner/repo>|<local_dir>|<kind>|<default_branch>|<build_cmd>|<forbidden_paths>"
#
#   owner/repo       — GitHub slug, used by `gh`
#   local_dir        — directory under FACTORY_DIR where the repo is cloned
#   kind             — "web" | "capacitor" | "other" — informational, used by docs
#   default_branch   — branch the daemon pulls from and opens PRs against
#   build_cmd        — final verification command (run by Claude, not the shell);
#                      leave as "" if the repo has no build step
#   forbidden_paths  — colon-separated git pathspecs that the daemon must reset
#                      to HEAD before committing trailing changes (so build output
#                      and other off-limits paths can never sneak into a PR).

# ---------------------------------------------------------------- factory paths
FACTORY_DIR="${FACTORY_DIR:-$HOME/stratos-games-factory}"
LOG_FILE="${LOG_FILE:-$FACTORY_DIR/build.log}"
LOCKFILE="${LOCKFILE:-$FACTORY_DIR/.daemon.lock}"

# ---------------------------------------------------------------- game registry
GAME_REPOS=(
  "mody-sahariar1/arrow-puzzle-testing|arrow-puzzle-testing|web|main|npm run build|docs:packages:prototypes"
  "mody-sahariar1/Bloxplode-Beta|Bloxplode-Beta|capacitor|main||android:capacitor.config.json:package-lock.json"
  "mody-sahariar1/house-mafia|house-mafia|web|main|npm run build|docs:node_modules:dist"
)

# ---------------------------------------------------------------- daemon limits
MAX_ISSUE_BODY_LINES="${MAX_ISSUE_BODY_LINES:-50}"
MAX_ISSUES_PER_REPO_PER_RUN="${MAX_ISSUES_PER_REPO_PER_RUN:-3}"
CLAUDE_TIMEOUT_SECONDS="${CLAUDE_TIMEOUT_SECONDS:-1800}"

# Optional one-shot filters (set in environment, not here):
#   REPO_FILTER="mody-sahariar1/arrow-puzzle-testing"  → only this repo
#   ISSUE_FILTER="15"                                   → only this issue number
# Useful for manual debugging runs.

# ---------------------------------------------------------------- telegram (optional)
# Override these in daemon/config.local.sh (gitignored) if you want notifications.
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

# ---------------------------------------------------------------- claude flags (legacy, used by deprecated daemon scripts)
CLAUDE_FLAGS=(-p --dangerously-skip-permissions --effort max)

# ---------------------------------------------------------------- local overrides
# Anything in config.local.sh wins. Use it for secrets and per-machine tweaks.
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/config.local.sh" ]]; then
  # shellcheck disable=SC1091
  source "$(dirname "${BASH_SOURCE[0]}")/config.local.sh"
fi
