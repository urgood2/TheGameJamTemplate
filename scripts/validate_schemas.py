#!/usr/bin/env python3
"""Validate output files against JSON Schemas.

Supports JSON and YAML inputs. Designed for CI validation with stable logging.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

try:
    import yaml
except ImportError:  # pragma: no cover
    yaml = None

try:
    import jsonschema
except ImportError:  # pragma: no cover
    jsonschema = None

LOG_PREFIX = "[SCHEMA]"


@dataclass
class ValidationErrorInfo:
    path: str
    message: str
    line: int


@dataclass
class ValidationResult:
    path: Path
    schema_path: Path
    valid: bool
    errors: list[ValidationErrorInfo]
    schema_version_mismatch: bool


def log(message: str, verbose: bool = True) -> None:
    if verbose:
        print(f"{LOG_PREFIX} {message}")


def get_git_root() -> Path:
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            check=True,
        )
        return Path(result.stdout.strip())
    except (subprocess.CalledProcessError, FileNotFoundError):
        return Path.cwd()


def load_json(path: Path) -> dict:
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def load_yaml(path: Path) -> dict:
    if yaml is None:
        raise RuntimeError("PyYAML is required to validate YAML inputs")
    with open(path, encoding="utf-8") as f:
        return yaml.safe_load(f)


def schema_version_expected(schema: dict) -> str | None:
    props = schema.get("properties", {}) if isinstance(schema, dict) else {}
    version = props.get("schema_version", {}) if isinstance(props, dict) else {}
    if isinstance(version, dict):
        return version.get("const")
    return None


def schema_version_actual(payload: dict) -> str | None:
    if isinstance(payload, dict):
        return payload.get("schema_version")
    return None


def error_path_string(error_path: Iterable[object]) -> str:
    parts = []
    for part in error_path:
        if isinstance(part, int):
            if not parts:
                parts.append(f"[{part}]")
            else:
                parts[-1] = f"{parts[-1]}[{part}]"
        else:
            parts.append(str(part))
    return ".".join(parts) if parts else "<root>"


def find_line_number(text: str, path: str) -> int:
    if path in ("", "<root>"):
        return 1
    # Best-effort: find the last key token in the text
    token = path.split(".")[-1]
    if "[" in token:
        token = token.split("[")[0]
    if not token:
        return 1
    needle = f'"{token}"'
    for idx, line in enumerate(text.splitlines(), start=1):
        if needle in line:
            return idx
    return 1


def validate_payload(payload: dict, schema: dict, raw_text: str) -> tuple[bool, list[ValidationErrorInfo]]:
    if jsonschema is None:
        raise RuntimeError("jsonschema is required to validate schemas")
    validator = jsonschema.Draft202012Validator(schema)
    errors = []
    for error in sorted(validator.iter_errors(payload), key=lambda e: e.path):
        path = error_path_string(error.path)
        line = find_line_number(raw_text, path)
        errors.append(ValidationErrorInfo(path=path, message=error.message, line=line))
    return len(errors) == 0, errors


def validate_file(path: Path, schema_path: Path, is_yaml: bool = False) -> ValidationResult:
    payload = load_yaml(path) if is_yaml else load_json(path)
    schema = load_json(schema_path)
    raw_text = path.read_text(encoding="utf-8")

    valid, errors = validate_payload(payload, schema, raw_text)

    expected_version = schema_version_expected(schema)
    actual_version = schema_version_actual(payload)
    mismatch = expected_version is not None and actual_version is not None and expected_version != actual_version

    return ValidationResult(
        path=path,
        schema_path=schema_path,
        valid=valid,
        errors=errors,
        schema_version_mismatch=mismatch,
    )


def expand_targets(root: Path) -> list[tuple[Path, Path, bool]]:
    schema_root = root / "planning" / "schemas"
    targets: list[tuple[Path, Path, bool]] = []

    def add_single(path: Path, schema_name: str, is_yaml: bool = False) -> None:
        targets.append((path, schema_root / schema_name, is_yaml))

    def add_glob(pattern: str, schema_name: str) -> None:
        matches = sorted((root / pattern).parent.glob(Path(pattern).name))
        if not matches:
            targets.append((root / pattern, schema_root / schema_name, False))
        else:
            for match in matches:
                targets.append((match, schema_root / schema_name, False))

    add_single(root / "test_output" / "status.json", "status.schema.json")
    add_single(root / "test_output" / "results.json", "results.schema.json")
    add_single(root / "test_output" / "capabilities.json", "capabilities.schema.json")
    add_single(root / "test_output" / "run_state.json", "run_state.schema.json")
    add_single(root / "test_output" / "test_manifest.json", "test_manifest.schema.json")

    add_glob("planning/inventory/bindings.*.json", "bindings_inventory.schema.json")
    add_glob("planning/inventory/components.*.json", "components_inventory.schema.json")
    add_glob("planning/inventory/patterns.*.json", "patterns_inventory.schema.json")
    add_glob("planning/inventory/frequency.*.json", "frequency.schema.json")
    add_single(root / "planning" / "inventory" / "stats.json", "stats.schema.json")

    add_single(
        root / "planning" / "cm_rules_candidates.yaml",
        "cm_rules_candidates.schema.json",
        is_yaml=True,
    )

    return targets


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate outputs against schemas")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose logging")
    args = parser.parse_args()

    if jsonschema is None:
        print("jsonschema is required to validate schemas", file=sys.stderr)
        return 2

    root = get_git_root()
    targets = expand_targets(root)

    log(f"Validating {len(targets)} files against schemas...", True)

    valid_count = 0
    invalid_count = 0
    mismatch_count = 0
    exit_code = 0

    for path, schema_path, is_yaml in targets:
        log(f"{path}: validating against {schema_path.name}...", True)
        if not path.exists():
            log(f"{path}: INVALID", True)
            log("  - Line 1: <root>: File missing", True)
            invalid_count += 1
            exit_code = 1
            continue
        try:
            result = validate_file(path, schema_path, is_yaml=is_yaml)
        except Exception as exc:
            log(f"{path}: INVALID", True)
            log(f"  - Line 1: <root>: {exc}", True)
            invalid_count += 1
            exit_code = 1
            continue

        if result.schema_version_mismatch:
            mismatch_count += 1
            expected = schema_version_expected(load_json(result.schema_path))
            actual = schema_version_actual(load_yaml(path) if is_yaml else load_json(path))
            log(
                f"{path}: WARNING schema_version mismatch (file={actual}, schema={expected})",
                True,
            )

        if result.valid:
            log(f"{path}: VALID", True)
            valid_count += 1
        else:
            log(f"{path}: INVALID", True)
            for error in result.errors:
                log(f"  - Line {error.line}: {error.path}: {error.message}", True)
            invalid_count += 1
            exit_code = 1

    log("=== SUMMARY ===", True)
    log(f"Valid: {valid_count}", True)
    log(f"Invalid: {invalid_count}", True)
    log(f"Schema version mismatches: {mismatch_count}", True)

    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
