# Roadmap

Living planning document. As of 2026-05.

---

## Current state

Cicero is operational on minerva.

- OpenClaw 2026.5.x with native `@openclaw/anthropic-provider`
- Default brain: `claude-haiku-4-5`
- Escalation: `big_brain` → `claude-sonnet-4-6`, `galaxy_brain` → `claude-opus-4-7`, both via `lib/brain_mcp.py`
- Workspace files (SOUL, IDENTITY, USER, TOOLS, AGENTS) injected every session — full Cicero voice restored with Haiku
- `cicero-memory` fully wired: Chroma + MCP, launchd-managed; corpus re-ingested from `cicero-backstory.md`
- `cicero-bigbrain` skill live
- `cicero-health` still a stub
- iMessage channel live (`cicero.ortega@icloud.com`, allowlist)
- CLI live (`cicero chat`, `cicero ask`)

---

## Phase 5 — Documentation

**Status:** Complete (rewritten 2026-05-26 to reflect the Anthropic API migration).

---

## Phase 6 — Security & Reliability

**Status:** Complete

minerva on Tailscale, never-sleep, restart on power failure. `ai.openclaw.gateway` and `ai.cicero.chroma` both `KeepAlive: true`, both rendered by `setup.sh`. Gateway token rotation scheduled (Jan 1, Jul 1). API key handling documented in `docs/security.md`.

---

## Phase 7 — Big Brain Mode

**Status:** Complete (2026-05-26)

Implemented as MCP tools in `lib/brain_mcp.py`, exposed as the `cicero-bigbrain` skill. Triggers are the phrases "big brain" (→ Sonnet 4.6) and "galaxy brain" (→ Opus 4.7) anywhere in the user's message. Cicero strips the trigger and delivers the larger model's answer verbatim. Each call logs to `~/Library/Logs/cicero-brain.log`.

Open follow-ups, monitored not blocked:
- Iterate on the trigger phrasing once we have real iMessage usage. If "big brain" gets caught by accident or missed when intended, adjust SKILL.md.
- Add a spend cap if monthly usage materially exceeds projection.
- Decide whether to pass conversation context into escalations by default. Currently the skill exposes `context` as an optional argument; Haiku can populate it.

---

## Phase 8 — Apple ID & iMessage

**Status:** Complete

Apple ID `cicero.ortega@icloud.com` signed into Messages.app on minerva. `@openclaw/imessage` + `imsg` CLI wired. DM allowlist (Carlos only), groups disabled, catchup enabled, message coalescing on. Cicero responds only when messaged.

---

## Phase 9 — Apple Reminders

**Status:** Planned. Depends on: nothing blocking.

- Cicero is owner of the shared chore list.
- Owner and wife are collaborators.
- Cicero can create reminders and assign them to specific collaborators.
- After adding a time-sensitive item, Cicero sends an iMessage to the assignee.
- Grocery list and other shared lists: Cicero is collaborator only.

Out of scope for this phase: location-based triggers, time-based nudges (deferred to 2.0).

---

## Phase 10 — Postgres Integration

**Status:** Planned. Depends on: external data pipelines (status TBD).

- Postgres instance on Saturn.
- Two candidate pipelines (independent projects):
  1. Apple Health + Heavy workout app
  2. Personal finance (Monarch Money)
- Cicero starts read-only; write access added as use cases emerge.
- `cicero-health` stub already registered.

---

## Phase 11 — Calendar (Google + iCal)

**Status:** Planned. Setup details require definition before implementation.

- Read both iCal (iCloud) and Google Calendar; read-only to start.
- Work calendar: shared read access ideal; details TBD.
- Auth: OAuth (Google) + CalDAV (iCloud).

---

## Phase 12 — Google Drive

**Status:** Planned. Lowest priority.

- Read-only initially. OAuth with personal Google account.

---

## Phase 13 — Future hardware

**Status:** Speculative.

The Mac mini migration that was on the prior roadmap is moot — minerva *is* the Mac mini. Documented here only to retire the item. Workspace, skills, and MCPs are portable to any future Mac; the deploy script does the heavy lifting.

---

## Future / unscheduled

- Proactive messages and scheduled reports via iMessage and email.
- Time-based reminder nudges (Phase 9 2.0).
- Additional skills: garden, home automation, journaling.
- Per-tool spend caps once usage data justifies them.
