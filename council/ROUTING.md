# Observation routing — every gap becomes a tracked artifact

This file is the single source of truth for how every agent in the Stratos Games Factory routes observations to tracked artifacts. It is referenced from CLAUDE.md but lives in its own file so the main brain stays lean.

Every agent — main thread, builder subagent, inline agents (product / monetization / content / competitor / UA), council — follows this matrix when it observes a problem the factory should fix or remember. **Never let an observation die in conversation.** Produce a tracked artifact, every time.

## The routing matrix

| What you observed | Where it goes | How |
|---|---|---|
| **Buildable bug or feature gap in a game** | Issue on the **game repo** | `gh issue create --label build-request --milestone <G-stage>` — pick from the G quick reference (CLAUDE.md Step 2), bias to G1 if unclear |
| **Buildable bug or capability gap in the factory** (validators, agents, brain, gates, workflows) | Issue on **`sahilmodi1965/stratos-games-factory`** | `gh issue create --label factory-improvement --milestone <F-stage>` — pick from the F quick reference (CLAUDE.md Step 2), bias to F1 if unclear |
| **Persistent operational state** future passes need to know about (constraint, paused initiative, deferred decision) | Issue on the factory repo | `gh issue create --label swarm-state` — no milestone. Must include "Filed:", "Why this issue exists:", "When to close:" per the swarm-state pattern |
| **Behavioral lesson** future Claude sessions should apply (preference, advisory, corner case) | Memory file via the auto memory system | Use feedback / project / user types per the memory schema. Memory shapes Claude's behavior; issues track factory work. The two are not exclusive — many lessons need both. |
| **Regression in factory metrics** (smoke pass rate, build cycle time, decomposition trip rate, time-to-fix) | Surfaced in next council weekly review **AND** filed as factory-improvement issue with proposed fix | Council reads `runs.jsonl` for patterns and turns recurring failures into buildable issues — never let a regression sit only in the log |

## Enforcement principles

1. **Subagents inherit this rule.** Every subagent prompt (the Step 3 builder spawn template included) ends with: *"If during your work you observe any factory gap, missing capability, or behavioral lesson, file it as the appropriate tracked artifact via the routing matrix in `council/ROUTING.md` BEFORE ending. Never report a gap in your summary text and let it die there."*
2. **Inline agents follow the same rule.** When an inline agent (council / content / competitor / product / monetization / UA) identifies a gap that does not match its own output type, it files the routed artifact in the same pass — not just mentions it in its report.
3. **The main thread audits the routing.** Step 10 (report + log) explicitly checks: *"did any observation in this pass go unrouted?"* If yes, route it before logging.
4. **The council closes the long loop.** Step 9 reads `runs.jsonl` weekly and turns recurring patterns the per-pass routing missed into tracked artifacts. See CLAUDE.md Step 9 for the artifact-per-entry mapping.

This is the single mechanism that makes the factory self-learning **without requiring an orchestrator agent**. Routing is distributed to every agent; this file is the single source of truth; observations cannot escape into ephemeral conversation.
