#!/usr/bin/env bash
set -euo pipefail

# Usage: render.sh <manifest.json>
# Example: ./devlog/bin/render.sh devlog/sessions/2024-01-15/meta/video.json

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <manifest.json>"
    echo "Example: $0 devlog/sessions/2024-01-15/meta/video.json"
    exit 1
fi

MANIFEST="$1"

if [[ ! -f "$MANIFEST" ]]; then
    echo "Error: Manifest not found: $MANIFEST"
    exit 1
fi

# Derive paths
MANIFEST_DIR=$(dirname "$MANIFEST")
SESSION_DIR=$(dirname "$MANIFEST_DIR")
POST_NAME=$(basename "${MANIFEST%.json}")
OUTPUT="$SESSION_DIR/out/${POST_NAME}.mp4"
ASSETS_DIR="devlog/remotion/public/assets/${POST_NAME}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  RENDERING: $POST_NAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Manifest: $MANIFEST"
echo "Output:   $OUTPUT"
echo ""

# Create output directories
mkdir -p "$SESSION_DIR/out"
mkdir -p "$ASSETS_DIR"

echo "Copying assets..."

# Extract and copy all media files from segments
python3 << EOF
import json
import shutil
import os

manifest = json.load(open('$MANIFEST'))
assets_dir = '$ASSETS_DIR'
session_dir = '$SESSION_DIR'
manifest_dir = '$MANIFEST_DIR'

for i, segment in enumerate(manifest.get('segments', [])):
    # Copy media file
    media = segment.get('media')
    if media:
        if media.startswith('../') or media.startswith('./'):
            src = os.path.normpath(os.path.join(manifest_dir, media))
        elif media.startswith('/'):
            src = media
        else:
            src = os.path.join(session_dir, media)

        if os.path.exists(src):
            dst = os.path.join(assets_dir, os.path.basename(src))
            shutil.copy2(src, dst)
            print(f"  Copied: {os.path.basename(src)}")
        else:
            print(f"  Warning: Media not found: {src}")

    # Copy voice file
    voice = segment.get('voice')
    if voice:
        if voice.startswith('../') or voice.startswith('./'):
            src = os.path.normpath(os.path.join(manifest_dir, voice))
        elif voice.startswith('/'):
            src = voice
        else:
            src = os.path.join(session_dir, voice)

        if os.path.exists(src):
            dst = os.path.join(assets_dir, os.path.basename(src))
            shutil.copy2(src, dst)
            print(f"  Copied: {os.path.basename(src)}")
        else:
            print(f"  Warning: Voice not found: {src}")

    # Copy SFX file
    sfx = segment.get('sfx')
    if sfx:
        if sfx.startswith('../') or sfx.startswith('./'):
            src = os.path.normpath(os.path.join(manifest_dir, sfx))
        elif sfx.startswith('/'):
            src = sfx
        else:
            src = os.path.join(session_dir, sfx)

        if os.path.exists(src):
            dst = os.path.join(assets_dir, os.path.basename(src))
            shutil.copy2(src, dst)
            print(f"  Copied SFX: {os.path.basename(src)}")
        else:
            print(f"  Warning: SFX not found: {src}")
EOF

echo ""

# Install Remotion dependencies if needed
cd devlog/remotion
if [[ ! -d "node_modules" ]]; then
    echo "Installing Remotion dependencies (first time only)..."
    npm install
    echo ""
fi

# Transform manifest paths to point to public/assets/
PROPS=$(python3 << EOF
import json
import os

manifest = json.load(open('../../$MANIFEST'))
post_name = '$POST_NAME'

# Update segment paths to point to public assets
for segment in manifest.get('segments', []):
    if segment.get('media'):
        segment['media'] = f"assets/{post_name}/{os.path.basename(segment['media'])}"
    if segment.get('voice'):
        segment['voice'] = f"assets/{post_name}/{os.path.basename(segment['voice'])}"
    if segment.get('sfx'):
        segment['sfx'] = f"assets/{post_name}/{os.path.basename(segment['sfx'])}"

print(json.dumps(manifest))
EOF
)

echo "Rendering video..."
echo ""

# Render using Remotion
npx remotion render DevlogVideo "../../$OUTPUT" --props="$PROPS"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  DONE!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Video saved to: $OUTPUT"
echo ""

# Get caption from manifest if available
CAPTION=$(python3 -c "import json; m=json.load(open('../../$MANIFEST')); print(m.get('upload', {}).get('caption', ''))" 2>/dev/null || echo "")
if [[ -n "$CAPTION" ]]; then
    echo "Caption (copied to clipboard):"
    echo "$CAPTION"
    echo "$CAPTION" | pbcopy
fi
