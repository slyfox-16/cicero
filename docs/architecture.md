# Cicero Architecture

Cicero is a personal AI assistant running as an OpenClaw agent on Minerva (MacBook Pro M4 Pro, 24GB unified memory, Apple Silicon). The repo versions the workspace, skills, and deploy scripts. OpenClaw provides the inference loop, channel layer, memory system, and skill runtime.

---

## Current Architecture

```
iMessage (primary channel)          cicero chat / cicero ask (dev)
        │                                       │
        │                                       ├── cicero chat → openclaw tui --local
        │                                       │
        ▼                                       └── cicero ask  → openclaw agent ...
imsg CLI (/opt/homebrew/bin/imsg)                           │
  reads ~/Library/Messages/chat.db               ▼
        │                           OpenClaw Gateway (ws://127.0.0.1:18789, loopback only)
        └──────────────────────────► Managed by launchd (ai.openclaw.gateway)
                                                │
                                                ├── iMessage channel (@openclaw/imessage)
                                                │       ├── allowlist DM policy (Carlos only)
                                                │       ├── catchup enabled (60 min window)
                                                │       └── Apple ID: cicero.ortega@icloud.com
                                                │
                                                ├── Agent runtime
                                                │       ├── Reads workspace/ files at session start
                                                │       │   (SOUL.md, AGENTS.md, IDENTITY.md, USER.md, TOOLS.md)
                                                │       ├── Injects loaded skill descriptions into system prompt
                                                │       └── Maintains session history in ~/.openclaw/agents/main/sessions/
                                                │
                                                ├── Ollama provider (http://127.0.0.1:11434, MLX backend)
                                                │       ├── qwen3:8b  [primary]
                                                │       └── llama3.1:8b-instruct-q5_K_M  [fallback]
                                                │
                                                ├── Workspace skills (workspace/skills/)
                                                │       ├── cicero-health  [stub — Postgres not yet wired]
                                                │       └── cicero-memory  →  query_cicero_memory_tool MCP tool
                                                │                                  │
                                                │                                  ▼
                                                │                          memory_mcp.py (stdio-launched)
                                                │                                  │
                                                │                                  ▼
                                                │                          memory_query.py (cosine search)
                                                │                                  │
                                                │                                  ▼
                                                └── Chroma server (http://127.0.0.1:8000, loopback only)
                                                        Managed by launchd (ai.cicero.chroma)
                                                        Persist dir: ~/cicero/data/chroma/
                                                        Collection: cicero_memory (all-MiniLM-L6-v2, 384-dim)
```

All inference and data remain on Minerva. No outbound traffic.

---

## Repo Layout

```
cicero/
├── workspace/              Source of truth for the agent's files.
│   │                       Symlinked from ~/.openclaw/workspace.
│   ├── SOUL.md             Cicero's voice and behavioral rules.
│   ├── IDENTITY.md         Name, vibe, surface metadata.
│   ├── AGENTS.md           Workspace conventions and memory rules.
│   ├── USER.md             Context about Carlos.
│   ├── TOOLS.md            Environment-specific notes (hostnames, devices).
│   ├── HEARTBEAT.md        Periodic task checklist (passive — no active tasks yet).
│   └── skills/             Workspace-level skill files (auto-discovered by OpenClaw).
│       ├── cicero-health/  Stub. Pending health data ingestion workstream.
│       └── cicero-memory/  Routes to query_cicero_memory_tool MCP server.
│
├── lib/                       Importable Python modules + MCP servers.
│   ├── memory_query.py        query_cicero_memory() — semantic retrieval over Chroma.
│   └── memory_mcp.py          MCP server exposing query_cicero_memory_tool to the agent.
│
├── scripts/
│   ├── cicero                 CLI wrapper (cicero chat / cicero ask).
│   └── ingest_memory.py       Idempotent ingestion of cicero-backstory.md into Chroma.
│
├── data/                      [gitignored] Chroma vector store. Local-only.
│   └── chroma/
│
├── deploy/
│   └── mac/
│       ├── setup.sh                   [pending] Idempotent Mac installer.
│       └── ai.openclaw.gateway.plist  launchd unit template (gateway token templated).
│
└── docs/
    ├── architecture.md    This file.
    ├── decisions.md       Key architectural decisions.
    ├── security.md        Operational discipline for running LLMs locally.
    ├── roadmap.md         What comes next.
    └── scope.md           What Cicero is and is not.
```

---

## Deploy

| Component | Minerva |
|-----------|---------|
| Machine | MacBook Pro M4 Pro, 24GB unified memory, Apple Silicon |
| Service manager | launchd user agent |
| Gateway token | env var in launchd plist |
| Primary channel | iMessage (`cicero.ortega@icloud.com`) |
| Dev channel | CLI (`cicero chat`, `cicero ask`) |
| iMessage bridge | `imsg` CLI v0.9.0 (`steipete/tap/imsg`) |
| Ollama backend | MLX (Apple Silicon) |
| Primary model | `qwen3:8b` |
| Fallback model | `llama3.1:8b-instruct-q5_K_M` |
| Setup script | `deploy/mac/setup.sh` |

---

## Known Limitations

- **Skill routing.** `cicero-health` is a stub — the SKILL.md defines behavior but there is no real HTTP/SQL dispatch behind it yet. `cicero-memory` is fully wired: MCP server (`memory_mcp.py`) → retrieval library (`memory_query.py`) → Chroma, launchd-managed. Prose-only stubs route inconsistently; real dispatch is reliable.
- **Single agent.** Only the `main` agent is configured. Multi-agent workflows are not needed yet.
- **No backup for `~/.openclaw`.** Session history and credentials live outside the repo. The workspace is backed by git. A `deploy/mac/backup.sh` is a future work item.
- **iMessage basic mode only.** Running without SIP disabled — no reactions, edit, unsend, or threaded replies. Text send/receive is fully functional. Advanced actions require SIP off (deliberate tradeoff; see `docs/decisions.md`).
