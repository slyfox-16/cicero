#!/usr/bin/env bash
# Idempotent bootstrap for Cicero on a Saturn-like Linux box.
#
#   ./deploy/saturn/setup.sh
#
# Re-runnable. Skips steps already done. Does not rotate the gateway token on
# subsequent runs (delete ~/.config/systemd/user/openclaw-gateway.service to
# force a fresh token).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORKSPACE="$REPO_ROOT/workspace"
UNIT_SRC="$REPO_ROOT/deploy/saturn/openclaw-gateway.service"
UNIT_DST="$HOME/.config/systemd/user/openclaw-gateway.service"
OPENCLAW_CONFIG="$HOME/.openclaw/openclaw.json"
WORKSPACE_LINK="$HOME/.openclaw/workspace"
MODEL="qwen3:8b"

log() { printf '[setup] %s\n' "$*"; }
warn() { printf '[setup] WARN: %s\n' "$*" >&2; }
die() { printf '[setup] ERROR: %s\n' "$*" >&2; exit 1; }

# 1. Ollama
if ! command -v ollama >/dev/null 2>&1; then
  warn "ollama not installed. Install from https://ollama.com/download and re-run."
  exit 1
fi
log "ollama: $(ollama --version 2>&1 | head -1)"

# 2. Pull the model if missing
if ! ollama list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$MODEL"; then
  log "pulling $MODEL ..."
  ollama pull "$MODEL"
else
  log "model $MODEL already present"
fi

# 3. OpenClaw CLI
if ! command -v openclaw >/dev/null 2>&1; then
  if command -v npm >/dev/null 2>&1; then
    log "installing openclaw via npm (may require sudo)"
    sudo npm install -g openclaw@latest
  else
    die "openclaw not installed and npm not found. Install Node.js + npm, then re-run."
  fi
fi
log "openclaw: $(openclaw --version 2>&1 | head -1)"

# 4. Ensure ~/.openclaw exists and the workspace symlink points at the repo
mkdir -p "$HOME/.openclaw"
if [ -L "$WORKSPACE_LINK" ]; then
  current="$(readlink "$WORKSPACE_LINK")"
  if [ "$current" != "$WORKSPACE" ]; then
    log "repointing workspace symlink ($current -> $WORKSPACE)"
    ln -sfn "$WORKSPACE" "$WORKSPACE_LINK"
  else
    log "workspace symlink already correct"
  fi
elif [ -e "$WORKSPACE_LINK" ]; then
  backup="$WORKSPACE_LINK.pre-cicero-$(date +%s)"
  warn "existing $WORKSPACE_LINK is not a symlink; moving to $backup"
  mv "$WORKSPACE_LINK" "$backup"
  ln -sfn "$WORKSPACE" "$WORKSPACE_LINK"
else
  ln -sfn "$WORKSPACE" "$WORKSPACE_LINK"
fi
log "workspace -> $(readlink "$WORKSPACE_LINK")"

# 5. Systemd unit (only install if missing — preserves existing token on re-runs)
mkdir -p "$(dirname "$UNIT_DST")"
if [ ! -f "$UNIT_DST" ]; then
  token="$(openssl rand -hex 24 2>/dev/null || head -c 48 /dev/urandom | xxd -p -c 48)"
  if [ -z "$token" ]; then
    die "failed to generate gateway token (need openssl or xxd)"
  fi
  log "installing systemd unit with fresh gateway token"
  sed "s|__GENERATE_ME__|$token|" "$UNIT_SRC" > "$UNIT_DST"
  systemctl --user daemon-reload

  # Sync the token into openclaw.json so the CLI auth matches the gateway.
  if [ -f "$OPENCLAW_CONFIG" ]; then
    python3 - "$OPENCLAW_CONFIG" "$token" <<'PY'
import json, sys
path, token = sys.argv[1], sys.argv[2]
with open(path) as f:
    cfg = json.load(f)
cfg.setdefault("gateway", {}).setdefault("auth", {})["mode"] = "token"
cfg["gateway"]["auth"]["token"] = token
with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
PY
    log "synced token into $OPENCLAW_CONFIG"
  else
    warn "$OPENCLAW_CONFIG not found. Run \`openclaw onboard\` once before the gateway will work."
  fi
else
  log "systemd unit already installed (leaving token alone)"
fi

# 6. Install cicero CLI wrapper
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"
ln -sfn "$REPO_ROOT/scripts/cicero" "$LOCAL_BIN/cicero"
log "cicero -> $LOCAL_BIN/cicero"
# Add ~/.local/bin to PATH in .bashrc if not already there
if ! grep -q 'HOME/.local/bin' "$HOME/.bashrc" 2>/dev/null; then
  printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.bashrc"
  log "added ~/.local/bin to PATH in .bashrc"
fi

# 7. Enable + start
systemctl --user enable --now openclaw-gateway >/dev/null
sleep 2
if systemctl --user is-active --quiet openclaw-gateway; then
  log "openclaw-gateway is active"
else
  warn "openclaw-gateway is not active — check: systemctl --user status openclaw-gateway"
fi

log "done."
