#!/usr/bin/env python3
"""Generate Tiled wall rulesets catalog and showcase demo map.

This script inspects wall assets from the required manifest and produces:
- Canonical wall autotile runtime rulesets for dungeon_mode and dungeon_437
- Single-tile fill rulesets for every wall asset (complete coverage)
- Ruleset catalog JSON for programmatic loading
- A showcase Tiled map + tileset files built from those assets
"""

from __future__ import annotations

import argparse
import json
import os
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any

try:
    from PIL import Image
except Exception:  # pragma: no cover - optional dependency guard
    Image = None


DEFAULT_MANIFEST = Path("planning/tiled_assets/required_asset_manifest.json")
DEFAULT_RULESETS_DIR = Path("planning/tiled_assets/rulesets")
DEFAULT_GENERATED_RULESETS_DIR = DEFAULT_RULESETS_DIR / "generated"
DEFAULT_CATALOG = DEFAULT_RULESETS_DIR / "wall_rules_catalog.json"
DEFAULT_DEMO_MAP_DIR = Path("assets/maps/tiled_demo")

FILENAME_RE = re.compile(
    r"^(?P<prefix>[A-Za-z0-9]+)_(?P<index>\d{3})_(?P<desc>.+)\.png$"
)


@dataclass(frozen=True)
class WallAsset:
    path: str
    source: str
    prefix: str
    tile_id: int
    desc: str
    stem: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate full wall ruleset coverage and tiled showcase map."
    )
    parser.add_argument("--project-root", type=Path, default=Path.cwd())
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--rulesets-dir", type=Path, default=DEFAULT_RULESETS_DIR)
    parser.add_argument(
        "--generated-rulesets-dir", type=Path, default=DEFAULT_GENERATED_RULESETS_DIR
    )
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG)
    parser.add_argument("--demo-map-dir", type=Path, default=DEFAULT_DEMO_MAP_DIR)
    parser.add_argument("--check-only", action="store_true")
    return parser.parse_args()


def _resolve(root: Path, path_like: Path) -> Path:
    p = Path(path_like)
    if not p.is_absolute():
        p = (root / p).resolve()
    return p


def _rel(root: Path, path: Path) -> str:
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except Exception:
        return path.resolve().as_posix()


def load_manifest_walls(manifest_path: Path) -> list[str]:
    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    category_files = data.get("category_files", {})
    walls = category_files.get("walls", [])
    if not isinstance(walls, list) or not walls:
        raise ValueError("Manifest must include non-empty category_files.walls")
    out: list[str] = []
    for item in walls:
        if not isinstance(item, str) or not item.strip():
            raise ValueError("Wall entries must be non-empty strings")
        out.append(item.strip())
    return sorted(set(out))


def parse_wall_asset(path_text: str) -> WallAsset:
    p = Path(path_text)
    filename = p.name
    m = FILENAME_RE.match(filename)
    if m is None:
        raise ValueError(f"Wall asset filename does not match expected format: {path_text}")
    source = p.parent.name
    if source not in {"dungeon_mode", "dungeon_437"}:
        raise ValueError(f"Unsupported wall source folder '{source}' in: {path_text}")
    return WallAsset(
        path=path_text,
        source=source,
        prefix=m.group("prefix"),
        tile_id=int(m.group("index")),
        desc=m.group("desc"),
        stem=p.stem,
    )


def index_assets_by_desc(assets: list[WallAsset]) -> dict[str, dict[str, WallAsset]]:
    out: dict[str, dict[str, WallAsset]] = {"dungeon_mode": {}, "dungeon_437": {}}
    for asset in assets:
        out[asset.source][asset.desc] = asset
    return out


def write_json(path: Path, payload: dict[str, Any], check_only: bool) -> None:
    if check_only:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def write_text(path: Path, text: str, check_only: bool) -> None:
    if check_only:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def tile_spec(asset: WallAsset, **kwargs: Any) -> dict[str, Any]:
    spec: dict[str, Any] = {"id": asset.tile_id}
    for k, v in kwargs.items():
        if v:
            spec[k] = v
    return spec


