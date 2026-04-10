#!/bin/bash
# deploy-brain.sh — push the factory's brain + workflows into every game repo.
#
# - Arrow Puzzle: appends brain/arrow-puzzle-autobuilder.md to its CLAUDE.md
#   (only the section between the STRATOS-AUTOBUILDER markers; idempotent).
# - Bloxplode: writes brain/bloxplode-claude.md as CLAUDE.md (only if missing or
#   if its existing CLAUDE.md is itself a previous Stratos-deployed copy).
# - Both: deploys .github/ISSUE_TEMPLATE/build-request.md and
#   .github/workflows/* from templates/workflows-<game>/.
# - Both: ensures all factory labels exist (build-request, building, done,
#   ship-it, auto-merged).
#
# Idempotent. Safe to run repeatedly. Only commits/pushes when something
# actually changed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FACTORY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck disable=SC1091
source "$FACTORY_DIR/daemon/config.sh"

say()  { printf "\033[1;36m▸\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m✓\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!\033[0m %s\n" "$*"; }
die()  { printf "\033[1;31m✗\033[0m %s\n" "$*"; exit 1; }

# CLAUDE.md sources of truth — single lean document per game.
# brain/*.md is kept for historical reference but is no longer load-bearing.
ARROW_CLAUDE="$FACTORY_DIR/templates/claude-arrow-puzzle.md"
BLOX_CLAUDE="$FACTORY_DIR/templates/claude-bloxplode.md"
ISSUE_TEMPLATE="$FACTORY_DIR/templates/build-request.md"

[[ -f "$ARROW_CLAUDE" ]]   || die "missing $ARROW_CLAUDE"
[[ -f "$BLOX_CLAUDE" ]]    || die "missing $BLOX_CLAUDE"
[[ -f "$ISSUE_TEMPLATE" ]] || die "missing $ISSUE_TEMPLATE"

ensure_label() {
  local repo="$1" name="$2" color="$3" desc="$4"
  gh label create "$name" --repo "$repo" --color "$color" --description "$desc" >/dev/null 2>&1 || true
}

ensure_all_labels() {
  local repo="$1"
  ensure_label "$repo" "build-request" "0e8a16" "Human-filed request for the daemon to build"
  ensure_label "$repo" "building"      "fbca04" "Daemon is currently working on this"
  ensure_label "$repo" "done"          "5319e7" "Daemon has opened a PR for this"
  ensure_label "$repo" "ship-it"       "1f883d" "Ready for production release"
  ensure_label "$repo" "auto-merged"   "8957e5" "PR was auto-merged after CI passed (safe-paths only)"
}

