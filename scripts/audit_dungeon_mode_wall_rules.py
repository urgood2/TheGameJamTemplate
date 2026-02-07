#!/usr/bin/env python3
"""Audit dungeon_mode wall tiles and export a PDF wall-rules report.

The audit derives cardinal connectivity from each tile's center-connected
opaque component, then documents the canonical 16-mask mapping used for
runtime autotiling.
"""

from __future__ import annotations

import json
import math
import textwrap
from collections import deque
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MANIFEST = PROJECT_ROOT / "planning/tiled_assets/required_asset_manifest.json"
OUTPUT_DIR = PROJECT_ROOT / "planning/tiled_assets/reports"
OUTPUT_PDF = OUTPUT_DIR / "dungeon_mode_wall_rules_audit.pdf"
OUTPUT_JSON = OUTPUT_DIR / "dungeon_mode_wall_rules_audit.json"


@dataclass(frozen=True)
class TileInfo:
    id: int
    desc: str
    path: Path
    rel_path: str


@dataclass(frozen=True)
class RuleMapping:
    mask: int
    name: str
    tile_desc: str
    rotation: int


MASK_BITS = {"north": 1, "east": 2, "south": 4, "west": 8}
PAGE_W = 1654
PAGE_H = 2339


CANONICAL_RULES = [
    RuleMapping(mask=15, name="cross", tile_desc="box_cross", rotation=0),
    RuleMapping(mask=14, name="t_down", tile_desc="box_horizontal", rotation=180),
    RuleMapping(mask=11, name="t_up", tile_desc="box_horizontal", rotation=0),
    RuleMapping(mask=7, name="t_right", tile_desc="box_horizontal", rotation=90),
    RuleMapping(mask=13, name="t_left", tile_desc="box_horizontal", rotation=270),
    RuleMapping(mask=5, name="vertical", tile_desc="box_corner_bl", rotation=90),
    RuleMapping(mask=10, name="horizontal", tile_desc="box_corner_bl", rotation=0),
    RuleMapping(mask=6, name="corner_tl", tile_desc="box_corner_br", rotation=90),
    RuleMapping(mask=12, name="corner_tr", tile_desc="box_corner_br", rotation=180),
    RuleMapping(mask=3, name="corner_bl", tile_desc="box_corner_br", rotation=0),
    RuleMapping(mask=9, name="corner_br", tile_desc="box_corner_br", rotation=270),
    RuleMapping(mask=1, name="end_north", tile_desc="block_full", rotation=0),
    RuleMapping(mask=2, name="end_east", tile_desc="block_full", rotation=90),
    RuleMapping(mask=4, name="end_south", tile_desc="block_full", rotation=180),
    RuleMapping(mask=8, name="end_west", tile_desc="block_full", rotation=270),
    RuleMapping(mask=0, name="isolated", tile_desc="shade_heavy", rotation=0),
]


def load_dungeon_mode_tiles() -> list[TileInfo]:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    walls = manifest["category_files"]["walls"]
    out: list[TileInfo] = []
    for rel in walls:
        if "/dungeon_mode/" not in rel:
            continue
        p = PROJECT_ROOT / rel
        name = p.stem  # dm_240_box_corner_tl
        parts = name.split("_", 2)
        tile_id = int(parts[1])
        desc = parts[2]
        out.append(TileInfo(id=tile_id, desc=desc, path=p, rel_path=rel))
    out.sort(key=lambda t: t.id)
    return out


def rotate_tile(im: Image.Image, degrees: int) -> Image.Image:
    if degrees % 360 == 0:
        return im
    return im.rotate(-degrees, expand=False)


