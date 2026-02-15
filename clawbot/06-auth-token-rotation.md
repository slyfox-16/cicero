# 06 - OpenClaw Auth Token Rotation (Hygiene)

OpenClaw uses an auth token for sensitive endpoints (for example tool execution).

## 0) Where the Token Lives

On the host, token config typically lives at:

- `~/.openclaw/openclaw.json`

In your prior setup, the key was:

- `gateway.auth.token`

Treat this token like a password:

- do not commit it
- store it in your password manager
- rotate it if it leaks

## 1) Rotate the Token

On the host:

```bash
NEW_TOKEN="$(openssl rand -hex 32)"
openclaw config set gateway.auth.token "$NEW_TOKEN"
systemctl --user restart openclaw-gateway.service
```

Set it in your shell for testing:

```bash
export OC_TOKEN="$NEW_TOKEN"
```

## 2) Verify Authenticated Invocation Over Tailnet

From a client on the tailnet:

```bash
export OC_TOKEN="PASTE_TOKEN_HERE"

curl -sS "https://saturn.<tailnet>.ts.net/tools/invoke" \
  -H "Authorization: Bearer $OC_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"tool":"sessions_list","args":{}}' | head
```

If this fails:

- confirm the serve mapping (`sudo tailscale serve status`)
- confirm the gateway is up locally (`curl -I http://127.0.0.1:18789/ | head`)
- check gateway logs (`journalctl --user -u openclaw-gateway.service -n 200 --no-pager`)

