#!/usr/bin/env python3
"""Sync docs Evidence blocks with test_registry.lua.

Ensures documentation Evidence blocks (Verified/Unverified status) match
the test registry, preventing drift between docs and actual test coverage.

Input:
- docs/quirks.md
- planning/bindings/*.md
- planning/components/*.md
- planning/patterns/*.md
- assets/scripts/test/test_registry.lua

Modes:
- --check: Report mismatches, exit non-zero if any
- --fix: Update docs Evidence blocks to match registry

Logging prefix: [SYNC]
"""
from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

# Exit codes
EXIT_SUCCESS = 0
EXIT_MISMATCH = 1
EXIT_ERROR = 2


@dataclass
class RegistryEntry:
    """Entry from test_registry.lua."""

    doc_id: str
    test_id: str | None = None
    test_file: str | None = None
    status: str = "unverified"
    reason: str | None = None


@dataclass
class DocEvidence:
    """Evidence block from documentation."""

    doc_id: str
    file_path: str
    line_number: int
    status: str  # "verified" or "unverified"
    test_ref: str | None = None  # e.g., "test_file::test_id"
    reason: str | None = None
    raw_text: str = ""


@dataclass
class Mismatch:
    """Mismatch between doc and registry."""

    doc_evidence: DocEvidence
    registry_entry: RegistryEntry | None
    reason: str


def log(message: str, verbose: bool = True) -> None:
    """Log a message with [SYNC] prefix."""
    if verbose:
        print(f"[SYNC] {message}")


def get_git_root() -> Path | None:
    """Get the git repository root."""
    import subprocess

    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            check=True,
        )
        return Path(result.stdout.strip())
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None


def parse_registry_lua(registry_path: Path, verbose: bool = False) -> dict[str, RegistryEntry]:
    """Parse test_registry.lua and extract entries.

    Returns dict mapping doc_id -> RegistryEntry.
    """
    log(f"Loading {registry_path}...", verbose)

    if not registry_path.exists():
        log(f"  Warning: Registry not found at {registry_path}", verbose)
        return {}

    content = registry_path.read_text()
    entries: dict[str, RegistryEntry] = {}

    # Pattern to match doc entries in the Lua table
    # Format: ["doc_id"] = { test_id = "...", status = "...", ... },
    entry_pattern = re.compile(
        r'\["([^"]+)"\]\s*=\s*\{([^}]+)\}',
        re.MULTILINE,
    )

    for match in entry_pattern.finditer(content):
        doc_id = match.group(1)
        fields_str = match.group(2)

        # Extract fields
        test_id = None
        test_file = None
        status = "unverified"
        reason = None

        # Parse test_id (might be nil or string)
        test_id_match = re.search(r'test_id\s*=\s*"([^"]*)"', fields_str)
        if test_id_match:
            test_id = test_id_match.group(1)

        test_file_match = re.search(r'test_file\s*=\s*"([^"]*)"', fields_str)
        if test_file_match:
            test_file = test_file_match.group(1)

        status_match = re.search(r'status\s*=\s*"([^"]*)"', fields_str)
        if status_match:
            status = status_match.group(1)

        reason_match = re.search(r'reason\s*=\s*"([^"]*)"', fields_str)
        if reason_match:
            reason = reason_match.group(1)

        entries[doc_id] = RegistryEntry(
            doc_id=doc_id,
            test_id=test_id,
            test_file=test_file,
            status=status,
            reason=reason,
        )

    log(f"  Entries: {len(entries)}", verbose)
    return entries


def is_valid_doc_id(doc_id: str) -> bool:
    """Check if a doc_id is valid (not a template/example).

    Valid doc_ids have format:
    - prefix:identifier (pattern:, binding:, component:)
    - sol2_* (legacy format without colon)
    """
    # Skip template/example markers
    if "(or" in doc_id or ")" in doc_id or "<" in doc_id or ">" in doc_id:
        return False

    # sol2_* format is valid without colon
    if doc_id.startswith("sol2_"):
        return True

    # Other formats must have a colon
    if ":" not in doc_id:
        return False

    # Must start with known prefix
    valid_prefixes = ["pattern:", "binding:", "component:"]
    return any(doc_id.startswith(p) for p in valid_prefixes)


