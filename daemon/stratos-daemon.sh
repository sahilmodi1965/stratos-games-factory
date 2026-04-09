#!/bin/bash
# stratos-daemon.sh — the hourly Stratos Games Factory loop.
#
# What it does:
#   1. For every game in config.sh, sync the local clone to origin/main.
#   2. Read open `build-request` issues via the gh CLI.
#   3. For each, run `claude -p` with a structured prompt that forces it to
#      read the game's CLAUDE.md and process the issue.
#   4. If Claude made changes, push a branch and open a PR that closes the issue.
#   5. If not, comment on the issue and leave it for a human.
#
# Designed to be run by cron, hourly. Safe to run manually.
# A lockfile prevents overlapping runs.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/config.sh"

mkdir -p "$FACTORY_DIR"
touch "$LOG_FILE"

# ---------------------------------------------------------------- lockfile
if [[ -f "$LOCKFILE" ]]; then
  existing_pid="$(cat "$LOCKFILE" 2>/dev/null || echo "")"
  if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] daemon already running (pid $existing_pid), exiting" >> "$LOG_FILE"
    exit 0
  fi
  rm -f "$LOCKFILE"
fi
echo $$ > "$LOCKFILE"
trap 'rm -f "$LOCKFILE"' EXIT

# ---------------------------------------------------------------- helpers
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

notify_telegram() {
  [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]] && return 0
  curl -s -o /dev/null \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "text=$1" \
    --data-urlencode "disable_web_page_preview=true" || true
}

ensure_label() {
  local repo="$1" name="$2" color="$3" desc="$4"
  gh label create "$name" --repo "$repo" --color "$color" --description "$desc" >/dev/null 2>&1 || true
}

# Check if an issue title is likely already addressed by recent (24h) commits.
# Heuristic: extract significant words (length>=4) from the title, and check if
# any single recent commit subject contains 3+ of them. Returns 0 if matched.
recently_addressed() {
  local title="$1"
  local default_branch="$2"

  local recent
  recent=$(git log --since='24 hours ago' --pretty=format:'%s' "origin/$default_branch" 2>/dev/null)
  [[ -z "$recent" ]] && return 1

  local keywords
  keywords=$(printf '%s\n' "$title" \
    | tr 'A-Z' 'a-z' \
    | tr -cs 'a-z0-9' '\n' \
    | awk 'length($0) >= 4 && $0 !~ /^(build|fix|feat|chore|test|with|that|this|when|then|from|into|will|been|have|some|other|just|like|need|make|them|than|also|only|very|much|same|both|each|over|onto|onto|onto)$/' \
    | sort -u)
  [[ -z "$keywords" ]] && return 1

  local total
  total=$(printf '%s\n' "$keywords" | grep -c .)
  [[ "$total" -lt 3 ]] && return 1

  local subject subject_lc matches kw
  while IFS= read -r subject; do
    [[ -z "$subject" ]] && continue
    subject_lc=$(printf '%s' "$subject" | tr 'A-Z' 'a-z')
    matches=0
    while IFS= read -r kw; do
      [[ -z "$kw" ]] && continue
      case "$subject_lc" in
        *"$kw"*) matches=$((matches + 1)) ;;
      esac
    done <<< "$keywords"
    if [[ "$matches" -ge 3 ]]; then
      return 0
    fi
  done <<< "$recent"

  return 1
}

# ---------------------------------------------------------------- preflight
for tool in git gh jq claude curl; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    log "FATAL: required tool '$tool' not found in PATH"
    notify_telegram "❌ Stratos daemon FATAL: missing tool '$tool'"
    exit 1
  fi
done

if ! gh auth status >/dev/null 2>&1; then
  log "FATAL: gh CLI not authenticated. Run 'gh auth login'."
  notify_telegram "❌ Stratos daemon FATAL: gh not authenticated"
  exit 1
fi

log "================ daemon run starting (pid $$) ================"

# ---------------------------------------------------------------- main loop
total_built=0
total_skipped=0
total_failed=0

