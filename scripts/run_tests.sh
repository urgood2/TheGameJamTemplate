#!/usr/bin/env bash
set -euo pipefail

LOG_PREFIX="[CI]"

log() {
    echo "${LOG_PREFIX} $*"
}

json_get() {
    local path="$1"
    local key="$2"
    python3 - <<PY
import json
from pathlib import Path
path = Path("${path}")
try:
    data = json.loads(path.read_text())
    value = data
    for part in "${key}".split("."):
        if not part:
            continue
        value = value.get(part, None) if isinstance(value, dict) else None
    if isinstance(value, bool):
        print("true" if value else "false")
    elif value is None:
        print("")
    else:
        print(value)
except Exception:
    print("")
PY
}

json_list_failed_tests() {
    local path="$1"
    python3 - <<PY
import json
from pathlib import Path
path = Path("${path}")
try:
    data = json.loads(path.read_text())
    for entry in data.get("tests", []):
        status = str(entry.get("status", "")).lower()
        if status == "fail":
            test_id = entry.get("test_id", "unknown")
            message = entry.get("error", {}).get("message", "error")
            print(f"{test_id}: {message}")
except Exception:
    pass
PY
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

log "=========================================="
log "=== Test Suite CI Wrapper ==="
log "=========================================="
log "Started at: $(date -Iseconds)"
log "Platform: $(uname -s) $(uname -m)"
log "Git commit: $(git rev-parse HEAD 2>/dev/null || echo unknown)"
log "Git branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"

log "Starting engine with test scene..."
log "Command: ./build/raylib-cpp-cmake-template --scene test"

mkdir -p test_output
set +e
./build/raylib-cpp-cmake-template --scene test 2>&1 | tee test_output/test_log.txt
ENGINE_EXIT=${PIPESTATUS[0]}
set -e

log "Engine exited with code ${ENGINE_EXIT}"

log "Checking run_state.json..."
if [ ! -f "test_output/run_state.json" ]; then
    log "CRASH DETECTED: run_state.json missing"
    log "=== RESULT: CRASH ==="
    log "Exit code: 2"
    exit 2
fi

IN_PROGRESS=$(json_get "test_output/run_state.json" "in_progress")
LAST_STARTED=$(json_get "test_output/run_state.json" "last_test_started")
LAST_COMPLETED=$(json_get "test_output/run_state.json" "last_test_completed")

log "  File exists: yes"
log "  in_progress: ${IN_PROGRESS:-unknown}"
log "  last_test_completed: ${LAST_COMPLETED:-unknown}"

if [ "${IN_PROGRESS}" = "true" ]; then
    log "CRASH DETECTED: in_progress still true"
    log "  Last test started: ${LAST_STARTED:-unknown}"
    log "=== RESULT: CRASH ==="
    log "Exit code: 2"
    exit 2
fi

log "Checking status.json..."
if [ ! -f "test_output/status.json" ]; then
    log "ERROR: status.json not generated"
    log "=== RESULT: FAILURE ==="
    log "Exit code: 1"
    exit 1
fi

PASSED=$(json_get "test_output/status.json" "passed")
TOTAL=$(json_get "test_output/status.json" "total")
PASSED_COUNT=$(json_get "test_output/status.json" "passed_count")
FAILED_COUNT=$(json_get "test_output/status.json" "failed")
SKIPPED=$(json_get "test_output/status.json" "skipped")
DURATION=$(json_get "test_output/status.json" "duration_ms")

log "  passed: ${PASSED:-unknown}"
log "  total: ${TOTAL:-0}, passed: ${PASSED_COUNT:-0}, failed: ${FAILED_COUNT:-0}, skipped: ${SKIPPED:-0}"
log "  duration: ${DURATION:-0}ms"

if [ "${PASSED}" = "true" ]; then
    log "=========================================="
    log "=== RESULT: SUCCESS ==="
    log "=========================================="
    log "Exit code: 0"
    exit 0
fi

log "=========================================="
log "=== RESULT: FAILURE ==="
log "=========================================="
log "Exit code: 1"
log "Failed tests:"
json_list_failed_tests "test_output/results.json" | while read -r line; do
    if [ -n "$line" ]; then
        log "  - ${line}"
    fi
done
log "See test_output/report.md for details"
exit 1
