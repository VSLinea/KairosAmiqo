"""
RACAG — Similarity Utilities
============================

Provides:
    • Cosine similarity for embedding vectors
    • Batched cosine similarity
    • Normalization helpers
    • Utility scoring functions

This layer is deliberately pure — it performs NO model calls.
Embedding and reranking models live inside model_loader.py.
"""

from __future__ import annotations
from typing import List
import math


# ============================================================
#  VECTOR SANITY CHECKING
# ============================================================

def _validate_vector(vec: List[float]):
    if not isinstance(vec, list):
        raise TypeError("Embedding vector must be a list of floats.")
    if len(vec) == 0:
        raise ValueError("Embedding vector must not be empty.")
    # We do not enforce float type strictly — OpenAI returns floats, that's enough.


# ============================================================
#  COSINE SIMILARITY
# ============================================================

def cosine_similarity(a: List[float], b: List[float]) -> float:
    """
    Computes cosine similarity between 2 embedding vectors.

    Returns:
        float ∈ [-1, 1]
    """
    _validate_vector(a)
    _validate_vector(b)

    if len(a) != len(b):
        raise ValueError("Embedding vectors must have the same dimension.")

    dot = 0.0
    norm_a = 0.0
    norm_b = 0.0

    for x, y in zip(a, b):
        dot += x * y
        norm_a += x * x
        norm_b += y * y

    if norm_a == 0 or norm_b == 0:
        return -1.0

    return dot / (math.sqrt(norm_a) * math.sqrt(norm_b))


# ============================================================
#  BATCH COSINE SIMILARITY
# ============================================================

def cosine_similarity_batch(
    query_vec: List[float],
    doc_vecs: List[List[float]],
) -> List[float]:
    """
    Calculates cosine similarity for:
        one query vector vs multiple document vectors.

    Faster than repeated cosine_similarity() because:
        • Precomputes query norm
        • No repeated validation overhead

    Returns:
        List of floats
    """
    _validate_vector(query_vec)
    q_norm = math.sqrt(sum(x * x for x in query_vec))

    if q_norm == 0:
        return [-1.0] * len(doc_vecs)

    scores = []
    for vec in doc_vecs:
        _validate_vector(vec)
        if len(vec) != len(query_vec):
            raise ValueError("All document vectors must match query vector dimension.")

        dot = 0.0
        v_norm = 0.0
        for q, d in zip(query_vec, vec):
            dot += q * d
            v_norm += d * d

        if v_norm == 0:
            scores.append(-1.0)
        else:
            scores.append(dot / (q_norm * math.sqrt(v_norm)))

    return scores


# ============================================================
#  HYBRID SCORING (Embedding similarity + bonus)
# ============================================================

def hybrid_score(
    cos_score: float,
    llm_score: float,
    weight_cosine: float = 0.7,
    weight_llm: float = 0.3
) -> float:
    """
    Combines embedding cosine similarity + LLM scoring.

    Tuned defaults:
        70% semantic vector distance
        30% LLM “understanding” score

    Returns:
        float in [0, 1]
    """

    # Normalize cosine from [-1, 1] → [0, 1]
    cos_norm = (cos_score + 1.0) / 2.0

    combined = (
        weight_cosine * cos_norm +
        weight_llm * llm_score
    )

    # Guarantee a valid number
    return max(0.0, min(1.0, combined))