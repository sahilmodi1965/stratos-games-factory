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

# The above jq has an issue with walking chains (reduce is awkward for variable-length
# DAG traversal). Fall back to a bash loop for chain-walking — more readable, 2-level
# stacks are the common case.
#
# Strategy:
#   1. Build parent->children map in jq → JSON object {parent_num: [child_nums]}
#   2. Bash loop: for each root that has children, walk children in breadth order
#   3. Independents = roots with no children

children_map="$(echo "$graph_json" | jq '
  reduce .[] as $p ({};
    if $p.parent != null then
      .[$p.parent | tostring] = ((.[$p.parent | tostring] // []) + [$p.num])
    else . end)
')"

roots="$(echo "$graph_json" | jq -r '.[] | select(.parent == null) | .num')"

chains=()        # each element is a space-separated chain: "35 40 41"
independents=()

for root in $roots; do
  # Does this root have any children?
  has_child="$(echo "$children_map" | jq --argjson r "$root" 'has(($r | tostring))')"
  if [[ "$has_child" == "true" ]]; then
    # Walk the chain depth-first (single-parent, usually linear).
    chain_nodes=("$root")
    current="$root"
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      next="$(echo "$children_map" | jq -r --argjson c "$current" '.[$c | tostring] // [] | .[0] // empty')"
      [[ -z "$next" ]] && break
      chain_nodes+=("$next")
      current="$next"
    done
    chains+=("${chain_nodes[*]}")
  else
    independents+=("$root")
  fi
done

# ---------------------------------------------------------------- render plan
render_plan() {
  local chain_text=""
  local step=1

  # Ordered chains first.
  if [[ "${#chains[@]}" -gt 0 ]]; then
    for chain in "${chains[@]}"; do
      local first=1
      for pr_num in $chain; do
        if [[ "$first" -eq 1 ]]; then
          chain_text+="${step}. Merge **#${pr_num}** first (foundation — standalone)"$'\n'
          first=0
        else
          chain_text+="${step}. Then **#${pr_num}** (stacks on previous; auto-rebases after merge)"$'\n'
        fi
        step=$((step + 1))
      done
    done
  fi

  # Independents after.
  if [[ "${#independents[@]}" -gt 0 ]]; then
    for pr_num in "${independents[@]}"; do
      [[ -z "$pr_num" ]] && continue
      chain_text+="${step}. **#${pr_num}** — independent, merge anytime"$'\n'
      step=$((step + 1))
    done
  fi

  echo "$chain_text"
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
  if [[ "${#chains[@]}" -gt 0 ]]; then
    for chain in "${chains[@]}"; do
      chain_arr=($chain)
      printf '  Chain: '
      chain_first=1
      for pr_num in "${chain_arr[@]}"; do
        if [[ "$chain_first" -eq 1 ]]; then
          printf '#%s' "$pr_num"
          chain_first=0
        else
          printf ' → #%s' "$pr_num"
        fi
      done
      echo
    done
  fi
  if [[ "${#independents[@]}" -gt 0 ]]; then
    printf '  Independent: '
    ind_first=1
    for pr_num in "${independents[@]}"; do
      [[ -z "$pr_num" ]] && continue
      if [[ "$ind_first" -eq 1 ]]; then
        printf '#%s' "$pr_num"
        ind_first=0
      else
        printf ', #%s' "$pr_num"
      fi
    done
    echo
  fi
  exit 0
fi

# ---------------------------------------------------------------- post mode
# Build the full comment body (same text on every PR in the game).
comment_body="${MARKER}
🤖 **Factory merge plan** — refreshed ${TS}

${plan_body}
<sub>Computed from PR body \"stacks on #N\" markers. Re-posted every swarm pass. Edit in place — no spam.</sub>"

# Collect all PR numbers (chains + independents) to post on.
all_prs=()
if [[ "${#chains[@]}" -gt 0 ]]; then
  for chain in "${chains[@]}"; do
    for pr_num in $chain; do all_prs+=("$pr_num"); done
  done
fi
if [[ "${#independents[@]}" -gt 0 ]]; then
  for pr_num in "${independents[@]}"; do
    [[ -n "$pr_num" ]] && all_prs+=("$pr_num")
  done
fi

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
