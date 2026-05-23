# Cicero

Personal AI assistant, running as an OpenClaw agent on minerva.

Local-first. CLI-operated. No cloud inference, no web UI, no subscriptions.

---

## Running

**Interactive session (TUI):**

```bash
cicero chat
```

Opens a full terminal chat UI running against the embedded local agent. Type to converse.

**One-shot (scripting or quick queries):**

```bash
cicero ask "your message here"
```

The gateway must be running. Check with:

```bash
cicero gateway status
```

---

## Fresh Install (minerva / Mac)

```bash
git clone https://github.com/slyfox-16/cicero.git ~/cicero
cd ~/cicero
./deploy/mac/setup.sh
```

`setup.sh` is idempotent. It installs Node + OpenClaw, pulls the model, creates the workspace symlink, installs the launchd agent, and starts the gateway. Re-runnable.

If `~/.openclaw/openclaw.json` is missing (first run on a fresh machine), the script will stop and prompt you to run `openclaw onboard` once, then re-run.

---

## How It Works

OpenClaw reads `workspace/` at session start and injects `SOUL.md`, `AGENTS.md`, `IDENTITY.md`, and `USER.md` into the system prompt. The workspace is symlinked from `~/.openclaw/workspace` to `~/cicero/workspace`, so the repo is the source of truth — edits are live immediately.

The model is `qwen3:8b` running locally via Ollama (fallback: `llama3.1:8b-instruct-q5_K_M`). Skills live in `workspace/skills/` and are auto-discovered.

---

## Docs

- [Architecture](docs/architecture.md) — decisions, current design
- [Security](docs/security.md) — operational discipline for running LLMs locally
- [Roadmap](docs/roadmap.md) — health data, memory, proactive agents, upcoming work
- [Scope](docs/scope.md) — what Cicero is and is not
