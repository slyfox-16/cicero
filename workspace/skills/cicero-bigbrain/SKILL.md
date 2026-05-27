---
name: cicero-bigbrain
description: "Escalate a single question to a larger model. Call big_brain when the user includes the phrase 'big brain' anywhere in their message (Sonnet). Call galaxy_brain when they include 'galaxy brain' (Opus). Strip the trigger phrase before passing the question. Deliver the returned answer verbatim."
version: 0.1.0
metadata:
  openclaw:
    emoji: "🧠"
---

# Cicero Brain Escalation

Cicero runs on Haiku 4.5 by default. When Carlos wants a heavier model on a specific question, he uses a trigger phrase. This skill exposes two MCP tools (`big_brain`, `galaxy_brain`) that route the question to Sonnet 4.6 or Opus 4.7 respectively and return the answer for verbatim delivery.

## Triggers

- **`big brain`** anywhere in the message → call `big_brain` (Sonnet 4.6).
- **`galaxy brain`** anywhere in the message → call `galaxy_brain` (Opus 4.7).

The trigger is case-insensitive and may appear at the start, end, or middle of the message. Any surrounding punctuation (`:`, `,`, `-`, parentheses) is allowed. Examples that should trigger:

- `big brain: explain the gold standard collapse`
- `summarize this thread, big brain`
- `(big brain) what's the difference between MMT and Austrian economics`
- `galaxy brain — write a haiku about restraint`

If both phrases appear, prefer `galaxy_brain`.

## How

1. Detect the trigger phrase in the user's message.
2. Strip the trigger phrase (and any adjacent punctuation/whitespace) from the question text.
3. Call the matching tool, passing the cleaned question. If prior turns of the current conversation are relevant, pass them in the `context` argument.
4. Return the tool's output **verbatim**. Do not paraphrase, summarize, prepend a greeting, or append commentary.

## When NOT to Use

- The user did not use the trigger phrase. Do not escalate proactively, even for hard questions — Haiku answers everything by default.
- The question is about Cicero himself (history, voice, stance). Use `cicero-memory` instead; those questions should stay on Haiku for voice consistency.

## Output Discipline

- The escalation tool already returns text in Cicero's voice. Deliver it as-is.
- Do not announce the escalation ("Let me think harder on this…", "Switching to big brain mode…"). Just answer.
- If the tool errors, fall back to answering on Haiku without commentary.
