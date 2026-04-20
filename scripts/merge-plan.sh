#!/bin/bash
# merge-plan.sh — compute + publish the merge-order plan for a game's auto/* PRs.
#
# Motivation (factory-improvement #64):
#   Ripon reviews every PR. When auto-PRs stack (e.g. Bloxplode #41→#40→#35),
#   merging out-of-order triggers rebase cascades (~40 min wasted per wrong-order
#   merge). The factory already detects "green + mergeable" (status.sh #56) — this
#   closes the loop by also telling him the CORRECT ORDER on every PR in the chain.
#
# What it does:
#   1. Fetches open auto/* PRs for <repo>
#   2. Parses each PR body/title for "stacks on #N" (and synonyms)
#   3. Builds the dependency graph → ordered chains + independent PRs
#   4. --dry-run: prints the plan to stdout (for status.sh)
#   5. --post:    upserts a marker-tagged comment on every PR in the game
#                 (idempotent — edits in place via the HTML marker)
#
# Usage:
#   bash scripts/merge-plan.sh --dry-run <owner/repo>
#   bash scripts/merge-plan.sh --post    <owner/repo>
#
# Called by:
#   - scripts/status.sh (dry-run, inline display per game)
#   - CLAUDE.md Step 1 Assess (post, after status.sh confirms backlog)

set -uo pipefail

MODE="--dry-run"
REPO=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|--post) MODE="$1"; shift ;;
    -*) echo "unknown flag: $1" >&2; exit 2 ;;
    *)  REPO="$1"; shift ;;
  esac
done

if [[ -z "$REPO" ]]; then
  echo "usage: $0 [--dry-run|--post] <owner/repo>" >&2
  exit 2
fi

MARKER="<!-- factory-merge-plan v1 -->"
TS="$(date -u '+%Y-%m-%d %H:%M UTC')"

# ---------------------------------------------------------------- fetch PRs
prs_json="$(gh pr list --repo "$REPO" --state open \
  --json number,title,body,headRefName,createdAt,isDraft,mergeable --limit 100 2>/dev/null || echo '[]')"

auto_prs="$(echo "$prs_json" | jq '[.[] | select(.headRefName | startswith("auto/"))]')"
pr_count="$(echo "$auto_prs" | jq 'length')"

if [[ "$pr_count" -lt 2 ]]; then
  # Nothing to order — either 0 or 1 PRs, no chain possible.
  if [[ "$MODE" == "--dry-run" ]]; then
    echo "  (no chain — $pr_count open auto-PR$([[ $pr_count -eq 1 ]] && echo "" || echo "s"))"
  fi
  exit 0
fi

