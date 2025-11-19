# racag/embedding/prompt_formatter.py

import hashlib
from typing import Dict, Any


def compute_hash(text: str) -> str:
    """Returns a stable hash for dedup + versioning."""
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def build_metadata(chunk: Dict[str, Any]) -> Dict[str, Any]:
    """
    Build unified RACAG metadata structure for storage and retrieval.
    This keeps all pipelines consistent.
    """
    file_path = chunk.get("file_path") or chunk.get("file") or "UNKNOWN_FILE"
    language = chunk.get("language", "unknown")
    framework = chunk.get("framework", "generic")
    module = chunk.get("module", "root")
    object_type = chunk.get("object_type") or ",".join(chunk.get("tags", [])) if isinstance(chunk.get("tags"), list) else chunk.get("tags") or "unknown"
    lines = chunk.get("lines") or f"{chunk.get('start_line', '?')}-{chunk.get('end_line', '?')}"
    text = chunk.get("chunk_text") or chunk.get("text", "")

    metadata = {
        "file": file_path,
        "chunk_id": chunk.get("chunk_id") or chunk.get("id", "UNKNOWN_ID"),
        "language": language,
        "framework": framework,
        "module": module,
        "object_type": object_type,
        "lines": lines,
        "hash": compute_hash(text),
        "length": len(text),
    }

    return metadata


def format_chunk_as_prompt(chunk: Dict[str, Any]) -> str:
    """
    Generates a clean, informative prompt for embedding.
    Includes metadata so embeddings are contextual.
    """
    text = (chunk.get("chunk_text") or chunk.get("text") or "").strip()
    metadata = build_metadata(chunk)

    header = [
        f"### File: {metadata['file']}",
        f"### Chunk ID: {metadata['chunk_id']}",
        f"### Language: {metadata['language']}",
        f"### Framework: {metadata['framework']}",
        f"### Module: {metadata['module']}",
        f"### Object: {metadata['object_type']}",
        f"### Lines: {metadata['lines']}",
        f"### Hash: {metadata['hash']}",
    ]

    header_block = "\n".join(header)

    return f"""{header_block}

{text}
"""


def build_record(chunk: Dict[str, Any], embedding: list) -> Dict[str, Any]:
    """
    Converts (chunk + embedding) into the final unified RACAG record.
    """
    metadata = build_metadata(chunk)

    return {
        "embedding": embedding,
        "metadata": metadata,
        "text": (chunk.get("chunk_text") or chunk.get("text") or "").strip(),
    }