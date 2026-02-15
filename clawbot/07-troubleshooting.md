# 07 - Troubleshooting

## Check the OpenClaw Gateway Service

On the host:

```bash
systemctl --user status openclaw-gateway.service --no-pager -l
journalctl --user -u openclaw-gateway.service -n 200 --no-pager
```

## Check Whether the Gateway Is Listening

```bash
curl -I http://127.0.0.1:18789/ | head
ss -lntp | grep 18789 || true
```

Common failures:

- Port already in use: change the gateway port or stop the conflicting service.
- Not bound to loopback: ensure it binds to `127.0.0.1` (not `0.0.0.0`).
- PATH issues under systemd: use an absolute `openclaw` path or `/usr/bin/env openclaw` in `ExecStart`.

## Check Tailscale Serve

On the host:

```bash
sudo tailscale serve status
```

Common failures:

- Path mismatch: you served `/` but are requesting another path (or vice versa).
- Service down behind Serve: Serve is up but OpenClaw is not responding on `127.0.0.1:18789`.

## Check Ollama

On the host:

```bash
curl -sS http://127.0.0.1:11434/api/tags | head
ollama list
```

Common failures:

- Ollama not running: start/restart it (how depends on how you installed it).
- Wrong bind address: ensure Ollama is reachable at `127.0.0.1:11434`.

## Auth / 401 Errors

If you get 401 from OpenClaw:

- confirm you are sending `Authorization: Bearer ...`
- confirm the token matches `gateway.auth.token` in `~/.openclaw/openclaw.json`
- if you rotated the token, restart the gateway service

## npm / Node Issues

If `sudo npm install -g openclaw@latest` fails:

- verify Node 22 is installed: `node -v`
- check npm version: `npm -v`
- if you previously installed via a different method (nvm/asdf), PATH may be confusing under sudo/systemd

