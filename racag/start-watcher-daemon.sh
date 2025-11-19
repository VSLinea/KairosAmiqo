#!/bin/bash
#
# RACAG Watcher - Background Daemon
# Simple persistent watcher that runs in background
#

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
PID_FILE="$SCRIPT_DIR/watcher.pid"
LOG_FILE="$SCRIPT_DIR/logs/watcher.out.log"
ERR_FILE="$SCRIPT_DIR/logs/watcher.err.log"

# Ensure logs directory exists
mkdir -p "$SCRIPT_DIR/logs"

cd "$REPO_ROOT"

# Kill existing watcher if running
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if ps -p "$OLD_PID" > /dev/null 2>&1; then
        echo "Stopping existing watcher (PID: $OLD_PID)..."
        kill "$OLD_PID" 2>/dev/null || true
        sleep 1
    fi
    rm -f "$PID_FILE"
fi

# Start watcher in background
echo "Starting RACAG watcher..."
echo "Logs: $LOG_FILE"

nohup bash -c "
    cd '$REPO_ROOT'
    source racag/venv/bin/activate
    export PYTHONPATH='$REPO_ROOT:\$PYTHONPATH'
    if [ -f '.copilot/.secrets' ]; then
        export OPENAI_API_KEY=\$(cat .copilot/.secrets)
    fi
    python3 -m racag.watcher.racag_watcher
" >> "$LOG_FILE" 2>> "$ERR_FILE" &

# Save PID
echo $! > "$PID_FILE"

echo "✅ RACAG watcher started (PID: $(cat $PID_FILE))"
echo ""
echo "Commands:"
echo "  Check status: ps -p \$(cat $PID_FILE)"
echo "  View logs:    tail -f $LOG_FILE"
echo "  Stop:         kill \$(cat $PID_FILE)"
