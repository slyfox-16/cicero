# Scope

## What Cicero is

Cicero is a personal AI assistant running as an OpenClaw agent on minerva.

- A configured agent, not a platform. OpenClaw is the platform; this repo holds workspace, skills, and deploy scripts.
- Hosted inference, local data plane. The brain (Haiku 4.5, with Sonnet 4.6 and Opus 4.7 on demand) runs on the Anthropic API. Memory, skill execution, session state, channel state, and logs stay on minerva.
- iMessage-first. CLI for development.
- Single-user. One operator: Carlos.

## In scope

- Cicero's personality, voice, and behavioral rules (`workspace/`).
- Skill definitions, current and future (`workspace/skills/`).
- MCP servers and retrieval libraries (`lib/`).
- Deploy and service configuration for minerva (`deploy/`, `scripts/`).
- Architecture, security, operations, and roadmap docs (`docs/`).

## Out of scope

- A web UI.
- A custom inference runtime. OpenClaw + Anthropic API handle inference.
- Multi-user access.
- Public deployment. The gateway is loopback-bound; the iMessage allowlist gates inbound. Exposing either is out of scope.
- Self-hosted models. Tried; persona and tool-call quality were inadequate. See `docs/decisions.md`.

## Interfaces

- **Primary:** iMessage at `cicero.ortega@icloud.com`. Allowlist-gated.
- **Dev:** `cicero chat` (embedded TUI) and `cicero ask "<text>"` (one-shot via gateway).
