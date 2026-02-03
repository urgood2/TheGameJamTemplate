"""Tests for validate_docs_and_registry.py."""

from __future__ import annotations

import json
from pathlib import Path

from validate_docs_and_registry import run_validation


def write_file(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


def write_registry(path: Path, entries: list[dict]) -> None:
    lines = ["return {", "    docs = {"]  # minimal structure
    for entry in entries:
        doc_id = entry["doc_id"]
        lines.append(f'        ["{doc_id}"] = {{')
        if "test_id" in entry:
            lines.append(f'            test_id = "{entry["test_id"]}",')
        if "quirks_anchor" in entry:
            lines.append(f'            quirks_anchor = "{entry["quirks_anchor"]}",')
        lines.append("        },")
    lines.append("    },")
    lines.append("}")
    write_file(path, "\n".join(lines))


def test_duplicate_doc_ids_detected(tmp_path: Path) -> None:
    root = tmp_path
    write_file(
        root / "planning" / "patterns" / "a.md",
        "**doc_id:** `pattern:core.example.one`\n",
    )
    write_file(
        root / "planning" / "components" / "b.md",
        "**doc_id:** `pattern:core.example.one`\n",
    )

    issues, counts = run_validation(root, {"duplicates"})
    assert counts["failed"] == 1
    assert any(issue.check == "duplicates" for issue in issues)


def test_verified_requires_registry_mapping(tmp_path: Path) -> None:
    root = tmp_path
    write_file(
        root / "planning" / "patterns" / "a.md",
        "\n".join(
            [
                "**doc_id:** `pattern:core.example.verified`",
                "**Verified:** Yes | Test: `test_core.lua::core.example`",
            ]
        ),
    )

    issues, counts = run_validation(root, {"verified"})
    assert counts["failed"] == 1
    assert any("Missing registry entry" in issue.message for issue in issues)


def test_registry_doc_id_requires_doc(tmp_path: Path) -> None:
    root = tmp_path
    write_registry(
        root / "assets" / "scripts" / "test" / "test_registry.lua",
        [{"doc_id": "pattern:missing.doc", "test_id": "missing.test"}],
    )

    issues, counts = run_validation(root, {"registry"})
    assert counts["failed"] == 1
    assert any(issue.check == "registry" for issue in issues)


def test_registry_test_id_requires_manifest(tmp_path: Path) -> None:
    root = tmp_path
    write_registry(
        root / "assets" / "scripts" / "test" / "test_registry.lua",
        [{"doc_id": "pattern:core.example.one", "test_id": "core.example"}],
    )
    manifest = {
        "schema_version": "1.0",
        "tests": [{"test_id": "other.test"}],
    }
    write_file(
        root / "test_output" / "test_manifest.json",
        json.dumps(manifest),
    )

    issues, counts = run_validation(root, {"manifest"})
    assert counts["failed"] == 1
    assert any(issue.check == "manifest" for issue in issues)


def test_quirks_anchor_missing(tmp_path: Path) -> None:
    root = tmp_path
    write_registry(
        root / "assets" / "scripts" / "test" / "test_registry.lua",
        [{"doc_id": "pattern:core.example.one", "quirks_anchor": "missing-anchor"}],
    )
    write_file(
        root / "docs" / "quirks.md",
        "# Known Quirks\n\n## Present Anchor\n",
    )

    issues, counts = run_validation(root, {"quirks"})
    assert counts["failed"] == 1
    assert any(issue.check == "quirks" for issue in issues)
