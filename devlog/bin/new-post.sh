#!/usr/bin/env bash
set -euo pipefail

POST_NAME="${1:-post1}"
SESSION_DIR="${2:-devlog/sessions/$(date +%F)}"

META_FILE="$SESSION_DIR/meta/$POST_NAME.json"

if [[ -f "$META_FILE" ]]; then
    echo "Post already exists: $META_FILE"
    exit 1
fi

mkdir -p "$SESSION_DIR/meta"

cat > "$META_FILE" << 'EOF'
{
  "title": "YOUR TITLE HERE",
  "subtitle": "Brief description of what changed",
  "fps": 30,
  "clips": [
    { "src": "clips/clip1.mp4", "durationInFrames": 150 }
  ],
  "voice": { "src": "voice/voice_processed.wav", "startFrame": 0 },
  "caption": "Working on something cool!\n\n#gamedev #indiedev #gamejam"
}
EOF

echo "Created post manifest: $META_FILE"
echo ""
echo "Edit the manifest to configure your post:"
echo "  - title: Hook text (first 3 seconds)"
echo "  - subtitle: Supporting text"
echo "  - clips: Array of video clips to stitch"
echo "  - voice: Voiceover audio file"
echo "  - caption: TikTok/X post caption with hashtags"
