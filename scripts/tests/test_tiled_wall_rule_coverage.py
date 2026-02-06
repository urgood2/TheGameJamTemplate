"""Unit tests for scripts/tiled_wall_rule_coverage.py."""

from __future__ import annotations

import json
from pathlib import Path

import tiled_wall_rule_coverage as twrc


def _write_json(path: Path, obj: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, indent=2), encoding="utf-8")


def test_infer_exclusion_reason_is_specific_for_known_patterns() -> None:
    assert "Lighting/shade" in twrc.infer_exclusion_reason("assets/d437_176_shade_light.png")
    assert "Partial block wall" in twrc.infer_exclusion_reason("assets/d437_220_block_lower.png")
    assert "Bridge tile" in twrc.infer_exclusion_reason("assets/dm_136_bridge.png")
    assert "Standalone wall motif" in twrc.infer_exclusion_reason("assets/dm_129_wall_brick.png")


def test_build_coverage_report_accounts_all_manifest_assets(tmp_path: Path) -> None:
    project = tmp_path / "project"
    manifest_path = project / "planning" / "manifest.json"
    rulesets_dir = project / "planning" / "rulesets"

    _write_json(
        manifest_path,
        {
            "category_files": {
                "walls": [
                    "assets/a_wall.png",
                    "assets/b_shade.png",
                ]
            }
        },
    )

    _write_json(
        rulesets_dir / "demo_walls.runtime.json",
        {
            "ruleset": "demo",
            "source_assets": ["assets/a_wall.png"],
            "rules": [],
        },
    )

    walls = twrc.load_manifest_walls(manifest_path, project)
    rulesets = twrc.discover_runtime_rulesets(rulesets_dir, project)
    report = twrc.build_coverage_report(
        manifest_walls=walls,
        rulesets=rulesets,
        project_root=project,
        manifest_path=manifest_path,
        rulesets_dir=rulesets_dir,
    )

    assert report["total_wall_assets"] == 2
    assert report["mapped_count"] == 1
    assert report["excluded_count"] == 1
    assert report["uncovered_count"] == 0
    assert report["unknown_mapped_count"] == 0
    assert twrc.validate_coverage_report(report) == []


def test_validate_coverage_report_fails_on_unknown_mapped_assets(tmp_path: Path) -> None:
    project = tmp_path / "project"
    manifest_path = project / "planning" / "manifest.json"
    rulesets_dir = project / "planning" / "rulesets"

    _write_json(
        manifest_path,
        {
            "category_files": {
                "walls": [
                    "assets/a_wall.png",
                ]
            }
        },
    )

    _write_json(
        rulesets_dir / "demo_walls.runtime.json",
        {
            "ruleset": "demo",
            "source_assets": ["assets/missing_not_in_manifest.png"],
            "rules": [],
        },
    )

    walls = twrc.load_manifest_walls(manifest_path, project)
    rulesets = twrc.discover_runtime_rulesets(rulesets_dir, project)
    report = twrc.build_coverage_report(
        manifest_walls=walls,
        rulesets=rulesets,
        project_root=project,
        manifest_path=manifest_path,
        rulesets_dir=rulesets_dir,
    )

    errors = twrc.validate_coverage_report(report)
    assert any("not present in manifest" in error for error in errors)


def test_project_wall_coverage_report_validates() -> None:
    project_root = Path(__file__).resolve().parents[2]
    manifest_path = project_root / "planning" / "tiled_assets" / "required_asset_manifest.json"
    rulesets_dir = project_root / "planning" / "tiled_assets" / "rulesets"

    walls = twrc.load_manifest_walls(manifest_path, project_root)
    rulesets = twrc.discover_runtime_rulesets(rulesets_dir, project_root)
    report = twrc.build_coverage_report(
        manifest_walls=walls,
        rulesets=rulesets,
        project_root=project_root,
        manifest_path=manifest_path,
        rulesets_dir=rulesets_dir,
    )

    errors = twrc.validate_coverage_report(report)
    assert errors == []
    assert report["total_wall_assets"] > 0
    assert report["mapped_count"] > 0
