#!/usr/bin/env python3
"""
Generate Lua type stubs for ECS components.

This script extracts key component classes from chugget_code_definitions.lua
and outputs a cleaner, focused file for IDE autocomplete.

Usage:
    python3 tools/lua-types/generate_component_types.py

Output:
    assets/scripts/types/components.generated.lua
"""

import re
import sys
from pathlib import Path
from typing import Dict, List, Tuple

# Components to extract (in stable, alphabetical order for deterministic output)
# These are the most commonly used components for gameplay scripting
# Note: Names must match exactly what's in chugget_code_definitions.lua
TARGET_COMPONENTS = sorted([
    "GameObject",
    "GameObjectMethods",
    "GameObjectState",
    "ScriptComponent",
    "Transform",
    "UIConfig",
    "UIElementComponent",
    "UIState",
    "UILayoutConfig",
    "UIStyleConfig",
    "UIContentConfig",
    "UIInteractionConfig",
])

# Additional type aliases for common patterns
COMMON_ALIASES = """
---@alias Entity number Entity ID (integer handle)
---@alias EntityID number Alias for Entity
---@alias ComponentType table Component type table used with component_cache.get
"""


def parse_class_definition(content: str, class_name: str) -> Tuple[str, str]:
    """
    Extract a @class definition and its fields from the content.

    Returns (class_doc, fields_doc) or ("", "") if not found.
    """
    # Pattern to find ---@class ClassName and everything until the next ---@class or end
    pattern = rf'(---@class {re.escape(class_name)}.*?(?=---@class|\Z))'

    match = re.search(pattern, content, re.DOTALL)
    if not match:
        return "", ""

    block = match.group(1).strip()

    # Split into class definition and table definition
    lines = block.split('\n')
    class_lines = []
    table_lines = []
    in_table = False

    for line in lines:
        stripped = line.strip()
        if stripped.startswith(f'{class_name} = {{'):
            in_table = True
            continue
        elif in_table and stripped == '}':
            break
        elif in_table:
            # Convert table field format to @field format
            # Example: "---@type number" + "actualX = nil," -> "---@field actualX number"
            if stripped.startswith('---@type'):
                # Next non-comment line has the field name
                continue
            elif '=' in stripped and not stripped.startswith('---'):
                # This is a field assignment like "actualX = nil,  -- The logical X position."
                field_match = re.match(r'(\w+)\s*=\s*\w+,?\s*--\s*(.*)', stripped)
                if field_match:
                    field_name = field_match.group(1)
                    comment = field_match.group(2)
                    # Look for the preceding @type annotation
                    for prev_line in reversed(class_lines[-5:]):
                        type_match = re.search(r'---@type\s+(.+)', prev_line)
                        if type_match:
                            field_type = type_match.group(1).strip()
                            table_lines.append(f"---@field {field_name} {field_type} {comment}")
                            break
        elif not in_table:
            class_lines.append(line)

    return '\n'.join(class_lines), '\n'.join(table_lines)


def extract_simplified_class(content: str, class_name: str) -> str:
    """
    Extract a simplified class definition with @field annotations.
    """
    # Find the class block
    pattern = rf'---@class {re.escape(class_name)}\n(.*?)(?=\n---@class|\Z)'
    match = re.search(pattern, content, re.DOTALL)

    if not match:
        return ""

    # Get everything after ---@class ClassName until next class or end
    block_content = match.group(0)

    # Find the table definition block
    table_pattern = rf'{re.escape(class_name)}\s*=\s*\{{\n(.*?)\n\}}'
    table_match = re.search(table_pattern, block_content, re.DOTALL)

    result_lines = [f"---@class {class_name}"]

    if table_match:
        table_content = table_match.group(1)

        # Parse fields from the table
        # Pattern: ---@type typename\n    fieldname = value,  -- comment
        field_blocks = re.findall(
            r'---@type\s+([^\n]+)\n\s*(\w+)\s*=\s*[^,]+,?\s*(?:--\s*(.*))?',
            table_content
        )

        for field_type, field_name, comment in field_blocks:
            field_type = field_type.strip()
            comment = comment.strip() if comment else ""
            if comment:
                result_lines.append(f"---@field {field_name} {field_type} {comment}")
            else:
                result_lines.append(f"---@field {field_name} {field_type}")

    return '\n'.join(result_lines)


def generate_component_types(source_path: Path, output_path: Path) -> bool:
    """
    Generate component type stubs from source definitions.

    Returns True on success, False on failure.
    """
    if not source_path.exists():
        print(f"Error: Source file not found: {source_path}", file=sys.stderr)
        return False

    content = source_path.read_text(encoding='utf-8')

    # Build output
    output_lines = [
        "---@meta",
        "--[[",
        "================================================================================",
        "COMPONENT TYPES - Auto-generated from chugget_code_definitions.lua",
        "================================================================================",
        "This file is GENERATED. Do not edit manually.",
        "",
        "To regenerate:",
        "    python3 tools/lua-types/generate_component_types.py",
        "",
        "These types provide IDE autocomplete for ECS components.",
        "]]",
        "",
        COMMON_ALIASES,
        "",
    ]

    # Extract each target component
    for class_name in TARGET_COMPONENTS:
        class_def = extract_simplified_class(content, class_name)
        if class_def:
            output_lines.append(class_def)
            output_lines.append("")
        else:
            output_lines.append(f"-- Note: {class_name} not found in source")
            output_lines.append("")

    # Add common component type globals
    output_lines.extend([
        "---------------------------------------------------------------------------",
        "-- Component Type Globals (for use with component_cache.get)",
        "---------------------------------------------------------------------------",
        "",
    ])

    for class_name in TARGET_COMPONENTS:
        output_lines.append(f"---@type {class_name}")
        output_lines.append(f"{class_name} = {{}}")
        output_lines.append("")

    # Write output
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text('\n'.join(output_lines), encoding='utf-8')

    print(f"Generated: {output_path}")
    return True


def main():
    """Main entry point."""
    # Determine paths relative to this script
    script_dir = Path(__file__).parent
    repo_root = script_dir.parent.parent

    source_path = repo_root / "assets" / "scripts" / "chugget_code_definitions.lua"
    output_path = repo_root / "assets" / "scripts" / "types" / "components.generated.lua"

    success = generate_component_types(source_path, output_path)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
