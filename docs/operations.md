# Operations — Cicero on Minerva

Reference runbook for operating Cicero on Minerva. Not a development guide — see CLAUDE.md for that.

---

## Verifying workspace injection

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

---

## Gateway token rotation

The gateway token authenticates requests to the OpenClaw gateway. It lives in `~/.openclaw/openclaw.json` and in `~/Library/LaunchAgents/ai.openclaw.gateway.plist`.

**Automatic rotation** runs every 6 months via launchd (`ai.cicero.token-rotate`): January 1 and July 1 at 03:00. Logs go to `~/Library/Logs/cicero-token-rotate.{out,err}.log`.

**Manual rotation** (use if the token is ever exposed):
```bash
bash ~/cicero/scripts/rotate_token.sh
```

The script generates a new 48-hex-character token, updates `openclaw.json`, re-renders the gateway plist, and restarts the gateway. The gateway is back up within a few seconds.

To verify the rotation job is loaded:
```bash
launchctl print "gui/$(id -u)/ai.cicero.token-rotate"
```

---

## Common failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Cicero answers as "Assistant" / "Qwen" / model vendor | `skipBootstrap: true` in openclaw.json | Remove it (see above) |
| Cicero answers as "Assistant" / vendor name even after fix | Wrong model — strong RLHF identity anchoring | Check `openclaw config get agents.defaults` → verify `model.primary` is `ollama/qwen3:8b` |
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
| `~/cicero/scripts/ingest_memory.py` | Idempotent ingestion of `docs/archive/cicero-backstory.md` |
| `~/cicero/lib/memory_query.py` | `query_cicero_memory(...)` library function |
| `~/cicero/lib/memory_mcp.py` | MCP server exposing `query_cicero_memory_tool` as an agent tool |
| `~/cicero/workspace/skills/cicero-memory/SKILL.md` | Routing prose; tells the agent when to call the MCP tool |
| `~/Library/LaunchAgents/ai.cicero.chroma.plist` | launchd unit for the Chroma server |
| `~/Library/Logs/cicero-chroma.{out,err}.log` | Server logs |

Server runs at `127.0.0.1:8000`, collection `cicero_memory`, embeddings via `all-MiniLM-L6-v2` (384-dim, cosine). Python env: conda `cicero-memory` (3.11) with packages installed via `uv`.

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
