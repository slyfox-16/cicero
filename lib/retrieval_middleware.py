"""Conditional retrieval middleware (Auto-RAG safety net).

Checks every user message against Cicero's Chroma memory. If the top
result exceeds SIMILARITY_THRESHOLD, returns a formatted context block
to prepend into the conversation. Returns None when the message is
unrelated to stored memory, injecting nothing.

Usage (from scripts/cicero or any wrapper):

    from retrieval_middleware import maybe_retrieve
    context = maybe_retrieve(user_message)
    if context:
        full_message = context + "\n\n" + user_message
    else:
        full_message = user_message
"""

from __future__ import annotations

import os
import sys
from pathlib import Path
from typing import Optional

os.environ.setdefault("HF_HUB_OFFLINE", "1")
os.environ.setdefault("TRANSFORMERS_OFFLINE", "1")
os.environ.setdefault("ANONYMIZED_TELEMETRY", "False")

sys.path.insert(0, str(Path(__file__).resolve().parent))
from memory_query import query_cicero_memory  # noqa: E402

SIMILARITY_THRESHOLD = 0.60
TOP_K = 3

_CONTEXT_HEADER = (
    "[RETRIEVED MEMORY — inject before model call]\n"
    "The following context was retrieved from your long-term memory. "
    "These are YOUR experiences and recollections — you are Cicero. "
    "Respond in first person (say 'I', not 'Cicero'). "
    "Use this to answer accurately. Do not fabricate details not present here.\n"
)
_CONTEXT_FOOTER = "[END RETRIEVED MEMORY]"


def maybe_retrieve(user_message: str) -> Optional[str]:
    """Return a formatted memory context block if relevant hits exist, else None."""
    hits = query_cicero_memory(query=user_message, k=TOP_K, score_threshold=SIMILARITY_THRESHOLD)
    if not hits:
        return None

    chunks = "\n\n".join(h["text"] for h in hits)
    return f"{_CONTEXT_HEADER}\n{chunks}\n\n{_CONTEXT_FOOTER}"


if __name__ == "__main__":
    cases = [
        # (query, expect_hit)
        ("Tell me about Robert Cairns", True),
        ("Where did you grow up", True),
        ("What did you do during the war", True),
        ("Who taught you mathematics", True),
        ("Tell me about your time in Edinburgh", True),
        ("What is the weather today", False),
        ("Help me write an email", False),
        ("What time is it", False),
        ("Search the web for news", False),
        ("How do I cook pasta", False),
    ]
    passed = 0
    for query, expect_hit in cases:
        raw_hits = query_cicero_memory(query=query, k=1, score_threshold=0.0)
        top_score = raw_hits[0]["score"] if raw_hits else 0.0
        result = maybe_retrieve(query)
        hit = result is not None
        ok = hit == expect_hit
        passed += ok
        tag = "OK  " if ok else "FAIL"
        label = "backstory" if expect_hit else "unrelated"
        print(f"[{tag}] {top_score:.3f}  ({label})  {query!r}")
    print(f"\n{passed}/{len(cases)} passed  threshold={SIMILARITY_THRESHOLD}")