def parse_doc_evidence(file_path: Path, verbose: bool = False) -> list[DocEvidence]:
    """Parse a markdown file for Evidence blocks.

    Looks for patterns like:
    - **Evidence:**
      - Verified: Test: test_file::test_id
      - Unverified: reason

    Also looks for doc_id patterns:
    - doc_id: pattern:system.feature
    - doc_ids: pattern:a, pattern:b

    Skips code fences and template sections.
    """
    if not file_path.exists():
        return []

    content = file_path.read_text()
    lines = content.splitlines()
    evidence_list: list[DocEvidence] = []

    current_doc_ids: list[str] = []
    in_code_fence = False
    in_template_section = False
    i = 0

    while i < len(lines):
        line = lines[i]

        # Track code fences
        if line.strip().startswith("```"):
            in_code_fence = not in_code_fence
            i += 1
            continue

        # Skip lines in code fences
        if in_code_fence:
            i += 1
            continue

        # Skip template section (marked by "Entry Template" heading)
        if "Entry Template" in line or "entry-template" in line:
            in_template_section = True
            i += 1
            continue

        # Exit template section at next major heading (## or ---)
        if in_template_section and (line.startswith("## ") or line.startswith("---")):
            in_template_section = False

        # Skip lines in template section
        if in_template_section:
            i += 1
            continue

        # Look for doc_id declarations
        # Format: - doc_id: pattern:system.feature
        # Format: - doc_ids: pattern:a, pattern:b
        doc_id_match = re.match(r'^-?\s*doc_ids?:\s*(.+)$', line, re.IGNORECASE)
        if doc_id_match:
            ids_str = doc_id_match.group(1).strip()
            # Split by comma if multiple
            raw_ids = [d.strip() for d in ids_str.split(',')]
            # Filter to valid doc_ids only
            current_doc_ids = [d for d in raw_ids if is_valid_doc_id(d)]
            i += 1
            continue

        # Look for Evidence blocks
        # Format: **Evidence:**
        # Format: - Verified: Test: test_file::test_id
        # Format: - Unverified: reason
        if '**Evidence:**' in line or line.strip().startswith('- Verified:') or line.strip().startswith('- Unverified:'):
            # Parse the evidence
            evidence_line = line
            evidence_line_num = i + 1

            # If this is just the header, look at next lines
            if '**Evidence:**' in line:
                i += 1
                while i < len(lines) and lines[i].strip().startswith('-'):
                    evidence_line = lines[i]
                    break
                else:
                    i += 1
                    continue

            # Parse Verified/Unverified
            verified_match = re.search(r'Verified:\s*Test:\s*(\S+)', evidence_line)
            unverified_match = re.search(r'Unverified:\s*(.+)', evidence_line)

            if verified_match:
                test_ref = verified_match.group(1).strip()
                for doc_id in current_doc_ids:
                    evidence_list.append(DocEvidence(
                        doc_id=doc_id,
                        file_path=str(file_path),
                        line_number=evidence_line_num,
                        status="verified",
                        test_ref=test_ref,
                        raw_text=evidence_line,
                    ))
            elif unverified_match:
                reason = unverified_match.group(1).strip()
                for doc_id in current_doc_ids:
                    evidence_list.append(DocEvidence(
                        doc_id=doc_id,
                        file_path=str(file_path),
                        line_number=evidence_line_num,
                        status="unverified",
                        reason=reason,
                        raw_text=evidence_line,
                    ))

        i += 1

    return evidence_list


def find_doc_files(git_root: Path) -> list[Path]:
    """Find all documentation files to scan."""
    doc_files: list[Path] = []

    # docs/quirks.md
    quirks = git_root / "docs" / "quirks.md"
    if quirks.exists():
        doc_files.append(quirks)

    # planning/bindings/*.md
    for pattern in ["planning/bindings/*.md", "planning/components/*.md", "planning/patterns/*.md"]:
        doc_files.extend(git_root.glob(pattern))

    return doc_files


def compare_evidence(
    doc_evidence: list[DocEvidence],
    registry: dict[str, RegistryEntry],
    verbose: bool = False,
) -> list[Mismatch]:
    """Compare doc evidence with registry and find mismatches."""
    mismatches: list[Mismatch] = []

    for evidence in doc_evidence:
        doc_id = evidence.doc_id

        if doc_id not in registry:
            mismatches.append(Mismatch(
                doc_evidence=evidence,
                registry_entry=None,
                reason=f"doc_id '{doc_id}' not found in registry",
            ))
            continue

        reg_entry = registry[doc_id]

        # Check status match
        if evidence.status.lower() != reg_entry.status.lower():
            mismatches.append(Mismatch(
                doc_evidence=evidence,
                registry_entry=reg_entry,
                reason=f"Status mismatch: doc says '{evidence.status}' but registry says '{reg_entry.status}'",
            ))
            continue

        # If verified, check test reference matches
        if evidence.status.lower() == "verified" and evidence.test_ref:
            expected_ref = f"{reg_entry.test_file}::{reg_entry.test_id}" if reg_entry.test_file and reg_entry.test_id else None
            if expected_ref and evidence.test_ref != expected_ref:
                mismatches.append(Mismatch(
                    doc_evidence=evidence,
                    registry_entry=reg_entry,
                    reason=f"Test ref mismatch: doc says '{evidence.test_ref}' but registry has '{expected_ref}'",
                ))

    return mismatches


