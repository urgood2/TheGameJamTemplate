#!/usr/bin/env bash
# Convert landscape video to TikTok/Shorts vertical format (1080x1920)
# Uses blurred background + centered gameplay
# Usage: ./make-vertical.sh <input.mp4> <output.mp4>
set -euo pipefail

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <input.mp4> <output.mp4>"
    echo "Converts landscape video to 9:16 vertical with blurred background"
    exit 1
fi

IN="$1"
OUT="$2"

mkdir -p "$(dirname "$OUT")"

echo "Converting to vertical format..."
echo "  Input: $IN"
echo "  Output: $OUT"

ffmpeg -y -i "$IN" -filter_complex "\
[0:v]scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,boxblur=20:1[bg]; \
[0:v]scale=1080:-2:force_original_aspect_ratio=decrease[fg]; \
[bg][fg]overlay=(W-w)/2:(H-h)/2" \
-c:v libx264 -preset veryfast -crf 18 -pix_fmt yuv420p \
-c:a aac -b:a 192k \
"$OUT"

echo "Done! Created vertical video: $OUT"
