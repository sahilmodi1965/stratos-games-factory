# Stratos Games Factory — Agents

Every autonomous behavior in the factory is an **agent**. Each agent is:

1. A folder under `agents/` (except `builder` and `council` which live at `daemon/` and `council/`).
2. Registered in [`agents/registry.json`](registry.json).
3. Dispatched by the **swarm** (Claude Code session), a GitHub event, or manually.
4. Communicates with the rest of the system **only through GitHub issues, PRs, and labels**. No shared database, no direct RPC between agents.

Adding a new agent:

```
agents/myagent/
├── README.md         ← what it does, when it runs, what it outputs
└── (optional script) ← legacy scripts exist but swarm mode is primary
```

Then register it in `registry.json` and add its logic to CLAUDE.md's swarm playbook.

## Current roster

See [`registry.json`](registry.json) for the authoritative list. Human-readable summary:

| Agent | Status | Dispatch | Writes | Reads |
|---|---|---|---|---|
| **builder** | active | swarm (subagent) | PRs that fix/add features | `build-request` issues |
| **product** | active | swarm (inline) | `product-data` issues | `analytics-data` issues + game config |
| **monetization** | active | swarm (inline) | `monetization-data` issues | game ad integration code |
| **content** | active | swarm (inline) | `build-request` issues | game CLAUDE.md + codebase |
| **competitor** | active | swarm (inline) | `market-intel` issues | web search results |
| **ua** | active | swarm (inline) | `ua-assets` issues | game features + release tags |
| **council** | active | swarm (inline) | `COUNCIL.md`, council issues | build.log + PRs/issues |
| **qa** | active | GitHub Actions | screenshots, PR comments | PR diff + built game |
| **platform** | active | manual | `release-ready` issues, APK/AAB artifacts | main branch |

## Design principles

- **Agents don't talk to each other directly.** They all write to GitHub issues. The `builder` agent picks up the output of `content` and `product` because those issues carry the `build-request` label, which is all `builder` knows to look at. No coupling.
- **The swarm is the orchestrator.** When Sahil says "go" in Claude Code, the swarm (CLAUDE.md playbook) runs agents in priority order. See CLAUDE.md for the full playbook.
- **Agents are cheap to add, cheap to retire.** Add a folder, a registry entry, and a step in CLAUDE.md. Remove the same three things.
- **Human review stays in the loop.** Every agent's output goes into the normal GitHub review surface (issues, PRs, labels). Nothing ships without a human merge, except auto-merged safe-path PRs.
