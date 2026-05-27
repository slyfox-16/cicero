"""MCP server exposing big-brain (Sonnet) and galaxy-brain (Opus) escalation tools.

Cicero runs on Haiku 4.5 by default. When Carlos uses the phrase "big brain" or
"galaxy brain" (prefix, suffix, or anywhere in the message), Cicero invokes the
matching tool here. The tool calls a larger Claude model directly via the
Anthropic SDK and returns the answer for Cicero to deliver verbatim.

Stdio transport. Registered via:
    openclaw mcp set cicero-brain '{
      "command": "<env python>",
      "args":    ["<repo>/lib/brain_mcp.py"]
    }'

API key resolution (first match wins):
  1. ANTHROPIC_API_KEY env var
  2. ~/.config/anthropic/api_key (file, mode 0600 expected)
"""

from __future__ import annotations

import json
import os
import time
from datetime import datetime, timezone
from pathlib import Path

from anthropic import Anthropic
from mcp.server.fastmcp import FastMCP

BIG_BRAIN_MODEL = "claude-sonnet-4-6"
GALAXY_BRAIN_MODEL = "claude-opus-4-7"
MAX_TOKENS = 4096

LOG_PATH = Path.home() / "Library" / "Logs" / "cicero-brain.log"

ESCALATION_SYSTEM_PROMPT = (
    "You are answering on behalf of Cicero — a personal AI assistant with a calm, "
    "dry, economical voice. The caller (Cicero, running on a smaller model) has "
    "escalated this question to you because it needs more depth than he can deliver. "
    "Respond directly to the question in plain prose. Do not greet, do not introduce "
    "yourself, do not editorialize about the question or your role. The caller will "
    "deliver your output verbatim to the user. Match Cicero's voice: clipped, "
    "observant, no filler, no emojis, no apology theater. If the question is "
    "underspecified, answer the most reasonable reading rather than asking for "
    "clarification."
)


def _resolve_api_key() -> str:
    env = os.environ.get("ANTHROPIC_API_KEY")
    if env:
        return env.strip()
    key_file = Path.home() / ".config" / "anthropic" / "api_key"
    if key_file.is_file():
        return key_file.read_text().strip()
    raise RuntimeError(
        "No Anthropic API key found. Set ANTHROPIC_API_KEY or write the key to "
        "~/.config/anthropic/api_key (mode 0600)."
    )


_client: Anthropic | None = None


def _client_lazy() -> Anthropic:
    global _client
    if _client is None:
        _client = Anthropic(api_key=_resolve_api_key())
    return _client


def _log(model: str, question_len: int, answer_len: int, latency_ms: int,
         usage: dict | None, error: str | None = None) -> None:
    try:
        LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        entry = {
            "ts": datetime.now(timezone.utc).isoformat(),
            "model": model,
            "question_chars": question_len,
            "answer_chars": answer_len,
            "latency_ms": latency_ms,
            "usage": usage,
            "error": error,
        }
        with LOG_PATH.open("a") as f:
            f.write(json.dumps(entry) + "\n")
    except Exception:
        pass


def _escalate(model: str, question: str, context: str) -> str:
    client = _client_lazy()
    user_content = question if not context else f"Context:\n{context}\n\nQuestion:\n{question}"
    start = time.perf_counter()
    try:
        resp = client.messages.create(
            model=model,
            max_tokens=MAX_TOKENS,
            system=ESCALATION_SYSTEM_PROMPT,
            messages=[{"role": "user", "content": user_content}],
        )
    except Exception as e:
        _log(model, len(question), 0, int((time.perf_counter() - start) * 1000), None, str(e)[:200])
        raise
    latency_ms = int((time.perf_counter() - start) * 1000)
    text_parts = [b.text for b in resp.content if getattr(b, "type", None) == "text"]
    answer = "\n".join(text_parts).strip()
    usage = {
        "input_tokens": getattr(resp.usage, "input_tokens", None),
        "output_tokens": getattr(resp.usage, "output_tokens", None),
    } if getattr(resp, "usage", None) else None
    _log(model, len(question), len(answer), latency_ms, usage)
    return answer


mcp = FastMCP("cicero-brain")


@mcp.tool()
def big_brain(question: str, context: str = "") -> str:
    """Escalate a question to Claude Sonnet 4.6 (big brain mode).

    Use this when the user includes the phrase "big brain" anywhere in their
    message (prefix, suffix, case-insensitive, punctuation optional). Strip the
    trigger phrase from the question before passing it in. Pass any relevant
    conversational context separately. Deliver the returned answer to the user
    verbatim — do not paraphrase or summarize.

    Args:
        question: The user's question with the "big brain" trigger phrase removed.
        context: Optional prior-turn context the larger model should consider.

    Returns:
        The model's answer as plain text. Deliver verbatim.
    """
    return _escalate(BIG_BRAIN_MODEL, question, context)


@mcp.tool()
def galaxy_brain(question: str, context: str = "") -> str:
    """Escalate a question to Claude Opus 4.7 (galaxy brain mode).

    Use this when the user includes the phrase "galaxy brain" anywhere in their
    message (prefix, suffix, case-insensitive, punctuation optional). Strip the
    trigger phrase from the question before passing it in. Pass any relevant
    conversational context separately. Deliver the returned answer to the user
    verbatim — do not paraphrase or summarize.

    Args:
        question: The user's question with the "galaxy brain" trigger phrase removed.
        context: Optional prior-turn context the larger model should consider.

    Returns:
        The model's answer as plain text. Deliver verbatim.
    """
    return _escalate(GALAXY_BRAIN_MODEL, question, context)


if __name__ == "__main__":
    mcp.run()
