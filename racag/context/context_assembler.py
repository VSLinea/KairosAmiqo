"""
RACAG — Context Assembler (v2)
==============================

Takes the structured results from QueryEngine and produces a
final, cleaned, token-bounded, LLM-ready context packet.

Compatible with the new RACAG query schema:
    result item keys:
        - id:        unique chunk id (string)
        - text:      chunk body text (string)
        - file:      source file path (string)
        - lang:      language hint (string)
        - lines:     line range string, e.g. "12-48" (string)
        - score_*:   ranking scores (ignored for now)
"""

from __future__ import annotations

from typing import Any, Dict, List, Tuple
import re

# Optional: for token estimation
try:  # pragma: no cover - optional dependency
    import tiktoken  # type: ignore
except ImportError:  # pragma: no cover
    tiktoken = None


# ============================================================
# CONFIG
# ============================================================

# Hard cap for Copilot / VS Code context injection
MAX_TOKENS = 2800
SAFETY_MARGIN = 0.85  # Leave buffer so Copilot doesn't truncate
MAX_FINAL_TOKENS = int(MAX_TOKENS * SAFETY_MARGIN)

# Allow chunk merging if line ranges are near each other
MERGE_MAX_LINE_GAP = 3

# Minimum useful content length
MIN_CHARS_THRESHOLD = 20


# ============================================================
# Utilities
# ============================================================


def estimate_tokens(text: str) -> int:
    """Rough token estimator.

    Uses tiktoken if available, otherwise simple chars/token
    heuristic (~4 chars per token).
    """

    if tiktoken is not None:
        try:
            enc = tiktoken.get_encoding("cl100k_base")
            return len(enc.encode(text))
        except Exception:
            # Fall back to heuristic if anything goes wrong
            pass

    return max(1, int(len(text) / 4))


def clean_text(text: str) -> str:
    """Lightweight cleaner.

    - Normalises blank lines
    - Strips trailing spaces
    - Removes obvious comment noise and import spam
    """

    # Remove triple-blank lines
    text = re.sub(r"\n\s*\n\s*\n+", "\n\n", text)

    # Strip trailing spaces
    text = re.sub(r"[ \t]+$", "", text, flags=re.MULTILINE)

    # Remove Swift / Python / JS-style line comments (best-effort)
    text = re.sub(r"//.*?$", "", text, flags=re.MULTILINE)
    text = re.sub(r"#.*?$", "", text, flags=re.MULTILINE)

    # Remove simple block comments
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)

    # Remove noisy import-only lines
    text = re.sub(r"(?m)^\s*(import|from)\s+[^\n]+$", "", text)

    # Normalise blank lines again
    text = re.sub(r"\n\s*\n\s*\n+", "\n\n", text)

    return text.strip()


# ============================================================
# Deduplication
# ============================================================


