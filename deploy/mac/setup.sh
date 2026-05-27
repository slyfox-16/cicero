#!/usr/bin/env bash
# Idempotent bootstrap for Cicero on a macOS box (Apple Silicon).
#
#   ./deploy/mac/setup.sh
#
# Re-runnable. Skips steps already done. Reuses the gateway token from
# openclaw.json if one is already present; otherwise generates one.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORKSPACE="$REPO_ROOT/workspace"
PLIST_SRC="$REPO_ROOT/deploy/mac/ai.openclaw.gateway.plist"
PLIST_DST="$HOME/Library/LaunchAgents/ai.openclaw.gateway.plist"
PLIST_LABEL="ai.openclaw.gateway"
CHROMA_PLIST_SRC="$REPO_ROOT/deploy/mac/ai.cicero.chroma.plist"
CHROMA_PLIST_DST="$HOME/Library/LaunchAgents/ai.cicero.chroma.plist"
CHROMA_PLIST_LABEL="ai.cicero.chroma"
ROTATE_PLIST_SRC="$REPO_ROOT/deploy/mac/ai.cicero.token-rotate.plist"
ROTATE_PLIST_DST="$HOME/Library/LaunchAgents/ai.cicero.token-rotate.plist"
ROTATE_PLIST_LABEL="ai.cicero.token-rotate"
OPENCLAW_HOME="$HOME/.openclaw"
OPENCLAW_CONFIG="$OPENCLAW_HOME/openclaw.json"
WORKSPACE_LINK="$OPENCLAW_HOME/workspace"
ANTHROPIC_KEY_FILE="$HOME/.config/anthropic/api_key"
MODEL_REF="anthropic/claude-haiku-4-5"
VENV_PY="$REPO_ROOT/.venv/bin/python"

log() { printf '[setup] %s\n' "$*"; }
warn() { printf '[setup] WARN: %s\n' "$*" >&2; }
die() { printf '[setup] ERROR: %s\n' "$*" >&2; exit 1; }

# 1. Homebrew preflight
command -v brew >/dev/null 2>&1 || die "Homebrew not found. Install from https://brew.sh and re-run."
log "brew: $(brew --version | head -1)"

# 2. Node + npm
if ! command -v node >/dev/null 2>&1; then
  log "installing node via Homebrew"
  brew install node
fi
log "node: $(node --version)"
command -v npm >/dev/null 2>&1 || die "npm not found after node install"

# 2a. GitHub CLI
if ! command -v gh >/dev/null 2>&1; then
  log "installing gh (GitHub CLI) via Homebrew"
  brew install gh
else
  log "gh: $(gh --version | head -1)"
fi

# 3. Anthropic API key — required for both the OpenClaw provider and the brain MCP
# Resolution order: env var → .env file in repo root → key file
api_key=""
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  api_key="$ANTHROPIC_API_KEY"
  log "using ANTHROPIC_API_KEY from environment"
elif [ -f "$REPO_ROOT/.env" ]; then
  # Parse .env tolerantly: strip spaces, quotes, and export keyword
  api_key="$(grep -E '^[[:space:]]*(export[[:space:]]+)?ANTHROPIC_API_KEY' "$REPO_ROOT/.env" \
    | head -1 \
    | sed 's/^[[:space:]]*(export[[:space:]]+)?ANTHROPIC_API_KEY[[:space:]]*=[[:space:]]*//' \
    | tr -d '"'"'"' ' \
    | tr -d '[:space:]')"
  [ -n "$api_key" ] && log "using ANTHROPIC_API_KEY from $REPO_ROOT/.env"
fi
if [ -z "$api_key" ] && [ -r "$ANTHROPIC_KEY_FILE" ]; then
  api_key="$(tr -d '[:space:]' < "$ANTHROPIC_KEY_FILE")"
  [ -n "$api_key" ] && log "using API key from $ANTHROPIC_KEY_FILE"
fi
[ -n "$api_key" ] || die "Anthropic API key not found. Add it to $REPO_ROOT/.env as ANTHROPIC_API_KEY=sk-ant-... or write it to $ANTHROPIC_KEY_FILE (mode 0600)."

# Mirror the key into the file so the brain MCP can read it regardless of shell state
mkdir -p "$(dirname "$ANTHROPIC_KEY_FILE")"
umask_old=$(umask)
umask 077
printf '%s' "$api_key" > "$ANTHROPIC_KEY_FILE"
umask "$umask_old"
chmod 600 "$ANTHROPIC_KEY_FILE"
log "anthropic api key persisted at $ANTHROPIC_KEY_FILE (mode 0600)"

