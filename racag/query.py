# racag/query.py

import json
from racag.retrieval.query_embedder import embed_query
from racag.retrieval.semantic_retriever import semantic_search
from racag.context.context_assembler import assemble_context
from datetime import datetime

def query_racag(text: str, top_k: int = 5):
    print(f"\n🔍 Searching RACAG for: \"{text}\"\n")

    # Convert text → embedding
    q_emb = embed_query(text)

    # Retrieve chunks (new schema)
    results = semantic_search(q_emb, top_k=top_k)

    if not results:
        print("⚠️ No results found.")
        results = []

    # Pretty terminal output (safe for missing metadata)
    for i, r in enumerate(results, start=1):
        meta = r.get("metadata", {})
        print(f"#{i} — {r.get('chunk_id', 'unknown')}")
        print(f"   Score: {r.get('score', 0):.4f}")
        print(f"   File: {meta.get('file_path', 'unknown')}")
        print(f"   Lines: {meta.get('lines', '?-?')}")
        print("")

    # Build Copilot-ready context bundle
    context_bundle = assemble_context(text, results)

    # Add timestamp to context bundle
    context_bundle["_timestamp"] = datetime.now().isoformat()

    # Save the assembled context so Copilot or other tools can read it
    with open("racag/logs/last_context.json", "w", encoding="utf-8") as f:
        json.dump(context_bundle, f, indent=2)

    print("🧠 Context assembled → racag/logs/last_context.json")
    return context_bundle

if __name__ == "__main__":
    import sys
    text = " ".join(sys.argv[1:]) or "default query"
    query_racag(text)