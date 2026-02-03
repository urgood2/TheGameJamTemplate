"""Unit tests for sync_docs_evidence.py.

Tests cover:
- doc_id validation
- Evidence block parsing
- Registry entry comparison
- Mismatch detection
- Fix generation
"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent))

from sync_docs_evidence import (
    DocEvidence,
    RegistryEntry,
    compare_evidence,
    generate_evidence_text,
    is_valid_doc_id,
    parse_doc_evidence,
    parse_registry_lua,
)


class TestIsValidDocId:
    """Test doc_id validation."""

    def test_valid_pattern(self):
        """Valid pattern doc_id."""
        assert is_valid_doc_id("pattern:ecs.init.data_preserved") is True

    def test_valid_binding(self):
        """Valid binding doc_id."""
        assert is_valid_doc_id("binding:physics.raycast") is True

    def test_valid_component(self):
        """Valid component doc_id."""
        assert is_valid_doc_id("component:Transform") is True

    def test_valid_sol2(self):
        """Valid sol2 doc_id."""
        assert is_valid_doc_id("sol2_usertype_physics") is True

    def test_invalid_no_colon(self):
        """Invalid: no colon."""
        assert is_valid_doc_id("invalid") is False

    def test_invalid_template_or(self):
        """Invalid: template with (or)."""
        assert is_valid_doc_id("pattern:system.feature (or binding:name)") is False

    def test_invalid_angle_brackets(self):
        """Invalid: template with angle brackets."""
        assert is_valid_doc_id("<test_file>::<test_id>") is False

    def test_invalid_unknown_prefix(self):
        """Invalid: unknown prefix."""
        assert is_valid_doc_id("unknown:something") is False


class TestParseDocEvidence:
    """Test parsing Evidence blocks from markdown."""

    def test_empty_file(self, tmp_path):
        """Empty file returns empty list."""
        doc = tmp_path / "empty.md"
        doc.write_text("")
        assert parse_doc_evidence(doc) == []

    def test_missing_file(self, tmp_path):
        """Missing file returns empty list."""
        assert parse_doc_evidence(tmp_path / "nonexistent.md") == []

    def test_doc_id_and_verified(self, tmp_path):
        """Parses doc_id and verified evidence."""
        doc = tmp_path / "test.md"
        doc.write_text("""
### Test Entry
- doc_id: pattern:test.feature
- Test: test_file.lua::test.feature.basic

**Evidence:**
- Verified: Test: test_file.lua::test.feature.basic
""")
        result = parse_doc_evidence(doc)
        assert len(result) == 1
        assert result[0].doc_id == "pattern:test.feature"
        assert result[0].status == "verified"
        assert result[0].test_ref == "test_file.lua::test.feature.basic"

    def test_doc_id_and_unverified(self, tmp_path):
        """Parses doc_id and unverified evidence."""
        doc = tmp_path / "test.md"
        doc.write_text("""
### Test Entry
- doc_id: component:Debug

**Evidence:**
- Unverified: Internal component, no test needed
""")
        result = parse_doc_evidence(doc)
        assert len(result) == 1
        assert result[0].doc_id == "component:Debug"
        assert result[0].status == "unverified"
        assert "Internal component" in result[0].reason

    def test_multiple_doc_ids(self, tmp_path):
        """Parses multiple doc_ids on one entry."""
        doc = tmp_path / "test.md"
        doc.write_text("""
### Multi Test
- doc_ids: pattern:a, pattern:b, pattern:c

**Evidence:**
- Verified: Test: test.lua::multi
""")
        result = parse_doc_evidence(doc)
        assert len(result) == 3
        assert {r.doc_id for r in result} == {"pattern:a", "pattern:b", "pattern:c"}

    def test_skips_code_fence(self, tmp_path):
        """Skips content inside code fences."""
        doc = tmp_path / "test.md"
        doc.write_text("""
### Real Entry
- doc_id: pattern:real

```markdown
- doc_id: pattern:fake.in.code
**Evidence:**
- Verified: Test: fake.lua::fake
```

**Evidence:**
- Verified: Test: real.lua::real
""")
        result = parse_doc_evidence(doc)
        assert len(result) == 1
        assert result[0].doc_id == "pattern:real"

    def test_skips_template_section(self, tmp_path):
        """Skips Entry Template section."""
        doc = tmp_path / "test.md"
        doc.write_text("""
## Entry Template
- doc_id: pattern:system.feature.case (or binding:name)

**Evidence:**
- Verified: Test: <test_file>::<test_id>

---

## Real Section
- doc_id: pattern:actual.entry

**Evidence:**
- Verified: Test: actual.lua::test
""")
        result = parse_doc_evidence(doc)
        assert len(result) == 1
        assert result[0].doc_id == "pattern:actual.entry"

    def test_filters_invalid_doc_ids(self, tmp_path):
        """Filters out invalid doc_ids from comma-separated list."""
        doc = tmp_path / "test.md"
        doc.write_text("""
### Mixed
- doc_ids: pattern:valid, invalid_no_prefix, pattern:also_valid

