"""Public exports for the RACAG query package."""

from .query_engine import query_engine


class QueryEngine:
    """Compatibility wrapper preserving historical class-based imports."""

    def __init__(self, *_, **__):
        pass

    def run(self, question: str):
        return query_engine(question)


__all__ = ["query_engine", "QueryEngine"]