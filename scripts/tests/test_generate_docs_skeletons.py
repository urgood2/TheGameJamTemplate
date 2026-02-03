import sys
from pathlib import Path

import pytest

SCRIPT_DIR = Path(__file__).resolve().parents[1]
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from generate_docs_skeletons import InventoryTarget, log, update_doc


def write_inventory(path: Path):
    data = {
        "bindings": {
            "functions": [
                {
                    "lua_name": "core.ping",
                    "type": "function",
                    "signature": "void ping()",
                    "source_ref": "src/core.cpp:12",
                }
            ]
        }
    }
    path.write_text(__import__("json").dumps(data), encoding="utf-8")


def test_preserves_manual_content(tmp_path: Path):
    inventory = tmp_path / "bindings.core.json"
    output = tmp_path / "bindings" / "core_bindings.md"
    output.parent.mkdir(parents=True, exist_ok=True)
    write_inventory(inventory)

    output.write_text(
        "Manual intro\n\n<!-- AUTOGEN:BEGIN binding_list -->\nold\n<!-- AUTOGEN:END binding_list -->\n\nManual footer\n",
        encoding="utf-8",
    )

    target = InventoryTarget(inventory, output, "binding_list")
    ok = update_doc(target, check=False, verbose=False)
    assert ok is True

    content = output.read_text(encoding="utf-8")
    assert "Manual intro" in content
    assert "Manual footer" in content
    assert "core.ping" in content


def test_missing_markers_appends(tmp_path: Path):
    inventory = tmp_path / "bindings.core.json"
    output = tmp_path / "bindings" / "core_bindings.md"
    output.parent.mkdir(parents=True, exist_ok=True)
    write_inventory(inventory)

    output.write_text("Manual only\n", encoding="utf-8")

    target = InventoryTarget(inventory, output, "binding_list")
    ok = update_doc(target, check=False, verbose=False)
    assert ok is True

    content = output.read_text(encoding="utf-8")
    assert "AUTOGEN:BEGIN binding_list" in content
    assert "core.ping" in content


def test_idempotent(tmp_path: Path):
    inventory = tmp_path / "bindings.core.json"
    output = tmp_path / "bindings" / "core_bindings.md"
    output.parent.mkdir(parents=True, exist_ok=True)
    write_inventory(inventory)

    output.write_text(
        "<!-- AUTOGEN:BEGIN binding_list -->\nold\n<!-- AUTOGEN:END binding_list -->\n",
        encoding="utf-8",
    )

    target = InventoryTarget(inventory, output, "binding_list")
    update_doc(target, check=False, verbose=False)
    first = output.read_text(encoding="utf-8")
    update_doc(target, check=False, verbose=False)
    second = output.read_text(encoding="utf-8")
    assert first == second


def test_check_mode(tmp_path: Path):
    inventory = tmp_path / "bindings.core.json"
    output = tmp_path / "bindings" / "core_bindings.md"
    output.parent.mkdir(parents=True, exist_ok=True)
    write_inventory(inventory)

    output.write_text(
        "<!-- AUTOGEN:BEGIN binding_list -->\nold\n<!-- AUTOGEN:END binding_list -->\n",
        encoding="utf-8",
    )

    target = InventoryTarget(inventory, output, "binding_list")
    assert update_doc(target, check=True, verbose=False) is False


def test_logging_prefix(capsys):
    log("test message", verbose=True)
    captured = capsys.readouterr()
    assert captured.out.startswith("[DOCS]")
    assert "test message" in captured.out


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
