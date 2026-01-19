#!/bin/zsh
# Net Worth Monthly Capture Script
# Usage: ./capture-net-worth.sh [--force]
# Requires: Shortcut "Net Worth Screenshot" in macOS Shortcuts app

set -e

VAULT_PATH="/Users/joshuashin/Documents/Bramses-opinionated"
NETWORTH_DIR="$VAULT_PATH/Net Worth"
TEMPLATE="$NETWORTH_DIR/templates/monthly-entry-template.md"
SCREENSHOTS_DIR="$NETWORTH_DIR/screenshots"
LOG_FILE="$HOME/.net-worth-tracker.log"

# Create directories
mkdir -p "$SCREENSHOTS_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Get current date info
CURRENT_DATE%Y-%m=$(date '+-%d')
CURRENT_MONTH=$(date '+%Y-%m')
CURRENT_YEAR=$(date '+%Y')
MONTH_NAME=$(date '+%B')
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

SCREENSHOT_NAME="net-worth-${CURRENT_MONTH}-${TIMESTAMP}.png"
SCREENSHOT_PATH="$SCREENSHOTS_DIR/$SCREENSHOT_NAME"

log "Starting net worth capture for $MONTH_NAME $CURRENT_YEAR"

# Step 1: Capture screenshot using Shortcuts (or fallback to screencapture)
if shortcuts run "Net Worth Screenshot" 2>/dev/null; then
    log "Shortcuts shortcut executed"
    # Shortcuts should save to a known location, or use IPC
    # For now, we'll use screencapture as backup
else
    log "Shortcuts not available, using screencapture"
fi

# Capture screenshot interactively (user selects window/region)
echo "📸 Taking net worth screenshot..."
screencapture -i "$SCREENSHOT_PATH"

if [ ! -f "$SCREENSHOT_PATH" ]; then
    log "ERROR: Screenshot failed"
    echo "❌ Screenshot failed. Please capture manually and save to:"
    echo "$SCREENSHOT_PATH"
    exit 1
fi

log "Screenshot saved: $SCREENSHOT_PATH"

# Step 2: Get net worth amount from user (or prompt)
echo "💰 Enter net worth amount (e.g., $1,234,567):"
read NET_WORTH

if [ -z "$NET_WORTH" ]; then
    log "ERROR: No net worth entered"
    echo "❌ No net worth entered. Skipping this month."
    exit 1
fi

# Step 3: Calculate change from previous month (if exists)
LAST_ENTRY=$(ls -1 "$NETWORTH_DIR"/net-worth-*.md 2>/dev/null | sort -r | head -1)

if [ -n "$LAST_ENTRY" ] && [ -f "$LAST_ENTRY" ]; then
    LAST_NET_WORTH=$(grep -oP 'net_worth: \K.*' "$LAST_ENTRY" | tr -d '$,')
    LAST_DATE=$(grep -oP 'date: \K.*' "$LAST_ENTRY")
    
    if [ -n "$LAST_NET_WORTH" ] && [ "$LAST_NET_WORTH" != "null" ]; then
        # Calculate change (simple string comparison for display)
        CHANGE="$NET_WORTH (vs $LAST_DATE)"
        
        # Try to calculate percentage
        LAST_NUM=$(echo "$LAST_NET_WORTH" | tr -d '[:space:]:$' | grep -oE '^[0-9]+' || echo "0")
        if [ "$LAST_NUM" != "0" ] && [ -n "$LAST_NUM" ]; then
            CHANGE_PERCENT="N/A (manual calc needed)"
        else
            CHANGE_PERCENT="N/A"
        fi
    else
        CHANGE="First entry"
        CHANGE_PERCENT="N/A"
    fi
else
    CHANGE="First entry"
    CHANGE_PERCENT="N/A"
fi

# Step 4: Generate note from template
NOTE_NAME="net-worth-${CURRENT_MONTH}.md"
NOTE_PATH="$NETWORTH_DIR/$NOTE_NAME"

# Replace placeholders
sed -e "s/{{DATE}}/$CURRENT_DATE/g" \
    -e "s/{{MONTH}}/$CURRENT_MONTH/g" \
    -e "s/{{YEAR}}/$CURRENT_YEAR/g" \
    -e "s/{{MONTH_NAME}}/$MONTH_NAME/g" \
    -e "s/{{NET_WORTH}}/$NET_WORTH/g" \
    -e "s/{{CHANGE}}/$CHANGE/g" \
    -e "s/{{CHANGE_PERCENT}}/$CHANGE_PERCENT/g" \
    -e "s/{{SCREENSHOT_NAME}}/$SCREENSHOT_NAME/g" \
    "$TEMPLATE" > "$NOTE_PATH"

log "Note created: $NOTE_PATH"

# Step 5: Update index (if exists)
INDEX_FILE="$NETWORTH_DIR/README.md"
if [ -f "$INDEX_FILE" ]; then
    # Append to index table
    echo "| $CURRENT_MONTH | $NET_WORTH | $CHANGE |" >> "$INDEX_FILE.tmp" 2>/dev/null || true
fi

echo ""
echo "✅ Net worth captured!"
echo "📝 Note: $NOTE_PATH"
echo "📸 Screenshot: $SCREENSHOT_PATH"
echo "💰 Net Worth: $NET_WORTH"

log "Net worth capture complete: $NET_WORTH"
