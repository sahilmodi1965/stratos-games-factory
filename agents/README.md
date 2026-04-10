# Stratos Games Factory — Agents

Every autonomous behavior in the factory is an **agent**. Each agent is:

1. A folder under `agents/` (except the two original agents — `builder` and `council` — that predate this directory and live at `daemon/` and `council/` respectively).
2. Registered in [`agents/registry.json`](registry.json).
3. Triggered by a cron, a GitHub event, or a label.
4. Communicates with the rest of the system **only through GitHub issues, PRs, and labels**. No shared database, no direct RPC between agents.

Adding a new agent:

```
agents/myagent/
├── README.md         ← what it does, when it runs, what it outputs
└── myagent-agent.sh  ← the script (or a reference to GH Actions for passive agents)
```

Then register it in `registry.json` and, if it needs a schedule, add a cron line to `daemon/install.sh`.

## Current roster

See [`registry.json`](registry.json) for the authoritative list. Human-readable summary:

| Agent | Status | Schedule | Writes | Reads |
|---|---|---|---|---|
| **builder** | active | hourly | PRs that fix/add features | `build-request` issues |
| **council** | active | Sunday 00:00 | `COUNCIL.md`, council issues | build.log + PRs/issues |
| **qa** | active | every PR | screenshots, PR comments | PR diff + built game |
| **content** | active | Wednesday 00:00 | `build-request` issues | game CLAUDE.md + codebase |
| **competitor** | active | Tuesday 00:00 | `market-intel` issues | web search results |
| **platform** | active | on `ship-it` label | `release-ready` issues, APK/AAB artifacts | main branch |
| **product** | planned | Monday 00:00 | data-backed improvement issues | Firebase Analytics / Crashlytics |
| **monetization** | planned | Monday 00:00 | ad-optimization issues | AdMob revenue data |
| **ua** | planned | on release | store listings, screenshots, ASO keywords | release tag + game assets |

## Design principles

- **Agents don't talk to each other directly.** They all write to GitHub issues. The `builder` agent picks up the output of `content` and `competitor` because those issues carry the `build-request` label, which is all `builder` knows to look at. No coupling.
- **Agents can be planned before built.** A `README.md` in the agent's folder is a living spec. When someone builds the script, the spec becomes the test.
- **Agents are cheap to add, cheap to retire.** Delete the folder, delete the registry entry, delete the cron line.
- **Human review stays in the loop.** Every agent's output goes into the normal GitHub review surface (issues, PRs, labels). Nothing ships without a human merge, except auto-merged safe-path PRs.
