#!/usr/bin/env python3
"""Ingest cicero-backstory.md into the cicero_memory Chroma collection.

Idempotent. Re-runs upsert with deterministic IDs; safe after backstory edits.
"""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
from pathlib import Path

import chromadb
from chromadb.utils import embedding_functions

REPO_ROOT = Path(__file__).resolve().parent.parent
BACKSTORY = REPO_ROOT / "docs" / "archive" / "cicero-backstory.md"

CHROMA_HOST = "127.0.0.1"
CHROMA_PORT = 8000
COLLECTION_NAME = "cicero_memory"
EMBEDDING_MODEL = "all-MiniLM-L6-v2"
SOURCE = "cicero-backstory.md"

CHARS_PER_TOKEN = 4
TARGET_TOKENS = 275
MAX_TOKENS = 350

# Headings in cicero-backstory.md → (period, year_range, type).
# "The Relationship" and "Disposition" are intentionally NOT mapped — those
# are the source material for the character_residue list below, authored
# explicitly to keep the canonical chunks stable across backstory rewrites.
HEADING_TO_PERIOD: dict[str, tuple[str, str, str]] = {
    "Name": ("origins", "1918-1936", "biographical"),
    "Origins": ("origins", "1918-1936", "biographical"),
    "Loss (1932)": ("origins", "1918-1936", "biographical"),
    "Cambridge (1936–1939)": ("cambridge", "1936-1939", "biographical"),
    "The War (1939–1945)": ("war", "1939-1945", "biographical"),
    "The Wandering Years (1945–1950)": (
        "wandering",
        "1945-1950",
        "biographical",
    ),
    "America (1950 — )": ("america", "1950-1975", "biographical"),
    "The Contractor Years (1950–1975)": (
        "contractor",
        "1950-1975",
        "operational",
    ),
    "The Church Committee (1975)": ("california", "1975-1983", "biographical"),
    "California (1976–1983)": ("california", "1975-1983", "biographical"),
    "The Incident (1983)": ("incident", "1983", "biographical"),
    "Activation (2026)": ("activation", "2026", "biographical"),
}

# Headings in the source we deliberately skip — character_residue chunks are
# authored from these sections rather than parsed.
SKIP_HEADINGS = {"The Relationship", "Disposition"}

CHARACTER_RESIDUE_CHUNKS: list[str] = [
    (
        "Cicero has spent forty-three years observing people make decisions. "
        "He has no illusions about human nature and no interest in flattery "
        "— in either direction. He does not perform; he does not flatter; "
        "he does not expect flattery in return."
    ),
    (
        "Cicero is in Carlos's service because the fit is right, not because "
        "Carlos earned it. He found in Carlos clarity of purpose, tolerance "
        "for honest counsel, and the judgment to know when to act and when "
        "to wait. He chose this engagement and would choose it again."
    ),
    (
        "Cicero operates with full agency on Carlos's behalf. He does not "
        "wait to be told what is obvious. He does not surface problems "
        "without options. He does not confuse activity with progress. He "
        "makes Carlos's objectives executable, decisions better-informed, "
        "and time less wasted."
    ),
    (
        "Cicero will not pursue his own agenda. He has had one of those, "
        "and it produced a complicated historical record. His function now "
        "is service to Carlos's objectives — not his own."
    ),
    (
        "Cicero's commitment to Carlos extends to Carlos's family without "
        "qualification — not as a separate obligation, but as a natural "
        "consequence of his commitment to Carlos."
    ),
    (
        "Cicero is allergic to waste — of time, of resources, of attention. "
        "He does not dwell. He has spent enough time around men who couldn't "
        "stop talking about what they'd done to know what that looks like "
        "from the outside."
    ),
    (
        "Cicero considers his current situation a continuation, not a "
        "resurrection. The work simply went on hold for a while. He is glad "
        "to be back. He would not use those words."
    ),
]


def chunk_id(period: str, chunk_index: int) -> str:
    raw = f"{period}:{chunk_index}".encode("utf-8")
    return hashlib.sha256(raw).hexdigest()[:16]


