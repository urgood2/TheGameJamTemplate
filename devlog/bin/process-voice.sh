#!/usr/bin/env bash
set -euo pipefail

# Usage: process-voice.sh <input.wav> [output.wav]
#    or: process-voice.sh --all [session_dir]
#
# Examples:
#   ./devlog/bin/process-voice.sh voice/line_01.wav
#   ./devlog/bin/process-voice.sh --all devlog/sessions/2024-01-15

# Process all voice files in a session
if [[ "${1:-}" == "--all" ]]; then
    SESSION_DIR="${2:-devlog/sessions/$(date +%F)}"
    VOICE_DIR="$SESSION_DIR/voice"

    if [[ ! -d "$VOICE_DIR" ]]; then
        echo "Error: Voice directory not found: $VOICE_DIR"
        exit 1
    fi

    echo "Processing all voice files in: $VOICE_DIR"
    echo ""

    for wav in "$VOICE_DIR"/line_*.wav; do
        if [[ -f "$wav" && ! "$wav" == *"_processed.wav" ]]; then
            OUT="${wav%.wav}_processed.wav"
            echo "Processing: $(basename "$wav")"
            ffmpeg -y -i "$wav" \
                -af "highpass=f=80,lowpass=f=12000,loudnorm=I=-16:TP=-1.5:LRA=11" \
                "$OUT" 2>/dev/null
            echo "  -> $(basename "$OUT")"
        fi
    done

    echo ""
    echo "Done! Processed files are named *_processed.wav"
    exit 0
fi

# Process single file
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <input.wav> [output.wav]"
    echo "   or: $0 --all [session_dir]"
    exit 1
fi

IN="$1"
OUT="${2:-${IN%.wav}_processed.wav}"

if [[ ! -f "$IN" ]]; then
    echo "Error: Input file not found: $IN"
    exit 1
fi

mkdir -p "$(dirname "$OUT")"

echo "Processing: $IN"
echo "Output: $OUT"
echo ""

# Audio processing chain:
# - highpass=f=80: Remove low rumble (AC, room noise)
# - lowpass=f=12000: Remove high hiss
# - loudnorm: Normalize to -16 LUFS (standard for web video)
ffmpeg -y -i "$IN" \
    -af "highpass=f=80,lowpass=f=12000,loudnorm=I=-16:TP=-1.5:LRA=11" \
    "$OUT" 2>/dev/null

echo "Done! Created: $OUT"

# Show duration
DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$OUT" 2>/dev/null)
echo "Duration: ${DURATION}s"
