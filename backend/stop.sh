#!/bin/bash

if [ -f /tmp/kairos-backend.pid ]; then
  PID=$(cat /tmp/kairos-backend.pid)
  if kill $PID 2>/dev/null; then
    echo "✅ Backend stopped (PID: $PID)"
  else
    echo "⚠️  Process $PID not found, cleaning up"
  fi
  rm /tmp/kairos-backend.pid
else
  # Fallback: kill by port
  if lsof -ti:3000 > /dev/null 2>&1; then
    kill $(lsof -ti:3000) 2>/dev/null
    echo "✅ Backend stopped (killed by port)"
  else
    echo "ℹ️  Backend not running"
  fi
fi
