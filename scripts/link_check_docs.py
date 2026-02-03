#!/usr/bin/env python3
"""Validate documentation links and references."""
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path

LOG_PREFIX = "[LINKS]"
EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_ERROR = 2

DOC_ID_RE = re.compile(r"(?:pattern|binding|component):[A-Za-z0-9._-]+")
DOC_ID_LINE_RE = re.compile(r"\bdoc_ids?\b", re.IGNORECASE)
TEST_REF_RE = re.compile(r"Test:\s*`?([^`\s]+)`?", re.IGNORECASE)
QUIRKS_ANCHOR_RE = re.compile(r"quirks_anchor:\s*([A-Za-z0-9._-]+)", re.IGNORECASE)
QUIRKS_LINK_RE = re.compile(r"quirks\.md#([A-Za-z0-9._-]+)")
SOURCE_REF_RE = re.compile(r"(?:source_ref|Source):\s*`?([^`\s]+)`?", re.IGNORECASE)
MARKDOWN_LINK_RE = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")


@dataclass
class Occurrence:
    value: str
    file_path: Path
    line_number: int


def log(message: str, verbose: bool = True) -> None:
    if verbose:
        print(f"{LOG_PREFIX} {message}")


def get_git_root() -> Path | None:
    import subprocess

    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            check=True,
        )
        return Path(result.stdout.strip())
    except (FileNotFoundError, subprocess.CalledProcessError):
        return None


def find_markdown_files(root: Path) -> list[Path]:
    files: list[Path] = []
    files.extend((root / "planning" / "bindings").glob("*.md"))
    files.extend((root / "planning" / "components").glob("*.md"))
    files.extend((root / "planning" / "patterns").glob("*.md"))
    quirks = root / "docs" / "quirks.md"
    if quirks.exists():
        files.append(quirks)
    reference_index = root / "docs" / "reference" / "index.md"
    if reference_index.exists():
        files.append(reference_index)
    return files


def extract_doc_ids(line: str) -> list[str]:
    if not DOC_ID_LINE_RE.search(line):
        return []
    return DOC_ID_RE.findall(line)


def slugify_heading(text: str) -> str:
    text = text.strip().lower()
    text = re.sub(r"[^\w\s-]", "", text)
    text = re.sub(r"\s+", "-", text)
    text = re.sub(r"-{2,}", "-", text)
    return text


def load_quirks_anchors(quirks_path: Path) -> set[str]:
    anchors: set[str] = set()
    if not quirks_path.exists():
        return anchors
    for line in quirks_path.read_text().splitlines():
        stripped = line.strip()
        anchor_match = re.search(r'<a id="([^"]+)">', stripped)
        if anchor_match:
            anchors.add(anchor_match.group(1))
        if stripped.startswith("#"):
            heading = stripped.lstrip("#").strip()
            if heading:
                anchors.add(slugify_heading(heading))
                if re.fullmatch(r"[A-Za-z0-9._-]+", heading):
                    anchors.add(heading.lower())
    return anchors


def load_manifest_tests(manifest_path: Path) -> set[str]:
    if not manifest_path.exists():
        return set()
    try:
        payload = json.loads(manifest_path.read_text())
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON in manifest: {manifest_path}") from exc
    return {entry.get("test_id") for entry in payload.get("tests", []) if entry.get("test_id")}


def resolve_link_target(base: Path, target: str) -> Path | None:
    if target.startswith(("http://", "https://", "mailto:", "tel:")):
        return None
    if target.startswith("#"):
        return None
    path_part = target.split("#", 1)[0]
    if not path_part:
        return None
    return (base / path_part).resolve()


