#!/bin/bash
# deploy-brain.sh — push the factory's brain into every game repo.
#
# - Arrow Puzzle: appends brain/arrow-puzzle-autobuilder.md to its CLAUDE.md
#   (only the section between the STRATOS-AUTOBUILDER markers; idempotent).
# - Bloxplode: writes brain/bloxplode-claude.md as CLAUDE.md (only if missing or
#   if its existing CLAUDE.md is itself a previous Stratos-deployed copy).
# - Both: deploys .github/ISSUE_TEMPLATE/build-request.md.
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

ARROW_BRAIN="$FACTORY_DIR/brain/arrow-puzzle-autobuilder.md"
BLOX_BRAIN="$FACTORY_DIR/brain/bloxplode-claude.md"
ISSUE_TEMPLATE="$FACTORY_DIR/templates/build-request.md"

[[ -f "$ARROW_BRAIN" ]]    || die "missing $ARROW_BRAIN"
[[ -f "$BLOX_BRAIN" ]]     || die "missing $BLOX_BRAIN"
[[ -f "$ISSUE_TEMPLATE" ]] || die "missing $ISSUE_TEMPLATE"

deploy_repo() {
  local repo="$1" local_dir="$2" branch="$3"
  local clone_path="$FACTORY_DIR/$local_dir"

  say "Deploying brain to $repo"

  if [[ ! -d "$clone_path/.git" ]]; then
    say "  cloning $repo → $clone_path"
    gh repo clone "$repo" "$clone_path"
  fi

  cd "$clone_path"
  git fetch origin "$branch" >/dev/null 2>&1
  git checkout "$branch" >/dev/null 2>&1
  git reset --hard "origin/$branch" >/dev/null 2>&1

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

  # ---- CLAUDE.md
  case "$local_dir" in
    arrow-puzzle-testing)
      if [[ ! -f CLAUDE.md ]]; then
        warn "  Arrow Puzzle has no CLAUDE.md — that is unexpected. Skipping append."
      else
        # Strip any previous autobuilder section AND trailing blank lines in one pass.
        local tmp
        tmp="$(mktemp)"
        awk '
          BEGIN { skip = 0; n = 0 }
          /<!-- STRATOS-AUTOBUILDER:BEGIN -->/ { skip = 1; next }
          /<!-- STRATOS-AUTOBUILDER:END -->/   { skip = 0; next }
          skip == 0 { lines[++n] = $0 }
          END {
            while (n > 0 && lines[n] == "") n--
            for (i = 1; i <= n; i++) print lines[i]
          }
        ' CLAUDE.md > "$tmp"
        mv "$tmp" CLAUDE.md
        printf '\n\n' >> CLAUDE.md
        cat "$ARROW_BRAIN" >> CLAUDE.md
        if ! git diff --quiet -- CLAUDE.md; then
          git add CLAUDE.md
          changed=1
          ok "  appended autobuilder section to CLAUDE.md"
        else
          ok "  CLAUDE.md autobuilder section already current"
        fi
      fi
      ;;
    Bloxplode-Beta)
      local should_write=0
      if [[ ! -f CLAUDE.md ]]; then
        should_write=1
      elif grep -q "STRATOS-AUTOBUILDER:BEGIN" CLAUDE.md; then
        # It's already a Stratos-deployed CLAUDE.md — refresh it.
        should_write=1
      else
        warn "  Bloxplode has a hand-written CLAUDE.md — leaving it alone. Add the autobuilder section manually."
      fi

      if (( should_write )); then
        if ! cmp -s "$BLOX_BRAIN" CLAUDE.md 2>/dev/null; then
          cp "$BLOX_BRAIN" CLAUDE.md
          git add CLAUDE.md
          changed=1
          ok "  wrote CLAUDE.md from brain/bloxplode-claude.md"
        else
          ok "  CLAUDE.md already current"
        fi
      fi
      ;;
    *)
      # Generic game: only write a starter CLAUDE.md if missing
      if [[ ! -f CLAUDE.md ]]; then
        cat > CLAUDE.md <<EOF
# CLAUDE.md

Starter brain for $local_dir, deployed by the Stratos Games Factory.
A human should fill in this file with project-specific rules.

<!-- STRATOS-AUTOBUILDER:BEGIN -->
## Stratos autobuilder rules

The Stratos Games Factory daemon will refuse to make changes in this repo
until a human writes proper rules above this marker.
<!-- STRATOS-AUTOBUILDER:END -->
EOF
        git add CLAUDE.md
        changed=1
        ok "  wrote starter CLAUDE.md"
      fi
      ;;
  esac

  if (( changed )); then
    git -c user.email="factory@stratos.games" -c user.name="Stratos Games Factory" \
      commit -m "chore(factory): deploy Stratos brain + issue template" >/dev/null
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
