# TOOLS.md — Local Environment Notes

Skills define _how_ tools work. This file holds environment-specific specifics — hostnames, paths, models, device names — unique to this deployment.

## Host

- **minerva** — Mac mini. Primary and only host. OpenClaw gateway at `127.0.0.1:18789` (loopback only), managed by launchd (`ai.openclaw.gateway`). Chroma vector store at `127.0.0.1:8000` (`ai.cicero.chroma`).

## Brain

Cicero runs on the Anthropic API via OpenClaw's native `@openclaw/anthropic-provider`.

| Mode | Model | Trigger |
|---|---|---|
| Default | `claude-haiku-4-5` | every message |
| Big brain | `claude-sonnet-4-6` | "big brain" anywhere in the message |
| Galaxy brain | `claude-opus-4-7` | "galaxy brain" anywhere in the message |

Escalation is handled by the `cicero-bigbrain` skill, which routes to a local MCP server (`lib/brain_mcp.py`) that calls the larger model directly. The escalated answer is delivered verbatim — no Haiku-side commentary.

API key lives in the OpenClaw credential store (`~/.openclaw/agents/main/agent/auth-profiles.json`) for the provider; the brain MCP reads it from `ANTHROPIC_API_KEY` or `~/.config/anthropic/api_key`.

## Data Sources

- **Long-term memory:** Chroma at `127.0.0.1:8000`, collection `cicero_memory`. Queried via `cicero-memory` skill → `query_cicero_memory_tool` MCP server. Seeded from `docs/archive/cicero-backstory.md`.
- **Web search:** DuckDuckGo (`duckduckgo` plugin, no API key required). Use `web_search` for the internet, `web_fetch` for specific URLs.
- **Health (pending):** Apple Health export + Heavy app → Postgres pipeline. Not yet wired. The `cicero-health` skill returns a stub until then.

Add specifics here as the environment grows.
