#!/bin/bash
# status.sh — dashboard for the Stratos Games Factory.
#
# Shows, for each registered game:
#   - last commit on default branch
#   - open `build-request` issues
#   - open PRs from auto/* branches
#   - last daemon-touched timestamp on the local clone
#
# Plus daemon health: cron presence, last log line, error count.

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

# ---------------------------------------------------------------- per-game
for entry in "${GAME_REPOS[@]}"; do
  IFS='|' read -r repo local_dir kind branch _build <<< "$entry"
  echo "$(cyan "▸ $repo")  $(dim "($kind, $branch)")"

  clone_path="$FACTORY_DIR/$local_dir"
  if [[ -d "$clone_path/.git" ]]; then
    last_commit="$(git -C "$clone_path" log -1 --pretty=format:'%h %s (%cr by %an)' "$branch" 2>/dev/null || echo '?')"
    echo "    last commit:  $last_commit"
  else
    echo "    $(yellow "local clone missing")"
  fi

  # Open build-request issues
  open_issues="$(gh issue list --repo "$repo" --label "build-request" --state open --json number,title 2>/dev/null || echo '[]')"
  open_count="$(echo "$open_issues" | jq 'length')"
  if (( open_count == 0 )); then
    echo "    open issues:  $(green "0")"
  else
    echo "    open issues:  $(yellow "$open_count")"
    echo "$open_issues" | jq -r '.[] | "      #\(.number)  \(.title)"'
  fi

  # Open auto/* PRs
  open_prs="$(gh pr list --repo "$repo" --state open --json number,title,headRefName 2>/dev/null || echo '[]')"
  auto_pr_count="$(echo "$open_prs" | jq '[.[] | select(.headRefName | startswith("auto/"))] | length')"
  if (( auto_pr_count == 0 )); then
    echo "    open auto PRs: $(green "0")"
  else
    echo "    open auto PRs: $(yellow "$auto_pr_count")"
    echo "$open_prs" | jq -r '.[] | select(.headRefName | startswith("auto/")) | "      #\(.number)  \(.title)"'
  fi
  echo
done

# ---------------------------------------------------------------- daemon health
echo "$(cyan "▸ Daemon health")"
if crontab -l 2>/dev/null | grep -Fq "stratos-daemon.sh"; then
  echo "    cron entry:   $(green "installed")"
else
  echo "    cron entry:   $(red "MISSING")  (run daemon/install.sh)"
fi

if [[ -f "$LOG_FILE" ]]; then
  last_log="$(grep -E '^\[.*\] ===+ daemon run' "$LOG_FILE" 2>/dev/null | tail -1)"
  if [[ -n "$last_log" ]]; then
    echo "    last run:     $last_log"
  else
    echo "    last run:     $(yellow "no completed runs yet")"
  fi
  err_count="$(grep -cE 'ERROR|FATAL' "$LOG_FILE" 2>/dev/null; :)"
  err_count="${err_count:-0}"
  if (( err_count > 0 )); then
    echo "    errors in log:$(red " $err_count")  (tail $LOG_FILE)"
  else
    echo "    errors in log:$(green " 0")"
  fi
else
  echo "    log file:     $(yellow "missing")  ($LOG_FILE)"
fi

if [[ -f "$LOCKFILE" ]]; then
  pid="$(cat "$LOCKFILE" 2>/dev/null || echo "")"
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    echo "    lock:         $(yellow "running (pid $pid)")"
  else
    echo "    lock:         $(red "stale lockfile")  (rm $LOCKFILE)"
  fi
else
  echo "    lock:         $(green "free")"
fi
echo
