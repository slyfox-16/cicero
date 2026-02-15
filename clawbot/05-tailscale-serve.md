# 05 - Expose OpenClaw via Tailscale Serve (Tailnet-Only HTTPS)

Goal: expose the local OpenClaw gateway (`127.0.0.1:18789`) over HTTPS to your tailnet only.

## 1) Create a Serve Mapping

On the host:

```bash
sudo tailscale serve --bg --set-path / http://127.0.0.1:18789
sudo tailscale serve status
```

Note: `tailscale serve` often requires `sudo` because it manages system-level networking and certificates.

## 2) Discover the Public Tailnet URL

Run:

```bash
sudo tailscale serve status
```

Use the hostname it prints (example format):

- `https://saturn.<tailnet>.ts.net/`

## 3) Verify From a Client

On `jupiter` (or any tailnet client):

```bash
curl -I "https://saturn.<tailnet>.ts.net/" | head
```

If you get a 200/302, the HTTPS front door is working.
If you get an error, see `clawbot/07-troubleshooting.md`.

## Security Note

Tailscale Serve restricts access to your tailnet, but you still must use OpenClaw auth tokens for any endpoints that execute tools.

