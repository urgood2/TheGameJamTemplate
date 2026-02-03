"""Unit tests for extract_components.py.

Tests cover:
- Parses basic struct fields and types
- Handles nested/templated types by marking extraction_confidence lower
- Categorization rules are deterministic
- Generates stable lua_accessibility_matrix.md skeleton
- Output objects satisfy schema-required fields
- Logs use stable [EXTRACT] prefixes
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from textwrap import dedent

import pytest

# Add scripts to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from extract_components import (
    LOG_PREFIX,
    ComponentInfo,
    FieldInfo,
    categorize_file,
    component_to_dict,
    extract_fields,
    generate_lua_matrix,
    is_complex_type,
    parse_header,
)


class TestFieldExtraction:
    """Test field parsing from struct bodies."""

    def test_basic_fields(self) -> None:
        """Parses basic struct fields with types."""
        struct_body = dedent("""
        {
            float x = 0.0f;
            float y = 0.0f;
            int count;
            bool enabled = true;
        }
        """)
        fields = extract_fields(struct_body)

        assert len(fields) == 4
        assert fields[0].name == "x"
        assert fields[0].type == "float"
        assert fields[0].default == "0.0f"
        assert fields[1].name == "y"
        assert fields[2].name == "count"
        assert fields[2].default is None
        assert fields[3].name == "enabled"
        assert fields[3].default == "true"

    def test_brace_initializer(self) -> None:
        """Parses fields with brace initializers."""
        struct_body = dedent("""
        {
            std::string name{};
            float alpha{1.0f};
            Color color{};
        }
        """)
        fields = extract_fields(struct_body)

        assert len(fields) == 3
        assert fields[0].name == "name"
        # Empty braces {} parsed as None (default initialized)
        assert fields[0].default is None or fields[0].default == ""
        assert fields[1].name == "alpha"
        assert fields[1].default == "1.0f"

    def test_complex_types_marked(self) -> None:
        """Complex types reduce extraction confidence."""
        struct_body = dedent("""
        {
            std::vector<int> items;
            std::map<std::string, int> lookup;
            sol::function callback;
            float simple;
        }
        """)
        fields = extract_fields(struct_body)

        assert len(fields) == 4
        # Complex types flagged
        assert fields[0].is_complex  # vector
        assert fields[1].is_complex  # map
        assert fields[2].is_complex  # sol::function
        assert not fields[3].is_complex  # float is simple


class TestComplexTypeDetection:
    """Test is_complex_type function."""

    @pytest.mark.parametrize(
        "type_str,expected",
        [
            ("float", False),
            ("int", False),
            ("bool", False),
            ("std::string", False),
            ("std::vector<int>", True),
            ("std::map<std::string, int>", True),
            ("sol::table", True),
            ("sol::function", True),
            ("std::function<void()>", True),
        ],
    )
    def test_type_classification(self, type_str: str, expected: bool) -> None:
        """Types classified correctly as simple or complex."""
        assert is_complex_type(type_str) == expected


class TestCategorization:
    """Test file categorization rules."""

    @pytest.mark.parametrize(
        "path,expected_category",
        [
            (Path("src/components/components.hpp"), "core"),
            (Path("src/systems/physics/physics_components.hpp"), "physics"),
            (Path("src/systems/composable_mechanics/components.hpp"), "combat"),
            (Path("src/systems/ui/ui_components.hpp"), "ui"),
            (Path("src/systems/layer/layer.hpp"), "rendering"),
            (Path("src/systems/input/input.hpp"), "input"),
            (Path("src/systems/unknown/mystery.hpp"), "other"),
        ],
    )
    def test_categorization_deterministic(self, path: Path, expected_category: str) -> None:
        """Categorization is deterministic based on path."""
        assert categorize_file(path) == expected_category


class TestHeaderParsing:
    """Test parsing of complete header files."""

    def test_parse_simple_header(self, tmp_path: Path) -> None:
        """Parses simple header with struct definitions."""
        header = tmp_path / "test.hpp"
        header.write_text(dedent("""
        #pragma once

        struct SimpleComponent {
            float x = 0.0f;
            float y = 0.0f;
        };

        struct TagComponent {
        };
        """))

        components = parse_header(header, verbose=False)

        assert len(components) == 2
        assert components[0].name == "SimpleComponent"
        assert len(components[0].fields) == 2
        assert components[0].is_tag is False
        assert components[1].name == "TagComponent"
        assert components[1].is_tag is True

    def test_confidence_reduced_for_complex(self, tmp_path: Path) -> None:
        """Complex types reduce extraction confidence."""
        header = tmp_path / "complex.hpp"
        header.write_text(dedent("""
        struct ComplexComponent {
            std::vector<int> items;
            std::map<std::string, float> lookup;
            sol::table data;
        };
        """))

        components = parse_header(header, verbose=False)

        assert len(components) == 1
        # Confidence reduced from 1.0 due to complex types
        assert components[0].extraction_confidence < 1.0


class TestOutputGeneration:
    """Test output file generation."""

    def test_component_to_dict_schema(self) -> None:
        """Output dict has required schema fields."""
        comp = ComponentInfo(
            name="TestComponent",
            category="core",
            file_path="src/test.hpp",
            line_number=10,
            fields=[
                FieldInfo(name="x", type="float", default="0.0f", is_complex=False),
            ],
            is_tag=False,
            extraction_confidence=0.9,
            notes=["test note"],
        )

        result = component_to_dict(comp)

        # Required fields present
        assert "name" in result
        assert "category" in result
        assert "file_path" in result
        assert "line_number" in result
        assert "is_tag" in result
        assert "extraction_confidence" in result
        assert "notes" in result
        assert "fields" in result

        # Fields have required structure
        assert len(result["fields"]) == 1
        assert result["fields"][0]["name"] == "x"
        assert result["fields"][0]["type"] == "float"

    def test_lua_matrix_generation(self) -> None:
        """Generates valid lua accessibility matrix."""
        components = [
            ComponentInfo(
                name="Comp1",
                category="core",
                file_path="a.hpp",
                line_number=1,
                fields=[],
                is_tag=True,
            ),
            ComponentInfo(
                name="Comp2",
                category="physics",
                file_path="b.hpp",
                line_number=1,
                fields=[FieldInfo("x", "float")],
            ),
        ]

        matrix = generate_lua_matrix(components)

        # Has header
        assert "# Lua Accessibility Matrix" in matrix
        # Has table header
        assert "| Component | Category | Lua Access | Via | Notes |" in matrix
        # Has components
        assert "| Comp1 |" in matrix
        assert "| Comp2 |" in matrix
        # Has legend
        assert "## Legend" in matrix


class TestLogging:
    """Test logging format."""

    def test_log_prefix(self) -> None:
        """Log prefix is stable."""
        assert LOG_PREFIX == "[EXTRACT]"


class TestSchemaCompliance:
    """Test that output satisfies schema requirements."""

    def test_json_serializable(self) -> None:
        """Output can be serialized to JSON."""
        comp = ComponentInfo(
            name="Test",
            category="core",
            file_path="test.hpp",
            line_number=1,
            fields=[FieldInfo("x", "float", "0.0f", False)],
        )

        # Should not raise
        json_str = json.dumps(component_to_dict(comp))
        assert json_str  # Non-empty

        # Should be valid JSON
        parsed = json.loads(json_str)
        assert parsed["name"] == "Test"
