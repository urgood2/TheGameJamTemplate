#!/usr/bin/env python3
"""Sync test_registry.lua from inventories and test_manifest.json.

This script addresses the "triple truth problem" by treating test_registry.lua
as a GENERATED artifact, reducing drift between docs, registry, and actual tests.

Sources:
- planning/inventory/*.json (doc_ids)
- test_output/test_manifest.json (test → doc_id mappings)
- test_registry_overrides.lua (manual exceptions)

Output:
- assets/scripts/test/test_registry.lua (deterministic generation)

Logging prefix: [SYNC]
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path

# Exit codes
EXIT_SUCCESS = 0
EXIT_CHECK_FAILED = 1
EXIT_ERROR = 2

# Paths (relative to git root)
INVENTORY_DIR = Path("planning/inventory")
TEST_MANIFEST = Path("test_output/test_manifest.json")
OVERRIDES_FILE = Path("assets/scripts/test/test_registry_overrides.lua")
REGISTRY_OUTPUT = Path("assets/scripts/test/test_registry.lua")

LOG_PREFIX = "[SYNC]"


@dataclass
class DocIdEntry:
    """Registry entry for a doc_id."""

    doc_id: str
    test_id: str | None = None
    test_file: str | None = None
    status: str = "unverified"
    reason: str | None = None
    source_ref: str | None = None
    category: str | None = None
    tags: list[str] = field(default_factory=list)


def log(message: str, verbose: bool = True) -> None:
    """Log a message with [SYNC] prefix."""
    if verbose:
        print(f"{LOG_PREFIX} {message}")


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


def extract_doc_ids_from_bindings(data: dict) -> list[tuple[str, str | None]]:
    """Extract doc_ids from a bindings inventory file.

    Returns list of (doc_id, source_ref) tuples.
    """
    doc_ids = []
    bindings = data.get("bindings", {})

    # Handle different binding types
    for binding_type in ["usertypes", "functions", "constants", "enums", "methods", "properties"]:
        items = bindings.get(binding_type, [])
        for item in items:
            if "doc_id" in item:
                source_ref = item.get("source_ref")
                doc_ids.append((item["doc_id"], source_ref))

    return doc_ids


def extract_doc_ids_from_components(data: dict) -> list[tuple[str, str | None]]:
    """Extract doc_ids from a components inventory file.

    Components don't have doc_id field, so we generate: component:{name}
    Returns list of (doc_id, source_ref) tuples.
    """
    doc_ids = []
    components = data.get("components", [])

    for component in components:
        name = component.get("name")
        if name:
            # Generate doc_id in standard format
            doc_id = f"component:{name}"
            file_path = component.get("file_path", "")
            line_num = component.get("line_number", "")
            source_ref = f"{file_path}:{line_num}" if file_path else None
            doc_ids.append((doc_id, source_ref))

    return doc_ids


def extract_doc_ids_from_patterns(data: dict) -> list[tuple[str, str | None]]:
    """Extract doc_ids from a patterns inventory file.

    Returns list of (doc_id, source_ref) tuples.
    """
    doc_ids = []
    patterns = data.get("patterns", [])

    for pattern in patterns:
        if "doc_id" in pattern:
            source_ref = pattern.get("source_ref")
            doc_ids.append((pattern["doc_id"], source_ref))
        elif "name" in pattern:
            # Generate doc_id if not present
            doc_id = f"pattern:{pattern['name']}"
            source_ref = pattern.get("source_ref")
            doc_ids.append((doc_id, source_ref))

    return doc_ids


def load_inventories(
    inventory_dir: Path, verbose: bool = False
) -> tuple[dict[str, str | None], list[str]]:
    """Load all inventory files and extract doc_ids.

    Returns (doc_id -> source_ref, inventory filenames).
    """
    log("Loading inventories...", verbose)
    doc_ids: dict[str, str | None] = {}
    inventory_files = []

    for inv_file in sorted(inventory_dir.glob("*.json")):
        try:
            with open(inv_file, encoding="utf-8") as f:
                data = json.load(f)
        except (OSError, json.JSONDecodeError) as e:
            log(f"  Warning: Failed to load {inv_file.name}: {e}", verbose)
            continue

        extracted = []
        if inv_file.name.startswith("bindings."):
            extracted = extract_doc_ids_from_bindings(data)
            item_type = "bindings"
        elif inv_file.name.startswith("components."):
            extracted = extract_doc_ids_from_components(data)
            item_type = "components"
        elif inv_file.name.startswith("patterns."):
            extracted = extract_doc_ids_from_patterns(data)
            item_type = "patterns"
        else:
            # Skip non-inventory files like stats.json
            continue

        for doc_id, source_ref in extracted:
            doc_ids[doc_id] = source_ref

        inventory_files.append(inv_file.name)
        log(f"  {inv_file.name}: {len(extracted)} {item_type}", verbose)

    log(f"  Total doc_ids from inventories: {len(doc_ids)}", verbose)
    return doc_ids, inventory_files


def load_test_manifest(
    manifest_path: Path,
    verbose: bool = False,
    display_name: str | None = None,
) -> tuple[dict[str, dict], int, int]:
    """Load test manifest and build doc_id -> test mapping.

    Returns (doc_id->test mapping, tests_registered, doc_ids_declared).
    """
    display = display_name or str(manifest_path)
    log(f"Loading {display}...", verbose)

    if not manifest_path.exists():
        log("  Warning: Test manifest not found, continuing without test mappings", verbose)
        return {}, 0, 0

    try:
        with open(manifest_path, encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        log(f"  Warning: Failed to load manifest: {e}", verbose)
        return {}, 0, 0

    tests = data.get("tests", [])
    log(f"  Tests registered: {len(tests)}", verbose)

    # Build doc_id -> test mapping (deterministic)
    doc_id_to_test: dict[str, dict] = {}
    total_doc_ids = 0

    for test in sorted(tests, key=lambda t: str(t.get("test_id", ""))):
        test_id = test.get("test_id")
        test_file = test.get("test_file")
        tags = test.get("tags", [])
        category = test.get("category")

        for doc_id in test.get("doc_ids", []):
            total_doc_ids += 1
            if doc_id not in doc_id_to_test:
                doc_id_to_test[doc_id] = {
                    "test_id": test_id,
                    "test_file": test_file,
                    "tags": sorted(set(tags)) if isinstance(tags, list) else [],
                    "category": category,
                }

    log(f"  doc_ids declared: {total_doc_ids}", verbose)
    return doc_id_to_test, len(tests), total_doc_ids


def parse_lua_overrides(overrides_path: Path, verbose: bool = False) -> dict[str, dict]:
    """Parse Lua overrides file.

    Expects format:
    return {
        ["doc_id"] = { status = "...", reason = "...", ... },
        ...
    }
    """
    log(f"Loading {overrides_path}...", verbose)

    if not overrides_path.exists():
        log("  No overrides file found, skipping", verbose)
        return {}

    try:
        content = overrides_path.read_text()
    except OSError as e:
        log(f"  Warning: Failed to read overrides: {e}", verbose)
        return {}

    overrides: dict[str, dict] = {}

    # Strip Lua comments (lines starting with --)
    lines = []
    for line in content.splitlines():
        stripped = line.lstrip()
        if not stripped.startswith("--"):
            lines.append(line)
    content_no_comments = "\n".join(lines)

    # Simple Lua table parsing for our specific format
    # Match entries like: ["doc_id"] = { key = "value", ... }
    entry_pattern = re.compile(
        r'\["([^"]+)"\]\s*=\s*\{([^}]*)\}',
        re.MULTILINE,
    )

    for match in entry_pattern.finditer(content_no_comments):
        doc_id = match.group(1)
        fields_str = match.group(2)

        entry: dict[str, str | None] = {}

        # Parse simple key = "value" pairs
        field_pattern = re.compile(r'(\w+)\s*=\s*"([^"]*)"')
        for field_match in field_pattern.finditer(fields_str):
            key = field_match.group(1)
            value = field_match.group(2)
            entry[key] = value

        if entry:
            overrides[doc_id] = entry

    log(f"  Overrides loaded: {len(overrides)}", verbose)
    return overrides


def build_registry(
    inventory_doc_ids: dict[str, str | None],
    test_mappings: dict[str, dict],
    overrides: dict[str, dict],
    verbose: bool = False,
) -> tuple[dict[str, DocIdEntry], int, int, int]:
    """Build the registry from all sources."""
    log("Matching doc_ids to tests...", verbose)
    registry: dict[str, DocIdEntry] = {}

    verified_count = 0
    unverified_count = 0
    overrides_applied = 0

    # Process all doc_ids from inventories
    for doc_id in sorted(inventory_doc_ids.keys()):
        source_ref = inventory_doc_ids[doc_id]

        if doc_id in test_mappings:
            test_info = test_mappings[doc_id]
            entry = DocIdEntry(
                doc_id=doc_id,
                test_id=test_info.get("test_id"),
                test_file=test_info.get("test_file"),
                status="verified",
                source_ref=source_ref,
                category=test_info.get("category"),
                tags=test_info.get("tags", []),
            )
            verified_count += 1
        else:
            entry = DocIdEntry(
                doc_id=doc_id,
                status="unverified",
                reason="No test registered for this doc_id",
                source_ref=source_ref,
            )
            unverified_count += 1

        registry[doc_id] = entry

    # Also include test-declared doc_ids not in inventories
    for doc_id, test_info in test_mappings.items():
        if doc_id not in registry:
            registry[doc_id] = DocIdEntry(
                doc_id=doc_id,
                test_id=test_info.get("test_id"),
                test_file=test_info.get("test_file"),
                status="verified",
                category=test_info.get("category"),
                tags=test_info.get("tags", []),
            )
            verified_count += 1

    log(f"  Verified (test exists): {verified_count}", verbose)
    log(f"  Unverified (no test): {unverified_count}", verbose)

    # Apply overrides
    if overrides:
        for doc_id, override in overrides.items():
            if doc_id not in registry:
                continue
            entry = registry[doc_id]
            if "status" in override:
                entry.status = override["status"]
            if "reason" in override:
                entry.reason = override["reason"]
            if "test_id" in override:
                entry.test_id = override["test_id"]
            if "note" in override:
                entry.reason = override.get("note")
            overrides_applied += 1
            log(f"  Applying: {doc_id}", verbose)

    return registry, verified_count, unverified_count, overrides_applied


def generate_registry_lua(
    registry: dict[str, DocIdEntry],
    inventory_files: list[str],
    manifest_path: str,
    overrides_path: str,
) -> str:
    """Generate deterministic Lua registry file content."""
    now = datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")

    lines = [
        "-- AUTO-GENERATED by scripts/sync_registry_from_manifest.py",
        "-- Do not edit directly. Use test_registry_overrides.lua for exceptions.",
        f"-- Generated at: {now}",
        f"-- From: {manifest_path}, planning/inventory/*.json",
        "",
        "return {",
        '    schema_version = "1.0",',
        f'    generated_at = "{now}",',
        "    sources = {",
        f'        manifest = "{manifest_path}",',
        f'        overrides = "{overrides_path}",',
        "        inventories = {",
    ]

    # Add inventory files
    for inv_file in sorted(inventory_files):
        lines.append(f'            "{inv_file}",')
    lines.append("        },")
    lines.append("    },")
    lines.append("    docs = {")

    # Add doc entries sorted alphabetically
    for doc_id in sorted(registry.keys()):
        entry = registry[doc_id]
        lines.append(f'        ["{doc_id}"] = {{')

        if entry.test_id:
            lines.append(f'            test_id = "{entry.test_id}",')
        else:
            lines.append("            test_id = nil,")

        if entry.test_file:
            lines.append(f'            test_file = "{entry.test_file}",')

        lines.append(f'            status = "{entry.status}",')

        if entry.reason:
            # Escape quotes in reason
            escaped_reason = entry.reason.replace('"', '\\"')
            lines.append(f'            reason = "{escaped_reason}",')

        if entry.source_ref:
            lines.append(f'            source_ref = "{entry.source_ref}",')

        if entry.category:
            lines.append(f'            category = "{entry.category}",')

        if entry.tags:
            tags_str = ", ".join(f'"{t}"' for t in sorted(set(entry.tags)))
            lines.append(f"            tags = {{{tags_str}}},")

        lines.append("        },")

    lines.append("    },")
    lines.append("}")
    lines.append("")

    return "\n".join(lines)


def parse_registry_docs(content: str) -> dict[str, dict]:
    """Parse doc entries from a generated registry file."""
    docs: dict[str, dict] = {}
    current_id = None
    current_fields: dict[str, object] = {}

    for raw_line in content.splitlines():
        line = raw_line.strip()
        if line.startswith('["') and line.endswith("{"):
            current_id = line.split('"', 2)[1]
            current_fields = {}
            continue
        if current_id and line.startswith("}"):
            docs[current_id] = current_fields
            current_id = None
            continue
        if not current_id:
            continue

        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().rstrip(",")

        if value == "nil":
            parsed = None
        elif value.startswith("{") and value.endswith("}"):
            items = [v.strip().strip('"') for v in value.strip("{}").split(",") if v.strip()]
            parsed = items
        elif value.startswith('"') and value.endswith('"'):
            parsed = value.strip('"')
        else:
            parsed = value

        current_fields[key] = parsed

    return docs


def compare_registries(old_content: str, new_content: str) -> tuple[int, int, int]:
    """Compare old and new registry content.

    Returns (new_entries, updated_entries, removed_entries).
    """
    old_docs = parse_registry_docs(old_content)
    new_docs = parse_registry_docs(new_content)

    old_ids = set(old_docs.keys())
    new_ids = set(new_docs.keys())

    new_entries = len(new_ids - old_ids)
    removed_entries = len(old_ids - new_ids)
    updated_entries = sum(
        1 for doc_id in (old_ids & new_ids)
        if old_docs.get(doc_id) != new_docs.get(doc_id)
    )

    return new_entries, updated_entries, removed_entries


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Sync test_registry.lua from inventories and test manifest.",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Check mode: report differences without writing",
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Enable verbose output",
    )

    args = parser.parse_args()
    verbose = args.verbose or args.check  # Always verbose in check mode

    log("=== Registry Sync from Manifest ===", verbose)

    # Find git root
    git_root = get_git_root()
    if git_root is None:
        log("ERROR: Not in a git repository", True)
        return EXIT_ERROR

    # Resolve paths
    inventory_dir = git_root / INVENTORY_DIR
    manifest_path = git_root / TEST_MANIFEST
    overrides_path = git_root / OVERRIDES_FILE
    output_path = git_root / REGISTRY_OUTPUT

    # Load all sources
    test_mappings, tests_registered, doc_ids_declared = load_test_manifest(
        manifest_path, verbose, display_name=str(TEST_MANIFEST)
    )
    inventory_doc_ids, inventory_files = load_inventories(inventory_dir, verbose)
    overrides = parse_lua_overrides(overrides_path, verbose)

    # Build registry
    log(f"Applying overrides from {OVERRIDES_FILE}...", verbose)

    registry, verified_count, unverified_count, overrides_applied = build_registry(
        inventory_doc_ids, test_mappings, overrides, verbose
    )
    log(f"  Verified (test exists): {verified_count}", verbose)
    log(f"  Unverified (no test): {unverified_count}", verbose)
    log(f"  Overrides applied: {overrides_applied}", verbose)

    # Generate output
    log("Generating test_registry.lua...", verbose)
    new_content = generate_registry_lua(
        registry,
        inventory_files,
        str(TEST_MANIFEST),
        str(OVERRIDES_FILE),
    )

    # Compare with existing
    if output_path.exists():
        old_content = output_path.read_text()
        new_entries, updated_entries, removed_entries = compare_registries(old_content, new_content)
        log(f"  New entries: {new_entries}", verbose)
        log(f"  Updated entries: {updated_entries}", verbose)
        log(f"  Removed entries: {removed_entries}", verbose)
    else:
        log(f"  Creating new registry with {len(registry)} entries", verbose)

    # Check mode
    if args.check:
        if output_path.exists():
            if new_content == output_path.read_text():
                log("Registry is up to date.", verbose)
                return EXIT_SUCCESS
            else:
                log("Registry needs updating (run without --check to update).", verbose)
                return EXIT_CHECK_FAILED
        else:
            log("Registry does not exist (run without --check to create).", verbose)
            return EXIT_CHECK_FAILED

    # Write output
    log("Writing test_registry.lua...", verbose)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(new_content)

    log("Done.", verbose)
    log(f"Registry now has {len(registry)} entries.", verbose)
    return EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main())
