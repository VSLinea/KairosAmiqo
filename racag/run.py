"""
RACAG CLI Wrapper
=================

Allows calling the full RACAG pipeline directly from the command line:

    python -m racag "How does the negotiation engine update state?"

Produces a formatted context packet suitable for feeding into
Copilot, VS Code models, Kairos iOS adapters, etc.
"""

from __future__ import annotations
import sys
from racag.runtime.racag_runtime import run_racag


def main():
    if len(sys.argv) < 2:
        print("Usage:")
        print("    python -m racag \"your query here\"")
        sys.exit(1)

    query = " ".join(sys.argv[1:])
    print(f"\n🔍 RACAG Query: {query}\n")

    result = run_racag(query)

    if result["status"] != "success":
        print("❌ Error:", result["status"])
        print("Details:", result.get("details"))
        sys.exit(1)

    print("📦 Final RACAG Context:\n")
    print(result["context"])
    print("\n---")
    print(f"Chunks used: {result.get('chunks_used', 'N/A')}")
    print(f"Retrieved:   {result['details']['retrieval_count']}")
    print(f"Reranked:    {result['details']['reranked_count']}")


if __name__ == "__main__":
    main()