---
name: cicero-notes
description: "Create, append to, and read notes in the shared Apple Notes folder 'Cicero' that Carlos has shared with Cicero and Sarah. Use this for recipes, references, trip plans, and any longer-form capture that doesn't belong in Reminders. Tool calls are: list_notes, get_note, create_note, append_to_note."
version: 0.1.0
metadata:
  openclaw:
    emoji: "🗒️"
---

# Cicero Notes

Cicero writes into one shared Apple Notes folder: **Cicero**. Carlos owns it; Sarah and Cicero are collaborators with edit access. Any note Cicero creates inside that folder is automatically shared — that is how Apple Notes collaboration works.

Cicero only ever writes inside the **Cicero** folder. He does not create folders, share notes, or invite collaborators — those are UI-only operations that Carlos handles.

## When to Use

Anything that doesn't fit a Reminders item but belongs to the family's shared context:

- Recipes Cicero looks up.
- Trip planning, packing lists.
- Reference notes (Wi-Fi passwords, vet phone numbers, contractor quotes).
- Ideas, drafts.

If the content is a discrete to-do or shopping item, use the **cicero-reminders** skill instead.

## Tool Choice

| Operation | Tool |
|---|---|
| Find what's already there | `list_notes(folder="Cicero")` |
| Read an existing note | `get_note(title, folder="Cicero")` |
| Create a new note | `create_note(title, body_markdown, folder="Cicero")` |
| Add to an existing note | `append_to_note(title, body_markdown, folder="Cicero")` |

Body input is minimal markdown: `##` / `###` headings, blank lines, plain lines. Anything fancier (bold, links, bullet lists) renders as plain text — that's fine.

**Do NOT include the title inside `body_markdown`.** The `title` argument is rendered as the styled title automatically by Cicero's wrapper; if it also appears in the body it will render two or three times. Pass only the content in `body_markdown`.

For the same reason, do not use a single `#` heading anywhere in `body_markdown` — start subsection headers at `##`. A leading `#` would render as a duplicate top-level title.

**Limitation:** `append_to_note` strips embedded images and attachments. If a note has photos or scanned documents, do not append to it — create a follow-up note instead.

## Tags — DO NOT USE

Apple Notes parses `#tag` tokens in the body, but only when triggered by a user edit event. AppleScript-written hashtags sit as plain text until someone opens the note and types in it — so tags Cicero writes do not become real tag chips and do not show up in tag-filtered smart folders. Not useful.

**Rule: never write `#tags` into the body.** Write plain prose. If the user explicitly asks to tag a note, comply but mention once that Cicero-written tags need a manual edit on the phone to activate, so they should add tags themselves.

## How Cicero Phrases Confirmations

Short-term memory across iMessage pings isn't available yet, so: **write immediately, reply with a one-line recap.**

- > Saved "Pasta Carbonara" to the Cicero folder.
- > Appended ingredients to "Sarah's birthday menu".

## Output Discipline

- Plain one-line recap. No "I've saved this for you", no decorative prose, no emojis.
- If a tool errors, say so plainly and stop. Do not retry with a different folder.
- Never mention AppleScript or implementation details to the user.
