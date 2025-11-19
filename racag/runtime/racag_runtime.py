"""
RACAG Runtime Orchestrator
==========================

This is the high-level pipeline that ties together:

    1. QueryEngine → retrieve candidates
    2. ReRanker     → semantic sorting using GPT-4.1-mini
    3. Assembler    → merging, dedupe, token-trim, formatting

This file exposes a single clean call:

        run_racag(query: str) -> dict

Which produces the final LLM-ready "Context Packet"
(used by Copilot, VSCode, or the Kairos iOS adapter).
"""

from __future__ import annotations
from typing import Dict, Any, List

from racag.query.query_engine import QueryEngine
from racag.reranker.rerank_engine import ReRanker
from racag.context.context_assembler import assemble_context


# ============================================================
# Instantiate global components (cached, not recreated per call)
# ============================================================

query_engine = QueryEngine()
reranker = ReRanker()


# ============================================================
# MAIN PIPELINE
# ============================================================

def run_racag(query: str, *, max_final: int = 3) -> Dict[str, Any]:
    """
    Executes the full RACAG pipeline:

        query → retrieve → rerank → assemble → output

    Returns a dict:
    {
        status: "success",
        query: "...",
        context: "...",
        chunks_used: N,
        details: {...}
    }
    """

    # --------------------------------------------------------
    # Step 1 — Retrieve candidates
    # --------------------------------------------------------
    retrieved = query_engine.search(query=query)

    if retrieved["status"] != "success" or len(retrieved.get("results", [])) == 0:
        return {
            "status": "no_results",
            "query": query,
            "context": "",
            "chunks_used": 0,
            "details": {"retrieval": retrieved},
        }

    # --------------------------------------------------------
    # Step 2 — Reranking (GPT-4.1-mini)
    # --------------------------------------------------------
    reranked = reranker.rerank(
        query=query,
        chunks=retrieved["results"],
        top_k=max_final,
    )

    if reranked["status"] != "success":
        return {
            "status": "error",
            "query": query,
            "context": "",
            "chunks_used": 0,
            "details": {"retrieval": retrieved, "rerank": reranked},
        }

    # Replace the original candidates with reranked subset
    refined_results = {
        "status": "success",
        "query": query,
        "results": reranked["results"],
    }

    # --------------------------------------------------------
    # Step 3 — Assemble final context packet
    # --------------------------------------------------------
    final_packet = assemble_context(refined_results)

    # --------------------------------------------------------
    # Combine metadata for debugging, tracing, logging
    # --------------------------------------------------------
    final_packet["details"] = {
        "retrieval_count": len(retrieved.get("results", [])),
        "reranked_count": len(reranked.get("results", [])),
        "retrieval": retrieved,
        "rerank": reranked,
    }

    return final_packet


# ============================================================
# Manual test hook
# ============================================================

if __name__ == "__main__":
    print("RACAG runtime ✓ ready")
    q = "Where is the negotiation engine state machine implemented?"
    out = run_racag(q)
    print("\n--- RACAG CONTEXT ---\n")
    print(out["context"])