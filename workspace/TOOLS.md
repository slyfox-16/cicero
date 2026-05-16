# TOOLS.md — Local Environment Notes

Skills define _how_ tools work. This file holds environment-specific specifics — hostnames, paths, device names — that are unique to this deployment.

## Hosts

- **Saturn** — legacy host. Linux. Ollama at `127.0.0.1:11434`. OpenClaw gateway at `127.0.0.1:18789` (loopback only).
- **minerva** — primary Mac host. Ollama at `127.0.0.1:11434` (`deepseek-r1:14b`). OpenClaw gateway at `127.0.0.1:18789` (loopback only). Gateway managed by launchd (`ai.openclaw.gateway`).

## Data Sources (pending)

- Health: Apple Health export + Heavy app → Postgres on Saturn. Not yet wired. The `health` skill returns a stub until then.
- Long-term memory: Chroma instance on Saturn. Not yet wired. The `chroma` skill returns a stub until then.

Add specifics here as the environment grows.
