# Cicero Architecture

Cicero is a personal AI assistant running as an OpenClaw agent on minerva (Mac mini, Apple Silicon). The repo versions the workspace, skills, and deploy scripts. OpenClaw provides the channel layer, gateway, session loop, and skill runtime. Inference is served by the Anthropic API via OpenClaw's native `@openclaw/anthropic-provider`.

---

## Current Architecture

```
iMessage (primary channel)                       cicero chat / cicero ask (dev)
        │                                                   │
        │                                                   ├── cicero chat → openclaw tui --local
        │                                                   │
        ▼                                                   └── cicero ask  → openclaw agent ...
imsg CLI (/opt/homebrew/bin/imsg)                                       │
  reads ~/Library/Messages/chat.db                                      ▼
        │                                       OpenClaw Gateway (ws://127.0.0.1:18789, loopback)
        └──────────────────────────────────────► Managed by launchd (ai.openclaw.gateway)
                                                            │
                                                            ├── iMessage channel (@openclaw/imessage)
                                                            │       ├── allowlist DM policy (Carlos only)
                                                            │       ├── catchup enabled (60 min window)
                                                            │       └── Apple ID: cicero.ortega@icloud.com
                                                            │
                                                            ├── Agent runtime (single agent: main)
                                                            │       ├── Reads workspace/ at session start
                                                            │       │   (SOUL.md, AGENTS.md, IDENTITY.md, USER.md, TOOLS.md)
                                                            │       ├── Injects skill descriptions into the system prompt
                                                            │       └── Session history in ~/.openclaw/agents/main/sessions/
                                                            │
                                                            ├── Anthropic provider (@openclaw/anthropic-provider)
                                                            │       └── claude-haiku-4-5  [default brain]
                                                            │           Auth: OpenClaw credentials store
                                                            │           or ANTHROPIC_API_KEY env
                                                            │
                                                            └── Workspace skills (workspace/skills/)
                                                                    ├── cicero-memory → memory_mcp.py (stdio)
                                                                    │       └── memory_query.py → Chroma
                                                                    │
                                                                    ├── cicero-bigbrain → brain_mcp.py (stdio)
                                                                    │       ├── big_brain    → Anthropic SDK → Sonnet 4.6
                                                                    │       └── galaxy_brain → Anthropic SDK → Opus 4.7
                                                                    │
                                                                    ├── cicero-reminders → apple-reminders MCP (stdio)
                                                                    │       └── mcp-server-apple-events (FradSer, npx, pinned)
                                                                    │               └── EventKit → shared Reminders lists
                                                                    │                   (Honeydew, Groceries, Garden)
                                                                    │
                                                                    ├── cicero-notes → notes_mcp.py (stdio)
                                                                    │       └── osascript → Notes.app
                                                                    │           → shared "Cicero" folder
                                                                    │
                                                                    └── cicero-health   [stub — not wired]

Chroma server (http://127.0.0.1:8000, loopback only)
  Managed by launchd (ai.cicero.chroma)
  Persist dir: ~/cicero/data/chroma/
  Collection: cicero_memory (all-MiniLM-L6-v2, 384-dim)
```

User messages enter via iMessage or the CLI. The gateway routes them to the `main` agent, which runs on Haiku 4.5. Haiku may call any registered MCP tool — Chroma memory, big-brain/galaxy-brain escalation, web search, or future skills. Big-brain and galaxy-brain calls go directly to the Anthropic API for Sonnet/Opus; the returned answer is delivered verbatim.

---

## Brain modes and escalation

| Mode | Model | How it's invoked |
|---|---|---|
| Default | `claude-haiku-4-5` | Every turn; configured in `agents.defaults.model.primary` |
| Big brain | `claude-sonnet-4-6` | `big_brain` MCP tool, triggered by the phrase "big brain" |
| Galaxy brain | `claude-opus-4-7` | `galaxy_brain` MCP tool, triggered by the phrase "galaxy brain" |

The trigger detection lives in Haiku (per the `cicero-bigbrain` SKILL.md), not in a pre-processor. This was a deliberate simplification: it avoids fighting OpenClaw's routing internals and lets us iterate on trigger phrasing by editing prose, not code.

Each escalation call writes a line to `~/Library/Logs/cicero-brain.log` (model, latency, token usage) for spend audit.

---

## Repo layout