def canonical_rulesets_by_source(
    by_desc: dict[str, dict[str, WallAsset]]
) -> dict[str, dict[str, Any]]:
    dm = by_desc["dungeon_mode"]
    d4 = by_desc["dungeon_437"]

    required_dm = [
        "box_corner_bl",
        "box_corner_br",
        "box_horizontal",
        "box_cross",
        "block_full",
        "shade_heavy",
    ]
    # The dungeon_mode naming around 240-250 is not a direct geometric legend;
    # use connectivity-derived canonical pieces with rotation:
    # - box_corner_bl (dm_242): straight piece (E-W) when unrotated
    # - box_corner_br (dm_243): corner (N-E) when unrotated
    # - box_horizontal (dm_244): tee (N-E-W) when unrotated
    # - box_cross (dm_250): 4-way
    # - block_full (dm_254): end-cap (N) when unrotated
    # - shade_heavy (dm_253): isolated (0 neighbors)
    for key in required_dm:
        if key not in dm:
            raise ValueError(f"dungeon_mode canonical rules missing descriptor: {key}")

    dm_straight = dm["box_corner_bl"]
    dm_corner = dm["box_corner_br"]
    dm_tee = dm["box_horizontal"]
    dm_cross = dm["box_cross"]
    dm_end = dm["block_full"]
    dm_isolated = dm["shade_heavy"]

    dm_rules = [
        {"name": "cross", "terrain": 1, "exact_mask": 15, "tile": tile_spec(dm_cross)},
        {"name": "t_down", "terrain": 1, "exact_mask": 14, "tile": tile_spec(dm_tee, rotation=180)},
        {"name": "t_up", "terrain": 1, "exact_mask": 11, "tile": tile_spec(dm_tee)},
        {"name": "t_right", "terrain": 1, "exact_mask": 7, "tile": tile_spec(dm_tee, rotation=90)},
        {"name": "t_left", "terrain": 1, "exact_mask": 13, "tile": tile_spec(dm_tee, rotation=270)},
        {"name": "vertical", "terrain": 1, "exact_mask": 5, "tile": tile_spec(dm_straight, rotation=90)},
        {"name": "horizontal", "terrain": 1, "exact_mask": 10, "tile": tile_spec(dm_straight)},
        {"name": "corner_tl", "terrain": 1, "exact_mask": 6, "tile": tile_spec(dm_corner, rotation=90)},
        {"name": "corner_tr", "terrain": 1, "exact_mask": 12, "tile": tile_spec(dm_corner, rotation=180)},
        {"name": "corner_bl", "terrain": 1, "exact_mask": 3, "tile": tile_spec(dm_corner)},
        {"name": "corner_br", "terrain": 1, "exact_mask": 9, "tile": tile_spec(dm_corner, rotation=270)},
        {"name": "end_north", "terrain": 1, "exact_mask": 1, "tile": tile_spec(dm_end)},
        {"name": "end_east", "terrain": 1, "exact_mask": 2, "tile": tile_spec(dm_end, rotation=90)},
        {"name": "end_south", "terrain": 1, "exact_mask": 4, "tile": tile_spec(dm_end, rotation=180)},
        {"name": "end_west", "terrain": 1, "exact_mask": 8, "tile": tile_spec(dm_end, rotation=270)},
        {"name": "isolated", "terrain": 1, "exact_mask": 0, "tile": tile_spec(dm_isolated)},
    ]

    required_d4 = [
        "box_cross",
        "box_vert",
        "box_horiz",
        "corner_tl",
        "corner_tr",
        "block_full",
    ]
    for key in required_d4:
        if key not in d4:
            raise ValueError(f"dungeon_437 canonical rules missing descriptor: {key}")

    d4_rules = [
        {"name": "cross", "terrain": 1, "exact_mask": 15, "tile": tile_spec(d4["box_cross"])},
        {"name": "t_down", "terrain": 1, "exact_mask": 14, "tile": tile_spec(d4["box_cross"])},
        {"name": "t_up", "terrain": 1, "exact_mask": 11, "tile": tile_spec(d4["box_cross"])},
        {"name": "t_right", "terrain": 1, "exact_mask": 7, "tile": tile_spec(d4["box_cross"])},
        {"name": "t_left", "terrain": 1, "exact_mask": 13, "tile": tile_spec(d4["box_cross"])},
        {"name": "vertical", "terrain": 1, "exact_mask": 5, "tile": tile_spec(d4["box_vert"])},
        {"name": "horizontal", "terrain": 1, "exact_mask": 10, "tile": tile_spec(d4["box_horiz"])},
        {"name": "corner_tl", "terrain": 1, "exact_mask": 6, "tile": tile_spec(d4["corner_tl"])},
        {"name": "corner_tr", "terrain": 1, "exact_mask": 12, "tile": tile_spec(d4["corner_tr"])},
        {"name": "corner_bl", "terrain": 1, "exact_mask": 3, "tile": tile_spec(d4["corner_tl"], flip_y=True)},
        {"name": "corner_br", "terrain": 1, "exact_mask": 9, "tile": tile_spec(d4["corner_tr"], flip_y=True)},
        {"name": "end_north", "terrain": 1, "exact_mask": 1, "tile": tile_spec(d4["box_vert"])},
        {"name": "end_east", "terrain": 1, "exact_mask": 2, "tile": tile_spec(d4["box_horiz"])},
        {"name": "end_south", "terrain": 1, "exact_mask": 4, "tile": tile_spec(d4["box_vert"])},
        {"name": "end_west", "terrain": 1, "exact_mask": 8, "tile": tile_spec(d4["box_horiz"])},
        {"name": "isolated", "terrain": 1, "exact_mask": 0, "tile": tile_spec(d4["block_full"])},
    ]

    return {
        "dungeon_mode_walls": {
            "schema_version": "1.0",
            "ruleset": "dungeon_mode_walls",
            "description": (
                "Cardinal-neighbor autotile mapping for dungeon_mode wall set "
                "(connectivity-derived canonical pieces + rotation)."
            ),
            "default_terrain": 1,
            "mask_bits": {"north": 1, "east": 2, "south": 4, "west": 8},
            "rules": dm_rules,
            "source_assets": sorted(
                {
                    dm_straight.path,
                    dm_corner.path,
                    dm_tee.path,
                    dm_cross.path,
                    dm_end.path,
                    dm_isolated.path,
                }
            ),
        },
        "dungeon_437_walls": {
            "schema_version": "1.0",
            "ruleset": "dungeon_437_walls",
            "description": "Cardinal-neighbor autotile mapping for dungeon_437 wall glyph set.",
            "default_terrain": 1,
            "mask_bits": {"north": 1, "east": 2, "south": 4, "west": 8},
            "rules": d4_rules,
            "source_assets": sorted(
                {
                    d4["corner_tl"].path,
                    d4["corner_tr"].path,
                    d4["box_vert"].path,
                    d4["box_horiz"].path,
                    d4["box_cross"].path,
                    d4["block_full"].path,
                }
            ),
        },
    }


