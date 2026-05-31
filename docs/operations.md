# Operations — Cicero on minerva

**Status: minerva decommissioned 2026-05-30. This runbook is preserved as the reference for Mac revival. For revival steps and platform porting, see `docs/hibernation.md` first.**

Runbook for operating Cicero on a Mac. Not a development guide — see CLAUDE.md.

---

## Anthropic API key

The key lives in `~/cicero/.env` as `ANTHROPIC_API_KEY=sk-ant-...`. `setup.sh` reads it from there and stamps it into two places:

1. **Gateway plist** (`~/Library/LaunchAgents/ai.openclaw.gateway.plist`) — `EnvironmentVariables` block. OpenClaw's `@openclaw/anthropic-provider` reads `ANTHROPIC_API_KEY` from the process environment. This survives every `cicero gateway restart` without interactive auth.
2. **`~/.config/anthropic/api_key`** (mode 0600) — read by `lib/brain_mcp.py` as fallback if the env var isn't set. Since brain_mcp.py runs as a child of the gateway, it also inherits `ANTHROPIC_API_KEY` from the plist env directly.

**Initial setup** is fully handled by `deploy/mac/setup.sh` — no interactive steps.

If you ever need to register OpenClaw's credential store manually (e.g. after a fresh `openclaw onboard`):
```bash
openclaw models auth login --provider anthropic
# choose "Anthropic API key", paste key
```

**Rotation.** When the key is rotated in the Anthropic console:
1. Update `~/cicero/.env` with the new key.
2. Re-run `./deploy/mac/setup.sh` — it stamps the new key into the plist and the key file.
3. `cicero gateway restart`.
4. Smoke test: `cicero ask "hello"`

**Spend audit.** Each big-brain / galaxy-brain call writes a JSON line to `~/Library/Logs/cicero-brain.log` with model, latency, and token counts. Tail it: `tail -f ~/Library/Logs/cicero-brain.log | jq .`.

---

## Verifying workspace injection

The session `.jsonl` does not contain the system prompt. Check the trajectory:

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

Healthy output: `Injected: True`. If length is far below ~10K chars, workspace files are missing.

---

## Brain mode verification

```bash
# Default Haiku
openclaw agent --agent main --session-id "t-$(date +%s%N)" \
  --message "What's your name and what tools do you have?"

# Big brain (Sonnet) — confirm in the log
openclaw agent --agent main --session-id "t-$(date +%s%N)" \
  --message "big brain: outline a 1955 portfolio thesis in three lines"
tail -1 ~/Library/Logs/cicero-brain.log | jq .

# Galaxy brain (Opus)
openclaw agent --agent main --session-id "t-$(date +%s%N)" \
  --message "galaxy brain: trace a fault from a misfiring 1960s teletype back to a ground loop"
tail -1 ~/Library/Logs/cicero-brain.log | jq .
```

The log line should show `"model": "claude-sonnet-4-6"` or `"claude-opus-4-7"` respectively, along with `input_tokens` / `output_tokens`.

---

## Gateway token rotation

The gateway token authenticates requests to the OpenClaw gateway. It lives in `~/.openclaw/openclaw.json` and in `~/Library/LaunchAgents/ai.openclaw.gateway.plist`.

**Automatic rotation** runs every 6 months via launchd (`ai.cicero.token-rotate`): Jan 1 and Jul 1 at 03:00 UTC. Logs: `~/Library/Logs/cicero-token-rotate.{out,err}.log`.

**Manual rotation:**
```bash
bash ~/cicero/scripts/rotate_token.sh
```

Verify the job is loaded:
```bash
launchctl print "gui/$(id -u)/ai.cicero.token-rotate"
```

---

## iMessage channel

Cicero receives and responds to iMessages via `@openclaw/imessage` backed by the `imsg` CLI. The channel reads `~/Library/Messages/chat.db` directly and sends via Messages.app AppleScript.

