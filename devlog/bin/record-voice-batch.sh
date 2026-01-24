#!/usr/bin/env bash
set -euo pipefail

# Usage: record-voice-batch.sh <lines_file> [session_dir]
#
# Records multiple voice lines in sequence with minimal friction.
# Lines file is a simple text file with one line per recording.
#
# Example lines file:
#   So I found a bug in my game...
#   Look at this glitch.
#   But honestly? It looks kinda cool.
#   I think I'm keeping it.

LINES_FILE="${1:-}"
SESSION_DIR="${2:-devlog/sessions/$(date +%F)}"

if [[ -z "$LINES_FILE" ]]; then
    echo "Usage: $0 <lines_file> [session_dir]"
    echo ""
    echo "Example:"
    echo "  echo -e 'Line one\\nLine two\\nLine three' > /tmp/lines.txt"
    echo "  $0 /tmp/lines.txt"
    exit 1
fi

if [[ ! -f "$LINES_FILE" ]]; then
    echo "Error: Lines file not found: $LINES_FILE"
    exit 1
fi

mkdir -p "$SESSION_DIR/voice"

# Count lines
TOTAL_LINES=$(wc -l < "$LINES_FILE" | tr -d ' ')
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  BATCH VOICE RECORDING"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Recording $TOTAL_LINES voice lines to: $SESSION_DIR/voice/"
echo ""
echo "For each line:"
echo "  1. Read the line shown"
echo "  2. Press ENTER to start recording"
echo "  3. Speak the line clearly"
echo "  4. Press Ctrl+C to stop"
echo "  5. Choose to keep, re-record, or skip"
echo ""
read -p "Press ENTER to begin..."

LINE_NUM=0
while IFS= read -r LINE_TEXT || [[ -n "$LINE_TEXT" ]]; do
    ((LINE_NUM++))
    PADDED_NUM=$(printf "%02d" $LINE_NUM)
    OUT_FILE="$SESSION_DIR/voice/line_${PADDED_NUM}.wav"

    while true; do
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  LINE $LINE_NUM of $TOTAL_LINES"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "  Say: \"$LINE_TEXT\""
        echo ""
        echo "  Output: $OUT_FILE"
        echo ""
        read -p "Press ENTER to record (or 's' to skip)... " ACTION

        if [[ "$ACTION" == "s" || "$ACTION" == "S" ]]; then
            echo "Skipped line $LINE_NUM"
            break
        fi

        echo "Recording... (Ctrl+C to stop)"

        # Record audio
        ffmpeg -f avfoundation -i ":0" -ac 1 -ar 48000 -y "$OUT_FILE" 2>/dev/null || true

        echo ""
        echo "Saved: $OUT_FILE"

        # Play it back
        echo "Playing back..."
        afplay "$OUT_FILE" 2>/dev/null || true

        echo ""
        read -p "Keep this recording? [Y/n/r(e-record)] " KEEP

        if [[ "$KEEP" == "r" || "$KEEP" == "R" ]]; then
            echo "Re-recording..."
            continue
        elif [[ "$KEEP" == "n" || "$KEEP" == "N" ]]; then
            rm -f "$OUT_FILE"
            echo "Deleted. Skipping line."
            break
        else
            echo "Kept: line_${PADDED_NUM}.wav"
            break
        fi
    done
done < "$LINES_FILE"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  RECORDING COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Recorded files:"
ls -la "$SESSION_DIR/voice/"*.wav 2>/dev/null || echo "  (none)"
echo ""
echo "Next step: Process the voice files"
echo "  ./devlog/bin/process-voice.sh --all $SESSION_DIR"
