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
PR_TEMPLATE="$FACTORY_DIR/templates/pull_request_template.md"
ARROW_DASHBOARD="$FACTORY_DIR/templates/readme-dashboard-arrow-puzzle.md"
BLOX_DASHBOARD="$FACTORY_DIR/templates/readme-dashboard-bloxplode.md"

[[ -f "$ARROW_CLAUDE" ]]    || die "missing $ARROW_CLAUDE"
[[ -f "$BLOX_CLAUDE" ]]     || die "missing $BLOX_CLAUDE"
[[ -f "$ISSUE_TEMPLATE" ]]  || die "missing $ISSUE_TEMPLATE"
[[ -f "$PR_TEMPLATE" ]]     || die "missing $PR_TEMPLATE"
[[ -f "$ARROW_DASHBOARD" ]] || die "missing $ARROW_DASHBOARD"
[[ -f "$BLOX_DASHBOARD" ]]  || die "missing $BLOX_DASHBOARD"

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

  # ---- QA agent assets (Playwright spec + config + tests/e2e/)
  local qa_src_dir="$FACTORY_DIR/templates/qa-assets/"
  case "$local_dir" in
    arrow-puzzle-testing) qa_src_dir="${qa_src_dir}arrow-puzzle" ;;
    Bloxplode-Beta)       qa_src_dir="${qa_src_dir}bloxplode" ;;
    *)                    qa_src_dir="" ;;
  esac
  if [[ -n "$qa_src_dir" && -d "$qa_src_dir" ]]; then
    mkdir -p tests/e2e
    # playwright.config.js at repo root
    if [[ -f "$qa_src_dir/playwright.config.js" ]]; then
      if ! cmp -s "$qa_src_dir/playwright.config.js" playwright.config.js 2>/dev/null; then
        cp "$qa_src_dir/playwright.config.js" playwright.config.js
        git add playwright.config.js
        changed=1
        ok "  updated playwright.config.js"
      else
        ok "  playwright.config.js already current"
      fi
    fi
    # tests/e2e/smoke.spec.js
    if [[ -f "$qa_src_dir/tests/e2e/smoke.spec.js" ]]; then
      if ! cmp -s "$qa_src_dir/tests/e2e/smoke.spec.js" tests/e2e/smoke.spec.js 2>/dev/null; then
        cp "$qa_src_dir/tests/e2e/smoke.spec.js" tests/e2e/smoke.spec.js
        git add tests/e2e/smoke.spec.js
        changed=1
        ok "  updated tests/e2e/smoke.spec.js"
      else
        ok "  tests/e2e/smoke.spec.js already current"
      fi
    fi
    # Patch package.json: ensure @playwright/test (and http-server for bloxplode) are dev deps + a test:e2e script.
    if [[ -f package.json ]] && command -v node >/dev/null 2>&1; then
      local pkg_kind="vite"
      [[ "$local_dir" == "Bloxplode-Beta" ]] && pkg_kind="static"
      node -e '
        const fs = require("fs");
        const kind = process.argv[1];
        const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
        let changed = false;
        pkg.scripts = pkg.scripts || {};
        if (pkg.scripts["test:e2e"] !== "playwright test") {
          pkg.scripts["test:e2e"] = "playwright test";
          changed = true;
        }
        pkg.devDependencies = pkg.devDependencies || {};
        if (!pkg.devDependencies["@playwright/test"]) {
          pkg.devDependencies["@playwright/test"] = "^1.49.0";
          changed = true;
        }
        if (kind === "static" && !pkg.devDependencies["http-server"]) {
          pkg.devDependencies["http-server"] = "^14.1.1";
          changed = true;
        }
        if (changed) {
          fs.writeFileSync("package.json", JSON.stringify(pkg, null, 2) + "\n");
          process.stdout.write("patched\n");
        }
      ' "$pkg_kind" > /tmp/pkg-patch-result 2>/dev/null
      if [[ -s /tmp/pkg-patch-result ]]; then
        git add package.json
        changed=1
        ok "  patched package.json (added @playwright/test + test:e2e)"
      else
        ok "  package.json playwright deps already present"
      fi
      rm -f /tmp/pkg-patch-result
    fi
  fi

  # ---- PR template
  if [[ -f "$PR_TEMPLATE" ]]; then
    mkdir -p .github
    if ! cmp -s "$PR_TEMPLATE" .github/pull_request_template.md 2>/dev/null; then
      cp "$PR_TEMPLATE" .github/pull_request_template.md
      git add .github/pull_request_template.md
      changed=1
      ok "  updated .github/pull_request_template.md"
    else
      ok "  PR template already current"
    fi
  fi

  # ---- README dashboard injection (between STRATOS-DASHBOARD markers)
  local dashboard_src=""
  case "$local_dir" in
    arrow-puzzle-testing) dashboard_src="$ARROW_DASHBOARD" ;;
    Bloxplode-Beta)       dashboard_src="$BLOX_DASHBOARD" ;;
  esac
  if [[ -n "$dashboard_src" && -f "$dashboard_src" ]]; then
    if [[ ! -f README.md ]]; then
      cp "$dashboard_src" README.md
      git add README.md
      changed=1
      ok "  created README.md from dashboard template"
    else
      # Strip any existing dashboard block, then prepend the new one.
      local tmp
      tmp="$(mktemp)"
      awk '
        BEGIN { skip = 0 }
        /<!-- STRATOS-DASHBOARD:BEGIN -->/ { skip = 1; next }
        /<!-- STRATOS-DASHBOARD:END -->/   { skip = 0; next }
        skip == 0 { print }
      ' README.md > "$tmp"
      # Strip any leading blank lines from the stripped content
      sed -i.bak '/./,$!d' "$tmp" 2>/dev/null || true
      rm -f "${tmp}.bak"

      local new_readme
      new_readme="$(mktemp)"
      cat "$dashboard_src" > "$new_readme"
      printf '\n' >> "$new_readme"
      cat "$tmp" >> "$new_readme"
      rm -f "$tmp"

      if ! cmp -s "$new_readme" README.md 2>/dev/null; then
        mv "$new_readme" README.md
        git add README.md
        changed=1
        ok "  injected dashboard block into README.md"
      else
        rm -f "$new_readme"
        ok "  README.md dashboard block already current"
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
