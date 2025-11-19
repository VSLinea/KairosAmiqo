#!/usr/bin/env python3
"""
RACAG Query CLI - Fetch context for Copilot integration

Usage:
    python3 -m racag.query_cli --q "user question" --top_k 20
    
Returns JSON with top K most relevant chunks from RACAG.
"""

import sys
import json
import argparse
from pathlib import Path

# Ensure PYTHONPATH includes repo root
repo_root = Path(__file__).resolve().parents[1]
if str(repo_root) not in sys.path:
    sys.path.insert(0, str(repo_root))

from racag.retrieval.query_embedder import embed_query
from racag.retrieval.semantic_retriever import semantic_search


def query_racag_cli(question: str, top_k: int = 20) -> dict:
    """
    Query RACAG and return structured results.
    
    Args:
        question: User's question or context request
        top_k: Number of results to return
        
    Returns:
        dict with query, results, and metadata
    """
    try:
        # Generate query embedding
        query_embedding = embed_query(question)
        
        # Retrieve relevant chunks
        results = semantic_search(query_embedding, top_k=top_k)
        
        # Format response
        return {
            "success": True,
            "query": question,
            "results_count": len(results),
            "results": results,
            "message": f"Retrieved {len(results)} relevant chunks"
        }
        
    except Exception as e:
        return {
            "success": False,
            "query": question,
            "results_count": 0,
            "results": [],
            "error": str(e),
            "message": f"Query failed: {e}"
        }


def main():
    parser = argparse.ArgumentParser(
        description="Query RACAG for relevant code/documentation context"
    )
    parser.add_argument(
        "--q",
        "--query",
        dest="query",
        required=True,
        help="Question or context request"
    )
    parser.add_argument(
        "--top_k",
        type=int,
        default=20,
        help="Number of results to return (default: 20)"
    )
    parser.add_argument(
        "--format",
        choices=["json", "text"],
        default="json",
        help="Output format"
    )
    
    args = parser.parse_args()
    
    # Execute query
    result = query_racag_cli(args.query, args.top_k)
    
    # Output
    if args.format == "json":
        print(json.dumps(result, indent=2))
    else:
        # Text format for human reading
        if result["success"]:
            print(f"Query: {result['query']}")
            print(f"Results: {result['results_count']}\n")
            for i, chunk in enumerate(result["results"][:10], 1):
                meta = chunk.get("metadata", {})
                print(f"{i}. [{chunk.get('score', 0):.3f}] {meta.get('file_path', 'unknown')}")
                print(f"   Lines {meta.get('lines', '?-?')}")
                print()
        else:
            print(f"Error: {result['message']}", file=sys.stderr)
            sys.exit(1)
    
    sys.exit(0 if result["success"] else 1)


if __name__ == "__main__":
    main()
