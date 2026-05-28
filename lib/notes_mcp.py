"""MCP server exposing CRUD operations on Apple Notes via AppleScript.

Cicero writes into a single iCloud folder ("Cicero") that Carlos has shared
with cicero.ortega@icloud.com and Sarah. New notes created inside that folder
inherit the share automatically — that is how Apple Notes collaboration works.

AppleScript is the only programmatic surface for Notes; the public Notes API
does not expose sharing, collaboration links, or smart folders. So this MCP
deliberately does not try to share notes itself.

Stdio transport. Registered via:
    openclaw mcp set cicero-notes '{
      "command": "<env python>",
      "args":    ["<repo>/lib/notes_mcp.py"]
    }'
"""

from __future__ import annotations

import re
import subprocess

from mcp.server.fastmcp import FastMCP

DEFAULT_FOLDER = "Cicero"
OSASCRIPT_TIMEOUT_SEC = 20

mcp = FastMCP("cicero-notes")


def _osascript(script: str) -> str:
    res = subprocess.run(
        ["osascript", "-e", script],
        capture_output=True,
        text=True,
        timeout=OSASCRIPT_TIMEOUT_SEC,
    )
    if res.returncode != 0:
        raise RuntimeError((res.stderr or "osascript failed").strip())
    return res.stdout.strip()


def _escape_html(s: str) -> str:
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def _markdown_to_html(md: str) -> str:
    """Minimal markdown → HTML. Notes.app renders HTML for the body property.

    Supports: ## / ### sub-headings (not #, reserved for the note title),
    blank lines as <br>, plain lines as <div>. Anything fancier (bold,
    links, lists) renders as plain text — fine for v1.
    """
    out: list[str] = []
    for line in md.split("\n"):
        if not line.strip():
            out.append("<br>")
            continue
        m = re.match(r"^(#{2,3})\s+(.*)$", line)
        if m:
            level = len(m.group(1))
            out.append(f"<h{level}>{_escape_html(m.group(2))}</h{level}>")
        else:
            out.append(f"<div>{_escape_html(line)}</div>")
    return "".join(out)


def _as_string(s: str) -> str:
    """Escape a Python string for inclusion inside an AppleScript double-quoted literal."""
    return s.replace("\\", "\\\\").replace('"', '\\"')


@mcp.tool()
def list_notes(folder: str = DEFAULT_FOLDER) -> dict:
    """List titles of notes in the given Notes folder (default: shared 'Cicero').

    Args:
        folder: Folder name. Defaults to the shared "Cicero" folder.

    Returns:
        {"folder": str, "titles": [str, ...]}
    """
    f = _as_string(folder)
    script = f'tell application "Notes" to get name of every note of folder "{f}"'
    out = _osascript(script)
    titles = [t.strip() for t in out.split(",")] if out else []
    return {"folder": folder, "titles": titles}


@mcp.tool()
def get_note(title: str, folder: str = DEFAULT_FOLDER) -> dict:
    """Return the body (HTML) of the first note matching `title` in `folder`.

    Args:
        title: Exact note title.
        folder: Folder name. Defaults to "Cicero".

    Returns:
        {"title": str, "folder": str, "body_html": str}
    """
    t = _as_string(title)
    f = _as_string(folder)
    script = f'tell application "Notes" to get body of note "{t}" of folder "{f}"'
    body = _osascript(script)
    return {"title": title, "folder": folder, "body_html": body}


@mcp.tool()
def create_note(title: str, body_markdown: str, folder: str = DEFAULT_FOLDER) -> dict:
    """Create a new note inside `folder`. Sharing is inherited from the folder.

    Use this for recipes, references, trip plans, and any longer-form capture
    that doesn't belong in Reminders.

    The wrapper handles title styling automatically (renders `title` as the
    Apple Notes Title style via `<h1>` plus a one-space `name:` property).
    Do NOT also include the title inside `body_markdown`, or you'll get
    duplicate titles in the rendered note.

    Args:
        title: Note title. Rendered as the first line (auto-styled as the
               note title by Notes.app).
        body_markdown: Body in minimal markdown. # / ## / ### headings, blank
                       lines, and plain lines are supported. Anything fancier
                       renders as plain text. Do NOT include the title here.
        folder: Folder name. Defaults to "Cicero".

    Returns:
        {"ok": True, "title": str, "folder": str}
    """
    f = _as_string(folder)
    # Title style: <h1> in the body gives the proper Apple Notes "Title"
    # styling (large, bold). The AppleScript `name:` property must be set to
    # a single space — leaving it unset or empty makes Notes auto-derive a
    # title from the first body line, which then duplicates with the <h1>.
    body_html = f"<h1>{_escape_html(title)}</h1>" + _markdown_to_html(body_markdown)
    body = _as_string(body_html)
    script = (
        f'tell application "Notes" to tell folder "{f}" to '
        f'make new note with properties {{name:" ", body:"{body}"}}'
    )
    _osascript(script)
    return {"ok": True, "title": title, "folder": folder}


@mcp.tool()
def append_to_note(title: str, body_markdown: str, folder: str = DEFAULT_FOLDER) -> dict:
    """Append markdown content to an existing note's body.

    Warning: AppleScript edits strip or break embedded images and attachments.
    Avoid using this on notes that contain photos, scanned documents, or
    file attachments — create a follow-up note instead.

    Args:
        title: Exact title of the existing note.
        body_markdown: Content to append (markdown, same dialect as create_note).
        folder: Folder name. Defaults to "Cicero".

    Returns:
        {"ok": True, "title": str, "folder": str}
    """
    t = _as_string(title)
    f = _as_string(folder)
    addition = _as_string(_markdown_to_html(body_markdown))
    script = (
        f'tell application "Notes" to tell folder "{f}" to '
        f'set body of note "{t}" to (body of note "{t}") & "{addition}"'
    )
    _osascript(script)
    return {"ok": True, "title": title, "folder": folder}


if __name__ == "__main__":
    mcp.run()
