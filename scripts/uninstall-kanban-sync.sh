#!/bin/bash
# uninstall-kanban-sync.sh
# Removes the Kanban sync service

set -euo pipefail

PLIST_DEST="$HOME/Library/LaunchAgents/com.joshuashin.kanban-sync.plist"
SERVICE_NAME="com.joshuashin.kanban-sync"

echo "Uninstalling Kanban sync service..."

# Stop service if running
if launchctl list | grep -q "$SERVICE_NAME"; then
    echo "Stopping service..."
    launchctl unload "$PLIST_DEST" 2>/dev/null || true
fi

# Remove plist
if [[ -f "$PLIST_DEST" ]]; then
    echo "Removing launchd plist..."
    rm "$PLIST_DEST"
fi

echo ""
echo "✅ Service uninstalled."
echo ""
echo "Note: State files preserved in ~/.kanban-sync/"
echo "      Delete manually if desired: rm -rf ~/.kanban-sync"
echo ""
echo "The synced section in TODO_prototype.md is preserved."
echo "Remove manually if desired (between the <!-- KANBAN-SYNC --> markers)"
