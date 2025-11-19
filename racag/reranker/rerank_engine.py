"""
RACAG — Rerank Engine
=====================

Pipeline:
    1. Embedding similarities (text-embedding-3-large)
    2. LLM semantic rerank (gpt-4.1-mini)
    3. Hybrid scoring → Top-3 / Top-5 / Top-8 dynamic output

Dependencies:
    • model_loader.py
    • similarity.py
"""

from __future__ import annotations
import logging
from typing import List, Dict
from racag.reranker.similarity import (
    cosine_similarity_batch,
    hybrid_score,
)
from racag.reranker.model_loader import (
    get_rerank_client,
    get_rerank_model_name,
)

logger = logging.getLogger("racag.reranker")

# ============================================================
#  CONFIG
# ============================================================

LLM_MODEL = get_rerank_model_name()

# Thresholds for dynamic expansion
THRESH_TOP5 = 0.55
THRESH_TOP8 = 0.40

# ============================================================
#  RERANK ENGINE
# ============================================================

def rerank_results(
    query_text: str,
    query_vec: List[float],
    candidates: List[Dict],
    top_k_base: int = 3,
) -> List[Dict]:
    """
    Full rerank pipeline:
        • Compute cosine scores for all candidates
        • Send top-12 to the LLM (hard cap to limit cost)
        • Combine into hybrid score
        • Dynamic Top-3 → Top-5 → Top-8 expansion
    """

    # -------------------------
    # Step 1 — cosine similarity
    # -------------------------
    doc_vecs = [c["embedding"] for c in candidates]
    cos_scores = cosine_similarity_batch(query_vec, doc_vecs)

    # Attach cosine to each candidate
    for c, score in zip(candidates, cos_scores):
        c["cosine"] = float(score)

    # Sort by cosine descending
    candidates.sort(key=lambda x: x["cosine"], reverse=True)

    # -------------------------
    # Step 2 — Pick top ~12 for LLM rerank
    # -------------------------
    llm_pool = candidates[:12]

    try:
        rerank_client = get_rerank_client()

        # Build prompt for batch scoring
        prompt = _build_rerank_prompt(query_text, llm_pool)

        llm_scores = rerank_client.chat.completions.create(
            model=LLM_MODEL,
            messages=[{"role": "user", "content": prompt}],
            max_tokens=32,
            temperature=0,
        )

        # Extract scores (0–1)
        raw_response = llm_scores.choices[0].message.content or ""
        llm_values = _parse_llm_scores(raw_response)
    except Exception as exc:  # pragma: no cover - defensive fall back to cosine-only rerank
        logger.warning("LLM rerank failed; falling back to cosine only: %s", exc)
        llm_values = [0.0] * len(llm_pool)

    # Attach LLM score to each pool doc
    if len(llm_values) < len(llm_pool):
        llm_values.extend([0.0] * (len(llm_pool) - len(llm_values)))
    elif len(llm_values) > len(llm_pool):
        llm_values = llm_values[:len(llm_pool)]

    for c, s in zip(llm_pool, llm_values):
        c["llm_score"] = float(s)

    # For docs beyond top-12, assign fallback 0.0
    for c in candidates[12:]:
        c["llm_score"] = 0.0

    # -------------------------
    # Step 3 — hybrid score
    # -------------------------
    for c in candidates:
        c["hybrid"] = hybrid_score(
            c["cosine"],
            c["llm_score"],
        )

    # Final sort
    candidates.sort(key=lambda x: x["hybrid"], reverse=True)

    top_score = candidates[0]["hybrid"]

    # -------------------------
    # Step 4 — dynamic expansion
    # -------------------------

    if top_score >= THRESH_TOP5:
        final_k = top_k_base
    elif top_score >= THRESH_TOP8:
        final_k = 5
    else:
        final_k = 8

    return candidates[:final_k]


# ============================================================
#  HELPER: Build LLM Rerank Prompt
# ============================================================

def _build_rerank_prompt(query: str, docs: List[Dict]) -> str:
    """
    Produces a deterministic scoring prompt for GPT-4.1-mini.
    Returns scores only, no explanations.
    """
    lines = [
        "You are a semantic ranking model.",
        "Rate each document on how relevant it is to the query.",
        "Return ONLY a list of numbers (0–1, high = better).",
        "",
        f"Query:\n{query}\n",
        "Documents:",
    ]

    for idx, c in enumerate(docs, start=1):
        snippet = c["chunk_text"]
        if len(snippet) > 800:
            snippet = snippet[:800] + "…"

        lines.append(f"[{idx}]\n{snippet}\n")

    lines.append("Return relevance scores as:\n0.82, 0.65, 0.14 …")

    return "\n".join(lines)


# ============================================================
#  HELPER: Parse LLM numeric scores
# ============================================================

def _parse_llm_scores(text: str) -> List[float]:
    """
    Extracts floats from the rerank model output.
    Example input:
        "0.88, 0.63, 0.21"
    """
    import re

    nums = re.findall(r"[0-1]\.\d+", text)
    return [float(n) for n in nums]


# ============================================================
# Compatibility wrapper
# ============================================================


class ReRanker:
    """Compatibility wrapper so older imports continue to function."""

    def __init__(self, top_k_base: int = 3):
        self.top_k_base = top_k_base

    def rerank(self, query_text: str, query_vec, candidates: List[Dict]) -> List[Dict]:
        return rerank_results(
            query_text=query_text,
            query_vec=query_vec,
            candidates=candidates,
            top_k_base=self.top_k_base,
        )


# ============================================================
#  MAIN ENTRY (optional test hook)
# ============================================================

if __name__ == "__main__":
    print("Rerank engine loaded ✓")