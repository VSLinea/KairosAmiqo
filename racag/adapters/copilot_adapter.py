"""
Copilot Adapter for RACAG
=========================

This adapter converts RACAG retrieval output into a clean,
Copilot-friendly prompt block.

Copilot tends to behave best when given:

1. A SYSTEM-STYLE introduction
2. A CONTEXT block (large, multi-file references)
3. A USER query

This adapter formats RACAG data into that structure.
"""

from __future__ import annotations
from typing import Dict, List


SYSTEM_HEADER = """\
You are GitHub Copilot working inside a large multi-file project.
You must obey the RACAG-generated context. Do not hallucinate files.
Only reference content explicitly provided below.
"""


def format_for_copilot(context: str, query: str, chunks_used: List[str] | None = None) -> str:
    """
    Wraps RACAG context into a Copilot-optimized prompt.
    """

    context_header = "### PROJECT CONTEXT (RACAG Retrieval)\n"
    context_footer = "\n### END CONTEXT\n"

    used_ids = ""
    if chunks_used:
        used_ids = "\nReferenced chunk IDs:\n" + "\n".join(f"- {cid}" for cid in chunks_used)

    final_prompt = (
        SYSTEM_HEADER
        + "\n\n"
        + context_header
        + context
        + context_footer
        + used_ids
        + "\n\n### USER REQUEST\n"
        + query.strip()
        + "\n"
    )

    return final_prompt


def build_copilot_packet(racag_result: Dict) -> Dict:
    """
    Converts the RACAG pipeline output into a deterministic Copilot Chat packet.

    Returns a dict suitable for direct JSON->Copilot injection.

    {
        "role": "system",
        "content": "<formatted prompt here>"
    }
    """

    return {
        "role": "system",
        "content": format_for_copilot(
            context=racag_result["context"],
            query=racag_result["query"],
            chunks_used=racag_result.get("chunks_used", []),
        ),
    }