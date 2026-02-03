#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[PYTEST] Running scripts unit tests..."
set +e

# Try multiple methods to run pytest
if command -v pytest &> /dev/null; then
    output=$(pytest -q "$SCRIPT_DIR/tests" "$@")
elif command -v uv &> /dev/null; then
    output=$(uv run --with pytest pytest -q "$SCRIPT_DIR/tests" "$@")
elif python3 -c "import pytest" 2>/dev/null; then
    output=$(python3 -m pytest -q "$SCRIPT_DIR/tests" "$@")
else
    echo "[PYTEST] FAIL: pytest not found. Install with: pip install pytest"
    echo "Or use: uv run --with pytest pytest scripts/tests"
    exit 1
fi
status=$?
set -e

echo "$output"

if [ $status -eq 0 ]; then
    # Extract count from "12 passed in 0.08s" style output
    count=$(echo "$output" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' | tail -1)
    if [ -n "$count" ]; then
        echo "[PYTEST] PASS: ${count} tests"
    else
        echo "[PYTEST] PASS: tests"
    fi
    exit 0
fi

echo "[PYTEST] FAIL: pytest failures above"
exit $status
