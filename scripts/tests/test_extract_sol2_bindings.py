"""Tests for extract_sol2_bindings.py.

These tests verify the Sol2 binding extraction logic using
fixture C++ snippets without requiring actual source files.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import TYPE_CHECKING

import pytest

# Add scripts directory to path
SCRIPTS_DIR = Path(__file__).parent.parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from extract_sol2_bindings import (
    CONFIDENCE_HIGH,
    CONFIDENCE_LOW,
    CONFIDENCE_MEDIUM,
    BindingRecord,
    SystemInventory,
    extract_from_file,
    generate_doc_id,
)


class TestGenerateDocId:
    """Tests for doc_id generation."""

    def test_simple_name(self) -> None:
        """Simple names are converted correctly."""
        assert generate_doc_id("Entity", "usertype") == "sol2_usertype_entity"

    def test_dotted_name(self) -> None:
        """Dotted names have dots replaced with underscores."""
        assert generate_doc_id("physics.RaycastHit", "usertype") == "sol2_usertype_physics_raycasthit"

    def test_method_name(self) -> None:
        """Method names with colons are handled."""
        assert generate_doc_id("Entity:GetPosition", "method") == "sol2_method_entity_getposition"


class TestBindingRecord:
    """Tests for BindingRecord dataclass."""

    def test_to_dict(self) -> None:
        """to_dict produces correct JSON-serializable output."""
        record = BindingRecord(
            lua_name="Entity",
            binding_type="usertype",
            cpp_type="entt::entity",
            doc_id="sol2_usertype_entity",
            source_ref="src/test.cpp:42",
            extraction_confidence=CONFIDENCE_HIGH,
        )
        d = record.to_dict()

        assert d["lua_name"] == "Entity"
        assert d["type"] == "usertype"
        assert d["cpp_type"] == "entt::entity"
        assert d["extraction_confidence"] == "high"
        assert d["verified"] is False


class TestSystemInventory:
    """Tests for SystemInventory dataclass."""

    def test_to_dict_schema(self) -> None:
        """to_dict includes required schema fields."""
        inv = SystemInventory(system_name="test")
        inv.usertypes.append(
            BindingRecord(
                lua_name="TestType",
                binding_type="usertype",
                doc_id="sol2_usertype_testtype",
                source_ref="test.cpp:1",
            )
        )
        d = inv.to_dict()

        assert "schema_version" in d
        assert d["schema_version"] == "1.0"
        assert "generated_at" in d
        assert "system" in d
        assert d["system"] == "test"
        assert "summary" in d
        assert "bindings" in d

    def test_summary_counts(self) -> None:
        """Summary includes correct counts."""
        inv = SystemInventory(system_name="test")
        inv.usertypes.append(
            BindingRecord(lua_name="A", binding_type="usertype", doc_id="a", source_ref="t:1")
        )
        inv.usertypes.append(
            BindingRecord(
                lua_name="B",
                binding_type="usertype",
                doc_id="b",
                source_ref="t:2",
                extraction_confidence=CONFIDENCE_LOW,
            )
        )
        inv.functions.append(
            BindingRecord(lua_name="foo", binding_type="function", doc_id="foo", source_ref="t:3")
        )

        d = inv.to_dict()
        assert d["summary"]["usertypes"] == 2
        assert d["summary"]["functions"] == 1
        assert d["summary"]["low_confidence"] == 1


class TestExtractFromFile:
    """Tests for extract_from_file function using fixture files."""

    @pytest.fixture
    def cpp_new_usertype(self, tmp_path: Path) -> Path:
        """Create a fixture file with new_usertype pattern."""
        content = '''
#include <sol/sol.hpp>

void setup_bindings(sol::state& lua) {
    lua.new_usertype<Player>(
        "Player",
        "name", &Player::name,
        "health", &Player::health
    );

    lua.new_usertype<Enemy>(
        "Enemy",
        "damage", &Enemy::damage
    );
}
'''
        f = tmp_path / "test_usertype.cpp"
        f.write_text(content)
        return f

    @pytest.fixture
    def cpp_set_function(self, tmp_path: Path) -> Path:
        """Create a fixture file with set_function patterns."""
        content = '''
#include <sol/sol.hpp>

void setup_bindings(sol::state& lua) {
    sol::table physics_table = lua["physics"].get_or_create<sol::table>();
    physics_table.set_function("raycast", &do_raycast);
    physics_table.set_function("query", &do_query);

    lua.set_function("globalFunc", &global_function);
}
'''
        f = tmp_path / "test_functions.cpp"
        f.write_text(content)
        return f

    @pytest.fixture
    def cpp_enum(self, tmp_path: Path) -> Path:
        """Create a fixture file with enum patterns."""
        content = '''
#include <sol/sol.hpp>

void setup_bindings(sol::state& lua) {
    lua.new_enum("ActionResult",
        "SUCCESS", 0,
        "FAILURE", 1,
        "RUNNING", 2
    );

    sol::table ts = lua["TextSystem"].get_or_create<sol::table>();
    ts["TextWrapMode"] = lua.create_table_with(
        "WORD", 0,
        "CHARACTER", 1
    );
}
'''
        f = tmp_path / "test_enums.cpp"
        f.write_text(content)
        return f

    @pytest.fixture
    def cpp_binding_recorder(self, tmp_path: Path) -> Path:
        """Create a fixture file with BindingRecorder patterns."""
        content = '''
#include "binding_recorder.hpp"

void setup_bindings(sol::state& lua) {
    auto& rec = BindingRecorder::instance();

    rec.bind_function(
        lua,
        {},
        "publishEvent",
        &publish_event,
        "signature here",
        "doc here"
    );

    rec.bind_usertype<Entity>(
        lua,
        "Entity",
        "1.0",
        "Entity type"
    );

    rec.add_type("physics.RaycastHit").doc = "Result of raycast";
    rec.record_method("physics.RaycastHit", MethodDef{ "getPoint", "() -> vec2" });
    rec.record_property("physics.RaycastHit", { "fraction", "number" });
}
'''
        f = tmp_path / "test_recorder.cpp"
        f.write_text(content)
        return f

    def test_detects_new_usertype(self, cpp_new_usertype: Path) -> None:
        """Detects lua.new_usertype patterns."""
        usertypes, functions, constants, enums, methods, properties, unrecognized = extract_from_file(
            cpp_new_usertype, "test"
        )

        assert len(usertypes) == 2
        names = {u.lua_name for u in usertypes}
        assert "Player" in names
        assert "Enemy" in names

        # Check confidence
        for u in usertypes:
            assert u.extraction_confidence == CONFIDENCE_HIGH

    def test_detects_set_function(self, cpp_set_function: Path) -> None:
        """Detects set_function patterns."""
        usertypes, functions, constants, enums, methods, properties, unrecognized = extract_from_file(
            cpp_set_function, "test"
        )

        assert len(functions) >= 2
        names = {f.lua_name for f in functions}
        assert "physics_table.raycast" in names or "raycast" in names

    def test_detects_enum(self, cpp_enum: Path) -> None:
        """Detects enum patterns."""
        usertypes, functions, constants, enums, methods, properties, unrecognized = extract_from_file(
            cpp_enum, "test"
        )

        assert len(enums) >= 1
        names = {e.lua_name for e in enums}
        assert "ActionResult" in names

    def test_detects_binding_recorder_function(self, cpp_binding_recorder: Path) -> None:
        """Detects BindingRecorder.bind_function patterns."""
        usertypes, functions, constants, enums, methods, properties, unrecognized = extract_from_file(
            cpp_binding_recorder, "test"
        )

        func_names = {f.lua_name for f in functions}
        assert "publishEvent" in func_names

    def test_detects_binding_recorder_usertype(self, cpp_binding_recorder: Path) -> None:
        """Detects BindingRecorder.bind_usertype patterns."""
        usertypes, functions, constants, enums, methods, properties, unrecognized = extract_from_file(
            cpp_binding_recorder, "test"
        )

        type_names = {u.lua_name for u in usertypes}
        assert "Entity" in type_names
        assert "physics.RaycastHit" in type_names

    def test_detects_record_method(self, cpp_binding_recorder: Path) -> None:
        """Detects record_method patterns."""
        usertypes, functions, constants, enums, methods, properties, unrecognized = extract_from_file(
            cpp_binding_recorder, "test"
        )

        method_names = {m.lua_name for m in methods}
        assert "physics.RaycastHit:getPoint" in method_names

    def test_detects_record_property(self, cpp_binding_recorder: Path) -> None:
        """Detects record_property patterns."""
        usertypes, functions, constants, enums, methods, properties, unrecognized = extract_from_file(
            cpp_binding_recorder, "test"
        )

        prop_names = {p.lua_name for p in properties}
        assert "physics.RaycastHit.fraction" in prop_names

    def test_source_ref_includes_line_number(self, cpp_new_usertype: Path) -> None:
        """Source references include file and line number."""
        usertypes, _, _, _, _, _, _ = extract_from_file(cpp_new_usertype, "test")

        assert len(usertypes) > 0
        for u in usertypes:
            assert ":" in u.source_ref
            parts = u.source_ref.rsplit(":", 1)
            assert parts[1].isdigit()


class TestConfidenceLevels:
    """Tests for extraction confidence assignment."""

    @pytest.fixture
    def cpp_mixed_confidence(self, tmp_path: Path) -> Path:
        """Create a fixture file with patterns of varying confidence."""
        content = '''
void setup(sol::state& lua) {
    // High confidence - direct lua.new_usertype
    lua.new_usertype<HighConfType>("HighConfType");

    // Medium confidence - indirect table
    sol::table custom = lua["custom"];
    custom.new_usertype<MedConfType>("MedConfType");
}
'''
        f = tmp_path / "test_confidence.cpp"
        f.write_text(content)
        return f

    def test_direct_binding_is_high_confidence(self, cpp_mixed_confidence: Path) -> None:
        """Direct lua.new_usertype gets high confidence."""
        usertypes, _, _, _, _, _, _ = extract_from_file(cpp_mixed_confidence, "test")

        high_conf = [u for u in usertypes if u.lua_name == "HighConfType"]
        assert len(high_conf) == 1
        assert high_conf[0].extraction_confidence == CONFIDENCE_HIGH


class TestLogOutput:
    """Tests for logging output format."""

    def test_extract_prefix_in_output(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        """Extraction output uses [EXTRACT] prefix."""
        content = '''
void setup(sol::state& lua) {
    lua.new_usertype<TestType>("TestType");
}
'''
        f = tmp_path / "test.cpp"
        f.write_text(content)

        extract_from_file(f, "test")
        captured = capsys.readouterr()

        assert "[EXTRACT]" in captured.out


class TestSchemaValidation:
    """Smoke tests for output schema validity."""

    def test_inventory_json_is_valid(self) -> None:
        """SystemInventory.to_dict produces valid JSON."""
        inv = SystemInventory(system_name="test")
        inv.usertypes.append(
            BindingRecord(
                lua_name="Test",
                binding_type="usertype",
                doc_id="test",
                source_ref="t:1",
            )
        )

        d = inv.to_dict()
        # Should be JSON serializable
        json_str = json.dumps(d)
        assert json_str

        # Should have required fields
        parsed = json.loads(json_str)
        assert "schema_version" in parsed
        assert "system" in parsed
        assert "bindings" in parsed
        assert "usertypes" in parsed["bindings"]
