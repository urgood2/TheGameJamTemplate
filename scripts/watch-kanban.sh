#!/bin/bash
# watch-kanban.sh
# Watches Obsidian Kanban file and triggers sync on changes
#
# Requires: fswatch (brew install fswatch)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_SCRIPT="$SCRIPT_DIR/sync-kanban-to-todo.sh"
ROADMAP_SYNC_SCRIPT="/Users/joshuashin/conductor/repos/muscle-sim-website/scripts/sync-kanban-to-roadmap.sh"
KANBAN_FILE="/Users/joshuashin/Documents/Bramses-opinionated/Surviorslike Kanban.md"
LOG_FILE="$HOME/.kanban-sync/watcher.log"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Check if fswatch is installed
if ! command -v fswatch &> /dev/null; then
    log "ERROR: fswatch not installed. Run: brew install fswatch"
    exit 1
fi

log "Starting Kanban watcher for: $KANBAN_FILE"
log "TODO sync script: $SYNC_SCRIPT"
log "Roadmap sync script: $ROADMAP_SYNC_SCRIPT"

# Debounce: fswatch can fire multiple events rapidly when a file is saved
# We use --latency to batch events within 2 seconds
# Note: fswatch watches single files non-recursively by default
fswatch \
    --latency=2 \
    "$KANBAN_FILE" | while read -r event; do
    log "Change detected: $event"

    # Small delay to ensure file is fully written
    sleep 0.5

    # Run TODO sync (capture output for logging)
    if "$SYNC_SCRIPT" 2>&1 | tee -a "$LOG_FILE"; then
        log "TODO sync completed successfully"
    else
        exit_code=$?
        log "TODO sync exited with code: $exit_code"
    fi

    # Run roadmap sync for muscle-sim-website (if script exists)
    if [[ -x "$ROADMAP_SYNC_SCRIPT" ]]; then
        if "$ROADMAP_SYNC_SCRIPT" 2>&1 | tee -a "$LOG_FILE"; then
            log "Roadmap sync completed successfully"
        else
            exit_code=$?
            log "Roadmap sync exited with code: $exit_code"
        fi
    fi
done
