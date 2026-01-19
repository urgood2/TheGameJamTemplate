#!/bin/bash
# install-kanban-sync.sh
# Installs the Kanban sync service as a launchd agent (runs on login)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLIST_SOURCE="$SCRIPT_DIR/com.joshuashin.kanban-sync.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/com.joshuashin.kanban-sync.plist"
SERVICE_NAME="com.joshuashin.kanban-sync"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║           Kanban Sync Service Installer                    ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check dependencies
echo "Checking dependencies..."
if ! command -v fswatch &> /dev/null; then
    echo "❌ fswatch not found. Installing via Homebrew..."
    brew install fswatch
fi

if ! command -v terminal-notifier &> /dev/null; then
    echo "⚠️  terminal-notifier not found. Notifications will be disabled."
    echo "   Install with: brew install terminal-notifier"
fi

echo "✅ Dependencies OK"
echo ""

# Create state directory
mkdir -p "$HOME/.kanban-sync"

# Stop existing service if running
if launchctl list | grep -q "$SERVICE_NAME"; then
    echo "Stopping existing service..."
    launchctl unload "$PLIST_DEST" 2>/dev/null || true
fi

# Copy plist to LaunchAgents
echo "Installing launchd plist..."
mkdir -p "$HOME/Library/LaunchAgents"
cp "$PLIST_SOURCE" "$PLIST_DEST"

# Load the service
echo "Starting service..."
launchctl load "$PLIST_DEST"

# Run initial sync
echo "Running initial sync..."
"$SCRIPT_DIR/sync-kanban-to-todo.sh" --force || true

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                    Installation Complete!                  ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "⚠️  IMPORTANT: macOS Full Disk Access Required"
echo ""
echo "Your Kanban file is in ~/Documents which requires Full Disk Access."
echo "The launchd service won't work until you grant access:"
echo ""
echo "  1. Open System Settings → Privacy & Security → Full Disk Access"
echo "  2. Click '+' and add: /bin/bash"
echo "     (Press Cmd+Shift+G and type /bin/bash)"
echo "  3. Restart the service: launchctl unload then load the plist"
echo ""
echo "Alternative: Run the watcher manually in a Terminal window:"
echo "  $SCRIPT_DIR/watch-kanban.sh"
echo ""
echo "Commands:"
echo "  • Check status:     launchctl list | grep kanban"
echo "  • View logs:        tail -f ~/.kanban-sync/sync.log"
echo "  • Manual sync:      $SCRIPT_DIR/sync-kanban-to-todo.sh"
echo "  • Force sync:       $SCRIPT_DIR/sync-kanban-to-todo.sh --force"
echo "  • Stop service:     launchctl unload $PLIST_DEST"
echo "  • Start service:    launchctl load $PLIST_DEST"
echo "  • Uninstall:        $SCRIPT_DIR/uninstall-kanban-sync.sh"
echo ""
