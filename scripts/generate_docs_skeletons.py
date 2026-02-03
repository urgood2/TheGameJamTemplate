#!/usr/bin/env python3
"""Generate Tier-0 doc skeletons from inventory JSON files.

Rewrites AUTOGEN blocks in markdown files while preserving manual content.
"""
from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

LOG_PREFIX = "[DOCS]"


@dataclass
class InventoryTarget:
    inventory_path: Path
    output_path: Path
    marker: str


def log(message: str, verbose: bool = True) -> None:
    if verbose:
        print(f"{LOG_PREFIX} {message}")


def autogen_block(marker: str, lines: Iterable[str]) -> str:
    begin = f"<!-- AUTOGEN:BEGIN {marker} -->"
    end = f"<!-- AUTOGEN:END {marker} -->"
    body = "\n".join(lines)
    return "\n".join([begin, body, end])


def replace_autogen(content: str, marker: str, new_block: str) -> tuple[str, bool]:
    begin = f"<!-- AUTOGEN:BEGIN {marker} -->"
    end = f"<!-- AUTOGEN:END {marker} -->"
    if begin in content and end in content:
        start = content.index(begin) + len(begin)
        finish = content.index(end)
        updated = content[:start] + "\n" + new_block.split("\n", 1)[1].rsplit("\n", 1)[0] + "\n" + content[finish:]
        return updated, False

    separator = "\n\n" if content and not content.endswith("\n") else "\n"
    updated = content + separator + new_block + "\n"
    return updated, True


def load_json(path: Path) -> dict:
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def binding_lines(data: dict) -> list[str]:
    bindings = data.get("bindings", {})
    rows = []
    for key in ("usertypes", "functions", "constants", "enums", "methods", "properties"):
        for item in bindings.get(key, []):
            lua_name = item.get("lua_name") or item.get("name") or "<unknown>"
            binding_type = item.get("type") or key.rstrip("s")
            signature = item.get("signature") or ""
            source_ref = item.get("source_ref") or ""
            parts = [f"`{lua_name}`", f"({binding_type})"]
            if signature:
                parts.append(f"`{signature}`")
            if source_ref:
                parts.append(f"`{source_ref}`")
            rows.append("- " + " — ".join(parts))
    return sorted(rows)


def component_lines(data: dict) -> list[str]:
    rows = []
    for item in data.get("components", []):
        name = item.get("name") or "<unknown>"
        file_path = item.get("file_path") or ""
        line = item.get("line_number")
        fields = item.get("fields") or []
        location = f"{file_path}:{line}" if file_path and line else file_path
        parts = [f"`{name}`"]
        if location:
            parts.append(f"`{location}`")
        parts.append(f"fields: {len(fields)}")
        rows.append("- " + " — ".join(parts))
    return sorted(rows)


def pattern_lines(data: dict) -> list[str]:
    rows = []
    for item in data.get("patterns", []):
        name = item.get("name") or item.get("doc_id") or "<unknown>"
        source_ref = item.get("source_ref") or ""
        parts = [f"`{name}`"]
        if source_ref:
            parts.append(f"`{source_ref}`")
        rows.append("- " + " — ".join(parts))
    return sorted(rows)


def inventory_targets(inventory_dir: Path, output_root: Path) -> list[InventoryTarget]:
    targets: list[InventoryTarget] = []
    for path in sorted(inventory_dir.glob("*.json")):
        name = path.name
        if name.startswith("bindings."):
            system = name[len("bindings.") : -len(".json")]
            output_path = output_root / "bindings" / f"{system}_bindings.md"
            targets.append(InventoryTarget(path, output_path, "binding_list"))
        elif name.startswith("components."):
            category = name[len("components.") : -len(".json")]
            output_path = output_root / "components" / f"{category}_components.md"
            targets.append(InventoryTarget(path, output_path, "component_list"))
        elif name.startswith("patterns."):
            area = name[len("patterns.") : -len(".json")]
            output_path = output_root / "patterns" / f"{area}_patterns.md"
            targets.append(InventoryTarget(path, output_path, "pattern_list"))
    return targets


def build_lines(target: InventoryTarget, data: dict) -> list[str]:
    if target.marker == "binding_list":
        return binding_lines(data)
    if target.marker == "component_list":
        return component_lines(data)
    if target.marker == "pattern_list":
        return pattern_lines(data)
    return []


def update_doc(target: InventoryTarget, check: bool, verbose: bool) -> bool:
    data = load_json(target.inventory_path)
    lines = build_lines(target, data)
    block = autogen_block(target.marker, lines)

    content = ""
    if target.output_path.exists():
        content = target.output_path.read_text(encoding="utf-8")

    updated, inserted = replace_autogen(content, target.marker, block)
    if inserted:
        log(f"WARNING: Missing AUTOGEN markers in {target.output_path.name}, appended block", verbose)

    if check:
        return updated == content

    target.output_path.parent.mkdir(parents=True, exist_ok=True)
    target.output_path.write_text(updated, encoding="utf-8")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate doc skeletons from inventories")
    parser.add_argument("--inventory-dir", type=Path, default=Path("planning/inventory"))
    parser.add_argument("--output-root", type=Path, default=Path("planning"))
    parser.add_argument("--check", action="store_true", help="Check mode (no writes)")
    parser.add_argument("--verbose", "-v", action="store_true")
    args = parser.parse_args()

    verbose = args.verbose or args.check

    targets = inventory_targets(args.inventory_dir, args.output_root)
    if not targets:
        log("WARNING: No inventory files found", verbose)
        return 1

    all_ok = True
    for target in targets:
        log(f"Processing {target.inventory_path} -> {target.output_path}", verbose)
        try:
            ok = update_doc(target, args.check, verbose)
        except Exception as exc:  # pragma: no cover - unexpected errors
            log(f"ERROR: Failed to process {target.inventory_path}: {exc}", True)
            return 2
        all_ok = all_ok and ok

    if args.check and not all_ok:
        log("Check failed: docs need regeneration", verbose)
        return 1

    log("Done.", verbose)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
