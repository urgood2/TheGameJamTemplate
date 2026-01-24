#!/usr/bin/env bash
# Trim a clip from a recording
# Usage: ./trim.sh <input.mp4> <start_time> <end_time> <output.mp4>
# Example: ./trim.sh raw/record_143022.mp4 00:01:23 00:01:35 clips/combo_showcase.mp4
set -euo pipefail

if [[ $# -lt 4 ]]; then
    echo "Usage: $0 <input.mp4> <start_time> <end_time> <output.mp4>"
    echo "Example: $0 raw/record_143022.mp4 00:01:23 00:01:35 clips/combo.mp4"
    exit 1
fi

IN="$1"
START="$2"
END="$3"
OUT="$4"

mkdir -p "$(dirname "$OUT")"

echo "Trimming: $IN"
echo "  From: $START to $END"
echo "  Output: $OUT"

ffmpeg -y -i "$IN" -ss "$START" -to "$END" \
  -c:v libx264 -preset veryfast -crf 18 -pix_fmt yuv420p \
  -c:a aac -b:a 192k \
  "$OUT"

echo "Done! Created: $OUT"
