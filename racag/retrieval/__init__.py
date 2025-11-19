"""Semantic search and retrieval from ChromaDB."""

__all__ = ["embed_query", "semantic_search"]


def embed_query(query: str):
    """Generate embedding for search query."""
    from racag.retrieval.query_embedder import embed_query as _embed
    return _embed(query)


def semantic_search(query_embedding: list, collection_name: str = "kairos"):
    """Perform semantic search in ChromaDB."""
    from racag.retrieval.semantic_retriever import semantic_search as _search
    return _search(query_embedding, collection_name)
