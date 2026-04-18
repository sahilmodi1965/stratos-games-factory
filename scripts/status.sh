#!/bin/bash
# status.sh — swarm-facing dashboard for the Stratos Games Factory.
#
# Run at the start of every swarm "go" (CLAUDE.md Step 1). Replaces the
# dozen raw `gh` calls Step 1 used to require with one structured view of:
#
#   1. Open swarm-state notes (operational blockers, pauses, deferrals)
#   2. Per-game queue state, with paused games clearly skipped
#   3. Suggested focus for this pass
#
# Also usable interactively (`bash scripts/status.sh`) as a human dashboard.
# Replaces the older cron-daemon health view — cron is deprecated in swarm mode.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FACTORY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck disable=SC1091
source "$FACTORY_DIR/daemon/config.sh"

FACTORY_REPO="sahilmodi1965/stratos-games-factory"

bold()  { printf "\033[1m%s\033[0m" "$*"; }
dim()   { printf "\033[2m%s\033[0m" "$*"; }
green() { printf "\033[32m%s\033[0m" "$*"; }
yellow(){ printf "\033[33m%s\033[0m" "$*"; }
red()   { printf "\033[31m%s\033[0m" "$*"; }
cyan()  { printf "\033[36m%s\033[0m" "$*"; }

now_epoch=$(date +%s)

# Parse ISO8601 → unix epoch, BSD and GNU compatible.
# Accepts both "Z" and "+HH:MM" suffixes by normalizing to UTC YYYY-MM-DD HH:MM:SS.
iso_to_epoch() {
  local iso="$1"
  # Strip timezone suffix and T separator for a parse-friendly form.
  local norm
  norm="$(echo "$iso" | sed -E 's/([0-9:]+)[Zz]?([+-][0-9:]+)?$/\1/' | tr 'T' ' ')"
  date -j -u -f '%Y-%m-%d %H:%M:%S' "$norm" +%s 2>/dev/null \
    || date -u -d "$iso" +%s 2>/dev/null \
    || echo "$now_epoch"
}
age_days() {
  local ts; ts=$(iso_to_epoch "$1")
  echo $(( (now_epoch - ts) / 86400 ))
}

# Read the current G-pointer for a game from council/G-POINTERS.
# Maps local_dir (from daemon/config.sh) to the slug used in G-POINTERS.
# Returns empty string if no pointer is recorded.
g_pointer_for_game() {
  local local_dir="$1"
  local slug
  case "$local_dir" in
    arrow-puzzle-testing) slug="arrow-puzzle" ;;
    Bloxplode-Beta)       slug="bloxplode" ;;
    house-mafia)           slug="house-mafia" ;;
    *)                     slug="$local_dir" ;;
  esac
  grep -E "^${slug}: " "$FACTORY_DIR/council/G-POINTERS" 2>/dev/null \
    | head -1 \
    | sed -E 's/^[^:]+:[[:space:]]+([^[:space:]]+).*/\1/'
}

echo
echo "$(bold "Stratos Games Factory — swarm dashboard")"
echo "$(dim "$(date)")"
echo

# ---------------------------------------------------------------- swarm-state
echo "$(cyan "▸ Open swarm-state notes")"
swarm_state_json="$(gh issue list --repo "$FACTORY_REPO" --label swarm-state --state open \
  --json number,title,body,createdAt --limit 50 2>/dev/null || echo '[]')"
ss_count="$(echo "$swarm_state_json" | jq 'length')"
if [[ "$ss_count" -eq 0 ]]; then
  echo "    $(green "none")"
else
  echo "$swarm_state_json" \
    | jq -r '.[] | "    #\(.number)  \(.title)"'
  echo "    $(dim "read full body: gh issue view <N> --repo $FACTORY_REPO")"
fi
echo

# Detect paused games from swarm-state bodies.
# Heuristic: a swarm-state note that mentions the repo's slug / local_dir
# AND "paus" / "dormant" marks that repo as paused.
# bash 3.2 has no associative arrays — use a newline-delimited list of
# "repo|#<note>" entries and a lookup helper.
PAUSED_REPOS=""

lookup_paused() {
  local want="$1"
  while IFS='|' read -r r ref; do
    [[ -z "$r" ]] && continue
    if [[ "$r" == "$want" ]]; then
      echo "$ref"
      return 0
    fi
  done <<< "$PAUSED_REPOS"
  return 1
}

