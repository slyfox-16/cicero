# CLAUDE.md — Cicero Repo

This repo is Cicero's configuration — personality, workspace files, skills, deploy scripts, and the MCP servers that back them. It is not Cicero itself. The runtime is OpenClaw on minerva, with inference served by the Anthropic API via OpenClaw's native `@openclaw/anthropic-provider`. Edits here are live (workspace is symlinked into the running agent).

**Primary channel:** iMessage at `cicero.ortega@icloud.com`. CLI (`cicero chat` / `cicero ask`) is for development.

---

## What this repo contains

```
cicero/
├── .env                    API keys (gitignored). ANTHROPIC_API_KEY=sk-ant-...
├── pyproject.toml          Python deps (uv-managed). Run: uv sync
├── .venv/                  [gitignored] Repo-local Python venv.
├── workspace/              Live files — symlinked to ~/.openclaw/workspace
│   ├── SOUL.md             Voice and behavioral rules.
│   ├── IDENTITY.md         Cicero/Edmund Hargreaves — short factual block.
│   ├── AGENTS.md           Workspace conventions, memory rules, red lines.
│   ├── USER.md             Context about Carlos.
│   ├── TOOLS.md            Environment specifics — host, brain models, data sources.
│   ├── HEARTBEAT.md        Periodic task checklist (passive — empty by design).
│   └── skills/             Workspace-level skills, auto-discovered by OpenClaw.
│       ├── cicero-memory/    → query_cicero_memory_tool (Chroma)
│       ├── cicero-bigbrain/  → big_brain (Sonnet 4.6) + galaxy_brain (Opus 4.7)
│       ├── cicero-reminders/ → apple-reminders MCP (FradSer, via EventKit)
│       ├── cicero-notes/     → notes_mcp.py (AppleScript wrapper for shared Cicero folder)
│       └── cicero-health/    Stub. Postgres pipeline pending.
├── lib/                    MCP servers + Python libs.
│   ├── memory_query.py     Semantic retrieval over Chroma.
│   ├── memory_mcp.py       MCP exposing query_cicero_memory_tool.
│   ├── brain_mcp.py        MCP exposing big_brain + galaxy_brain (Anthropic SDK).
│   ├── notes_mcp.py        MCP exposing list/get/create/append for Apple Notes via AppleScript.
│   └── retrieval_middleware.py  Auto-inject memory context into `cicero ask`.
├── data/                   [gitignored] Chroma vector store.
├── deploy/mac/
│   ├── setup.sh                       Idempotent Mac installer.
│   ├── ai.openclaw.gateway.plist      launchd unit template (token + API key templated).
│   ├── ai.cicero.chroma.plist         launchd unit for the Chroma server.
│   └── ai.cicero.token-rotate.plist   Scheduled gateway token rotation.
├── scripts/
│   ├── cicero                          CLI wrapper: chat / ask / gateway
│   ├── ingest_memory.py                Idempotent ingestion of cicero-backstory.md → Chroma.
│   └── rotate_token.sh                 Manual gateway token rotation.
└── docs/
    ├── architecture.md   Current architecture and repo layout.
    ├── decisions.md      ADRs.
    ├── operations.md     Runbook for minerva.
    ├── roadmap.md        Upcoming workstreams.
    ├── security.md       Operational discipline.
    ├── scope.md          What Cicero is and is not.
    └── archive/
        ├── cicero-backstory.md  Seed corpus for cicero-memory.
        └── persona.md           Historical ADR (reopened with Claude).
```

---

## Running Cicero

```bash
cicero chat          # TUI session
cicero ask "..."     # One-shot via gateway
```

**Restart the gateway after:**
- `openclaw.json` changes (including MCP registrations).
- **Any edits to `workspace/skills/*/SKILL.md` or new skill directories.** OpenClaw caches skill discovery at gateway level; the "workspace edits are live per-session" rule covers the prompt-injected files (`SOUL.md`, `AGENTS.md`, `USER.md`, `TOOLS.md`, `IDENTITY.md`) but not skill prose. If Cicero ignores a freshly-edited SKILL rule, restart before debugging further.

