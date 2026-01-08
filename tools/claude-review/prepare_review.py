#!/usr/bin/env python3
"""Prepare pending changes for review with session isolation for concurrent safety."""

import argparse
import fcntl
import json
import os
import sys
import tempfile
import uuid
from datetime import datetime
from pathlib import Path

DEFAULT_REVIEW_DIR = Path.home() / ".claude-review"
SESSIONS_DIR = DEFAULT_REVIEW_DIR / "sessions"


def get_file_type(file_path: str) -> str:
    suffix = Path(file_path).suffix.lstrip(".")
    return suffix if suffix else "txt"


def atomic_write_json(path: Path, data: dict) -> None:
    """Write JSON atomically using temp file + rename pattern.

    This prevents partial writes if the process crashes mid-write.
    On Unix/Mac, rename() is atomic within the same filesystem.
    """
    # Write to temp file in same directory (ensures same filesystem)
    fd, temp_path = tempfile.mkstemp(
        dir=path.parent,
        prefix=f".{path.name}.",
        suffix=".tmp"
    )
    try:
        with os.fdopen(fd, 'w') as f:
            json.dump(data, f, indent=2)
        # Atomic rename
        os.rename(temp_path, path)
    except:
        # Clean up temp file on failure
        if os.path.exists(temp_path):
            os.unlink(temp_path)
        raise


def create_session() -> str:
    """Create a new unique session ID."""
    # Use timestamp prefix for sorting + UUID suffix for uniqueness
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    unique_id = uuid.uuid4().hex[:8]
    return f"{timestamp}-{unique_id}"


def get_session_dir(session_id: str) -> Path:
    """Get the directory for a specific session."""
    return SESSIONS_DIR / session_id


def acquire_session_lock(session_dir: Path) -> int:
    """Acquire an exclusive lock on the session directory.

    Returns the file descriptor for the lock file (caller must keep it open).
    """
    lock_file = session_dir / ".lock"
    fd = os.open(str(lock_file), os.O_RDWR | os.O_CREAT)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        return fd
    except BlockingIOError:
        os.close(fd)
        raise RuntimeError(f"Session {session_dir.name} is locked by another process")


def main():
    parser = argparse.ArgumentParser(description="Prepare changes for review")
    parser.add_argument("file_path", help="Path to the file being changed")
    parser.add_argument("--original", help="File containing original content")
    parser.add_argument("--proposed", help="File containing proposed content")
    parser.add_argument("--original-text", help="Original content as string")
    parser.add_argument("--proposed-text", help="Proposed content as string")
    parser.add_argument("--diff", help="Diff file (optional)")
    parser.add_argument("--output-dir", help="Output directory (for testing, bypasses sessions)")
    parser.add_argument("--session", help="Use existing session ID instead of creating new one")
    args = parser.parse_args()

    # Determine output directory
    if args.output_dir:
        # Testing mode - bypass session system
        output_dir = Path(args.output_dir)
        session_id = None
    else:
        # Normal mode - use session isolation
        session_id = args.session or create_session()
        output_dir = get_session_dir(session_id)

    output_dir.mkdir(parents=True, exist_ok=True)

    # Acquire lock if using sessions
    lock_fd = None
    if session_id:
        try:
            lock_fd = acquire_session_lock(output_dir)
        except RuntimeError as e:
            print(f"[prepare] Error: {e}", file=sys.stderr)
            sys.exit(1)

    try:
        original = ""
        proposed = ""

        if args.original:
            original = Path(args.original).read_text()
        elif args.original_text:
            original = args.original_text

        if args.proposed:
            proposed = Path(args.proposed).read_text()
        elif args.proposed_text:
            proposed = args.proposed_text

        meta = {
            "file_path": args.file_path,
            "file_type": get_file_type(args.file_path),
            "original_content": original,
            "proposed_content": proposed,
            "timestamp": datetime.now().isoformat(),
            "session_id": session_id,
        }

        # Atomic write to prevent partial file corruption
        meta_path = output_dir / "pending_meta.json"
        atomic_write_json(meta_path, meta)

        if args.diff:
            diff_path = output_dir / "pending.diff"
            # For diff, also use atomic write
            diff_content = Path(args.diff).read_text()
            fd, temp_path = tempfile.mkstemp(dir=output_dir, prefix=".diff.", suffix=".tmp")
            try:
                with os.fdopen(fd, 'w') as f:
                    f.write(diff_content)
                os.rename(temp_path, diff_path)
            except:
                if os.path.exists(temp_path):
                    os.unlink(temp_path)
                raise

        print(f"[prepare] Review data written to {output_dir}")
        if session_id:
            print(f"[prepare] Session ID: {session_id}")
            print(f"[prepare] Run: python3 {DEFAULT_REVIEW_DIR.parent}/tools/claude-review/server.py --session {session_id}")
        else:
            print(f"[prepare] Run: python3 server.py --test-dir {output_dir}")

    finally:
        # Release lock
        if lock_fd is not None:
            fcntl.flock(lock_fd, fcntl.LOCK_UN)
            os.close(lock_fd)


if __name__ == "__main__":
    main()
