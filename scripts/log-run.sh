#!/usr/bin/env bash
# log-run.sh — schema-v3 compliant row builder for council/runs.jsonl.
# Enforces mandatory fields at write time. See CLAUDE.md Step 10.
# Canonical write path since factory-improvement #50.
#
# Exits 2 if a required arg is missing or invalid; 3 if the built row fails
# the schema check (belt-and-suspenders — shouldn't happen with valid args).
set -euo pipefail

RUNS_FILE="${RUNS_FILE:-council/runs.jsonl}"
APPEND=0
# ISO-8601 with TZ on GNU (`date -Iseconds`), fall back to UTC Z on BSD/macOS.
TS="$(date -Iseconds 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")"

SCOPE=""; AGENTS=""; MILESTONE="F1"; SWARM_STATE_SEEN=""
ARB_DECISION=""; ARB_REASON=""; NOTES=""
MEM=""; BRAIN=""; FILED=""; CLOSED=""; ROUTED="0"
GAMES_ARGS=(); DECOMP_ARGS=()

usage() {
  cat <<'USAGE'
Usage: bash scripts/log-run.sh [options]

Required:
  --scope <string>                         factory repo name or game scope
  --arbitration-decision brain|game|mixed|review
  --arbitration-reason "<one sentence>"    which decision-tree branch matched
  --notes "<one line>"                     human note for the council

Optional:
  --game name:issues:prs:failed:skipped    repeatable, per game touched
  --memory-writes a,b,c                    memory filenames written this pass
  --brain-edits a,b,c                      brain files edited this pass
  --factory-issues-filed 50,51             factory-improvement numbers filed
  --factory-issues-closed 30,45            factory-improvement numbers closed
  --observations-routed N                  count of artifacts routed
  --swarm-state-seen N,N                   swarm-state issue numbers seen in Step 1
  --decomposition orig:structure:polish:true|false   repeatable, per split
  --agents a,b                             agents that fired this pass
  --milestone F1                           factory milestone (default F1)
  --append                                 append to council/runs.jsonl
                                           (default: emit to stdout)

Schema: see CLAUDE.md Step 10 for the full v3 row shape.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope) SCOPE="$2"; shift 2;;
    --agents) AGENTS="$2"; shift 2;;
    --game) GAMES_ARGS+=("$2"); shift 2;;
    --milestone) MILESTONE="$2"; shift 2;;
    --swarm-state-seen) SWARM_STATE_SEEN="$2"; shift 2;;
    --decomposition) DECOMP_ARGS+=("$2"); shift 2;;
    --arbitration-decision) ARB_DECISION="$2"; shift 2;;
    --arbitration-reason) ARB_REASON="$2"; shift 2;;
    --memory-writes) MEM="$2"; shift 2;;
    --brain-edits) BRAIN="$2"; shift 2;;
    --factory-issues-filed) FILED="$2"; shift 2;;
    --factory-issues-closed) CLOSED="$2"; shift 2;;
    --observations-routed) ROUTED="$2"; shift 2;;
    --notes) NOTES="$2"; shift 2;;
    --append) APPEND=1; shift;;
    -h|--help) usage; exit 0;;
    *) echo "log-run: unknown arg: $1" >&2; usage >&2; exit 2;;
  esac
done

missing=()
[[ -z "$SCOPE" ]] && missing+=("--scope")
[[ -z "$ARB_DECISION" ]] && missing+=("--arbitration-decision")
[[ -z "$ARB_REASON" ]] && missing+=("--arbitration-reason")
[[ -z "$NOTES" ]] && missing+=("--notes")
if [[ ${#missing[@]} -gt 0 ]]; then
  echo "log-run: missing required arg(s): ${missing[*]}" >&2
  exit 2
fi

case "$ARB_DECISION" in
  brain|game|mixed|review) ;;
  *) echo "log-run: --arbitration-decision must be one of: brain game mixed review (got: $ARB_DECISION)" >&2; exit 2;;
esac

# comma-separated list → jq array; numbers stay numbers, non-numeric → strings.
to_array() {
  local s="${1:-}"
  if [[ -z "$s" ]]; then echo '[]'; return; fi
  jq -nc --arg s "$s" '[ $s | split(",") | map(gsub("^\\s+|\\s+$";"")) | .[] | (tonumber? // .) ]'
}

games_json='{}'
for g in "${GAMES_ARGS[@]+"${GAMES_ARGS[@]}"}"; do
  IFS=':' read -r name i p f s <<< "$g"
  if [[ -z "$name" || -z "$i" || -z "$p" || -z "$f" || -z "$s" ]]; then
    echo "log-run: bad --game (expected name:issues:prs:failed:skipped): $g" >&2; exit 2
  fi
  games_json=$(jq -nc --argjson base "$games_json" --arg name "$name" \
    --argjson i "$i" --argjson p "$p" --argjson f "$f" --argjson s "$s" \
    '$base + {($name): {issues: $i, prs: $p, failed: $f, skipped: $s}}')
done

decomp_json='[]'
for d in "${DECOMP_ARGS[@]+"${DECOMP_ARGS[@]}"}"; do
  IFS=':' read -r orig struct polish smoked <<< "$d"
  case "$smoked" in true|1|yes) smoked_bool=true;; *) smoked_bool=false;; esac
  decomp_json=$(jq -nc --argjson base "$decomp_json" \
    --argjson o "$orig" --argjson st "$struct" --argjson pl "$polish" --argjson sm "$smoked_bool" \
    '$base + [{original: $o, structure: $st, polish: $pl, smoked: $sm}]')
done

row=$(jq -nc \
  --arg ts "$TS" \
  --arg scope "$SCOPE" \
  --argjson agents "$(to_array "$AGENTS")" \
  --argjson games "$games_json" \
  --arg milestone "$MILESTONE" \
  --argjson ss "$(to_array "$SWARM_STATE_SEEN")" \
  --argjson decomp "$decomp_json" \
  --arg arbd "$ARB_DECISION" \
  --arg arbr "$ARB_REASON" \
  --argjson mem "$(to_array "$MEM")" \
  --argjson brain "$(to_array "$BRAIN")" \
  --argjson filed "$(to_array "$FILED")" \
  --argjson closed "$(to_array "$CLOSED")" \
  --argjson routed "$ROUTED" \
  --arg notes "$NOTES" \
  '{
    ts: $ts, scope: $scope, agents: $agents, games: $games,
    factory_milestone: $milestone, swarm_state_seen: $ss,
    decomposition_rule_fired: $decomp,
    arbitration_decision: $arbd, arbitration_reason: $arbr,
    factory_delta: {
      memory_writes: $mem, brain_edits: $brain,
      factory_issues_filed: $filed, factory_issues_closed: $closed,
      observations_routed: $routed
    },
    notes: $notes
  }')

echo "$row" | jq -e '
  .arbitration_decision and .arbitration_reason and
  (.factory_delta | has("memory_writes") and has("brain_edits") and
   has("factory_issues_filed") and has("factory_issues_closed") and has("observations_routed"))
' >/dev/null || { echo "log-run: row failed schema check" >&2; exit 3; }

if [[ "$APPEND" == "1" ]]; then
  echo "$row" >> "$RUNS_FILE"
  echo "log-run: appended to $RUNS_FILE" >&2
else
  echo "$row"
fi