```bash
cicero gateway restart       # graceful; expects gateway already up
launchctl kickstart -k "gui/$(id -u)/ai.openclaw.gateway"   # force-restart from launchd; use if gateway is down or wedged
```

---

## Working in this repo (lessons earned)

These are not theoretical principles. Each cost an avoidable round-trip and is here so the next session doesn't repeat the same mistake.

1. **Validate the load-bearing capability with the smallest possible test before building scaffolding.** If a feature depends on "Apple exposes X" or "the MCP returns Y," prove it with one tool call or one `cicero ask` *before* writing the Python wrapper, the skill file, and the setup-script registration. Tearing out an MCP+skill+docs trio is expensive; checking a capability is cheap.

2. **For macOS UI walkthroughs (Shortcuts, System Settings, Reminders.app), have Carlos enumerate what he sees before authoring the steps.** Apple's UI varies enough across macOS versions that detailed click-by-click instructions written from web articles will be wrong. Ask "open Shortcuts.app, click +, search 'reminder', tell me the action names you see" — then write the walkthrough around what's actually there.

3. **Vendor docs and blog snippets are not tested behavior.** Especially around Apple integrations: hashtag parsing, smart-folder sharing, EventKit field exposure are all places where the public docs and the actual programmatic behavior diverge. Run a smoke test on minerva before designing a feature around an assumed capability.

4. **Verify the exact names of pre-existing things rather than assuming.** Reminders list names, Notes folder names, Contact display names — all human-set strings that don't match your guess. Ask Carlos, or have Cicero enumerate (`reminders_lists`, `list_notes`), before writing the first line of code that references them.

5. **Research community + vendor + GitHub before designing a new integration.** Apple Community forums, the relevant MCP server's GitHub issues, Reddit, and search results for "EventKit / AppleScript / Shortcuts + the capability you want." Ten minutes here surfaces known limitations and existing patterns before you spend an hour designing around capabilities that don't exist.

