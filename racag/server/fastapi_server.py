"""
FastAPI Server for RACAG
========================

This file creates an HTTP API around the RACAG engine.
It is safe for production and usable by:

- Kairos Amiqo iOS app
- Android app (future)
- GCP Cloud Run
- Fastify backend
- Local dev

Endpoint:
    POST /racag/query

Request JSON:
{
    "query": "text",
    "max_chunks": 3,
    "include_raw": false
}

Response JSON:
{
    "ok": true,
    "query": "...",
    "context": "...",
    "chunks_used": [...],
    "tokens_context": 421,
    "tokens_estimated_total": 598
}
"""

from __future__ import annotations
import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from racag.adapters.backend_adapter import build_backend_response


# -------------------------------
# Request schema
# -------------------------------
class RACAGRequest(BaseModel):
    query: str
    max_chunks: int | None = None
    include_raw: bool = False


# -------------------------------
# FastAPI app
# -------------------------------
app = FastAPI(
    title="Kairos RACAG Server",
    description="Retrieval-Augmented Context-Aware Generator for Kairos Amiqo",
    version="1.0.0",
)

# CORS – allow mobile apps, web apps, CLI, etc.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],            # For production: restrict to your domains
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
async def home():
    return {"status": "ok", "message": "RACAG FastAPI server running"}


@app.post("/racag/query")
async def racag_query(request: RACAGRequest):
    """
    Accepts a RACAG query request and returns structured JSON.
    """

    result = build_backend_response(
        query=request.query,
        max_chunks=request.max_chunks,
        include_raw_chunks=request.include_raw
    )

    return result


# -------------------------------
# Local dev runner
# -------------------------------
def start_dev_server(host="0.0.0.0", port=8000):
    uvicorn.run(
        "racag.server.fastapi_server:app",
        host=host,
        port=port,
        reload=True,
    )


if __name__ == "__main__":
    start_dev_server()