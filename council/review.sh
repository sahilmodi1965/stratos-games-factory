#!/bin/bash
# review.sh — weekly self-audit for the Stratos Games Factory.
#
# Reads the past 7 days of build activity and asks Claude (acting as the
# Stratos Factory Architect) to identify patterns, append lessons learned to
# council/COUNCIL.md, and file GitHub issues for any architectural
# improvements it recommends.
#
# Run by cron: Sunday 00:00 UTC. Safe to run manually.

set -uo pipefail

# cron's minimal PATH does not include Homebrew, nvm, or ~/.local/bin.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$HOME/.nvm/versions/node/v20.20.0/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FACTORY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck disable=SC1091
source "$FACTORY_DIR/daemon/config.sh"

COUNCIL_DIR="$FACTORY_DIR/council"
COUNCIL_MD="$COUNCIL_DIR/COUNCIL.md"
REVIEW_LOG="$COUNCIL_DIR/review.log"
CONTEXT_FILE="$COUNCIL_DIR/review-context.md"

mkdir -p "$COUNCIL_DIR"
touch "$REVIEW_LOG"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$REVIEW_LOG"
}

# ---------------------------------------------------------------- preflight
for tool in git gh claude jq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    log "FATAL: required tool '$tool' not found in PATH"
    exit 1
  fi
done

if ! gh auth status >/dev/null 2>&1; then
  log "FATAL: gh CLI not authenticated"
  exit 1
fi

log "================ weekly council review starting ================"

# ---------------------------------------------------------------- gather context
# Cutoff date for "past 7 days". Both BSD and GNU date variants.
WEEK_CUTOFF="$(date -v-7d '+%Y-%m-%d' 2>/dev/null || date -d '7 days ago' '+%Y-%m-%d' 2>/dev/null || echo '1970-01-01')"
log "context window: since $WEEK_CUTOFF"

{
  echo "# Stratos Factory Weekly Review Context"
  echo
  echo "Generated: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "Window:    $WEEK_CUTOFF → now"
  echo
  echo "---"
  echo
  echo "## Section 1 — Current COUNCIL.md content"
  echo
  if [[ -f "$COUNCIL_MD" ]]; then
    cat "$COUNCIL_MD"
  else
    echo "_(COUNCIL.md does not exist yet)_"
  fi
  echo
  echo "---"
  echo
  echo "## Section 2 — Daemon build.log entries from the past 7 days"
  echo
  echo '```'
  if [[ -f "$FACTORY_DIR/build.log" ]]; then
    awk -v cutoff="$WEEK_CUTOFF" '
      /^\[/ {
        ts = substr($0, 2, 10)
        keep = (ts >= cutoff)
      }
      keep
    ' "$FACTORY_DIR/build.log" || echo "_(awk failed)_"
  else
    echo "_(no build.log)_"
  fi
  echo '```'
  echo
  echo "---"
  echo
  echo "## Section 3 — Closed issues across all game repos in the past 7 days"
  for entry in "${GAME_REPOS[@]}"; do
    IFS='|' read -r repo _ _ _ _ _ <<< "$entry"
    echo
    echo "### $repo"
    echo
    gh issue list --repo "$repo" --state closed --limit 100 \
      --json number,title,closedAt,labels \
      --jq '.[] | select(.closedAt and ((.closedAt | fromdateiso8601) > (now - 604800))) |
            "- #\(.number) \"\(.title)\"  closed=\(.closedAt) labels=[\([.labels[].name] | join(","))]"' \
      2>/dev/null || echo "_(query failed for $repo)_"
  done
  echo
  echo "---"
  echo
  echo "## Section 4 — Closed/merged PRs across all game repos in the past 7 days"
  for entry in "${GAME_REPOS[@]}"; do
    IFS='|' read -r repo _ _ _ _ _ <<< "$entry"
    echo
    echo "### $repo"
    echo
    gh pr list --repo "$repo" --state all --limit 100 \
      --json number,title,closedAt,mergedAt,headRefName,labels \
      --jq '.[] | select(
                  (.closedAt and ((.closedAt | fromdateiso8601) > (now - 604800))) or
                  (.mergedAt and ((.mergedAt | fromdateiso8601) > (now - 604800)))
                ) |
            "- #\(.number) \"\(.title)\"  branch=\(.headRefName)  merged=\(.mergedAt // "no")  labels=[\([.labels[].name] | join(","))]"' \
      2>/dev/null || echo "_(query failed for $repo)_"
  done
  echo
  echo "---"
  echo
  echo "## Section 5 — Currently open auto/* PRs (in case they reveal stuck work)"
  for entry in "${GAME_REPOS[@]}"; do
    IFS='|' read -r repo _ _ _ _ _ <<< "$entry"
    echo
    echo "### $repo"
    echo
    gh pr list --repo "$repo" --state open --limit 100 \
      --json number,title,headRefName,createdAt,labels \
      --jq '.[] | select(.headRefName | startswith("auto/")) |
            "- #\(.number) \"\(.title)\"  branch=\(.headRefName)  created=\(.createdAt)"' \
      2>/dev/null || echo "_(query failed for $repo)_"
  done
  echo
} > "$CONTEXT_FILE"