def generate_evidence_text(reg_entry: RegistryEntry) -> str:
    """Generate correct Evidence text from registry entry."""
    if reg_entry.status == "verified" and reg_entry.test_file and reg_entry.test_id:
        return f"- Verified: Test: {reg_entry.test_file}::{reg_entry.test_id}"
    else:
        reason = reg_entry.reason or "No test registered"
        return f"- Unverified: {reason}"


def fix_evidence_in_file(
    file_path: Path,
    mismatches: list[Mismatch],
    registry: dict[str, RegistryEntry],
    verbose: bool = False,
) -> int:
    """Fix Evidence blocks in a file. Returns count of fixes applied."""
    if not file_path.exists():
        return 0

    content = file_path.read_text()
    lines = content.splitlines()
    fixes_applied = 0

    # Group mismatches by line number for this file
    file_mismatches = [m for m in mismatches if m.doc_evidence.file_path == str(file_path)]

    for mismatch in file_mismatches:
        evidence = mismatch.doc_evidence
        line_idx = evidence.line_number - 1

        if line_idx < 0 or line_idx >= len(lines):
            continue

        # Get registry entry (might be None if doc_id not found)
        reg_entry = registry.get(evidence.doc_id)
        if not reg_entry:
            continue

        # Generate new evidence text
        new_text = generate_evidence_text(reg_entry)

        # Find the line with the evidence and replace it
        # This is a simple replacement - more sophisticated would handle multiline
        old_line = lines[line_idx]
        if 'Verified:' in old_line or 'Unverified:' in old_line:
            # Preserve indentation
            indent_match = re.match(r'^(\s*)', old_line)
            indent = indent_match.group(1) if indent_match else ""
            lines[line_idx] = indent + new_text
            fixes_applied += 1
            log(f"  {file_path.name}: Updated {evidence.doc_id}", verbose)
            if reg_entry.status == "verified":
                log(f"    Verified: Test: {reg_entry.test_file}::{reg_entry.test_id}", verbose)
            else:
                log(f"    Unverified: {reg_entry.reason}", verbose)

    if fixes_applied > 0:
        file_path.write_text("\n".join(lines) + "\n")

    return fixes_applied


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Sync docs Evidence blocks with test_registry.lua.",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Check mode: report mismatches without fixing",
    )
    parser.add_argument(
        "--fix",
        action="store_true",
        help="Fix mode: update docs to match registry",
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Enable verbose output",
    )

    args = parser.parse_args()

    # Default to check mode if neither specified
    if not args.check and not args.fix:
        args.check = True

    verbose = args.verbose or args.check

    log("=== Docs Evidence Sync ===", verbose)

    # Find git root
    git_root = get_git_root()
    if git_root is None:
        log("ERROR: Not in a git repository", True)
        return EXIT_ERROR

    # Load registry
    registry_path = git_root / "assets" / "scripts" / "test" / "test_registry.lua"
    registry = parse_registry_lua(registry_path, verbose)

    if not registry:
        log("Warning: No registry entries found", verbose)

    # Find and scan doc files
    log("Scanning documentation files...", verbose)
    doc_files = find_doc_files(git_root)
    log(f"  Files: {len(doc_files)}", verbose)

    all_evidence: list[DocEvidence] = []
    for doc_file in doc_files:
        evidence = parse_doc_evidence(doc_file, verbose)
        all_evidence.extend(evidence)

    log(f"  doc_ids found: {len(all_evidence)}", verbose)

    # Compare
    mismatches = compare_evidence(all_evidence, registry, verbose)

    if not mismatches:
        log("All Evidence blocks match registry.", verbose)
        return EXIT_SUCCESS

    # Report mismatches
    log(f"\nFound {len(mismatches)} mismatch(es):", verbose)
    for mismatch in mismatches:
        ev = mismatch.doc_evidence
        log(f"  {ev.file_path}:{ev.line_number}", verbose)
        log(f"    doc_id: {ev.doc_id}", verbose)
        log(f"    {mismatch.reason}", verbose)

    if args.check:
        log(f"\nMISMATCH: {len(mismatches)} inconsistency(ies) found", verbose)
        return EXIT_MISMATCH

    # Fix mode
    if args.fix:
        log("\nUpdating Evidence blocks...", verbose)
        total_fixes = 0

        # Group by file
        files_to_fix = {m.doc_evidence.file_path for m in mismatches}
        for file_path_str in files_to_fix:
            file_path = Path(file_path_str)
            fixes = fix_evidence_in_file(file_path, mismatches, registry, verbose)
            total_fixes += fixes

        log("\n=== Summary ===", verbose)
        log(f"Files modified: {len(files_to_fix)}", verbose)
        log(f"Evidence blocks updated: {total_fixes}", verbose)

        # Check for doc_ids in docs but not in registry
        missing_in_registry = [m for m in mismatches if m.registry_entry is None]
        if missing_in_registry:
            log(f"Missing doc_ids in registry: {len(missing_in_registry)} (warning)", verbose)

        log("Done.", verbose)

    return EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main())
