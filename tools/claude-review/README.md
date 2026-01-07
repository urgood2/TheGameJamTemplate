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

```bash
# Prepare review data
python3 ~/.claude-review/prepare_review.py <file_path> \
    --original <original_file> \
    --proposed <proposed_file>

# Start review server
python3 ~/.claude-review/server.py

# Or with options
python3 ~/.claude-review/server.py --port 4000 --no-browser
```

## CLI Options

**server.py:**
- `--port PORT` - Server port (default: 3456)
- `--no-browser` - Don't auto-open browser
- `--no-shutdown` - Don't shutdown after feedback submission

**prepare_review.py:**
- `--original FILE` - File with original content
- `--proposed FILE` - File with proposed content
- `--original-text TEXT` - Original content as string
- `--proposed-text TEXT` - Proposed content as string
- `--diff FILE` - Optional diff file
- `--output-dir DIR` - Custom output directory

## Feedback Format

After submitting, feedback is saved to `~/.claude-review/feedback.json`:

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
├── server.py           # Review server
├── prepare_review.py   # Prepare review data
├── pending_meta.json   # Current review data
├── pending.diff        # Optional diff file
├── feedback.json       # Latest feedback
└── history/            # Archived reviews
```

## Running Tests

```bash
python3 ~/.claude-review/test_server.py
```