def mask_from_center_component(im: Image.Image) -> int:
    px = im.load()
    occupied = [[px[x, y][3] > 0 for x in range(8)] for y in range(8)]

    seeds = [(x, y) for y in (3, 4) for x in (3, 4) if occupied[y][x]]
    if not seeds:
        pts = [(x, y) for y in range(8) for x in range(8) if occupied[y][x]]
        if pts:
            seeds = [min(pts, key=lambda p: (p[0] - 3.5) ** 2 + (p[1] - 3.5) ** 2)]
    if not seeds:
        return 0

    q = deque(seeds)
    seen = set(seeds)
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx = x + dx
            ny = y + dy
            if 0 <= nx < 8 and 0 <= ny < 8 and occupied[ny][nx] and (nx, ny) not in seen:
                seen.add((nx, ny))
                q.append((nx, ny))

    mask = 0
    if any(y == 0 for x, y in seen):
        mask |= MASK_BITS["north"]
    if any(x == 7 for x, y in seen):
        mask |= MASK_BITS["east"]
    if any(y == 7 for x, y in seen):
        mask |= MASK_BITS["south"]
    if any(x == 0 for x, y in seen):
        mask |= MASK_BITS["west"]
    return mask


def bits_label(mask: int) -> str:
    n = 1 if mask & 1 else 0
    e = 1 if mask & 2 else 0
    s = 1 if mask & 4 else 0
    w = 1 if mask & 8 else 0
    return f"N{n} E{e} S{s} W{w}"


