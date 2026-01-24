#!/usr/bin/env bash
# Start screen recording with FFmpeg
# Usage: ./record-start.sh [session_dir]
set -euo pipefail

SESSION_DIR="${1:-devlog/sessions/$(date +%F)}"
mkdir -p "$SESSION_DIR/raw"

OUT="$SESSION_DIR/raw/record_$(date +%H%M%S).mp4"
PIDFILE="$SESSION_DIR/raw/.recording.pid"

if [[ -f "$PIDFILE" ]]; then
    echo "Recording already in progress! PID: $(cat "$PIDFILE")"
    echo "Run record-stop.sh first."
    exit 1
fi

# Device indices (adjust if needed - run: ffmpeg -f avfoundation -list_devices true -i "")
# "1:0" = Capture screen 0 : MacBook Pro Microphone
SCREEN_DEVICE="1"
MIC_DEVICE="0"

echo "Starting recording..."
echo "  Output: $OUT"
echo "  Screen: device $SCREEN_DEVICE"
echo "  Mic: device $MIC_DEVICE"

ffmpeg -y \
  -f avfoundation -framerate 60 -capture_cursor 1 -i "$SCREEN_DEVICE:$MIC_DEVICE" \
  -c:v libx264 -preset veryfast -crf 18 -pix_fmt yuv420p \
  -c:a aac -b:a 192k \
  "$OUT" > "$SESSION_DIR/raw/ffmpeg_record.log" 2>&1 &

echo $! > "$PIDFILE"
echo "Recording started! PID: $(cat "$PIDFILE")"
echo "Run 'devlog/bin/record-stop.sh' to stop."
