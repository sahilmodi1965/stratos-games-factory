#!/bin/bash
# status.sh — dashboard for the Stratos Games Factory.
#
# Per game:        last commit, open build-request issues, open auto PRs,
#                  auto-merges this week
# Build queue:     issues currently labeled `building` across all games
# Daemon health:   cron presence, last run, errors in last 24h
# Quick stats:     total processed, total PRs, total auto-merges (last 30d)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FACTORY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck disable=SC1091
source "$FACTORY_DIR/daemon/config.sh"

bold()  { printf "\033[1m%s\033[0m" "$*"; }
dim()   { printf "\033[2m%s\033[0m" "$*"; }
green() { printf "\033[32m%s\033[0m" "$*"; }
yellow(){ printf "\033[33m%s\033[0m" "$*"; }
red()   { printf "\033[31m%s\033[0m" "$*"; }
cyan()  { printf "\033[36m%s\033[0m" "$*"; }

echo
echo "$(bold "Stratos Games Factory — status")"
echo "$(dim "$(date)")"
echo

# Aggregate counters across games
grand_open_issues=0
grand_open_prs=0
grand_building=0
grand_auto_merged_week=0
grand_auto_merged_month=0
grand_done_month=0

# ---------------------------------------------------------------- per-game
for entry in "${GAME_REPOS[@]}"; do
  IFS='|' read -r repo local_dir kind branch _build <<< "$entry"
  echo "$(cyan "▸ $repo")  $(dim "($kind, $branch)")"

  clone_path="$FACTORY_DIR/$local_dir"
  if [[ -d "$clone_path/.git" ]]; then
    last_sha="$(git -C "$clone_path" log -1 --pretty=format:'%h' "$branch" 2>/dev/null || echo '?')"
    last_subj="$(git -C "$clone_path" log -1 --pretty=format:'%s' "$branch" 2>/dev/null || echo '?')"
    last_meta="$(git -C "$clone_path" log -1 --pretty=format:'by %an, %cr' "$branch" 2>/dev/null || echo '')"
    echo "    last commit:    $last_sha $last_subj"
    echo "                    $(dim "$last_meta")"
  else
    echo "    $(yellow "local clone missing")"
  fi

  # Open build-request issues (excluding ones already done)
  open_issues_json="$(gh issue list --repo "$repo" --label "build-request" --state open --json number,title,labels --limit 100 2>/dev/null || echo '[]')"
  open_issues_filtered="$(echo "$open_issues_json" | jq '[.[] | select((.labels | map(.name)) as $l | ($l | index("done") | not))]')"
  open_count="$(echo "$open_issues_filtered" | jq 'length')"
  grand_open_issues=$((grand_open_issues + open_count))
  if [[ "$open_count" -eq 0 ]]; then
    echo "    open requests:  $(green "0")"
  else
    echo "    open requests:  $(yellow "$open_count")"
    echo "$open_issues_filtered" | jq -r '.[] | "      #\(.number)  \(.title)"' | head -5
    if [[ "$open_count" -gt 5 ]]; then
      echo "      $(dim "(+ $((open_count - 5)) more)")"
    fi
  fi

  # Currently building
  building_count="$(echo "$open_issues_json" | jq '[.[] | select((.labels | map(.name)) as $l | $l | index("building"))] | length')"
  grand_building=$((grand_building + building_count))
  if [[ "$building_count" -gt 0 ]]; then
    echo "    in progress:    $(yellow "$building_count")  $(dim "(daemon is working)")"
  fi

  # Open auto PRs
  open_prs_json="$(gh pr list --repo "$repo" --state open --json number,title,headRefName,labels --limit 100 2>/dev/null || echo '[]')"
  auto_pr_count="$(echo "$open_prs_json" | jq '[.[] | select(.headRefName | startswith("auto/"))] | length')"
  grand_open_prs=$((grand_open_prs + auto_pr_count))
  if [[ "$auto_pr_count" -eq 0 ]]; then
    echo "    open auto PRs:  $(green "0")"
  else
    echo "    open auto PRs:  $(yellow "$auto_pr_count")"
    echo "$open_prs_json" | jq -r '.[] | select(.headRefName | startswith("auto/")) | "      #\(.number)  \(.title)"' | head -5
  fi

  # Auto-merge counts (last 7d / last 30d)
  week_cutoff=$(( $(date +%s) - 7 * 86400 ))
  month_cutoff=$(( $(date +%s) - 30 * 86400 ))
  closed_prs_json="$(gh pr list --repo "$repo" --state merged --label "auto-merged" --json number,mergedAt --limit 200 2>/dev/null || echo '[]')"
  week_count="$(echo "$closed_prs_json" | jq --argjson c "$week_cutoff" '[.[] | select(.mergedAt and ((.mergedAt | fromdateiso8601) > $c))] | length')"
  month_count="$(echo "$closed_prs_json" | jq --argjson c "$month_cutoff" '[.[] | select(.mergedAt and ((.mergedAt | fromdateiso8601) > $c))] | length')"
  grand_auto_merged_week=$((grand_auto_merged_week + week_count))
  grand_auto_merged_month=$((grand_auto_merged_month + month_count))
  if [[ "$week_count" -gt 0 ]]; then
    echo "    auto-merged 7d: $(green "$week_count")  $(dim "(${month_count} this month)")"
  else
    echo "    auto-merged 7d: $(dim "0")  $(dim "(${month_count} this month)")"
  fi

  # Done issues this month (closed with `done` label)
  done_issues="$(gh issue list --repo "$repo" --state closed --label "done" --json number,closedAt --limit 200 2>/dev/null || echo '[]')"
  done_month="$(echo "$done_issues" | jq --argjson c "$month_cutoff" '[.[] | select(.closedAt and ((.closedAt | fromdateiso8601) > $c))] | length')"
  grand_done_month=$((grand_done_month + done_month))

  echo
