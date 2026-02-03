"""Tests for pack_test_artifacts.py."""

from __future__ import annotations

import json
import zipfile
from pathlib import Path

from pack_test_artifacts import (
    LOG_PREFIX,
    build_index,
    collect_artifacts,
    create_zip,
    safe_filename,
)


def write_file(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


def test_log_prefix_stable() -> None:
    assert LOG_PREFIX == "[ARTIFACT]"


def test_zip_order_is_deterministic(tmp_path: Path) -> None:
    output_dir = tmp_path / "test_output"
    write_file(output_dir / "status.json", "{}")
    write_file(output_dir / "results.json", "{}")
    write_file(output_dir / "report.md", "report")
    write_file(output_dir / "run_state.json", "{}")
    write_file(output_dir / "junit.xml", "<xml />")

    files = collect_artifacts(output_dir)
    zip_path = tmp_path / "test_output" / "test_artifacts.zip"
    create_zip(output_dir, zip_path, files)

    with zipfile.ZipFile(zip_path) as zf:
        names = zf.namelist()

    assert names == sorted(names)


def test_artifacts_index_contains_links(tmp_path: Path) -> None:
    output_dir = tmp_path / "test_output"
    write_file(
        output_dir / "status.json",
        json.dumps({"failed": 1, "passed_count": 0, "skipped": 0, "total": 1}),
    )
    write_file(
        output_dir / "run_state.json",
        json.dumps({"run_id": "run123", "started_at": "2026-02-03T00:00:00Z"}),
    )
    failed_test = {
        "test_id": "ui.click.missing_marker",
        "status": "fail",
        "error": {"message": "Expected click event"},
        "artifacts": [
            "test_output/screenshots/ui.click.missing_marker.png",
        ],
    }
    write_file(output_dir / "results.json", json.dumps({"tests": [failed_test]}))
    (output_dir / "screenshots").mkdir(parents=True, exist_ok=True)
    write_file(output_dir / "screenshots" / "ui.click.missing_marker.png", "png")
    (output_dir / "artifacts" / safe_filename(failed_test["test_id"])).mkdir(parents=True, exist_ok=True)

    index_path = build_index(output_dir)
    content = index_path.read_text()

    assert "ui.click.missing_marker" in content
    assert "screenshots/ui.click.missing_marker.png" in content
    assert "artifacts/" in content


def test_collect_handles_missing_dirs(tmp_path: Path) -> None:
    output_dir = tmp_path / "test_output"
    write_file(output_dir / "status.json", "{}")
    files = collect_artifacts(output_dir)
    assert (output_dir / "status.json") in files
