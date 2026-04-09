#!/bin/bash
# config.sh — central configuration for the Stratos Games Factory daemon.
#
# Format for GAME_REPOS entries:
#   "<owner/repo>|<local_dir>|<kind>|<default_branch>|<build_cmd>"
#
#   owner/repo      — GitHub slug, used by `gh`
#   local_dir       — directory under FACTORY_DIR where the repo is cloned
#   kind            — "web" | "capacitor" | "other" — informational, used by docs
#   default_branch  — branch the daemon pulls from and opens PRs against
#   build_cmd       — final verification command (run by Claude, not the shell);
#                     leave as "" if the repo has no build step

# ---------------------------------------------------------------- factory paths
FACTORY_DIR="${FACTORY_DIR:-$HOME/stratos-games-factory}"
LOG_FILE="${LOG_FILE:-$FACTORY_DIR/build.log}"
LOCKFILE="${LOCKFILE:-$FACTORY_DIR/.daemon.lock}"

# ---------------------------------------------------------------- game registry
GAME_REPOS=(
  "mody-sahariar1/arrow-puzzle-testing|arrow-puzzle-testing|web|main|npm run build"
  "mody-sahariar1/Bloxplode-Beta|Bloxplode-Beta|capacitor|main|"
)

# ---------------------------------------------------------------- daemon limits
MAX_ISSUE_BODY_LINES="${MAX_ISSUE_BODY_LINES:-50}"
MAX_ISSUES_PER_REPO_PER_RUN="${MAX_ISSUES_PER_REPO_PER_RUN:-3}"
CLAUDE_TIMEOUT_SECONDS="${CLAUDE_TIMEOUT_SECONDS:-1800}"

# ---------------------------------------------------------------- telegram (optional)
# Override these in daemon/config.local.sh (gitignored) if you want notifications.
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

# ---------------------------------------------------------------- claude flags
# --dangerously-skip-permissions is required for headless cron operation.
# The daemon constrains Claude via the prompt and the per-repo CLAUDE.md instead.
CLAUDE_FLAGS=(-p --dangerously-skip-permissions)

# ---------------------------------------------------------------- local overrides
# Anything in config.local.sh wins. Use it for secrets and per-machine tweaks.
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/config.local.sh" ]]; then
  # shellcheck disable=SC1091
  source "$(dirname "${BASH_SOURCE[0]}")/config.local.sh"
fi