done

# ---------------------------------------------------------------- build queue
echo "$(cyan "▸ Build queue (across all games)")"
if [[ "$grand_building" -gt 0 ]]; then
  echo "    $(yellow "$grand_building issue(s) in progress")"
  for entry in "${GAME_REPOS[@]}"; do
    IFS='|' read -r repo _ _ _ _ <<< "$entry"
    gh issue list --repo "$repo" --label "building" --state open --json number,title 2>/dev/null \
      | jq -r --arg r "$repo" '.[] | "      \($r)#\(.number)  \(.title)"'
  done
else
  echo "    $(green "empty")  $(dim "no issues currently being built")"
fi
echo

# ---------------------------------------------------------------- daemon health
echo "$(cyan "▸ Daemon health")"
if crontab -l 2>/dev/null | grep -Fq "stratos-daemon.sh"; then
  echo "    cron entry:     $(green "installed")"
else
  echo "    cron entry:     $(red "MISSING")  $(dim "(run daemon/install.sh)")"
fi

if [[ -f "$LOG_FILE" ]]; then
  last_log="$(grep -E '^\[.*\] ===+ daemon run' "$LOG_FILE" 2>/dev/null | tail -1)"
  if [[ -n "$last_log" ]]; then
    echo "    last run:       $last_log"
  else
    echo "    last run:       $(yellow "no completed runs yet")"
  fi

  # Errors in the last 24h (parse timestamps from log lines).
  # Portable across BSD/macOS awk: substring extraction, no 3-arg match().
  cutoff_iso="$(date -v-24H '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -d '24 hours ago' '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo '1970-01-01 00:00:00')"
  err_24h="$(awk -v cutoff="$cutoff_iso" '
    /^\[/ {
      ts = substr($0, 2, 19)
      if (ts >= cutoff && /ERROR|FATAL/) c++
    }
    END { print c+0 }
  ' "$LOG_FILE" 2>/dev/null || echo 0)"
  if [[ "$err_24h" -gt 0 ]]; then
    echo "    errors (24h):   $(red "$err_24h")  $(dim "(tail $LOG_FILE)")"
  else
    echo "    errors (24h):   $(green "0")"
  fi
else
  echo "    log file:       $(yellow "missing")  $(dim "($LOG_FILE)")"
fi

if [[ -f "$LOCKFILE" ]]; then
  pid="$(cat "$LOCKFILE" 2>/dev/null || echo "")"
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    echo "    lock:           $(yellow "running (pid $pid)")"
  else
    echo "    lock:           $(red "stale lockfile")  $(dim "(rm $LOCKFILE)")"
  fi
else
  echo "    lock:           $(green "free")"
fi
echo

# ---------------------------------------------------------------- aggregates
echo "$(cyan "▸ Aggregate stats")"
echo "    open build requests:    $grand_open_issues"
echo "    open auto PRs:          $grand_open_prs"
echo "    in progress now:        $grand_building"
echo "    auto-merged (last 7d):  $grand_auto_merged_week"
echo "    auto-merged (last 30d): $grand_auto_merged_month"
echo "    done issues (last 30d): $grand_done_month"
echo
