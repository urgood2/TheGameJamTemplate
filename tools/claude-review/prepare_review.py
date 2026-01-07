#!/usr/bin/env python3
"""Prepare pending changes for review."""

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path

DEFAULT_REVIEW_DIR = Path.home() / ".claude-review"


def get_file_type(file_path: str) -> str:
    suffix = Path(file_path).suffix.lstrip(".")
    return suffix if suffix else "txt"


def main():
    parser = argparse.ArgumentParser(description="Prepare changes for review")
    parser.add_argument("file_path", help="Path to the file being changed")
    parser.add_argument("--original", help="File containing original content")
    parser.add_argument("--proposed", help="File containing proposed content")
    parser.add_argument("--original-text", help="Original content as string")
    parser.add_argument("--proposed-text", help="Proposed content as string")
    parser.add_argument("--diff", help="Diff file (optional)")
    parser.add_argument("--output-dir", help="Output directory (for testing)")
    args = parser.parse_args()

    output_dir = Path(args.output_dir) if args.output_dir else DEFAULT_REVIEW_DIR
    output_dir.mkdir(parents=True, exist_ok=True)

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
    }

    meta_path = output_dir / "pending_meta.json"
    meta_path.write_text(json.dumps(meta, indent=2))

    if args.diff:
        diff_path = output_dir / "pending.diff"
        diff_path.write_text(Path(args.diff).read_text())

    print(f"[prepare] Review data written to {output_dir}")
    print(f"[prepare] Run: python3 {DEFAULT_REVIEW_DIR}/server.py")


if __name__ == "__main__":
    main()
