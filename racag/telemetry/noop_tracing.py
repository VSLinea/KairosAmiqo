# racag/telemetry/noop_tracing.py

from opentelemetry import trace
from opentelemetry.trace import NoOpTracerProvider

def disable_tracing():
    """
    Forces OpenTelemetry to use a NO-OP tracer provider.
    This guarantees:
    - No spans
    - No exporters
    - No telemetry
    - No performance overhead
    """
    trace.set_tracer_provider(NoOpTracerProvider())