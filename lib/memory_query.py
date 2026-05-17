from __future__ import annotations

import os
from typing import Literal, Optional, TypedDict

os.environ.setdefault("HF_HUB_OFFLINE", "1")
os.environ.setdefault("TRANSFORMERS_OFFLINE", "1")
os.environ.setdefault("ANONYMIZED_TELEMETRY", "False")

import chromadb  # noqa: E402
from chromadb.utils import embedding_functions  # noqa: E402

CHROMA_HOST = "127.0.0.1"
CHROMA_PORT = 8000
COLLECTION_NAME = "cicero_memory"
EMBEDDING_MODEL = "all-MiniLM-L6-v2"

_COLLECTION = None

PeriodLiteral = Literal[
    "origins",
    "cambridge",
    "war",
    "wandering",
    "america",
    "contractor",
    "california",
    "incident",
    "dormancy",
    "activation",
    "character_residue",
]
TypeLiteral = Literal["biographical", "operational", "character_residue"]


class MemoryHit(TypedDict):
    text: str
    period: str
    year_range: str
    type: str
    score: float
    chunk_id: str


def _get_collection():
    global _COLLECTION
    if _COLLECTION is None:
        client = chromadb.HttpClient(host=CHROMA_HOST, port=CHROMA_PORT)
        ef = embedding_functions.SentenceTransformerEmbeddingFunction(
            model_name=EMBEDDING_MODEL
        )
        _COLLECTION = client.get_or_create_collection(
            name=COLLECTION_NAME,
            embedding_function=ef,
            metadata={"hnsw:space": "cosine"},
        )
    return _COLLECTION


def _build_where(
    period: Optional[str], type_filter: Optional[str]
) -> Optional[dict]:
    clauses = []
    if period:
        clauses.append({"period": period})
    if type_filter:
        clauses.append({"type": type_filter})
    if not clauses:
        return None
    if len(clauses) == 1:
        return clauses[0]
    return {"$and": clauses}


def query_cicero_memory(
    query: str,
    k: int = 5,
    score_threshold: float = 0.30,
    period: Optional[PeriodLiteral] = None,
    type_filter: Optional[TypeLiteral] = None,
) -> list[MemoryHit]:
    try:
        col = _get_collection()
        where = _build_where(period, type_filter)
        res = col.query(
            query_texts=[query],
            n_results=k,
            where=where,
        )
    except Exception:
        return []

    docs = (res.get("documents") or [[]])[0]
    metas = (res.get("metadatas") or [[]])[0]
    ids = (res.get("ids") or [[]])[0]
    distances = (res.get("distances") or [[]])[0]

    hits: list[MemoryHit] = []
    for text, meta, cid, dist in zip(docs, metas, ids, distances):
        score = max(0.0, min(1.0, 1.0 - (float(dist) / 2.0)))
        if score < score_threshold:
            continue
        hits.append(
            MemoryHit(
                text=text,
                period=str(meta.get("period", "")),
                year_range=str(meta.get("year_range", "")),
                type=str(meta.get("type", "")),
                score=score,
                chunk_id=cid,
            )
        )
    hits.sort(key=lambda h: h["score"], reverse=True)
    return hits
