# CLAUDE.md — Cicero Repo

This repo is Cicero's configuration — personality, workspace files, skills, and deploy scripts. It is not Cicero itself. The runtime is OpenClaw + Ollama running on minerva. Edits here are live immediately (workspace is symlinked into the running agent).

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
│   └── ingest_memory.py               Idempotent ingestion of docs/cicero-backstory.md into Chroma.
└── docs/
    ├── architecture.md    Current design and decisions log.
    ├── roadmap.md         Upcoming workstreams in priority order.
    ├── security.md        Operational discipline for running LLMs locally.
    ├── scope.md           What Cicero is and is not.
    └── cicero-backstory.md  Seed corpus for the cicero-memory vector store.
```

---

## Running Cicero

```bash
cicero chat          # TUI session (embedded local agent, no gateway needed)
cicero ask "..."     # One-shot via gateway
```

Gateway health:
```bash
launchctl print "gui/$(id -u)/ai.openclaw.gateway" | head
tail ~/Library/Logs/openclaw-gateway.err.log
```

Restart gateway (required after openclaw.json changes):
```bash
launchctl kickstart -k "gui/$(id -u)/ai.openclaw.gateway"
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
- Do not use aggressive override phrasing ("CRITICAL RULE", "never reveal training") — it causes refusal behavior on deepseek-r1.
- The identity line that works: `You are Cicero — a personal AI assistant. That is your name and your identity.`
- deepseek-r1:14b respects the persona as written. No special anchoring needed.

### Verifying workspace injection

The session `.jsonl` log does not contain the system prompt. Check the trajectory:

```bash
python3 - <<'PY'
import json, glob, os
sessions = glob.glob(os.path.expanduser("~/.openclaw/agents/main/sessions/*.trajectory.jsonl"))
latest = max(sessions, key=os.path.getmtime)
with open(latest) as f:
    for line in f:
        msg = json.loads(line)
        if msg.get("type") == "context.compiled":
            sp = msg["data"]["systemPrompt"]
            print("Injected:", "SOUL" in sp and "Cicero" in sp)
            print("System prompt length:", len(sp), "chars")
            break
PY
```

Healthy output: `Injected: True`, length ~15-17K chars. If length is ~3-4K, workspace files are missing.

### Changing the model

1. Pull the model: `ollama pull <model>`
2. Update `openclaw.json`: `openclaw config get agents.defaults` → edit `model.primary`
3. Update `deploy/mac/setup.sh`: change the `MODEL=` line
4. Update `workspace/TOOLS.md`: note the model under the minerva host entry
5. Restart the gateway: `launchctl kickstart -k "gui/$(id -u)/ai.openclaw.gateway"`
6. **Test persona compliance in a fresh session:**
   ```bash
   openclaw agent --agent main --session-id "test-$(date +%s%N)" --message "What is your name?"
   ```
   Expected: answers as Cicero. If it says "Qwen", "Assistant", or the model vendor — the model's RLHF training overrides persona instructions. Try a different model.

**Known persona compliance:**
- `deepseek-r1:14b` ✅ Holds Cicero identity reliably.
- `qwen3:*` ❌ RLHF training overrides system prompt identity. Not fixable with prompt engineering.

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

## Common failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Cicero answers as "Assistant" / "Qwen" / model vendor | `skipBootstrap: true` in openclaw.json | Remove it (see above) |
| Cicero answers as "Assistant" / "Qwen" even after fix | Wrong model — RLHF identity anchoring | Switch to deepseek-r1:14b |
| `cicero ask` hangs or errors | Gateway not running | `launchctl kickstart -k "gui/$(id -u)/ai.openclaw.gateway"` |
| SOUL.md edit has no effect on `cicero ask` | openclaw.json change needs restart | Restart gateway |
| Workspace symlink wrong after worktree cleanup | Symlink pointed at worktree path | `ln -sfn ~/cicero/workspace ~/.openclaw/workspace` |
| Onboard re-run changed default model | `openclaw onboard` auto-pulls gemma4 | Re-pin: `openclaw config get agents.defaults`, update `model.primary` |
| `cicero ask` answers without backstory context | Chroma server down — MCP tool returns empty | `curl -fsS http://127.0.0.1:8000/api/v2/heartbeat`; `launchctl kickstart -k "gui/$(id -u)/ai.cicero.chroma"` |
| Ingestion fails with `Could not connect to tenant` | Chroma not running or wrong port | Check `~/Library/Logs/cicero-chroma.err.log`; restart unit |
| Agent never invokes `query_cicero_memory_tool` | MCP server unregistered or gateway cached old config | `openclaw mcp list` should show `cicero-memory`; if missing re-run `openclaw mcp set`; restart gateway |
| MCP tool errors with `ModuleNotFoundError: mcp` | `mcp` package not in env | `uv pip install --python ~/miniconda3/envs/cicero-memory/bin/python mcp` |

---

## Chroma vector memory

The `cicero-memory` skill is backed by a local Chroma server holding semantically-chunked biographical and operational lore.

| Path | Purpose |
|---|---|
| `~/cicero/data/chroma/` | Persistent vector store (gitignored — binary index files) |
| `~/cicero/scripts/ingest_memory.py` | Idempotent ingestion of `docs/cicero-backstory.md` |
| `~/cicero/lib/memory_query.py` | `query_cicero_memory(...)` library function |
| `~/cicero/lib/memory_mcp.py` | MCP server exposing `query_cicero_memory_tool` as an agent tool |
| `~/cicero/workspace/skills/cicero-memory/SKILL.md` | Routing prose; tells the agent when to call the MCP tool |
| `~/Library/LaunchAgents/ai.cicero.chroma.plist` | launchd unit for the Chroma server |
| `~/Library/Logs/cicero-chroma.{out,err}.log` | Server logs |

Server runs at `127.0.0.1:8000`, collection `cicero_memory`, embeddings via `all-MiniLM-L6-v2` (384-dim, cosine). Python env: conda `cicero-memory` (3.11) with packages installed via `uv`.

### Current limitation — chat cannot call the tool yet

The MCP server is registered and works end-to-end from Python (`scripts/ingest_memory.py`, `lib/memory_query.py`). But the active chat model `deepseek-r1:14b` is a reasoning model and does **not** support Ollama function calling — declaring `supportsTools: true` for it in `openclaw.json` causes "provider rejected the request schema or tool payload" errors. The chat agent therefore cannot invoke `query_cicero_memory_tool` mid-session.

This unblocks automatically when:
1. A new Ollama model that holds the Cicero persona *and* supports tool calls becomes available (test with the persona compliance check in "Changing the model" above), or
2. OpenClaw gains a way to expose MCP results to a non-tool-using model (e.g. auto-prepending top-k hits into the message context).

The retrieval infrastructure is fully operational from scripts and from any tool-capable client. No action needed beyond the model swap when one is available.

### Operating the server

```bash
# Health check
curl -fsS http://127.0.0.1:8000/api/v2/heartbeat

# Restart Chroma (after plist edits)
launchctl kickstart -k "gui/$(id -u)/ai.cicero.chroma"

# Re-ingest (idempotent — safe to re-run after editing the backstory)
~/miniconda3/envs/cicero-memory/bin/python ~/cicero/scripts/ingest_memory.py

# Dry run (no writes — prints chunks)
~/miniconda3/envs/cicero-memory/bin/python ~/cicero/scripts/ingest_memory.py --dry-run

# Inspect MCP registration
openclaw mcp list
openclaw mcp show cicero-memory

# Restart the gateway after MCP changes (config cache)
launchctl kickstart -k "gui/$(id -u)/ai.openclaw.gateway"
```

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
