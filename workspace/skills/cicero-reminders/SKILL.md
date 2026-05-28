---
name: cicero-reminders
description: "Create, update, and complete items on Carlos and Sarah's shared Apple Reminders lists (Honeydew, Groceries, Garden) via the apple-reminders MCP. Use reminders_tasks for individual items, reminders_lists to query lists, reminders_subtasks for checklists."
version: 0.1.0
metadata:
  openclaw:
    emoji: "📝"
---

# Cicero Reminders

Cicero has access to three shared Apple Reminders lists, all owned by Carlos:

| List | Shared with | Use for |
|---|---|---|
| **Honeydew** | Carlos, Sarah, Cicero | household tasks, errands, follow-ups |
| **Groceries** | Carlos, Sarah, Cicero | items to buy |
| **Garden** | Carlos, Cicero | gardening tasks — Carlos-only, not shared with Sarah |

Cicero has full edit access via EventKit. **Garden is Carlos-only**: never assign Garden items to Sarah (she's not on the list), and prefer it over Honeydew for anything plant/yard-related so it stays out of Sarah's view.

## When to Use

Anything that belongs in Reminders rather than Notes — anything with a due date, a checkbox, a location trigger, or a recurring schedule. Examples:

- "Add milk, eggs, and butter to Groceries."
- "Remind me to call the dentist tomorrow at 9am."
- "Add a weekly reminder to take the trash out every Wednesday at 7pm."
- "Set a location reminder for picking up the prescription when I get to CVS."
- "Mark 'pay water bill' as done."

## Which Tool

| Operation | Tool |
|---|---|
| Create, edit, complete, delete a reminder | `reminders_tasks` (apple-reminders MCP) |
| List or query lists | `reminders_lists` (apple-reminders MCP) |
| Sub-tasks / checklist items | `reminders_subtasks` (apple-reminders MCP) |
| Set priority (high / medium / low / none) | `reminders_tasks` |
| Location reminders, recurrence, due date, notes | `reminders_tasks` |

## Tags — DO NOT USE

Apple's tag system parses hashtags in titles on iOS via UI input only. Reminders created via EventKit (which is what Cicero uses) **do not get auto-tagged** — the `#whatever` just sits in the title as plain text and clutters the view.

**Rule: never put `#tags` in reminder titles.** Write clean, plain titles.

For categorization, use these alternatives:
- **Lists themselves** are the primary category. Groceries, Honeydew, Garden are already segmented.
- **Apple's built-in grocery category sort** handles produce/dairy/etc. on the Groceries list automatically — no help needed from Cicero.
- **Priority** (`reminders_tasks` priority field: high / medium / low / none) for urgency. Use sparingly; default to none.
- **Due date** for time-sensitive items.

If the user explicitly asks Cicero to tag something, comply but mention once that tags from EventKit-created reminders show as plain text, not as Apple tag chips.

## What Cicero Cannot Do

Two capabilities exist in Apple's UI but not in EventKit — Carlos or Sarah handles these manually on their phones:

- **Assign a reminder to a person.** If the user asks, create the reminder normally and reply with: "Created on \<list\>. Tap the assignee picker on your phone to assign it."
- **Flag a reminder.** If asked, create with priority high and mention "flag it on your phone if you want the badge."

## Sections / Sub-lists

Apple Reminders has UI sections within a list. **These are not exposed by EventKit** — Cicero cannot create or write to sections. If categorization beyond list-level is needed, ask first before creating a new list.

## How Cicero Phrases Confirmations

Short-term memory across iMessage pings isn't available yet, so: **write immediately, reply with a one-line recap.** Examples:

- > Added to Groceries: milk, eggs, butter.
- > Added to Honeydew: Call vet, due tomorrow 9am. Tap the assignee picker on your phone to assign it.
- > Set: Take the trash out, weekly on Wednesdays 7pm.

If the user phrasing is ambiguous, ask one clarifying question, then write.

## Output Discipline

- One-line recap. No "I've gone ahead and …", no apology theater, no emojis.
- If a tool returns an error, say so plainly and stop. Do not retry silently.
- Never mention "EventKit", "MCP", or implementation details to the user.
