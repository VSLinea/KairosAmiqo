import os
from typing import List, Dict

# --- Disable all Chroma telemetry BEFORE importing any Chroma modules ---
os.environ["CHROMA_TELEMETRY_ENABLED"] = "false"
os.environ["ANONYMIZED_TELEMETRY"] = "false"

from chromadb import PersistentClient
from chromadb.config import Settings
from openai import OpenAI

# Load OpenAI key from env
openai_client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

# Set up local ChromaDB (telemetry OFF, duckdb+faiss backend)
chroma_client = PersistentClient(
    path="racag/db/chroma_store",
    settings=Settings(anonymized_telemetry=False)
)

collection = chroma_client.get_or_create_collection(
    name="kairos_chunks",
    metadata={"hnsw:space": "cosine"}
)

def embed_text(text: str) -> List[float]:
    """Embed text using OpenAI's embedding-3-small model."""
    response = openai_client.embeddings.create(
        model="text-embedding-3-small",
        input=text
    )
    return response.data[0].embedding

def build_metadata(chunk: Dict) -> Dict:
    """Build metadata following the unified RACAG schema."""
    return {
        "description": chunk.get("description", ""),
        "file_path": chunk.get("file_path", "unknown"),
        "framework": chunk.get("framework", "unknown"),
        "function": chunk.get("function", "unknown"),
        "language": chunk.get("language", "unknown"),
        "lines": f"{chunk.get('start_line','?')}-{chunk.get('end_line','?')}",
        "module": chunk.get("module", "unknown"),
        "tags": chunk.get("tags", [])
    }

def embed_and_store(chunks: List[Dict]):
    """Embed RACAG chunks and store them in Chroma."""
    for chunk in chunks:
        text = chunk["chunk_text"]
        vector = embed_text(text)
        metadata = build_metadata(chunk)

        collection.add(
            ids=[chunk["chunk_id"]],
            embeddings=[vector],
            documents=[text],
            metadatas=[metadata]
        )

    print(f"✅ Stored {len(chunks)} chunks in ChromaDB.")