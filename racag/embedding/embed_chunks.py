import os
import json
from datetime import datetime

from racag.embedding.chunk_embedder import embed_chunk
from racag.embedding.prompt_formatter import build_metadata

# Path to the chunk prompts (produced by file_watcher)
PROMPTS_DIR = "racag/logs/prompts"

# Path to store embedding results
EMBEDDINGS_DIR = "racag/logs/embeddings"
os.makedirs(EMBEDDINGS_DIR, exist_ok=True)


def normalize_prompt(prompt_data: dict) -> dict:
    """
    Normalize fields so the embedder always receives a correct schema.
    """

    return {
        "chunk_id": prompt_data.get("chunk_id"),
        "description": prompt_data.get("description", ""),
        "file_path": prompt_data.get("source_file"),
        "framework": prompt_data.get("framework", "unknown"),
        "function": prompt_data.get("function", None),
        "language": prompt_data.get("language", "unknown"),
        "module": prompt_data.get("module", None),
        "tags": prompt_data.get("tags", []),
        "lines": [
            prompt_data.get("start_line"),
            prompt_data.get("end_line"),
        ],
        "source_file": prompt_data.get("source_file"),
        "relative_path": prompt_data.get("relative_path", None),
    }


def main():
    print("🚀 Embedding all prompt chunks...")

    for filename in os.listdir(PROMPTS_DIR):
        if not filename.endswith(".json"):
            continue

        prompt_path = os.path.join(PROMPTS_DIR, filename)
        with open(prompt_path, "r", encoding="utf-8") as f:
            raw_prompt = json.load(f)

        prompt = normalize_prompt(raw_prompt)

        try:
            embedding = embed_chunk(prompt)
        except Exception as e:
            print(f"❌ Error embedding {filename}: {e}")
            continue

        metadata = build_metadata(
            source_file=prompt["file_path"],
            relative_path=prompt.get("relative_path"),
            tags=prompt.get("tags", []),
        )

        result = {
            "chunk_id": prompt["chunk_id"],
            "description": prompt["description"],
            "file_path": prompt["file_path"],
            "framework": prompt["framework"],
            "function": prompt["function"],
            "language": prompt["language"],
            "module": prompt["module"],
            "tags": prompt["tags"],
            "lines": prompt["lines"],
            "embedding": embedding,
            "metadata": metadata,
        }

        out_path = os.path.join(
            EMBEDDINGS_DIR, f"{prompt['chunk_id']}.json"
        )

        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(result, f, indent=2)

        print(f"✅ Embedded: {filename} → {os.path.basename(out_path)}")


if __name__ == "__main__":
    main()