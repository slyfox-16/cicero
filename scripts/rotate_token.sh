#!/usr/bin/env bash
# Rotate the OpenClaw gateway token.
#
# Updates openclaw.json and re-renders the gateway launchd plist, then
# restarts the gateway. Safe to re-run. Run as the Cicero user (not root).
#
# Called automatically by ai.cicero.token-rotate launchd job every 6 months.
# Can also be run manually:
#   bash ~/cicero/scripts/rotate_token.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLIST_SRC="$REPO_ROOT/deploy/mac/ai.openclaw.gateway.plist"
PLIST_DST="$HOME/Library/LaunchAgents/ai.openclaw.gateway.plist"
PLIST_LABEL="ai.openclaw.gateway"
OPENCLAW_CONFIG="$HOME/.openclaw/openclaw.json"
LOG="$HOME/Library/Logs/cicero-token-rotate.log"

log() { printf '[%s] %s\n' "$(date -u +%FT%TZ)" "$*" | tee -a "$LOG"; }

log "starting gateway token rotation"

[ -f "$OPENCLAW_CONFIG" ] || { log "ERROR: $OPENCLAW_CONFIG not found"; exit 1; }
[ -f "$PLIST_SRC" ]      || { log "ERROR: $PLIST_SRC not found"; exit 1; }

# Generate new token
new_token="$(openssl rand -hex 24 2>/dev/null || head -c 48 /dev/urandom | xxd -p -c 48)"
[ -n "$new_token" ] || { log "ERROR: failed to generate token"; exit 1; }

# Update openclaw.json
python3 - "$OPENCLAW_CONFIG" "$new_token" <<'PY'
import json, sys
path, token = sys.argv[1], sys.argv[2]
with open(path) as f:
    cfg = json.load(f)
cfg.setdefault("gateway", {}).setdefault("auth", {})
cfg["gateway"]["auth"]["token"] = token
with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
PY
log "openclaw.json updated"

# Re-render the gateway plist from template
node_bin="$(command -v node)"
npm_root="$(npm root -g)"
openclaw_entry="$npm_root/openclaw/dist/index.js"
[ -f "$openclaw_entry" ] || { log "ERROR: openclaw entry not found at $openclaw_entry"; exit 1; }

tmp_plist="$(mktemp)"
sed \
  -e "s|__GENERATE_ME__|$new_token|g" \
  -e "s|__HOME__|$HOME|g" \
  -e "s|__NODE_BIN__|$node_bin|g" \
  -e "s|__OPENCLAW_ENTRY__|$openclaw_entry|g" \
  "$PLIST_SRC" > "$tmp_plist"
mv "$tmp_plist" "$PLIST_DST"
log "gateway plist updated"

# Restart the gateway
launchctl kickstart -k "gui/$(id -u)/$PLIST_LABEL" >/dev/null 2>&1 || true
sleep 2
if nc -z 127.0.0.1 18789 2>/dev/null; then
  log "gateway restarted successfully and is listening on 18789"
else
  log "WARNING: gateway not responding on 18789 after restart — check $HOME/Library/Logs/openclaw-gateway.err.log"
fi

log "token rotation complete"
