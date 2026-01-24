#!/usr/bin/env bash
set -euo pipefail

# Usage: order-audio.sh <audio_dir> <script_file> [output_dir]
#
# Transcribes audio files using whisper and attempts to match them to script lines.
# Outputs a JSON mapping for Claude to verify and rename files.
#
# Requires: whisper (pip install openai-whisper) OR insanely-fast-whisper
#
# Example:
#   ./devlog/bin/order-audio.sh ./raw-recordings/ ./script.txt ./voice/
#
# Script file format (one line per expected recording):
#   So I found a bug in my game...
#   Look at this glitch.
#   But honestly? It looks kinda cool.
#   I think I'm keeping it.

AUDIO_DIR="${1:-}"
SCRIPT_FILE="${2:-}"
OUTPUT_DIR="${3:-}"

if [[ -z "$AUDIO_DIR" ]] || [[ -z "$SCRIPT_FILE" ]]; then
    echo "Usage: $0 <audio_dir> <script_file> [output_dir]"
    echo ""
    echo "Transcribes audio files and matches them to script lines."
    echo "If output_dir is provided, copies renamed files there."
    echo ""
    echo "Example:"
    echo "  $0 ./recordings/ ./lines.txt ./voice/"
    exit 1
fi

if [[ ! -d "$AUDIO_DIR" ]]; then
    echo "Error: Audio directory not found: $AUDIO_DIR"
    exit 1
fi

if [[ ! -f "$SCRIPT_FILE" ]]; then
    echo "Error: Script file not found: $SCRIPT_FILE"
    exit 1
fi

# Check for whisper
WHISPER_CMD=""
if command -v whisper &>/dev/null; then
    WHISPER_CMD="whisper"
elif command -v insanely-fast-whisper &>/dev/null; then
    WHISPER_CMD="insanely-fast-whisper"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  AUDIO ORDERING ASSISTANT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Audio directory: $AUDIO_DIR"
echo "Script file:     $SCRIPT_FILE"
echo "Output:          ${OUTPUT_DIR:-<mapping only>}"
echo ""

# Get audio files
AUDIO_FILES=$(find "$AUDIO_DIR" -maxdepth 1 -type f \( -name "*.wav" -o -name "*.mp3" -o -name "*.m4a" \) | sort)
AUDIO_COUNT=$(echo "$AUDIO_FILES" | grep -c . || echo 0)

# Get script lines
SCRIPT_LINES=$(cat "$SCRIPT_FILE")
SCRIPT_COUNT=$(echo "$SCRIPT_LINES" | grep -c . || echo 0)

echo "Found $AUDIO_COUNT audio files"
echo "Script has $SCRIPT_COUNT lines"
echo ""

if [[ "$AUDIO_COUNT" -ne "$SCRIPT_COUNT" ]]; then
    echo "Warning: Mismatch between audio files ($AUDIO_COUNT) and script lines ($SCRIPT_COUNT)"
    echo ""
fi

# Create temporary directory for transcriptions
TRANS_DIR=$(mktemp -d)
MAPPING_FILE="$AUDIO_DIR/audio_mapping.json"

if [[ -n "$WHISPER_CMD" ]]; then
    echo "Using $WHISPER_CMD for transcription..."
    echo ""

    # Transcribe each file
    declare -A TRANSCRIPTIONS

    while IFS= read -r audio_file; do
        [[ -z "$audio_file" ]] && continue
        filename=$(basename "$audio_file")
        echo "Transcribing: $filename"

        if [[ "$WHISPER_CMD" == "whisper" ]]; then
            # Standard whisper
            transcription=$($WHISPER_CMD "$audio_file" --model tiny --language en --output_format txt --output_dir "$TRANS_DIR" 2>/dev/null)
            trans_file="$TRANS_DIR/$(basename "${audio_file%.*}").txt"
            if [[ -f "$trans_file" ]]; then
                transcription=$(cat "$trans_file" | tr -d '\n' | xargs)
            fi
        else
            # insanely-fast-whisper
            transcription=$($WHISPER_CMD "$audio_file" --model-name tiny 2>/dev/null | grep -o '"text": "[^"]*"' | sed 's/"text": "//;s/"$//' || echo "")
        fi

        echo "  -> \"$transcription\""
        TRANSCRIPTIONS["$filename"]="$transcription"
    done <<< "$AUDIO_FILES"

    echo ""
    echo "Matching transcriptions to script lines..."
    echo ""

    # Create mapping JSON
    python3 << EOF
