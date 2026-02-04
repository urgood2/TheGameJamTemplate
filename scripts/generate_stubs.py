#!/usr/bin/env python3
"""Generate EmmyLua stubs from binding/component inventories.

Outputs stub files under docs/lua_stubs/ for IDE autocomplete.
"""
from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable

LOG_PREFIX = "[STUBS]"


def log(message: str) -> None:
    print(f"{LOG_PREFIX} {message}")


IDENT_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def normalize_name(name: str) -> str:
    return name.replace("::", ".").replace(":", ".")


def sanitize_segment(segment: str) -> str:
    if IDENT_RE.match(segment):
        return segment
    cleaned = re.sub(r"[^A-Za-z0-9_]", "_", segment)
    if not cleaned:
        cleaned = "_"
    if cleaned[0].isdigit():
        cleaned = f"_{cleaned}"
    return cleaned


def sanitize_dotted(name: str) -> str:
    parts = [sanitize_segment(part) for part in name.split(".") if part]
    return ".".join(parts)


def parse_signature(signature: str) -> tuple[list[tuple[str, str]], list[str]] | None:
    if not signature:
        return None
    match = re.match(r"^[^(]*\((?P<params>[^)]*)\)\s*->\s*(?P<returns>.*)$", signature)
    if not match:
        return None
    params_raw = match.group("params").strip()
    returns_raw = match.group("returns").strip()
    params: list[tuple[str, str]] = []
    if params_raw:
        for idx, token in enumerate(params_raw.split(","), start=1):
            token = token.strip()
            if not token:
                continue
            token = token.split("=")[0].strip()
            if ":" in token:
                name_part, type_part = token.split(":", 1)
                name = sanitize_segment(name_part.strip().rstrip("?"))
                typ = type_part.strip() or "any"
            else:
                name = sanitize_segment(token.rstrip("?"))
                if not name:
                    name = f"param{idx}"
                typ = "any"
            params.append((name, typ))
    returns: list[str] = []
    if returns_raw:
        for ret in returns_raw.split(","):
            ret = ret.strip()
            if not ret:
                continue
            returns.append(ret)
    if not returns:
        returns.append("any")
    return params, returns


@dataclass
class StubClass:
    name: str
    kind: str = "usertype"
    fields: dict[str, str] = field(default_factory=dict)


@dataclass
class StubFunction:
    name: str
    signature: str = ""


@dataclass
class StubModule:
    classes: dict[str, StubClass] = field(default_factory=dict)
    functions: dict[str, StubFunction] = field(default_factory=dict)
    tables: set[str] = field(default_factory=set)

    def ensure_class(self, name: str, kind: str = "usertype") -> StubClass:
        if name not in self.classes:
            self.classes[name] = StubClass(name=name, kind=kind)
        else:
            if kind == "enum":
                self.classes[name].kind = "enum"
        return self.classes[name]

    def add_function(self, name: str, signature: str) -> None:
        if name not in self.functions:
            self.functions[name] = StubFunction(name=name, signature=signature)

    def add_table(self, name: str) -> None:
        if not name:
            return
        parts = [part for part in name.split(".") if part]
        for idx in range(1, len(parts) + 1):
            self.tables.add(".".join(parts[:idx]))


@dataclass
class BindingItem:
    lua_name: str
    kind: str
    signature: str
    source_ref: str


@dataclass
class StubSpec:
    output: str
    inventory: str
    predicate: callable


def load_binding_items(path: Path) -> list[BindingItem]:
    data = json.loads(path.read_text())
    items: list[BindingItem] = []
    bindings = data.get("bindings", {})
    for group in bindings.values():
        if not isinstance(group, list):
            continue
        for entry in group:
            lua_name = entry.get("lua_name", "")
            if not lua_name:
                continue
            items.append(
                BindingItem(
                    lua_name=lua_name,
                    kind=entry.get("type", ""),
                    signature=entry.get("signature", ""),
                    source_ref=entry.get("source_ref", ""),
                )
            )
    return items


def load_component_entries(component_files: Iterable[Path]) -> list[dict]:
    entries: list[dict] = []
    for path in component_files:
        data = json.loads(path.read_text())
        comps = data.get("components", [])
        if isinstance(comps, list):
            entries.extend(comps)
    return entries


def classify_source(item: BindingItem, needle: str) -> bool:
    return needle in (item.source_ref or "")


def build_stub_module(items: list[BindingItem]) -> StubModule:
    module = StubModule()
    for item in items:
        name = normalize_name(item.lua_name)
        name = sanitize_dotted(name)
        if not name:
            continue
        if item.kind in {"usertype", "enum"}:
            module.ensure_class(name, kind=item.kind)
            module.add_table(name)
            continue
        if item.kind == "property":
            if "." in name:
                class_name, field_name = name.rsplit(".", 1)
                cls = module.ensure_class(class_name)
                cls.fields[field_name] = "any"
                module.add_table(class_name)
            continue
        if item.kind == "function":
            module.add_function(name, item.signature)
            if "." in name:
                module.add_table(name.rsplit(".", 1)[0])
            continue
        if item.kind == "method":
            module.add_function(name, item.signature)
            if "." in name:
                module.add_table(name.rsplit(".", 1)[0])
            continue
        if item.kind == "constant":
            module.add_function(name, item.signature)
            continue
    return module