for entry in "${GAME_REPOS[@]}"; do
  IFS='|' read -r repo local_dir kind default_branch build_cmd <<< "$entry"
  game_name="$local_dir"
  log "── processing $repo  (kind=$kind, branch=$default_branch)"

  clone_path="$FACTORY_DIR/$local_dir"
  if [[ ! -d "$clone_path/.git" ]]; then
    log "  clone missing, attempting fresh clone"
    if ! gh repo clone "$repo" "$clone_path" >> "$LOG_FILE" 2>&1; then
      log "  ERROR: failed to clone $repo, skipping"
      total_failed=$((total_failed + 1))
      continue
    fi
  fi

  cd "$clone_path" || { log "  ERROR: cannot cd to $clone_path"; continue; }

  # Make sure the labels exist (idempotent)
  ensure_label "$repo" "build-request" "0e8a16" "Human-filed request for the daemon to build"
  ensure_label "$repo" "building"      "fbca04" "Daemon is currently working on this"
  ensure_label "$repo" "done"          "5319e7" "Daemon has opened a PR for this"
  ensure_label "$repo" "ship-it"       "1f883d" "Ready for production release"
  ensure_label "$repo" "auto-merged"   "8957e5" "PR was auto-merged after CI passed (safe-paths only)"

  # Hard reset to origin so the daemon never carries local state
  git fetch origin "$default_branch" >> "$LOG_FILE" 2>&1 || { log "  ERROR: git fetch failed"; continue; }
  git checkout "$default_branch" >> "$LOG_FILE" 2>&1 || true
  git reset --hard "origin/$default_branch" >> "$LOG_FILE" 2>&1
  git clean -fdx -e node_modules >> "$LOG_FILE" 2>&1 || true

  issues_json="$(gh issue list --repo "$repo" --label "build-request" --state open --json number,title,body,labels --limit 50 2>/dev/null || echo '[]')"
  issue_count="$(echo "$issues_json" | jq 'length')"
  log "  $issue_count open build-request issue(s)"

  processed_in_repo=0
  i=-1

  while (( ++i < issue_count )); do
    if (( processed_in_repo >= MAX_ISSUES_PER_REPO_PER_RUN )); then
      log "  reached per-run cap ($MAX_ISSUES_PER_REPO_PER_RUN), deferring rest"
      break
    fi

    num="$(echo "$issues_json"   | jq -r ".[$i].number")"
    title="$(echo "$issues_json" | jq -r ".[$i].title")"
    body="$(echo "$issues_json"  | jq -r ".[$i].body  // \"\"")"
    label_csv="$(echo "$issues_json" | jq -r ".[$i].labels | map(.name) | join(\",\")")"

    if [[ ",$label_csv," == *",building,"* ]] || [[ ",$label_csv," == *",done,"* ]]; then
      log "  issue #$num already in progress or done, skipping"
      continue
    fi

    body_lines="$(printf '%s\n' "$body" | wc -l | tr -d ' ')"
    if (( body_lines > MAX_ISSUE_BODY_LINES )); then
      log "  issue #$num too large ($body_lines lines > $MAX_ISSUE_BODY_LINES), commenting and skipping"
      gh issue comment "$num" --repo "$repo" --body "🤖 **Stratos daemon**: this request is too large for an automated build (${body_lines} lines, cap is ${MAX_ISSUE_BODY_LINES}). Please split it into smaller issues, or work directly with a human reviewer." >/dev/null 2>&1 || true
      total_skipped=$((total_skipped + 1))
      continue
    fi

    # Refetch right before each issue so concurrent human pushes are visible.
    git fetch origin "$default_branch" >> "$LOG_FILE" 2>&1 || true
    git checkout "$default_branch" >> "$LOG_FILE" 2>&1 || true
    git reset --hard "origin/$default_branch" >> "$LOG_FILE" 2>&1

    # Check if recent commits already addressed this issue (concurrent direct push).
    if recently_addressed "$title" "$default_branch"; then
      log "  issue #$num looks already addressed by recent commits, closing"
      gh issue close "$num" --repo "$repo" --comment "🤖 **Stratos daemon**: looks like this was already addressed in commits within the last 24 hours. Closing — please reopen with more specifics or file a new issue if it's still needed." >/dev/null 2>&1 || true
      total_skipped=$((total_skipped + 1))
      continue
    fi

    timestamp="$(date +%Y%m%d-%H%M%S)"
    branch="auto/${game_name}-issue-${num}-${timestamp}"

    log "  ▶ starting build for issue #$num: $title"
    gh issue edit "$num" --repo "$repo" --add-label "building" >> "$LOG_FILE" 2>&1 || true
    notify_telegram "🛠 Stratos: starting build for ${game_name} issue #${num} — ${title}"

    if ! git checkout -b "$branch" >> "$LOG_FILE" 2>&1; then
      log "  ERROR: could not create branch $branch"
      gh issue edit "$num" --repo "$repo" --remove-label "building" >> "$LOG_FILE" 2>&1 || true
      total_failed=$((total_failed + 1))
      continue
    fi

    # Build the prompt for Claude
    prompt_file="$(mktemp -t stratos-prompt.XXXXXX)"
    cat > "$prompt_file" <<EOF
