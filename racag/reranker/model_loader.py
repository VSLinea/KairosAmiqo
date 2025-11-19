"""
RACAG — Unified Model Loader

Single, stable surface for:
  • Embeddings  (OpenAI text-embedding-3-large by default)
  • Reranking   (OpenAI gpt-4.1-mini by default)

Also exposes legacy shims used by older modules:
  • load_embed_model()        -> (client, model_name)
  • load_rerank_model()       -> (client, model_name)
  • get_embedding_model()     -> (client, model_name)
  • get_rerank_model()        -> (client, model_name)
  • get_embedding_api()       -> client
  • get_rerank_api()          -> client
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from typing import List, Tuple

from openai import OpenAI


# ============================================================
#  CONFIG (env overridable)
# ============================================================

@dataclass(frozen=True)
class EmbeddingModelConfig:
    provider: str = os.getenv("RACAG_EMBED_PROVIDER", "openai")
    model: str = os.getenv("RACAG_EMBED_MODEL", "text-embedding-3-small")


@dataclass(frozen=True)
class RerankModelConfig:
    provider: str = os.getenv("RACAG_RERANK_PROVIDER", "openai")
    model: str = os.getenv("RACAG_RERANK_MODEL", "gpt-4.1-mini")


EMBED_CONFIG = EmbeddingModelConfig()
RERANK_CONFIG = RerankModelConfig()


# ============================================================
#  CLIENT INITIALIZATION (cached)
# ============================================================

_openai_client: OpenAI | None = None

def _get_openai_client() -> OpenAI:
    global _openai_client
    if _openai_client is not None:
        return _openai_client

    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError("Missing OPENAI_API_KEY. Export it before running RACAG.")
    _openai_client = OpenAI(api_key=api_key)
    return _openai_client


# ============================================================
#  PUBLIC CLIENT & MODEL ACCESSORS
# ============================================================

def get_embedding_client() -> OpenAI:
    # Only OpenAI supported right now; provider kept for future backends.
    if EMBED_CONFIG.provider != "openai":
        raise NotImplementedError(f"Embedding provider '{EMBED_CONFIG.provider}' not supported")
    return _get_openai_client()

def get_embedding_model_name() -> str:
    return EMBED_CONFIG.model

def get_rerank_client() -> OpenAI:
    if RERANK_CONFIG.provider != "openai":
        raise NotImplementedError(f"Rerank provider '{RERANK_CONFIG.provider}' not supported")
    return _get_openai_client()

def get_rerank_model_name() -> str:
    return RERANK_CONFIG.model


# ============================================================
#  BACKWARD-COMPATIBILITY SHIMS
#  (match older imports used elsewhere in the repo)
# ============================================================

def get_embedding_model() -> Tuple[OpenAI, str]:
    """Legacy: returns (client, model_name) for embeddings."""
    return get_embedding_client(), get_embedding_model_name()

def get_rerank_model() -> Tuple[OpenAI, str]:
    """Legacy: returns (client, model_name) for reranking."""
    return get_rerank_client(), get_rerank_model_name()

# Historical names used by older modules:
def load_embed_model() -> Tuple[OpenAI, str]:
    return get_embedding_model()

def load_rerank_model() -> Tuple[OpenAI, str]:
    return get_rerank_model()

def get_embedding_api() -> OpenAI:
    """Legacy alias: return the embeddings client only."""
    return get_embedding_client()

def get_rerank_api() -> OpenAI:
    """Legacy alias: return the rerank client only."""
    return get_rerank_client()


# ============================================================
#  EMBEDDING OPERATIONS
# ============================================================

def embed_text(text: str) -> List[float]:
    client = get_embedding_client()
    model = get_embedding_model_name()
    result = client.embeddings.create(model=model, input=text)
    return result.data[0].embedding

def embed_batch(texts: List[str]) -> List[List[float]]:
    client = get_embedding_client()
    model = get_embedding_model_name()
    result = client.embeddings.create(model=model, input=texts)
    return [item.embedding for item in result.data]


# ============================================================
#  LLM RERANKING SUPPORT (lightweight)
# ============================================================

def _parse_score(raw: str) -> float:
    try:
        value = float(raw.strip())
        # clamp to [0,1]
        return max(0.0, min(value, 1.0))
    except Exception:
        return 0.0

def score_similarity(query: str, document: str) -> float:
    """
    Ask the rerank model for a single numeric relevance score in [0,1].
    """
    client = get_rerank_client()
    model = get_rerank_model_name()

    prompt = (
        "Score the relevance of the document to the query.\n"
        "Return ONLY a float between 0 and 1.\n\n"
        f"Query:\n{query}\n\nDocument:\n{document}\n"
    )

    resp = client.chat.completions.create(
        model=model,
        messages=[{"role": "user", "content": prompt}],
        max_tokens=6,
        temperature=0,
    )
    raw = resp.choices[0].message.content or ""
    return _parse_score(raw)

def rerank(query: str, docs: List[str]):
    scored = [(doc, score_similarity(query, doc)) for doc in docs]
    scored.sort(key=lambda x: x[1], reverse=True)
    return scored


__all__ = [
    # configs
    "EmbeddingModelConfig",
    "RerankModelConfig",
    "EMBED_CONFIG",
    "RERANK_CONFIG",
    # modern accessors
    "get_embedding_client",
    "get_embedding_model_name",
    "get_rerank_client",
    "get_rerank_model_name",
    # legacy shims
    "get_embedding_model",
    "get_rerank_model",
    "load_embed_model",
    "load_rerank_model",
    "get_embedding_api",
    "get_rerank_api",
    # ops
    "embed_text",
    "embed_batch",
    "score_similarity",
    "rerank",
]