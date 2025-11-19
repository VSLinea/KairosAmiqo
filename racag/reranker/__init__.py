"""Result reranking for improved relevance."""

__all__ = ["rerank_results", "ReRanker"]


def rerank_results(query: str, results: list):
    """Rerank search results for improved relevance."""
    from racag.reranker.rerank_engine import rerank_results as _rerank
    return _rerank(query, results)


class ReRanker:
    """Compatibility wrapper for class-based reranker."""
    
    def __init__(self, *_, **__):
        pass
    
    def rerank(self, query: str, results: list):
        return rerank_results(query, results)