import json
import sys
from difflib import SequenceMatcher

# Script lines
script_lines = """$SCRIPT_LINES""".strip().split('\n')
script_lines = [l.strip() for l in script_lines if l.strip()]

# Transcriptions (from environment or inline)
transcriptions = {}
$(for f in "${!TRANSCRIPTIONS[@]}"; do echo "transcriptions['$f'] = '''${TRANSCRIPTIONS[$f]}'''"; done)

def similarity(a, b):
    return SequenceMatcher(None, a.lower(), b.lower()).ratio()

# Match transcriptions to script lines
matches = []
used_files = set()
used_lines = set()

for i, script_line in enumerate(script_lines):
    best_match = None
    best_score = 0

    for filename, trans in transcriptions.items():
        if filename in used_files:
            continue
        score = similarity(script_line, trans)
        if score > best_score:
            best_score = score
            best_match = filename

    if best_match and best_score > 0.3:  # Threshold
        matches.append({
            'line_num': i + 1,
            'script': script_line,
            'file': best_match,
            'transcription': transcriptions[best_match],
            'confidence': round(best_score, 2)
        })
        used_files.add(best_match)
    else:
        matches.append({
            'line_num': i + 1,
            'script': script_line,
            'file': None,
            'transcription': None,
            'confidence': 0
        })

# Output
result = {
    'matches': matches,
    'unmatched_files': [f for f in transcriptions.keys() if f not in used_files]
}

with open('$MAPPING_FILE', 'w') as f:
    json.dump(result, f, indent=2)

print(json.dumps(result, indent=2))
EOF
else
    echo "Whisper not found. Creating manual mapping template..."
    echo ""

    # Create template for manual matching
    python3 << EOF
import json

script_lines = """$SCRIPT_LINES""".strip().split('\n')
script_lines = [l.strip() for l in script_lines if l.strip()]

audio_files = """$AUDIO_FILES""".strip().split('\n')
audio_files = [f.split('/')[-1] for f in audio_files if f.strip()]

result = {
    'script_lines': [{'num': i+1, 'text': line} for i, line in enumerate(script_lines)],
    'audio_files': audio_files,
    'matches': [
        {'line_num': i+1, 'script': line, 'file': None, 'transcription': '(needs review)'}
        for i, line in enumerate(script_lines)
    ],
    'instructions': 'Claude should listen to each audio file and match to script lines'
}

with open('$MAPPING_FILE', 'w') as f:
    json.dump(result, f, indent=2)

print("Manual matching required. Mapping template saved to:")
print(f"  $MAPPING_FILE")
print("")
print("Audio files to match:")
for f in audio_files:
    print(f"  - {f}")
print("")
print("Script lines:")
for i, line in enumerate(script_lines):
    print(f"  {i+1}. {line}")
EOF
fi

echo ""

# If output directory specified and mapping complete, copy files
if [[ -n "$OUTPUT_DIR" ]] && [[ -f "$MAPPING_FILE" ]]; then
    echo ""
    echo "To apply the mapping and rename files, run:"
    echo "  python3 devlog/bin/apply-audio-mapping.py $MAPPING_FILE $AUDIO_DIR $OUTPUT_DIR"
fi

rm -rf "$TRANS_DIR"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  DONE - Review mapping in $MAPPING_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