# 4. OpenClaw CLI
if ! command -v openclaw >/dev/null 2>&1; then
  log "installing openclaw via npm -g"
  npm install -g openclaw@latest
fi
log "openclaw: $(openclaw --version 2>&1 | head -1)"

# 5. Token: reuse the one in openclaw.json if present, else generate a fresh one
mkdir -p "$OPENCLAW_HOME"
if [ -f "$OPENCLAW_CONFIG" ]; then
  token="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("gateway",{}).get("auth",{}).get("token",""))' "$OPENCLAW_CONFIG")"
else
  token=""
fi
if [ -z "$token" ]; then
  token="$(openssl rand -hex 24 2>/dev/null || head -c 48 /dev/urandom | xxd -p -c 48)"
  [ -n "$token" ] || die "failed to generate gateway token (need openssl or xxd)"
  log "generated new gateway token"
else
  log "reusing existing gateway token from openclaw.json"
fi

# 6. Onboard if openclaw.json is missing
if [ ! -f "$OPENCLAW_CONFIG" ]; then
  log "running openclaw onboard (non-interactive, local + anthropic)"
  ANTHROPIC_API_KEY="$api_key" openclaw onboard \
    --non-interactive --accept-risk \
    --flow quickstart \
    --mode local \
    --auth-choice anthropic-cli \
    --anthropic-api-key "$api_key" \
    --gateway-bind loopback \
    --gateway-port 18789 \
    --gateway-auth token \
    --gateway-token "$token" \
    --skip-daemon \
    --skip-channels \
    --skip-skills \
    || warn "onboard returned non-zero (gateway not running yet is expected)"
  [ -f "$OPENCLAW_CONFIG" ] || die "onboard did not create $OPENCLAW_CONFIG"
else
  log "openclaw.json already present — skipping onboard"
fi

# 7. Register / refresh the Anthropic API key with the OpenClaw provider
# OpenClaw 2026.5.x uses `openclaw models auth login` (interactive).
# We check whether auth is already present; if not, prompt the user to run it manually.
log "anthropic API key injected into gateway plist env — no interactive auth login needed"

# 8. Pin the agent default model to Haiku, sync gateway token, ensure clean state
python3 - "$OPENCLAW_CONFIG" "$token" "$MODEL_REF" <<'PY'
import json, os, sys
path, token, model_ref = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    cfg = json.load(f)
defaults = cfg.setdefault("agents", {}).setdefault("defaults", {})
model_cfg = defaults.setdefault("model", {})
model_cfg["primary"] = model_ref
model_cfg.pop("fallback", None)
defaults.pop("skipBootstrap", None)
# Drop legacy per-model Ollama params (no-ops for Anthropic; kept harmlessly removed)
models = defaults.get("models")
if isinstance(models, dict):
    for k in list(models.keys()):
        if k.startswith("ollama/"):
            models.pop(k, None)
    if not models:
        defaults.pop("models", None)
cfg.setdefault("gateway", {}).setdefault("auth", {})
cfg["gateway"]["auth"]["mode"] = "token"
cfg["gateway"]["auth"]["token"] = token
tools = cfg.setdefault("tools", {})
tools["profile"] = "coding"
tools["deny"] = ["canvas", "image_generate", "music_generate", "video_generate", "code_execution"]
channels = cfg.setdefault("channels", {})
if "imessage" not in channels:
    channels["imessage"] = {
        "enabled": True,
        "cliPath": "/opt/homebrew/bin/imsg",
        "dbPath": f"{os.environ['HOME']}/Library/Messages/chat.db",
        "service": "imessage",
        "dmPolicy": "allowlist",
        "allowFrom": ["carlos.m.ortega16@gmail.com"],
        "groupPolicy": "disabled",
        "coalesceSameSenderDms": True,
        "blockStreaming": True,
        "catchup": {
            "enabled": True,
            "maxAgeMinutes": 60,
            "perRunLimit": 50,
            "firstRunLookbackMinutes": 30,
        },
    }
with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
PY
log "openclaw.json: model -> $MODEL_REF, token synced, skipBootstrap removed, legacy ollama params pruned"

# 8a. Enable DuckDuckGo web search
openclaw plugins enable duckduckgo >/dev/null 2>&1 || true
log "duckduckgo plugin enabled"

