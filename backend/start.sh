#!/bin/bash
set -e
cd "$(dirname "$0")"

# Check if already running
if lsof -ti:3000 > /dev/null 2>&1; then
  echo "❌ Backend already running on port 3000"
  echo "Run ./stop.sh first"
  exit 1
fi

# Build if needed
if [ ! -d "dist" ] || [ ! -f "dist/index.js" ]; then
  echo "📦 Building backend..."
  npm run build
fi

# Start in production mode
echo "🚀 Starting backend on port 3000..."
nohup npm start > /tmp/kairos-backend.log 2>&1 &
echo $! > /tmp/kairos-backend.pid

sleep 3

if lsof -ti:3000 > /dev/null 2>&1; then
  echo "✅ Backend running (PID: $(cat /tmp/kairos-backend.pid))"
  echo "📋 Logs: tail -f /tmp/kairos-backend.log"
  echo "🏥 Health: curl http://127.0.0.1:3000/health"
else
  echo "❌ Backend failed to start"
  echo "Check logs: tail -30 /tmp/kairos-backend.log"
  exit 1
fi
