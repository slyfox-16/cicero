# Cicero

Personal AI assistant, running as an OpenClaw agent on minerva. Inference via the Anthropic API (Haiku 4.5 default, Sonnet 4.6 and Opus 4.7 on demand).

iMessage-first. CLI for development. No web UI.

---

## Running

**Interactive session (TUI):**

```bash
cicero chat
```

**One-shot:**

```bash
cicero ask "your message here"
```

Requires the gateway. Check with `cicero gateway status`, restart with `cicero gateway restart`.

**iMessage:** Message `cicero.ortega@icloud.com` from an allowlisted account. Cicero replies in the same conversation.

---

## Brain modes

Cicero defaults to Haiku 4.5. Two larger models are reachable per-message by including a trigger phrase anywhere in the message:

| Mode | Model | Trigger |
|---|---|---|
| Default | `claude-haiku-4-5` | (none — every message) |
| Big brain | `claude-sonnet-4-6` | `big brain` |
| Galaxy brain | `claude-opus-4-7` | `galaxy brain` |

Examples:

- `big brain: explain the gold standard collapse`
- `summarize this thread, galaxy brain`
- `(big brain) what's the difference between MMT and Austrian economics`

The escalation runs as an MCP tool; Cicero delivers the larger model's answer verbatim. Per-call spend is logged to `~/Library/Logs/cicero-brain.log`.

---

## Fresh install (minerva / Mac)

```bash
git clone https://github.com/slyfox-16/cicero.git ~/cicero
cd ~/cicero
./deploy/mac/setup.sh
```

`setup.sh` is idempotent. It installs Node + OpenClaw + the Anthropic Python SDK, registers the Anthropic provider with your API key, creates the workspace symlink, registers the MCP servers, and installs the launchd units. Re-runnable.

You will need:
- An Anthropic API key in `~/.config/anthropic/api_key` (mode 0600) or the `ANTHROPIC_API_KEY` env var.
- Full Disk Access granted to `node` and `imsg` for iMessage delivery (one-time, in System Settings → Privacy & Security).

---

## How it works

OpenClaw reads `workspace/` at session start and injects `SOUL.md`, `AGENTS.md`, `IDENTITY.md`, `USER.md`, and `TOOLS.md` into the system prompt. The workspace is symlinked from `~/.openclaw/workspace` to `~/cicero/workspace`, so the repo is the source of truth — edits are live.

Inference goes through OpenClaw's native `@openclaw/anthropic-provider`. Skills (`workspace/skills/`) are auto-discovered. Cicero's long-term memory is a local Chroma vector store seeded from `docs/archive/cicero-backstory.md` and queried via the `cicero-memory` MCP tool.

---

## Docs

- [Architecture](docs/architecture.md) — current design
- [Operations](docs/operations.md) — runbook for minerva
- [Decisions](docs/decisions.md) — ADRs
- [Security](docs/security.md) — operational discipline for an API-backed personal agent
- [Roadmap](docs/roadmap.md) — what comes next
- [Scope](docs/scope.md) — what Cicero is and is not
