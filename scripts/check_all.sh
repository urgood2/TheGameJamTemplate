#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

LOG_PREFIX="[CHECK]"
TOTAL_STEPS=9
CURRENT_STEP=0
FAILED_STEPS=()

DRY_RUN=0
FAIL_STEP="${CHECK_ALL_FAIL_STEP:-0}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --fail-step)
            if [[ $# -lt 2 ]]; then
                echo "${LOG_PREFIX} ERROR: --fail-step requires a step number"
                exit 2
            fi
            FAIL_STEP="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

log() {
    echo "${LOG_PREFIX} $*"
}

format_duration() {
    local total="$1"
    local mins=$((total / 60))
    local secs=$((total % 60))
    if [ "$mins" -gt 0 ]; then
        echo "${mins}m ${secs}s"
    else
        echo "${secs}s"
    fi
}

run_cmd() {
    local label="$1"
    shift
    log "  Running ${label}..."
    if [ "$DRY_RUN" -eq 1 ]; then
        log "  DRY-RUN: $*"
        return 0
    fi
    if "$@"; then
        return 0
    fi
    return 1
}

run_step() {
    local name="$1"
    shift
    ((CURRENT_STEP++))
    log "[$CURRENT_STEP/$TOTAL_STEPS] ${name}..."

    if [[ "$FAIL_STEP" == "$CURRENT_STEP" ]]; then
        log "  FAIL (forced)"
        FAILED_STEPS+=("[$CURRENT_STEP/$TOTAL_STEPS] ${name}")
        return 1
    fi

    local start_time end_time duration
    start_time=$(date +%s)
    if "$@"; then
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        log "  PASS (${duration}s)"
        return 0
    else
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        log "  FAIL (${duration}s)"
        FAILED_STEPS+=("[$CURRENT_STEP/$TOTAL_STEPS] ${name}")
        return 1
    fi
}

step_toolchain() {
    run_cmd "scripts/doctor.py" python3 scripts/doctor.py || return 1
}

step_inventory() {
    run_cmd "scripts/extract_sol2_bindings.py" python3 scripts/extract_sol2_bindings.py || return 1
    run_cmd "scripts/extract_components.py" python3 scripts/extract_components.py || return 1
}

step_scope_stats() {
    run_cmd "scripts/recount_scope_stats.py" python3 scripts/recount_scope_stats.py || return 1
}

step_docs_skeletons() {
    run_cmd "scripts/generate_docs_skeletons.py" python3 scripts/generate_docs_skeletons.py || return 1
}

step_validate_schemas() {
    run_cmd "scripts/validate_schemas.py" python3 scripts/validate_schemas.py || return 1
}

step_registry_sync() {
    run_cmd "scripts/sync_registry_from_manifest.py" python3 scripts/sync_registry_from_manifest.py || return 1
}

step_docs_consistency() {
    run_cmd "scripts/validate_docs_and_registry.py" python3 scripts/validate_docs_and_registry.py || return 1
    run_cmd "scripts/link_check_docs.py" python3 scripts/link_check_docs.py || return 1
}

step_evidence_check() {
    run_cmd "scripts/sync_docs_evidence.py --check" python3 scripts/sync_docs_evidence.py --check || return 1
}

step_test_suite() {
    run_cmd "test harness" ./scripts/run_tests.sh || return 1
    run_cmd "coverage report" lua -e "package.path='assets/scripts/?.lua;assets/scripts/?/init.lua;'..package.path; local cr=require('test.test_coverage_report'); local ok=cr.generate('test_output/results.json','test_output/coverage_report.md'); if not ok then os.exit(1) end" || return 1
}

START_TIME=$(date +%s)

log "=========================================="
log "=== Full Verification Pipeline ==="
log "=========================================="
log "Started at: $(date -Iseconds)"
log ""

run_step "Validating toolchain" step_toolchain || true
run_step "Regenerating inventories" step_inventory || true
run_step "Regenerating scope stats" step_scope_stats || true
run_step "Regenerating doc skeletons" step_docs_skeletons || true
run_step "Validating schemas" step_validate_schemas || true
run_step "Syncing registry from manifest" step_registry_sync || true
run_step "Checking docs consistency" step_docs_consistency || true
run_step "Checking evidence blocks" step_evidence_check || true
run_step "Running test suite" step_test_suite || true

END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))
PASSED_STEPS=$((TOTAL_STEPS - ${#FAILED_STEPS[@]}))

log ""
log "=========================================="
if [ ${#FAILED_STEPS[@]} -eq 0 ]; then
    log "=== FINAL RESULT: PASS ==="
    log "All ${TOTAL_STEPS} steps passed."
    log "Total time: $(format_duration "$TOTAL_DURATION")"
    log "Passed steps: ${PASSED_STEPS}/${TOTAL_STEPS}"
    exit 0
else
    log "=== FINAL RESULT: FAIL ==="
    log "Failed steps:"
    for step in "${FAILED_STEPS[@]}"; do
        log "  - ${step}"
    done
    log "Total time: $(format_duration "$TOTAL_DURATION")"
    log "Passed steps: ${PASSED_STEPS}/${TOTAL_STEPS}"
    exit 1
fi
