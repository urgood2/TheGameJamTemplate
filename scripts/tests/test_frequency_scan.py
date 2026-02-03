import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parents[1]
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from frequency_scan import scan_frequency  # noqa: E402


def _entry_map(output: dict) -> dict:
    return {item["name"]: item for item in output["items"]}


def test_token_aware_ignores_comments_and_strings(tmp_path: Path):
    lua = (
        "-- physics.segment_query in comment\n"
        "local s = \"physics.segment_query in string\"\n"
        "physics.segment_query()\n"
    )
    file_path = tmp_path / "sample.lua"
    file_path.write_text(lua, encoding="utf-8")

    logs: list[str] = []
    output, _fallback = scan_frequency(
        names=["physics.segment_query"],
        roots=[tmp_path],
        system="physics",
        mode="token_aware",
        occurrence_threshold=10,
        logger=logs.append,
        file_paths=[file_path],
        project_root=tmp_path,
    )

    entry = _entry_map(output)["physics.segment_query"]
    assert entry["total_occurrences"] == 1
    assert entry["file_lines"]["sample.lua"] == [3]


def test_multiline_comment_handling(tmp_path: Path):
    lua = (
        "--[[\n"
        "physics.segment_query\n"
        "]]\n"
        "physics.segment_query()\n"
    )
    file_path = tmp_path / "comment.lua"
    file_path.write_text(lua, encoding="utf-8")

    output, _fallback = scan_frequency(
        names=["physics.segment_query"],
        roots=[tmp_path],
        system="physics",
        mode="token_aware",
        occurrence_threshold=10,
        logger=lambda _msg: None,
        file_paths=[file_path],
        project_root=tmp_path,
    )

    entry = _entry_map(output)["physics.segment_query"]
    assert entry["total_occurrences"] == 1
    assert entry["file_lines"]["comment.lua"] == [4]


def test_regex_fallback_on_tokenizer_failure(tmp_path: Path):
    lua = "local s = \"unterminated\nphysics.segment_query()\n"
    file_path = tmp_path / "broken.lua"
    file_path.write_text(lua, encoding="utf-8")

    output, fallback_used = scan_frequency(
        names=["physics.segment_query"],
        roots=[tmp_path],
        system="physics",
        mode="token_aware",
        occurrence_threshold=10,
        logger=lambda _msg: None,
        file_paths=[file_path],
        project_root=tmp_path,
    )

    entry = _entry_map(output)["physics.segment_query"]
    assert fallback_used is True
    assert entry["total_occurrences"] == 1


def test_alias_matching_records_canonical_name(tmp_path: Path):
    lua = "UIBox()\n"
    file_path = tmp_path / "alias.lua"
    file_path.write_text(lua, encoding="utf-8")

    output, _fallback = scan_frequency(
        names=["ui.box"],
        roots=[tmp_path],
        system="ui",
        mode="token_aware",
        aliases={"ui.box": ["UIBox"]},
        occurrence_threshold=10,
        logger=lambda _msg: None,
        file_paths=[file_path],
        project_root=tmp_path,
    )

    entry = _entry_map(output)["ui.box"]
    assert "UIBox" in entry["matched_aliases"]
    assert entry["alias_hits"]["UIBox"] == 1
    assert entry["total_occurrences"] == 1


def test_high_frequency_rule_files_or_occurrences(tmp_path: Path):
    files = {
        "a.lua": "foo()\n",
        "b.lua": "foo()\n",
        "c.lua": "foo()\n",
        "d.lua": "bar()\nbar()\n",
        "e.lua": "baz()\n",
    }
    file_paths = []
    for name, content in files.items():
        path = tmp_path / name
        path.write_text(content, encoding="utf-8")
        file_paths.append(path)

    output, _fallback = scan_frequency(
        names=["foo", "bar", "baz"],
        roots=[tmp_path],
        system="core",
        mode="token_aware",
        occurrence_threshold=2,
        logger=lambda _msg: None,
        file_paths=file_paths,
        project_root=tmp_path,
    )

    entries = _entry_map(output)
    assert entries["foo"]["high_frequency"] is True
    assert "files>=3" in entries["foo"]["high_frequency_reason"]

    assert entries["bar"]["high_frequency"] is True
    assert "occurrences>=2" in entries["bar"]["high_frequency_reason"]

    assert entries["baz"]["high_frequency"] is False


def test_logging_prefixes_stable(tmp_path: Path):
    lua = "alpha()\n"
    file_path = tmp_path / "log.lua"
    file_path.write_text(lua, encoding="utf-8")

    logs: list[str] = []
    scan_frequency(
        names=["alpha"],
        roots=[tmp_path],
        system="core",
        mode="token_aware",
        occurrence_threshold=10,
        logger=logs.append,
        file_paths=[file_path],
        project_root=tmp_path,
    )

    assert logs
    assert logs[0].startswith("[FREQ] === Frequency Scan for core ===")
    for line in logs:
        assert line.startswith("[FREQ]")
