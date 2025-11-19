import re
from pathlib import Path
from typing import List, Dict

def chunk_markdown(file_path: str) -> List[Dict]:
    """
    Splits a markdown file into chunks based on headings (## and ###),
    producing unified-schema chunk dictionaries.
    """
    import hashlib

    chunks = []
    path = Path(file_path)
    lines = path.read_text(encoding="utf-8").splitlines()

    def compute_id(text: str) -> str:
        h = hashlib.sha1(text.encode("utf-8")).hexdigest()[:12]
        return f"{path.name}::md::{h}"

    current_text = []
    current_start = 0

    for i, line in enumerate(lines):
        if re.match(r"^(##|###)\s", line):
            if current_text:
                full_text = "\n".join(current_text).strip()
                start_line = current_start + 1
                end_line = i
                chunks.append({
                    "chunk_id": compute_id(full_text),
                    "chunk_text": full_text,
                    "language": "markdown",
                    "framework": "generic",
                    "module": path.stem,
                    "function": None,
                    "file_path": str(path),
                    "start_line": start_line,
                    "end_line": end_line,
                    "tags": ["markdown"],
                    "lines": f"{start_line}-{end_line}",
                })
            current_text = [line]
            current_start = i
        else:
            current_text.append(line)

    if current_text:
        full_text = "\n".join(current_text).strip()
        start_line = current_start + 1
        end_line = len(lines)
        chunks.append({
            "chunk_id": compute_id(full_text),
            "chunk_text": full_text,
            "language": "markdown",
            "framework": "generic",
            "module": path.stem,
            "function": None,
            "file_path": str(path),
            "start_line": start_line,
            "end_line": end_line,
            "tags": ["markdown"],
            "lines": f"{start_line}-{end_line}",
        })

    return chunks