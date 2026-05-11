# Cicero Architecture

Cicero is a personal AI assistant running as an OpenClaw agent on Saturn (Linux). The repo versions the workspace, skills, and deploy scripts. OpenClaw provides the inference loop, channel layer, memory system, and skill runtime.

---

## Decisions Log

### Why Path A: OpenClaw, not a custom brain

A custom Python/FastAPI brain meant maintaining an inference loop, channel adapters, memory serialization, and a skill runtime in perpetuity. OpenClaw already solves all of that. The repo's job is to configure the agent — personality, model, skills — not to reimplement the platform. Less surface area is more reliable surface area.

### Why qwen3:8b

Fits in 8GB VRAM (GTX 1080 on Saturn). Strong tool-calling support (`compat.supportsTools: true`). Holds persona well across multi-turn conversations. `llama3.1:8b-instruct-q4_K_M` is the documented fallback if persona drift is observed.

### Why Chroma is a skill, not core memory

OpenClaw's built-in memory (workspace MD files, daily notes, MEMORY.md) handles preferences and short-term context. Chroma earns its place as a semantic search layer over structured data — health records, garden notes, decision logs — that is too large and too structured for the workspace-file model. Keeping it a skill means it is optional, replaceable, and has a clean boundary.

### Why git replaces MLflow

The workspace is Markdown files, not model weights. Version control on configuration and personality is git's problem. MLflow solves experiment tracking for training runs. There are no training runs here.

### Why symlink the workspace into the repo

`~/.openclaw/workspace` is where OpenClaw reads the agent's files at runtime. `~/cicero/workspace` is the git-versioned source of truth. A symlink makes them the same directory. Edits in the repo are immediately live; OpenClaw never diverges from what's committed.

### Why CLI-only for now

No Telegram, Discord, iMessage, or any channel is wired. Saturn is a headless Linux box used for personal compute. The CLI (`openclaw agent --agent main --message "..."`) is sufficient for early development. Channels add attack surface (see `security.md`). iMessage will come when Cicero migrates to a Mac mini that has native Apple ecosystem access.

---

## Current Architecture

```
CLI (openclaw agent …)
        │
        ▼
OpenClaw Gateway (ws://127.0.0.1:18789, loopback only)
        │
        ├── Agent runtime
        │       ├── Reads workspace/ files at session start
        │       │   (SOUL.md, AGENTS.md, IDENTITY.md, USER.md, TOOLS.md)
        │       ├── Injects loaded skill descriptions into system prompt
        │       └── Maintains session history in ~/.openclaw/agents/main/sessions/
        │
        ├── Ollama provider (http://127.0.0.1:11434)
        │       └── qwen3:8b  (keep_alive: 60s, ~7.4GB VRAM when loaded)
        │
        └── Workspace skills (workspace/skills/)
                ├── cicero-health  [stub — Postgres not yet wired]
                └── cicero-memory  [stub — Chroma not yet wired]
```

Data stays on Saturn. No outbound traffic except Ollama inference calls (localhost).

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
│   ├── HEARTBEAT.md        Periodic task checklist (empty — Cicero is passive now).
│   ├── skills/             Workspace-level skill files (auto-discovered by OpenClaw).
│   │   ├── cicero-health/  Stub. Pending health data ingestion workstream.
│   │   └── cicero-memory/  Stub. Pending Chroma wiring.
│   └── cron/               Reserved for future proactive agents. Empty now.
│
├── deploy/
│   ├── saturn/
│   │   ├── openclaw-gateway.service   Systemd user unit (OPENCLAW_GATEWAY_TOKEN templated).
│   │   └── setup.sh                   Idempotent installer. Generates token on first run,
│   │                                  syncs it into openclaw.json, starts the service.
│   └── mac/
│       └── README.md                  Placeholder for the Mac mini migration.
│
└── docs/
    ├── architecture.md    This file.
    ├── security.md        Operational discipline for running LLMs locally.
    ├── roadmap.md         What comes next.
    └── scope.md           What Cicero is and is not.
```

---

## Saturn → Mac Migration Plan

The move happens when iMessage integration is worth pursuing. The workspace is portable — it moves as-is. What changes:

| Component | Saturn (now) | Mac mini (later) |
|-----------|-------------|-----------------|
| Service manager | systemd user unit | launchd plist |
| Package manager | npm global (sudo) | Homebrew |
| Gateway token | env var in unit | env var in plist |
| Channels | none (CLI only) | iMessage (via BlueBubbles or native bridge) |
| Ollama | GTX 1080, 8GB VRAM | Apple Silicon unified memory |
| Health data | Postgres on Saturn | Postgres migrates to Mac, or stays on Saturn as a service |

`deploy/saturn/setup.sh` is the template. `deploy/mac/setup.sh` (not yet written) mirrors it with Homebrew, launchd, and channel enablement.

---

## Known Limitations and Open Questions

- **Skill routing.** qwen3:8b does not reliably route natural-language queries to workspace skills via prose-only SKILL.md. Skills with real tool-call dispatch (HTTP/subprocess) will route more reliably. The stubs are functional as documentation and registration artifacts.
- **keep_alive: 60s.** qwen3:8b unloads from VRAM 60 seconds after idle. Cold start takes ~3-5s. Trade-off: Saturn has only ~500MB VRAM headroom when the model is loaded, so holding it indefinitely crowds out anything else Ollama needs to do.
- **Single agent.** Only the `main` agent is configured. Multi-agent workflows (e.g., a separate coding agent, a separate scheduling agent) are possible in OpenClaw but not yet needed.
- **No backup strategy for ~/.openclaw.** Session history and credentials live outside the repo. The workspace is backed by git. A future `deploy/saturn/backup.sh` should handle the rest.
