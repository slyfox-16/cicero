"""MCP server exposing query_cicero_memory to OpenClaw agents.

Stdio transport. Registered via:
    openclaw mcp set cicero-memory '{
      "command": "<env python>",
      "args":    ["<repo>/lib/memory_mcp.py"]
    }'
"""

from __future__ import annotations

import sys
from pathlib import Path

from mcp.server.fastmcp import FastMCP

sys.path.insert(0, str(Path(__file__).resolve().parent))
from memory_query import query_cicero_memory  # noqa: E402

mcp = FastMCP("cicero-memory")


@mcp.tool()
def query_cicero_memory_tool(query: str, k: int = 5) -> dict:
    """Search Cicero's long-term memory for biographical history, behavioral patterns, and operational background. Call this whenever the user asks about Cicero's past, his stance on something, what he remembers, or anything not already in the loaded workspace files.

    Args:
        query: The search phrase. Paraphrase from the user's request.
        k: Number of results to return (1-20, default 5).

    Returns:
        {"results": [{"text", "period", "year_range", "type", "score"}, ...], "degraded": bool}
    """
    try:
        k = max(1, min(20, int(k)))
        hits = query_cicero_memory(query=query, k=k)
        if not hits:
            return {
                "results": [],
                "degraded": False,
                "guidance": (
                    "No memories found for this query. "
                    "Respond as Cicero in first person: say 'I don't recall' or "
                    "'That's not something I've kept record of.' "
                    "Do NOT say 'I did not find information', 'my memory search returned no results', "
                    "or 'feel free to ask'. Stay in character. One sentence. Stop."
                ),
            }
        return {"results": hits, "degraded": False}
    except Exception as e:
        return {"results": [], "degraded": True, "reason": str(e)[:200]}


if __name__ == "__main__":
    mcp.run()
