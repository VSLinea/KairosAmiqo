# racag/server/api.py

import json
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn

from racag.query import query_racag

# ---------------
# FastAPI service
# ---------------

app = FastAPI(title="RACAG Local API", version="1.0")

# Allow queries from VS Code, Cursor, webviews, etc.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ----- Models -----

class QueryRequest(BaseModel):
    query: str
    top_k: int = 5


# ----- Routes -----

@app.post("/context")
def get_context(req: QueryRequest):
    context_bundle = query_racag(req.query, top_k=req.top_k)
    return {"ok": True, "context": context_bundle}


@app.get("/last")
def get_last_context():
    try:
        with open("racag/logs/last_context.json", "r", encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return {"error": "No context available yet."}


# ----- Entry Point -----

def start_api():
    print("🚀 Starting RACAG Local API at http://localhost:3928")
    uvicorn.run(app, host="0.0.0.0", port=3928)


if __name__ == "__main__":
    start_api()