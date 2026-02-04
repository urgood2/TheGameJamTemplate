import io
import unittest
from pathlib import Path
import sys

PROJECT_ROOT = Path(__file__).resolve().parents[2]
SCRIPTS_DIR = PROJECT_ROOT / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

import select_tests


class TestSelectTests(unittest.TestCase):
    def test_glob_matching_selects_expected_categories_tags(self):
        impact_map = {
            "default": {"categories": ["smoke"], "tags": []},
            "impact_rules": [
                {
                    "name": "physics",
                    "globs": ["src/systems/physics/**"],
                    "filters": {"categories": ["physics"], "tags": ["physics"]},
                },
                {
                    "name": "ui_system",
                    "globs": ["assets/scripts/ui/**"],
                    "filters": {"categories": ["ui"], "tags": ["ui", "visual"]},
                },
            ],
        }
        changed_files = [
            "src/systems/physics/collision.cpp",
            "assets/scripts/ui/panel.lua",
        ]
        categories, tags, skip_tests = select_tests.match_rules(
            changed_files, impact_map
        )
        self.assertFalse(skip_tests)
        self.assertIn("physics", categories)
        self.assertIn("ui", categories)
        self.assertIn("smoke", categories)
        self.assertIn("physics", tags)
        self.assertIn("ui", tags)
        self.assertIn("visual", tags)

    def test_default_smoke_included_when_no_matches(self):
        impact_map = {"impact_rules": []}
        categories, tags, skip_tests = select_tests.match_rules([], impact_map)
        self.assertFalse(skip_tests)
        self.assertIn("smoke", categories)
        self.assertEqual(set(), tags)

    def test_wildcard_category_behavior(self):
        impact_map = {
            "default": {"categories": ["smoke"], "tags": []},
            "impact_rules": [
                {
                    "name": "all",
                    "globs": ["scripts/test_*.py"],
                    "filters": {"categories": ["*"], "tags": []},
                }
            ],
        }
        categories, tags, skip_tests = select_tests.match_rules(
            ["scripts/test_copy_assets.py"], impact_map
        )
        self.assertIn("*", categories)
        args = select_tests.format_runner_args(categories, tags, skip_tests=skip_tests)
        self.assertEqual("--all-categories", args)

    def test_skip_tests_yields_validators_only_args(self):
        impact_map = {
            "default": {"categories": ["smoke"], "tags": []},
            "impact_rules": [
                {
                    "name": "docs",
                    "globs": ["docs/**"],
                    "filters": {"categories": [], "tags": ["validation"]},
                    "skip_tests": True,
                }
            ],
        }
        categories, tags, skip_tests = select_tests.match_rules(
            ["docs/readme.md"], impact_map
        )
        args = select_tests.format_runner_args(categories, tags, skip_tests=skip_tests)
        self.assertEqual("--skip-tests --validators-only", args)

    def test_nightly_mode_args_deterministic(self):
        impact_map = {
            "nightly": {
                "categories": ["*"],
                "tags": ["*"],
                "include_slow": True,
                "include_visual": True,
            }
        }
        stream = io.StringIO()
        args = select_tests.select_nightly(impact_map, stream)
        self.assertEqual("--all-categories --include-slow --include-visual", args)

    def test_logging_prefixes_stable(self):
        impact_map = {"default": {"categories": ["smoke"], "tags": []}}
        stream = io.StringIO()
        args = select_tests.select_tests([], impact_map, "origin/main", stream)
        output_lines = stream.getvalue().splitlines()
        self.assertGreater(len(output_lines), 0)
        for line in output_lines[:-1]:
            if line.strip():
                self.assertTrue(line.startswith("[SELECT]"))
        self.assertEqual("--categories=smoke", args)
        self.assertEqual(args, output_lines[-1])


if __name__ == "__main__":
    unittest.main()
