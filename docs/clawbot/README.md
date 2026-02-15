# Clawbot For Cicero (No Siri)

This folder contains **copy/paste runnable** setup docs for running **Clawbot** as part of the Cicero project:

- Local LLM via **Ollama** (persona model: `cicero-clawbot:latest`)
- Remote/control surface via **OpenClaw**
- Tailnet-only HTTPS exposure via **Tailscale Serve**

Out of scope (for now):

- Siri / iOS Shortcuts integration
- Any separate FastAPI "bridge" service

## Threat Model (Baseline)

- **Tailnet-only**: services should not be publicly reachable from the internet.
- **Auth required**: OpenClaw endpoints that execute tools require a bearer token.
- **Local binding**: bind OpenClaw to `127.0.0.1` and only expose it through `tailscale serve`.
- **No secrets in git**: do not commit tokens, Modelfiles containing private info, or config dumps.

## Quickstart (Happy Path)

1. Prereqs: `docs/clawbot/01-prereqs.md`
2. Create persona model: `docs/clawbot/02-ollama-persona-model.md`
3. Install OpenClaw: `docs/clawbot/03-openclaw-install.md`
4. Run gateway as systemd user service: `docs/clawbot/04-openclaw-gateway.md`
5. Expose via Tailscale Serve: `ops/saturn/tailscale-serve.md`
6. Rotate/manage tokens: `docs/clawbot/06-auth-token-rotation.md`
7. Troubleshoot: `docs/clawbot/07-troubleshooting.md`

## Quick Verify Commands

On the host:

```bash
curl -sS http://127.0.0.1:11434/api/tags | head
bin/ollama list | grep -i cicero-clawbot
bin/openclaw status
curl -I http://127.0.0.1:18789/ | head
```

From a client on the same tailnet:

```bash
sudo tailscale serve status
curl -I "https://saturn.<tailnet>.ts.net/" | head
```