# 8b. imsg CLI for iMessage channel
if ! command -v imsg >/dev/null 2>&1; then
  log "installing imsg via Homebrew (steipete/tap)"
  brew tap steipete/tap 2>/dev/null || true
  brew install steipete/tap/imsg
else
  log "imsg already installed: $(imsg --version 2>&1 | head -1)"
fi

# 8c. Enable iMessage plugin
openclaw plugins enable imessage >/dev/null 2>&1 || true
log "imessage plugin enabled"

# 9. Workspace symlink
if [ -L "$WORKSPACE_LINK" ]; then
  current="$(readlink "$WORKSPACE_LINK")"
  if [ "$current" != "$WORKSPACE" ]; then
    log "repointing workspace symlink ($current -> $WORKSPACE)"
    ln -sfn "$WORKSPACE" "$WORKSPACE_LINK"
  else
    log "workspace symlink already correct"
  fi
elif [ -d "$WORKSPACE_LINK" ] && [ -z "$(ls -A "$WORKSPACE_LINK")" ]; then
  log "removing empty workspace dir to replace with symlink"
  rmdir "$WORKSPACE_LINK"
  ln -sfn "$WORKSPACE" "$WORKSPACE_LINK"
elif [ -e "$WORKSPACE_LINK" ]; then
  backup="$WORKSPACE_LINK.pre-cicero-$(date +%s)"
  warn "existing $WORKSPACE_LINK is not empty; moving to $backup"
  mv "$WORKSPACE_LINK" "$backup"
  ln -sfn "$WORKSPACE" "$WORKSPACE_LINK"
else
  ln -sfn "$WORKSPACE" "$WORKSPACE_LINK"
fi
log "workspace -> $(readlink "$WORKSPACE_LINK")"

# 9a. Ensure Python venv and deps (uv-managed, repo-local at .venv/)
if ! command -v uv >/dev/null 2>&1; then
  log "installing uv via Homebrew"
  brew install uv
fi
log "uv: $(uv --version)"
log "syncing Python venv at $REPO_ROOT/.venv"
(cd "$REPO_ROOT" && uv sync --quiet) \
  || die "uv sync failed — check pyproject.toml and try: cd $REPO_ROOT && uv sync"
[ -x "$VENV_PY" ] || die "venv python not found at $VENV_PY after uv sync"
log "venv python: $("$VENV_PY" --version)"

# 9b. Register MCP servers
log "registering MCP servers"
MEMORY_MCP_JSON="{\"command\":\"$VENV_PY\",\"args\":[\"$REPO_ROOT/lib/memory_mcp.py\"]}"
BRAIN_MCP_JSON="{\"command\":\"$VENV_PY\",\"args\":[\"$REPO_ROOT/lib/brain_mcp.py\"]}"
openclaw mcp set cicero-memory "$MEMORY_MCP_JSON" >/dev/null 2>&1 \
  || warn "failed to register cicero-memory MCP"
openclaw mcp set cicero-brain "$BRAIN_MCP_JSON" >/dev/null 2>&1 \
  || warn "failed to register cicero-brain MCP"

# 10. Install / refresh launchd plist for the gateway
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
npm_root="$(npm root -g)"
openclaw_entry="$npm_root/openclaw/dist/index.js"
[ -f "$openclaw_entry" ] || die "openclaw entry not found at $openclaw_entry"
node_bin="$(command -v node)"

tmp_plist="$(mktemp)"
sed \
  -e "s|__GENERATE_ME__|$token|g" \
  -e "s|__HOME__|$HOME|g" \
  -e "s|__NODE_BIN__|$node_bin|g" \
  -e "s|__OPENCLAW_ENTRY__|$openclaw_entry|g" \
  -e "s|__ANTHROPIC_API_KEY__|$api_key|g" \
  "$PLIST_SRC" > "$tmp_plist"

needs_bootstrap=0
if [ ! -f "$PLIST_DST" ]; then
  needs_bootstrap=1
  mv "$tmp_plist" "$PLIST_DST"
  log "installed launchd plist"
elif ! cmp -s "$tmp_plist" "$PLIST_DST"; then
  mv "$tmp_plist" "$PLIST_DST"
  log "refreshed launchd plist (content changed)"
else
  rm -f "$tmp_plist"
  log "launchd plist already up to date"