**Evidence:**
- Verified: Test: test.lua::test
""")
        result = parse_doc_evidence(doc)
        assert len(result) == 2
        doc_ids = {r.doc_id for r in result}
        assert "pattern:valid" in doc_ids
        assert "pattern:also_valid" in doc_ids
        assert "invalid_no_prefix" not in doc_ids


class TestParseRegistryLua:
    """Test parsing test_registry.lua."""

    def test_missing_file(self, tmp_path):
        """Missing file returns empty dict."""
        result = parse_registry_lua(tmp_path / "nonexistent.lua", verbose=False)
        assert result == {}

    def test_single_entry(self, tmp_path):
        """Parses single registry entry."""
        registry = tmp_path / "test_registry.lua"
        registry.write_text("""
return {
    docs = {
        ["pattern:test"] = {
            test_id = "test.basic",
            test_file = "test.lua",
            status = "verified",
        },
    },
}
""")
        result = parse_registry_lua(registry, verbose=False)
        assert len(result) == 1
        assert "pattern:test" in result
        assert result["pattern:test"].status == "verified"
        assert result["pattern:test"].test_id == "test.basic"

    def test_unverified_entry(self, tmp_path):
        """Parses unverified entry with reason."""
        registry = tmp_path / "test_registry.lua"
        registry.write_text("""
return {
    docs = {
        ["component:Internal"] = {
            test_id = nil,
            status = "unverified",
            reason = "Internal only",
        },
    },
}
""")
        result = parse_registry_lua(registry, verbose=False)
        assert result["component:Internal"].status == "unverified"
        assert result["component:Internal"].reason == "Internal only"

    def test_multiple_entries(self, tmp_path):
        """Parses multiple registry entries."""
        registry = tmp_path / "test_registry.lua"
        registry.write_text("""
return {
    docs = {
        ["pattern:a"] = { status = "verified", test_id = "a.test", test_file = "a.lua" },
        ["pattern:b"] = { status = "unverified", reason = "Not tested" },
        ["pattern:c"] = { status = "verified", test_id = "c.test", test_file = "c.lua" },
    },
}
""")
        result = parse_registry_lua(registry, verbose=False)
        assert len(result) == 3


class TestCompareEvidence:
    """Test comparing doc evidence with registry."""

    def test_no_evidence(self):
        """No evidence means no mismatches."""
        result = compare_evidence([], {}, verbose=False)
        assert result == []

    def test_matching_verified(self):
        """Verified evidence matches verified registry."""
        evidence = [DocEvidence(
            doc_id="pattern:test",
            file_path="test.md",
            line_number=10,
            status="verified",
            test_ref="test.lua::test.basic",
        )]
        registry = {
            "pattern:test": RegistryEntry(
                doc_id="pattern:test",
                test_id="test.basic",
                test_file="test.lua",
                status="verified",
            )
        }
        result = compare_evidence(evidence, registry, verbose=False)
        assert len(result) == 0

    def test_status_mismatch(self):
        """Detects status mismatch."""
        evidence = [DocEvidence(
            doc_id="pattern:test",
            file_path="test.md",
            line_number=10,
            status="verified",
            test_ref="test.lua::test.basic",
        )]
        registry = {
            "pattern:test": RegistryEntry(
                doc_id="pattern:test",
                status="unverified",
                reason="Not implemented",
            )
        }
        result = compare_evidence(evidence, registry, verbose=False)
        assert len(result) == 1
        assert "Status mismatch" in result[0].reason

    def test_missing_in_registry(self):
        """Detects doc_id missing from registry."""
        evidence = [DocEvidence(
            doc_id="pattern:unknown",
            file_path="test.md",
            line_number=10,
            status="verified",
            test_ref="test.lua::test",
        )]
        registry = {}
        result = compare_evidence(evidence, registry, verbose=False)
        assert len(result) == 1
        assert "not found in registry" in result[0].reason

    def test_test_ref_mismatch(self):
        """Detects test reference mismatch."""
        evidence = [DocEvidence(
            doc_id="pattern:test",
            file_path="test.md",
            line_number=10,
            status="verified",
            test_ref="old.lua::old.test",
        )]
        registry = {
            "pattern:test": RegistryEntry(
                doc_id="pattern:test",
                test_id="new.test",
                test_file="new.lua",
                status="verified",
            )
        }
        result = compare_evidence(evidence, registry, verbose=False)
        assert len(result) == 1
        assert "Test ref mismatch" in result[0].reason


class TestGenerateEvidenceText:
    """Test generating Evidence text."""

    def test_verified_with_test(self):
        """Generates verified text with test reference."""
        entry = RegistryEntry(
            doc_id="pattern:test",
            test_id="test.basic",
            test_file="test.lua",
            status="verified",
        )
        result = generate_evidence_text(entry)
        assert result == "- Verified: Test: test.lua::test.basic"

    def test_unverified_with_reason(self):
        """Generates unverified text with reason."""
        entry = RegistryEntry(
            doc_id="pattern:test",
            status="unverified",
            reason="Internal only",
        )
        result = generate_evidence_text(entry)
        assert result == "- Unverified: Internal only"

    def test_unverified_default_reason(self):
        """Generates unverified with default reason."""
        entry = RegistryEntry(
            doc_id="pattern:test",
            status="unverified",
        )
        result = generate_evidence_text(entry)
        assert result == "- Unverified: No test registered"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
