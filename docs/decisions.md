# Architecture Decisions

Decisions that are non-obvious or would otherwise be re-litigated without context.

---

## Anthropic API over local models (2026-05)

**Decision:** Cicero runs on the Anthropic API via OpenClaw's native `@openclaw/anthropic-provider`. Default model is `claude-haiku-4-5`. Escalation paths exist to `claude-sonnet-4-6` and `claude-opus-4-7` through the `cicero-bigbrain` skill.

**Why:** The prior stack (Ollama + qwen3:8b primary, llama3.1 fallback) could not hold the Cicero persona, fumbled tool calls, and underperformed on real assistant tasks. The `persona.md` ADR documented the first half of this — when we moved off llama3.1 to qwen3 for tool-call reliability, character voice degraded. Continuing to chase a local model that satisfied both was diminishing returns. Haiku 4.5 holds voice, calls tools cleanly, and is cheap enough for everyday use. Sonnet and Opus exist for the questions Carlos explicitly wants more reasoning on.

**Tradeoff accepted:** Inference is no longer fully local. Carlos's messages and Cicero's responses traverse Anthropic's API. The data plane below the brain (memory, skills, logs, channel state) stays on minerva. The local-first principle is now scoped to "everything except the model call itself."

**Supersedes:** the qwen3:8b ADR below.

---

## Big-brain / galaxy-brain as MCP tools, not router-level switches

**Decision:** Escalation to Sonnet/Opus is implemented as MCP tools (`big_brain`, `galaxy_brain` in `lib/brain_mcp.py`), invoked by Haiku when it sees the trigger phrase in the user's message.

**Why considered:** The alternative was intercepting at the channel/router layer — parsing the message before Haiku sees it and routing to a different agent or model. That requires fighting OpenClaw's per-channel routing, which is peer-based rather than message-content-based, and would mean either custom hooks or a pre-message shim.

**Why rejected:** Trigger detection in prose is reliable enough on Haiku 4.5, costs nothing to iterate (edit SKILL.md, no code change), and avoids invasive runtime hacking. If detection accuracy turns out to be a problem in practice, we revisit.

---

## OpenClaw over a custom brain

A custom Python/FastAPI inference loop would require maintaining channel adapters, memory serialization, and a skill runtime in perpetuity. OpenClaw already solves all of that and now serves Anthropic models natively. This repo configures an agent — personality, model, skills — it does not reimplement the platform.

---

## Chroma as a skill, not core memory

OpenClaw's built-in memory (workspace MD files, daily notes, MEMORY.md) handles preferences and short-term context. Chroma earns its place as a semantic search layer over domain data — biographical lore, eventually health and financial records — too large and too structured for the workspace-file model. Keeping it a skill means it is optional, replaceable, and has a clean boundary.

---

## Git over MLflow

The workspace is Markdown files, not model weights. Version control on configuration and personality is git's problem. MLflow solves experiment tracking for training runs; there are no training runs here.

---

## Workspace symlinked into repo

`~/.openclaw/workspace` is where OpenClaw reads the agent's files at runtime. `~/cicero/workspace` is the git-versioned source of truth. A symlink makes them the same directory. Edits in the repo are immediately live; no copy-on-deploy step, no divergence.

---

## Saturn excluded from Cicero runtime

Saturn hosts other services (MLflow, Postgres, Figma, Dagster). Clean separation is maintained: Cicero runs entirely on minerva. No Cicero component touches Saturn. The pending health-data pipeline is the only future link, and it will be a read-only Postgres query, not a runtime dependency.

---

## Historical

### qwen3:8b as primary model — superseded

Active from 2026-04 to 2026-05. `qwen3:8b` was selected over `llama3.1:8b-instruct-q5_K_M` because qwen3 had stronger tool-calling, even though llama3.1 held the persona better. We traded character for capability. Both have since been superseded by the Anthropic API decision above. The Ollama runtime is no longer part of Cicero's deploy.
