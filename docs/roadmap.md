# Roadmap

Living planning document. Reflects decided direction, known blockers, and open design questions as of 2026-05.

---

## Current State

Cicero is operational on Minerva. This is the baseline.

- OpenClaw 2026.5.x + Ollama (MLX backend, Apple Silicon)
- Primary model: `llama3.1:8b-instruct-q4_K_M`. Fallback: `qwen3:8b`.
- Persona integrated — SOUL.md / IDENTITY.md injected every session
- `cicero-health` stub registered (no backend yet)
- `cicero-memory` fully wired: Chroma + MCP (`memory_mcp.py` → `memory_query.py`), launchd-managed
- Chroma running on Minerva (loopback, launchd-managed)
- CLI-only channel

---

## Phase 5 — Documentation

**Status:** Complete

Overhauled `docs/` to describe what Cicero currently is. Ground-truth reference, not a design journal.

Files in scope: architecture.md, security.md, decisions.md, scope.md, note.md, roadmap.md.  
Excluded: cicero-backstory.md.

---

## Phase 6 — Big Brain Mode (Claude API Escalation)

**Status:** Planned  
**Depends on:** Anthropic API key configured on Minerva

### 1.0

- Invoked via slash command: `/bigbrain`
- Routes that single message to Claude Sonnet via the Anthropic API
- Returns to local model immediately after — no persistent mode change
- Full persona (SOUL.md), all skills, all tools, and Chroma access remain active during the escalated call — behavior is identical to local model except for the underlying inference
- Conversation history is not passed to Sonnet — single message only
- No confirmation step required

### 2.0 (deferred)

- Full conversation context passed to Sonnet on `/bigbrain` invocation

### Galaxy Brain — `/galaxybrain` (Opus)

**Status:** TBD — documented future item, not part of this phase

- Deferred due to Opus pricing risk — no current use case justifies the cost
- If ever implemented: single message only, no context passing, always
- Revisit only if a concrete task arises that Sonnet cannot handle

### Open Design Question

Verify OpenClaw 2026.5.x tool and skill passthrough behavior for API backends. Confirm Chroma and registered skills are visible to Sonnet during `/bigbrain` calls. Check openclaw.ai docs before implementing — may require explicit configuration.

---

## Phase 7 — Apple ID & iMessage

**Status:** Blocked  
**Blocker:** Cicero requires a dedicated Apple ID before any Apple integrations can proceed. This is the critical path item for Phases 7 and 8.

### Apple ID Setup

- Account uses an iCloud email address — no external email provider
- Google Voice number reserved for verification — pending account approval
- Apple ID creation deferred to Mac mini migration: new device reduces Apple account trust friction

### iMessage Integration

- Cicero communicates via iMessage using his dedicated Apple ID
- Authorized senders: owner and wife only — all others ignored
- Cicero responds only when messaged — no proactive outreach in this phase
- OpenClaw iMessage channel enabled on Mac mini at migration time

---

## Phase 8 — Apple Reminders

**Status:** Planned  
**Depends on:** Phase 7 (Apple ID)

- Cicero is list owner of the shared chore list
- Owner and wife are collaborators
- Cicero can create reminders and assign them to specific collaborators
- After adding a time-sensitive item, Cicero sends an iMessage to the assignee — intended to trigger Apple Intelligence reminder suggestion on their device
- Grocery list and other shared lists: Cicero is collaborator only, not owner — no assignment needed

**Out of scope for this phase:**
- Location-based triggers
- Time-based nudges (deferred to 2.0)

**2.0 (deferred):**
- Time-based nudges: Cicero sends an iMessage to the assignee at a specified time for items that require it
- Location-based triggers: explicitly out of scope, not planned

**Open Design Question:**
Which lists does Cicero own vs. collaborate on? Chore list confirmed as owner. All others TBD at implementation time.

---

## Phase 9 — Postgres Integration

**Status:** Planned  
**Depends on:** Data pipelines (external projects, built independently of Cicero — status TBD)

- Postgres instance running on Saturn
- Two candidate pipelines being built separately as independent projects:
  1. Apple Health data ingestion (Apple Health + Heavy workout app)
  2. Personal finance data (Monarch Money)
- Pipeline documentation will be provided when ready — Cicero skill implementation follows from that documentation
- Cicero starts with read-only access; write access added as use cases emerge
- `cicero-health` stub already registered — real implementation follows pipeline completion

Note: pipelines are independent projects. Do not block Cicero roadmap progress on them. Treat as TBD until documentation is provided.

---

## Phase 10 — Google Calendar / iCal

**Status:** Planned  
**Depends on:** Nothing blocking — setup details require definition before implementation

- Cicero reads both iCal (iCloud) and Google Calendar
- Read-only to start; write access added as use cases emerge
- Work calendar: goal is shared read access for full schedule visibility — setup details TBD
- Wife's calendar: TBD — may be needed for chore and reminder coordination
- Authentication: OAuth with personal Google account for Google Calendar; iCloud CalDAV for iCal

**Open Design Question:**
Calendar setup and any required account or sharing changes need to be defined before implementation begins. Confirm whether the work calendar can be shared with read access and what that requires.

---

## Phase 11 — Google Drive

**Status:** Planned  
**Depends on:** Nothing blocking

- Read-only to start; write access added as use cases emerge
- Authentication: OAuth with personal Google account
- No specific use case defined yet — capability established for future use
- Lowest priority integration

---

## Phase 12 — Mac Mini Migration

**Status:** Planned  
**Depends on:** Phase 7 (Apple ID must exist before iMessage can be enabled on the new machine)

- Minerva is the current Cicero machine; Mac mini is the long-term target
- At migration:
  - Fresh machine setup via `deploy/mac/setup.sh` (not yet written)
  - `brew install ollama openclaw`
  - `ollama pull llama3.1:8b-instruct-q4_K_M`
  - iMessage channel enabled (requires Cicero Apple ID — see Phase 7)
  - Minerva instance decommissioned
- What does not change: `workspace/`, skills, persona, model config

---

## Future / Unscheduled

Items with no defined phase.

- Proactive messages and scheduled reports via iMessage and/or email
- Time-based reminder nudges (2.0 scope from Phase 8)
- Galaxy brain mode (`/galaxybrain` via Opus) — deferred indefinitely; single message only if ever implemented, no context passing
- Additional skills: garden, home, reminders
- Write access to Postgres, Google Drive, Google Calendar
