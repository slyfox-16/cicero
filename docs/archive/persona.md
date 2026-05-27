# ADR: Cicero Persona — End of Life

**Status:** Reopened 2026-05-26. Persona enforcement is back, no special rules needed — with Claude Haiku 4.5 as the brain, character voice holds without persona-compliance scaffolding. SOUL.md and IDENTITY.md have been rewritten in Cicero's voice, and the Chroma corpus is re-ingested. See `docs/decisions.md` for the Anthropic-API ADR. The historical record below is preserved for context.

**Original status:** Superseded
**Original date:** 2026-05-17

---

## What the persona was

"Cicero" as a character voice — a 1960s British special operations officer with the analytical discipline of a seasoned hedge fund partner. The persona gave the assistant a distinct identity: calm authority, deliberate restraint, first-person ownership of a fabricated operational history ("I was in Havana", "I reported that the operation would fail"), and a set of stylistic constraints (no emojis, no theatrics, no verbosity, no comedy).

The character's backstory was seeded from `docs/cicero-backstory.md` and ingested into the Chroma vector store so that memory queries would surface persona-consistent lore, surfaced as if "remembered" rather than retrieved.

---

## How it was implemented

Originally authored as a single `personality.txt` file (in `packages/cicero/`, now absent from the repo). Later split into two workspace files:

- **`workspace/SOUL.md`** — tone, behavioral rules, character voice, values, first-person voice enforcement. Injected into the system prompt on every turn.
- **`workspace/IDENTITY.md`** — name, origin story, role, vibe metadata. Also injected at session start.

Both files live in `workspace/` and are live-synced to `~/.openclaw/workspace/` via a symlink. Edits to either file take effect on the next session without a gateway restart.

The Chroma memory layer (`cicero-memory` skill → `query_cicero_memory_tool` MCP server) was used to retrieve biographical lore during chat, providing grounded persona-consistent answers to questions about the character's past.

---

## Which model held the persona and why

`llama3.1:8b-instruct-q4_K_M` (and later `q5_K_M`) was the only tested model that reliably held the character voice as instructed. The model had relatively weak RLHF identity anchoring, which made it responsive to system-prompt persona injection.

`qwen3:8b`, tested as a candidate primary, could not hold the persona. Its stronger RLHF training anchors its identity to the vendor-trained behavior — system-prompt persona instructions are overridden silently. The agent would answer as "Assistant" or "Qwen" regardless of SOUL.md content.

`deepseek-r1:14b` was briefly tested but does not support Ollama function calling at all, making it unusable as a primary regardless of persona behavior.

---

## Why it was end-of-lifed

The persona created a hard dependency on `llama3.1:8b-instruct-q4_K_M` — the weakest model in the tested set. `qwen3:8b` has substantially stronger tool calling, better reasoning, and is the correct long-term primary. Forcing persona compliance meant choosing character voice over capability, which is the wrong tradeoff for an infrastructure-grade personal assistant.

The persona was also a maintenance liability: character consistency required careful SOUL.md authoring, persona compliance testing on every model change, and a Chroma corpus of backstory lore. None of that work contributes to the assistant's actual utility.

**The assistant will still be named Cicero.** The name is retained. The character voice is not enforced.

---

## What was retained

- `workspace/SOUL.md` — retained as required by OpenClaw's workspace spec. Character language removed; only operational and behavioral rules remain.
- `workspace/IDENTITY.md` — retained. Character description will be revised in a future pass; name and role lines are kept.
- `docs/cicero-backstory.md` — retained as a historical artifact. The Chroma store seeded from it was wiped as part of this change (2026-05-17 Chroma reset).
- `personality.txt` — the original source file is not present in the current repo (was in `packages/cicero/`, a path no longer tracked). Nothing to preserve.

---

## What changed in this transition

| File | Change |
|---|---|
| `workspace/SOUL.md` | Character voice removed; operational rules retained |
| `workspace/IDENTITY.md` | No change in this pass; character description lines to be updated later |
| `deploy/mac/setup.sh` | Primary model switched to `qwen3:8b`; fallback to `llama3.1:8b-instruct-q5_K_M` |
| `docs/architecture.md` | Primary/fallback model entries updated |
| `docs/decisions.md` | Model rationale updated |
| `docs/operations.md` | Stale deepseek troubleshooting row removed; tool-call limitation section removed |
| `README.md` | Model reference updated |
| `workspace/TOOLS.md` | Model note updated |
| `data/chroma/` | Vector store wiped and recreated empty |
