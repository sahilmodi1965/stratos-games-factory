# `agents/aso/` — ASO subagent registry

Smart-af subagents the ASO brain (`brain/aso/README.md`) summons to do focused, crafty work. Each subagent has a single job, a written contract, and an explicit anti-bottleneck rule.

| Subagent | One-line job | Output | Triggered by |
|---|---|---|---|
| [`game-introspector`](game-introspector/README.md) | Read game source, build inventory of exciting state primitives | `brain/aso/inventories/<game>.md` | First encounter with a game OR after game-repo source merges |
| [`state-reacher`](state-reacher/README.md) | Find a path from boot to a target marketing state | Playwright sequence OR minimal-PR proposal OR three-paths-failed report | ASO brain's `carousel-composer` plans a shot |
| [`hook-designer`](hook-designer/README.md) | Design the minimum-viable game-side hook to expose a needed state | PR description for the game repo | `state-reacher` returns "needs minimal hook" |
| [`carousel-composer`](carousel-composer/README.md) | Order shots by conversion psychology, write captions, pick gradients, generate v6 spec | `scripts/store-screenshots/compositions/<game>-v6.json` | After `state-reacher` returns reach-results for all 10 shots |

## Operating principles inherited from the brain

Every subagent under `agents/aso/` inherits the brain's non-negotiable rules from `brain/aso/README.md`:

1. **Target the platform MAXIMUM, never the minimum.** 10 shots App Store, 8 Play. Never settle for compliance floors.
2. **Cleanup-after-yourself.** If your subagent run produces orphan artifacts (scratch files, stale GitHub comments, half-renamed states), clean them before exiting.
3. **Three crafty paths before "blocked".** Existing primitives → minimal new hook → real interaction sequence. In that order.
4. **Single-purpose.** If you notice work outside your charter, route it (file an issue tagged for the right agent) and continue your job. Don't scope-creep.
5. **Smart > compliant.** Build the right thing crafty, not the minimum thing easy.

## Invocation pattern

The ASO brain summons a subagent via Claude Code's Agent tool:

```
Agent({
  subagent_type: "general-purpose",  // until specialized types are registered
  description: "<short description>",
  prompt: "Read agents/aso/<subagent>/README.md. Then: <focused task with inputs>"
})
```

For the four ASO specialists, the brain prepends a charter-load instruction:
```
"Read agents/aso/game-introspector/README.md and follow it as your charter. Then..."
```

Once Phase 2 of the v8 roadmap lands, these subagents may move to first-class `subagent_type` entries in Claude Code's agent registry.

## Communication

Subagents communicate **only through written artifacts**:

- `brain/aso/inventories/<game>.md` — `game-introspector` writes, others read
- `brain/aso/reach-results/<game>/<shot-id>.md` — `state-reacher` writes, `carousel-composer` reads (transient — cleaned each run)
- GitHub issues + PRs — `hook-designer` writes when minimal hooks need shipping
- `scripts/store-screenshots/compositions/<game>-v6.json` — `carousel-composer` writes, `capture.mjs` reads

No shared in-memory state. No direct subagent-to-subagent calls. The brain coordinates by feeding outputs of one subagent as inputs to the next.

## Cross-references

- `brain/aso/README.md` — the brain's charter + pipeline
- `brain/aso/V8-INTROSPECTION-PROPOSAL.md` — the v7 → v8 upgrade plan
- `agents/registry.json` — authoritative agent list (these 4 register here)
- `agents/README.md` — factory-wide agent conventions