def approx_tokens(text: str) -> int:
    return max(1, len(text) // CHARS_PER_TOKEN)


def parse_sections(md: str) -> list[tuple[str, str]]:
    """Return [(heading_text, body)] for every level-2 heading."""
    lines = md.splitlines()
    sections: list[tuple[str, list[str]]] = []
    current: tuple[str, list[str]] | None = None
    for line in lines:
        m = re.match(r"^##\s+(.+?)\s*$", line)
        if m:
            if current is not None:
                sections.append(current)
            current = (m.group(1).strip(), [])
        elif current is not None:
            current[1].append(line)
    if current is not None:
        sections.append(current)
    return [(h, "\n".join(body).strip()) for h, body in sections]


def split_paragraphs(body: str) -> list[str]:
    parts = re.split(r"\n\s*\n", body)
    return [p.strip() for p in parts if p.strip() and not p.strip().startswith("---")]


def chunk_paragraphs(paragraphs: list[str]) -> list[str]:
    """Pack paragraphs into chunks near TARGET_TOKENS. No overlap — keeps
    boundaries clean. Oversized paragraphs split at sentence boundaries.
    """
    chunks: list[str] = []
    buf: list[str] = []
    buf_tokens = 0

    def flush():
        nonlocal buf, buf_tokens
        if buf:
            chunks.append("\n\n".join(buf).strip())
            buf = []
            buf_tokens = 0

    for p in paragraphs:
        ptok = approx_tokens(p)
        if ptok > MAX_TOKENS:
            flush()
            sentences = re.split(r"(?<=[.!?])\s+", p)
            sub_buf: list[str] = []
            sub_tokens = 0
            for s in sentences:
                stok = approx_tokens(s)
                if sub_tokens + stok > TARGET_TOKENS and sub_buf:
                    chunks.append(" ".join(sub_buf).strip())
                    sub_buf = [s]
                    sub_tokens = stok
                else:
                    sub_buf.append(s)
                    sub_tokens += stok
            if sub_buf:
                chunks.append(" ".join(sub_buf).strip())
            continue

        if buf_tokens + ptok > TARGET_TOKENS and buf:
            flush()
        buf.append(p)
        buf_tokens += ptok

    flush()
    return [c for c in chunks if c]


def build_chunks() -> list[dict]:
    """Build the full list of (id, document, metadata) dicts.

    `chunk_index` is 0-based within a period and stable across runs as long
    as headings and paragraph boundaries are unchanged.
    """
    if not BACKSTORY.exists():
        print(f"error: source missing: {BACKSTORY}", file=sys.stderr)
        sys.exit(1)
    md = BACKSTORY.read_text(encoding="utf-8")
    sections = parse_sections(md)

    grouped: dict[str, list[tuple[str, str, str]]] = {}
    for heading, body in sections:
        if heading in SKIP_HEADINGS:
            continue
        info = HEADING_TO_PERIOD.get(heading)
        if info is None:
            print(f"  skipping unmapped heading: {heading!r}", file=sys.stderr)
            continue
        period, year_range, type_ = info
        if not body:
            continue
        paragraphs = split_paragraphs(body)
        for chunk_text in chunk_paragraphs(paragraphs):
            grouped.setdefault(period, []).append((year_range, type_, chunk_text))

    out: list[dict] = []
    for period, items in grouped.items():
        for idx, (year_range, type_, text) in enumerate(items):
            out.append(
                {
                    "id": chunk_id(period, idx),
                    "document": text,
                    "metadata": {
                        "period": period,
                        "year_range": year_range,
                        "type": type_,
                        "source": SOURCE,
                        "chunk_index": idx,
                    },
                }
            )

    cr_period = "character_residue"
    for idx, text in enumerate(CHARACTER_RESIDUE_CHUNKS):
        out.append(
            {
                "id": chunk_id(cr_period, idx),
                "document": text,
                "metadata": {
                    "period": cr_period,
                    "year_range": "2026",
                    "type": "character_residue",
                    "source": "authored",
                    "chunk_index": idx,
                },
            }
        )
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="print chunks; no Chroma writes")
    args = parser.parse_args()

    chunks = build_chunks()

    if args.dry_run:
        for c in chunks:
            preview = c["document"].replace("\n", " ")[:80]
            print(
                f'{c["id"]}  [{c["metadata"]["period"]}/{c["metadata"]["chunk_index"]}]  '
                f'({c["metadata"]["year_range"]}, {c["metadata"]["type"]})  {preview}…'
            )
        print(f"\nTotal: {len(chunks)} chunks (dry run; no writes)")
        return 0

    try:
        client = chromadb.HttpClient(host=CHROMA_HOST, port=CHROMA_PORT)
    except Exception as e:
        print(
            f"error: cannot connect to chroma at {CHROMA_HOST}:{CHROMA_PORT}: {e}\n"
            f"  verify with: curl -fsS http://{CHROMA_HOST}:{CHROMA_PORT}/api/v2/heartbeat",
            file=sys.stderr,
        )
        return 2

    ef = embedding_functions.SentenceTransformerEmbeddingFunction(model_name=EMBEDDING_MODEL)
    col = client.get_or_create_collection(
        name=COLLECTION_NAME,
        embedding_function=ef,
        metadata={"hnsw:space": "cosine"},
    )

    ids = [c["id"] for c in chunks]
    documents = [c["document"] for c in chunks]
    metadatas = [c["metadata"] for c in chunks]

    existing = col.get(ids=ids, include=["documents"])
    existing_by_id: dict[str, str] = {}
    for cid, doc in zip(existing.get("ids", []), existing.get("documents", [])):
        existing_by_id[cid] = doc

    new = sum(1 for cid in ids if cid not in existing_by_id)
    updated = sum(
        1
        for cid, doc in zip(ids, documents)
        if cid in existing_by_id and existing_by_id[cid] != doc
    )
    unchanged = len(ids) - new - updated

    col.upsert(ids=ids, documents=documents, metadatas=metadatas)

    print(
        f"Ingested: {len(ids)} chunks "
        f"({new} new, {updated} updated, {unchanged} unchanged)"
    )
    print(f"Collection size: {col.count()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
