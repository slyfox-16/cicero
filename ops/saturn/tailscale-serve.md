# Saturn: Tailscale Serve (Tailnet-Only HTTPS)

Goal: expose local services bound to `127.0.0.1` over HTTPS to your tailnet only.

## OpenClaw Gateway

Assuming the gateway is listening on:

- `http://127.0.0.1:18789`

Create the Serve mapping on `saturn`:

```bash
sudo tailscale serve --bg --set-path / http://127.0.0.1:18789
sudo tailscale serve status
```

Note: `tailscale serve` often requires `sudo` because it manages system-level networking and certificates.

Discover the tailnet URL:

```bash
sudo tailscale serve status
```

It will print something like:

- `https://saturn.<tailnet>.ts.net/`

Verify from another tailnet client:

```bash
curl -I "https://saturn.<tailnet>.ts.net/" | head
```

## Security Notes

- Bind backends to `127.0.0.1`, not `0.0.0.0`.
- Tailnet-only HTTPS is not a substitute for app auth: keep OpenClaw auth tokens enabled.

