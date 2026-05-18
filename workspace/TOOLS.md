# TOOLS.md — Local Environment Notes

Skills define _how_ tools work. This file holds environment-specific specifics — hostnames, paths, device names — that are unique to this deployment.

## Hosts

- **Saturn** — legacy host. Linux. Ollama at `127.0.0.1:11434`. OpenClaw gateway at `127.0.0.1:18789` (loopback only).
- **minerva** — primary Mac host. Ollama at `127.0.0.1:11434` (`qwen3:8b` primary, `llama3.1:8b-instruct-q5_K_M` fallback, tool-capable). OpenClaw gateway at `127.0.0.1:18789` (loopback only). Gateway managed by launchd (`ai.openclaw.gateway`). Chroma vector store at `127.0.0.1:8000` (`ai.cicero.chroma`).

## Data Sources

- **Long-term memory:** Chroma at `127.0.0.1:8000`, collection `cicero_memory`. Queried via `cicero-memory` skill → `query_cicero_memory_tool` MCP server. Seeded from `docs/cicero-backstory.md`.
- **Web search:** DuckDuckGo (`duckduckgo` plugin, no API key required). Enabled in OpenClaw. Use `web_search` to search the internet; use `web_fetch` to retrieve specific URLs.
- **Health (pending):** Apple Health export + Heavy app → Postgres on Saturn. Not yet wired. The `cicero-health` skill returns a stub until then.

Add specifics here as the environment grows.