You are working autonomously on the **${game_name}** repository as part of the
Stratos Games Factory. The current working directory is the root of that repo.

==============================================================================
STEP 1 — Read the brain.

Read the file \`CLAUDE.md\` in this repo's root. Follow EVERY rule and convention
in it without deviation. If there is no CLAUDE.md, stop immediately and respond
with "ERROR: no CLAUDE.md found, refusing to proceed".

==============================================================================
STEP 2 — Understand the request.

You are processing GitHub Issue #${num} on ${repo}.

Title: ${title}

Body:
---
${body}
---

==============================================================================
STEP 3 — Make the change.

Make the smallest, most targeted change set that satisfies the issue. Rules:

- ONE focused commit per logical change. Use conventional commits
  ("fix:", "feat:", "chore:", "refactor:"). Every commit message MUST reference
  "#${num}" so it auto-links.
- Hard exclusions (do NOT touch):
  * \`packages/*\` in Arrow Puzzle (cross-game shared kit; needs human review).
  * \`android/*\` in Bloxplode (native build artifacts).
  * \`prototypes/\` and \`docs/\` (built artifacts) in Arrow Puzzle.
  * Anything the repo's CLAUDE.md flags as off-limits.
- Do not refactor unrelated code. Do not add features beyond the issue scope.
- Do not add docstrings, comments, or type annotations to code you didn't change.
- If the issue is unclear, ambiguous, or you cannot fix it safely, do NOTHING
  and explain why in your final response. Leaving the working tree clean is the
  correct outcome in this case.

==============================================================================
STEP 4 — Verify the build.

If this repo has a build step, run it as the final action and ensure it passes.
For ${game_name}, the build command is: ${build_cmd:-<none>}
If the build fails, fix or revert until it passes. Never leave a broken build.

==============================================================================
STEP 5 — Report.

Output a one-paragraph summary of what you changed (or why you made no
changes). Do not output anything else after that paragraph.
EOF

    log "  invoking claude (timeout ${CLAUDE_TIMEOUT_SECONDS}s)"
    claude_log="$(mktemp -t stratos-claude.XXXXXX)"
    if command -v gtimeout >/dev/null 2>&1; then
      gtimeout "$CLAUDE_TIMEOUT_SECONDS" claude "${CLAUDE_FLAGS[@]}" < "$prompt_file" > "$claude_log" 2>&1
    else
      claude "${CLAUDE_FLAGS[@]}" < "$prompt_file" > "$claude_log" 2>&1
    fi
    claude_exit=$?
    log "  claude exited $claude_exit"
    cat "$claude_log" >> "$LOG_FILE"
    claude_summary="$(tail -40 "$claude_log")"
    rm -f "$prompt_file"

    # Did anything change?
    has_uncommitted="$(git status --porcelain)"
    head_sha="$(git rev-parse HEAD 2>/dev/null || echo "")"
    base_sha="$(git rev-parse "origin/$default_branch" 2>/dev/null || echo "")"

    if [[ -z "$has_uncommitted" && "$head_sha" == "$base_sha" ]]; then
      log "  no changes for issue #$num"
      gh issue edit "$num" --repo "$repo" --remove-label "building" >> "$LOG_FILE" 2>&1 || true
      gh issue comment "$num" --repo "$repo" --body "🤖 **Stratos daemon**: ran but produced no changes. Last output from Claude:

\`\`\`
$claude_summary
\`\`\`

A human can refine the issue and the daemon will retry on the next run." >/dev/null 2>&1 || true
      git checkout "$default_branch" >> "$LOG_FILE" 2>&1 || true
      git branch -D "$branch" >> "$LOG_FILE" 2>&1 || true
      notify_telegram "ℹ️  Stratos: no changes for ${game_name} issue #${num}"
      total_skipped=$((total_skipped + 1))
      rm -f "$claude_log"
      continue
    fi

    # Sweep up any uncommitted residue Claude left behind
    if [[ -n "$has_uncommitted" ]]; then
      git add -A >> "$LOG_FILE" 2>&1
      git commit -m "chore: trailing changes for #${num}" >> "$LOG_FILE" 2>&1 || true
    fi

    # Merge-conflict detection: refetch origin and try to rebase. If a human
    # pushed to main while Claude was working, the rebase may conflict — in
    # which case we abort, comment, and reopen for the next run.
    git fetch origin "$default_branch" >> "$LOG_FILE" 2>&1 || true
    if ! git rebase "origin/$default_branch" >> "$LOG_FILE" 2>&1; then
      git rebase --abort >> "$LOG_FILE" 2>&1 || true
      log "  merge conflict against latest origin/$default_branch for issue #$num"
      gh issue edit "$num" --repo "$repo" --remove-label "building" >> "$LOG_FILE" 2>&1 || true
      gh issue comment "$num" --repo "$repo" --body "🤖 **Stratos daemon**: build complete locally but a merge conflict was detected against \`$default_branch\` (likely a concurrent push). Will retry on the next run." >/dev/null 2>&1 || true
      notify_telegram "⚠️  Stratos: merge conflict for ${game_name} issue #${num} (will retry next run)"
      git checkout "$default_branch" >> "$LOG_FILE" 2>&1 || true
      git branch -D "$branch" >> "$LOG_FILE" 2>&1 || true
      total_skipped=$((total_skipped + 1))
      rm -f "$claude_log"
      continue
    fi

    log "  pushing branch $branch"
    if ! git push -u origin "$branch" >> "$LOG_FILE" 2>&1; then
      log "  ERROR: git push failed for $branch"
      gh issue edit "$num" --repo "$repo" --remove-label "building" >> "$LOG_FILE" 2>&1 || true
      gh issue comment "$num" --repo "$repo" --body "🤖 **Stratos daemon**: build completed locally but \`git push\` failed. Check the daemon log on the host machine." >/dev/null 2>&1 || true
      git checkout "$default_branch" >> "$LOG_FILE" 2>&1 || true
      git branch -D "$branch" >> "$LOG_FILE" 2>&1 || true
      total_failed=$((total_failed + 1))
      rm -f "$claude_log"
      continue
    fi

    pr_body_file="$(mktemp -t stratos-pr.XXXXXX)"
    cat > "$pr_body_file" <<EOF
Closes #${num}

🤖 Generated by the Stratos Games Factory daemon.

**Summary from Claude:**

\`\`\`
$claude_summary
\`\`\`

Reviewer checklist:
- [ ] Diff matches the issue scope (no surprise refactors).
- [ ] Build passes locally / in CI.
- [ ] Play-tested on the target platform.
EOF

    pr_url="$(gh pr create --repo "$repo" --base "$default_branch" --head "$branch" \
      --title "auto: #${num} — ${title}" \
      --body-file "$pr_body_file" 2>&1 | tail -1)"
    rm -f "$pr_body_file" "$claude_log"

    log "  PR opened: $pr_url"
    gh issue edit "$num" --repo "$repo" --remove-label "building" --add-label "done" >> "$LOG_FILE" 2>&1 || true
    gh issue comment "$num" --repo "$repo" --body "🤖 **Stratos daemon**: build complete → ${pr_url}" >> "$LOG_FILE" 2>&1 || true
    notify_telegram "✅ Stratos: PR for ${game_name} issue #${num} → ${pr_url}"

    git checkout "$default_branch" >> "$LOG_FILE" 2>&1 || true
    total_built=$((total_built + 1))
    processed_in_repo=$((processed_in_repo + 1))
  done
done

log "================ daemon run finished ================"
log "  built: $total_built  |  skipped: $total_skipped  |  failed: $total_failed"

if (( total_built > 0 )); then
  notify_telegram "Stratos daemon: built ${total_built}, skipped ${total_skipped}, failed ${total_failed}"
fi

exit 0