fi
if [ "$needs_bootstrap" -eq 1 ]; then
  launchctl bootstrap "gui/$(id -u)" "$PLIST_DST" 2>/dev/null \
    || warn "launchctl bootstrap returned non-zero (may already be loaded)"
fi

# 11. Chroma launchd plist
tmp_chroma="$(mktemp)"
sed -e "s|__HOME__|$HOME|g" "$CHROMA_PLIST_SRC" > "$tmp_chroma"
chroma_needs_bootstrap=0
if [ ! -f "$CHROMA_PLIST_DST" ]; then
  chroma_needs_bootstrap=1
  mv "$tmp_chroma" "$CHROMA_PLIST_DST"
  log "installed chroma launchd plist"
elif ! cmp -s "$tmp_chroma" "$CHROMA_PLIST_DST"; then
  mv "$tmp_chroma" "$CHROMA_PLIST_DST"
  log "refreshed chroma launchd plist (content changed)"
else
  rm -f "$tmp_chroma"
  log "chroma launchd plist already up to date"
fi
if [ "$chroma_needs_bootstrap" -eq 1 ]; then
  launchctl bootstrap "gui/$(id -u)" "$CHROMA_PLIST_DST" 2>/dev/null \
    || warn "launchctl bootstrap chroma returned non-zero (may already be loaded)"
fi

# 11a. Token-rotate launchd plist
tmp_rotate="$(mktemp)"
sed -e "s|__HOME__|$HOME|g" "$ROTATE_PLIST_SRC" > "$tmp_rotate"
rotate_needs_bootstrap=0
if [ ! -f "$ROTATE_PLIST_DST" ]; then
  rotate_needs_bootstrap=1
  mv "$tmp_rotate" "$ROTATE_PLIST_DST"
  log "installed token-rotate launchd plist"
elif ! cmp -s "$tmp_rotate" "$ROTATE_PLIST_DST"; then
  mv "$tmp_rotate" "$ROTATE_PLIST_DST"
  log "refreshed token-rotate launchd plist (content changed)"
else
  rm -f "$tmp_rotate"
  log "token-rotate launchd plist already up to date"
fi
if [ "$rotate_needs_bootstrap" -eq 1 ]; then
  launchctl bootstrap "gui/$(id -u)" "$ROTATE_PLIST_DST" 2>/dev/null \
    || warn "launchctl bootstrap token-rotate returned non-zero (may already be loaded)"
fi

# 12. Re-ingest the Chroma backstory corpus (idempotent)
if [ -x "$VENV_PY" ] && [ -f "$REPO_ROOT/scripts/ingest_memory.py" ]; then
  log "ingesting cicero-backstory.md into Chroma (idempotent)"
  # Give Chroma a moment if it just started
  for _ in 1 2 3 4 5; do
    if curl -sf --max-time 1 http://127.0.0.1:8000/api/v2/heartbeat >/dev/null; then break; fi
    sleep 1
  done
  "$VENV_PY" "$REPO_ROOT/scripts/ingest_memory.py" \
    || warn "ingest_memory.py returned non-zero — re-run manually"
fi

# 13. cicero CLI wrapper
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"
ln -sfn "$REPO_ROOT/scripts/cicero" "$LOCAL_BIN/cicero"
log "cicero -> $LOCAL_BIN/cicero"
if ! grep -q 'HOME/.local/bin' "$HOME/.zshrc" 2>/dev/null; then
  printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.zshrc"
  log "added ~/.local/bin to PATH in .zshrc"
fi

# 14. Kickstart and probe
launchctl kickstart -k "gui/$(id -u)/$PLIST_LABEL" >/dev/null 2>&1 || true
sleep 2
if nc -z 127.0.0.1 18789 2>/dev/null; then
  log "openclaw-gateway is listening on 18789"
else
  warn "gateway not responding on 18789 — check: launchctl print gui/$(id -u)/$PLIST_LABEL"
  warn "logs: tail ~/Library/Logs/openclaw-gateway.err.log"
fi

# 15. macOS permission reminders for iMessage
if command -v imsg >/dev/null 2>&1; then
  log ""
  log "iMessage channel: manual permission steps required if not already granted:"
  log "  1. System Settings > Privacy & Security > Full Disk Access — add $(command -v node) and $(command -v imsg)"
  log "  2. System Settings > Privacy & Security > Automation — allow Messages.app control (prompted on first send)"
  log ""
fi

log "done."
