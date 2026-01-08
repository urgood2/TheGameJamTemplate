# Claude Code Annotation Review System

A local web UI for reviewing Claude's proposed code changes with inline annotations.

## Quick Start

When Claude proposes changes you want to annotate:

1. Tell Claude: "review that"
2. Claude will prepare the review data and start the server
3. Browser opens with diff viewer
4. Select text, add comments
5. Submit feedback
6. Claude reads your annotations and adjusts

## Manual Usage

### Basic (Single Session)

```bash
# Prepare review data (creates isolated session)
python3 ~/.claude-review/prepare_review.py myfile.lua \
    --original /tmp/original.lua \
    --proposed /tmp/proposed.lua
# Output: Session ID: 20260108-103500-abc12345

# Start review server for that session
python3 ~/.claude-review/server.py --session 20260108-103500-abc12345
```

### Concurrent Sessions (Multiple Terminals)

Each invocation creates an isolated session, so you can run multiple reviews simultaneously:

```bash
# Terminal 1
python3 ~/.claude-review/prepare_review.py file1.lua --original a.lua --proposed b.lua
# Session ID: 20260108-103500-abc12345
python3 ~/.claude-review/server.py --session 20260108-103500-abc12345
# → Runs on port 3456

# Terminal 2 (at the same time)
python3 ~/.claude-review/prepare_review.py file2.lua --original c.lua --proposed d.lua
# Session ID: 20260108-103501-def67890
python3 ~/.claude-review/server.py --session 20260108-103501-def67890
# → Automatically finds port 3457
```

**Concurrency features:**
- **Session isolation** - Each review gets its own directory under `~/.claude-review/sessions/<id>/`
- **Automatic port discovery** - If port 3456 is taken, finds the next available port
- **File locking** - Prevents two servers from accessing the same session
- **Atomic writes** - Feedback files are written atomically to prevent corruption

## CLI Options

**server.py:**
- `--session ID` - Session ID to serve (uses `~/.claude-review/sessions/<id>/`)
- `--port PORT` - Preferred port (default: 3456, auto-discovers next if taken)
- `--no-browser` - Don't auto-open browser
- `--no-shutdown` - Don't shutdown after feedback submission
- `--test-dir DIR` - Override directory (bypasses session system, for testing)

**prepare_review.py:**
- `--original FILE` - File with original content
- `--proposed FILE` - File with proposed content
- `--original-text TEXT` - Original content as string
- `--proposed-text TEXT` - Proposed content as string
- `--diff FILE` - Optional diff file
- `--session ID` - Use existing session ID instead of creating new one
- `--output-dir DIR` - Custom output directory (bypasses session system, for testing)

## Feedback Format

After submitting, feedback is saved to the session directory:

```json
{
  "file": "path/to/file.lua",
  "reviewed_at": "2026-01-07T12:00:00Z",
  "status": "changes_requested",
  "comments": [
    {
      "selection": { "start": {"line": 5, "col": 0}, "end": {"line": 5, "col": 20} },
      "selected_text": "the selected code",
      "comment": "Your feedback here"
    }
  ],
  "general_comment": "Overall feedback"
}
```

## Status Options

- `approved` - Apply the changes as-is
- `changes_requested` - Claude should address comments and revise
- `rejected` - Discard the proposed changes entirely

## Directory Structure

```
~/.claude-review/
├── sessions/                    # Isolated review sessions
│   └── 20260108-103500-abc123/  # Session directory
│       ├── .lock                # Session lock file
│       ├── pending_meta.json    # Review data
│       ├── pending.diff         # Optional diff
│       ├── feedback.json        # Submitted feedback
│       └── history/             # Archived reviews
├── server.py                    # Review server (legacy location)
└── prepare_review.py            # Prepare script (legacy location)
```

## Legacy Mode

For backward compatibility, running without `--session` uses the old shared directory:

```bash
# Old behavior (not concurrent-safe)
python3 ~/.claude-review/server.py
```

## Running Tests

```bash
python3 ~/.claude-review/test_server.py
```