if [[ "$ss_count" -gt 0 ]]; then
  # Flatten each issue body to single-line so we can scan with grep.
  flat_notes="$(echo "$swarm_state_json" \
    | jq -r '.[] | "\(.number)||\((.title + " " + (.body // "")) | gsub("\\s+"; " "))"')"
  while IFS='|' read -r note_num _sep rest; do
    [[ -z "$note_num" ]] && continue
    text_lc="$(echo "$rest" | tr '[:upper:]' '[:lower:]')"
    [[ "$text_lc" == *"paus"* || "$text_lc" == *"dormant"* ]] || continue
    for entry in "${GAME_REPOS[@]}"; do
      IFS='|' read -r repo local_dir _rest <<< "$entry"
      slug_lc="$(echo "${repo##*/}" | tr '[:upper:]' '[:lower:]')"
      local_lc="$(echo "$local_dir" | tr '[:upper:]' '[:lower:]')"
      if [[ "$text_lc" == *"$slug_lc"* || "$text_lc" == *"$local_lc"* ]]; then
        PAUSED_REPOS+="${repo}|#${note_num}"$'\n'
      fi
    done
  done <<< "$flat_notes"
fi

# ---------------------------------------------------------------- per-game
total_open_prs=0
total_pending=0
focus_text=""
focus_score=0

# Per-game gate state collected for the gate block + suggested-focus logic.
# bash 3.2 has no associative arrays — use newline-delimited "repo|count|state".
PER_GAME_GATE=""
PER_GAME_THRESHOLD=3

for entry in "${GAME_REPOS[@]}"; do
  IFS='|' read -r repo local_dir kind branch _build <<< "$entry"

  pause_ref="$(lookup_paused "$repo" || true)"
  if [[ -n "$pause_ref" ]]; then
    echo "$(cyan "▸ $repo")  $(yellow "⏸ PAUSED") $(dim "per $pause_ref — skipped")"
    PER_GAME_GATE+="${repo}|0|swarm-state-paused"$'\n'
    echo
    continue
  fi

  g_ptr="$(g_pointer_for_game "$local_dir")"
  if [[ -n "$g_ptr" ]]; then
    echo "$(cyan "▸ $repo")  $(dim "($kind, $branch, currently at") $(bold "$g_ptr")$(dim ")")"
  else
    echo "$(cyan "▸ $repo")  $(dim "($kind, $branch)")"
  fi

  # --- Open auto/* PRs with age and warning labels ----------------------
  prs_json="$(gh pr list --repo "$repo" --state open \
    --json number,title,headRefName,labels,createdAt --limit 100 2>/dev/null || echo '[]')"
  auto_prs="$(echo "$prs_json" | jq '[.[] | select(.headRefName | startswith("auto/"))]')"
  pr_count="$(echo "$auto_prs" | jq 'length')"
  total_open_prs=$((total_open_prs + pr_count))

  # --- Per-game gate state ----------------------------------------------
  if [[ "$pr_count" -ge "$PER_GAME_THRESHOLD" ]]; then
    gate_state="paused"
  elif [[ "$pr_count" -ge 1 ]]; then
    gate_state="sequential-busy"
  else
    gate_state="open"
  fi
  PER_GAME_GATE+="${repo}|${pr_count}|${gate_state}"$'\n'

  if [[ "$pr_count" -eq 0 ]]; then
    echo "    open auto PRs:          $(green "0")  $(dim "[gate: open]")"
  else
    oldest_iso="$(echo "$auto_prs" | jq -r 'sort_by(.createdAt) | .[0].createdAt')"
    oldest_days=$(age_days "$oldest_iso")
    needs_rebase="$(echo "$auto_prs" | jq '[.[] | select(.labels | map(.name) | index("needs-rebase"))] | length')"
    ci_red="$(echo "$auto_prs" | jq '[.[] | select(.labels | map(.name) | index("ci-red"))] | length')"
    extras=""
    [[ "$needs_rebase" -gt 0 ]] && extras+=", ${needs_rebase} needs-rebase"
    [[ "$ci_red" -gt 0 ]] && extras+=", ${ci_red} ci-red"
    case "$gate_state" in
      paused)           gate_label="$(red "[gate: PAUSED]")" ;;
      sequential-busy)  gate_label="$(yellow "[gate: sequential-busy — wait for merge]")" ;;
      *)                gate_label="$(green "[gate: open]")" ;;
    esac
    if [[ "$pr_count" -ge 10 ]]; then
      printf "    open auto PRs:          %s  %s  %s\n" "$(red "$pr_count")" "$(dim "(oldest ${oldest_days}d${extras})")" "$gate_label"
    else
      printf "    open auto PRs:          %s  %s  %s\n" "$(yellow "$pr_count")" "$(dim "(oldest ${oldest_days}d${extras})")" "$gate_label"
    fi
    echo "$auto_prs" | jq -r 'sort_by(.createdAt) | .[] | "      #\(.number)  \(.title)"' | head -5
    [[ "$pr_count" -gt 5 ]] && echo "      $(dim "(+ $((pr_count - 5)) more)")"
  fi

  # --- Pending build-request issues (open, not `done`, not `building`) --
  issues_json="$(gh issue list --repo "$repo" --label build-request --state open \
    --json number,title,labels --limit 100 2>/dev/null || echo '[]')"
  pending_json="$(echo "$issues_json" | jq '[.[] | select((.labels | map(.name)) as $l | ($l | index("done") | not) and ($l | index("building") | not))]')"
  pending_count="$(echo "$pending_json" | jq 'length')"
  total_pending=$((total_pending + pending_count))

  if [[ "$pending_count" -eq 0 ]]; then
    echo "    pending build-request:  $(green "0")"
  else
    echo "    pending build-request:  $(yellow "$pending_count")"
    echo "$pending_json" | jq -r '.[] | "      #\(.number)  \(.title)"' | head -5
    [[ "$pending_count" -gt 5 ]] && echo "      $(dim "(+ $((pending_count - 5)) more)")"
  fi

  # --- Stuck `building` issues (labeled building, no PR yet) ------------
  stuck_count="$(echo "$issues_json" | jq '[.[] | select(.labels | map(.name) | index("building"))] | length')"
  if [[ "$stuck_count" -gt 0 ]]; then
    echo "    stuck building:         $(red "$stuck_count")"
  fi

  # --- Agent freshness (last filing per agent label) --------------------
  for label in product-data monetization-data content-agent market-intel ua-assets analytics-data; do
    last_iso="$(gh issue list --repo "$repo" --label "$label" --state all --limit 1 \
      --json createdAt --jq '.[0].createdAt // empty' 2>/dev/null)"
    if [[ -n "$last_iso" ]]; then
      days=$(age_days "$last_iso")
      echo "    $(dim "${label}:") ${days}d ago"
    fi
  done

  # --- Focus scoring ----------------------------------------------------
  if [[ "$pr_count" -ge 10 && "$focus_score" -lt 3 ]]; then
    focus_text="drain ${repo} (${pr_count} stacked PRs)"
    focus_score=3
  elif [[ "$pr_count" -ge 5 && "$focus_score" -lt 2 ]]; then
    focus_text="review ${repo} (${pr_count} PRs awaiting review)"
    focus_score=2
  elif [[ "$pending_count" -gt 0 && "$focus_score" -lt 1 ]]; then
    focus_text="build ${pending_count} pending issue(s) on ${repo}"
    focus_score=1
  fi

  echo
done

# ---------------------------------------------------------------- council freshness
echo "$(cyan "▸ Council")"
last_council_line="$(git -C "$FACTORY_DIR" log --format='%aI %s' --grep='council:' -1 2>/dev/null || echo '')"
if [[ -n "$last_council_line" ]]; then
  last_council_iso="${last_council_line%% *}"
  last_council_days=$(age_days "$last_council_iso")
  echo "    last review:  ${last_council_days}d ago  $(dim "(${last_council_line#* })")"
else
  echo "    last review:  $(yellow "never")"
fi
if [[ -f "$FACTORY_DIR/council/runs.jsonl" ]]; then
  runs_count=$(wc -l < "$FACTORY_DIR/council/runs.jsonl" 2>/dev/null | tr -d ' ')
  echo "    runs logged:  ${runs_count:-0}  $(dim "(council/runs.jsonl)")"
fi
echo

# ---------------------------------------------------------------- backlog gate (#54, refined #57)
# Per-game gate: each game has an independent open/sequential-busy/paused state.
# Ripon reviews per-game (drains one game at a time), so portfolio-aggregate
# was the wrong radius. Open games proceed normally; paused games skip game-side
# steps; sequential-busy means "you have 1-2 PRs open here, wait for merge
# before opening another" (preferred default for clean queues).
echo "$(cyan "▸ Backlog gate (per-game)")"
any_paused=0
any_sequential=0
all_open=1
while IFS='|' read -r repo count state; do
  [[ -z "$repo" ]] && continue
  case "$state" in
    paused)
      echo "    $(red "⏸ PAUSED")    $repo  $(dim "($count auto-PRs open, threshold $PER_GAME_THRESHOLD)")"
      any_paused=1
      all_open=0
      ;;
    sequential-busy)
      echo "    $(yellow "◐ busy")     $repo  $(dim "($count auto-PR open — sequential mode: wait for merge)")"
      any_sequential=1
      all_open=0
      ;;
    swarm-state-paused)
      echo "    $(yellow "⏸ swarm-state pause") $repo"
      all_open=0
      ;;
    *)
      echo "    $(green "✓ open")    $repo  $(dim "(0 auto-PRs)")"
      ;;
  esac
done <<< "$PER_GAME_GATE"
if [[ "$any_paused" -eq 1 ]]; then
  echo "    $(dim "Override paused game via explicit \"go force <game>\" / \"override backlog <game>\".")"
fi
echo

# ---------------------------------------------------------------- focus
echo "$(cyan "▸ Suggested focus")"
if [[ "$any_paused" -eq 1 ]]; then
  echo "    drain backlog on paused game(s) — ping Ripon on green-mergeable PRs,"
  echo "    strip stale [DRAFT] titles, close abandoned auto-PRs (>14d). Open games proceed normally."
elif [[ -n "$focus_text" ]]; then
  echo "    $focus_text"
elif [[ "$ss_count" -gt 0 ]]; then
  echo "    $(dim "no pending work — review swarm-state notes and factory-improvement queue")"
else
  echo "    $(green "idle")  $(dim "(nothing pending across all active games)")"
fi
echo
