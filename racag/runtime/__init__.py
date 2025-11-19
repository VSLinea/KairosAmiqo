"""Runtime environment for RACAG query execution."""

__all__ = ["run_racag"]


def run_racag(question: str):
    """Execute RACAG query with full pipeline."""
    from racag.runtime.racag_runtime import run_racag as _run
    return _run(question)