| Item | Value |
|---|---|
| Apple ID | `cicero.ortega@icloud.com` |
| Plugin | `@openclaw/imessage` (enabled in `openclaw.json`) |
| Bridge binary | `/opt/homebrew/Cellar/imsg/<version>/libexec/imsg` |
| DM policy | `allowlist` — Carlos (`carlos.m.ortega16@gmail.com`) only |
| Group chats | disabled |
| Catchup | enabled (60 min, 50 messages per restart) |

### Required macOS permissions

Granted once per machine. Re-grant after OS updates that revoke them.

- **Full Disk Access**: `node` binary and the `imsg` binary, in System Settings → Privacy & Security → Full Disk Access.
- **Automation (Messages.app)**: granted in System Settings → Privacy & Security → Automation. Prompted on first send.

### Operating

```bash
openclaw channels status --probe      # channel state
imsg chats --limit 3                  # confirm imsg can read the DB
cicero gateway logs                   # tail gateway logs

# Add an authorized sender — edit openclaw.json, then restart
# channels.imessage.allowFrom: ["carlos.m.ortega16@gmail.com", "+15551234567"]
cicero gateway restart
```

---

## Common failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Provider returns `401 unauthorized` | API key missing or expired | Re-run the auth login; update `~/.config/anthropic/api_key`; restart gateway |
| Big-brain call fails with `No Anthropic API key found` | `~/.config/anthropic/api_key` missing for the MCP | Create the file (mode 0600) |
| Cicero answers as "Assistant" / vendor name | `skipBootstrap: true` in `openclaw.json` | Remove it (see CLAUDE.md) |
| `cicero ask` hangs or errors | Gateway not running | `cicero gateway restart` |
| SOUL.md edit has no effect on `cicero ask` | openclaw.json cached config | Restart gateway |
| Workspace symlink wrong after worktree cleanup | Symlink pointed at worktree path | `ln -sfn ~/cicero/workspace ~/.openclaw/workspace` |
| `cicero ask` answers without backstory context | Chroma server down — MCP tool returns empty | `curl -fsS http://127.0.0.1:8000/api/v2/heartbeat`; `launchctl kickstart -k "gui/$(id -u)/ai.cicero.chroma"` |
| Ingestion fails with `Could not connect to tenant` | Chroma not running or wrong port | Check `~/Library/Logs/cicero-chroma.err.log`; restart unit |
| Agent never invokes `query_cicero_memory_tool` | MCP server unregistered or gateway cached old config | `openclaw mcp list` should show `cicero-memory`; if missing re-run `openclaw mcp set`; restart gateway |
| Brain-escalation tool never invoked despite trigger phrase | MCP unregistered | `openclaw mcp list` should show `cicero-brain`; re-register if missing; restart gateway |
| MCP tool errors with `ModuleNotFoundError: mcp` or `anthropic` | Python deps missing | `cd ~/cicero && uv sync` |
| iMessage: `authorization denied (code: 23)` | Full Disk Access not granted to the imsg binary | Grant FDA to imsg and node in System Settings |
| iMessage: messages from Carlos ignored | `allowFrom` identifier mismatch | `sqlite3 ~/Library/Messages/chat.db "SELECT id FROM handle ORDER BY ROWID DESC LIMIT 10;"` — update `allowFrom` |
| iMessage: channel shows `exited` in logs | FDA revoked (common after macOS update) | Re-grant permissions, restart gateway |
| iMessage: Cicero receives but doesn't send | Automation permission for Messages.app revoked | System Settings → Privacy & Security → Automation — re-enable Messages for Node |

---

## Apple Reminders + Notes integration

Cicero writes to two shared Apple Reminders lists (Honeydew, Groceries) and one shared Apple Notes folder (Cicero). All three are owned by Carlos and shared with `cicero.ortega@icloud.com`.

### One-time manual setup

Done by Carlos on his iPhone (or any of his devices signed into iCloud):

1. **Reminders** → open Honeydew → tap the share icon → invite `cicero.ortega@icloud.com` with "Can make changes". Repeat for Groceries (also shared with Sarah) and Garden (Carlos + Cicero only — do not invite Sarah).
2. **Notes** → create a folder named exactly `Cicero` → share it with `cicero.ortega@icloud.com` *and* Sarah with "Can make changes". Sarah must accept her invite too.

