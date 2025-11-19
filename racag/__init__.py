"""
RACAG: Retrieval-Augmented Context-Aware Generator

A code retrieval system for the KairosAmiqo project that provides
intelligent context assembly for AI-assisted development.
"""

__version__ = "1.0.0"
__all__ = ["query_racag"]


def query_racag(question: str):
    """
    Main entry point for RACAG queries.
    
    Args:
        question: Natural language question about the codebase
        
    Returns:
        Dict containing retrieved context and metadata
    """
    from racag.query import query_racag as _query_racag
    return _query_racag(question)
