import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parents[1]
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from strip_lua_comments import strip_comments


def test_strip_comments_removes_comments_preserves_strings():
    source = (
        "local a = 1 -- LINE_COMMENT\n"
        "local s = \"-- not comment\" -- TRAILING\n"
        "--[[\nBLOCK_COMMENT\n]]\n"
        "local t = '-- also not'\n"
    )
    result = strip_comments(source)

    assert "LINE_COMMENT" not in result
    assert "BLOCK_COMMENT" not in result
    assert "\"-- not comment\"" in result
    assert "'-- also not'" in result
    assert result.count("\n") == source.count("\n")


def test_strip_comments_cli_tmp_path(tmp_path):
    src_path = tmp_path / "input.lua"
    dst_path = tmp_path / "output.lua"
    src_path.write_text("local a = 1 -- comment\n", encoding="utf-8")

    script_path = SCRIPT_DIR / "strip_lua_comments.py"
    result = subprocess.run(
        [sys.executable, str(script_path), str(src_path), str(dst_path)],
        capture_output=True,
        text=True,
    )

    assert result.returncode == 0, result.stderr
    output = dst_path.read_text(encoding="utf-8")
    assert "--" not in output
    assert "local a = 1" in output
