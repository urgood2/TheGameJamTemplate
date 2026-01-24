#!/usr/bin/env bash
# Stop screen recording
# Usage: ./record-stop.sh [session_dir]
set -euo pipefail

SESSION_DIR="${1:-devlog/sessions/$(date +%F)}"
PIDFILE="$SESSION_DIR/raw/.recording.pid"

if [[ ! -f "$PIDFILE" ]]; then
    echo "No recording in progress (pidfile not found: $PIDFILE)"
    exit 1
fi

PID=$(cat "$PIDFILE")
echo "Stopping recording (PID: $PID)..."

# Send interrupt signal for clean FFmpeg shutdown
kill -INT "$PID" 2>/dev/null || true

# Wait a moment for FFmpeg to finalize
sleep 2

rm -f "$PIDFILE"
echo "Recording stopped."
echo "Files in: $SESSION_DIR/raw/"
ls -la "$SESSION_DIR/raw/"*.mp4 2>/dev/null || echo "(no mp4 files found)"
