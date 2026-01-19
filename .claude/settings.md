# Claude Code Settings Documentation

This document explains the Claude Code configuration in `.claude/settings.json` for the Missoula game project.

## Quick Reference

| Setting | Value | Purpose |
|---------|-------|---------|
| `defaultMode` | `bypassPermissions` | Auto-allow most operations |
| Destructive commands | `ask` | Require confirmation |
| Web fetching | `allow` | Always permitted |

---

## Permission Settings

### Default Mode: `bypassPermissions`

```json
"defaultMode": "bypassPermissions"
```

This setting allows Claude to execute most tools without asking for permission each time. It's appropriate for development workflows where you trust Claude's judgment on file operations.

**Alternative modes:**
- `askPermissions` - Prompts for every tool use (very verbose)
- `denyPermissions` - Blocks operations by default (restrictive)

### Allow List

```json
"allow": [
  "WebFetch(domain:*)",
  "Fetch(domain:*)"
]
```

These operations are always allowed without prompting:
- **WebFetch/Fetch**: Allows Claude to fetch documentation, examples, and external resources

### Ask List (Requires Confirmation)

```json
"ask": [
  "Bash(git push:*)",
  "Bash(git push)",
  "Bash(gh pr merge:*)",
  "Bash(git reset --hard:*)",
  "Bash(git clean -fd:*)",
  "Bash(git revert:*)",
  "Bash(rm -rf:*)",
  "Bash(rm -r:*)",
  "Bash(sudo:*)"
]
```

These commands require explicit user approval:

| Command | Reason |
|---------|--------|
| `git push` | Sends code to remote (visible to team) |
| `gh pr merge` | Merges PR (irreversible) |
| `git reset --hard` | Discards uncommitted changes |
| `git clean -fd` | Deletes untracked files |
| `git revert` | Creates revert commits |
| `rm -rf / rm -r` | Recursive file deletion |
| `sudo` | Elevated privileges |

### Deny List

```json
"deny": []
```

No operations are explicitly blocked. Add patterns here to completely prevent certain commands.

---

## Hooks

Hooks automate tasks in response to Claude Code events. They execute shell scripts and can modify behavior.

### Hook Types

| Hook | Trigger | Use Cases |
|------|---------|-----------|
| `PreToolUse` | Before tool execution | Validation, blocking unsafe operations |
| `PostToolUse` | After tool execution | Auto-formatting, running tests |
| `UserPromptSubmit` | When user sends prompt | Skill suggestions, context injection |
| `Stop` | When agent completes | Cleanup, notifications |

### Hook Configuration Format

```json
"hooks": {
  "PreToolUse": [
    {
      "name": "descriptive-name",
      "matcher": "Edit|Write",
      "timeout": 5000,
      "command": ".claude/hooks/your-hook.sh"
    }
  ]
}
```

| Field | Description |
|-------|-------------|
| `name` | Human-readable identifier |
| `matcher` | Tool name(s) to trigger on (pipe-separated) |
| `timeout` | Maximum execution time in ms |
| `command` | Script path (relative to project root) |

### Environment Variables

Hooks receive context via environment variables:

| Variable | Available In | Description |
|----------|--------------|-------------|
| `CLAUDE_TOOL_NAME` | All hooks | Name of the tool being used |
| `CLAUDE_TOOL_INPUT_FILE_PATH` | Edit, Write, Read | File being operated on |
| `CLAUDE_TOOL_INPUT_COMMAND` | Bash | Command being executed |

### Hook Response Format

Hooks communicate back to Claude via JSON on stdout:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Explanation shown to user"
  }
}
```

**For PreToolUse:**
- `permissionDecision`: `"allow"` or `"deny"`
- `permissionDecisionReason`: Message explaining the decision

**For PostToolUse/UserPromptSubmit:**
- `feedback`: Non-blocking message shown to user

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success (allow or feedback provided) |
| 1 | Non-blocking error (show warning) |
| 2 | Blocking error (PreToolUse only - deny operation) |

---

## Current Hooks

### `conventional-commits.py` (PreToolUse)

**Purpose**: Enforces Conventional Commits format for git commit messages.

**Triggers**: `Bash` commands containing `git commit`

**Behavior**:
- Parses commit message from `-m` flag
- Validates against pattern: `type(scope)?: description`
- Blocks non-compliant commits with helpful guidance

**Valid types**: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `ci`, `build`, `revert`

### `branch-protection.sh` (PreToolUse) - Proposed

**Purpose**: Prevents file edits on master/main branch.

**Triggers**: `Edit`, `Write` tools

**Behavior**:
- Checks current git branch
- Blocks edits if on `master` or `main`
- Suggests creating feature branch

### `auto-format.sh` (PostToolUse) - Proposed

**Purpose**: Auto-formats code after edits.

**Triggers**: `Edit`, `Write` tools

**Behavior**:
- Detects file type from extension
- Runs appropriate formatter (clang-format for C++, stylua for Lua)
- Provides feedback message

### `skill-suggestion.py` (UserPromptSubmit) - Proposed

**Purpose**: Suggests relevant skills based on prompt content.

**Triggers**: All user prompts

**Behavior**:
- Analyzes prompt for keywords and patterns
- Suggests up to 2 relevant skills
- Non-blocking feedback

---

## Agents

Agents are specialized Claude instances with focused capabilities.

| Agent | File | Purpose |
|-------|------|---------|
| `code-reviewer` | `agents/code-reviewer.md` | Code review checklist |
| `frontend-developer` | `agents/frontend-developer.md` | React/UI development |

---

## Commands

Custom slash commands for common workflows.

| Command | Purpose |
|---------|---------|
| `/update-cookbook` | Sync Lua API cookbook with codebase |
| `/update-devlog` | Add devlog entries from commits |
| `/spec` | Create feature specification |
| `/interview` | Flesh out plan through questioning |
| `/generate-tests` | Generate test suite |
| `/setup-ralph` | Configure Ralph autonomous mode |

---

## Troubleshooting

### Hook Not Running
1. Check file is executable: `chmod +x .claude/hooks/your-hook.sh`
2. Verify path in settings.json is correct
3. Check timeout isn't too short

### Hook Blocking Unexpectedly
1. Test hook manually: `echo '{"tool_name": "Edit"}' | ./your-hook.sh`
2. Check exit code: should be 0 for allow, 2 for block
3. Verify JSON output is valid

### Permission Prompt for Allowed Command
1. Check pattern matches exactly (case-sensitive)
2. Use wildcards (*) for variable parts
3. Restart Claude Code after settings changes

---

## See Also

- [CLAUDE.md](../CLAUDE.md) - Main project documentation
- [Claude Code Docs](https://docs.anthropic.com/claude/docs/claude-code) - Official documentation
