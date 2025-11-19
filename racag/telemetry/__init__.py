"""Telemetry and tracing utilities."""

__all__ = ["disable_tracing"]


def disable_tracing():
    """Disable OpenTelemetry tracing."""
    from racag.telemetry.noop_tracing import disable_tracing as _disable
    return _disable()
