#!/bin/bash
# Auto-Format Hook for Claude Code
# Automatically formats code after edits based on file extension
#
# This hook is triggered on PostToolUse for Edit and Write tools
# It formats the edited file using the appropriate formatter

# Get the edited file path from environment variable
FILE_PATH="${CLAUDE_TOOL_INPUT_FILE_PATH:-}"

# Exit silently if no file path
if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# Check file extension and apply appropriate formatter
case "$FILE_PATH" in
    *.cpp|*.hpp|*.c|*.h)
        # Format C/C++ files with clang-format
        if command -v clang-format &> /dev/null; then
            clang-format -i "$FILE_PATH" 2>/dev/null || true
            # Provide feedback that formatting was applied
            cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "feedback": "Auto-formatted C++ file with clang-format"
  }
}
EOF
        fi
        ;;
    *.lua)
        # Format Lua files with stylua (if available)
        if command -v stylua &> /dev/null; then
            stylua "$FILE_PATH" 2>/dev/null || true
            cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "feedback": "Auto-formatted Lua file with stylua"
  }
}
EOF
        fi
        ;;
    *.json)
        # Format JSON files with jq (if available)
        if command -v jq &> /dev/null; then
            TMP_FILE=$(mktemp)
            if jq '.' "$FILE_PATH" > "$TMP_FILE" 2>/dev/null; then
                mv "$TMP_FILE" "$FILE_PATH"
                cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "feedback": "Auto-formatted JSON file"
  }
}
EOF
            else
                rm -f "$TMP_FILE"
            fi
        fi
        ;;
    *)
        # No formatter for this file type
        ;;
esac

exit 0
