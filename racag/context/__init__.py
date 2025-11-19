"""Context assembly and formatting for retrieved results."""

__all__ = ["assemble_context", "context_to_markdown"]


def assemble_context(results: list):
    """Assemble retrieved chunks into structured context."""
    from racag.context.context_assembler import assemble_context as _assemble
    return _assemble(results)


def context_to_markdown(context: dict):
    """Convert context to markdown format."""
    from racag.context.context_assembler import context_to_markdown as _to_md
    return _to_md(context)
