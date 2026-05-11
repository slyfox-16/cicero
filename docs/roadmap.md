# Roadmap

Current state and what comes next, in order.

---

## Now (stable)

Cicero CLI on Saturn. Local-only. Passive.

- OpenClaw 2026.5.7 running qwen3:8b via Ollama on a GTX 1080.
- Workspace versioned in git, symlinked into `~/.openclaw/workspace`.
- Personality and behavioral rules loaded from `workspace/SOUL.md`.
- `cicero-health` and `cicero-memory` skills registered as stubs.
- Systemd service, idempotent setup script, deploy artifacts in the repo.

---

## Next: Health Data Ingestion

The `cicero-health` skill returns a placeholder. Real implementation requires:

1. **Ingestion pipeline.** Apple Health XML export + Heavy app CSV → ETL → Postgres on Saturn. Schema: `workouts`, `sleep_sessions`, `body_metrics`. One-shot historical import, then incremental updates.
2. **Query interface.** A small wrapper the skill can call — SQL or a thin HTTP service — that takes a natural-language query parameter and returns structured rows.
3. **Replace the stub.** Update `workspace/skills/cicero-health/SKILL.md` with real dispatch instructions that call the query interface.

Relevant files: `workspace/skills/cicero-health/README.md` has the full TODO list.

---

## Then: Real Chroma Memory

The `cicero-memory` skill returns a placeholder. Real implementation requires:

1. **Chroma server on Saturn** (or embedded mode). Already installed; not yet integrated.
2. **Indexer.** Watch `workspace/memory/` and `workspace/MEMORY.md`, embed on change, upsert into Chroma. Likely using `nomic-embed-text` via Ollama.
3. **Query wrapper.** HTTP endpoint or subprocess the skill calls with a query string.
4. **Replace the stub.** Update `workspace/skills/cicero-memory/SKILL.md` with real dispatch.

Relevant files: `workspace/skills/cicero-memory/README.md` has the full TODO list.

---

## Then: Proactive Agents

`workspace/cron/` is reserved. When proactive behavior is ready:

1. Define cron jobs in `workspace/cron/` using OpenClaw's cron format.
2. Define heartbeat tasks in `workspace/HEARTBEAT.md`.
3. Start with low-stakes checks: morning briefing, calendar summary.
4. Add actuating behavior only after the security posture is reviewed.

---

## Then: Mac Migration

When iMessage integration is worth pursuing:

1. Write `deploy/mac/setup.sh` mirroring `deploy/saturn/setup.sh` for Homebrew + launchd.
2. Install on Mac mini. Validate workspace symlink and gateway.
3. Enable iMessage channel (BlueBubbles or native bridge).
4. Migrate or replicate Postgres health data.
5. Decommission Saturn instance, or keep it as a secondary.

See `deploy/mac/README.md` and `docs/architecture.md` (Saturn → Mac section) for the migration plan.

---

## Future Skills

In rough priority order, none of these are started:

- **Garden.** Track plantings, harvests, notes. Likely a flat-file or SQLite backend.
- **Home automation.** Read/control devices. Depends on what home infra looks like at migration time.
- **Apple Reminders.** Mac-only via `remindctl`. Actuates, so security review required before enabling.
- **Web search.** Brave API key. Low priority while Cicero is CLI-only.
