import hashlib
from pathlib import Path
from typing import Dict, List

# ---------------------------------------------------
# INTERNAL UTILITIES
# ---------------------------------------------------

def safe_str(value) -> str:
    """Converts None to empty string and strips whitespace."""
    if value is None:
        return ""
    return str(value).strip()


def detect_language(filepath: str) -> str:
    ext = Path(filepath).suffix.lower()
    mapping = {
        ".py": "python",
        ".swift": "swift",
        ".js": "javascript",
        ".ts": "typescript",
        ".kt": "kotlin",
        ".java": "java",
        ".md": "markdown",
        ".txt": "text",
        ".json": "json",
        ".sh": "shell",
    }
    return mapping.get(ext, "unknown")


def detect_framework(filepath: str) -> str:
    p = filepath.lower()
    if "swift" in p or "ios" in p:
        return "swiftui"
    if "node" in p or "server" in p:
        return "nodejs"
    if "python" in p or "racag" in p:
        return "python"
    if "react" in p or "tsx" in p:
        return "react"
    return "generic"


def detect_module(filepath: str) -> str:
    return Path(filepath).stem


def generate_chunk_id(text: str, filepath: str, start: int, end: int) -> str:
    """Deterministic ID: ensures deduplication across runs."""
    h = hashlib.md5(f"{filepath}:{start}:{end}:{text}".encode("utf-8")).hexdigest()[:12]
    file_id = Path(filepath).name
    return f"{file_id}::{h}"


def sanitize_text(text: str) -> str:
    """Strip weird characters and null bytes."""
    if not isinstance(text, str):
        return ""
    return text.replace("\x00", "").replace("\u0000", "").strip()


# ---------------------------------------------------
# MAIN NORMALIZATION FUNCTION
# ---------------------------------------------------

def normalize_chunks(raw_chunks: List[Dict]) -> List[Dict]:
    """
    Main unifier for all chunkers.
    Ensures ALL chunks follow the unified RACAG schema.
    """

    normalized = []

    for c in raw_chunks:
        try:
            text = sanitize_text(
                c.get("chunk_text") or 
                c.get("text") or 
                c.get("content") or 
                ""
            )

            if not text.strip():
                continue

            file_path = safe_str(
                c.get("file_path") or
                c.get("source_file") or
                c.get("path") or
                "unknown"
            )

            start_line = int(c.get("start_line", 0))
            end_line = int(c.get("end_line", 0))

            chunk_id = generate_chunk_id(text, file_path, start_line, end_line)

            item = {
                "chunk_id": chunk_id,
                "chunk_text": text,
                "description": safe_str(c.get("description", "")),
                "file_path": file_path,
                "framework": safe_str(c.get("framework") or detect_framework(file_path)),
                "function": safe_str(c.get("function") or ""),
                "language": safe_str(c.get("language") or detect_language(file_path)),
                "module": safe_str(c.get("module") or detect_module(file_path)),
                "tags": c.get("tags") or [],
                "start_line": start_line,
                "end_line": end_line,
            }

            if len(item["chunk_text"]) > 5000:
                item["chunk_text"] = item["chunk_text"][:5000] + "\n[...] TRUNCATED"

            normalized.append(item)

        except Exception as e:
            print(f"⚠️ normalization error on chunk: {e}")
            continue

    return normalized


# ---------------------------------------------------
# COMPAT WRAPPER
# ---------------------------------------------------

def normalize_chunk(c: Dict):
    """Normalize a single chunk dict."""
    result = normalize_chunks([c])
    return result[0] if result else None