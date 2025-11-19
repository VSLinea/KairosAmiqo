import math
from typing import List, Dict
from chromadb import PersistentClient

# Connect to the same Chroma store used by embed_and_store
chroma_client = PersistentClient(path="racag/db/chroma_store")
collection = chroma_client.get_or_create_collection(name="kairos_chunks")

# ---------- BASIC COSINE SIMILARITY ----------
def cosine_similarity(a: List[float], b: List[float]) -> float:
    dot = sum(x * y for x, y in zip(a, b))
    norm_a = math.sqrt(sum(x * x for x in a))
    norm_b = math.sqrt(sum(y * y for y in b))
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return dot / (norm_a * norm_b)

# ---------- MAIN SEARCH USING CHROMA ----------
def semantic_search(query_embedding: List[float], top_k: int = 5) -> List[Dict]:
    """
    Runs vector similarity search over ChromaDB using the RACAG unified metadata format.
    """

    # Query Chroma
    results = collection.query(
        query_embeddings=[query_embedding],
        n_results=top_k,
        include=["metadatas", "documents", "distances"]
    )

    out = []
    ids = results.get("ids", [[]])[0]
    metas = results.get("metadatas", [[]])[0]
    dists = results.get("distances", [[]])[0]

    for chunk_id, meta, dist in zip(ids, metas, dists):
        out.append({
            "chunk_id": chunk_id,
            "score": 1 / (1 + dist),  # convert distance → similarity
            "metadata": meta
        })

    return out