def build_fill_runtime(asset: WallAsset) -> dict[str, Any]:
    rules: list[dict[str, Any]] = []
    for mask in range(16):
        rules.append(
            {
                "name": f"fill_mask_{mask:02d}",
                "terrain": 1,
                "exact_mask": mask,
                "tile": {"id": asset.tile_id},
            }
        )
    return {
        "schema_version": "1.0",
        "ruleset": f"{asset.source}_{asset.stem}_fill",
        "description": f"Single-tile fill autotile ruleset generated for {asset.path}.",
        "default_terrain": 1,
        "mask_bits": {"north": 1, "east": 2, "south": 4, "west": 8},
        "rules": rules,
        "source_assets": [asset.path],
    }


def load_image_size(path: Path) -> tuple[int, int]:
    if Image is None:
        return 8, 8
    with Image.open(path) as img:
        return int(img.width), int(img.height)


def generate_rulesets(
    root: Path,
    rulesets_dir: Path,
    generated_rulesets_dir: Path,
    catalog_path: Path,
    assets: list[WallAsset],
    check_only: bool,
) -> dict[str, Any]:
    by_desc = index_assets_by_desc(assets)
    canonical = canonical_rulesets_by_source(by_desc)

    catalog_entries: list[dict[str, Any]] = []

    # Canonical primary rulesets (stable paths).
    for ruleset_id, runtime in canonical.items():
        runtime_path = rulesets_dir / f"{ruleset_id}.runtime.json"
        rules_path = rulesets_dir / f"{ruleset_id}.rules.txt"
        write_json(runtime_path, runtime, check_only)
        write_text(
            rules_path,
            "# Generated runtime wall autotile rules.\n"
            f"runtime_json = {runtime_path.name}\n",
            check_only,
        )
        catalog_entries.append(
            {
                "id": ruleset_id,
                "source": "dungeon_mode" if "mode" in ruleset_id else "dungeon_437",
                "mode": "canonical",
                "rules_path": _rel(root, rules_path),
                "runtime_path": _rel(root, runtime_path),
                "source_assets": runtime["source_assets"],
            }
        )

    # Full per-asset fill rulesets to ensure every wall asset has a programmatic autotile entrypoint.
    for asset in assets:
        ruleset_id = f"{asset.source}_{asset.stem}_fill"
        runtime_payload = build_fill_runtime(asset)
        runtime_path = generated_rulesets_dir / f"{ruleset_id}.runtime.json"
        rules_path = generated_rulesets_dir / f"{ruleset_id}.rules.txt"
        write_json(runtime_path, runtime_payload, check_only)
        write_text(
            rules_path,
            "# Generated single-tile fill wall autotile rules.\n"
            f"runtime_json = {runtime_path.name}\n",
            check_only,
        )
        catalog_entries.append(
            {
                "id": ruleset_id,
                "source": asset.source,
                "mode": "single_tile_fill",
                "asset": asset.path,
                "rules_path": _rel(root, rules_path),
                "runtime_path": _rel(root, runtime_path),
                "source_assets": [asset.path],
            }
        )

    catalog = {
        "schema_version": "1.0",
        "description": "Generated Tiled wall ruleset catalog (canonical + per-asset fill variants).",
        "total_rulesets": len(catalog_entries),
        "rulesets": catalog_entries,
    }
    write_json(catalog_path, catalog, check_only)
    return catalog


