import hashlib
from racag.embedding.prompt_formatter import (
    build_metadata,
    build_record
)


def embed_chunk(chunk: dict) -> dict:
    """
    Takes a parsed chunk, computes a deterministic embedding, and returns
    a unified RACAG record with:
        - embedding
        - metadata
        - text
    """

    text = chunk.get("text", "").strip()

    # --- Compute embedding (dummy SHA256 for now) ---
    digest = hashlib.sha256(text.encode("utf-8")).digest()
    embedding = [b / 255 for b in digest[:10]]

    # --- Build metadata using RACAG unified schema ---
    metadata = build_metadata(chunk)

    # --- Build final record ---
    record = build_record(chunk, embedding)

    return record