#!/bin/bash
# stratos-daemon.sh — the hourly Stratos Games Factory loop.
#
# What it does:
#   1. For every game in config.sh, sync the local clone to origin/main.
#   2. Read open `build-request` issues via the gh CLI.
#   3. For each, run `claude --effort max -p` with a sticky system prompt
#      that forces it to explore the codebase and validate before stopping.
#   4. After Claude finishes, scrub forbidden paths (build output, native
#      artifacts, etc.) so they can never sneak into a PR.
#   5. Run `npm run validate` if present. Block the push on failure.
#   6. Push branch + open PR + label issue done.
#
# Designed to be run by cron, hourly. Safe to run manually.
# A lockfile prevents overlapping runs.

# cron has a minimal PATH that does NOT include Homebrew, nvm, or ~/.local/bin.
# Without this export, cron runs fail with "gh: command not found" before they
# can do anything useful. Manual runs already have a full PATH so the export
# is a no-op for them.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$HOME/.nvm/versions/node/v20.20.0/bin:$PATH"

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
#
# Heuristic: extract significant words from the title, subtract per-game
# stop-words (repo + game name parts) and dynamic stop-words (any word
# appearing in 50%+ of recent commit subjects), then look for any recent
# commit whose subject contains >=3 remaining title keywords.
#
# Council issue #2 traced a false positive on issue #16: the title's
# "arrow puzzle game" overlapped with a cleanup commit's "arrow puzzle ...
# game screen" because the repo-name words alone hit the 3-keyword
# threshold. The stop-word filter below makes that class of overlap
# impossible.
recently_addressed() {
  local title="$1"
  local default_branch="$2"
  local repo="$3"  # owner/repo, used to derive repo-name stop-words

  local recent
  recent=$(git log --since='24 hours ago' --pretty=format:'%s' "origin/$default_branch" 2>/dev/null)
  [[ -z "$recent" ]] && return 1

  local commit_count
  commit_count=$(printf '%s\n' "$recent" | grep -c .)
  [[ "$commit_count" -eq 0 ]] && return 1

  # ---- 1. Repo-name stop-words ----
  # Split owner/repo on slash AND underscore AND dash, lowercase, length>=4.
  # NOTE: dash MUST be the last char in tr's set, otherwise tr interprets
  # it as a range marker (e.g. "/-_" becomes the ASCII range / to _).
  # For "mody-sahariar1/arrow-puzzle-testing" this yields:
  #   mody, sahariar1, arrow, puzzle, testing
  local repo_stops
  repo_stops=$(printf '%s' "$repo" \
    | tr 'A-Z' 'a-z' \
    | tr '/_-' '\n\n\n' \
    | awk 'length($0) >= 4 {print}' \
    | sort -u)

  # ---- 2. Dynamic stop-words: words appearing in >=50% of recent commits ----
  # Only apply when there's enough signal (>=4 commits in window).
  local dynamic_stops=""
  if [[ "$commit_count" -ge 4 ]]; then
    local threshold=$(( (commit_count + 1) / 2 ))  # 50% rounded up
    dynamic_stops=$(printf '%s\n' "$recent" \
      | awk -v t="$threshold" '
        {
          line = tolower($0)
          gsub(/[^a-z0-9]+/, " ", line)
          n = split(line, w, " ")
          delete seen
          for (i = 1; i <= n; i++) {
            if (length(w[i]) >= 4 && !seen[w[i]]) {
              seen[w[i]] = 1
              count[w[i]]++
            }
          }
        }
        END {
          for (k in count) if (count[k] >= t) print k
        }' \
      | sort -u)
  fi

  # ---- 3. Combined stop-word set ----
  # repo_stops ∪ dynamic_stops ∪ static common-verb list
  local stops_file
  stops_file=$(mktemp -t stratos-stops.XXXXXX)
  {
    printf '%s\n' "$repo_stops"
    printf '%s\n' "$dynamic_stops"
    # Static common-verb / connector list
    cat <<'STATIC_STOPS'
build
chore
debug
docs
feat
feature
fixed
fixes
issue
test
tests
that
this
with
when
then
from
into
will
been
have
some
just
like
need
make
them
than
also
only
very
much
same
both
each
over
onto
which
where
should
would
could
about
because
update
updated
adds
added
remove
removed
STATIC_STOPS
  } | sort -u > "$stops_file"

  # ---- 4. Title keywords minus stop-words ----
  local title_words_file
  title_words_file=$(mktemp -t stratos-title.XXXXXX)
  printf '%s\n' "$title" \
    | tr 'A-Z' 'a-z' \
    | tr -cs 'a-z0-9' '\n' \
    | awk 'length($0) >= 4' \
    | sort -u > "$title_words_file"

  local keywords
  keywords=$(comm -23 "$title_words_file" "$stops_file")
  rm -f "$stops_file" "$title_words_file"

  local total
  total=$(printf '%s\n' "$keywords" | grep -c .)
  [[ "$total" -lt 3 ]] && return 1

  # ---- 5. Overlap check against recent commit subjects ----
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
  IFS='|' read -r repo local_dir kind default_branch build_cmd forbidden_paths <<< "$entry"
  game_name="$local_dir"

  # Optional one-shot filter for manual debug runs.
  if [[ -n "${REPO_FILTER:-}" && "$repo" != "$REPO_FILTER" ]]; then
    log "── skipping $repo (REPO_FILTER=$REPO_FILTER)"
    continue
  fi

  log "── processing $repo  (kind=$kind, branch=$default_branch)"
  if [[ -n "$forbidden_paths" ]]; then
    log "  forbidden paths: ${forbidden_paths//:/ }"
  fi
  # NOTE: the daemon no longer passes a separate system prompt or council
  # file to Claude. Each game repo's CLAUDE.md is now the single source of
  # truth — see templates/claude-<game>.md for what gets deployed there.
  # The user message tells Claude to read CLAUDE.md as its first action.

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

  # Optional one-shot filter for manual debug runs.
  if [[ -n "${ISSUE_FILTER:-}" ]]; then
    issues_json="$(echo "$issues_json" | jq --arg n "$ISSUE_FILTER" '[.[] | select(.number == ($n | tonumber))]')"
    log "  ISSUE_FILTER=$ISSUE_FILTER active"
  fi

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
    if recently_addressed "$title" "$default_branch" "$repo"; then
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

    # The token-efficient prompt. The repo's own CLAUDE.md (deployed by
    # scripts/deploy-brain.sh from templates/claude-<game>.md) is the single
    # source of truth for everything: hard rules, exploration phases,
    # forbidden paths, refusal criteria, final checklist. The daemon's job
    # here is just to point Claude at it and hand over the issue.
    prompt_file="$(mktemp -t stratos-prompt.XXXXXX)"
    cat > "$prompt_file" <<EOF
Read CLAUDE.md in this repo, then implement this GitHub issue.

Repo: ${repo}
Issue: #${num}
Title: ${title}

Body:
${body}

End with one paragraph summarizing what you changed (or why you refused).
EOF

    log "  invoking claude (effort=max, timeout ${CLAUDE_TIMEOUT_SECONDS}s)"

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

    # ---------- post-Claude safety net: scrub forbidden paths ----------
    # Even with strong system-prompt rules, Claude (or the build it ran) may
    # leave forbidden paths in the working tree. Reset them to HEAD before
    # we evaluate or commit anything.
    if [[ -n "$forbidden_paths" ]]; then
      IFS=':' read -ra forbid <<< "$forbidden_paths"
      for fp in "${forbid[@]}"; do
        [[ -z "$fp" ]] && continue
        # Reset tracked paths
        git checkout HEAD -- "$fp" >> "$LOG_FILE" 2>&1 || true
        # Remove untracked files inside that path
        if [[ -d "$fp" ]]; then
          git clean -fdx -- "$fp" >> "$LOG_FILE" 2>&1 || true
        fi
      done
      log "  scrubbed forbidden paths from working tree"
    fi

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

    # Sweep up any uncommitted residue Claude left behind. The forbidden-paths
    # scrub above already removed build output and other off-limits files, so
    # this only catches Claude's own intentional edits that they forgot to
    # commit.
    if [[ -n "$(git status --porcelain)" ]]; then
      git add -A >> "$LOG_FILE" 2>&1
      git commit -m "chore: trailing changes for #${num}" >> "$LOG_FILE" 2>&1 || true
    fi

    # ---------- post-Claude validation gate ----------
    # If the repo's package.json declares a `validate` script, run it. Failure
    # blocks the push: the daemon comments on the issue and leaves it for the
    # next run (so a fresh attempt can iterate).
    validation_failed=0
    if [[ -f package.json ]] && grep -q '"validate"' package.json 2>/dev/null; then
      log "  running npm run validate"
      validate_log="$(mktemp -t stratos-validate.XXXXXX)"
      if ! npm run validate > "$validate_log" 2>&1; then
        validation_failed=1
        log "  ✗ npm run validate FAILED"
        cat "$validate_log" >> "$LOG_FILE"
      else
        log "  ✓ npm run validate passed"
      fi
      validate_summary="$(tail -30 "$validate_log")"
      rm -f "$validate_log"
    else
      validate_summary=""
      log "  no validate script in package.json, skipping post-build validation"
    fi

    if (( validation_failed )); then
      gh issue edit "$num" --repo "$repo" --remove-label "building" >> "$LOG_FILE" 2>&1 || true
      gh issue comment "$num" --repo "$repo" --body "🤖 **Stratos daemon**: build attempt completed but \`npm run validate\` failed. Will retry on the next run.

\`\`\`
$validate_summary
\`\`\`

Last summary from Claude:

\`\`\`
$claude_summary
\`\`\`" >/dev/null 2>&1 || true
      notify_telegram "❌ Stratos: validation failed for ${game_name} issue #${num} (will retry)"
      git checkout "$default_branch" >> "$LOG_FILE" 2>&1 || true
      git branch -D "$branch" >> "$LOG_FILE" 2>&1 || true
      total_failed=$((total_failed + 1))
      rm -f "$claude_log"
      continue
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
