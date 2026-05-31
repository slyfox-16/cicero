# Roadmap

Categorized backlog. Three categories:

- **Infrastructure** — substrate changes that unlock downstream work.
- **Feature** — new capability for Cicero.
- **Revision** — improvement to something that already exists.

Completed items are removed from this doc once they ship; they live in their relevant ADR (`docs/decisions.md`), the architecture overview (`docs/architecture.md`), or operations runbook (`docs/operations.md`). The roadmap is forward-looking only.

**Current status:** Cicero is hibernated as of 2026-05-30. minerva decommissioned. Future host: Saturn (Linux). The Saturn migration section below must be completed before any other infrastructure work resumes.

---

## Saturn migration (deferred — do this first on revival)

minerva is gone. Before Cicero can run on Saturn, the following must be built. None of this is
designed in detail yet — do that work when revival is imminent.

### Primary channel replacement

iMessage has no Linux equivalent. Pick one and implement before anything else — without a channel,
Cicero has no input. Options in rough order of preference:

- **Matrix** (self-hostable, bridges to iMessage/Signal/SMS via various bridges, open protocol)
- **Signal-CLI** (end-to-end encrypted, open source, requires a dedicated phone number)
- **Telegram bot** (easiest to implement, hosted infrastructure, not self-sovereign)
- **Webhook / simple HTTP** (lowest friction for dev use; no mobile UX)

### Linux service management

Replace launchd with systemd user services:
- `~/.config/systemd/user/cicero-gateway.service` — OpenClaw gateway
- `~/.config/systemd/user/cicero-chroma.service` — Chroma vector store
- systemd timer for token rotation (replaces `ai.cicero.token-rotate.plist`)

### Linux deploy script

Write `deploy/linux/setup.sh` mirroring `deploy/mac/setup.sh`. Reference the Mac script as the
authoritative spec for what it needs to do:
- Install deps via apt/dnf/pacman instead of Homebrew
- Set up systemd units instead of launchd plists
- Register MCPs, create workspace symlink, start services
- No `imsg`, no macOS permissions steps

### cicero-reminders replacement

EventKit is macOS-only. Evaluate:
- Todoist API (hosted; good mobile apps Carlos and Sarah already use)
- Nextcloud Tasks / CalDAV (self-hosted; fits self-sovereignty ethos)
- Match the three-list model (Honeydew, Groceries, Garden) as closely as possible

### cicero-notes replacement

AppleScript is macOS-only. Evaluate:
- Nextcloud Notes (self-hosted; pairs with Tasks)
- Joplin server (self-hosted; markdown-native)
- Keep the same "Cicero" shared folder model where possible

### Memory re-ingestion

On first Saturn boot, run `scripts/ingest_memory.py` against a fresh Chroma instance to rebuild
long-term memory from `docs/archive/cicero-backstory.md`. No data was lost — the corpus is in git.

### brain_mcp.py log path (trivial)

Change `LOG_PATH` in `lib/brain_mcp.py` from `Path.home() / "Library" / "Logs"` to
`Path.home() / ".local" / "share" / "cicero" / "logs"`.

---

## Infrastructure

### Multi-user identity & contact-gated allowlist

**Depends on Saturn migration (primary channel replacement).**

Cicero currently treats every inbound message as "from Carlos" — the iMessage allowlist contains only `carlos.m.ortega16@gmail.com`. Sarah and any future users have no first-class place in the system.

**Goals:**
- Define the set of users that can interact with Cicero. Initial set: Carlos, Sarah.
- Gate inbound messages by Cicero's iCloud Contacts: if the sender is not a Contact, Cicero ignores them. This replaces the hard-coded `allowFrom` list in `openclaw.json` with a dynamic check against Contacts.app.
- Record each user's identity (name, email(s), phone number(s), relationship to Carlos) so Cicero knows who he is talking to and can address them correctly.
- Record outbound channels per user (Carlos's email, Sarah's phone, etc.) so Cicero can initiate contact — needed for proactive messages and the time-based reminder nudges below.

**Open design questions:**
- Where to store the user registry — a workspace file (`workspace/USERS.md`), a structured JSON, or sync directly from Contacts.app each session.
- How to handle a sender who is in Contacts but has no defined role (greet politely, refuse, ask for clarification).
- Whether to surface "I don't know who you are" responses or silently ignore.

Unblocks: short-term memory (needs a user key to partition by), proactive messaging, time-based reminder nudges, future per-user permissions on what Cicero can write.

---

### Short-term memory (24-hour conversational context, per user)

**Depends on Saturn migration (primary channel) and multi-user identity.**

Cicero currently has no memory of what he said earlier in a conversation. Every iMessage and CLI call starts cold. This kills follow-up questions ("add the recipe ingredients to groceries" after a recipe lookup), and it makes confirm-before-write impossible.

