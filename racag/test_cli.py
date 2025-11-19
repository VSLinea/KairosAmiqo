"""Minimal CLI for exercising the RACAG pipeline end-to-end."""

import argparse
import json

from racag.context.context_assembler import context_to_markdown
from racag.query.query_engine import query_engine


def main() -> None:
    parser = argparse.ArgumentParser(
        prog="python -m racag.test_cli",
        description="RACAG end-to-end query test.",
    )
    parser.add_argument("question", type=str, help="Natural language question")
    parser.add_argument("--json", action="store_true", help="Print raw JSON response")
    args = parser.parse_args()

    result = query_engine(args.question)

    if args.json:
        print(json.dumps(result, indent=2, ensure_ascii=False))
        return

    if result.get("status") != "success":
        print(f"RACAG status: {result.get('status', 'unknown')}")
        return

    markdown = context_to_markdown(
        result.get("results", []),
        title=f"Context for: {args.question}",
    )
    print(markdown)


if __name__ == "__main__":
    main()