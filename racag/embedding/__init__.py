"""Embedding generation and storage."""

__all__ = ["embed_chunk", "format_chunk_as_prompt", "build_metadata"]


def embed_chunk(chunk: dict):
    """Generate embedding for a code chunk."""
    from racag.embedding.chunk_embedder import embed_chunk as _embed
    return _embed(chunk)


def format_chunk_as_prompt(chunk: dict):
    """Format chunk as embedding prompt."""
    from racag.embedding.prompt_formatter import format_chunk_as_prompt as _format
    return _format(chunk)


def build_metadata(chunk: dict):
    """Build metadata for chunk."""
    from racag.embedding.prompt_formatter import build_metadata as _build
    return _build(chunk)
