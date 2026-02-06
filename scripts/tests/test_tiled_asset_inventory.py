"""Unit tests for scripts/tiled_asset_inventory.py."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import tiled_asset_inventory as tai


def _write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def _make_file(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"")


def test_descriptor_from_stem_parses_prefixed_name() -> None:
    assert tai.descriptor_from_stem("dm_129_wall_brick") == "wall_brick"
    assert tai.descriptor_from_stem("d437_089_upper_Y") == "upper_Y"
    assert tai.descriptor_from_stem("no_prefix_name") == "no_prefix_name"


def test_build_manifest_categorizes_and_detects_uncategorized(tmp_path: Path) -> None:
    root = tmp_path / "project"
    a_dir = root / "assets" / "a"
    b_dir = root / "assets" / "b"

    _make_file(a_dir / "dm_001_wall_stone.png")
    _make_file(a_dir / "dm_002_floor_stone.png")
    _make_file(b_dir / "d437_003_upper_A.png")
    _make_file(b_dir / "d437_004_unknown_blob.png")

    cfg_path = root / "rules.json"
    _write(
        cfg_path,
        json.dumps(
            {
                "categories": ["walls", "floors", "ui_symbols"],
                "extensions": [".png"],
                "sources": [
                    {"name": "a", "path": "assets/a", "expected_count": 2},
                    {"name": "b", "path": "assets/b", "expected_count": 2},
                ],
                "rules": [
                    {"category": "walls", "pattern": "^wall_"},
                    {"category": "floors", "pattern": "^floor_"},
                    {"category": "ui_symbols", "pattern": "^upper_"},
                ],
            }
        ),
    )

    config = tai.load_config(cfg_path, root)
    manifest = tai.build_manifest(config, root)

    assert manifest["total_files"] == 4
    assert manifest["categorized_files"] == 3
    assert manifest["uncategorized_count"] == 1
    assert "assets/b/d437_004_unknown_blob.png" in manifest["uncategorized_files"]
    assert manifest["category_counts"]["walls"] == 1
    assert manifest["category_counts"]["floors"] == 1
    assert manifest["category_counts"]["ui_symbols"] == 1


def test_validate_manifest_fails_on_uncategorized() -> None:
    manifest = {
        "total_files": 5,
        "categorized_files": 4,
        "uncategorized_count": 1,
        "source_errors": [],
    }
    errors = tai.validate_manifest(manifest, fail_on_uncategorized=True)
    assert any("uncategorized" in e for e in errors)

    no_fail_errors = tai.validate_manifest(manifest, fail_on_uncategorized=False)
    assert all("uncategorized" not in e for e in no_fail_errors)


def test_cli_writes_manifest_and_exits_nonzero_on_uncategorized(tmp_path: Path) -> None:
    root = tmp_path / "project"
    src = root / "assets" / "set"
    _make_file(src / "dm_001_wall_stone.png")
    _make_file(src / "dm_002_missing.png")

    cfg_path = root / "rules.json"
    out_path = root / "manifest.json"
    _write(
        cfg_path,
        json.dumps(
            {
                "categories": ["walls"],
                "extensions": [".png"],
                "sources": [{"name": "set", "path": "assets/set", "expected_count": 2}],
                "rules": [{"category": "walls", "pattern": "^wall_"}],
            }
        ),
    )

    script_path = Path(__file__).resolve().parents[1] / "tiled_asset_inventory.py"
    result = subprocess.run(
        [
            sys.executable,
            str(script_path),
            "--project-root",
            str(root),
            "--config",
            str(cfg_path),
            "--output",
            str(out_path),
        ],
        text=True,
        capture_output=True,
        check=False,
    )

    assert result.returncode == 1
    assert out_path.exists()

    manifest = json.loads(out_path.read_text(encoding="utf-8"))
    assert manifest["uncategorized_count"] == 1

