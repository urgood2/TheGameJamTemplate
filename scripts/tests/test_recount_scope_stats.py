"""Unit tests for recount_scope_stats.py.

Tests cover:
- Counts are correct for small fixture trees
- Parser handles empty/unknown categories
- Output matches schema-required fields
- Logging includes stable [STATS] prefixes
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from textwrap import dedent

import pytest

# Add scripts to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from recount_scope_stats import (
    LOG_PREFIX,
    SCHEMA_VERSION,
    ComponentStats,
    LuaStats,
    ScopeStats,
    Sol2BindingStats,
    Sol2Stats,
    categorize_component,
    count_sol2_bindings,
    generate_markdown,
    run_scan,
    scan_all_component_files,
    scan_components,
    scan_lua_scripts,
    scan_sol2_bindings,
    stats_to_dict,
)


class TestLogPrefix:
    """Test logging format requirements."""

    def test_log_prefix_stable(self) -> None:
        """Log prefix is stable and parseable."""
        assert LOG_PREFIX == "[STATS]"

    def test_schema_version_stable(self) -> None:
        """Schema version is defined."""
        assert SCHEMA_VERSION == "1.0"


class TestSol2BindingStats:
    """Test Sol2 binding statistics."""

    def test_default_values(self) -> None:
        """Stats dataclass has sensible defaults."""
        stats = Sol2BindingStats(file="test.cpp")
        assert stats.file == "test.cpp"
        assert stats.types == 0
        assert stats.functions == 0
        assert stats.constants == 0


class TestComponentCategorization:
    """Test component categorization logic."""

    @pytest.mark.parametrize(
        "name,expected_category",
        [
            ("GOAPComponent", "AI"),
            ("BlackboardComponent", "AI"),
            ("TileComponent", "Core"),
            ("LocationComponent", "Core"),
            ("SpriteComponent", "Graphics"),
            ("NinePatchComponent", "Graphics"),
            ("VFXTag", "Graphics"),
            ("PhysicsBody", "Physics"),
            ("CollisionMask", "Physics"),
            ("UIBoxComponent", "UI"),
            ("ButtonComponent", "UI"),
            ("HealthComponent", "Combat"),
            ("DamageModifier", "Combat"),
            ("StateTag", "State"),
            ("AnimationComponent", "Animation"),
            ("SoundComponent", "Audio"),
            ("ScriptComponent", "Scripting"),
            ("ParticleEmitter", "Particles"),
            ("TransformComponent", "Transform"),
            ("TimerComponent", "Timer"),
            ("ContainerComponent", "Inventory"),
            ("InfoComponent", "Metadata"),
            ("UnknownComponent", "Other"),
        ],
    )
    def test_categorization(self, name: str, expected_category: str) -> None:
        """Component names categorize correctly."""
        assert categorize_component(name) == expected_category


class TestCountSol2Bindings:
    """Test Sol2 binding counting."""

    def test_file_without_bindings(self, tmp_path: Path) -> None:
        """Files without bindings return None."""
        cpp_file = tmp_path / "no_bindings.cpp"
        cpp_file.write_text("int main() { return 0; }")

        result = count_sol2_bindings(cpp_file)
        assert result is None

    def test_file_with_usertype(self, tmp_path: Path) -> None:
        """Files with usertypes are counted."""
        cpp_file = tmp_path / "has_bindings.cpp"
        cpp_file.write_text(dedent("""
            #include "sol/sol.hpp"

            void bind(sol::state& lua) {
                lua.new_usertype<MyType>("MyType",
                    "x", &MyType::x
                );
                lua.new_usertype<OtherType>("OtherType");
            }
        """))

        result = count_sol2_bindings(cpp_file)
        assert result is not None
        assert result.types == 2

    def test_file_with_functions(self, tmp_path: Path) -> None:
        """Files with function bindings are counted."""
        cpp_file = tmp_path / "functions.cpp"
        cpp_file.write_text(dedent("""
            #include "sol/sol.hpp"

            void bind(sol::state& lua) {
                rec.add_function("myFunc");
                lua["globalFunc"] = some_func;
            }
        """))

        result = count_sol2_bindings(cpp_file)
        assert result is not None
        assert result.functions >= 2


class TestScanSol2Bindings:
    """Test scanning directory for Sol2 bindings."""

    def test_empty_directory(self, tmp_path: Path) -> None:
        """Empty directory returns empty stats."""
        stats = scan_sol2_bindings(tmp_path)
        assert stats.total_types == 0
        assert stats.total_functions == 0
        assert len(stats.by_file) == 0

    def test_nonexistent_directory(self, tmp_path: Path) -> None:
        """Nonexistent directory returns empty stats."""
        stats = scan_sol2_bindings(tmp_path / "nonexistent")
        assert stats.total_types == 0
        assert len(stats.by_file) == 0

    def test_directory_with_bindings(self, tmp_path: Path) -> None:
        """Directory with bindings aggregates correctly."""
        # Create files with bindings
        f1 = tmp_path / "bindings1.cpp"
        f1.write_text(dedent("""
            #include "sol/sol.hpp"
            void bind(sol::state& lua) {
                lua.new_usertype<A>("A");
            }
        """))

        f2 = tmp_path / "bindings2.cpp"
        f2.write_text(dedent("""
            #include "sol/sol.hpp"
            void bind(sol::state& lua) {
                lua.new_usertype<B>("B");
                lua.new_usertype<C>("C");
            }
        """))

        stats = scan_sol2_bindings(tmp_path)
        assert stats.total_types == 3
        assert len(stats.by_file) == 2


class TestScanComponents:
    """Test component scanning."""

    def test_empty_file(self, tmp_path: Path) -> None:
        """Empty file returns zero components."""
        hpp = tmp_path / "empty.hpp"
        hpp.write_text("#pragma once\n")

        stats = scan_components(hpp)
        assert stats.total == 0

    def test_file_with_structs(self, tmp_path: Path) -> None:
        """File with structs is parsed correctly."""
        hpp = tmp_path / "components.hpp"
        hpp.write_text(dedent("""
            #pragma once

            struct HealthComponent {
                int hp;
            };

            struct TransformComponent {
                float x, y;
            };

            struct VFXTag {};
        """))

        stats = scan_components(hpp)
        assert stats.total == 3
        assert "Combat" in stats.by_category  # HealthComponent
        assert "Transform" in stats.by_category  # TransformComponent
        assert "Graphics" in stats.by_category  # VFXTag

    def test_nonexistent_file(self, tmp_path: Path) -> None:
        """Nonexistent file returns empty stats."""
        stats = scan_components(tmp_path / "nonexistent.hpp")
        assert stats.total == 0


class TestScanLuaScripts:
    """Test Lua script scanning."""

    def test_empty_directory(self, tmp_path: Path) -> None:
        """Empty directory returns zero scripts."""
        stats = scan_lua_scripts(tmp_path)
        assert stats.total == 0
        assert len(stats.by_directory) == 0

    def test_directory_with_scripts(self, tmp_path: Path) -> None:
        """Directory with scripts is counted correctly."""
        # Create directory structure
        (tmp_path / "core").mkdir()
        (tmp_path / "ui").mkdir()

        (tmp_path / "core" / "a.lua").write_text("-- lua")
        (tmp_path / "core" / "b.lua").write_text("-- lua")
        (tmp_path / "ui" / "c.lua").write_text("-- lua")
        (tmp_path / "root.lua").write_text("-- lua")

        stats = scan_lua_scripts(tmp_path)
        assert stats.total == 4
        assert stats.by_directory.get("core/", 0) == 2
        assert stats.by_directory.get("ui/", 0) == 1
        assert stats.by_directory.get("root", 0) == 1


class TestStatsToDict:
    """Test JSON serialization."""

    def test_dict_has_required_fields(self) -> None:
        """Output dict has all required schema fields."""
        stats = ScopeStats(
            sol2_bindings=Sol2Stats(
                total_types=5,
                total_functions=10,
                by_file=[Sol2BindingStats("test.cpp", 5, 10)],
            ),
            ecs_components=ComponentStats(
                total=20,
                by_category={"Core": 5, "Graphics": 15},
            ),
            lua_scripts=LuaStats(
                total=100,
                by_directory={"core/": 50, "ui/": 50},
            ),
        )

        d = stats_to_dict(stats)

        # Required top-level fields
        assert "schema_version" in d
        assert "generated_at" in d
        assert "sol2_bindings" in d
        assert "ecs_components" in d
        assert "lua_scripts" in d

        # Sol2 structure
        assert "total_types" in d["sol2_bindings"]
        assert "total_functions" in d["sol2_bindings"]
        assert "by_file" in d["sol2_bindings"]

        # Components structure
        assert "total" in d["ecs_components"]
        assert "by_category" in d["ecs_components"]

        # Lua structure
        assert "total" in d["lua_scripts"]
        assert "by_directory" in d["lua_scripts"]

    def test_json_serializable(self) -> None:
        """Output can be serialized to JSON."""
        stats = ScopeStats()
        d = stats_to_dict(stats)

        # Should not raise
        json_str = json.dumps(d)
        assert json_str

        # Should be valid JSON
        parsed = json.loads(json_str)
        assert parsed["schema_version"] == SCHEMA_VERSION


class TestGenerateMarkdown:
    """Test markdown generation."""

    def test_markdown_has_sections(self) -> None:
        """Markdown contains all required sections."""
        stats = ScopeStats(
            sol2_bindings=Sol2Stats(total_types=5, total_functions=10),
            ecs_components=ComponentStats(total=20, by_category={"Core": 20}),
            lua_scripts=LuaStats(total=100, by_directory={"core/": 100}),
        )

        md = generate_markdown(stats)

        assert "# Codebase Statistics" in md
        assert "## Sol2 Bindings" in md
        assert "## ECS Components" in md
        assert "## Lua Scripts" in md

    def test_markdown_has_tables(self) -> None:
        """Markdown contains properly formatted tables."""
        stats = ScopeStats(
            sol2_bindings=Sol2Stats(
                total_types=5,
                total_functions=10,
                by_file=[Sol2BindingStats("test.cpp", 5, 10)],
            ),
            ecs_components=ComponentStats(total=20, by_category={"Core": 20}),
            lua_scripts=LuaStats(total=100, by_directory={"core/": 100}),
        )

        md = generate_markdown(stats)

        # Table headers
        assert "| File | Types | Functions |" in md
        assert "| Category | Count |" in md
        assert "| Directory | Count |" in md

        # Data rows
        assert "| test.cpp |" in md
        assert "| Core |" in md
        assert "| core/ |" in md


class TestRunScan:
    """Test full scan integration."""

    def test_run_scan_nonexistent_dirs(self, tmp_path: Path) -> None:
        """Scan handles nonexistent directories gracefully."""
        stats = run_scan(
            tmp_path / "nonexistent_src",
            tmp_path / "nonexistent_scripts",
            verbose=False,
        )

        assert stats.sol2_bindings.total_types == 0
        assert stats.ecs_components.total == 0
        assert stats.lua_scripts.total == 0

    def test_run_scan_with_fixture(self, tmp_path: Path) -> None:
        """Scan works with fixture directory structure."""
        # Create minimal fixture
        src_dir = tmp_path / "src"
        src_dir.mkdir()
        components_dir = src_dir / "components"
        components_dir.mkdir()

        scripts_dir = tmp_path / "assets" / "scripts"
        scripts_dir.mkdir(parents=True)

        # Add a component file
        (components_dir / "components.hpp").write_text(dedent("""
            struct TestComponent { int x; };
        """))

        # Add a lua script
        (scripts_dir / "test.lua").write_text("-- test")

        stats = run_scan(src_dir, scripts_dir, verbose=False)

        assert stats.ecs_components.total >= 1
        assert stats.lua_scripts.total >= 1


class TestEdgeCases:
    """Test edge cases and error handling."""

    def test_empty_struct_body(self, tmp_path: Path) -> None:
        """Empty struct (tag component) is counted."""
        hpp = tmp_path / "tags.hpp"
        hpp.write_text(dedent("""
            struct EmptyTag {};
            struct AnotherTag { };
        """))

        stats = scan_components(hpp)
        assert stats.total == 2

    def test_nested_braces_in_struct(self, tmp_path: Path) -> None:
        """Struct with nested braces is handled."""
        hpp = tmp_path / "nested.hpp"
        hpp.write_text(dedent("""
            struct ComplexComponent {
                std::map<std::string, int> data{{"a", 1}};
                struct Inner { int x; } inner;
            };
        """))

        stats = scan_components(hpp)
        # Should find at least ComplexComponent (Inner might also be found)
        assert stats.total >= 1

    def test_unknown_category_falls_back(self) -> None:
        """Unknown component names categorize as Other."""
        assert categorize_component("XyzAbc123") == "Other"
        assert categorize_component("") == "Other"
