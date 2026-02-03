#!/usr/bin/env python3
"""Pack test_output artifacts for CI triage."""
from __future__ import annotations

import argparse
import json
import os
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any

LOG_PREFIX = "[ARTIFACT]"


def log(message: str) -> None:
    print(f"{LOG_PREFIX} {message}")


def load_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError:
        return {}


@dataclass
class TestSummary:
    passed: int = 0
    failed: int = 0
    skipped: int = 0
    total: int = 0


def summarize_status(status: dict[str, Any]) -> TestSummary:
    summary = TestSummary()
    if not status:
        return summary
    summary.passed = int(status.get("passed_count") or status.get("passed") or 0)
    summary.failed = int(status.get("failed") or 0)
    summary.skipped = int(status.get("skipped") or 0)
    summary.total = int(status.get("total") or (summary.passed + summary.failed + summary.skipped))
    return summary


def should_pack(status: dict[str, Any], force: bool) -> bool:
    if force:
        return True
    if not status:
        return False
    if status.get("passed") is True:
        return False
    if status.get("failed", 0) > 0:
        return True
    return False


def collect_artifacts(output_dir: Path) -> list[Path]:
    candidates = [
        output_dir / "status.json",
        output_dir / "results.json",
        output_dir / "report.md",
        output_dir / "run_state.json",
        output_dir / "junit.xml",
        output_dir / "test_log.txt",
        output_dir / "artifacts_index.md",
    ]
    files: list[Path] = [path for path in candidates if path.exists()]

    screenshots = output_dir / "screenshots"
    artifacts = output_dir / "artifacts"

    if screenshots.exists():
        files.extend(sorted([p for p in screenshots.rglob("*") if p.is_file()]))
    if artifacts.exists():
        files.extend(sorted([p for p in artifacts.rglob("*") if p.is_file()]))

    return sorted(set(files), key=lambda p: p.as_posix())


def build_index(output_dir: Path) -> Path:
    status = load_json(output_dir / "status.json")
    results = load_json(output_dir / "results.json")
    run_state = load_json(output_dir / "run_state.json")

    summary = summarize_status(status)
    run_id = run_state.get("run_id", "unknown")
    generated_at = run_state.get("completed_at") or run_state.get("started_at") or "unknown"

    failed_tests = []
    for entry in results.get("tests", []):
        status_value = str(entry.get("status", "")).lower()
        if status_value == "fail":
            failed_tests.append(entry)

    lines = [
        "# Test Artifacts Index",
        f"Generated: {generated_at}",
        f"Run ID: {run_id}",
        "",
        "## Summary",
        f"- Total: {summary.total}, Passed: {summary.passed}, Failed: {summary.failed}, Skipped: {summary.skipped}",
        "",
        "## Failed Tests",
        "| Test ID | Error | Screenshot | Artifacts |",
        "|---------|-------|------------|-----------|",
    ]

    for entry in failed_tests:
        test_id = entry.get("test_id", "unknown")
        error = entry.get("error", {})
        message = error.get("message", "Error")
        artifacts = entry.get("artifacts", []) or []
        screenshot = next((p for p in artifacts if "screenshots/" in p), "")
        screenshot = normalize_artifact_path(screenshot)
        artifact_dir = f"artifacts/{safe_filename(test_id)}/"
        screenshot_link = f"[screenshot]({screenshot})" if screenshot else "-"
        artifacts_link = f"[artifacts]({artifact_dir})" if (output_dir / artifact_dir).exists() else "-"
        lines.append(f"| {test_id} | {message} | {screenshot_link} | {artifacts_link} |")

    if not failed_tests:
        lines.append("| _none_ | - | - | - |")

    lines.extend(
        [
            "",
            "## Artifact Locations",
            "- Status: status.json",
            "- Full Results: results.json",
            "- Human Report: report.md",
            "- JUnit: junit.xml",
        ]
    )

    index_path = output_dir / "artifacts_index.md"
    index_path.write_text("\n".join(lines) + "\n")
    return index_path


def safe_filename(name: str) -> str:
    return "".join(ch if ch.isalnum() or ch in ("-", "_") else "_" for ch in name)


def normalize_artifact_path(path: str) -> str:
    if path.startswith("test_output/"):
        return path[len("test_output/") :]
    return path


def create_zip(output_dir: Path, zip_path: Path, files: list[Path]) -> int:
    zip_path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for file_path in files:
            arcname = file_path.relative_to(output_dir.parent)
            zf.write(file_path, arcname.as_posix())
    return zip_path.stat().st_size


def main() -> int:
    parser = argparse.ArgumentParser(description="Bundle test_output artifacts for CI.")
    parser.add_argument("--force", action="store_true", help="Create bundle even if tests passed")
    parser.add_argument("--output", default="test_output/test_artifacts.zip", help="Zip output path")
    args = parser.parse_args()

    output_dir = Path("test_output")
    zip_path = Path(args.output)

    log("=== Test Artifact Bundling ===")
    log("Collecting artifacts from test_output/...")

    status = load_json(output_dir / "status.json")
    if not should_pack(status, args.force):
        log("No failed tests detected. Skipping bundle.")
        return 0

    index_path = build_index(output_dir)

    log("Creating artifacts_index.md...")
    screenshots_root = output_dir / "screenshots"
    artifacts_root = output_dir / "artifacts"
    screenshots_count = len(list(screenshots_root.glob("*.png"))) if screenshots_root.exists() else 0
    diff_images_count = len(list(artifacts_root.rglob("*.png"))) if artifacts_root.exists() else 0
    log(f"  Screenshots: {screenshots_count}")
    log(f"  Diff images: {diff_images_count}")
    log("  Log files: 1" if (output_dir / "test_log.txt").exists() else "  Log files: 0")

    files = collect_artifacts(output_dir)
    log("Bundling for CI upload...")
    artifact_dirs = len([p for p in artifacts_root.iterdir() if p.is_dir()]) if artifacts_root.exists() else 0
    log(f"  test_output/artifacts/ ({artifact_dirs} dirs)")
    log(f"  test_output/screenshots/ ({screenshots_count} files)")
    for path in files:
        log(f"  {path.relative_to(output_dir.parent)}")

    size = create_zip(output_dir, zip_path, files)
    log(f"Creating {zip_path}...")
    log(f"  Size: {size} bytes")
    log(f"Done. Upload {zip_path} to CI.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
