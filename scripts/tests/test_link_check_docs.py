"""Tests for link_check_docs.py."""

from __future__ import annotations

import json
from pathlib import Path

from link_check_docs import LOG_PREFIX, run_checks


def write_file(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


def test_log_prefix_stable() -> None:
    assert LOG_PREFIX == "[LINKS]"


def test_duplicate_doc_id_detected(tmp_path: Path) -> None:
    root = tmp_path
    write_file(root / "planning" / "patterns" / "a.md", "doc_id: pattern:core.dup\n")
    write_file(root / "planning" / "components" / "b.md", "doc_id: pattern:core.dup\n")
    errors, _ = run_checks(root)
    assert any(err.startswith("Duplicate doc_id") for err in errors)


def test_missing_quirks_anchor_detected(tmp_path: Path) -> None:
    root = tmp_path
    write_file(root / "docs" / "quirks.md", "# Known Quirks\n")
    write_file(
        root / "planning" / "patterns" / "a.md",
        "quirks_anchor: missing-anchor\n",
    )
    errors, _ = run_checks(root)
    assert any(err.startswith("Missing anchor") for err in errors)


def test_test_ref_validated_against_manifest(tmp_path: Path) -> None:
    root = tmp_path
    manifest = {"schema_version": "1.0", "tests": [{"test_id": "core.example"}]}
    write_file(root / "test_output" / "test_manifest.json", json.dumps(manifest))
    write_file(
        root / "planning" / "patterns" / "a.md",
        "**Verified:** Yes | Test: `test_core.lua::core.example`\n",
    )
    errors, _ = run_checks(root)
    assert not any(err.startswith("Test not found") for err in errors)


def test_broken_markdown_link_detected(tmp_path: Path) -> None:
    root = tmp_path
    write_file(
        root / "planning" / "patterns" / "a.md",
        "[Missing](docs/missing.md)\n",
    )
    errors, _ = run_checks(root)
    assert any(err.startswith("Broken link") for err in errors)
