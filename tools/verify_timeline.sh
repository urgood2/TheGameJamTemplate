#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <timeline.jsonl>"
  exit 2
fi

TIMELINE="$1"

[ -f "$TIMELINE" ] || { echo "FAIL: Timeline not found"; exit 1; }

LINE_NUM=0
while IFS= read -r line; do
  LINE_NUM=$((LINE_NUM + 1))
  echo "$line" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null || {
    echo "FAIL: Invalid JSON at line $LINE_NUM"
    exit 1
  }
done < "$TIMELINE"

python3 << 'PYEOF' "$TIMELINE"
import json
import sys

path = sys.argv[1]
with open(path, "r") as f:
    for i, line in enumerate(f, 1):
        if not line.strip():
            continue
        event = json.loads(line)
        required = ["frame", "type", "ts"]
        missing = [field for field in required if field not in event]
        if missing:
            print(f"FAIL: Line {i} missing fields: {missing}")
            sys.exit(1)
print("PASS: All events valid")
PYEOF
