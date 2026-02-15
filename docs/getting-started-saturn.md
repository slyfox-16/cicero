# Getting Started on `saturn` (Happy Path)

This is the minimal end-to-end flow to get the Clawbot control surface running on `saturn`.

Assumptions:

- Ubuntu/Linux with systemd
- Tailscale installed and logged in
- Repo checked out at `"$HOME/cicero"`

## 1) Install Repo-Local OpenClaw

```bash
cd ~/cicero
npm --prefix tools/openclaw install
bin/openclaw --version
```

## 2) Install Ollama

Two supported paths:

1) System install (already running on `127.0.0.1:11434`)
2) Repo-local binary at `tools/ollama/bin/ollama` (see `tools/ollama/README.md`)

Verify:

```bash
curl -sS http://127.0.0.1:11434/api/tags | head
bin/ollama list
```

## 3) Build the Persona Model

```bash
pipelines/ollama/scripts/build-persona.sh
```

## 4) Start the OpenClaw Gateway (systemd user service)

Install the unit template:

```bash
mkdir -p ~/.config/systemd/user
cp -v ops/saturn/systemd/cicero-openclaw-gateway.service ~/.config/systemd/user/
systemctl --user daemon-reload
```

Edit `ExecStart` in the unit so it starts the gateway bound to `127.0.0.1:18789`:

```bash
$EDITOR ~/.config/systemd/user/cicero-openclaw-gateway.service
```

Start:

```bash
systemctl --user enable --now cicero-openclaw-gateway.service
systemctl --user status cicero-openclaw-gateway.service --no-pager -l
curl -I http://127.0.0.1:18789/ | head
```

## 5) Expose Over Tailnet HTTPS

```bash
sudo tailscale serve --bg --set-path / http://127.0.0.1:18789
sudo tailscale serve status
```

Full guide:

- `ops/saturn/tailscale-serve.md`

## 6) Rotate Token + Verify Auth

- `docs/clawbot/06-auth-token-rotation.md`

