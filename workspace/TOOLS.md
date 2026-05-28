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
- **Apple Reminders:** Three shared lists owned by Carlos, all shared with `cicero.ortega@icloud.com`:
  - **Honeydew** — household tasks, errands, follow-ups. Also shared with Sarah.
  - **Groceries** — items to buy. Also shared with Sarah. Apple's built-in grocery sort handles produce/dairy/etc. categorization automatically; Cicero adds no tags.
  - **Garden** — gardening tasks. Carlos + Cicero only, **not** shared with Sarah. Never assign Garden items to Sarah.
  - Backed by `mcp-server-apple-events` (FradSer, pinned at 1.4.0, via EventKit) for create / edit / complete / list / subtask / priority / location / recurrence. **Cannot do:** assign-to-person and flags (UI-only in Apple), sections within a list (not exposed by EventKit), and tags (hashtags in EventKit-created titles render as plain text, not as Apple tag chips). Carlos and Sarah handle assignment/flagging by tapping the reminder on their phone after Cicero creates it.
- **Apple Notes:** One shared folder **Cicero**, owned by Carlos, shared with `cicero.ortega@icloud.com` and Sarah. Cicero only writes inside this folder; new notes inherit the share. Backed by `lib/notes_mcp.py` (AppleScript via `osascript`). Notes with embedded images/attachments cannot be appended to — create a follow-up note instead. Smart folders are personal (cannot be shared), so Carlos and Sarah each create their own on their phones to filter by tag.
- **Health (pending):** Apple Health export + Heavy app → Postgres pipeline. Not yet wired. The `cicero-health` skill returns a stub until then.

Add specifics here as the environment grows.