deploy_repo() {
  local repo="$1" local_dir="$2" branch="$3"
  local clone_path="$FACTORY_DIR/$local_dir"

  say "Deploying brain + workflows to $repo"

  if [[ ! -d "$clone_path/.git" ]]; then
    say "  cloning $repo → $clone_path"
    gh repo clone "$repo" "$clone_path"
  fi

  cd "$clone_path"
  git fetch origin "$branch" >/dev/null 2>&1
  git checkout "$branch" >/dev/null 2>&1
  git reset --hard "origin/$branch" >/dev/null 2>&1

  ensure_all_labels "$repo"

  local changed=0

  # ---- Issue template
  mkdir -p .github/ISSUE_TEMPLATE
  if ! cmp -s "$ISSUE_TEMPLATE" .github/ISSUE_TEMPLATE/build-request.md 2>/dev/null; then
    cp "$ISSUE_TEMPLATE" .github/ISSUE_TEMPLATE/build-request.md
    git add .github/ISSUE_TEMPLATE/build-request.md
    changed=1
    ok "  updated .github/ISSUE_TEMPLATE/build-request.md"
  else
    ok "  issue template already current"
  fi

  # ---- Workflows
  local workflow_dir="$FACTORY_DIR/templates/workflows-$local_dir"
  local scripts_dir=""
  case "$local_dir" in
    arrow-puzzle-testing)
      workflow_dir="$FACTORY_DIR/templates/workflows-arrow-puzzle"
      scripts_dir="$FACTORY_DIR/templates/scripts-arrow-puzzle"
      ;;
    Bloxplode-Beta)
      workflow_dir="$FACTORY_DIR/templates/workflows-bloxplode"
      ;;
  esac
  if [[ -d "$workflow_dir" ]]; then
    mkdir -p .github/workflows
    local wf wf_name
    for wf in "$workflow_dir"/*.yml; do
      [[ -f "$wf" ]] || continue
      wf_name="$(basename "$wf")"
      if ! cmp -s "$wf" ".github/workflows/$wf_name" 2>/dev/null; then
        cp "$wf" ".github/workflows/$wf_name"
        git add ".github/workflows/$wf_name"
        changed=1
        ok "  updated .github/workflows/$wf_name"
      else
        ok "  workflow already current: $wf_name"
      fi
    done
  else
    warn "  no workflow templates for $local_dir at $workflow_dir"
  fi

  # ---- Validator scripts (game-specific)
  if [[ -n "$scripts_dir" && -d "$scripts_dir" ]]; then
    mkdir -p scripts
    local sf sf_name
    for sf in "$scripts_dir"/*.js; do
      [[ -f "$sf" ]] || continue
      sf_name="$(basename "$sf")"
      if ! cmp -s "$sf" "scripts/$sf_name" 2>/dev/null; then
        cp "$sf" "scripts/$sf_name"
        git add "scripts/$sf_name"
        changed=1
        ok "  updated scripts/$sf_name"
      else
        ok "  script already current: scripts/$sf_name"
      fi
    done

    # Patch package.json to add `validate` script if missing.
    if [[ -f package.json ]] && command -v node >/dev/null 2>&1; then
      if ! grep -q '"validate"' package.json; then
        node -e '
          const fs = require("fs");
          const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
          pkg.scripts = pkg.scripts || {};
          pkg.scripts.validate = "node scripts/validate.js";
          fs.writeFileSync("package.json", JSON.stringify(pkg, null, 2) + "\n");
        '
        git add package.json
        changed=1
        ok "  added \"validate\" script to package.json"
      else
        ok "  package.json validate script already present"
      fi
    fi
  fi

  # ---- CLAUDE.md (full replacement from the per-game source of truth)
  local claude_src=""
  case "$local_dir" in
    arrow-puzzle-testing) claude_src="$ARROW_CLAUDE" ;;
    Bloxplode-Beta)       claude_src="$BLOX_CLAUDE" ;;
  esac
  if [[ -n "$claude_src" && -f "$claude_src" ]]; then
    if ! cmp -s "$claude_src" CLAUDE.md 2>/dev/null; then
      cp "$claude_src" CLAUDE.md
      git add CLAUDE.md
      changed=1
      ok "  wrote CLAUDE.md from $(basename "$claude_src")"
    else
      ok "  CLAUDE.md already current"
    fi
  elif [[ ! -f CLAUDE.md ]]; then
    cat > CLAUDE.md <<EOF
# CLAUDE.md

Starter document for $local_dir. A human should fill in this file before
the Stratos Games Factory daemon will safely operate on the repo.
EOF
    git add CLAUDE.md
    changed=1
    warn "  wrote starter CLAUDE.md (no claude-$local_dir.md template found)"
  fi

  if (( changed )); then
    git -c user.email="factory@stratos.games" -c user.name="Stratos Games Factory" \
      commit -m "chore(factory): deploy Stratos brain, workflows, and issue template" >/dev/null
    say "  pushing to $repo"
    git push origin "$branch" >/dev/null
    ok "  pushed"
  else
    ok "  nothing to push"
  fi
  echo
}

for entry in "${GAME_REPOS[@]}"; do
  IFS='|' read -r repo local_dir _kind branch _build <<< "$entry"
  deploy_repo "$repo" "$local_dir" "$branch"
done

ok "Brain deployment complete."