def write_stub_file(path: Path, module: StubModule) -> None:
    lines: list[str] = []
    lines.append("---@meta")
    lines.append("-- Generated by scripts/generate_stubs.py. DO NOT EDIT BY HAND.")
    lines.append("")

    for table_name in sorted(module.tables, key=lambda s: (s.count("."), s)):
        lines.append(f"{table_name} = {table_name} or {{}}")
    if module.tables:
        lines.append("")

    for class_name in sorted(module.classes.keys()):
        cls = module.classes[class_name]
        if cls.kind == "enum":
            lines.append(f"---@enum {class_name}")
        else:
            lines.append(f"---@class {class_name}")
        for field_name in sorted(cls.fields.keys()):
            lines.append(f"---@field {field_name} any")
        lines.append(f"{class_name} = {class_name} or {{}}")
        lines.append("")

    for func_name in sorted(module.functions.keys()):
        func = module.functions[func_name]
        signature = parse_signature(func.signature) if func.signature else None
        if signature is None:
            lines.append("---@param ... any")
            lines.append("---@return any")
            lines.append(f"function {func_name}(...) end")
            lines.append("")
            continue
        params, returns = signature
        for name, typ in params:
            lines.append(f"---@param {name} {typ}")
        if returns:
            lines.append("---@return " + ", ".join(returns))
        param_list = ", ".join(name for name, _ in params)
        lines.append(f"function {func_name}({param_list}) end")
        lines.append("")

    path.write_text("\n".join(lines).rstrip() + "\n")


def write_components_stub(path: Path, component_entries: list[dict]) -> None:
    lines: list[str] = []
    lines.append("---@meta")
    lines.append("-- Generated by scripts/generate_stubs.py. DO NOT EDIT BY HAND.")
    lines.append("")

    for comp in sorted(component_entries, key=lambda c: c.get("name", "")):
        name = sanitize_segment(comp.get("name", ""))
        if not name:
            continue
        lines.append(f"---@class {name}")
        fields = comp.get("fields", []) if not comp.get("is_tag") else []
        for field in fields:
            field_name = sanitize_segment(field.get("name", ""))
            field_type = field.get("type", "any") or "any"
            if field_name:
                lines.append(f"---@field {field_name} {field_type}")
        lines.append(f"{name} = {name} or {{}}")
        lines.append("")

    path.write_text("\n".join(lines).rstrip() + "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate EmmyLua stubs from inventories")
    parser.add_argument("--inventory-dir", default="planning/inventory", help="Inventory directory")
    parser.add_argument("--output-dir", default="docs/lua_stubs", help="Output directory")
    args = parser.parse_args()

    inventory_dir = Path(args.inventory_dir)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    specs = [
        StubSpec("core.lua", "bindings.core.json", lambda item: True),
        StubSpec("physics.lua", "bindings.physics.json", lambda item: True),
        StubSpec("ui.lua", "bindings.ui.json", lambda item: True),
        StubSpec("timer.lua", "bindings.timer_anim.json", lambda item: True),
        StubSpec("input.lua", "bindings.input_sound_ai.json", lambda item: classify_source(item, "/input/") or "input_lua_bindings.cpp" in item.source_ref),
        StubSpec("sound.lua", "bindings.input_sound_ai.json", lambda item: classify_source(item, "/sound/") or "sound_system.cpp" in item.source_ref),
        StubSpec("ai.lua", "bindings.input_sound_ai.json", lambda item: classify_source(item, "/ai/") or "ai_system.cpp" in item.source_ref),
        StubSpec("shader.lua", "bindings.shader_layer.json", lambda item: classify_source(item, "/shaders/") or "shader" in item.source_ref),
        StubSpec("layer.lua", "bindings.shader_layer.json", lambda item: classify_source(item, "/layer/") or "layer_lua_bindings.cpp" in item.source_ref),
    ]

    for spec in specs:
        inv_path = inventory_dir / spec.inventory
        if not inv_path.exists():
            log(f"Skip {spec.output}: inventory missing at {inv_path}")
            continue
        items = [item for item in load_binding_items(inv_path) if spec.predicate(item)]
        module = build_stub_module(items)
        out_path = output_dir / spec.output
        write_stub_file(out_path, module)
        log(f"Wrote {out_path} ({len(module.functions)} functions, {len(module.classes)} classes)")

    component_files = sorted(inventory_dir.glob("components.*.json"))
    if component_files:
        component_entries = load_component_entries(component_files)
        out_path = output_dir / "components.lua"
        write_components_stub(out_path, component_entries)
        log(f"Wrote {out_path} ({len(component_entries)} components)")


if __name__ == "__main__":
    main()
