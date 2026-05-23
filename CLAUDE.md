# CLAUDE.md — Cicero Repo

This repo is Cicero's configuration — personality, workspace files, skills, and deploy scripts. It is not Cicero itself. The runtime is OpenClaw + Ollama running on minerva. Edits here are live immediately (workspace is symlinked into the running agent).

**Primary channel:** iMessage at `cicero.ortega@icloud.com`. CLI (`cicero chat` / `cicero ask`) is for development.

---

## What this repo contains

```
cicero/
├── workspace/              Agent's live files — symlinked to ~/.openclaw/workspace
│   ├── SOUL.md             Voice and behavioral rules. Edit deliberately.
│   ├── IDENTITY.md         Name, vibe, surface metadata.
│   ├── AGENTS.md           Workspace conventions and memory rules.
│   ├── USER.md             Context about Carlos (the user).
│   ├── TOOLS.md            Environment specifics — hostnames, models, data sources.
│   ├── HEARTBEAT.md        Periodic task checklist (currently passive).
│   └── skills/             Workspace-level skills, auto-discovered by OpenClaw.
│       ├── cicero-health/  Stub. Postgres not yet wired.
│       └── cicero-memory/  Routes to query_cicero_memory_tool MCP server.
├── lib/                    Importable Python modules + MCP servers.
│   ├── memory_query.py     query_cicero_memory() — semantic retrieval over Chroma.
│   └── memory_mcp.py       MCP server exposing query_cicero_memory_tool.
├── data/                   [gitignored] Chroma vector store. Local-only.
│   └── chroma/
├── deploy/
│   ├── mac/
│   │   ├── setup.sh                   Idempotent Mac installer (active).
│   │   └── ai.openclaw.gateway.plist  launchd unit template (token templated).
│   └── saturn/                        Legacy Linux deploy. Not the active path.
├── scripts/
│   ├── cicero                         CLI wrapper: `cicero chat` / `cicero ask`
│   └── ingest_memory.py               Idempotent ingestion of docs/archive/cicero-backstory.md into Chroma.
└── docs/
    ├── architecture.md    Current architecture and repo layout.
    ├── decisions.md       Key architectural decisions.
    ├── operations.md      Operational runbook for Minerva.
    ├── roadmap.md         Upcoming workstreams in priority order.
    ├── security.md        Operational discipline for running LLMs locally.
    ├── scope.md           What Cicero is and is not.
    └── archive/
        ├── cicero-backstory.md  Seed corpus for the cicero-memory vector store.
        └── persona.md           ADR: Cicero character persona — end of life.
```

---

## Running Cicero

```bash
cicero chat          # TUI session (embedded local agent, no gateway needed)
cicero ask "..."     # One-shot via gateway
```

Restart gateway (required after openclaw.json changes):
```bash
cicero gateway restart
```

---

## Developer guide

### Editing personality / behavior

Files in `workspace/` are read at session start and injected into the system prompt. Edits are live — no restart needed for `cicero chat`. For `cicero ask` (gateway path), edits are also live per-session; only `openclaw.json` changes need a gateway restart.

| File | Edit when |
|---|---|
| `SOUL.md` | Changing voice, tone, behavioral rules |
| `IDENTITY.md` | Changing name, vibe, avatar |
| `USER.md` | Updating context about Carlos |
| `TOOLS.md` | Adding a new host, data source, or model |
| `AGENTS.md` | Changing workspace conventions or memory rules |

**SOUL.md authoring rules:**
- Keep language natural and descriptive, not imperative or defensive.
- Do not use aggressive override phrasing ("CRITICAL RULE", "never reveal training") — it causes refusal behavior.
- The identity line that works: `You are Cicero — a personal AI assistant. That is your name and your identity.`
### Changing the model

1. Pull the model: `ollama pull <model>`
2. Update `openclaw.json`: `openclaw config get agents.defaults` → edit `model.primary`
3. Update `deploy/mac/setup.sh`: change the `MODEL=` line
4. Update `workspace/TOOLS.md`: note the model under the minerva host entry
5. Restart the gateway: `cicero gateway restart`
6. **Test tool call support in a fresh session:**
   ```bash
   openclaw agent --agent main --session-id "test-$(date +%s%N)" --message "What is your name and what tools do you have available?"
   ```
   Expected: answers as Cicero, lists available tools. If tool calls are broken — try a different model.

| Model | Tool Calls | Status |
|---|---|---|
| qwen3:8b | ✅ Working | Active primary |
| llama3.1:8b-instruct-q5_K_M | ✅ Working | Fallback |

A viable primary model must support Ollama function calling. Test tool call support before setting any model as primary.

### Adding or updating a skill

Skills live in `workspace/skills/<skill-name>/`. Each needs a `SKILL.md` that OpenClaw auto-discovers. A real skill also needs a dispatch mechanism (HTTP endpoint or subprocess call) — prose-only skills route inconsistently.

To add a skill:
1. Create `workspace/skills/<skill-name>/SKILL.md` describing what it does and how to invoke it.
2. Test routing: `cicero ask "use the <skill> skill to ..."` in a fresh session.
3. If routing is unreliable, add an explicit tool call (HTTP/subprocess) to SKILL.md.

### Re-running setup (fresh machine or after a wipe)

```bash
cd ~/cicero
./deploy/mac/setup.sh
```

If it stops asking for `openclaw onboard` — that means `~/.openclaw/openclaw.json` is missing. The script now handles this automatically (non-interactive onboard), but on a truly fresh machine with no prior OpenClaw state it will run onboard as part of setup.

**Critical: after any `openclaw onboard` run**, check for `skipBootstrap`:
```bash
openclaw config get agents.defaults
```
If `skipBootstrap: true` is present, remove it or workspace files will not inject:
```bash
python3 -c "
import json, pathlib
p = pathlib.Path.home() / '.openclaw' / 'openclaw.json'
c = json.loads(p.read_text())
c['agents']['defaults'].pop('skipBootstrap', None)
p.write_text(json.dumps(c, indent=2))
print('done')
"
```
`deploy/mac/setup.sh` removes this automatically on every run.

---

## Key paths on minerva

| Path | What |
|---|---|
| `~/cicero/` | This repo (source of truth) |
| `~/.openclaw/openclaw.json` | OpenClaw runtime config (model, gateway token, auth) |
| `~/.openclaw/workspace` | Symlink → `~/cicero/workspace` |
| `~/.openclaw/agents/main/` | Session history, agent auth state |
| `~/Library/LaunchAgents/ai.openclaw.gateway.plist` | launchd gateway unit (rendered from deploy/mac template) |
| `~/Library/Logs/openclaw-gateway.err.log` | Gateway error log |
| `~/.local/bin/cicero` | CLI shim → `~/cicero/scripts/cicero` |
