from __future__ import annotations

from typing import List

from racag.reranker import model_loader as ml


def embed_query(text: str) -> List[float]:
    """Convert a single query string into an embedding vector."""

    return ml.embed_text(text)


def embed_queries(texts: List[str]) -> List[List[float]]:
    """Batch embed multiple query strings."""

    if not texts:
        return []
    return ml.embed_batch(texts)