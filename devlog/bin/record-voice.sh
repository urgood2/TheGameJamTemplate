#!/usr/bin/env bash
set -euo pipefail

# Usage: record-voice.sh [line_name] [session_dir]
# Examples:
#   ./devlog/bin/record-voice.sh line_01
#   ./devlog/bin/record-voice.sh line_02 devlog/sessions/2024-01-15

LINE_NAME="${1:-voice_$(date +%H%M%S)}"
SESSION_DIR="${2:-devlog/sessions/$(date +%F)}"

mkdir -p "$SESSION_DIR/voice"

OUT="$SESSION_DIR/voice/${LINE_NAME}.wav"

# Check if file already exists
if [[ -f "$OUT" ]]; then
    echo "Warning: $OUT already exists!"
    read -p "Overwrite? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 1
    fi
fi

echo ""
echo "Recording: $LINE_NAME"
echo "Output: $OUT"
echo ""
echo "Press ENTER when ready, then speak your line."
echo "Press Ctrl+C when done."
echo ""
read -p "Ready? "

# Record using ffmpeg with macOS default audio input
# -f avfoundation: macOS audio/video capture
# -i ":0": default audio input device (: prefix means audio-only)
# -ac 1: mono audio (good for voice)
# -ar 48000: 48kHz sample rate
ffmpeg -f avfoundation -i ":0" -ac 1 -ar 48000 "$OUT" 2>/dev/null

echo ""
echo "Saved: $OUT"
echo ""

# Offer to play it back
read -p "Play it back? [Y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    afplay "$OUT"
fi

echo ""
echo "Next line? Run: ./devlog/bin/record-voice.sh line_0X"
