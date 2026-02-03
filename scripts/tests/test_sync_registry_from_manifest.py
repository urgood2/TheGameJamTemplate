import sys
from pathlib import Path

import pytest

SCRIPT_DIR = Path(__file__).resolve().parents[1]
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from sync_registry_from_manifest import (
    DocIdEntry,
    build_registry,
    compare_registries,
    generate_registry_lua,
    log,
)


def test_generate_registry_deterministic_order():
    registry = {
        "binding:zeta": DocIdEntry(doc_id="binding:zeta", status="unverified"),
        "binding:alpha": DocIdEntry(doc_id="binding:alpha", status="unverified"),
    }
    output = generate_registry_lua(
        registry,
        inventory_files=["bindings.test.json"],
        manifest_path="test_output/test_manifest.json",
        overrides_path="assets/scripts/test/test_registry_overrides.lua",
    )
    lines = [line.strip() for line in output.splitlines()]
    alpha_idx = lines.index('["binding:alpha"] = {')
    zeta_idx = lines.index('["binding:zeta"] = {')
    assert alpha_idx < zeta_idx


def test_manifest_mapping_and_overrides():
    inventory = {
        "binding:alpha": "src/alpha.cpp:1",
        "binding:beta": "src/beta.cpp:2",
    }
    test_mappings = {
        "binding:beta": {
            "test_id": "core.beta",
            "test_file": "test_core.lua",
            "tags": ["smoke", "core"],
            "category": "core",
        }
    }
    overrides = {
        "binding:alpha": {"status": "verified", "reason": "manual"}
    }

    registry, verified, unverified, overrides_applied = build_registry(
        inventory, test_mappings, overrides, verbose=False
    )

    assert registry["binding:beta"].test_id == "core.beta"
    assert registry["binding:beta"].status == "verified"
    assert registry["binding:alpha"].status == "verified"
    assert registry["binding:alpha"].reason == "manual"
    assert verified >= 1
    assert overrides_applied == 1


def test_compare_registries_counts():
    registry = {
        "binding:alpha": DocIdEntry(doc_id="binding:alpha", status="unverified"),
    }
    content_a = generate_registry_lua(
        registry,
        inventory_files=["bindings.test.json"],
        manifest_path="test_output/test_manifest.json",
        overrides_path="assets/scripts/test/test_registry_overrides.lua",
    )
    registry["binding:beta"] = DocIdEntry(doc_id="binding:beta", status="unverified")
    content_b = generate_registry_lua(
        registry,
        inventory_files=["bindings.test.json"],
        manifest_path="test_output/test_manifest.json",
        overrides_path="assets/scripts/test/test_registry_overrides.lua",
    )

    new_entries, updated_entries, removed_entries = compare_registries(content_a, content_b)
    assert new_entries == 1
    assert removed_entries == 0
    assert updated_entries == 0


def test_idempotent_output():
    registry = {
        "binding:alpha": DocIdEntry(doc_id="binding:alpha", status="unverified"),
    }
    content_a = generate_registry_lua(
        registry,
        inventory_files=["bindings.test.json"],
        manifest_path="test_output/test_manifest.json",
        overrides_path="assets/scripts/test/test_registry_overrides.lua",
    )
    content_b = generate_registry_lua(
        registry,
        inventory_files=["bindings.test.json"],
        manifest_path="test_output/test_manifest.json",
        overrides_path="assets/scripts/test/test_registry_overrides.lua",
    )
    assert content_a == content_b


def test_logging_prefix(capsys):
    log("Test message", verbose=True)
    captured = capsys.readouterr()
    assert captured.out.startswith("[SYNC]")
    assert "Test message" in captured.out


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
