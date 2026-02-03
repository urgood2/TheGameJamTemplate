#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

LOG_PREFIX="[CHECK-FAST]"

log() {
    echo "${LOG_PREFIX} $*"
}

log "Starting fast validation..."
log "Running scripts/validate_schemas.py..."
python3 scripts/validate_schemas.py

log "Running scripts/validate_docs_and_registry.py..."
python3 scripts/validate_docs_and_registry.py

log "Running scripts/link_check_docs.py..."
python3 scripts/link_check_docs.py

log "PASS: Fast validation complete."
