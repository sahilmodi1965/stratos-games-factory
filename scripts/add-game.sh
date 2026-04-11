#!/bin/bash
# add-game.sh — onboard a new game repo into the Stratos Games Factory.
#
# Usage:  bash scripts/add-game.sh owner/repo-name "Short description"
#
# What it does:
#   1. Clones the repo into ~/stratos-games-factory/<repo>/
#   2. Appends a GAME_REPOS entry to daemon/config.sh
#   3. Creates the build-request / building / done labels
#   4. Deploys a starter CLAUDE.md (if none) and the issue template
#
# Idempotent for the parts that can be — re-running with the same repo will
# detect duplicates in config.sh and refuse to add a second entry.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FACTORY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 owner/repo-name \"Short description\"" >&2
  exit 1
fi

REPO="$1"
DESC="$2"
LOCAL_DIR="$(basename "$REPO")"

say()  { printf "\033[1;36m▸\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m✓\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!\033[0m %s\n" "$*"; }
die()  { printf "\033[1;31m✗\033[0m %s\n" "$*"; exit 1; }

say "Adding $REPO to the Stratos Games Factory"
echo "  description: $DESC"
echo "  local dir:   $FACTORY_DIR/$LOCAL_DIR"
echo

# ---- 1. clone
if [[ -d "$FACTORY_DIR/$LOCAL_DIR/.git" ]]; then
  ok "Already cloned at $FACTORY_DIR/$LOCAL_DIR"
else
  say "Cloning..."
  gh repo clone "$REPO" "$FACTORY_DIR/$LOCAL_DIR"
  ok "Cloned"
fi

DEFAULT_BRANCH="$(gh repo view "$REPO" --json defaultBranchRef --jq .defaultBranchRef.name)"
[[ -z "$DEFAULT_BRANCH" ]] && DEFAULT_BRANCH="main"
ok "Default branch: $DEFAULT_BRANCH"

# ---- 2. append to config.sh
CONFIG="$FACTORY_DIR/daemon/config.sh"
if grep -Fq "$REPO|" "$CONFIG"; then
  ok "Already registered in daemon/config.sh"
else
  say "Registering in daemon/config.sh"
  # Insert before the closing paren of GAME_REPOS=()
  python3 - "$CONFIG" "$REPO" "$LOCAL_DIR" "$DEFAULT_BRANCH" <<'PY'
import re, sys
config_path, repo, local_dir, branch = sys.argv[1:]
src = open(config_path).read()
new_entry = f'  "{repo}|{local_dir}|other|{branch}|"\n'
def repl(m):
    body = m.group(1)
    if not body.endswith("\n"):
        body += "\n"
    return f"GAME_REPOS=(\n{body}{new_entry})"
new = re.sub(r"GAME_REPOS=\(\n(.*?)\)", repl, src, count=1, flags=re.DOTALL)
open(config_path, "w").write(new)
PY
  ok "Registered"
fi

# ---- 3. labels
say "Creating labels"
gh label create "build-request" --repo "$REPO" --color "0e8a16" --description "Human-filed request for the daemon to build" >/dev/null 2>&1 || true
gh label create "building"      --repo "$REPO" --color "fbca04" --description "Daemon is currently working on this" >/dev/null 2>&1 || true
gh label create "done"          --repo "$REPO" --color "5319e7" --description "Daemon has opened a PR for this" >/dev/null 2>&1 || true
ok "Labels ready"

# ---- 3b. ensure Actions workflow permissions allow write (needed for PR comments, auto-merge)
say "Setting Actions workflow permissions to read-write"
gh api "repos/$REPO/actions/permissions/workflow" -X PUT \
  -f default_workflow_permissions="write" \
  -F can_approve_pull_request_reviews=true 2>/dev/null || warn "Could not set Actions permissions (may need admin access)"
ok "Actions permissions set"

# ---- 4. deploy brain
say "Deploying issue template + starter CLAUDE.md"
bash "$FACTORY_DIR/scripts/deploy-brain.sh"

ok "Game added: $REPO"
echo
echo "Next steps:"
echo "  1. Write a real CLAUDE.md for the game (templates/claude-$LOCAL_DIR.md)"
echo "  2. Create workflow templates (templates/workflows-$LOCAL_DIR/)"
echo "  3. Run: bash scripts/deploy-brain.sh"
echo "  4. Open Claude Code, say 'go' — the swarm will pick up the new game"
