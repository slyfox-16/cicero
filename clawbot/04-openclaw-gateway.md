# 04 - Run OpenClaw Gateway as a systemd User Service

Goal: have the OpenClaw gateway running locally on the host:

- bind to `127.0.0.1`
- listen on port `18789`
- run as a `systemd --user` service

## 0) Determine Whether OpenClaw Ships a Unit

On the host:

```bash
systemctl --user list-unit-files | grep -i openclaw || true
systemctl --user list-unit-files | rg -i 'openclaw|claw' || true
```

If you see `openclaw-gateway.service`, follow Path A.
If not, follow Path B.

## Path A) If `openclaw-gateway.service` Exists

```bash
systemctl --user enable --now openclaw-gateway.service
systemctl --user status openclaw-gateway.service --no-pager -l
journalctl --user -u openclaw-gateway.service -n 100 --no-pager
```

Verify it is listening locally:

```bash
curl -I http://127.0.0.1:18789/ | head
```

If the root path does not respond, use the troubleshooting guide to discover the correct health endpoint and confirm the port binding.

## Path B) If No Unit Exists (Use Our Template)

1) Create the systemd user directory:

```bash
mkdir -p ~/.config/systemd/user
```

2) Copy the template:

- Source: `clawbot/templates/openclaw-gateway.service`
- Destination: `~/.config/systemd/user/openclaw-gateway.service`

3) Edit `ExecStart`

You must replace the placeholder subcommand and flags.
Use these to discover the correct gateway start command:

```bash
openclaw --help | sed -n '1,120p'
openclaw help 2>/dev/null | sed -n '1,120p' || true
```

Look for something like a `gateway`/`server`/`serve` subcommand and flags for:

- host (should be `127.0.0.1`)
- port (should be `18789`)

4) Start it:

```bash
systemctl --user daemon-reload
systemctl --user enable --now openclaw-gateway.service
systemctl --user status openclaw-gateway.service --no-pager -l
journalctl --user -u openclaw-gateway.service -n 100 --no-pager
```

5) Verify local reachability:

```bash
curl -I http://127.0.0.1:18789/ | head
```

## Notes

- Do not bind the gateway to `0.0.0.0` unless you fully understand your LAN exposure. The intended flow is loopback + `tailscale serve`.
- If you need to inspect open sockets:

```bash
ss -lntp | grep 18789 || true
```