def run_checks(root: Path) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []

    files = find_markdown_files(root)
    log(f"=== Documentation Link Check ===")
    log(f"Scanning {len(files)} markdown files...")

    doc_id_occurrences: dict[str, list[Occurrence]] = {}
    test_refs: list[Occurrence] = []
    quirks_refs: list[Occurrence] = []
    markdown_links: list[Occurrence] = []
    source_refs: list[Occurrence] = []

    for file_path in files:
        lines = file_path.read_text().splitlines()
        in_code_fence = False
        for idx, raw_line in enumerate(lines, start=1):
            line = raw_line.strip()
            if line.startswith("```"):
                in_code_fence = not in_code_fence
                continue
            if in_code_fence:
                continue

            for doc_id in extract_doc_ids(line):
                doc_id_occurrences.setdefault(doc_id, []).append(
                    Occurrence(doc_id, file_path, idx)
                )

            test_match = TEST_REF_RE.search(line)
            if test_match:
                test_refs.append(Occurrence(test_match.group(1), file_path, idx))

            anchor_match = QUIRKS_ANCHOR_RE.search(line)
            if anchor_match:
                quirks_refs.append(Occurrence(anchor_match.group(1), file_path, idx))

            for link_anchor in QUIRKS_LINK_RE.findall(line):
                quirks_refs.append(Occurrence(link_anchor, file_path, idx))

            for target in MARKDOWN_LINK_RE.findall(line):
                markdown_links.append(Occurrence(target, file_path, idx))

            source_match = SOURCE_REF_RE.search(line)
            if source_match:
                source_refs.append(Occurrence(source_match.group(1), file_path, idx))

    # 1) doc_id uniqueness
    log("Checking doc_id uniqueness...")
    log(f"  Found: {len(doc_id_occurrences)} doc_ids")
    duplicates = {doc_id: occs for doc_id, occs in doc_id_occurrences.items() if len(occs) > 1}
    if duplicates:
        for doc_id, occs in duplicates.items():
            log(f"  FAIL: Duplicate doc_id: {doc_id}")
            errors.append(f"Duplicate doc_id: {doc_id}")
            for occ in occs:
                log(f"    - {occ.file_path}:{occ.line_number}")
                errors.append(f"  - {occ.file_path}:{occ.line_number}")
    else:
        log("  PASS: All unique")

    # 2) Test references
    log("Checking Test: references...")
    manifest_tests = load_manifest_tests(root / "test_output" / "test_manifest.json")
    log(f"  References found: {len(test_refs)}")
    for occ in test_refs:
        test_id = occ.value
        if "::" in test_id:
            test_id = test_id.split("::", 1)[1]
        if test_id not in manifest_tests:
            log(f"  FAIL: Test not found: {test_id}")
            log(f"    - Referenced in: {occ.file_path}:{occ.line_number}")
            errors.append(f"Test not found: {test_id}")
            errors.append(f"  - Referenced in: {occ.file_path}:{occ.line_number}")
    if not any(err.startswith("Test not found") for err in errors):
        log("  PASS: All exist in test_manifest")

    # 3) Quirks anchors
    log("Checking quirks anchors...")
    anchors = load_quirks_anchors(root / "docs" / "quirks.md")
    log(f"  Anchors referenced: {len(quirks_refs)}")
    for occ in quirks_refs:
        if occ.value not in anchors:
            log(f"  FAIL: Missing anchor: #{occ.value}")
            log(f"    - Referenced in: {occ.file_path}:{occ.line_number}")
            errors.append(f"Missing anchor: #{occ.value}")
            errors.append(f"  - Referenced in: {occ.file_path}:{occ.line_number}")
    if not any(err.startswith("Missing anchor") for err in errors):
        log("  PASS: All found in docs/quirks.md")

    # 4) Markdown links
    log("Checking markdown links...")
    broken_links = 0
    for occ in markdown_links:
        target_path = resolve_link_target(occ.file_path.parent, occ.value)
        if target_path is None:
            continue
        if not target_path.exists():
            broken_links += 1
            log(f"  FAIL: Broken link: {occ.value}")
            log(f"    - From: {occ.file_path}:{occ.line_number}")
            errors.append(f"Broken link: {occ.value}")
            errors.append(f"  - From: {occ.file_path}:{occ.line_number}")
    if broken_links == 0:
        log("  PASS: All resolve")

    # 5) source_ref files (warnings)
    log("Checking source_ref files (warnings only)...")
    for occ in source_refs:
        path_part = occ.value.split(":", 1)[0]
        candidate = Path(path_part)
        if not candidate.is_absolute():
            candidate = (root / path_part).resolve()
        if not candidate.exists():
            log(f"  WARNING: source_ref file not found: {path_part}")
            log(f"    - In: {occ.file_path}:{occ.line_number}")
            warnings.append(f"source_ref file not found: {path_part}")
            warnings.append(f"  - In: {occ.file_path}:{occ.line_number}")

    return errors, warnings


def main() -> int:
    parser = argparse.ArgumentParser(description="Check documentation links and references.")
    parser.add_argument("--root", type=Path, default=None, help="Override repository root")
    args = parser.parse_args()

    root = args.root or get_git_root() or Path.cwd()
    missing_inputs: list[str] = []
    if not find_markdown_files(root):
        missing_inputs.append("planning/{bindings,components,patterns}/*.md")
    manifest_path = root / "test_output" / "test_manifest.json"
    quirks_path = root / "docs" / "quirks.md"
    if not manifest_path.exists():
        missing_inputs.append(str(manifest_path))
    if not quirks_path.exists():
        missing_inputs.append(str(quirks_path))
    if missing_inputs:
        log("ERROR: Missing required input files")
        for missing in missing_inputs:
            log(f"  - {missing}")
        return EXIT_ERROR

    try:
        errors, warnings = run_checks(root)
    except (OSError, UnicodeDecodeError, ValueError) as exc:
        log(f"ERROR: {exc}")
        return EXIT_ERROR

    log("=== SUMMARY ===")
    log(f"Errors: {len([e for e in errors if not e.startswith('  -')])}")
    log(f"Warnings: {len([w for w in warnings if not w.startswith('  -')])}")

    if errors:
        log("Status: FAIL")
        return EXIT_FAILURE

    log("Status: PASS")
    return EXIT_SUCCESS


if __name__ == "__main__":
    raise SystemExit(main())