```
cicero/
├── workspace/                       Source of truth for the agent's runtime files.
│   │                                Symlinked from ~/.openclaw/workspace.
│   ├── SOUL.md                      Voice and behavioral rules.
│   ├── IDENTITY.md                  Edmund Hargreaves / Cicero — short factual block.
│   ├── AGENTS.md                    Workspace conventions, memory rules, red lines.
│   ├── USER.md                      Context about Carlos.
│   ├── TOOLS.md                     Environment specifics (host, brain models, data sources).
│   ├── HEARTBEAT.md                 Periodic task checklist (empty — passive by design).
│   └── skills/                      Workspace skills, auto-discovered by OpenClaw.
│       ├── cicero-memory/           Routes to query_cicero_memory_tool MCP.
│       ├── cicero-bigbrain/         Routes to big_brain / galaxy_brain MCPs.
│       ├── cicero-reminders/        Routes to apple-reminders MCP (FradSer, EventKit).
│       ├── cicero-notes/            Routes to notes_mcp.py (AppleScript / shared Notes folder).
│       └── cicero-health/           Stub.
│
├── lib/                             MCP servers + retrieval library.
│   ├── memory_query.py              Semantic search over Chroma.
│   ├── memory_mcp.py                MCP exposing query_cicero_memory_tool.
│   ├── brain_mcp.py                 MCP exposing big_brain + galaxy_brain (Anthropic SDK).
│   ├── notes_mcp.py                 MCP exposing list/get/create/append for Apple Notes (osascript).
│   └── retrieval_middleware.py      Auto-inject memory context into `cicero ask` calls.
│
├── scripts/
│   ├── cicero                       CLI wrapper (chat, ask, gateway).
│   ├── ingest_memory.py             Idempotent ingestion of cicero-backstory.md → Chroma.
│   └── rotate_token.sh              Scheduled gateway token rotation.
│
├── data/                            [gitignored] Chroma vector store.
│   └── chroma/
│
├── deploy/mac/
│   ├── setup.sh                     Idempotent Mac installer.
│   ├── ai.openclaw.gateway.plist    launchd unit (token templated).
│   ├── ai.cicero.chroma.plist       launchd unit for the Chroma server.
│   └── ai.cicero.token-rotate.plist Scheduled token rotation.
│
└── docs/
    ├── architecture.md   This file.
    ├── operations.md     Runbook (gateway, Chroma, iMessage, API key).
    ├── decisions.md      ADRs.
    ├── security.md       API key handling, allowlist, loopback binding.
    ├── roadmap.md        What comes next.
    ├── scope.md          What Cicero is and is not.
    └── archive/
        ├── cicero-backstory.md   Seed corpus for cicero-memory.
        └── persona.md            Historical ADR (now reopened).
```

---

## Deploy

| Component | minerva |
|---|---|
| Machine | Mac mini, Apple Silicon |
| Service manager | launchd user agents |
| Gateway token | env var in launchd plist; rotated semi-annually |
| Primary channel | iMessage (`cicero.ortega@icloud.com`) |
| Dev channel | CLI (`cicero chat`, `cicero ask`) |
| iMessage bridge | `imsg` CLI (`steipete/tap/imsg`) |
| Brain provider | `@openclaw/anthropic-provider` |
| Default model | `claude-haiku-4-5` |
| Escalation models | `claude-sonnet-4-6`, `claude-opus-4-7` (via brain MCP) |
| Setup script | `deploy/mac/setup.sh` |

---

## Known limitations

- **Skill routing.** `cicero-health` is still a stub; Postgres + Apple Health pipeline pending.
- **Reminders + Notes — Apple gaps.** EventKit doesn't expose assignee, flags, or sections; Apple Notes' hashtag parser doesn't fire on AppleScript-written content. Cicero ships without tags, assignment, or flag support — see `docs/roadmap.md` "Reminders + Notes — open items" for the full list and possible future paths.
- **Single agent.** Only `main` is configured.
- **No `~/.openclaw` backup.** Session history and credentials live outside the repo. The workspace itself is git-versioned.
- **iMessage basic mode only.** Reactions, edits, unsend, and threaded replies require SIP off — deliberately not done.
- **No spend caps.** Per-call usage is logged but not capped. If Haiku usage stays bounded and big-brain/galaxy-brain are used sparingly, projected monthly spend is small; revisit when there's real data.
