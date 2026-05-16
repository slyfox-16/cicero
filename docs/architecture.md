# Cicero Architecture

Cicero is a personal AI assistant running as an OpenClaw agent on minerva (Mac). The repo versions the workspace, skills, and deploy scripts. OpenClaw provides the inference loop, channel layer, memory system, and skill runtime.

---

## Decisions Log

### Why Path A: OpenClaw, not a custom brain

A custom Python/FastAPI brain meant maintaining an inference loop, channel adapters, memory serialization, and a skill runtime in perpetuity. OpenClaw already solves all of that. The repo's job is to configure the agent — personality, model, skills — not to reimplement the platform. Less surface area is more reliable surface area.

### Why deepseek-r1:14b

Originally deployed with `qwen3:8b` on Saturn (GTX 1080, 8GB VRAM). After migrating to minerva (Apple Silicon, unified memory), `qwen3:30b-a3b` was available but failed to hold the Cicero persona on direct identity questions — its RLHF training overrides system prompt persona instructions. `deepseek-r1:14b` (9 GB) respects persona instructions reliably, has strong tool-calling support (`compat.supportsTools: true`), and fits comfortably in Apple Silicon unified memory. The R1 reasoning approach lets the model actively apply workspace instructions rather than defaulting to base training identity.

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
cicero chat / cicero ask
        │
        ├── cicero chat → openclaw tui --local (embedded agent, no gateway needed)
        │
        └── cicero ask  → openclaw agent --agent main --message "..."
                                │
                                ▼
                        OpenClaw Gateway (ws://127.0.0.1:18789, loopback only)
                        Managed by launchd (ai.openclaw.gateway)
                                │
                                ├── Agent runtime
                                │       ├── Reads workspace/ files at session start
                                │       │   (SOUL.md, AGENTS.md, IDENTITY.md, USER.md, TOOLS.md)
                                │       ├── Injects loaded skill descriptions into system prompt
                                │       └── Maintains session history in ~/.openclaw/agents/main/sessions/
                                │
                                ├── Ollama provider (http://127.0.0.1:11434)
                                │       └── deepseek-r1:14b  (~9GB unified memory)
                                │
                                └── Workspace skills (workspace/skills/)
                                        ├── cicero-health  [stub — Postgres not yet wired]
                                        └── cicero-memory  [stub — Chroma not yet wired]
```

Data stays on minerva. No outbound traffic except Ollama inference calls (localhost).

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

## Deploy

| Component | minerva (current) | Saturn (legacy) |
|-----------|-------------------|-----------------|
| Machine | Mac mini, Apple Silicon | Linux, GTX 1080 |
| Service manager | launchd user agent | systemd user unit |
| Package manager | Homebrew + npm | npm global (sudo) |
| Gateway token | env var in launchd plist | env var in systemd unit |
| Channels | none (CLI only) | none (CLI only) |
| Ollama | Apple Silicon unified memory | GTX 1080, 8GB VRAM |
| Model | `deepseek-r1:14b` | `qwen3:8b` |
| Setup script | `deploy/mac/setup.sh` | `deploy/saturn/setup.sh` |

Both setup scripts are idempotent. `deploy/mac/setup.sh` is the active install path.

---

## Known Limitations and Open Questions

- **Skill routing.** Skills with prose-only SKILL.md definitions route inconsistently. Skills with real tool-call dispatch (HTTP/subprocess) route more reliably. The stubs are functional as documentation and registration artifacts.
- **deepseek-r1 thinking blocks.** The model emits `<think>...</think>` reasoning before responses. OpenClaw suppresses these in TUI output; they are visible in raw trajectory logs. No action needed unless verbosity becomes a problem.
- **Single agent.** Only the `main` agent is configured. Multi-agent workflows are possible in OpenClaw but not yet needed.
- **No backup strategy for ~/.openclaw.** Session history and credentials live outside the repo. The workspace is backed by git. A future `deploy/mac/backup.sh` should handle the rest.
