#!/usr/bin/env python3
"""Entry point to run RACAG pipeline and emit JSON for MCP tools."""

from __future__ import annotations

import argparse
import json
import logging
import sys
from typing import Any

from racag.runtime.racag_runtime import run_racag


def _disable_verbose_logging() -> None:
    """Silence noisy stream handlers so stdout stays JSON only."""
    logger_names = [
        "racag.query_engine",
        "racag.runtime",
        "racag.reranker",
        "racag",
    ]

    for name in logger_names:
        logger = logging.getLogger(name)
        logger.handlers.clear()
        logger.propagate = False
        logger.setLevel(logging.WARNING)

    logging.basicConfig(level=logging.WARNING)


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run RACAG retrieval and emit JSON context for MCP clients.",
    )
    parser.add_argument("query", nargs="+", help="Natural language query to contextualise")
    parser.add_argument(
        "--top-k",
        dest="top_k",
        type=int,
        default=3,
        help="Maximum number of chunks to return (default: 3)",
    )
    return parser.parse_args()


def _emit(data: Any) -> None:
    json.dump(data, sys.stdout, ensure_ascii=True)
    sys.stdout.write("\n")
    sys.stdout.flush()


def main() -> int:
    args = _parse_args()
    query = " ".join(arg.strip() for arg in args.query).strip()

    if not query:
        sys.stderr.write("Query cannot be empty.\n")
        return 1

    _disable_verbose_logging()

    try:
        result = run_racag(query, max_final=max(1, args.top_k))
    except Exception as exc:  # pragma: no cover - defensive guard
        error_payload = {
            "status": "error",
            "query": query,
            "message": str(exc),
        }
        _emit(error_payload)
        return 1

    _emit(result)
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
