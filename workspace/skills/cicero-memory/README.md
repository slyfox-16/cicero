# cicero-memory

Stub skill. Currently returns a hardcoded placeholder for any "search your memory" prompt.

## What this will become

A semantic search skill over Cicero's long-term knowledge:

- **Backend:** Chroma vector DB on Saturn (already installed; not yet integrated).
- **Corpus:** Daily memory files (`workspace/memory/YYYY-MM-DD.md`), curated long-term notes (`workspace/MEMORY.md`), and structured project knowledge (garden notes, home automation device inventory, decision logs, etc.).
- **Embedding model:** TBD. Likely a local sentence-transformer to keep everything on Saturn.
- **Interface:** This skill will call a small wrapper that does `query → top-k chunks → reranked snippet bundle` and returns those snippets for Cicero to ground its response in.

## Why a skill, not core memory

OpenClaw has built-in short-term memory (the workspace MD files, daily notes, MEMORY.md). Chroma sits on top of that as a search layer — useful when the relevant memory is too old or too granular to fit in the system prompt.

## TODO (real implementation)

- [ ] Stand up a Chroma server on Saturn (or use embedded mode from inside the skill).
- [ ] Write the indexer: watch `workspace/memory/` and `workspace/MEMORY.md`, embed on change, upsert into Chroma.
- [ ] Pick the embedding model (local-first; nomic-embed-text via Ollama is a candidate).
- [ ] Define the query interface this skill calls (HTTP? gRPC? in-process Python wrapper invoked via a tool?).
- [ ] Replace the placeholder behavior in `SKILL.md` with the real query path.
- [ ] Decide whether to also index `cicero-health` Postgres rows for cross-domain search.

See `docs/roadmap.md` for the broader plan.
