# Cicero

Personal AI assistant, running as an OpenClaw agent on Saturn.

Local-first. CLI-operated. No cloud inference, no web UI, no subscriptions.

---

## Running

```bash
openclaw agent --agent main --message "your message here"
```

The gateway must be running. Check with:

```bash
systemctl --user status openclaw-gateway
```

---

## Fresh Install (Saturn)

```bash
git clone https://github.com/slyfox-16/cicero.git ~/cicero
cd ~/cicero
./deploy/saturn/setup.sh
```

`setup.sh` is idempotent. It installs dependencies, pulls the model, creates the workspace symlink, installs the systemd unit, and starts the gateway. Re-runnable.

---

## How It Works

OpenClaw reads `workspace/` at session start and injects `SOUL.md`, `AGENTS.md`, `IDENTITY.md`, and `USER.md` into the system prompt. The workspace is symlinked from `~/.openclaw/workspace` to `~/cicero/workspace`, so the repo is the source of truth — edits are live immediately.

The model is `qwen3:8b` running locally via Ollama. Skills live in `workspace/skills/` and are auto-discovered.

---

## Docs

- [Architecture](docs/architecture.md) — decisions, current design, Saturn → Mac migration plan
- [Security](docs/security.md) — operational discipline for running LLMs locally
- [Roadmap](docs/roadmap.md) — health data, Chroma memory, proactive agents, Mac migration
- [Scope](docs/scope.md) — what Cicero is and is not