6. **Match caution to reversibility.** On minerva (Carlos's own machine, idempotent setup script, local launchd), running `./deploy/mac/setup.sh` and `launchctl kickstart` is zero-blast-radius — just do it. Reserve "ask before acting" for things that hit shared state (git push, gh pr, modifying the Anthropic console, deleting data). Carlos has explicit feedback on this: don't make him ask you to deploy on his own dev box.

7. **Verify per claim, not per batch.** After each piece of a multi-part change, run one `cicero ask` smoke test that exercises it. Don't claim a feature works until you've actually seen it work end-to-end (read AND write paths). A single bug surfacing across three rounds of user corrections is three rounds you should have caught yourself with three 30-second tests.

---

## Developer guide

### Editing personality / behavior

Files in `workspace/` are read at session start and injected into the system prompt. Edits to `workspace/` are live per-session. `openclaw.json` changes need a gateway restart.

| File | Edit when |
|---|---|
| `SOUL.md` | Changing voice, tone, behavioral rules |
| `IDENTITY.md` | Changing the factual backstory block, name, avatar |
| `USER.md` | Updating context about Carlos |
| `TOOLS.md` | Adding a host, brain model, or data source |
| `AGENTS.md` | Changing workspace conventions or memory rules |

**SOUL.md authoring rules** (unchanged from prior era):
- Descriptive, not imperative. Natural prose. No "CRITICAL RULE", no "never reveal training".
- The identity line that works: `You are Cicero — a personal AI assistant. That is your name and your identity.`

### Changing the default brain model

The default brain is set in `~/.openclaw/openclaw.json` under `agents.defaults.model.primary` (currently `anthropic/claude-haiku-4-5`).

1. Pick the new model from `openclaw models list | grep anthropic`.
2. `openclaw config set agents.defaults.model.primary anthropic/<model-id>`.
3. Update `workspace/TOOLS.md` brain table.
4. Update `deploy/mac/setup.sh` (`MODEL_REF`) so a fresh install picks the new default.
5. `cicero gateway restart`.
6. Smoke test:
   ```bash
   cicero ask "What's your name and what tools do you have?"
   ```

### Changing the escalation models

`lib/brain_mcp.py` pins `BIG_BRAIN_MODEL` and `GALAXY_BRAIN_MODEL`. Edit the constants, run the unit through `python3 lib/brain_mcp.py` once if you want to validate import-time auth, and `cicero gateway restart` to pick up the change in any cached MCP state.

### Adding or updating a skill

Skills live in `workspace/skills/<skill-name>/`. Each needs a `SKILL.md` that OpenClaw auto-discovers. Prose-only skills route inconsistently — back them with an MCP server (see `lib/memory_mcp.py` and `lib/brain_mcp.py` for working examples).

To add one:
1. **First — validate the capability.** Before writing any files, prove the underlying surface (API, AppleScript dictionary, third-party tool) actually does what you need. One smoke test, one `osascript -e`, one `curl`. Don't skip this.
2. Create `workspace/skills/<skill-name>/SKILL.md`.
3. If the skill needs a tool, write `lib/<skill>_mcp.py` using FastMCP (`from mcp.server.fastmcp import FastMCP`). Add any new deps to `pyproject.toml` and run `uv sync`. For a third-party MCP, pin the version in `setup.sh` (`npx -y <pkg>@<version>`).
4. Register: `openclaw mcp set <skill> "{\"command\":\"$HOME/cicero/.venv/bin/python\",\"args\":[\"$HOME/cicero/lib/<skill>_mcp.py\"]}"`.
5. **Restart the gateway** (skill discovery is cached — `cicero gateway restart`, or `launchctl kickstart -k "gui/$(id -u)/ai.openclaw.gateway"` if the gateway is down).
6. Test in a fresh session: `cicero ask "use the <skill> skill to ..."`. Verify read AND write paths if the skill has both.
7. Update `workspace/AGENTS.md` "Tools" section and `workspace/TOOLS.md` "Data Sources" so the rest of the workspace knows the skill is live.

### Re-running setup (fresh machine or after a wipe)

```bash
cd ~/cicero
./deploy/mac/setup.sh
```

The script is idempotent. It reads `ANTHROPIC_API_KEY` from `.env` (or the environment), installs Node + OpenClaw + `uv`, syncs the Python venv, registers MCP servers, creates the workspace symlink, installs the launchd units (with the API key baked into the gateway plist environment), and starts the gateway. No interactive steps required.

If it stops asking for `openclaw onboard`, that means `~/.openclaw/openclaw.json` is missing on a truly fresh machine — let it run.

**After any `openclaw onboard` run**, check for `skipBootstrap`:
```bash
openclaw config get agents.defaults
```
If `skipBootstrap: true` is present, remove it (`setup.sh` does this automatically on every run, but worth knowing).

---

## Key paths on minerva

| Path | What |
|---|---|
| `~/cicero/` | This repo |
| `~/.openclaw/openclaw.json` | OpenClaw runtime config |
| `~/cicero/.env` | `ANTHROPIC_API_KEY` source (gitignored) |
| `~/cicero/.venv/` | Python venv (uv-managed, gitignored) |
| `~/.config/anthropic/api_key` | API key copy for brain MCP (written by setup.sh, mode 0600) |
| `~/.openclaw/workspace` | Symlink → `~/cicero/workspace` |
| `~/.openclaw/agents/main/sessions/` | Session trajectories |
| `~/Library/LaunchAgents/ai.openclaw.gateway.plist` | Gateway launchd unit |
| `~/Library/LaunchAgents/ai.cicero.chroma.plist` | Chroma launchd unit |
| `~/Library/Logs/openclaw-gateway.{out,err}.log` | Gateway logs |
| `~/Library/Logs/cicero-chroma.{out,err}.log` | Chroma logs |
| `~/Library/Logs/cicero-brain.log` | Per-call spend log for big-brain / galaxy-brain |
| `~/.local/bin/cicero` | CLI shim → `~/cicero/scripts/cicero` |