Done on the Mac (Cicero's user account, must be signed into iCloud as `cicero.ortega@icloud.com`):

3. Open **Reminders.app** once. Accept both shared-list invites.
4. Open **Notes.app** once. Accept the shared-folder invite.
5. System Settings → Privacy & Security → **Reminders** → enable the toggle for `node` (the OpenClaw gateway runtime) and Terminal.
6. System Settings → Privacy & Security → **Automation** → expand Terminal and `node` and enable Notes.app.

### Assigning reminders to a person — manual

Apple Reminders supports assigning shared-list items to a specific person (Carlos or Sarah) with native badges and notifications, but neither EventKit nor the Shortcuts "New Reminder" / "Edit Reminder" actions expose the Assignee field as of the macOS version on minerva. Cicero therefore does not assign reminders. When you want one assigned, do it manually on your phone after Cicero creates it — Apple's UI assignee picker is one tap.

### Smart folders (each person, on their own phone)

Carlos and Sarah each set these up once on their iPhone. They don't share — they're personal lenses.

- Notes → File → New Smart Folder → filter by **Tag** → e.g. `#recipe`. Repeat for `#travel`, `#reference`, whatever each person wants.

### Operating

```bash
openclaw mcp list                                    # confirm apple-reminders, cicero-notes registered
openclaw mcp show apple-reminders
cicero ask "list the reminders on Groceries"           # smoke test EventKit reads
cicero ask "add milk, eggs, and butter to Groceries"   # smoke test EventKit writes
cicero ask "save a note titled 'Test' with the body 'hello'"   # smoke test Notes
```

### Common failure modes

| Symptom | Cause | Fix |
|---|---|---|
| `apple-reminders` MCP errors `permission denied` | Reminders permission not granted to node | System Settings → Privacy & Security → Reminders → enable node |
| `cicero-notes` errors `Notes got an error: Can't get folder "Cicero"` | Folder not yet accepted or wrong name | Open Notes.app on the Mac, accept invite, confirm folder name is exactly `Cicero` |
| New note doesn't appear on Sarah's phone | Note was created outside the shared folder | Confirm the `folder` arg defaulted to `"Cicero"`; only that folder is shared |
| `append_to_note` mangles a note | Note contains images/attachments — AppleScript strips them | Create a follow-up note instead; never append to media notes |

---

## Chroma vector memory

The `cicero-memory` skill is backed by a local Chroma server holding semantically-chunked biographical and operational material.

| Path | Purpose |
|---|---|
| `~/cicero/data/chroma/` | Persistent vector store (gitignored — binary index) |
| `~/cicero/scripts/ingest_memory.py` | Idempotent ingestion of `docs/archive/cicero-backstory.md` |
| `~/cicero/lib/memory_query.py` | `query_cicero_memory(...)` library function |
| `~/cicero/lib/memory_mcp.py` | MCP server exposing `query_cicero_memory_tool` |
| `~/cicero/workspace/skills/cicero-memory/SKILL.md` | Routing prose for the agent |
| `~/Library/LaunchAgents/ai.cicero.chroma.plist` | launchd unit for the Chroma server |
| `~/Library/Logs/cicero-chroma.{out,err}.log` | Server logs |

Server runs at `127.0.0.1:8000`, collection `cicero_memory`, embeddings via `all-MiniLM-L6-v2` (384-dim, cosine). Python env: `~/cicero/.venv` (uv-managed, Python 3.14).

### Operating

```bash
curl -fsS http://127.0.0.1:8000/api/v2/heartbeat              # health
launchctl kickstart -k "gui/$(id -u)/ai.cicero.chroma"        # restart Chroma
~/cicero/.venv/bin/python ~/cicero/scripts/ingest_memory.py             # re-ingest (idempotent)
~/cicero/.venv/bin/python ~/cicero/scripts/ingest_memory.py --dry-run   # preview chunks
openclaw mcp list                                              # inspect MCP registrations
openclaw mcp show cicero-memory
cicero gateway restart                                         # apply MCP config changes
```