log "context built: $(wc -l < "$CONTEXT_FILE") lines, $(wc -c < "$CONTEXT_FILE") bytes"

# ---------------------------------------------------------------- existing council issues
existing_council_issues="$(gh issue list \
  --repo sahilmodi1965/stratos-games-factory \
  --label council --state open \
  --json number,title \
  --jq '[.[] | "#\(.number) \(.title)"] | join("\n")' 2>/dev/null || echo "")"

# ---------------------------------------------------------------- prompt for Claude
PROMPT_FILE="$(mktemp -t stratos-council-prompt.XXXXXX)"
cat > "$PROMPT_FILE" <<EOF
You are the **Stratos Factory Architect**. You review the factory's own
performance weekly and recommend improvements. You do NOT build games — you
build the system that builds games.

Your input is the file \`council/review-context.md\` in the current working
directory ($FACTORY_DIR). It contains:

  Section 1 — current \`council/COUNCIL.md\` (the factory's living memory)
  Section 2 — past 7 days of \`build.log\` from the daemon
  Section 3 — closed issues across all game repos in the past 7 days
  Section 4 — closed/merged PRs across all game repos in the past 7 days
  Section 5 — currently open auto/* PRs

Your job:

STEP 1 — Read \`council/review-context.md\` carefully, end to end. Read the
existing \`council/COUNCIL.md\` to understand what the factory already
knows about itself. Do not duplicate entries that are already there.

STEP 2 — Identify patterns in the past week. Ask yourself:
  - Which build attempts failed, and why?
  - Which build attempts succeeded but produced low-quality output (judged
    by issue comments, follow-up issues, or quick re-opening)?
  - Which validators caught real bugs vs. fired false alarms?
  - What parts of the system feel brittle or under-instrumented?
  - What "would have caught this earlier" insights does the data reveal?
  - Are there recurring failure modes that the factory keeps hitting?

If the past week has very little activity (which is likely for the first
weekly run), say so honestly and recommend what data would be most useful
to collect next week.

STEP 3 — Update \`council/COUNCIL.md\`:
  - APPEND new entries; never delete or rewrite existing ones unless they
    are now factually wrong (in which case append a "Lesson learned"
    explaining the correction).
  - Add a new top-level section header for this week's review:
    \`# Weekly review — $(date '+%Y-%m-%d')\`
  - Under it, add new entries using the four entry types defined at the
    top of COUNCIL.md (Lesson learned / Known issue / Architecture
    decision / Improvement suggestion).
  - Every entry must cite specific evidence: an issue number, PR number,
    build.log timestamp, or commit hash. Do not speculate without data.
  - Time-stamp every entry with $(date '+%Y-%m-%d').

STEP 4 — File GitHub issues on \`sahilmodi1965/stratos-games-factory\` for
any architectural improvements you recommend. For each one:

  gh issue create --repo sahilmodi1965/stratos-games-factory \\
    --title "council: <short title>" \\
    --label council \\
    --body "<recommendation with specific evidence and a concrete proposal>"

The \`council\` label distinguishes these from human-filed work. If a
recommendation overlaps with an issue that is already open under the
\`council\` label, add a comment to that existing issue instead of filing
a duplicate.

Currently open council issues (do not duplicate these):
$existing_council_issues

STEP 5 — Prune \`council/COUNCIL.md\` to keep it lean.

The factory daemon no longer reads COUNCIL.md directly — each game repo's
own \`CLAUDE.md\` is the live source of truth. COUNCIL.md is now the
factory's internal log only, and it must stay small enough to be useful.

Rules:
  - Hard cap: maximum **50 active entries** total across all sections
    (Lesson learned / Known issue / Architecture decision /
    Improvement suggestion).
  - For each existing active entry, decide: is this lesson now ENFORCED
    BY CODE (e.g. "the daemon resets forbidden paths" — that's already
    in the daemon, the lesson is no longer load-bearing)? If yes, move
    the entry to \`council/archive.md\` (append, never delete).
  - For each existing active entry, decide: is this entry now FACTUALLY
    OBSOLETE (e.g. references a file that no longer exists, or describes
    a workaround for a fixed bug)? If yes, archive it the same way.
  - If COUNCIL.md still has more than 50 active entries after pruning
    enforced/obsolete ones, archive the OLDEST entries until you're at 50.
  - When archiving an entry, prepend \`[archived YYYY-MM-DD]\` to its
    first line so the archive preserves provenance.
  - \`council/archive.md\` is append-only history. Never edit existing
    archive entries.

STEP 6 — End your response with a single paragraph summarizing what you
found, what you filed, and what you archived. Nothing else after that
paragraph.

# Operating principles

  - Be specific. Cite evidence. The factory will only act on
    recommendations that are backed by actual data, not speculation.
  - Prefer the cheapest validator that would have caught a given failure
    over the most thorough one. The factory has explicitly deferred
    expensive QA infrastructure (puppeteer, vision QA, action replay)
    until the council can justify it from data.
  - If you find a pattern that suggests an existing daemon rule is wrong,
    say so clearly. Architecture decisions are revisable when data shows
    they were wrong.
  - If you find that the past week was uneventful, do NOT invent
    recommendations. An honest "no signal yet" entry is more valuable than
    fabricated ones.
EOF

# ---------------------------------------------------------------- run claude
log "invoking claude (--effort max, in $FACTORY_DIR)"
cd "$FACTORY_DIR"
if command -v gtimeout >/dev/null 2>&1; then
  gtimeout 1800 claude -p --dangerously-skip-permissions --effort max \
    < "$PROMPT_FILE" >> "$REVIEW_LOG" 2>&1
else
  claude -p --dangerously-skip-permissions --effort max \
    < "$PROMPT_FILE" >> "$REVIEW_LOG" 2>&1
fi
claude_exit=$?
rm -f "$PROMPT_FILE"
log "claude exited $claude_exit"

# ---------------------------------------------------------------- ensure council label exists
gh label create "council" \
  --repo sahilmodi1965/stratos-games-factory \
  --color "8957e5" \
  --description "Recommendations from the weekly factory council review" \
  >/dev/null 2>&1 || true

# ---------------------------------------------------------------- commit COUNCIL.md updates
cd "$FACTORY_DIR"
if [[ -n "$(git status --porcelain council/)" ]]; then
  log "committing COUNCIL.md updates"
  git add council/
  git -c user.email="council@stratos.games" -c user.name="Stratos Council" \
    commit -m "council: weekly review $(date '+%Y-%m-%d')" >> "$REVIEW_LOG" 2>&1 || true
  git push origin main >> "$REVIEW_LOG" 2>&1 || true
else
  log "no COUNCIL.md changes to commit"
fi

# ---------------------------------------------------------------- clean up the context file
# (Keep COUNCIL.md and review.log, drop the per-run context file.)
rm -f "$CONTEXT_FILE"

log "================ weekly council review finished (exit $claude_exit) ================"
exit $claude_exit
