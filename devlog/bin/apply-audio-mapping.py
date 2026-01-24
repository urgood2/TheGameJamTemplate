#!/usr/bin/env python3
"""
Apply audio mapping to rename and organize voice files.

Usage: python3 apply-audio-mapping.py <mapping.json> <source_dir> <output_dir>
"""

import json
import shutil
import os
import sys

if len(sys.argv) < 4:
    print("Usage: python3 apply-audio-mapping.py <mapping.json> <source_dir> <output_dir>")
    sys.exit(1)

mapping_file = sys.argv[1]
source_dir = sys.argv[2]
output_dir = sys.argv[3]

# Load mapping
with open(mapping_file) as f:
    data = json.load(f)

# Create output directory
os.makedirs(output_dir, exist_ok=True)

print(f"Applying mapping from {mapping_file}")
print(f"Source: {source_dir}")
print(f"Output: {output_dir}")
print("")

# Process matches
for match in data.get('matches', []):
    line_num = match.get('line_num')
    source_file = match.get('file')

    if not source_file:
        print(f"  line_{line_num:02d} - SKIPPED (no match)")
        continue

    source_path = os.path.join(source_dir, source_file)
    if not os.path.exists(source_path):
        print(f"  line_{line_num:02d} - ERROR: Source not found: {source_file}")
        continue

    # Preserve extension
    ext = os.path.splitext(source_file)[1]
    dest_name = f"line_{line_num:02d}{ext}"
    dest_path = os.path.join(output_dir, dest_name)

    shutil.copy2(source_path, dest_path)
    print(f"  line_{line_num:02d}{ext} <- {source_file}")

print("")
print(f"Files copied to {output_dir}")
print("")
print("Next: Run process-voice.sh --all to normalize audio")
