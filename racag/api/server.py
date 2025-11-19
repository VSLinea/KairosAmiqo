# racag/api/server.py

from racag.telemetry.noop_tracing import disable_tracing
disable_tracing()

from fastapi import FastAPI
from racag.api.copilot_adapter import router as copilot_router

app = FastAPI(title="RACAG API", version="0.1")

# Register routers
app.include_router(copilot_router, prefix="/copilot")

@app.get("/")
def root():
    return {
        "status": "online",
        "message": "RACAG API is running.",
        "endpoints": {
            "contextualize": "/copilot/contextualize"
        }
    }


# Health endpoint
@app.get("/health")
def health():
    return {"status": "ok"}

# --- RACAG API server launcher ---

import uvicorn

def start_api():
    """Start RACAG API via uvicorn on 127.0.0.1:8009"""
    uvicorn.run(
        "racag.api.server:app",
        host="127.0.0.1",
        port=8009,
        reload=False,
        log_level="info"
    )