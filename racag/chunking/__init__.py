"""Code and document chunking for semantic search."""

__all__ = [
    "extract_code_chunks",
    "chunk_markdown",
    "chunk_json",
    "normalize_chunk"
]


def extract_code_chunks(file_path: str, language: str = "swift"):
    """Extract semantic chunks from source code."""
    from racag.chunking.code_chunker import extract_code_chunks as _extract
    return _extract(file_path, language)


def chunk_markdown(content: str):
    """Chunk markdown documents by headers."""
    from racag.chunking.markdown_chunker import chunk_markdown as _chunk
    return _chunk(content)


def chunk_json(content: str):
    """Chunk JSON documents intelligently."""
    from racag.chunking.json_chunker import chunk_json as _chunk
    return _chunk(content)


def normalize_chunk(chunk: dict):
    """Normalize chunk metadata."""
    from racag.chunking.normalize import normalize_chunk as _normalize
    return _normalize(chunk)
