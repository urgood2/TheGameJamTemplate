#!/bin/bash
# sync-kanban-to-todo.sh
# Syncs Obsidian Kanban to TODO_prototype.md with conflict detection
#
# Usage: ./sync-kanban-to-todo.sh [--force]
#   --force: Overwrite even if conflicts detected

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════════

KANBAN_FILE="/Users/joshuashin/Documents/Bramses-opinionated/Surviorslike Kanban.md"
TODO_FILE="/Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/docs/project-management/todos/TODO_prototype.md"
SYNC_STATE_DIR="$HOME/.kanban-sync"
HASH_FILE="$SYNC_STATE_DIR/last-sync-hash"
KANBAN_HASH_FILE="$SYNC_STATE_DIR/last-kanban-hash"
LOG_FILE="$SYNC_STATE_DIR/sync.log"

# Section markers in TODO_prototype.md
SYNC_START_MARKER="<!-- KANBAN-SYNC-START -->"
SYNC_END_MARKER="<!-- KANBAN-SYNC-END -->"

# ═══════════════════════════════════════════════════════════════════════════════
# Setup
# ═══════════════════════════════════════════════════════════════════════════════

mkdir -p "$SYNC_STATE_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

notify() {
    # macOS notification
    if command -v terminal-notifier &> /dev/null; then
        terminal-notifier -title "Kanban Sync" -message "$1" -sound default
    else
        echo "NOTIFICATION: $1"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Parse Kanban file and transform to readable markdown
# ═══════════════════════════════════════════════════════════════════════════════

transform_kanban() {
    local input_file="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Read the kanban file
    local content
    content=$(cat "$input_file")

    # Remove YAML frontmatter (--- ... ---) - macOS sed compatible
    content=$(echo "$content" | awk '
        BEGIN { in_front=0; skip_next_blank=0 }
        /^---$/ && !in_front { in_front=1; next }
        /^---$/ && in_front { in_front=0; skip_next_blank=1; next }
        in_front { next }
        skip_next_blank && /^[[:space:]]*$/ { skip_next_blank=0; next }
        { skip_next_blank=0; print }
    ')

    # Remove kanban settings block at end (%% kanban:settings ... %%)
    content=$(echo "$content" | awk '/^%% kanban:settings/,0 { next } { print }')

    # Collapse multiple blank lines into single blank line
    content=$(echo "$content" | cat -s)

    # Trim leading/trailing whitespace
    content=$(echo "$content" | sed -e '/./,$!d' -e :a -e '/^\n*$/{$d;N;ba' -e '}')

    # Build the synced section
    cat <<EOF
$SYNC_START_MARKER
## Synced from Obsidian Kanban
> Last synced: $timestamp
> Source: \`Surviorslike Kanban.md\`

$content

$SYNC_END_MARKER
EOF
}

# ═══════════════════════════════════════════════════════════════════════════════
# Extract current synced section from TODO file (if exists)
# ═══════════════════════════════════════════════════════════════════════════════

get_current_synced_section() {
    local todo_file="$1"
    if [[ -f "$todo_file" ]] && grep -q "$SYNC_START_MARKER" "$todo_file"; then
        sed -n "/$SYNC_START_MARKER/,/$SYNC_END_MARKER/p" "$todo_file"
    else
        echo ""
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Get content below synced section (user's manual content)
# ═══════════════════════════════════════════════════════════════════════════════

get_content_below_sync() {
    local todo_file="$1"
    if [[ -f "$todo_file" ]] && grep -q "$SYNC_END_MARKER" "$todo_file"; then
        # Get everything after the sync end marker
        sed -n "/$SYNC_END_MARKER/,\$p" "$todo_file" | tail -n +2
    elif [[ -f "$todo_file" ]]; then
        # No sync section exists yet, return entire file
        cat "$todo_file"
    else
        echo ""
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Conflict Detection
# ═══════════════════════════════════════════════════════════════════════════════

compute_hash() {
    echo "$1" | shasum -a 256 | cut -d' ' -f1
}

check_for_conflicts() {
    # Check if the synced section in TODO was manually edited
    local current_synced_section
    current_synced_section=$(get_current_synced_section "$TODO_FILE")

    if [[ -z "$current_synced_section" ]]; then
        # No synced section yet, no conflict possible
        return 0
    fi

    if [[ ! -f "$HASH_FILE" ]]; then
        # First run with existing sync section - assume it's valid
        return 0
    fi

    local stored_hash
    stored_hash=$(cat "$HASH_FILE")

    local current_hash
    current_hash=$(compute_hash "$current_synced_section")

    if [[ "$stored_hash" != "$current_hash" ]]; then
        # Synced section was modified manually!
        return 1
    fi

    return 0
}

check_kanban_changed() {
    # Check if kanban file actually changed since last sync
    # Note: Use cat | shasum instead of shasum directly to work around macOS FDA restrictions
    local current_kanban_hash
    current_kanban_hash=$(cat "$KANBAN_FILE" 2>/dev/null | shasum -a 256 | cut -d' ' -f1)

    if [[ -z "$current_kanban_hash" ]]; then
        log "WARNING: Could not read Kanban file for hash check"
        return 0  # Assume changed if we can't read
    fi

    if [[ -f "$KANBAN_HASH_FILE" ]]; then
        local stored_kanban_hash
        stored_kanban_hash=$(cat "$KANBAN_HASH_FILE")

        if [[ "$stored_kanban_hash" == "$current_kanban_hash" ]]; then
            return 1  # No change
        fi
    fi

    return 0  # Changed (or first run)
}

# ═══════════════════════════════════════════════════════════════════════════════
# Main Sync Logic
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    local force_sync=false

    if [[ "${1:-}" == "--force" ]]; then
        force_sync=true
        log "Force sync requested"
    fi

    # Validate source file exists
    if [[ ! -f "$KANBAN_FILE" ]]; then
        log "ERROR: Kanban file not found: $KANBAN_FILE"
        notify "Sync failed: Kanban file not found"
        exit 1
    fi

    # Check if kanban actually changed
    if ! check_kanban_changed; then
        log "Kanban file unchanged, skipping sync"
        exit 0
    fi

    # Check for conflicts
    if ! $force_sync && ! check_for_conflicts; then
        log "CONFLICT DETECTED: Synced section in TODO_prototype.md was manually edited"
        log "Use --force to overwrite, or manually resolve the conflict"
        notify "Sync conflict! Synced section was manually edited."
        exit 2
    fi

    # Transform kanban to markdown
    local new_synced_section
    new_synced_section=$(transform_kanban "$KANBAN_FILE")

    # Get existing content below sync section
    local content_below
    content_below=$(get_content_below_sync "$TODO_FILE")

    # Write the updated file
    {
        echo "$new_synced_section"
        echo ""
        echo "$content_below"
    } > "$TODO_FILE"

    # Store hashes for next conflict check
    local final_synced_section
    final_synced_section=$(get_current_synced_section "$TODO_FILE")
    compute_hash "$final_synced_section" > "$HASH_FILE"
    # Use cat | shasum to work around macOS FDA restrictions
    cat "$KANBAN_FILE" 2>/dev/null | shasum -a 256 | cut -d' ' -f1 > "$KANBAN_HASH_FILE"

    log "Successfully synced Kanban to TODO_prototype.md"
    notify "Kanban synced successfully"
}

main "$@"
