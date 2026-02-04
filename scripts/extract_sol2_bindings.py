#!/usr/bin/env python3
"""Extract Sol2 Lua bindings from C++ source files.

This script parses C++ files containing Sol2 binding code and generates
a structured JSON inventory of all Lua-exposed types, functions, and constants.

Usage:
    python scripts/extract_sol2_bindings.py [--output-dir DIR] [--system NAME]

Output:
    planning/inventory/bindings.{system}.json for each system
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field, asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from collections.abc import Iterator

# Confidence levels for extracted bindings
CONFIDENCE_HIGH = "high"
CONFIDENCE_MEDIUM = "medium"
CONFIDENCE_LOW = "low"

# Sol2 binding patterns (regex-based for initial implementation)
# These patterns match the code style seen in the codebase
PATTERNS = {
    "new_usertype": re.compile(
        r'(?:lua|state|stateToInit)\s*\.new_usertype\s*<\s*([^>]+)\s*>\s*\(\s*"([^"]+)"',
        re.MULTILINE,
    ),
    "new_usertype_table": re.compile(
        r'(\w+)\s*\.new_usertype\s*<\s*([^>]+)\s*>\s*\(\s*"([^"]+)"',
        re.MULTILINE,
    ),
    "set_function": re.compile(
        r'(\w+)\s*\.set_function\s*\(\s*"([^"]+)"\s*,',
        re.MULTILINE,
    ),
    "table_assignment": re.compile(
        r'(\w+)\s*\[\s*"([^"]+)"\s*\]\s*=',
        re.MULTILINE,
    ),
    "new_enum": re.compile(
        r'(?:lua|state|stateToInit)\s*\.new_enum\s*\(\s*"([^"]+)"',
        re.MULTILINE,
    ),
    "create_table_with": re.compile(
        r'(\w+)\s*\[\s*"([^"]+)"\s*\]\s*=\s*(?:lua|state)\s*\.create_table_with\s*\(',
        re.MULTILINE,
    ),
    "bind_function": re.compile(
        r'rec\.bind_function\s*\(\s*(?:lua|state)\s*,\s*\{[^}]*\}\s*,\s*"([^"]+)"',
        re.MULTILINE,
    ),
    "bind_usertype": re.compile(
        r'rec\.bind_usertype\s*<\s*([^>]+)\s*>\s*\(\s*(?:lua|state|stateToInit)\s*,\s*"([^"]+)"',
        re.MULTILINE,
    ),
    "add_type": re.compile(
        r'rec\.add_type\s*\(\s*"([^"]+)"',
        re.MULTILINE,
    ),
    "record_method": re.compile(
        r'rec\.record_method\s*\(\s*"([^"]+)"\s*,\s*MethodDef\s*\{\s*"([^"]+)"',
        re.MULTILINE,
    ),
    "record_property": re.compile(
        r'rec\.record_property\s*\(\s*"([^"]+)"\s*,\s*(?:PropDef\s*)?\{\s*"([^"]+)"',
        re.MULTILINE,
    ),
}


@dataclass
class BindingRecord:
    """A single extracted binding record."""

    lua_name: str
    binding_type: str  # usertype, function, constant, enum, method, property
    cpp_type: str = ""
    signature: str = ""
    doc_id: str = ""
    source_ref: str = ""
    extraction_confidence: str = CONFIDENCE_MEDIUM
    tier: int = 0
    verified: bool = False

    def to_dict(self) -> dict:
        """Convert to dictionary for JSON serialization."""
        return {
            "lua_name": self.lua_name,
            "type": self.binding_type,
            "cpp_type": self.cpp_type,
            "signature": self.signature,
            "doc_id": self.doc_id,
            "source_ref": self.source_ref,
            "extraction_confidence": self.extraction_confidence,
            "tier": self.tier,
            "verified": self.verified,
        }


@dataclass
class SystemInventory:
    """Inventory of bindings for a single system."""

    system_name: str
    source_files: list[str] = field(default_factory=list)
    usertypes: list[BindingRecord] = field(default_factory=list)
    functions: list[BindingRecord] = field(default_factory=list)
    constants: list[BindingRecord] = field(default_factory=list)
    enums: list[BindingRecord] = field(default_factory=list)
    methods: list[BindingRecord] = field(default_factory=list)
    properties: list[BindingRecord] = field(default_factory=list)
    unrecognized_patterns: list[dict] = field(default_factory=list)

    def to_dict(self) -> dict:
        """Convert to dictionary for JSON serialization."""
        return {
            "schema_version": "1.0",
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "system": self.system_name,
            "source_files": self.source_files,
            "summary": {
                "usertypes": len(self.usertypes),
                "functions": len(self.functions),
                "constants": len(self.constants),
                "enums": len(self.enums),
                "methods": len(self.methods),
                "properties": len(self.properties),
                "low_confidence": sum(
                    1
                    for b in (
                        self.usertypes
                        + self.functions
                        + self.constants
                        + self.enums
                        + self.methods
                        + self.properties
                    )
                    if b.extraction_confidence == CONFIDENCE_LOW
                ),
                "unrecognized_patterns": len(self.unrecognized_patterns),
            },
            "bindings": {
                "usertypes": [b.to_dict() for b in self.usertypes],
                "functions": [b.to_dict() for b in self.functions],
                "constants": [b.to_dict() for b in self.constants],
                "enums": [b.to_dict() for b in self.enums],
                "methods": [b.to_dict() for b in self.methods],
                "properties": [b.to_dict() for b in self.properties],
            },
            "unrecognized_patterns": self.unrecognized_patterns,
        }


def generate_doc_id(lua_name: str, binding_type: str) -> str:
    """Generate a stable doc_id for a binding."""
    safe_name = lua_name.replace(".", "_").replace(":", "_")
    return f"sol2_{binding_type}_{safe_name}".lower()


def extract_from_file(
    filepath: Path, system_name: str
) -> tuple[list[BindingRecord], list[BindingRecord], list[BindingRecord],
           list[BindingRecord], list[BindingRecord], list[BindingRecord], list[dict]]:
    """Extract bindings from a single C++ file.

    Returns:
        Tuple of (usertypes, functions, constants, enums, methods, properties, unrecognized)
    """
    usertypes: list[BindingRecord] = []
    functions: list[BindingRecord] = []
    constants: list[BindingRecord] = []
    enums: list[BindingRecord] = []
    methods: list[BindingRecord] = []
    properties: list[BindingRecord] = []
    unrecognized: list[dict] = []

    try:
        content = filepath.read_text(encoding="utf-8", errors="replace")
    except OSError as e:
        print(f"[EXTRACT]   WARNING: Could not read {filepath}: {e}", file=sys.stderr)
        return usertypes, functions, constants, enums, methods, properties, unrecognized

    lines = content.split("\n")
    file_ref = str(filepath)

    # Track line numbers for matches
    def find_line_number(match_start: int) -> int:
        return content[:match_start].count("\n") + 1

    # Extract new_usertype patterns
    for match in PATTERNS["new_usertype"].finditer(content):
        cpp_type, lua_name = match.groups()
        line_num = find_line_number(match.start())
        usertypes.append(
            BindingRecord(
                lua_name=lua_name,
                binding_type="usertype",
                cpp_type=cpp_type.strip(),
                doc_id=generate_doc_id(lua_name, "usertype"),
                source_ref=f"{file_ref}:{line_num}",
                extraction_confidence=CONFIDENCE_HIGH,
            )
        )
        print(f"[EXTRACT]   Found usertype: {lua_name} (type: {cpp_type.strip()})")

    # Extract new_usertype with table prefix
    for match in PATTERNS["new_usertype_table"].finditer(content):
        table_name, cpp_type, lua_name = match.groups()
        # Skip if table_name is lua/state (already captured above)
        if table_name in ("lua", "state", "stateToInit"):
            continue
        line_num = find_line_number(match.start())
        full_name = f"{table_name}.{lua_name}" if table_name != "lua" else lua_name
        usertypes.append(
            BindingRecord(
                lua_name=full_name,
                binding_type="usertype",
                cpp_type=cpp_type.strip(),
                doc_id=generate_doc_id(full_name, "usertype"),
                source_ref=f"{file_ref}:{line_num}",
                extraction_confidence=CONFIDENCE_MEDIUM,
            )
        )
        print(f"[EXTRACT]   Found usertype: {full_name} (type: {cpp_type.strip()})")

    # Extract set_function patterns
    for match in PATTERNS["set_function"].finditer(content):
        table_name, func_name = match.groups()
        line_num = find_line_number(match.start())
        # Determine confidence based on context
        confidence = CONFIDENCE_HIGH if table_name in ("lua", "physics_table", "tbl") else CONFIDENCE_MEDIUM
        full_name = f"{table_name}.{func_name}" if table_name not in ("lua", "tbl") else func_name
        functions.append(
            BindingRecord(
                lua_name=full_name,
                binding_type="function",
                doc_id=generate_doc_id(full_name, "function"),
                source_ref=f"{file_ref}:{line_num}",
                extraction_confidence=confidence,
            )
        )
        print(f"[EXTRACT]   Found function: {full_name} (confidence: {confidence})")

    # Extract new_enum patterns
    for match in PATTERNS["new_enum"].finditer(content):
        (enum_name,) = match.groups()
        line_num = find_line_number(match.start())
        enums.append(
            BindingRecord(
                lua_name=enum_name,
                binding_type="enum",
                doc_id=generate_doc_id(enum_name, "enum"),
                source_ref=f"{file_ref}:{line_num}",
                extraction_confidence=CONFIDENCE_HIGH,
            )
        )
        print(f"[EXTRACT]   Found enum: {enum_name}")

    # Extract create_table_with patterns (typically enums/constants)
    for match in PATTERNS["create_table_with"].finditer(content):
        table_name, enum_name = match.groups()
        line_num = find_line_number(match.start())
        full_name = f"{table_name}.{enum_name}" if table_name not in ("lua", "state") else enum_name
        enums.append(
            BindingRecord(
                lua_name=full_name,
                binding_type="enum",
                doc_id=generate_doc_id(full_name, "enum"),
                source_ref=f"{file_ref}:{line_num}",
                extraction_confidence=CONFIDENCE_MEDIUM,
            )
        )
        print(f"[EXTRACT]   Found enum: {full_name}")

    # Extract bind_function (BindingRecorder style)
    for match in PATTERNS["bind_function"].finditer(content):
        (func_name,) = match.groups()
        line_num = find_line_number(match.start())
        functions.append(
            BindingRecord(
                lua_name=func_name,
                binding_type="function",
                doc_id=generate_doc_id(func_name, "function"),
                source_ref=f"{file_ref}:{line_num}",
                extraction_confidence=CONFIDENCE_HIGH,
            )
        )
        print(f"[EXTRACT]   Found function (recorder): {func_name}")

    # Extract bind_usertype (BindingRecorder style)
    for match in PATTERNS["bind_usertype"].finditer(content):
        cpp_type, lua_name = match.groups()
        line_num = find_line_number(match.start())
        usertypes.append(
            BindingRecord(
                lua_name=lua_name,
                binding_type="usertype",
                cpp_type=cpp_type.strip(),
                doc_id=generate_doc_id(lua_name, "usertype"),
                source_ref=f"{file_ref}:{line_num}",
                extraction_confidence=CONFIDENCE_HIGH,
            )
        )
        print(f"[EXTRACT]   Found usertype (recorder): {lua_name}")

    # Extract add_type (type registration)
    for match in PATTERNS["add_type"].finditer(content):
        (type_name,) = match.groups()
        line_num = find_line_number(match.start())
        # Skip if already captured as usertype
        if not any(u.lua_name == type_name for u in usertypes):
            usertypes.append(
                BindingRecord(
                    lua_name=type_name,
                    binding_type="usertype",
                    doc_id=generate_doc_id(type_name, "usertype"),
                    source_ref=f"{file_ref}:{line_num}",
                    extraction_confidence=CONFIDENCE_MEDIUM,
                )
            )
            print(f"[EXTRACT]   Found type: {type_name}")

    # Extract record_method
    for match in PATTERNS["record_method"].finditer(content):
        type_name, method_name = match.groups()
        line_num = find_line_number(match.start())
        full_name = f"{type_name}:{method_name}"
        methods.append(
            BindingRecord(
                lua_name=full_name,
                binding_type="method",
                doc_id=generate_doc_id(full_name, "method"),
                source_ref=f"{file_ref}:{line_num}",
                extraction_confidence=CONFIDENCE_HIGH,
            )
        )
        print(f"[EXTRACT]   Found method: {full_name}")

    # Extract record_property
    for match in PATTERNS["record_property"].finditer(content):
        type_name, prop_name = match.groups()
        line_num = find_line_number(match.start())
        full_name = f"{type_name}.{prop_name}"
        properties.append(
            BindingRecord(
                lua_name=full_name,
                binding_type="property",
                doc_id=generate_doc_id(full_name, "property"),
                source_ref=f"{file_ref}:{line_num}",
                extraction_confidence=CONFIDENCE_HIGH,
            )
        )
        print(f"[EXTRACT]   Found property: {full_name}")

    # Detect potential unrecognized patterns
    # Look for sol:: patterns that weren't matched
    sol_pattern = re.compile(r'sol::\w+', re.MULTILINE)
    for match in sol_pattern.finditer(content):
        snippet = match.group()
        line_num = find_line_number(match.start())
        # Get context around the match
        line_start = content.rfind("\n", 0, match.start()) + 1
        line_end = content.find("\n", match.end())
        if line_end == -1:
            line_end = len(content)
        line_content = content[line_start:line_end].strip()

        # Skip common non-binding sol:: usages
        skip_patterns = ["sol::state", "sol::table", "sol::object", "sol::this_state",
                        "sol::lua_nil", "sol::property", "sol::readonly", "sol::type"]
        if any(sp in snippet for sp in skip_patterns):
            continue

        # Check if this line was already matched
        already_matched = False
        for pattern in PATTERNS.values():
            if pattern.search(line_content):
                already_matched = True
                break

        if not already_matched and "sol::" in line_content:
            # Might be an unrecognized pattern
            unrecognized.append({
                "line": line_num,
                "snippet": line_content[:200],
                "file": file_ref,
            })
            print(f"[EXTRACT]   WARNING: Unrecognized pattern at line {line_num}: {line_content[:80]}...")

    return usertypes, functions, constants, enums, methods, properties, unrecognized


def find_binding_files(src_dir: Path) -> Iterator[tuple[Path, str]]:
    """Find C++ files that likely contain Sol2 bindings.

    Yields:
        Tuples of (filepath, system_name)
    """
    # Map of directories to system names
    system_dirs = {
        "physics": "physics",
        "ui": "ui",
        "input": "input",
        "layer": "layer",
        "scripting": "scripting",
        "shaders": "shaders",
        "sound": "sound",
        "timer": "timer",
        "text": "text",
        "ldtk_loader": "ldtk",
        "gif": "gif",
        "localization": "localization",
        "save": "save",
        "event": "event",
        "anim": "animation",
        "render_groups": "render_groups",
        "composable_mechanics": "mechanics",
        "entity_gamestate_management": "gamestate",
        "tutorial": "tutorial",
        "transform": "transform",
        "telemetry": "telemetry",
        "util": "util",
    }

    for cpp_file in src_dir.rglob("*.cpp"):
        # Skip third_party
        if "third_party" in str(cpp_file):
            continue

        # Determine system name from path
        parts = cpp_file.parts
        system_name = "core"  # default

        for part in parts:
            if part in system_dirs:
                system_name = system_dirs[part]
                break

        # Only yield files that likely contain bindings
        content_preview = ""
        try:
            with open(cpp_file, "r", encoding="utf-8", errors="replace") as f:
                content_preview = f.read(5000)  # Check first 5KB
        except OSError:
            continue

        if any(pattern in content_preview for pattern in
               ["new_usertype", "set_function", "new_enum", "sol::", "BindingRecorder"]):
            yield cpp_file, system_name


def extract_all(src_dir: Path, output_dir: Path) -> dict[str, SystemInventory]:
    """Extract all bindings from source directory.

    Returns:
        Dictionary mapping system names to their inventories
    """
    print("[EXTRACT] === Sol2 Binding Extraction ===")

    inventories: dict[str, SystemInventory] = {}

    for filepath, system_name in find_binding_files(src_dir):
        print(f"[EXTRACT] Scanning {filepath}...")

        if system_name not in inventories:
            inventories[system_name] = SystemInventory(system_name=system_name)

        inv = inventories[system_name]
        inv.source_files.append(str(filepath))

        usertypes, functions, constants, enums, methods, properties, unrecognized = extract_from_file(
            filepath, system_name
        )

        inv.usertypes.extend(usertypes)
        inv.functions.extend(functions)
        inv.constants.extend(constants)
        inv.enums.extend(enums)
        inv.methods.extend(methods)
        inv.properties.extend(properties)
        inv.unrecognized_patterns.extend(unrecognized)

    # Print summaries
    for system_name, inv in inventories.items():
        print(f"\n[EXTRACT] === System Summary: {system_name} ===")
        print(f"[EXTRACT] Usertypes: {len(inv.usertypes)}")
        print(f"[EXTRACT] Functions: {len(inv.functions)}")
        print(f"[EXTRACT] Constants: {len(inv.constants)}")
        print(f"[EXTRACT] Enums: {len(inv.enums)}")
        print(f"[EXTRACT] Methods: {len(inv.methods)}")
        print(f"[EXTRACT] Properties: {len(inv.properties)}")

        low_conf = sum(
            1
            for b in (inv.usertypes + inv.functions + inv.constants + inv.enums + inv.methods + inv.properties)
            if b.extraction_confidence == CONFIDENCE_LOW
        )
        print(f"[EXTRACT] Low confidence: {low_conf} (review needed)")
        print(f"[EXTRACT] Unrecognized patterns: {len(inv.unrecognized_patterns)}")

    return inventories


def write_inventories(inventories: dict[str, SystemInventory], output_dir: Path) -> None:
    """Write inventory JSON files for each system."""
    output_dir.mkdir(parents=True, exist_ok=True)

    for system_name, inv in inventories.items():
        output_file = output_dir / f"bindings.{system_name}.json"
        print(f"[EXTRACT] Writing {output_file}")

        with open(output_file, "w", encoding="utf-8") as f:
            json.dump(inv.to_dict(), f, indent=2)


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Extract Sol2 Lua bindings from C++ source files."
    )
    parser.add_argument(
        "--src-dir",
        type=Path,
        default=Path("src"),
        help="Source directory to scan (default: src)",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("planning/inventory"),
        help="Output directory for JSON files (default: planning/inventory)",
    )
    parser.add_argument(
        "--system",
        type=str,
        default=None,
        help="Extract only a specific system (default: all)",
    )

    args = parser.parse_args()

    # Resolve paths relative to script location if not absolute
    script_dir = Path(__file__).parent
    project_root = script_dir.parent

    src_dir = args.src_dir if args.src_dir.is_absolute() else project_root / args.src_dir
    output_dir = args.output_dir if args.output_dir.is_absolute() else project_root / args.output_dir

    if not src_dir.exists():
        print(f"[EXTRACT] ERROR: Source directory not found: {src_dir}", file=sys.stderr)
        return 1

    inventories = extract_all(src_dir, output_dir)

    if args.system:
        if args.system not in inventories:
            print(f"[EXTRACT] ERROR: System '{args.system}' not found", file=sys.stderr)
            return 1
        inventories = {args.system: inventories[args.system]}

    write_inventories(inventories, output_dir)

    print("\n[EXTRACT] Complete.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
