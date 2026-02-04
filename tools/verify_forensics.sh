#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <forensics_dir>"
  exit 2
fi

FORENSICS_DIR="$1"
FAIL=0

check_file() {
  if [ -f "$FORENSICS_DIR/$1" ]; then
    echo "OK: $1"
  else
    echo "MISSING: $1"
    FAIL=1
  fi
}

check_optional() {
  if [ -f "$FORENSICS_DIR/$1" ]; then
    echo "OK (optional): $1"
  else
    echo "SKIPPED (optional): $1"
  fi
}

echo "=== Verifying Forensics Bundle ==="
check_file "run_manifest.json"
check_file "logs.jsonl"
check_file "timeline.jsonl"
check_file "last_logs.txt"
check_file "repro.sh"
check_file "repro.ps1"
check_file "test_api.json"

check_optional "final_frame.png"
check_optional "failure_clip.webm"
check_optional "hang_dump.json"
check_optional "determinism_diff.json"
check_optional "trace.json"

for json in run_manifest.json test_api.json; do
  if [ -f "$FORENSICS_DIR/$json" ]; then
    python3 -c "import json; json.load(open('$FORENSICS_DIR/$json'))" 2>/dev/null || {
      echo "INVALID JSON: $json"
      FAIL=1
    }
  fi
done

if [ -x "$FORENSICS_DIR/repro.sh" ]; then
  echo "OK: repro.sh is executable"
else
  echo "ERROR: repro.sh not executable"
  FAIL=1
fi

exit $FAIL
