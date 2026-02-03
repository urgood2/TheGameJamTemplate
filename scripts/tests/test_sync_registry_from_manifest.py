"""Unit tests for sync_registry_from_manifest.py.

Tests cover:
- Doc ID extraction from different inventory types
- Test manifest loading and mapping
- Lua overrides parsing
- Registry building and merging
- Deterministic output generation
"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent))

from sync_registry_from_manifest import (
    DocIdEntry,
    build_registry,
    extract_doc_ids_from_bindings,
    extract_doc_ids_from_components,
    extract_doc_ids_from_patterns,
    generate_registry_lua,
    parse_lua_overrides,
)


class TestExtractDocIdsFromBindings:
    """Test extracting doc_ids from bindings inventory files."""

    def test_empty_bindings(self):
        """Empty bindings dict returns empty list."""
        data = {"bindings": {}}
        assert extract_doc_ids_from_bindings(data) == []

    def test_usertypes(self):
        """Usertypes are extracted correctly."""
        data = {
            "bindings": {
                "usertypes": [
                    {"doc_id": "sol2_usertype_physics", "source_ref": "physics.cpp:100"},
                    {"doc_id": "sol2_usertype_collision", "source_ref": "collision.cpp:50"},
                ]
            }
        }
        result = extract_doc_ids_from_bindings(data)
        assert len(result) == 2
        assert ("sol2_usertype_physics", "physics.cpp:100") in result
        assert ("sol2_usertype_collision", "collision.cpp:50") in result

    def test_functions(self):
        """Functions are extracted correctly."""
        data = {
            "bindings": {
                "functions": [
                    {"doc_id": "binding:physics.raycast", "source_ref": "physics.cpp:200"},
                ]
            }
        }
        result = extract_doc_ids_from_bindings(data)
        assert len(result) == 1
        assert result[0] == ("binding:physics.raycast", "physics.cpp:200")

    def test_mixed_binding_types(self):
        """Multiple binding types are all extracted."""
        data = {
            "bindings": {
                "usertypes": [{"doc_id": "ut1"}],
                "functions": [{"doc_id": "fn1"}],
                "constants": [{"doc_id": "const1"}],
                "enums": [{"doc_id": "enum1"}],
                "methods": [{"doc_id": "method1"}],
                "properties": [{"doc_id": "prop1"}],
            }
        }
        result = extract_doc_ids_from_bindings(data)
        doc_ids = [r[0] for r in result]
        assert len(doc_ids) == 6
        assert "ut1" in doc_ids
        assert "fn1" in doc_ids
        assert "const1" in doc_ids
        assert "enum1" in doc_ids
        assert "method1" in doc_ids
        assert "prop1" in doc_ids

    def test_missing_doc_id_skipped(self):
        """Items without doc_id are skipped."""
        data = {
            "bindings": {
                "functions": [
                    {"doc_id": "valid"},
                    {"name": "no_doc_id"},  # Missing doc_id
                ]
            }
        }
        result = extract_doc_ids_from_bindings(data)
        assert len(result) == 1
        assert result[0][0] == "valid"


class TestExtractDocIdsFromComponents:
    """Test extracting doc_ids from components inventory files."""

    def test_empty_components(self):
        """Empty components list returns empty list."""
        data = {"components": []}
        assert extract_doc_ids_from_components(data) == []

    def test_generates_doc_id(self):
        """Doc ID is generated from component name."""
        data = {
            "components": [
                {
                    "name": "Transform",
                    "file_path": "components.hpp",
                    "line_number": 42,
                }
            ]
        }
        result = extract_doc_ids_from_components(data)
        assert len(result) == 1
        assert result[0] == ("component:Transform", "components.hpp:42")

    def test_multiple_components(self):
        """Multiple components are extracted."""
        data = {
            "components": [
                {"name": "Position", "file_path": "pos.hpp", "line_number": 10},
                {"name": "Velocity", "file_path": "vel.hpp", "line_number": 20},
                {"name": "Health", "file_path": "health.hpp", "line_number": 30},
            ]
        }
        result = extract_doc_ids_from_components(data)
        assert len(result) == 3
        doc_ids = [r[0] for r in result]
        assert "component:Position" in doc_ids
        assert "component:Velocity" in doc_ids
        assert "component:Health" in doc_ids

    def test_missing_name_skipped(self):
        """Components without name are skipped."""
        data = {
            "components": [
                {"name": "Valid"},
                {"category": "no_name"},  # Missing name
            ]
        }
        result = extract_doc_ids_from_components(data)
        assert len(result) == 1


class TestExtractDocIdsFromPatterns:
    """Test extracting doc_ids from patterns inventory files."""

    def test_empty_patterns(self):
        """Empty patterns list returns empty list."""
        data = {"patterns": []}
        assert extract_doc_ids_from_patterns(data) == []

    def test_explicit_doc_id(self):
        """Explicit doc_id is used when present."""
        data = {
            "patterns": [
                {"doc_id": "pattern:test.harness.register", "source_ref": "test.lua:100"}
            ]
        }
        result = extract_doc_ids_from_patterns(data)
        assert len(result) == 1
        assert result[0] == ("pattern:test.harness.register", "test.lua:100")

    def test_generated_doc_id(self):
        """Doc ID is generated from name when not present."""
        data = {
            "patterns": [
                {"name": "entity.spawn", "source_ref": "spawn.lua:50"}
            ]
        }
        result = extract_doc_ids_from_patterns(data)
        assert len(result) == 1
        assert result[0] == ("pattern:entity.spawn", "spawn.lua:50")


class TestParseLuaOverrides:
    """Test parsing Lua overrides file."""

    def test_missing_file(self, tmp_path):
        """Missing file returns empty dict."""
        result = parse_lua_overrides(tmp_path / "nonexistent.lua", verbose=False)
        assert result == {}

    def test_empty_table(self, tmp_path):
        """Empty return table returns empty dict."""
        overrides_file = tmp_path / "overrides.lua"
        overrides_file.write_text("return {}\n")
        result = parse_lua_overrides(overrides_file, verbose=False)
        assert result == {}

    def test_single_entry(self, tmp_path):
        """Single override entry is parsed."""
        overrides_file = tmp_path / "overrides.lua"
        overrides_file.write_text('''
return {
    ["binding:internal.func"] = {
        status = "unverified",
        reason = "Internal only"
    },
}
''')
        result = parse_lua_overrides(overrides_file, verbose=False)
        assert len(result) == 1
        assert "binding:internal.func" in result
        assert result["binding:internal.func"]["status"] == "unverified"
        assert result["binding:internal.func"]["reason"] == "Internal only"

    def test_multiple_entries(self, tmp_path):
        """Multiple override entries are parsed."""
        overrides_file = tmp_path / "overrides.lua"
        overrides_file.write_text('''
return {
    ["doc_id_1"] = { status = "verified", note = "Manually checked" },
    ["doc_id_2"] = { status = "unverified", reason = "Deprecated" },
}
''')
        result = parse_lua_overrides(overrides_file, verbose=False)
        assert len(result) == 2
        assert result["doc_id_1"]["status"] == "verified"
        assert result["doc_id_2"]["status"] == "unverified"

    def test_comments_ignored(self, tmp_path):
        """Lua comments are ignored."""
        overrides_file = tmp_path / "overrides.lua"
        overrides_file.write_text('''
-- This is a comment
return {
    -- ["commented"] = { status = "verified" },
    ["actual"] = { status = "verified" },
}
''')
        result = parse_lua_overrides(overrides_file, verbose=False)
        assert len(result) == 1
        assert "actual" in result
        assert "commented" not in result


class TestBuildRegistry:
    """Test building registry from all sources."""

    def test_empty_sources(self):
        """Empty sources produce empty registry."""
        result = build_registry({}, {}, {}, verbose=False)
        assert result == {}

    def test_inventory_only(self):
        """Inventory doc_ids without tests are unverified."""
        inventory = {
            "component:Health": "health.hpp:10",
            "component:Damage": "damage.hpp:20",
        }
        result = build_registry(inventory, {}, {}, verbose=False)
        assert len(result) == 2
        assert result["component:Health"].status == "unverified"
        assert result["component:Damage"].status == "unverified"

    def test_test_mappings_verify(self):
        """Test mappings mark doc_ids as verified."""
        inventory = {"binding:physics.raycast": "physics.cpp:100"}
        test_mappings = {
            "binding:physics.raycast": {
                "test_id": "physics.raycast.basic",
                "test_file": "test_physics.lua",
                "status": "verified",
                "tags": ["physics"],
                "category": "physics",
            }
        }
        result = build_registry(inventory, test_mappings, {}, verbose=False)
        assert len(result) == 1
        entry = result["binding:physics.raycast"]
        assert entry.status == "verified"
        assert entry.test_id == "physics.raycast.basic"
        assert entry.test_file == "test_physics.lua"

    def test_overrides_applied(self):
        """Overrides modify registry entries."""
        inventory = {"binding:internal.func": "internal.cpp:50"}
        overrides = {
            "binding:internal.func": {
                "status": "unverified",
                "reason": "Internal only, not exposed",
            }
        }
        result = build_registry(inventory, {}, overrides, verbose=False)
        entry = result["binding:internal.func"]
        assert entry.status == "unverified"
        assert entry.reason == "Internal only, not exposed"

    def test_test_declared_doc_ids_added(self):
        """Doc IDs from tests not in inventory are still added."""
        inventory = {}
        test_mappings = {
            "pattern:test.harness.assert": {
                "test_id": "harness.assert.basic",
                "test_file": "test_harness.lua",
                "status": "verified",
                "tags": ["selftest"],
                "category": "selftest",
            }
        }
        result = build_registry(inventory, test_mappings, {}, verbose=False)
        assert len(result) == 1
        assert "pattern:test.harness.assert" in result
        assert result["pattern:test.harness.assert"].status == "verified"


class TestGenerateRegistryLua:
    """Test Lua registry file generation."""

    def test_empty_registry(self):
        """Empty registry generates valid Lua."""
        output = generate_registry_lua({}, [], "test_manifest.json")
        assert "return {" in output
        assert "docs = {" in output
        assert "schema_version" in output

    def test_sorted_keys(self):
        """Doc IDs are sorted alphabetically."""
        registry = {
            "z_last": DocIdEntry(doc_id="z_last"),
            "a_first": DocIdEntry(doc_id="a_first"),
            "m_middle": DocIdEntry(doc_id="m_middle"),
        }
        output = generate_registry_lua(registry, [], "test_manifest.json")
        a_pos = output.find('["a_first"]')
        m_pos = output.find('["m_middle"]')
        z_pos = output.find('["z_last"]')
        assert a_pos < m_pos < z_pos

    def test_verified_entry_format(self):
        """Verified entry has all fields."""
        registry = {
            "binding:test": DocIdEntry(
                doc_id="binding:test",
                test_id="test.basic",
                test_file="test.lua",
                status="verified",
                source_ref="test.cpp:100",
                category="unit",
                tags=["tag1", "tag2"],
            )
        }
        output = generate_registry_lua(registry, [], "test_manifest.json")
        assert 'test_id = "test.basic"' in output
        assert 'test_file = "test.lua"' in output
        assert 'status = "verified"' in output
        assert 'source_ref = "test.cpp:100"' in output
        assert 'category = "unit"' in output
        assert "tag1" in output
        assert "tag2" in output

    def test_unverified_entry_format(self):
        """Unverified entry has reason."""
        registry = {
            "component:Debug": DocIdEntry(
                doc_id="component:Debug",
                status="unverified",
                reason="Internal component",
            )
        }
        output = generate_registry_lua(registry, [], "test_manifest.json")
        assert "test_id = nil" in output
        assert 'status = "unverified"' in output
        assert 'reason = "Internal component"' in output

    def test_header_metadata(self):
        """Header contains generation metadata."""
        output = generate_registry_lua({}, ["inv1.json", "inv2.json"], "manifest.json")
        assert "AUTO-GENERATED" in output
        assert "sync_registry_from_manifest.py" in output
        assert "Generated at:" in output
        assert "manifest.json" in output


class TestDeterministicOutput:
    """Test that output is deterministic."""

    def test_same_input_same_output(self):
        """Same input always produces same output (except timestamp)."""
        registry = {
            "doc1": DocIdEntry(doc_id="doc1", status="verified"),
            "doc2": DocIdEntry(doc_id="doc2", status="unverified", reason="test"),
        }
        output1 = generate_registry_lua(registry, ["inv.json"], "manifest.json")
        output2 = generate_registry_lua(registry, ["inv.json"], "manifest.json")

        # Remove timestamp lines for comparison
        def strip_timestamp(s):
            return "\n".join(
                ln for ln in s.splitlines()
                if "Generated at:" not in ln and "generated_at" not in ln
            )

        assert strip_timestamp(output1) == strip_timestamp(output2)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
