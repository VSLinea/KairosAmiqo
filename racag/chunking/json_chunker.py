from pathlib import Path
import json
from typing import List, Dict, Any

def chunk_json(file_path: str) -> List[Dict[str, Any]]:
    """
    Chunk JSON files by extracting top-level keys as semantic chunks.
    Each chunk contains:
        - chunk_id
        - text
        - language
        - file_path
        - type
        - start_line
        - end_line
        - content_hash
    """

    path = Path(file_path)
    raw = path.read_text(encoding="utf-8")

    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        total_lines = len(raw.splitlines())
        return [
            {
                "chunk_id": f"{path.name}::full_json",
                "chunk_text": raw,
                "language": "json",
                "framework": "generic",
                "module": path.stem,
                "function": None,
                "file_path": str(path),
                "start_line": 1,
                "end_line": total_lines,
                "tags": ["json_document"],
                "lines": f"1-{total_lines}",
            }
        ]

    chunks = []
    lines = raw.splitlines()
    total_lines = len(lines)

    # For each top-level key, extract text slice if possible
    if isinstance(data, dict):
        for key, value in data.items():
            # Convert each entry back to pretty-printed JSON
            sub_json = json.dumps({key: value}, indent=2)

            chunk_id = f"{path.name}::key::{key}"
            chunks.append({
                "chunk_id": chunk_id,
                "chunk_text": sub_json,
                "language": "json",
                "framework": "generic",
                "module": path.stem,
                "function": None,
                "file_path": str(path),
                "start_line": 1,
                "end_line": total_lines,
                "tags": ["json_key", f"key:{key}"],
                "lines": f"1-{total_lines}",
            })

    else:
        # If it's a JSON array or primitive
        sub_json = json.dumps(data, indent=2)
        chunks.append({
            "chunk_id": f"{path.name}::array_or_value",
            "chunk_text": sub_json,
            "language": "json",
            "framework": "generic",
            "module": path.stem,
            "function": None,
            "file_path": str(path),
            "start_line": 1,
            "end_line": total_lines,
            "tags": ["json_array_or_value"],
            "lines": f"1-{total_lines}",
        })

    return chunks