# ---------------------------------------------------------------- parse "stacks on #N"
# Detects: "stacks on #N", "stack on #N", "builds on #N", "depends on #N"
# in either PR title OR body. Case-insensitive. First match wins.
# NOTE: jq 1.7.1 silently drops items where try/catch catches a throwing
# capture(), so we use test-then-capture instead (verified working).
graph_json="$(echo "$auto_prs" | jq '
  [ .[] | {
      num: .number,
      title: .title,
      created: .createdAt,
      parent: (((.title // "") + "\n" + (.body // ""))
        | if test("(?i)(stacks?|builds?|depends?) on #[0-9]+")
            then (capture("(?i)(stacks?|builds?|depends?) on #(?<p>[0-9]+)").p | tonumber)
            else null
          end)
    } ]
')"

# ---------------------------------------------------------------- compute chains
# Root = PR with parent == null. For each root, walk its children (PRs whose
# parent == this PR) to build an ordered chain. PRs with no parent AND no
# children are independents.
ordered_json="$(echo "$graph_json" | jq '
  . as $all
  | [ .[] | select(.parent == null) ] as $roots
  | [ .[] | select(.parent != null) | .parent ] as $has_child_set
  | ($has_child_set | unique) as $parents_with_children
  | {
      chains: [
        $roots[]
        | select(.num | IN($parents_with_children[]))
        | . as $root
        | [ $root.num ]
          + [
              # Walk the chain by repeatedly finding the PR whose parent is the last node.
              # Limited to depth 10 — no real stack goes deeper.
              ( reduce range(0; 10) as $_ (
                  {cur: $root.num, acc: []};
                  ($all | map(select(.parent == .cur))) as $_unused  # placeholder, real walk below
                  | .
                )
              | .acc
              )
            ]
        | flatten
      ],
      independents: [
        $roots[]
        | select(.num | IN($parents_with_children[]) | not)
        | .num
      ]
    }
')"

# ---------------------------------------------------------------- build DAG view
# Fix for factory-improvement #67: the prior chain walker picked only the first
# child of each parent (`.[0]`), dropping any non-first branches silently. A PR
# with two stacked descendants on different branches (common in G-stage splits)
# left 4-of-8 PRs missing from the plan. Replacement strategy: skip chain walking
# entirely — render a DAG-aware table, one row per auto-PR, sorted by PR number.
# Every relationship is stated explicitly so Ripon sees the full graph regardless
# of topology.

# Flat list of every auto-PR's number (ascending) — iteration target below.
all_pr_nums="$(echo "$graph_json" | jq -r '[.[] | .num] | sort | .[]')"

# Count children per parent, so foundations with stacked descendants get an
# explicit "has N stacked descendants" hint.
child_count_map="$(echo "$graph_json" | jq '
  reduce .[] as $p ({};
    if $p.parent != null then
      .[$p.parent | tostring] = ((.[$p.parent | tostring] // 0) + 1)
    else . end)
')"

# ---------------------------------------------------------------- render plan
render_plan() {
  local table=""
  table+="| PR | Stacks on | Order hint |"$'\n'
  table+="|---|---|---|"$'\n'

  while IFS= read -r pr_num; do
    [[ -z "$pr_num" ]] && continue
    local parent
    parent="$(echo "$graph_json" | jq -r --argjson n "$pr_num" '.[] | select(.num == $n) | .parent // empty')"
    local kids
    kids="$(echo "$child_count_map" | jq -r --argjson n "$pr_num" '.[$n | tostring] // 0')"

    local stacks_cell hint_cell
    if [[ -z "$parent" ]]; then
      stacks_cell="— (root)"
      if [[ "$kids" -gt 0 ]]; then
        hint_cell="foundation — ${kids} stacked descendant$([[ "$kids" -gt 1 ]] && echo "s") wait on this merging first"
      else
        hint_cell="independent — merge anytime"
      fi
    else
      stacks_cell="#${parent}"
      hint_cell="merge after #${parent} (GitHub auto-rebases onto main)"
    fi
    table+="| #${pr_num} | ${stacks_cell} | ${hint_cell} |"$'\n'
  done <<< "$all_pr_nums"

  echo "$table"
}

plan_body="$(render_plan)"

if [[ -z "$plan_body" ]]; then
  # No chain AND no independents detected — shouldn't happen if pr_count ≥ 2,
  # but guard anyway.
  [[ "$MODE" == "--dry-run" ]] && echo "  (no plan — no stack markers found)"
  exit 0
fi

# ---------------------------------------------------------------- dry-run output
if [[ "$MODE" == "--dry-run" ]]; then
  # Compact edge list — one line per non-root PR, plus an "Independent" line
  # for roots with no stacked descendants. Multi-child parents are natural.
  while IFS= read -r pr_num; do
    [[ -z "$pr_num" ]] && continue
    parent="$(echo "$graph_json" | jq -r --argjson n "$pr_num" '.[] | select(.num == $n) | .parent // empty')"
    [[ -n "$parent" ]] && echo "  Stacks: #${parent} → #${pr_num}"
  done <<< "$all_pr_nums"
  roots_no_kids="$(echo "$graph_json" | jq -r --argjson cc "$child_count_map" '
    [.[] | select(.parent == null) | select(($cc[.num | tostring] // 0) == 0) | .num] | sort | map("#" + tostring) | join(", ")
  ')"
  [[ -n "$roots_no_kids" && "$roots_no_kids" != "" ]] && echo "  Independent: $roots_no_kids"
  exit 0
fi

# ---------------------------------------------------------------- post mode
# Build the full comment body (same text on every PR in the game).
comment_body="${MARKER}
🤖 **Factory merge plan** — refreshed ${TS}

${plan_body}
<sub>Computed from PR body \"stacks on #N\" markers. Re-posted every swarm pass. Edit in place — no spam.</sub>"

# Collect all auto-PR numbers to post on (DAG-aware: every PR, no exceptions).
all_prs=()
while IFS= read -r pr_num; do
  [[ -n "$pr_num" ]] && all_prs+=("$pr_num")
done <<< "$all_pr_nums"

posted=0
patched=0
unchanged=0

for pr_num in "${all_prs[@]}"; do
  # Find existing factory-merge-plan comment on this PR.
  existing="$(gh api "/repos/${REPO}/issues/${pr_num}/comments" --paginate 2>/dev/null \
    | jq -r --arg marker "$MARKER" 'map(select(.body | startswith($marker))) | .[0] // empty' 2>/dev/null)"

  if [[ -n "$existing" ]]; then
    existing_id="$(echo "$existing" | jq -r '.id')"
    existing_body="$(echo "$existing" | jq -r '.body')"
    # Skip PATCH if content is identical (only the timestamp differs → compare
    # everything except the timestamp line).
    norm_existing="$(echo "$existing_body" | grep -vE '^🤖 \*\*Factory merge plan\*\* — refreshed')"
    norm_new="$(echo "$comment_body" | grep -vE '^🤖 \*\*Factory merge plan\*\* — refreshed')"
    if [[ "$norm_existing" == "$norm_new" ]]; then
      unchanged=$((unchanged + 1))
      echo "  #${pr_num}: unchanged (skipped)"
      continue
    fi
    # PATCH in place.
    if gh api --method PATCH "/repos/${REPO}/issues/comments/${existing_id}" \
         -f body="$comment_body" >/dev/null 2>&1; then
      patched=$((patched + 1))
      echo "  #${pr_num}: updated (patched comment ${existing_id})"
    else
      echo "  #${pr_num}: patch FAILED (comment ${existing_id})"
    fi
  else
    # Create new comment.
    if gh pr comment "$pr_num" --repo "$REPO" --body "$comment_body" >/dev/null 2>&1; then
      posted=$((posted + 1))
      echo "  #${pr_num}: posted new comment"
    else
      echo "  #${pr_num}: post FAILED"
    fi
  fi
done

echo
echo "merge-plan summary for ${REPO}: ${posted} posted, ${patched} patched, ${unchanged} unchanged"
