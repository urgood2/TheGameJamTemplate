#!/usr/bin/env bash
set -euo pipefail

# Usage: upload-helper.sh <manifest.json>
# Opens upload pages and copies caption to clipboard

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <manifest.json>"
    exit 1
fi

MANIFEST="$1"

if [[ ! -f "$MANIFEST" ]]; then
    echo "Error: Manifest not found: $MANIFEST"
    exit 1
fi

# Get video path
MANIFEST_DIR=$(dirname "$MANIFEST")
SESSION_DIR=$(dirname "$MANIFEST_DIR")
POST_NAME=$(basename "${MANIFEST%.json}")
VIDEO_FILE="$SESSION_DIR/out/${POST_NAME}.mp4"

if [[ ! -f "$VIDEO_FILE" ]]; then
    echo "Error: Video not found: $VIDEO_FILE"
    echo ""
    echo "Run render first:"
    echo "  ./devlog/bin/render.sh $MANIFEST"
    exit 1
fi

# Get caption from manifest
CAPTION=$(python3 -c "
import json
m = json.load(open('$MANIFEST'))
caption = m.get('upload', {}).get('caption', '')
print(caption)
" 2>/dev/null || echo "")

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  UPLOAD: $POST_NAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "VIDEO FILE:"
echo "  $VIDEO_FILE"
echo ""

# Copy caption to clipboard
if [[ -n "$CAPTION" ]]; then
    echo "CAPTION (copied to clipboard):"
    echo "┌────────────────────────────────────────────────"
    echo "$CAPTION" | sed 's/^/│ /'
    echo "└────────────────────────────────────────────────"
    echo ""
    echo "$CAPTION" | pbcopy
fi

# Open Finder to the video file
echo "Opening video file location..."
open -R "$VIDEO_FILE"

echo ""
echo "Opening upload pages..."
echo ""

# Open upload pages
open "https://www.tiktok.com/upload"
sleep 0.5
open "https://twitter.com/compose/tweet"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  UPLOAD CHECKLIST"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "TikTok:"
echo "  [ ] Drag video from Finder to TikTok"
echo "  [ ] Paste caption (Cmd+V)"
echo "  [ ] Add a trending sound!"
echo "  [ ] Post"
echo ""
echo "X (Twitter):"
echo "  [ ] Click media icon, select video"
echo "  [ ] Paste caption (Cmd+V)"
echo "  [ ] Post"
echo ""