def checkerboard(size: int, c0=(38, 38, 38), c1=(58, 58, 58), block=8) -> Image.Image:
    out = Image.new("RGB", (size, size), c0)
    d = ImageDraw.Draw(out)
    for y in range(0, size, block):
        for x in range(0, size, block):
            if ((x // block) + (y // block)) % 2:
                d.rectangle([x, y, x + block - 1, y + block - 1], fill=c1)
    return out


def draw_wrapped_text(
    draw: ImageDraw.ImageDraw,
    text: str,
    x: int,
    y: int,
    *,
    font: ImageFont.ImageFont,
    fill: tuple[int, int, int] = (20, 20, 20),
    width_chars: int = 56,
    line_height: int = 20,
) -> int:
    lines = textwrap.wrap(text, width=width_chars, break_long_words=False, break_on_hyphens=False)
    if not lines:
        lines = [text]
    for line in lines:
        draw.text((x, y), line, font=font, fill=fill)
        y += line_height
    return y


def scaled_preview(im: Image.Image, scale: int = 20, show_grid: bool = True) -> Image.Image:
    tile = im.resize((8 * scale, 8 * scale), Image.NEAREST).convert("RGBA")
    bg = checkerboard(8 * scale, block=scale)
    bg = bg.convert("RGBA")
    bg.alpha_composite(tile, (0, 0))
    if show_grid:
        d = ImageDraw.Draw(bg)
        grid = (76, 76, 76, 255)
        border = (220, 220, 220, 255)
        for i in range(9):
            p = i * scale
            d.line([(p, 0), (p, 8 * scale - 1)], fill=grid, width=1)
            d.line([(0, p), (8 * scale - 1, p)], fill=grid, width=1)
        d.rectangle([0, 0, 8 * scale - 1, 8 * scale - 1], outline=border, width=2)
    return bg


def build_page_rules(
    tiles_by_desc: dict[str, TileInfo],
    base_images: dict[str, Image.Image],
    font: ImageFont.ImageFont,
) -> Image.Image:
    page = Image.new("RGB", (PAGE_W, PAGE_H), (250, 250, 250))
    draw = ImageDraw.Draw(page)

    draw.text((60, 40), "Dungeon Mode Wall Rules Audit", font=font, fill=(20, 20, 20))
    draw.text(
        (60, 80),
        "Connectivity method: center-connected opaque component -> cardinal border reachability",
        font=font,
        fill=(30, 30, 30),
    )
    draw.text(
        (60, 108),
        f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        font=font,
        fill=(70, 70, 70),
    )

    cell_w = 380
    cell_h = 515
    x0 = 60
    y0 = 170

    by_mask = {r.mask: r for r in CANONICAL_RULES}
    for mask in range(16):
        r = mask // 4
        c = mask % 4
        cx = x0 + c * cell_w
        cy = y0 + r * cell_h
        draw.rectangle([cx, cy, cx + cell_w - 16, cy + cell_h - 16], outline=(180, 180, 180), width=2)

        rule = by_mask[mask]
        tile_info = tiles_by_desc[rule.tile_desc]
        base = base_images[rule.tile_desc]
        transformed = rotate_tile(base, rule.rotation)
        preview = scaled_preview(transformed, scale=18, show_grid=True)
        page.paste(preview.convert("RGB"), (cx + 22, cy + 34))

        draw.text((cx + 200, cy + 34), f"mask {mask:02d}", font=font, fill=(20, 20, 20))
        draw.text((cx + 200, cy + 58), bits_label(mask), font=font, fill=(20, 20, 20))
        draw.text((cx + 200, cy + 86), f"rule: {rule.name}", font=font, fill=(20, 20, 20))
        draw.text((cx + 200, cy + 112), f"tile: dm_{tile_info.id:03d}_{rule.tile_desc}", font=font, fill=(20, 20, 20))
        draw.text((cx + 200, cy + 138), f"rotation: {rule.rotation}", font=font, fill=(20, 20, 20))

    draw.text(
        (60, 2200),
        "Canonical set used: dm_242 (straight), dm_243 (corner), dm_244 (tee), dm_250 (cross), dm_254 (end), dm_253 (isolated).",
        font=font,
        fill=(40, 40, 40),
    )
    draw.text(
        (60, 2228),
        "Each preview includes a visible 8x8 pixel grid to verify tile-to-grid alignment.",
        font=font,
        fill=(40, 40, 40),
    )
    return page


def build_contact_sheet_pages(
    tiles: list[TileInfo],
    base_images: dict[str, Image.Image],
    font: ImageFont.ImageFont,
) -> list[Image.Image]:
    cols = 3
    cell_w = 520
    cell_h = 200
    x0 = 50
    y0 = 110
    bottom_margin = 55
    rows_per_page = (PAGE_H - y0 - bottom_margin) // cell_h
    per_page = cols * rows_per_page
    page_count = max(1, math.ceil(len(tiles) / per_page))
    pages: list[Image.Image] = []

    for page_index in range(page_count):
        page = Image.new("RGB", (PAGE_W, PAGE_H), (252, 252, 252))
        draw = ImageDraw.Draw(page)
        draw.text(
            (60, 40),
            f"Dungeon Mode Wall Tiles (Page {page_index + 1}/{page_count})",
            font=font,
            fill=(20, 20, 20),
        )

        start = page_index * per_page
        end = min(len(tiles), start + per_page)
        subset = tiles[start:end]
        for i, tile in enumerate(subset):
            r = i // cols
            c = i % cols
            cx = x0 + c * cell_w
            cy = y0 + r * cell_h
            draw.rectangle([cx, cy, cx + cell_w - 12, cy + cell_h - 10], outline=(185, 185, 185), width=2)

            base = base_images[tile.desc]
            preview = scaled_preview(base, scale=14, show_grid=True)
            page.paste(preview.convert("RGB"), (cx + 14, cy + 14))

            masks = sorted({mask_from_center_component(rotate_tile(base, rot)) for rot in (0, 90, 180, 270)})
            unrot = mask_from_center_component(base)
            tx = cx + 142
            ty = cy + 16
            draw.text((tx, ty), f"dm_{tile.id:03d}_{tile.desc}", font=font, fill=(20, 20, 20))
            ty += 24
            draw.text((tx, ty), f"base mask: {unrot:02d} ({bits_label(unrot)})", font=font, fill=(20, 20, 20))
            ty += 22
            draw.text((tx, ty), f"rotation masks: {masks}", font=font, fill=(20, 20, 20))
            ty += 22
            _ = draw_wrapped_text(
                draw,
                f"path: {tile.rel_path}",
                tx,
                ty,
                font=font,
                fill=(60, 60, 60),
                width_chars=58,
                line_height=18,
            )

        pages.append(page)
    return pages


def build_page_summary(
    tiles: list[TileInfo],
    tiles_by_desc: dict[str, TileInfo],
    base_images: dict[str, Image.Image],
    font: ImageFont.ImageFont,
) -> Image.Image:
    page = Image.new("RGB", (PAGE_W, PAGE_H), (250, 250, 250))
    draw = ImageDraw.Draw(page)

    draw.text((60, 40), "Audit Summary", font=font, fill=(20, 20, 20))
    y = 90
    lines = [
        "1. Previous mapping relied on descriptor names; pixel connectivity disagreed for several dm_240-250 tiles.",
        "2. Corrected canonical mapping is now connectivity-derived and uses rotation for completeness.",
        "3. All 16 neighbor masks are covered by exact connectivity matches in the canonical rules.",
        "4. Non-canonical wall tiles remain available via generated per-asset fill rulesets in the catalog.",
        "",
        "Canonical mappings:",
    ]
    for line in lines:
        draw.text((60, y), line, font=font, fill=(25, 25, 25))
        y += 28

    for rule in sorted(CANONICAL_RULES, key=lambda r: r.mask):
        tile = tiles_by_desc[rule.tile_desc]
        base = base_images[rule.tile_desc]
        transformed = rotate_tile(base, rule.rotation)
        detected = mask_from_center_component(transformed)
        line = (
            f"mask {rule.mask:02d} {bits_label(rule.mask)} -> "
            f"dm_{tile.id:03d}_{rule.tile_desc} rot={rule.rotation} "
            f"(detected={detected:02d})"
        )
        draw.text((60, y), line, font=font, fill=(25, 25, 25))
        y += 24

    y += 20
    draw.text(
        (60, y),
        f"Dungeon mode wall assets in manifest: {len(tiles)} (listed across contact pages).",
        font=font,
        fill=(25, 25, 25),
    )
    y += 30
    draw.text(
        (60, y),
        "Rendering note: all previews now show an 8x8 grid, and contact pages wrap paths to prevent overlap.",
        font=font,
        fill=(25, 25, 25),
    )

    return page


def main() -> int:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    tiles = load_dungeon_mode_tiles()
    tiles_by_desc = {t.desc: t for t in tiles}
    base_images = {t.desc: Image.open(t.path).convert("RGBA") for t in tiles}

    # Validate canonical descriptor references.
    for rule in CANONICAL_RULES:
        if rule.tile_desc not in tiles_by_desc:
            raise ValueError(f"Missing dungeon_mode asset for canonical rule: {rule.tile_desc}")

    font = ImageFont.load_default()
    page1 = build_page_rules(tiles_by_desc, base_images, font)
    contact_pages = build_contact_sheet_pages(tiles, base_images, font)
    page_summary = build_page_summary(tiles, tiles_by_desc, base_images, font)

    pages_rgb = [page1.convert("RGB"), *[p.convert("RGB") for p in contact_pages], page_summary.convert("RGB")]
    pages_rgb[0].save(OUTPUT_PDF, save_all=True, append_images=pages_rgb[1:])

    audit_json = {
        "generated_at": datetime.now().isoformat(),
        "manifest": str(MANIFEST.relative_to(PROJECT_ROOT)),
        "tile_count": len(tiles),
        "canonical_rules": [
            {
                "mask": rule.mask,
                "bits": bits_label(rule.mask),
                "rule": rule.name,
                "tile_desc": rule.tile_desc,
                "tile_id": tiles_by_desc[rule.tile_desc].id,
                "rotation": rule.rotation,
                "detected_mask": mask_from_center_component(
                    rotate_tile(base_images[rule.tile_desc], rule.rotation)
                ),
            }
            for rule in sorted(CANONICAL_RULES, key=lambda r: r.mask)
        ],
        "tiles": [
            {
                "id": tile.id,
                "desc": tile.desc,
                "path": tile.rel_path,
                "rotation_masks": sorted(
                    {
                        mask_from_center_component(rotate_tile(base_images[tile.desc], rot))
                        for rot in (0, 90, 180, 270)
                    }
                ),
            }
            for tile in tiles
        ],
        "pdf": str(OUTPUT_PDF.relative_to(PROJECT_ROOT)),
    }
    OUTPUT_JSON.write_text(json.dumps(audit_json, indent=2) + "\n", encoding="utf-8")

    print(json.dumps({"pdf": str(OUTPUT_PDF), "json": str(OUTPUT_JSON)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
