#!/bin/bash
# install.sh — one-shot setup for the Stratos Games Factory.
#
# Run this once on the host machine (Sahil's MacBook). Idempotent — safe to
# re-run. Will not overwrite local config or already-cloned repos.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FACTORY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/config.sh"

# ---------------------------------------------------------------- pretty output
say()  { printf "\033[1;36m▸\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m✓\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!\033[0m %s\n" "$*"; }
die()  { printf "\033[1;31m✗\033[0m %s\n" "$*"; exit 1; }

say "Stratos Games Factory installer"
say "Factory dir: $FACTORY_DIR"
echo

# ---------------------------------------------------------------- 1. dependencies
say "Checking dependencies"
need_tools=(git gh claude jq node curl)
missing=()
for tool in "${need_tools[@]}"; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    missing+=("$tool")
  fi
done
if (( ${#missing[@]} > 0 )); then
  die "Missing tools: ${missing[*]}. Install them and re-run."
fi
ok "All required tools present"

if ! gh auth status >/dev/null 2>&1; then
  die "gh CLI is not authenticated. Run 'gh auth login' and retry."
fi
ok "gh CLI authenticated as $(gh api user --jq .login)"

# Make sure git uses gh's token for github.com so push works headlessly
gh auth setup-git >/dev/null 2>&1 || true
ok "git credential helper wired to gh"

if ! claude --version >/dev/null 2>&1; then
  warn "claude --version returned non-zero — make sure Claude Code is logged into a Max plan"
else
  ok "claude CLI present ($(claude --version 2>/dev/null | head -1))"
fi
echo

# ---------------------------------------------------------------- 2. clone game repos
say "Cloning game repos (if missing)"
for entry in "${GAME_REPOS[@]}"; do
  IFS='|' read -r repo local_dir _kind _branch _build <<< "$entry"
  target="$FACTORY_DIR/$local_dir"
  if [[ -d "$target/.git" ]]; then
    ok "$repo already cloned at $target"
  else
    say "  cloning $repo → $target"
    gh repo clone "$repo" "$target"
    ok "$repo cloned"
  fi
done
echo

# ---------------------------------------------------------------- 3. labels
say "Ensuring labels exist on each game repo"
for entry in "${GAME_REPOS[@]}"; do
  IFS='|' read -r repo _ _ _ _ <<< "$entry"
  gh label create "build-request" --repo "$repo" --color "0e8a16" --description "Human-filed request for the daemon to build" >/dev/null 2>&1 || true
  gh label create "building"      --repo "$repo" --color "fbca04" --description "Daemon is currently working on this" >/dev/null 2>&1 || true
  gh label create "done"          --repo "$repo" --color "5319e7" --description "Daemon has opened a PR for this" >/dev/null 2>&1 || true
  ok "$repo labels ready"
done
echo

# ---------------------------------------------------------------- 4. deploy brain
say "Deploying brain (CLAUDE.md updates + issue templates) to each game repo"
bash "$FACTORY_DIR/scripts/deploy-brain.sh"
echo

# ---------------------------------------------------------------- 5. cron
say "Installing hourly cron job"
CRON_LINE="0 * * * * /bin/bash $FACTORY_DIR/daemon/stratos-daemon.sh >> $FACTORY_DIR/build.log 2>&1"
existing_cron="$(crontab -l 2>/dev/null || true)"
if echo "$existing_cron" | grep -Fq "stratos-daemon.sh"; then
  ok "cron entry already present"
else
  ( echo "$existing_cron"; echo "$CRON_LINE" ) | crontab -
  ok "cron entry installed: $CRON_LINE"
fi
echo

# ---------------------------------------------------------------- 6. log file
touch "$FACTORY_DIR/build.log"
ok "build.log ready at $FACTORY_DIR/build.log"
echo

# ---------------------------------------------------------------- 7. summary
say "Status summary"
bash "$FACTORY_DIR/scripts/status.sh" || true
echo
ok "Install complete."
echo
echo "Next steps:"
echo "  • File a test issue on a game repo with label 'build-request'"
echo "  • Run the daemon manually:  bash $FACTORY_DIR/daemon/stratos-daemon.sh"
echo "  • Watch it work:            tail -f $FACTORY_DIR/build.log"
