#!/bin/zsh

# Fail fast on errors
set -e

# Go to project root
cd /Users/lyra/KairosMain

# Use the project venv python directly
PYTHON="/Users/lyra/KairosMain/.venv/bin/python"

# Just in case, verify python exists
if [ ! -x "$PYTHON" ]; then
  echo "ERROR: $PYTHON not found or not executable" >&2
  exit 1
fi

# Start the RACAG API (uvicorn server)
# racag/api/run_api.py should expose main() which starts uvicorn on 127.0.0.1:8009
exec "$PYTHON" -m racag.api.run_api
