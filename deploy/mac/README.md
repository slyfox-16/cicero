# Mac Deploy

Idempotent bootstrap for Cicero on macOS (Apple Silicon or Intel). Mac equivalent of `deploy/saturn/`.

## Prerequisites

- Homebrew (https://brew.sh)
- Ollama.app installed and running (https://ollama.com/download/mac) — the script will not install Ollama for you, because the .app variant manages its own launchd agent.

## Install

```bash
cd ~/cicero
./deploy/mac/setup.sh
```

If `~/.openclaw/openclaw.json` is missing, the script will stop and ask you to run `openclaw onboard` once interactively. Then re-run the script to finish installing the launchd agent, syncing the gateway token, and wiring up the `cicero` CLI.

## What it does

- Installs Node via Homebrew if missing
- Installs OpenClaw via `npm install -g openclaw@latest`
- Pulls model `qwen3:30b-a3b` via Ollama if missing
- Symlinks `~/.openclaw/workspace` → `<repo>/workspace`
- Installs `~/Library/LaunchAgents/ai.openclaw.gateway.plist` with a freshly generated gateway token and syncs the token into `~/.openclaw/openclaw.json`
- Symlinks `~/.local/bin/cicero` → `scripts/cicero` and adds `~/.local/bin` to `PATH` in `.zshrc`
- Starts the gateway via `launchctl`

Re-runnable. The token is generated only on the first install — delete `~/Library/LaunchAgents/ai.openclaw.gateway.plist` to force a fresh one.

## Diagnostics

```bash
launchctl print "gui/$(id -u)/ai.openclaw.gateway" | head
tail ~/Library/Logs/openclaw-gateway.err.log
curl -sf http://127.0.0.1:18789/
```

## Known config workarounds

### Runtime Config Notes

#### Persona persistence block (added 2026-05-16)

The following block lives under the top-level `"agent"` key in `~/.openclaw/openclaw.json`.
It is not written by `setup.sh` — add it manually after onboarding if missing:

```json
"agent": {
  "persona_persistence": {
    "mode": "enforced",
    "reinject_interval": 3,
    "style_check": true,
    "drift_threshold": 0.7
  },
  "memory": {
    "persona_priority": "high",
    "context_strategy": "persona_first"
  }
}
```

What each setting does:
- `mode "enforced"`: OpenClaw actively monitors persona adherence across tool calls and long turns.
- `reinject_interval 3`: SOUL.md is re-injected every 3 turns to counter context-window persona drift.
- `style_check true`: OpenClaw checks responses for persona consistency.
- `drift_threshold 0.7`: drift tolerance before correction fires.
- `context_strategy "persona_first"`: SOUL.md takes precedence in the assembled system prompt.

After adding, restart the gateway:
```bash
launchctl kickstart -k "gui/$(id -u)/ai.openclaw.gateway"
```

To verify the block is present:
```bash
cat ~/.openclaw/openclaw.json | python3 -c "import json,sys; c=json.load(sys.stdin); print(c.get('agent'))"
```

---

### Streaming disabled for Ollama (openclaw issues #5769 and #12217)

OpenClaw hardcodes `stream: true` on every model call. Ollama's streaming
implementation does not emit `tool_calls` delta chunks correctly — the
streaming response returns empty content with `finish_reason: "stop"`,
silently dropping any tool call the model generated.

**Workaround:** set `streaming: false` inside the model's `params` block.
The top-level streaming config field is dead code (issue #12217) and has
no effect — the fix must be in `params`.

`setup.sh` applies this automatically under `agents.defaults.models.<model>.params`.
If you ever find tool calls silently failing after a config change, verify this key:

```bash
python3 -c "
import json, pathlib
c = json.loads((pathlib.Path.home() / '.openclaw/openclaw.json').read_text())
print(c.get('agents',{}).get('defaults',{}).get('models',{}))
"
```

Expected: `{'ollama/llama3.1:8b-instruct-q5_K_M': {'params': {'streaming': False}}}`
