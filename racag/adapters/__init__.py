"""Adapters for integrating RACAG with external systems."""

__all__ = ["build_backend_response", "format_for_copilot"]


def build_backend_response(question: str):
    """Build backend-compatible response."""
    from racag.adapters.backend_adapter import build_backend_response as _build
    return _build(question)


def format_for_copilot(question: str):
    """Format response for GitHub Copilot."""
    from racag.adapters.copilot_adapter import format_for_copilot as _format
    return _format(question)
