#!/bin/zsh
# Net Worth Monthly Reminder Script
# Sends notification to run the capture script

set -e

# Check for terminal-notifier
if command -v terminal-notifier &> /dev/null; then
    terminal-notifier \
        -title "💰 Net Worth Capture" \
        -message "Time for your monthly net worth snapshot!" \
        -subtitle "Click to run capture script" \
        -open "file:///Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/scripts/capture-net-worth.sh" \
        -sound default
else
    # Fallback to osascript notification
    osascript -e 'display notification "Time for your monthly net worth snapshot!" with title "💰 Net Worth Capture"'
fi

echo "Reminder sent at $(date '+%Y-%m-%d %H:%M:%S')"