def _make_tile_layer(layer_id: int, name: str, width: int, height: int, data: list[int]) -> dict[str, Any]:
    return {
        "id": layer_id,
        "name": name,
        "type": "tilelayer",
        "visible": True,
        "opacity": 1.0,
        "width": width,
        "height": height,
        "x": 0,
        "y": 0,
        "data": data,
    }


def generate_demo_map(
    root: Path,
    demo_map_dir: Path,
    wall_assets: list[WallAsset],
    check_only: bool,
) -> dict[str, Any]:
    wall_asset_paths = [a.path for a in wall_assets]

    extras = [
        "assets/graphics/pre-packing-files_globbed/dungeon_mode/dm_192_floor_stone.png",
        "assets/graphics/pre-packing-files_globbed/dungeon_mode/dm_193_floor_wood.png",
        "assets/graphics/pre-packing-files_globbed/dungeon_mode/dm_194_floor_dirt.png",
        "assets/graphics/pre-packing-files_globbed/dungeon_mode/dm_195_floor_grass.png",
        "assets/graphics/pre-packing-files_globbed/dungeon_mode/dm_137_pillar.png",
        "assets/graphics/pre-packing-files_globbed/dungeon_mode/dm_138_arch.png",
        "assets/graphics/pre-packing-files_globbed/dungeon_mode/dm_208_torch_wall.png",
        "assets/graphics/pre-packing-files_globbed/dungeon_mode/dm_214_table.png",
        "assets/graphics/pre-packing-files_globbed/dungeon_mode/dm_215_chair.png",
        "assets/graphics/pre-packing-files_globbed/dungeon_mode/dm_144_hero_knight.png",
        "assets/graphics/pre-packing-files_globbed/dungeon_mode/dm_145_hero_mage.png",
        "assets/graphics/pre-packing-files_globbed/dungeon_mode/dm_146_hero_rogue.png",
        "assets/graphics/pre-packing-files_globbed/dungeon_mode/dm_147_hero_archer.png",
    ]
    all_assets: list[str] = []
    seen: set[str] = set()
    for p in wall_asset_paths + extras:
        if p not in seen:
            all_assets.append(p)
            seen.add(p)

    tile_size = 8
    width, height = 144, 96
    tile_count = width * height

    ground = [0] * tile_count
    walls_mode = [0] * tile_count
    walls_437 = [0] * tile_count
    props = [0] * tile_count
    wall_gallery_mode = [0] * tile_count
    wall_gallery_437 = [0] * tile_count

    gid_by_asset: dict[str, int] = {}
    tsj_dir = demo_map_dir / "tilesets"
    tilesets: list[dict[str, Any]] = []
    next_gid = 1

    for asset_path in all_assets:
        absolute_asset_path = _resolve(root, Path(asset_path))
        if not absolute_asset_path.exists():
            raise ValueError(f"Demo map asset missing: {asset_path}")
        stem = absolute_asset_path.stem
        tsj_name = f"{stem}.tsj"
        tsj_path = tsj_dir / tsj_name
        img_w, img_h = load_image_size(absolute_asset_path)
        relative_img = Path(os.path.relpath(absolute_asset_path, root)).as_posix()
        image_from_tsj = os.path.relpath(absolute_asset_path, tsj_path.parent).replace("\\", "/")
        tsj_payload = {
            "name": stem,
            "tilewidth": tile_size,
            "tileheight": tile_size,
            "tilecount": 1,
            "columns": 1,
            "image": image_from_tsj,
            "imagewidth": img_w,
            "imageheight": img_h,
            "properties": [
                {"name": "source_asset", "type": "string", "value": relative_img}
            ],
        }
        write_json(tsj_path, tsj_payload, check_only)

        gid_by_asset[asset_path] = next_gid
        tilesets.append({"firstgid": next_gid, "source": f"tilesets/{tsj_name}"})
        next_gid += 1

    def set_tile(layer: list[int], x: int, y: int, asset: str) -> None:
        if x < 0 or y < 0 or x >= width or y >= height:
            return
        layer[y * width + x] = gid_by_asset[asset]

    # Ground fill.
    floor_assets = extras[0:4]
    for y in range(height):
        for x in range(width):
            idx = (x // 12 + y // 8) % len(floor_assets)
            set_tile(ground, x, y, floor_assets[idx])

    # Canonical walls for dungeon_mode zone.
    dm = {
        "tl": "assets/graphics/pre-packing-files_globbed/dungeon_mode/dm_240_box_corner_tl.png",
        "tr": "assets/graphics/pre-packing-files_globbed/dungeon_mode/dm_241_box_corner_tr.png",
        "bl": "assets/graphics/pre-packing-files_globbed/dungeon_mode/dm_242_box_corner_bl.png",
        "br": "assets/graphics/pre-packing-files_globbed/dungeon_mode/dm_243_box_corner_br.png",
        "h": "assets/graphics/pre-packing-files_globbed/dungeon_mode/dm_244_box_horizontal.png",
        "v": "assets/graphics/pre-packing-files_globbed/dungeon_mode/dm_245_box_vertical.png",
        "cross": "assets/graphics/pre-packing-files_globbed/dungeon_mode/dm_250_box_cross.png",
    }

    left_x, left_y, left_w, left_h = 6, 6, 58, 38
    for x in range(left_x + 1, left_x + left_w - 1):
        set_tile(walls_mode, x, left_y, dm["h"])
        set_tile(walls_mode, x, left_y + left_h - 1, dm["h"])
    for y in range(left_y + 1, left_y + left_h - 1):
        set_tile(walls_mode, left_x, y, dm["v"])
        set_tile(walls_mode, left_x + left_w - 1, y, dm["v"])
    set_tile(walls_mode, left_x, left_y, dm["tl"])
    set_tile(walls_mode, left_x + left_w - 1, left_y, dm["tr"])
    set_tile(walls_mode, left_x, left_y + left_h - 1, dm["bl"])
    set_tile(walls_mode, left_x + left_w - 1, left_y + left_h - 1, dm["br"])

    for x in range(left_x + 8, left_x + left_w - 8):
        set_tile(walls_mode, x, left_y + 16, dm["h"])
    for y in range(left_y + 10, left_y + left_h - 6):
        set_tile(walls_mode, left_x + 28, y, dm["v"])
    set_tile(walls_mode, left_x + 28, left_y + 16, dm["cross"])

    # Canonical walls for dungeon_437 zone.
    d4 = {
        "tl": "assets/graphics/pre-packing-files_globbed/dungeon_437/d437_169_corner_tl.png",
        "tr": "assets/graphics/pre-packing-files_globbed/dungeon_437/d437_170_corner_tr.png",
        "h": "assets/graphics/pre-packing-files_globbed/dungeon_437/d437_196_box_horiz.png",
        "v": "assets/graphics/pre-packing-files_globbed/dungeon_437/d437_179_box_vert.png",
        "cross": "assets/graphics/pre-packing-files_globbed/dungeon_437/d437_197_box_cross.png",
    }
    right_x, right_y, right_w, right_h = 80, 8, 54, 36
    for x in range(right_x + 1, right_x + right_w - 1):
        set_tile(walls_437, x, right_y, d4["h"])
        set_tile(walls_437, x, right_y + right_h - 1, d4["h"])
    for y in range(right_y + 1, right_y + right_h - 1):
        set_tile(walls_437, right_x, y, d4["v"])
        set_tile(walls_437, right_x + right_w - 1, y, d4["v"])
    set_tile(walls_437, right_x, right_y, d4["tl"])
    set_tile(walls_437, right_x + right_w - 1, right_y, d4["tr"])
    set_tile(walls_437, right_x, right_y + right_h - 1, d4["tl"])
    set_tile(walls_437, right_x + right_w - 1, right_y + right_h - 1, d4["tr"])

    for x in range(right_x + 8, right_x + right_w - 8):
        set_tile(walls_437, x, right_y + 12, d4["h"])
    for y in range(right_y + 6, right_y + right_h - 6):
        set_tile(walls_437, right_x + 22, y, d4["v"])
    set_tile(walls_437, right_x + 22, right_y + 12, d4["cross"])

    # Props and characters across a shared avenue (visible y-sort behavior).
    pillar = extras[4]
    arch = extras[5]
    torch = extras[6]
    table = extras[7]
    chair = extras[8]
    heroes = extras[9:13]
    for i in range(10):
        y = 18 + i * 6
        set_tile(props, 70, y, pillar if i % 2 == 0 else arch)
        set_tile(props, 72, y + 1, torch if i % 3 == 0 else table)
    set_tile(props, 68, 30, heroes[0])
    set_tile(props, 68, 34, heroes[1])
    set_tile(props, 68, 38, heroes[2])
    set_tile(props, 68, 42, heroes[3])
    set_tile(props, 74, 41, chair)
    set_tile(props, 74, 43, chair)

    # Wall galleries: each wall asset appears once, split by source with wide spacing.
    mode_assets = [asset.path for asset in wall_assets if asset.source == "dungeon_mode"]
    d437_assets = [asset.path for asset in wall_assets if asset.source == "dungeon_437"]

    def place_gallery(layer: list[int], assets: list[str], gx0: int, gy0: int, cols: int, step_x: int, step_y: int) -> None:
        for i, asset in enumerate(assets):
            gx = gx0 + (i % cols) * step_x
            gy = gy0 + (i // cols) * step_y
            set_tile(layer, gx, gy, asset)

    place_gallery(wall_gallery_mode, mode_assets, gx0=4, gy0=56, cols=16, step_x=4, step_y=4)
    place_gallery(wall_gallery_437, d437_assets, gx0=6, gy0=72, cols=16, step_x=4, step_y=4)

    layers = [
        _make_tile_layer(1, "Ground", width, height, ground),
        _make_tile_layer(2, "Walls_Mode", width, height, walls_mode),
        _make_tile_layer(3, "Walls_437", width, height, walls_437),
        _make_tile_layer(4, "Props", width, height, props),
        _make_tile_layer(5, "Wall_Gallery_Mode", width, height, wall_gallery_mode),
        _make_tile_layer(6, "Wall_Gallery_437", width, height, wall_gallery_437),
        {
            "id": 7,
            "name": "Objects",
            "type": "objectgroup",
            "visible": True,
            "opacity": 1.0,
            "objects": [
                {"id": 1001, "name": "spawn_player", "type": "PlayerSpawn", "x": 96, "y": 96, "width": 8, "height": 8},
                {"id": 1002, "name": "spawn_enemy_a", "type": "Enemy", "x": 224, "y": 144, "width": 8, "height": 8},
                {"id": 1003, "name": "spawn_enemy_b", "type": "Enemy", "x": 736, "y": 128, "width": 8, "height": 8},
                {"id": 1004, "name": "spawn_loot", "type": "Loot", "x": 560, "y": 320, "width": 8, "height": 8},
                {"id": 1005, "name": "spawn_vendor", "type": "NPC", "x": 864, "y": 320, "width": 8, "height": 8},
            ],
        },
    ]

    map_payload = {
        "name": "tiled_wall_showcase",
        "orientation": "orthogonal",
        "renderorder": "right-down",
        "width": width,
        "height": height,
        "tilewidth": tile_size,
        "tileheight": tile_size,
        "infinite": False,
        "layers": layers,
        "tilesets": tilesets,
    }

    tmj_path = demo_map_dir / "wall_showcase.tmj"
    write_json(tmj_path, map_payload, check_only)

    info = {
        "schema_version": "1.0",
        "map_path": _rel(root, tmj_path),
        "tile_size": tile_size,
        "map_width": width,
        "map_height": height,
        "wall_asset_count": len(wall_asset_paths),
        "tileset_count": len(tilesets),
        "layers": [layer["name"] for layer in layers],
    }
    write_json(demo_map_dir / "wall_showcase.info.json", info, check_only)
    return info


def main() -> int:
    args = parse_args()
    root = args.project_root.resolve()
    manifest = _resolve(root, args.manifest)
    rulesets_dir = _resolve(root, args.rulesets_dir)
    generated_rulesets_dir = _resolve(root, args.generated_rulesets_dir)
    catalog = _resolve(root, args.catalog)
    demo_map_dir = _resolve(root, args.demo_map_dir)

    wall_paths = load_manifest_walls(manifest)
    assets = [parse_wall_asset(path_text) for path_text in wall_paths]
    assets.sort(key=lambda a: (a.source, a.tile_id, a.path))

    catalog_data = generate_rulesets(
        root=root,
        rulesets_dir=rulesets_dir,
        generated_rulesets_dir=generated_rulesets_dir,
        catalog_path=catalog,
        assets=assets,
        check_only=args.check_only,
    )
    demo_info = generate_demo_map(
        root=root, demo_map_dir=demo_map_dir, wall_assets=assets, check_only=args.check_only
    )

    summary = {
        "total_wall_assets": len(assets),
        "total_rulesets": int(catalog_data["total_rulesets"]),
        "catalog": _rel(root, catalog),
        "demo_map": demo_info["map_path"],
        "check_only": bool(args.check_only),
    }
    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