**Goals:**
- Persist the last 24 hours of message exchanges per user into a Chroma collection (separate from `cicero_memory`).
- On each inbound message, retrieve recent context for that user and inject it into the system prompt.
- Strict per-user partitioning: Sarah's threads never bleed into Carlos's, and vice versa. The retrieval key is the user identity from the multi-user infrastructure above.
- 24 hours is the default; old turns roll off automatically.

**Open design questions:**
- Whether to use Chroma (semantic recall over the day's messages) or a simpler chronological window (last N turns). Probably both: chronological for "what did I just say" and semantic for "did we talk about the vet recently."
- Whether assistant turns get stored alongside user turns (likely yes — Cicero needs his own outputs for follow-up context).
- TTL housekeeping: launchd job that prunes >24h entries, or query-time filtering.

**Depends on:** Multi-user identity (needs a user key to partition by).

**Unblocks:** Confirm-before-write on iMessage; "what did we just discuss" follow-ups; reduces the need for users to phrase every request atomically.

---

### Per-tool spend caps

Per-call Anthropic usage is logged to `~/Library/Logs/cicero-brain.log` but not capped. Haiku is cheap, but a runaway loop on Opus could surprise. Revisit once there's real usage data and define monthly per-model ceilings with a hard stop or alert.

---

## Feature

### Postgres integration

Postgres instance lives on Saturn. Two candidate pipelines, independent of each other:

1. Apple Health export + Heavy workout app — populates Carlos's training and biometric data.
2. Personal finance (Monarch Money) — populates spend / cash-flow / account state.

Cicero starts read-only. Write access added per use case as the pipelines mature. The `cicero-health` stub is already registered and will be the first consumer of pipeline #1. Pipeline status is tracked in those external projects, not here.

---

### Calendar (Google + iCal)

Read both Carlos's iCloud calendars and Google Calendar (personal + work, if work permits shared read). Read-only to start. Auth: OAuth for Google, CalDAV for iCloud. Unlocks scheduling-aware responses and would eventually pair well with reminder-creation flows.

---

### Time-based proactive nudges

**Depends on Saturn migration (primary channel) and multi-user identity.**

Cicero today only acts when messaged. A scheduled loop scans upcoming reminders and DMs the assignee an hour before due. Depends on multi-user identity (to know who to message) and is a small extension on top of the iMessage send path that already works.

---

### Proactive messages and scheduled reports

**Depends on Saturn migration (primary channel) and multi-user identity.**

Daily / weekly digests Cicero pushes out unprompted — morning brief, weekly grocery roundup, financial pulse once Postgres lands, etc. Same dependency on multi-user identity for routing.

---

### Google Drive

Read-only initially. OAuth with Carlos's personal Google account. Lowest priority of the planned data sources.

---

### Additional skills

Speculative slots, not designed yet. Garden assistant (planting calendar, weather-aware watering), home automation (HomeKit bridge), journaling (structured daily capture). Each becomes a feature ticket when there's a concrete use case.

---

## Revision

### Tag chips in Reminders

EventKit-created hashtags render as plain text in the title, not real Apple tag chips. Cicero currently writes no tags on reminders. Possible paths:

- Wrap reminder creation in a Shortcut, which may invoke Apple's tag parser via UI codepath.
- Use a private/undocumented EKReminder property for tags (fragile).
- Wait for Apple to expose tag support to EventKit.

Low priority — list separation, priority, and due dates cover most categorization need.

---

### Tag chips in Notes

AppleScript-written `#tag` content stores correctly but Notes' tag parser only fires on user edit events, so tags stay inert until the user opens the note and types. Trailing-space-plus-empty-paragraph workaround was tried and confirmed ineffective. Possible paths:

- Route note creation through a Shortcut with Apple's dedicated "Add Tags to Notes" action (requires manual Shortcut authoring on a Mac).
- Simulate a keystroke via `osascript` → System Events after creation (hacky).

Moot if cicero-notes is replaced with a non-Apple backend on Saturn. Revisit only on a future Mac revival.

---

### Assign-to-person on shared reminders

Not exposed by EventKit or by the New / Edit Reminder Shortcut actions on macOS. Carlos and Sarah assign manually on their phones today. Revisit if a future macOS update adds Assignee to a Shortcut action.

---

### Flag a reminder

Same situation as assignment — UI-only Apple feature, no public API. Cicero uses priority high as a stand-in if asked.

---

### Sections within a Reminders list

Not exposed by EventKit. Use lists themselves as the primary categorization for now. Watch for Apple to add API support.

---

### Confirm-before-write on channel

**Depends on Saturn migration (primary channel) and short-term memory.**

Today Cicero writes immediately and recaps. A confirm step ("Add milk, eggs, butter to Groceries — yes?") requires Cicero to remember the pending write between the two iMessage pings. **Depends on** the short-term memory infrastructure above. Once that lands, this becomes a small SKILL.md change.
