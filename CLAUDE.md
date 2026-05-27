# CLAUDE.md — Cicero Repo

This repo is Cicero's configuration — personality, workspace files, skills, deploy scripts, and the MCP servers that back them. It is not Cicero itself. The runtime is OpenClaw on minerva, with inference served by the Anthropic API via OpenClaw's native `@openclaw/anthropic-provider`. Edits here are live (workspace is symlinked into the running agent).

**Primary channel:** iMessage at `cicero.ortega@icloud.com`. CLI (`cicero chat` / `cicero ask`) is for development.

---

## What this repo contains

```
cicero/
├── workspace/              Live files — symlinked to ~/.openclaw/workspace
│   ├── SOUL.md             Voice and behavioral rules.
│   ├── IDENTITY.md         Cicero/Edmund Hargreaves — short factual block.
│   ├── AGENTS.md           Workspace conventions, memory rules, red lines.
│   ├── USER.md             Context about Carlos.
│   ├── TOOLS.md            Environment specifics — host, brain models, data sources.
│   ├── HEARTBEAT.md        Periodic task checklist (passive — empty by design).
│   └── skills/             Workspace-level skills, auto-discovered by OpenClaw.
│       ├── cicero-memory/   → query_cicero_memory_tool (Chroma)
│       ├── cicero-bigbrain/ → big_brain (Sonnet 4.6) + galaxy_brain (Opus 4.7)
│       └── cicero-health/   Stub. Postgres pipeline pending.
├── lib/                    MCP servers + Python libs.
│   ├── memory_query.py     Semantic retrieval over Chroma.
│   ├── memory_mcp.py       MCP exposing query_cicero_memory_tool.
│   ├── brain_mcp.py        MCP exposing big_brain + galaxy_brain (Anthropic SDK).
│   └── retrieval_middleware.py  Auto-inject memory context into `cicero ask`.
├── data/                   [gitignored] Chroma vector store.
├── deploy/mac/
│   ├── setup.sh                       Idempotent Mac installer.
│   ├── ai.openclaw.gateway.plist      launchd unit template (token templated).
│   ├── ai.cicero.chroma.plist         launchd unit for the Chroma server.
│   └── ai.cicero.token-rotate.plist   Scheduled gateway token rotation.
├── scripts/
│   ├── cicero                          CLI wrapper: chat / ask / gateway
│   ├── ingest_memory.py                Idempotent ingestion of cicero-backstory.md → Chroma.
│   └── rotate_token.sh                 Manual gateway token rotation.
└── docs/
    ├── architecture.md   Current architecture and repo layout.
    ├── decisions.md      ADRs.
    ├── operations.md     Runbook for minerva.
    ├── roadmap.md        Upcoming workstreams.
    ├── security.md       Operational discipline.
    ├── scope.md          What Cicero is and is not.
    └── archive/
        ├── cicero-backstory.md  Seed corpus for cicero-memory.
        └── persona.md           Historical ADR (reopened with Claude).
```

---

## Running Cicero

```bash
cicero chat          # TUI session
cicero ask "..."     # One-shot via gateway
```

Restart gateway (required after `openclaw.json` changes, including MCP registrations):
```bash
cicero gateway restart
```

---

## Developer guide

### Editing personality / behavior

Files in `workspace/` are read at session start and injected into the system prompt. Edits to `workspace/` are live per-session. `openclaw.json` changes need a gateway restart.

| File | Edit when |
|---|---|
| `SOUL.md` | Changing voice, tone, behavioral rules |
| `IDENTITY.md` | Changing the factual backstory block, name, avatar |
| `USER.md` | Updating context about Carlos |
| `TOOLS.md` | Adding a host, brain model, or data source |
| `AGENTS.md` | Changing workspace conventions or memory rules |

**SOUL.md authoring rules** (unchanged from prior era):
- Descriptive, not imperative. Natural prose. No "CRITICAL RULE", no "never reveal training".
- The identity line that works: `You are Cicero — a personal AI assistant. That is your name and your identity.`

### Changing the default brain model

The default brain is set in `~/.openclaw/openclaw.json` under `agents.defaults.model.primary` (currently `anthropic/claude-haiku-4-5`).

1. Pick the new model from `openclaw infer model list | grep '"provider":"anthropic"'`.
2. `openclaw config set agents.defaults.model.primary anthropic/<model-id>`.
3. Update `workspace/TOOLS.md` brain table.
4. Update `deploy/mac/setup.sh` so a fresh install picks the new default.
5. `cicero gateway restart`.
6. Smoke test:
   ```bash
   openclaw agent --agent main --session-id "t-$(date +%s%N)" --message "What's your name and what tools do you have?"
   ```

### Changing the escalation models

`lib/brain_mcp.py` pins `BIG_BRAIN_MODEL` and `GALAXY_BRAIN_MODEL`. Edit the constants, run the unit through `python3 lib/brain_mcp.py` once if you want to validate import-time auth, and `cicero gateway restart` to pick up the change in any cached MCP state.

### Adding or updating a skill

Skills live in `workspace/skills/<skill-name>/`. Each needs a `SKILL.md` that OpenClaw auto-discovers. Prose-only skills route inconsistently — back them with an MCP server (see `lib/memory_mcp.py` and `lib/brain_mcp.py` for working examples).

To add one:
1. Create `workspace/skills/<skill-name>/SKILL.md`.
2. If the skill needs a tool, write `lib/<skill>_mcp.py` using FastMCP (`from mcp.server.fastmcp import FastMCP`).
3. Register: `openclaw mcp set <skill> '{"command":"<python>","args":["<repo>/lib/<skill>_mcp.py"]}'`.
4. `cicero gateway restart`.
5. Test in a fresh session: `cicero ask "use the <skill> skill to ..."`

### Re-running setup (fresh machine or after a wipe)

```bash
cd ~/cicero
./deploy/mac/setup.sh
```

The script is idempotent. It installs Node + OpenClaw, registers the Anthropic provider with your API key, registers the MCP servers, creates the workspace symlink, installs the launchd units, and starts the gateway.

If it stops asking for `openclaw onboard`, that means `~/.openclaw/openclaw.json` is missing on a truly fresh machine — let it run.

**After any `openclaw onboard` run**, check for `skipBootstrap`:
```bash
openclaw config get agents.defaults
```
If `skipBootstrap: true` is present, remove it (`setup.sh` does this automatically on every run, but worth knowing).

---

## Key paths on minerva

| Path | What |
|---|---|
| `~/cicero/` | This repo |
| `~/.openclaw/openclaw.json` | OpenClaw runtime config |
| `~/.openclaw/agents/main/agent/auth-profiles.json` | Anthropic provider credentials |
| `~/.config/anthropic/api_key` | API key for brain-escalation MCP (mode 0600) |
| `~/.openclaw/workspace` | Symlink → `~/cicero/workspace` |
| `~/.openclaw/agents/main/sessions/` | Session trajectories |
| `~/Library/LaunchAgents/ai.openclaw.gateway.plist` | Gateway launchd unit |
| `~/Library/LaunchAgents/ai.cicero.chroma.plist` | Chroma launchd unit |
| `~/Library/Logs/openclaw-gateway.{out,err}.log` | Gateway logs |
| `~/Library/Logs/cicero-chroma.{out,err}.log` | Chroma logs |
| `~/Library/Logs/cicero-brain.log` | Per-call spend log for big-brain / galaxy-brain |
| `~/.local/bin/cicero` | CLI shim → `~/cicero/scripts/cicero` |
