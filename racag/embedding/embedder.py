# racag/embedding/embedder.py

import json
from pathlib import Path
from typing import Dict, Any

import os
from openai import OpenAI

# Initialize OpenAI client (requires OPENAI_API_KEY in env)
oai = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

EMBED_MODEL = "text-embedding-3-small"

# Output file for embeddings
EMBEDDINGS_OUTPUT = Path("racag/logs/embeddings.jsonl")
EMBEDDINGS_OUTPUT.parent.mkdir(parents=True, exist_ok=True)


def _normalize_metadata(chunk: Dict) -> Dict[str, Any]:
    """
    Ensures metadata always exists and is well‑formed.
    """
    meta = chunk.get("metadata", {})

    if not isinstance(meta, dict):
        meta = {}

    # Guarantee mandatory metadata fields
    meta.setdefault("file_path", chunk.get("file_path", "unknown"))
    meta.setdefault("language", chunk.get("language", "unknown"))
    meta.setdefault("framework", chunk.get("framework", "unknown"))
    meta.setdefault("module", chunk.get("module", "unknown"))
    meta.setdefault("function", chunk.get("function", "unknown"))
    meta.setdefault("description", chunk.get("description", ""))
    meta.setdefault("lines", f"{chunk.get('start_line', 0)}-{chunk.get('end_line', 0)}")

    return meta


def embed_chunk(chunk: Dict) -> Dict:
    """
    Embed a chunk according to the unified RACAG schema.
    """
    text = chunk.get("chunk_text", "").strip()
    if not text:
        raise ValueError("Empty chunk_text in chunk")

    # Create embedding
    response = oai.embeddings.create(
        input=text,
        model=EMBED_MODEL
    )
    vector = response.data[0].embedding

    # Build metadata
    metadata = _normalize_metadata(chunk)

    # Build final embedded object
    embedded = {
        "chunk_id": chunk["chunk_id"],
        "language": chunk.get("language", "unknown"),
        "framework": chunk.get("framework", "unknown"),
        "module": chunk.get("module", "unknown"),
        "function": chunk.get("function", "unknown"),

        "source_file": chunk.get("file_path", "unknown"),
        "start_line": chunk.get("start_line", 0),
        "end_line": chunk.get("end_line", 0),

        "chunk_text": text,
        "embedding": vector,
        "metadata": metadata
    }

    return embedded


def save_embedding(embedded_chunk: Dict):
    """
    Append the embedded chunk to embeddings.jsonl
    """
    with EMBEDDINGS_OUTPUT.open("a", encoding="utf-8") as f:
        f.write(json.dumps(embedded_chunk) + "\n")