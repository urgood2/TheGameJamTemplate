#!/usr/bin/env python3
"""
Generate an internal UI pack (atlas + manifest) from the Crusenho free pack sprites.

This script is intentionally deterministic:
- sorted input filenames
- fixed max atlas width
- fixed padding

Usage:
  python3 scripts/generate_crusenho_ui_pack.py \
    --source "/Users/joshuashin/Downloads/Complete_UI_Essential_Pack_Free/01_Flat_Theme/Sprites" \
    --out-dir "assets/ui_packs/crusenho_flat"
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
from pathlib import Path
from typing import Dict, List, Tuple

from PIL import Image


MAX_ATLAS_WIDTH = 1024
PADDING = 2


def _read_images(source_dir: Path) -> List[Tuple[str, Path, Image.Image]]:
    items: List[Tuple[str, Path, Image.Image]] = []
    for path in sorted(source_dir.glob("*.png")):
        img = Image.open(path).convert("RGBA")
        items.append((path.stem, path, img))
    if not items:
        raise RuntimeError(f"No PNG files found in {source_dir}")
    return items


def _pack_images(items: List[Tuple[str, Path, Image.Image]]) -> Tuple[Image.Image, Dict[str, List[int]]]:
    # Shelf pack by descending height then name for stable compactness.
    ordered = sorted(items, key=lambda x: (-x[2].height, x[0]))

    x = PADDING
    y = PADDING
    row_h = 0
    placements: Dict[str, List[int]] = {}

    for stem, _, img in ordered:
        w, h = img.size
        if x + w + PADDING > MAX_ATLAS_WIDTH:
            x = PADDING
            y += row_h + PADDING
            row_h = 0

        placements[stem] = [x, y, w, h]
        x += w + PADDING
        row_h = max(row_h, h)

    atlas_h = y + row_h + PADDING
    atlas = Image.new("RGBA", (MAX_ATLAS_WIDTH, atlas_h), (0, 0, 0, 0))

    # Paste in original order by lookup for deterministic output.
    lookup = {stem: img for stem, _, img in ordered}
    for stem in sorted(placements.keys()):
        px, py, _, _ = placements[stem]
        atlas.paste(lookup[stem], (px, py))

    return atlas, placements


def _np_for_panel(stem: str) -> List[int]:
    if "Frame0" in stem:
        return [12, 12, 12, 12]
    if "Banner0" in stem:
        return [8, 6, 8, 6]
    if "FrameMarker" in stem:
        return [8, 8, 8, 8]
    if "FrameSlot" in stem:
        return [6, 6, 6, 6]
    return [4, 4, 4, 4]


def _region(placements: Dict[str, List[int]], stem: str) -> Dict[str, object]:
    return {"region": placements[stem]}


def _region_fixed(placements: Dict[str, List[int]], stem: str) -> Dict[str, object]:
    d = _region(placements, stem)
    d["scale_mode"] = "fixed"
    return d


def _region_np(placements: Dict[str, List[int]], stem: str, patch: List[int]) -> Dict[str, object]:
    d = _region(placements, stem)
    d["9patch"] = patch
    return d


def _build_manifest(placements: Dict[str, List[int]]) -> Dict[str, object]:
    def exists(stem: str) -> None:
        if stem not in placements:
            raise KeyError(f"Missing required source sprite: {stem}.png")

    # Required cores
    required = [
        "UI_Flat_Frame01a",
        "UI_Flat_Button01a_1",
        "UI_Flat_Button01a_2",
        "UI_Flat_Button01a_3",
        "UI_Flat_Button01a_4",
        "UI_Flat_InputField01a",
        "UI_Flat_InputField02a",
        "UI_Flat_Bar01a",
        "UI_Flat_BarFill01a",
        "UI_Flat_Handle02a",
    ]
    for stem in required:
        exists(stem)

    manifest: Dict[str, object] = {
        "name": "crusenho_flat",
        "version": "1.0",
        "atlas": "atlas.png",
        "panels": {},
        "buttons": {},
        "progress_bars": {},
        "scrollbars": {},
        "sliders": {},
        "inputs": {},
        "icons": {},
    }

    panels = manifest["panels"]  # type: ignore[assignment]
    assert isinstance(panels, dict)
    for stem in sorted(placements.keys()):
        if any(k in stem for k in ("Frame0", "Banner0", "FrameMarker", "FrameSlot")):
            key = (
                stem.replace("UI_Flat_", "")
                .replace("01a", "01")
                .replace("02a", "02")
                .replace("03a", "03")
                .replace("04a", "04")
                .replace("01b", "01_hover")
                .replace("01c", "01_pressed")
                .replace("02b", "02_hover")
                .replace("02c", "02_pressed")
                .replace("03b", "03_hover")
                .replace("03c", "03_pressed")
            ).lower()
            panels[key] = _region_np(placements, stem, _np_for_panel(stem))

    buttons = manifest["buttons"]  # type: ignore[assignment]
    assert isinstance(buttons, dict)
    buttons["primary"] = {
        "normal": _region_np(placements, "UI_Flat_Button01a_1", [6, 6, 6, 6]),
        "hover": _region_np(placements, "UI_Flat_Button01a_2", [6, 6, 6, 6]),
        "pressed": _region_np(placements, "UI_Flat_Button01a_3", [6, 6, 6, 6]),
        "disabled": _region_np(placements, "UI_Flat_Button01a_4", [6, 6, 6, 6]),
    }
    buttons["secondary"] = {
        "normal": _region_np(placements, "UI_Flat_Button02a_1", [6, 6, 6, 6]),
        "hover": _region_np(placements, "UI_Flat_Button02a_2", [6, 6, 6, 6]),
        "pressed": _region_np(placements, "UI_Flat_Button02a_3", [6, 6, 6, 6]),
        "disabled": _region_np(placements, "UI_Flat_Button02a_4", [6, 6, 6, 6]),
    }
    buttons["select_primary"] = {
        "normal": _region_np(placements, "UI_Flat_Select01a_1", [6, 6, 6, 6]),
        "hover": _region_np(placements, "UI_Flat_Select01a_2", [6, 6, 6, 6]),
        "pressed": _region_np(placements, "UI_Flat_Select01a_3", [6, 6, 6, 6]),
        "disabled": _region_np(placements, "UI_Flat_Select01a_4", [6, 6, 6, 6]),
    }
    buttons["select_secondary"] = {
        "normal": _region_np(placements, "UI_Flat_Select02a_1", [6, 6, 6, 6]),
        "hover": _region_np(placements, "UI_Flat_Select02a_2", [6, 6, 6, 6]),
        "pressed": _region_np(placements, "UI_Flat_Select02a_3", [6, 6, 6, 6]),
        "disabled": _region_np(placements, "UI_Flat_Select02a_4", [6, 6, 6, 6]),
    }
    buttons["toggle_round"] = {
        "normal": _region_fixed(placements, "UI_Flat_ToggleOff01a"),
        "hover": _region_fixed(placements, "UI_Flat_ToggleOff02a"),
        "pressed": _region_fixed(placements, "UI_Flat_ToggleOn01a"),
        "disabled": _region_fixed(placements, "UI_Flat_ToggleOn02a"),
    }
    buttons["toggle_lr"] = {
        "normal": _region_fixed(placements, "UI_Flat_ToggleLeftOff01a"),
        "hover": _region_fixed(placements, "UI_Flat_ToggleRightOff01a"),
        "pressed": _region_fixed(placements, "UI_Flat_ToggleRightOn01a"),
        "disabled": _region_fixed(placements, "UI_Flat_ToggleLeftOn01a"),
    }
    buttons["icon_arrow"] = {"normal": _region_fixed(placements, "UI_Flat_ButtonArrow01a")}
    buttons["icon_check"] = {"normal": _region_fixed(placements, "UI_Flat_ButtonCheck01a")}
    buttons["icon_cross"] = {"normal": _region_fixed(placements, "UI_Flat_ButtonCross01a")}
    buttons["icon_play"] = {"normal": _region_fixed(placements, "UI_Flat_ButtonPlay01a")}
    buttons["stepper_plus"] = {"normal": _region_fixed(placements, "UI_Flat_ButtonPlus01a")}
    buttons["stepper_minus"] = {"normal": _region_fixed(placements, "UI_Flat_ButtonMinus01a")}

    progress_bars = manifest["progress_bars"]  # type: ignore[assignment]
    assert isinstance(progress_bars, dict)
    bar_stems = [f"UI_Flat_Bar{i:02d}a" for i in range(1, 14)]
    fill_stems = [f"UI_Flat_BarFill01{ch}" for ch in "abcdefg"]
    for idx, bar_stem in enumerate(bar_stems):
        if bar_stem not in placements:
            continue
        fill_stem = fill_stems[idx % len(fill_stems)]
        if fill_stem not in placements:
            continue
        key = f"style_{idx + 1:02d}"
        progress_bars[key] = {
            "background": _region_np(placements, bar_stem, [4, 2, 4, 2]),
            "fill": _region(placements, fill_stem),
        }

    scrollbars = manifest["scrollbars"]  # type: ignore[assignment]
    assert isinstance(scrollbars, dict)
    scrollbars["default"] = {
        "track": _region_np(placements, "UI_Flat_Bar12a", [4, 2, 4, 2]),
        "thumb": _region_fixed(placements, "UI_Flat_Handle04a"),
    }
    scrollbars["compact"] = {
        "track": _region_np(placements, "UI_Flat_Bar13a", [4, 2, 4, 2]),
        "thumb": _region_fixed(placements, "UI_Flat_Handle06a"),
    }
    scrollbars["wide"] = {
        "track": _region_np(placements, "UI_Flat_Bar09a", [4, 2, 4, 2]),
        "thumb": _region_fixed(placements, "UI_Flat_Handle05a"),
    }

    sliders = manifest["sliders"]  # type: ignore[assignment]
    assert isinstance(sliders, dict)
    sliders["default"] = {
        "track": _region_np(placements, "UI_Flat_Bar05a", [4, 2, 4, 2]),
        "thumb": _region_fixed(placements, "UI_Flat_Handle02a"),
    }
    sliders["compact"] = {
        "track": _region_np(placements, "UI_Flat_Bar06a", [4, 2, 4, 2]),
        "thumb": _region_fixed(placements, "UI_Flat_Handle01a"),
    }
    sliders["tall"] = {
        "track": _region_np(placements, "UI_Flat_Bar07a", [4, 2, 4, 2]),
        "thumb": _region_fixed(placements, "UI_Flat_Handle03a"),
    }

    inputs = manifest["inputs"]  # type: ignore[assignment]
    assert isinstance(inputs, dict)
    inputs["default"] = {
        "normal": _region_np(placements, "UI_Flat_InputField01a", [8, 8, 8, 8]),
        "focus": _region_np(placements, "UI_Flat_InputField02a", [8, 8, 8, 8]),
    }

    icons = manifest["icons"]  # type: ignore[assignment]
    assert isinstance(icons, dict)
    icon_aliases = {
        "arrow_lg": "UI_Flat_IconArrow01a",
        "arrow_md": "UI_Flat_IconArrow01b",
        "arrow_sm": "UI_Flat_IconArrow01c",
        "check_lg": "UI_Flat_IconCheck01a",
        "check_md": "UI_Flat_IconCheck01b",
        "check_sm": "UI_Flat_IconCheck01c",
        "cross_lg": "UI_Flat_IconCross01a",
        "cross_md": "UI_Flat_IconCross01b",
        "cross_sm": "UI_Flat_IconCross01c",
        "play_lg": "UI_Flat_IconPlay01a",
        "play_md": "UI_Flat_IconPlay01b",
        "play_sm": "UI_Flat_IconPlay01c",
        "play_xs": "UI_Flat_IconPlay01d",
        "point_lg": "UI_Flat_IconPoint01a",
        "point_md": "UI_Flat_IconPoint01b",
        "point_sm": "UI_Flat_IconPoint01c",
        "dropdown": "UI_Flat_IconDropdown01a",
        "stripe": "UI_Flat_IconStripe01a",
        "line": "UI_Flat_IconLine01a",
    }
    for key, stem in icon_aliases.items():
        if stem in placements:
            icons[key] = _region_fixed(placements, stem)

    return manifest


def _write_json(path: Path, payload: object) -> None:
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate Crusenho UI pack atlas + manifest.")
    parser.add_argument(
        "--source",
        default="/Users/joshuashin/Downloads/Complete_UI_Essential_Pack_Free/01_Flat_Theme/Sprites",
        help="Source directory containing loose PNG sprites.",
    )
    parser.add_argument(
        "--out-dir",
        default="assets/ui_packs/crusenho_flat",
        help="Output directory for atlas + pack manifest.",
    )
    args = parser.parse_args()

    source_dir = Path(args.source).expanduser().resolve()
    out_dir = Path(args.out_dir).resolve()

    if not source_dir.exists():
        raise FileNotFoundError(f"Source dir not found: {source_dir}")

    out_dir.mkdir(parents=True, exist_ok=True)

    items = _read_images(source_dir)
    atlas, placements = _pack_images(items)
    manifest = _build_manifest(placements)

    atlas_path = out_dir / "atlas.png"
    manifest_path = out_dir / "pack.json"
    regions_path = out_dir / "regions.json"

    atlas.save(atlas_path)
    _write_json(manifest_path, manifest)
    _write_json(regions_path, {"regions": placements})

    # Preserve source license for attribution clarity.
    license_src = source_dir.parent.parent / "License.txt"
    if license_src.exists():
        shutil.copy2(license_src, out_dir / "LICENSE.txt")

    print(f"[OK] Generated atlas: {atlas_path}")
    print(f"[OK] Generated manifest: {manifest_path}")
    print(f"[OK] Generated regions map: {regions_path}")
    print(f"[INFO] Atlas size: {atlas.width}x{atlas.height}")
    print(f"[INFO] Region count: {len(placements)}")


if __name__ == "__main__":
    main()

