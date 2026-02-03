import sys
from pathlib import Path

import pytest

SCRIPT_DIR = Path(__file__).resolve().parents[1]
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import validate_schemas


def write_json(path: Path, payload: dict):
    path.write_text(__import__("json").dumps(payload), encoding="utf-8")


def test_valid_json_passes(tmp_path: Path):
    schema = {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "type": "object",
        "required": ["schema_version", "value"],
        "properties": {
            "schema_version": {"type": "string", "const": "1.0"},
            "value": {"type": "integer"},
        },
    }
    data = {"schema_version": "1.0", "value": 3}

    schema_path = tmp_path / "schema.json"
    data_path = tmp_path / "data.json"
    write_json(schema_path, schema)
    write_json(data_path, data)

    result = validate_schemas.validate_file(data_path, schema_path)
    assert result.valid is True
    assert result.errors == []


def test_invalid_json_fails_with_path(tmp_path: Path):
    schema = {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "type": "object",
        "required": ["schema_version", "value"],
        "properties": {
            "schema_version": {"type": "string", "const": "1.0"},
            "value": {"type": "integer"},
        },
    }
    data = {"schema_version": "1.0", "value": "bad"}

    schema_path = tmp_path / "schema.json"
    data_path = tmp_path / "data.json"
    write_json(schema_path, schema)
    write_json(data_path, data)

    result = validate_schemas.validate_file(data_path, schema_path)
    assert result.valid is False
    assert result.errors
    assert result.errors[0].path == "value"
    assert "is not of type" in result.errors[0].message
    assert result.errors[0].line >= 1


def test_yaml_input_validates(tmp_path: Path):
    schema = {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "type": "object",
        "required": ["schema_version", "rules"],
        "properties": {
            "schema_version": {"type": "string", "const": "1.0"},
            "rules": {"type": "array"},
        },
    }
    schema_path = tmp_path / "schema.json"
    write_json(schema_path, schema)

    yaml_path = tmp_path / "rules.yaml"
    yaml_path.write_text("schema_version: '1.0'\nrules: []\n", encoding="utf-8")

    result = validate_schemas.validate_file(yaml_path, schema_path, is_yaml=True)
    assert result.valid is True


def test_missing_file_reports_error(monkeypatch, tmp_path: Path, capsys):
    schema_path = tmp_path / "schema.json"
    write_json(schema_path, {"$schema": "https://json-schema.org/draft/2020-12/schema", "type": "object"})

    missing_path = tmp_path / "missing.json"

    def fake_expand_targets(_root: Path):
        return [(missing_path, schema_path, False)]

    monkeypatch.setattr(validate_schemas, "expand_targets", fake_expand_targets)
    monkeypatch.setattr(validate_schemas, "get_git_root", lambda: tmp_path)
    monkeypatch.setattr(sys, "argv", ["validate_schemas.py"])

    exit_code = validate_schemas.main()
    captured = capsys.readouterr()
    assert exit_code != 0
    assert "INVALID" in captured.out
    assert "File missing" in captured.out


def test_logging_prefix(capsys):
    validate_schemas.log("Test message", verbose=True)
    captured = capsys.readouterr()
    assert captured.out.startswith("[SCHEMA]")
    assert "Test message" in captured.out


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
