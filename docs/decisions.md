# Architecture Decisions

Decisions that are non-obvious, have future action items, or would otherwise be
re-litigated without context. Ordered by date, newest first.

---

## 2026-05-16: Memory reliability fix — four-layer approach

**Problem:** Cicero was hallucinating backstory answers. The model was not calling
`query_cicero_memory_tool` when asked about biographical context.

**Root causes identified:**

1. Tool surface overload: 19+ tools exposed to a small local model caused routing
   collapse. The model stopped dispatching tools entirely.
2. Model regression: `mistral-nemo:12b` has a documented tool-call regression in
   Ollama (issue #6713) — emits plain text instead of `tool_calls`.
3. Streaming bug: OpenClaw hardcodes `stream: true`. Ollama streaming drops
   `tool_calls` delta chunks, silently eating any tool call the model generates
   (openclaw issue #5769). Top-level `streaming` config is dead code; the fix must
   be in `params` (issue #12217).

**Fixes applied:**

| Layer | Fix | Commit |
|-------|-----|--------|
| 1 | `tools.deny` list added; pruned tool surface to ~10 visible | a443980 |
| 2 | Switched to `llama3.1:8b-instruct-q5_K_M`; `num_ctx=12288` | b3eede0 |
| streaming | `params.streaming=false` in `agents.defaults.models`; documented in `deploy/mac/README.md` | de37c10 |
| 3 | `lib/retrieval_middleware.py` — conditional Auto-RAG (threshold 0.60); wired into `scripts/cicero ask` | de7af42 |
| 4 | `/remember` slash command — deterministic bypass direct to `query_cicero_memory_tool` | 0512b2b |

**Threshold calibration (Layer 3):** Backstory queries scored 0.629–0.783; irrelevant
queries scored 0.533–0.566. Gap of 0.063 with cutoff at 0.60. 10/10 test cases pass.

---

## Big Brain / Claude Sonnet Tool Calling (Future Work)

When big brain mode is configured to use Claude Sonnet via the Anthropic API,
the following applies:

- **Streaming fix does not apply to Sonnet.** The Anthropic API handles streaming
  and tool calls correctly by design — no workaround needed on that path.

- **Layer 3 middleware is path-agnostic.** The retrieval middleware runs upstream
  of model selection (inside `scripts/cicero ask`) and works on both the local
  Llama path and the Sonnet path without modification.

- **Verify MCP tool visibility on Sonnet path.** When big brain is configured,
  confirm that the `cicero-memory` MCP server registration is visible on the
  Sonnet agent path the same way it is on the local model path. This is an
  OpenClaw config verification step, not an architecture change.

- **Sonnet routes tools reliably.** `query_cicero_memory_tool` will be called
  correctly without any of the Ollama workarounds. Tool routing should work
  out of the box on the big brain path.

**Action required when building big brain:** verify MCP tool visibility on the
Sonnet path and confirm tool calls fire correctly on a single test turn before
considering the feature complete.
