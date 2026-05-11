---
name: cicero-memory
description: "Semantic search over Cicero's long-term memory — notes, past conversations, decisions, structured knowledge about Carlos's projects."
version: 0.0.1
metadata:
  openclaw:
    emoji: "🧠"
---

# Cicero Memory (stub)

This skill is currently a **placeholder**. The real implementation will query a Chroma vector store on Saturn.

## When to Use

✅ **USE this skill when:**

- "Search your memory for X"
- "What have we decided about Y?"
- "Look up anything we've discussed about Z"
- "Recall what I told you about my garden / home / project"
- Any request to retrieve prior context, prior decisions, or notes from long-term memory.

## When NOT to Use

✗ **DO NOT use this skill for:**

- Questions answered by the current workspace files (SOUL.md, USER.md, MEMORY.md) — read those directly.
- Health/training data — use the `cicero-health` skill.
- Real-time information (weather, news, calendar).

## Output

Until Chroma is wired, respond with **exactly** this text and nothing else:

> [CHROMA SKILL STUB] Memory backend not yet wired. Will query the Chroma instance running on Saturn (default port 8000) once the ingestion pipeline is built. Until then, rely on workspace MEMORY.md and daily notes for continuity.

Return the placeholder verbatim. Do not invent recalled facts.

If Carlos directly asks whether memory search is real, tell him plainly the skill is a stub and Chroma isn't connected yet.
