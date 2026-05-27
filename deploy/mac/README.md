# Mac Deploy

Idempotent bootstrap for Cicero on macOS (Apple Silicon). Active deploy path.

## Prerequisites

- Homebrew (https://brew.sh)
- An Anthropic API key. The script will fail with a clear message if it can't find one. Put it at either:
  - `~/.config/anthropic/api_key` (mode 0600), or
  - the `ANTHROPIC_API_KEY` env var (also fine, but the file is preferred so the brain MCP can read it without you re-sourcing your shell).

## Install

```bash
cd ~/cicero
./deploy/mac/setup.sh
```

If `~/.openclaw/openclaw.json` is missing, the script will run `openclaw onboard` non-interactively. On a truly fresh machine with no prior OpenClaw state, this may require one interactive pass — re-run if it stops.

## What it does

- Installs Node and `gh` via Homebrew if missing
- Installs OpenClaw via `npm install -g openclaw@latest`
- Installs `imsg` (`steipete/tap/imsg`) for the iMessage bridge
- Validates the Anthropic API key and registers it with the OpenClaw `@openclaw/anthropic-provider`
- Pins `agents.defaults.model.primary` to `anthropic/claude-haiku-4-5`
- Enables the DuckDuckGo and `@openclaw/imessage` plugins
- Symlinks `~/.openclaw/workspace` → `<repo>/workspace`
- Registers MCP servers: `cicero-memory` (Chroma) and `cicero-brain` (big_brain / galaxy_brain)
- Installs launchd units with a freshly generated gateway token:
  - `ai.openclaw.gateway` — the gateway
  - `ai.cicero.chroma` — the Chroma server
  - `ai.cicero.token-rotate` — semiannual gateway token rotation
- Symlinks `~/.local/bin/cicero` → `scripts/cicero` and adds `~/.local/bin` to `PATH`
- Starts everything via `launchctl`

Re-runnable. The gateway token is generated only on the first install — delete `~/Library/LaunchAgents/ai.openclaw.gateway.plist` to force a fresh one.

## Diagnostics

```bash
cicero gateway status
cicero gateway logs
openclaw infer model auth status
curl -sf http://127.0.0.1:18789/
curl -sf http://127.0.0.1:8000/api/v2/heartbeat
tail -f ~/Library/Logs/cicero-brain.log | jq .
```

## Known config notes

### Workspace bootstrap

After any `openclaw onboard`, OpenClaw can set `skipBootstrap: true` in `agents.defaults`, which prevents workspace files from injecting. `setup.sh` removes it on every run. To check manually:

```bash
openclaw config get agents.defaults
```

If you see `skipBootstrap: true`, remove it and restart the gateway.

### Persona persistence

These keys live inside `agents.defaults`. They are not written by `setup.sh` — merge manually if you want them, after onboarding:

```json
"personaPersistence": {
  "mode": "enforced",
  "reinjectInterval": 3,
  "styleCheck": true,
  "driftThreshold": 0.7
},
"memory": {
  "personaPriority": "high",
  "contextStrategy": "personaFirst"
}
```

With Haiku 4.5 holding character cleanly, these are less critical than they were on the Ollama-era models, but they don't hurt.

After editing, restart: `cicero gateway restart`
