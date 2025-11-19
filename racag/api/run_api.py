# racag/api/run_api.py

import uvicorn

if __name__ == "__main__":
    uvicorn.run(
        "racag.api.server:app",
        host="127.0.0.1",
        port=8009,
        reload=False,
        log_level="info"
    )