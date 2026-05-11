# Scope

## What Cicero Is

Cicero is a personal AI assistant running as an OpenClaw agent on Saturn. It is:

- A configured agent, not a platform. OpenClaw is the platform. This repo holds the workspace, skills, and deploy scripts.
- Local-first. Inference runs on Saturn's GPU via Ollama. No data leaves the machine except over localhost.
- CLI-operated. The interface is `openclaw agent --agent main --message "..."`. No web UI.
- Passive. No proactive outreach, no scheduled tasks, no channel subscriptions — yet.

## In Scope

- Cicero's personality, behavioral rules, and workspace configuration (`workspace/`).
- Skill definitions, current and future (`workspace/skills/`).
- Deploy scripts and service configuration for Saturn and (eventually) Mac (`deploy/`).
- Architecture, security, and roadmap documentation (`docs/`).

## Out of Scope

- A web UI. There is no `/` or `/chat` endpoint. There will not be one unless OpenClaw's Control UI satisfies that need.
- A custom inference engine. OpenClaw + Ollama handle inference.
- Multi-user access. Cicero is a personal assistant for one person.
- Public deployment. The gateway is bound to loopback. Exposing it publicly is out of scope and discouraged.

## Interfaces

One: `openclaw agent --agent main --message "<text>"`.

In the future: iMessage via the Mac mini migration (see `docs/roadmap.md`).
