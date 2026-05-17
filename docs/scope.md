# Scope

## What Cicero Is

Cicero is a personal AI assistant running as an OpenClaw agent on Minerva. It is:

- A configured agent, not a platform. OpenClaw is the platform. This repo holds the workspace, skills, and deploy scripts.
- Local-first. Inference runs on Minerva via Ollama (MLX backend, Apple Silicon). No data leaves the machine.
- CLI-operated. The interfaces are `cicero chat` (embedded TUI) and `cicero ask "<text>"` (one-shot via gateway).
- Passive. No proactive outreach, no scheduled tasks, no channel subscriptions — yet.

## In Scope

- Cicero's personality, behavioral rules, and workspace configuration (`workspace/`).
- Skill definitions, current and future (`workspace/skills/`).
- Deploy scripts and service configuration for Minerva (`deploy/`).
- Architecture, security, and roadmap documentation (`docs/`).

## Out of Scope

- A web UI. There is no `/` or `/chat` endpoint.
- A custom inference engine. OpenClaw + Ollama handle inference.
- Multi-user access. Cicero is a personal assistant for one person.
- Public deployment. The gateway is bound to loopback. Exposing it publicly is out of scope and discouraged.

## Interfaces

Two: `cicero chat` (embedded TUI, no gateway required) and `cicero ask "<text>"` (one-shot via gateway on `ws://127.0.0.1:18789`).

In the future: iMessage via the Mac mini migration (see `docs/roadmap.md`). Deferred until Minerva is replaced.
