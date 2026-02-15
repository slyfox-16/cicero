# Saturn Ops (systemd)

This folder contains **deployment/operations** docs and templates for running Cicero components on the `saturn` host.

Assumptions:

- OS: Ubuntu/Linux with systemd
- Repo location: `"$HOME/cicero"`
- Services run as **systemd user services** (`systemctl --user ...`)

## Install Repo-Local OpenClaw

From `~/cicero`:

```bash
npm --prefix tools/openclaw install
bin/openclaw --version
```

## Ollama

You have two supported paths:

1) System-level Ollama (already installed and listening on `127.0.0.1:11434`)
2) Repo-local Ollama binary at `tools/ollama/bin/ollama` (see `tools/ollama/README.md`)

Verify:

```bash
curl -sS http://127.0.0.1:11434/api/tags | head
bin/ollama list
```

## Build Persona Model

```bash
pipelines/ollama/scripts/build-persona.sh
```

## systemd User Services

Install unit templates:

```bash
mkdir -p ~/.config/systemd/user
cp -v ops/saturn/systemd/cicero-openclaw-gateway.service ~/.config/systemd/user/
# Optional:
# cp -v ops/saturn/systemd/cicero-ollama.service ~/.config/systemd/user/
systemctl --user daemon-reload
```

Edit the gateway unit and set the correct `ExecStart` subcommand/flags:

```bash
$EDITOR ~/.config/systemd/user/cicero-openclaw-gateway.service
```

Start and inspect:

```bash
systemctl --user enable --now cicero-openclaw-gateway.service
systemctl --user status cicero-openclaw-gateway.service --no-pager -l
journalctl --user -u cicero-openclaw-gateway.service -n 200 --no-pager
curl -I http://127.0.0.1:18789/ | head
```

## Tailnet HTTPS Front Door

See:

- `ops/saturn/tailscale-serve.md`

## Token Rotation

OpenClaw auth token docs:

- `docs/clawbot/06-auth-token-rotation.md`

