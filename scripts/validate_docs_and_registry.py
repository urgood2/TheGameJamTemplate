#!/usr/bin/env python3
"""Validate docs/registry consistency to prevent drift.

Checks:
1) Duplicate doc_id declarations in docs
2) Verified doc entries have registry mappings
3) Registry doc_ids exist in docs
4) Registry test_ids appear in test_manifest.json
5) Quirks anchors referenced in registry/candidates exist in docs/quirks.md

Logging prefix: [VALIDATE]
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover - handled in main error path
    yaml = None

LOG_PREFIX = "[VALIDATE]"

EXIT_SUCCESS = 0
EXIT_FAILED = 1
EXIT_ERROR = 2

DOC_ID_RE = re.compile(r"(?:pattern|binding|component):[A-Za-z0-9._-]+")
DOC_ID_LINE_RE = re.compile(r"\bdoc_ids?\b", re.IGNORECASE)


@dataclass
class DocIdOccurrence:
    doc_id: str
    file_path: Path
    line_number: int


@dataclass
class RegistryEntry:
    doc_id: str
    line_number: int
    test_id: str | None = None
    quirks_anchor: str | None = None


@dataclass
class ValidationIssue:
    check: str
    message: str
    details: list[str]


def log(message: str, verbose: bool = True, stderr: bool = False) -> None:
    if not verbose:
        return
    stream = sys.stderr if stderr else sys.stdout
    stream.write(f"{LOG_PREFIX} {message}\n")


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


def is_valid_doc_id(doc_id: str) -> bool:
    if "(or" in doc_id or "<" in doc_id or ">" in doc_id:
        return False
    return bool(DOC_ID_RE.match(doc_id))


def extract_doc_ids_from_line(line: str) -> list[str]:
    if not DOC_ID_LINE_RE.search(line):
        return []
    return [doc_id for doc_id in DOC_ID_RE.findall(line) if is_valid_doc_id(doc_id)]


def parse_docs(root: Path) -> tuple[dict[str, list[DocIdOccurrence]], set[str], int]:
    doc_files: list[Path] = []
    doc_files.extend((root / "planning" / "bindings").glob("*.md"))
    doc_files.extend((root / "planning" / "components").glob("*.md"))
    doc_files.extend((root / "planning" / "patterns").glob("*.md"))

    quirks = root / "docs" / "quirks.md"
    if quirks.exists():
        doc_files.append(quirks)

    occurrences: dict[str, list[DocIdOccurrence]] = {}
    verified_doc_ids: set[str] = set()

    for file_path in doc_files:
        lines = file_path.read_text().splitlines()
        in_code_fence = False
        current_doc_ids: list[str] = []

        for idx, raw_line in enumerate(lines, start=1):
            line = raw_line.strip()

            if line.startswith("```"):
                in_code_fence = not in_code_fence
                continue

            if in_code_fence:
                continue

            doc_ids = extract_doc_ids_from_line(line)
            if doc_ids:
                current_doc_ids = doc_ids
                for doc_id in doc_ids:
                    occurrences.setdefault(doc_id, []).append(
                        DocIdOccurrence(doc_id=doc_id, file_path=file_path, line_number=idx)
                    )
                continue

            lower = line.lower()
            status = None
            if "unverified" in lower:
                status = "unverified"
            elif "verified" in lower:
                status = "verified"

            if status == "verified" and current_doc_ids:
                for doc_id in current_doc_ids:
                    verified_doc_ids.add(doc_id)

    return occurrences, verified_doc_ids, len(doc_files)


def parse_registry(registry_path: Path) -> dict[str, RegistryEntry]:
    entries: dict[str, RegistryEntry] = {}
    if not registry_path.exists():
        return entries

    current_id = None
    current_line = None
    current_test_id = None
    current_anchor = None

    for idx, raw_line in enumerate(registry_path.read_text().splitlines(), start=1):
        line = raw_line.strip()
        if line.startswith('["') and line.endswith("{"):
            current_id = line.split('"', 2)[1]
            current_line = idx
            current_test_id = None
            current_anchor = None
            continue
        if current_id and line.startswith("}"):
            entries[current_id] = RegistryEntry(
                doc_id=current_id,
                line_number=current_line or idx,
                test_id=current_test_id,
                quirks_anchor=current_anchor,
            )
            current_id = None
            current_line = None
            current_test_id = None
            current_anchor = None
            continue
        if not current_id:
            continue

        if line.startswith("test_id"):
            match = re.search(r'test_id\s*=\s*"([^"]*)"', line)
            if match:
                current_test_id = match.group(1) or None
        if line.startswith("quirks_anchor"):
            match = re.search(r'quirks_anchor\s*=\s*"([^"]*)"', line)
            if match:
                current_anchor = match.group(1) or None

    return entries


def load_manifest(manifest_path: Path) -> set[str]:
    if not manifest_path.exists():
        return set()
    payload = json.loads(manifest_path.read_text())
    tests = payload.get("tests", [])
    return {entry.get("test_id") for entry in tests if entry.get("test_id")}


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
        if stripped.startswith("#"):
            heading = stripped.lstrip("#").strip()
            if heading:
                anchors.add(slugify_heading(heading))
    return anchors


def load_candidate_anchors(candidates_path: Path) -> set[str]:
    anchors: set[str] = set()
    if not candidates_path.exists() or yaml is None:
        return anchors
    data = yaml.safe_load(candidates_path.read_text())
    if not isinstance(data, dict):
        return anchors
    for rule in data.get("rules", []) or []:
        anchor = rule.get("quirks_anchor")
        if anchor:
            anchors.add(anchor)
    return anchors


def run_validation(root: Path, checks: set[str]) -> tuple[list[ValidationIssue], dict[str, int]]:
    issues: list[ValidationIssue] = []
    counts = {
        "checked": 0,
        "passed": 0,
        "failed": 0,
    }

    registry_path = root / "assets" / "scripts" / "test" / "test_registry.lua"
    manifest_path = root / "test_output" / "test_manifest.json"
    quirks_path = root / "docs" / "quirks.md"
    candidates_path = root / "planning" / "cm_rules_candidates.yaml"

    occurrences, verified_doc_ids, file_count = parse_docs(root)
    registry_entries = parse_registry(registry_path)

    doc_id_set = set(occurrences.keys())
    registry_doc_ids = set(registry_entries.keys())

    # 1) Duplicate doc_ids
    if "duplicates" in checks:
        counts["checked"] += 1
        duplicates = {doc_id: occs for doc_id, occs in occurrences.items() if len(occs) > 1}
        if duplicates:
            counts["failed"] += 1
            for doc_id, occs in duplicates.items():
                details = [f"{occ.file_path}:{occ.line_number}" for occ in occs]
                issues.append(ValidationIssue(
                    check="duplicates",
                    message=f"Duplicate doc_id {doc_id}",
                    details=details,
                ))
        else:
            counts["passed"] += 1

    # 2) Verified entries mapped in registry
    if "verified" in checks:
        counts["checked"] += 1
        missing = sorted(verified_doc_ids - registry_doc_ids)
        if missing:
            counts["failed"] += 1
            for doc_id in missing:
                occ = occurrences.get(doc_id, [None])[0]
                location = f"{occ.file_path}:{occ.line_number}" if occ else "unknown"
                issues.append(ValidationIssue(
                    check="verified",
                    message=f"Missing registry entry for verified doc_id {doc_id}",
                    details=[location],
                ))
        else:
            counts["passed"] += 1

    # 3) Registry entries point to docs
    if "registry" in checks:
        counts["checked"] += 1
        missing_docs = sorted(registry_doc_ids - doc_id_set)
        if missing_docs:
            counts["failed"] += 1
            for doc_id in missing_docs:
                entry = registry_entries.get(doc_id)
                location = f"{registry_path}:{entry.line_number}" if entry else str(registry_path)
                issues.append(ValidationIssue(
                    check="registry",
                    message=f"Registry doc_id missing from docs: {doc_id}",
                    details=[location],
                ))
        else:
            counts["passed"] += 1

    # 4) Registry test_ids appear in manifest
    if "manifest" in checks:
        counts["checked"] += 1
        manifest_tests = load_manifest(manifest_path)
        missing_tests = []
        for entry in registry_entries.values():
            if entry.test_id and entry.test_id not in manifest_tests:
                missing_tests.append(entry)
        if missing_tests:
            counts["failed"] += 1
            for entry in missing_tests:
                issues.append(ValidationIssue(
                    check="manifest",
                    message=f"test_id not in manifest: {entry.test_id}",
                    details=[f"{registry_path}:{entry.line_number}"],
                ))
        else:
            counts["passed"] += 1

    # 5) Quirks anchors
    if "quirks" in checks:
        counts["checked"] += 1
        anchors = load_quirks_anchors(quirks_path)
        referenced = {entry.quirks_anchor for entry in registry_entries.values() if entry.quirks_anchor}
        referenced |= load_candidate_anchors(candidates_path)
        missing_anchors = sorted(anchor for anchor in referenced if anchor not in anchors)
        if missing_anchors:
            counts["failed"] += 1
            for anchor in missing_anchors:
                issues.append(ValidationIssue(
                    check="quirks",
                    message=f"Missing quirks anchor: {anchor}",
                    details=[str(quirks_path)],
                ))
        else:
            counts["passed"] += 1

    counts["doc_files"] = file_count
    counts["doc_ids"] = len(doc_id_set)
    counts["registry_doc_ids"] = len(registry_doc_ids)
    counts["verified_doc_ids"] = len(verified_doc_ids)

    return issues, counts


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate docs/registry consistency.")
    parser.add_argument("--strict", action="store_true", help="Fail on warnings (no-op, all failures are errors)")
    parser.add_argument("--json", action="store_true", help="Output JSON summary")
    parser.add_argument(
        "--check",
        action="append",
        default=[],
        help="Run specific check(s): duplicates, verified, registry, manifest, quirks",
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=None,
        help="Override repository root (used for testing)",
    )
    args = parser.parse_args()

    root = args.root or get_git_root() or Path.cwd()
    checks = set(args.check or [])
    if not checks:
        checks = {"duplicates", "verified", "registry", "manifest", "quirks"}

    log("=== Docs/Registry Consistency Check ===", verbose=not args.json)
    log(f"Input root: {root}", verbose=not args.json)
    log("Input files:", verbose=not args.json)
    log("  Docs: planning/{bindings,components,patterns}/*.md", verbose=not args.json)
    log("  Quirks: docs/quirks.md", verbose=not args.json)
    log("  Registry: assets/scripts/test/test_registry.lua", verbose=not args.json)
    log("  Manifest: test_output/test_manifest.json", verbose=not args.json)

    issues, counts = run_validation(root, checks)

    if not args.json:
        log("[1/5] Checking for duplicate doc_ids...", verbose=True)
        log(f"  Scanned: {counts['doc_files']} files", verbose=True)
        log(f"  doc_ids found: {counts['doc_ids']}", verbose=True)
        if any(issue.check == "duplicates" for issue in issues):
            for issue in issues:
                if issue.check != "duplicates":
                    continue
                log(f"  FAIL: {issue.message}", verbose=True)
                for detail in issue.details:
                    log(f"    - {detail}", verbose=True)
        else:
            log("  PASS: No duplicates", verbose=True)

        log("[2/5] Checking Verified entries have registry mapping...", verbose=True)
        if any(issue.check == "verified" for issue in issues):
            for issue in issues:
                if issue.check != "verified":
                    continue
                log(f"  FAIL: {issue.message}", verbose=True)
                for detail in issue.details:
                    log(f"    - {detail}", verbose=True)
        else:
            log(f"  PASS: All {counts['verified_doc_ids']} Verified entries mapped", verbose=True)

        log("[3/5] Checking registry entries point to valid docs...", verbose=True)
        if any(issue.check == "registry" for issue in issues):
            for issue in issues:
                if issue.check != "registry":
                    continue
                log(f"  FAIL: {issue.message}", verbose=True)
                for detail in issue.details:
                    log(f"    - {detail}", verbose=True)
        else:
            log(f"  PASS: All {counts['registry_doc_ids']} registry entries valid", verbose=True)

        log("[4/5] Checking test_ids registered by harness...", verbose=True)
        if any(issue.check == "manifest" for issue in issues):
            for issue in issues:
                if issue.check != "manifest":
                    continue
                log(f"  FAIL: {issue.message}", verbose=True)
                for detail in issue.details:
                    log(f"    - {detail}", verbose=True)
        else:
            log("  PASS: All registry test_ids found in manifest", verbose=True)

        log("[5/5] Checking quirks anchors...", verbose=True)
        if any(issue.check == "quirks" for issue in issues):
            for issue in issues:
                if issue.check != "quirks":
                    continue
                log(f"  FAIL: {issue.message}", verbose=True)
                for detail in issue.details:
                    log(f"    - {detail}", verbose=True)
        else:
            log("  PASS: All anchors exist in docs/quirks.md", verbose=True)

        log("=== SUMMARY ===", verbose=True)
        log(f"Checks: {counts['checked']}", verbose=True)
        log(f"Passed: {counts['passed']}", verbose=True)
        log(f"Failed: {counts['failed']}", verbose=True)
        status = "VALID" if counts["failed"] == 0 else "INVALID"
        log(f"Status: {status}", verbose=True)

    if args.json:
        payload = {
            "checks": sorted(checks),
            "counts": counts,
            "issues": [
                {
                    "check": issue.check,
                    "message": issue.message,
                    "details": issue.details,
                }
                for issue in issues
            ],
        }
        print(json.dumps(payload, indent=2))

    return EXIT_SUCCESS if counts["failed"] == 0 else EXIT_FAILED


if __name__ == "__main__":
    raise SystemExit(main())
