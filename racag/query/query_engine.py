"""
RACAG — Query Engine
====================

Responsibilities:
    1. Embed the user query
    2. Retrieve top-N candidates from Chroma
    3. Call the Rerank Engine (cosine + GPT-4.1-mini)
    4. Assemble clean final context response

Dependencies:
    • embedding/model_loader
    • chromadb persistent client
    • reranker/rerank_engine
"""

from __future__ import annotations
from typing import List, Dict, Any

import chromadb
from chromadb.config import Settings

from racag.reranker.rerank_engine import rerank_results
from racag.reranker import model_loader as ml

import logging
import sys

logger = logging.getLogger("racag.query_engine")
logger.setLevel(logging.DEBUG)

# Console handler (minimal)
ch = logging.StreamHandler(sys.stdout)
ch.setLevel(logging.INFO)
ch.setFormatter(logging.Formatter("[RACAG][%(levelname)s] %(message)s"))

# File handler (full debug)
fh = logging.FileHandler("racag/logs/racag.log")
fh.setLevel(logging.DEBUG)
fh.setFormatter(logging.Formatter("%(asctime)s [%(levelname)s] %(message)s"))

logger.addHandler(ch)
logger.addHandler(fh)


# ============================================================
#  CONFIG
# ============================================================

CHROMA_PATH = "racag/db/chroma_store"
COLL_NAME = "kairos_chunks"

# Retrieval size BEFORE reranking
RETRIEVE_K = 40

# Final return size (the reranker may expand internally)
FINAL_K = 3


# ============================================================
#  MAIN QUERY ENGINE
# ============================================================

class QueryEngine:
    def __init__(
        self,
        chroma_path: str = CHROMA_PATH,
        coll_name: str = COLL_NAME,
        retrieve_k: int = RETRIEVE_K,
        final_k: int = FINAL_K,
    ):
        self.chroma_path = chroma_path
        self.coll_name = coll_name
        self.retrieve_k = retrieve_k
        self.final_k = final_k

    def run(self, user_query: str) -> Dict[str, Any]:
        """
        Main entrypoint for RACAG retrieval.

        Steps:
            1. Embed query
            2. Retrieve top-K via cosine similarity
            3. Rerank via hybrid scoring
            4. Return final structured context payload
        """
        logger.info(f"🔍 Query received: {user_query}")

        # Step 1 — embed the query
        query_vec = ml.embed_text(user_query)
        logger.debug("Query embedded successfully.")

        # Step 2 — retrieve from Chroma
        client = chromadb.PersistentClient(
            path=self.chroma_path,
            settings=Settings(anonymized_telemetry=False),
        )
        col = client.get_collection(self.coll_name)

        logger.debug(f"Retrieving top {self.retrieve_k} candidates from Chroma…")
        results = col.query(
            query_embeddings=[query_vec],
            n_results=self.retrieve_k,
            include=["documents", "metadatas", "embeddings"],
        )

        # Flatten Chroma output
        candidates: List[Dict[str, Any]] = []
        if results and results.get("ids") and results["ids"][0]:
            for i in range(len(results["ids"][0])):
                md = results["metadatas"][0][i]
                md = md if isinstance(md, dict) else {}
                candidates.append(
                    {
                        "id": results["ids"][0][i],
                        "chunk_text": results["documents"][0][i],
                        "metadata": md,
                        "embedding": results["embeddings"][0][i],
                    }
                )

        logger.debug(f"Retrieved {len(candidates)} raw candidates.")
        if not candidates:
            return {"query": user_query, "status": "no_results", "results": []}

        # Step 3 — rerank
        logger.debug("Running reranker (cosine + GPT-4.1-mini)…")
        reranked = rerank_results(
            query_text=user_query,
            query_vec=query_vec,
            candidates=candidates,
            top_k_base=self.final_k,
        )

        logger.info(f"Reranker returned {len(reranked)} final chunks.")
        logger.debug(
            f"Best chunk hybrid score: {reranked[0]['hybrid'] if reranked else 'N/A'}"
        )

        # Step 4 — prepare clean output
        formatted: List[Dict[str, Any]] = []
        for c in reranked:
            formatted.append(
                {
                    "id": c["id"],
                    "score_hybrid": round(c["hybrid"], 4),
                    "score_cosine": round(c["cosine"], 4),
                    "score_llm": round(c["llm_score"], 4),
                    "file": c["metadata"].get("file_path"),
                    "lang": c["metadata"].get("language"),
                    "lines": c["metadata"].get("lines"),
                    "text": c["chunk_text"],
                }
            )

        return {
            "query": user_query,
            "status": "success",
            "count": len(formatted),
            "results": formatted,
        }

# Backward-compatible function name
def query_engine(user_query: str) -> Dict[str, Any]:
    return QueryEngine().run(user_query)


# ============================================================
#  TEST ENTRY (Manual Debug)
# ============================================================

if __name__ == "__main__":
    print("Query Engine ready ✓")
    q = input("Enter query: ")
    out = query_engine(q)
    print(out)