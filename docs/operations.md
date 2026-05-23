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

## iMessage channel

Cicero receives and responds to iMessages via the `@openclaw/imessage` plugin backed by the `imsg` CLI. The channel reads `~/Library/Messages/chat.db` directly and sends via Messages.app AppleScript.

| Item | Value |
|---|---|
| Apple ID | `cicero.ortega@icloud.com` |
| Plugin | `@openclaw/imessage` (enabled in `openclaw.json`) |
| Bridge binary | `/opt/homebrew/Cellar/imsg/0.9.0/libexec/imsg` |
| DM policy | `allowlist` — Carlos (`carlos.m.ortega16@gmail.com`) only |
| Group chats | disabled |
| Catchup | enabled (60 min window, 50 messages per restart) |

### Required macOS permissions

Both must be granted once per machine. If revoked or lost after an OS update, re-grant and restart the gateway.

- **Full Disk Access**: granted to `/opt/homebrew/Cellar/node/26.0.0/bin/node` and `/opt/homebrew/Cellar/imsg/0.9.0/libexec/imsg` in System Settings > Privacy & Security > Full Disk Access
- **Automation (Messages.app)**: granted in System Settings > Privacy & Security > Automation — prompted on first send

### Operating the iMessage channel

```bash
# Check channel status
openclaw channels status --probe

# Test imsg can read the database
imsg chats --limit 3

# Check gateway logs for iMessage activity
cicero gateway logs

# Add an authorized sender (wife, etc.) — edit openclaw.json, then restart gateway
# "allowFrom": ["carlos.m.ortega16@gmail.com", "+1XXXXXXXXXX"]
cicero gateway restart
```

### Adding an authorized sender

Edit `~/.openclaw/openclaw.json`, find `channels.imessage.allowFrom`, and append the new handle (email or E.164 phone number like `+15551234567`). Then restart the gateway.

---

## Common failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Cicero answers as "Assistant" / "Qwen" / model vendor | `skipBootstrap: true` in openclaw.json | Remove it (see above) |
| Cicero answers as "Assistant" / vendor name even after fix | Wrong model — strong RLHF identity anchoring | Check `openclaw config get agents.defaults` → verify `model.primary` is `ollama/qwen3:8b` |
| `cicero ask` hangs or errors | Gateway not running | `cicero gateway restart` |
| SOUL.md edit has no effect on `cicero ask` | openclaw.json change needs restart | Restart gateway |
| Workspace symlink wrong after worktree cleanup | Symlink pointed at worktree path | `ln -sfn ~/cicero/workspace ~/.openclaw/workspace` |
| Onboard re-run changed default model | `openclaw onboard` auto-pulls gemma4 | Re-pin: `openclaw config get agents.defaults`, update `model.primary` |
| `cicero ask` answers without backstory context | Chroma server down — MCP tool returns empty | `curl -fsS http://127.0.0.1:8000/api/v2/heartbeat`; `launchctl kickstart -k "gui/$(id -u)/ai.cicero.chroma"` |
| Ingestion fails with `Could not connect to tenant` | Chroma not running or wrong port | Check `~/Library/Logs/cicero-chroma.err.log`; restart unit |
| Agent never invokes `query_cicero_memory_tool` | MCP server unregistered or gateway cached old config | `openclaw mcp list` should show `cicero-memory`; if missing re-run `openclaw mcp set`; restart gateway |
| MCP tool errors with `ModuleNotFoundError: mcp` | `mcp` package not in env | `uv pip install --python ~/miniconda3/envs/cicero-memory/bin/python mcp` |
| iMessage: `authorization denied (code: 23)` | Full Disk Access not granted to the imsg binary | Grant FDA to `/opt/homebrew/Cellar/imsg/0.9.0/libexec/imsg` and `/opt/homebrew/Cellar/node/.../bin/node` in System Settings |
| iMessage: messages from Carlos ignored | `allowFrom` identifier mismatch | `sqlite3 ~/Library/Messages/chat.db "SELECT id FROM handle ORDER BY ROWID DESC LIMIT 10;"` — update `allowFrom` with the correct handle |
| iMessage: channel shows `exited` in logs | FDA revoked (common after macOS update) | Re-grant permissions, restart gateway |
| iMessage: Cicero receives but doesn't send | Automation permission for Messages.app revoked | System Settings > Privacy & Security > Automation — re-enable Messages for Node |

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
cicero gateway restart
```
