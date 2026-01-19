#!/bin/bash
# Branch Protection Hook for Claude Code
# Prevents editing files when on master or main branch
#
# This hook is triggered on PreToolUse for Edit and Write tools
# It checks the current git branch and blocks the action if on a protected branch

# Get current branch name
current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

# Check if we're on a protected branch
if [[ "$current_branch" == "master" || "$current_branch" == "main" ]]; then
  # Output JSON response to block the action
  cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Cannot edit files on protected branch (master/main).\n\nCreate a feature branch first:\n  git checkout -b urgood2/your-feature-name\n\nOr switch to an existing feature branch:\n  git checkout urgood2/some-existing-branch"
  }
}
EOF
  exit 0
fi

# Allow the action if not on protected branch
exit 0
