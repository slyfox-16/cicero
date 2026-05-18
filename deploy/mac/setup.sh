#!/usr/bin/env bash
# Idempotent bootstrap for Cicero on a macOS box (Apple Silicon or Intel).
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
MODEL="llama3.1:8b-instruct-q5_K_M"
MODEL_REF="ollama/$MODEL"

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

# 3. Ollama (managed externally by Ollama.app)
curl -sf --max-time 3 http://127.0.0.1:11434/api/version >/dev/null \
  || die "Ollama not reachable on 127.0.0.1:11434. Install Ollama.app from https://ollama.com/download/mac and start it, then re-run."
log "ollama: $(curl -sf http://127.0.0.1:11434/api/version)"

# 4. Pull the model if missing
if ! ollama list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$MODEL"; then
  log "pulling $MODEL ..."
  ollama pull "$MODEL"
else
  log "model $MODEL already present"
fi

# 5. OpenClaw CLI
if ! command -v openclaw >/dev/null 2>&1; then
  log "installing openclaw via npm -g"
  npm install -g openclaw@latest
fi
log "openclaw: $(openclaw --version 2>&1 | head -1)"

# 6. Token: reuse the one in openclaw.json if present, else generate a fresh one
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

# 7. Onboard if openclaw.json is missing (non-interactive, local-only, no daemon)
if [ ! -f "$OPENCLAW_CONFIG" ]; then
  log "running openclaw onboard (non-interactive, local + ollama)"
  openclaw onboard \
    --non-interactive --accept-risk \
    --flow quickstart \
    --mode local \
    --auth-choice ollama \
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

# 8. Pin the agent default model, ensure token is recorded, remove skipBootstrap
python3 - "$OPENCLAW_CONFIG" "$token" "$MODEL_REF" <<'PY'
import json, sys
path, token, model_ref = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    cfg = json.load(f)
defaults = cfg.setdefault("agents", {}).setdefault("defaults", {})
defaults.setdefault("model", {})["primary"] = model_ref
defaults.pop("skipBootstrap", None)  # ensure workspace files are injected at session start
cfg.setdefault("gateway", {}).setdefault("auth", {})
cfg["gateway"]["auth"]["mode"] = "token"
cfg["gateway"]["auth"]["token"] = token
tools = cfg.setdefault("tools", {})
tools["profile"] = "coding"
tools["deny"] = ["canvas", "image_generate", "music_generate", "video_generate", "code_execution"]
# Workaround for openclaw issue #5769: Ollama streaming drops tool_calls delta chunks.
# streaming: false must live in params, not as a top-level field (issue #12217).
model_params = defaults.setdefault("models", {}).setdefault(model_ref, {}).setdefault("params", {})
model_params["streaming"] = False
with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
PY
log "openclaw.json: model -> $MODEL_REF, token synced, skipBootstrap removed, tools pruned, streaming disabled"

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

# 10. Install / refresh launchd plist (always render from template so token + paths stay in sync)
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
npm_root="$(npm root -g)"
openclaw_entry="$npm_root/openclaw/dist/index.js"
[ -f "$openclaw_entry" ] || die "openclaw entry not found at $openclaw_entry"
node_bin="$(command -v node)"

# Render the plist template into a temp file, then move into place only if changed.
tmp_plist="$(mktemp)"
sed \
  -e "s|__GENERATE_ME__|$token|g" \
  -e "s|__HOME__|$HOME|g" \
  -e "s|__NODE_BIN__|$node_bin|g" \
  -e "s|__OPENCLAW_ENTRY__|$openclaw_entry|g" \
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
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
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

log "done."
