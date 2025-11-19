"""
Backend Adapter for RACAG
=========================

This provides a clean API-facing interface around the RACAG engine.
It is designed to be consumed by:

- Fastify backend
- FastAPI / Flask backends
- GCP Cloud Run services
- Mobile clients (iOS/Android future)
- Local testing scripts

This adapter wraps RACAG output into stable JSON that external systems
can consume safely and consistently.
"""

from __future__ import annotations
from typing import Dict, Any

from racag.runtime.racag_runtime import run_racag


def build_backend_response(
    query: str,
    max_chunks: int | None = None,
    include_raw_chunks: bool = False
) -> Dict[str, Any]:
    """
    Execute the RACAG pipeline and return API-friendly JSON.

    Parameters:
        query (str): The user/system query.
        max_chunks (int): Optional cutoff for number of chunks used.
        include_raw_chunks (bool): Whether to include raw chunk data.

    Returns JSON like:

    {
        "ok": true,
        "query": "...",
        "context": "...",
        "chunks_used": [...],
        "raw_chunks": [...],    # optional
        "tokens_context": 3921,
        "tokens_estimated_total": 5700
    }
    """

    try:
        result = run_racag(query, max_chunks=max_chunks)

        response = {
            "ok": True,
            "query": query,
            "context": result["context"],
            "chunks_used": result.get("chunks_used", []),
            "tokens_context": result.get("tokens_context", None),
            "tokens_estimated_total": result.get("tokens_estimated_total", None),
        }

        if include_raw_chunks:
            response["raw_chunks"] = result.get("raw_chunks", [])

        return response

    except Exception as e:
        # Safe, structured backend error
        return {
            "ok": False,
            "error": {
                "type": type(e).__name__,
                "message": str(e),
            },
            "query": query,
        }