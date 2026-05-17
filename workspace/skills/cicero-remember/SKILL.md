---
name: cicero-remember
description: Directly query Cicero's biographical memory. Use /remember to retrieve backstory facts without relying on model routing.
user-invocable: true
command-dispatch: tool
command-tool: query_cicero_memory_tool
command-arg-mode: raw
---

When this skill is invoked via /remember, pass the user's query directly
to query_cicero_memory_tool with k=3. Return the results clearly formatted.
Do not interpret, embellish, or add context not present in the retrieved chunks.
If nothing is retrieved, say so plainly.