def dedupe(chunks: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Remove duplicate chunks by `id`.

    Assumes each result has a stable `id` field.
    """

    seen_ids = set()
    out: List[Dict[str, Any]] = []

    for c in chunks:
        cid = c.get("id")
        if not cid:
            # Safety: if a chunk somehow has no id, keep it once
            out.append(c)
            continue
        if cid in seen_ids:
            continue
        seen_ids.add(cid)
        out.append(c)

    return out


# ============================================================
# Merge nearby chunks
# ============================================================


def _parse_line_range(lines: str | None) -> Tuple[int, int]:
    if not lines or "-" not in lines:
        return (0, 0)
    try:
        a, b = lines.split("-", 1)
        return int(a), int(b)
    except Exception:
        return (0, 0)


def merge_chunks(chunks: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Merge nearby chunks from the same file.

    Rules:
    - same `file` path
    - line ranges close enough (gap <= MERGE_MAX_LINE_GAP)
    """

    if not chunks:
        return []

    # Normalise keys used here
    normalised: List[Dict[str, Any]] = []
    for c in chunks:
        normalised.append(
            {
                **c,
                "file": c.get("file") or c.get("file_path") or "unknown",
                "lines": c.get("lines") or c.get("line_range") or "",
                "text": c.get("text") or c.get("chunk_text") or "",
            }
        )

    chunks_sorted = sorted(normalised, key=lambda c: (c["file"], c["lines"]))

    merged: List[Dict[str, Any]] = []
    buffer: Dict[str, Any] | None = None

    for chunk in chunks_sorted:
        if buffer is None:
            buffer = chunk
            continue

        same_file = chunk["file"] == buffer["file"]
        a1, a2 = _parse_line_range(buffer["lines"])
        b1, b2 = _parse_line_range(chunk["lines"])

        if same_file and a2 and b1 and abs(b1 - a2) <= MERGE_MAX_LINE_GAP:
            # Merge into buffer
            buffer["text"] = (buffer["text"] + "\n" + chunk["text"]).strip()
            # Extend line range
            start = a1 or b1
            end = max(a2, b2)
            buffer["lines"] = f"{start}-{end}"
            continue

        # Flush old buffer, start new one
        merged.append(buffer)
        buffer = chunk

    if buffer is not None:
        merged.append(buffer)

    return merged


# ============================================================
# Token trimming
# ============================================================


def enforce_token_limit(chunks: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Truncate list of chunks to fit under MAX_FINAL_TOKENS."""

    output: List[Dict[str, Any]] = []
    total_tokens = 0

    for c in chunks:
        text = c.get("text") or c.get("chunk_text") or ""
        if not text or len(text) < MIN_CHARS_THRESHOLD:
            continue

        t = estimate_tokens(text)
        if total_tokens + t > MAX_FINAL_TOKENS:
            break

        total_tokens += t
        output.append(c)

    return output


# ============================================================
# Main Assembler
# ============================================================


def assemble_context(query_results: Dict[str, Any]) -> Dict[str, Any]:
    """Convert QueryEngine output into an LLM-ready context packet.

    Expected input shape (simplified):
        {
            "status": "success" | "no_results" | "error",
            "query": str,
            "results": [
                {
                    "id": str,
                    "text": str,
                    "file": str,
                    "lines": str,
                    "lang": str,
                    ... scores ...
                },
                ...
            ],
            ...
        }
    """

    status = query_results.get("status")
    if status != "success":
        return {
            "status": "no_results",
            "context": "",
            "chunks_used": 0,
            "query": query_results.get("query", ""),
        }

    raw = query_results.get("results") or []

    # Step 1: dedupe
    step1 = dedupe(raw)

    # Step 2: merge nearby chunks
    step2 = merge_chunks(step1)

    # Step 3: clean text
    for c in step2:
        text = c.get("text") or c.get("chunk_text") or ""
        c["text"] = clean_text(text)

    # Step 4: token limit
    step3 = enforce_token_limit(step2)

    # Step 5: final formatted blocks
    final_blocks: List[str] = []
    for c in step3:
        file_path = c.get("file") or c.get("file_path") or "unknown"
        lines = c.get("lines") or c.get("line_range") or "?"
        lang = c.get("lang") or c.get("language") or "unknown"
        text = c.get("text") or ""

        header = f"### File: {file_path}\n### Lines: {lines}\n### Lang: {lang}\n"
        block = header + text + "\n"
        final_blocks.append(block)

    return {
        "status": "success",
        "query": query_results.get("query", ""),
        "chunks_used": len(final_blocks),
        "context": "\n\n---\n\n".join(final_blocks),
        "raw_chunks": step3,
    }


# ============================================================
# Markdown formatter
# ============================================================


def context_to_markdown(results: List[Dict[str, Any]], title: str = "RACAG Context") -> str:
    """Render query_engine() results into a lightweight Markdown block."""

    lines: List[str] = [f"# {title}", ""]

    for idx, item in enumerate(results, start=1):
        file_path = item.get("file") or item.get("file_path") or "unknown"
        lang = item.get("lang") or item.get("language") or "unknown"
        line_range = item.get("lines") or item.get("line_range") or "?"
        score = item.get("score_hybrid")
        score_str = f"{score:.3f}" if isinstance(score, (int, float)) else "n/a"

        lines.append(f"## {idx}. {file_path} [{lang}] (lines {line_range}) — score {score_str}")
        lines.append("")

        text = (item.get("text") or item.get("chunk_text") or "").strip()
        if text:
            lines.append("```")
            lines.append(text)
            lines.append("```")
        lines.append("")

    return "\n".join(lines)


# ============================================================
# Manual Test
# ============================================================

if __name__ == "__main__":  # pragma: no cover
    print("Context Assembler ✓ ready (v2, RACAG-compatible)")