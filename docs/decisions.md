# Architecture Decisions

Decisions that are non-obvious or would otherwise be re-litigated without context. Ordered by topic.

---

## OpenClaw over a custom brain

A custom Python/FastAPI inference loop would require maintaining channel adapters, memory serialization, and a skill runtime in perpetuity. OpenClaw already solves all of that. This repo configures an agent — personality, model, skills — it does not reimplement the platform. Less surface area is more reliable surface area.

## llama3.1:8b-instruct-q4_K_M as primary model

`llama3.1:8b-instruct-q4_K_M` (Q4_K_M quantization, OLLAMA_KEEP_ALIVE=24h) fits comfortably in 24GB unified memory and has reliable tool-calling support. `qwen3:8b` is the configured fallback. Q4_K_M is the right quantization tradeoff between quality and resident size.

## Chroma as a skill, not core memory

OpenClaw's built-in memory (workspace MD files, daily notes, MEMORY.md) handles preferences and short-term context. Chroma earns its place as a semantic search layer over domain data — biographical lore, health records, decision logs — too large and too structured for the workspace-file model. Keeping it a skill means it is optional, replaceable, and has a clean boundary. The backend is wired end-to-end on Minerva (server-mode chromadb, launchd-managed, loopback-only). See `docs/architecture.md` for the current implementation.

## Git over MLflow

The workspace is Markdown files, not model weights. Version control on configuration and personality is git's problem. MLflow solves experiment tracking for training runs; there are no training runs here.

## Workspace symlinked into repo

`~/.openclaw/workspace` is where OpenClaw reads the agent's files at runtime. `~/cicero/workspace` is the git-versioned source of truth. A symlink makes them the same directory. Edits in the repo are immediately live; no copy-on-deploy step, no divergence.

## CLI-only channel for now

No iMessage, Telegram, Discord, or any inbound channel is wired. The CLI (`cicero chat`, `cicero ask`) is sufficient for development. Channels add attack surface (see `docs/security.md`). iMessage is deferred until Cicero migrates to a Mac mini with native Apple ecosystem access.

## Saturn excluded from Cicero runtime

Saturn hosts other services (MLflow, Postgres, Figma, Dagster). Clean separation is maintained: Cicero runs entirely on Minerva. No Cicero component — gateway, Ollama, Chroma, workspace — touches Saturn.
