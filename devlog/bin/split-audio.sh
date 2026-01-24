#!/usr/bin/env bash
set -euo pipefail

# Usage: split-audio.sh <input.wav> <output_dir> [silence_threshold] [min_silence_duration]
# Splits audio on silence into separate line files
#
# Example: ./devlog/bin/split-audio.sh batch_recording.wav ./voice/
#
# Parameters:
#   silence_threshold: dB level for silence detection (default: -30dB)
#   min_silence_duration: seconds of silence to split on (default: 0.5)

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <input.wav> <output_dir> [silence_threshold_db] [min_silence_sec]"
    echo ""
    echo "Example: $0 my_recording.wav ./voice/"
    echo "         $0 my_recording.wav ./voice/ -35 0.8"
    exit 1
fi

INPUT="$1"
OUTPUT_DIR="$2"
SILENCE_THRESH="${3:--30}"  # Default -30dB
MIN_SILENCE="${4:-0.5}"     # Default 0.5 seconds

if [[ ! -f "$INPUT" ]]; then
    echo "Error: Input file not found: $INPUT"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  SPLITTING AUDIO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Input:            $INPUT"
echo "Output directory: $OUTPUT_DIR"
echo "Silence threshold: ${SILENCE_THRESH}dB"
echo "Min silence gap:   ${MIN_SILENCE}s"
echo ""

# Detect silence and get timestamps
echo "Detecting silence..."
SILENCE_LOG=$(mktemp)

ffmpeg -i "$INPUT" -af "silencedetect=noise=${SILENCE_THRESH}dB:d=${MIN_SILENCE}" -f null - 2>&1 | \
    grep "silence_" > "$SILENCE_LOG" || true

# Parse silence timestamps and split
python3 << EOF
import re
import subprocess
import os

silence_log = open('$SILENCE_LOG').read()
input_file = '$INPUT'
output_dir = '$OUTPUT_DIR'

# Get total duration
result = subprocess.run([
    'ffprobe', '-v', 'error', '-show_entries', 'format=duration',
    '-of', 'default=noprint_wrappers=1:nokey=1', input_file
], capture_output=True, text=True)
total_duration = float(result.stdout.strip())

# Parse silence start/end times
silence_starts = re.findall(r'silence_start: ([\d.]+)', silence_log)
silence_ends = re.findall(r'silence_end: ([\d.]+)', silence_log)

# Build segments (voice between silences)
segments = []
current_pos = 0.0

for i, (start, end) in enumerate(zip(silence_starts, silence_ends)):
    start = float(start)
    end = float(end)
    
    # Voice segment before this silence
    if start > current_pos + 0.1:  # At least 0.1s of content
        segments.append((current_pos, start))
    
    current_pos = end

# Final segment after last silence
if total_duration > current_pos + 0.1:
    segments.append((current_pos, total_duration))

if not segments:
    print("No voice segments detected. Try adjusting threshold.")
    exit(1)

print(f"Found {len(segments)} voice segments")
print("")

# Extract each segment
for i, (start, end) in enumerate(segments):
    output_file = os.path.join(output_dir, f'line_{i+1:02d}.wav')
    duration = end - start
    
    # Add small padding
    pad_start = max(0, start - 0.05)
    pad_duration = duration + 0.1
    
    subprocess.run([
        'ffmpeg', '-y', '-i', input_file,
        '-ss', str(pad_start),
        '-t', str(pad_duration),
        '-c:a', 'pcm_s16le',
        output_file
    ], capture_output=True)
    
    print(f"  line_{i+1:02d}.wav  ({duration:.1f}s)")

print("")
print(f"Split into {len(segments)} files in {output_dir}")
EOF

rm -f "$SILENCE_LOG"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  DONE!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "  1. Review the split files in $OUTPUT_DIR"
echo "  2. Delete any bad takes or silence files"
echo "  3. Rename if needed (keep line_XX format)"
echo "  4. Run: ./devlog/bin/process-voice.sh --all"
