# 01 - Prereqs

This guide targets the setup you described:

- Host: `saturn` (Ubuntu/Linux, systemd available)
- Client: `jupiter` (macOS or Linux)
- Network: Tailscale tailnet-only access

Replace these variables to match your environment:

```bash
HOSTNAME="saturn"
OLLAMA_URL="http://127.0.0.1:11434"
OPENCLOW_LOCAL="http://127.0.0.1:18789"
```

## 0) Assumptions

- You can SSH into the host.
- Ollama is installed on the host and listening on `127.0.0.1:11434`.
- Tailscale is installed on the host and the client, and both are logged into the same tailnet.
- You will expose OpenClaw via `tailscale serve` (typically requires `sudo`).

## 1) Verify Ollama

On the host:

```bash
curl -sS http://127.0.0.1:11434/api/tags | head
ollama list
```

If those fail, fix Ollama first before continuing.

## 2) Verify Tailscale

On the host:

```bash
tailscale status
tailscale ip -4
```

On the client:

```bash
tailscale status
```

## 3) Install/Verify Node.js (for OpenClaw)

We used NodeSource to install Node 22 on Ubuntu:

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs
node -v
npm -v
```

Expected:

- Node: `v22.x`
- npm: `10.x+`

## 4) (Optional) Install ripgrep

Some commands in later docs use `rg` for convenience. If you don't have it:

```bash
sudo apt-get update
sudo apt-get install -y ripgrep
```

Everything can be done with `grep` if you prefer.

