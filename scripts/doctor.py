#!/usr/bin/env python3
"""
Toolchain validation script for TheGameJamTemplate.

Validates that all required tooling is installed and accessible before
running automation scripts. Designed for CI fast-failure and developer
environment verification.

Usage:
    python3 scripts/doctor.py [--json] [--verbose]

Exit codes:
    0: All required tools available
    1: Missing required dependencies
"""

from __future__ import annotations

import argparse
import json
import os
import platform
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from collections.abc import Sequence

# Logging prefix for parseable output
LOG_PREFIX = "[DOCTOR]"

# Minimum Python version required
MIN_PYTHON_VERSION = (3, 9)


@dataclass
class ToolCheck:
    """Result of a tool availability check."""

    name: str
    required: bool = True
    found: bool = False
    version: str | None = None
    path: str | None = None
    install_hint: str = ""
    purpose: str = ""


@dataclass
class DoctorResult:
    """Aggregate results of all tool checks."""

    checks: list[ToolCheck] = field(default_factory=list)

    @property
    def required_found(self) -> int:
        return sum(1 for c in self.checks if c.required and c.found)

    @property
    def required_total(self) -> int:
        return sum(1 for c in self.checks if c.required)

    @property
    def optional_found(self) -> int:
        return sum(1 for c in self.checks if not c.required and c.found)

    @property
    def optional_total(self) -> int:
        return sum(1 for c in self.checks if not c.required)

    @property
    def is_ready(self) -> bool:
        return self.required_found == self.required_total

    def to_dict(self) -> dict:
        """Convert to JSON-serializable dict."""
        return {
            "ready": self.is_ready,
            "required": {"found": self.required_found, "total": self.required_total},
            "optional": {"found": self.optional_found, "total": self.optional_total},
            "checks": [
                {
                    "name": c.name,
                    "required": c.required,
                    "found": c.found,
                    "version": c.version,
                    "path": c.path,
                }
                for c in self.checks
            ],
        }


def log(msg: str, indent: int = 0) -> None:
    """Print with doctor prefix."""
    prefix = "  " * indent if indent else ""
    print(f"{LOG_PREFIX} {prefix}{msg}")


def get_install_hint(tool: str) -> str:
    """Get platform-appropriate install hint."""
    system = platform.system().lower()

    hints = {
        "python": {
            "linux": "apt install python3 (Ubuntu/Debian) or dnf install python3 (Fedora)",
            "darwin": "brew install python3",
            "windows": "Download from https://python.org or winget install Python.Python.3",
        },
        "ripgrep": {
            "linux": "apt install ripgrep (Ubuntu/Debian) or cargo install ripgrep",
            "darwin": "brew install ripgrep",
            "windows": "choco install ripgrep or cargo install ripgrep",
        },
        "cm": {
            "linux": "Install from https://github.com/joshuashin/cm or pip install cm-cli",
            "darwin": "Install from https://github.com/joshuashin/cm or pip install cm-cli",
            "windows": "pip install cm-cli",
        },
        "git": {
            "linux": "apt install git (Ubuntu/Debian)",
            "darwin": "brew install git or xcode-select --install",
            "windows": "Download from https://git-scm.com or winget install Git.Git",
        },
        "jsonschema": {
            "linux": "pip install jsonschema",
            "darwin": "pip install jsonschema",
            "windows": "pip install jsonschema",
        },
    }

    if tool in hints:
        return hints[tool].get(system, hints[tool].get("linux", ""))
    return ""


def run_command(cmd: Sequence[str], timeout: int = 10) -> tuple[int, str, str]:
    """Run a command and return (returncode, stdout, stderr)."""
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        return result.returncode, result.stdout, result.stderr
    except FileNotFoundError:
        return -1, "", "Command not found"
    except subprocess.TimeoutExpired:
        return -2, "", "Command timed out"
    except Exception as e:
        return -3, "", str(e)


def check_python_version(verbose: bool = False) -> ToolCheck:
    """Check Python version meets minimum requirement."""
    check = ToolCheck(
        name="Python",
        required=True,
        purpose="Required for automation scripts",
        install_hint=get_install_hint("python"),
    )

    version_info = sys.version_info
    version_str = f"{version_info.major}.{version_info.minor}.{version_info.micro}"
    check.path = sys.executable

    if version_info >= MIN_PYTHON_VERSION:
        check.found = True
        check.version = version_str
    else:
        check.version = f"{version_str} (need >= {MIN_PYTHON_VERSION[0]}.{MIN_PYTHON_VERSION[1]})"

    return check


def check_ripgrep(verbose: bool = False) -> ToolCheck:
    """Check ripgrep availability."""
    check = ToolCheck(
        name="ripgrep",
        required=True,
        purpose="Required for frequency scanning",
        install_hint=get_install_hint("ripgrep"),
    )

    rg_path = shutil.which("rg")
    if not rg_path:
        return check

    check.path = rg_path
    returncode, stdout, _ = run_command(["rg", "--version"])

    if returncode == 0:
        check.found = True
        # Parse version from "ripgrep 14.0.3" or similar
        match = re.search(r"ripgrep\s+(\d+\.\d+\.\d+)", stdout)
        if match:
            check.version = match.group(1)
        else:
            check.version = stdout.split("\n")[0].strip()

    return check


def check_cm_cli(verbose: bool = False) -> ToolCheck:
    """Check cm CLI availability (optional)."""
    check = ToolCheck(
        name="cm",
        required=False,
        purpose="Optional for Phase 8 playbook population",
        install_hint=get_install_hint("cm"),
    )

    cm_path = shutil.which("cm")
    if not cm_path:
        return check

    check.path = cm_path
    returncode, stdout, stderr = run_command(["cm", "--version"])

    if returncode == 0:
        check.found = True
        # Parse version - format varies
        version_text = stdout.strip() or stderr.strip()
        match = re.search(r"(\d+\.\d+\.\d+)", version_text)
        if match:
            check.version = match.group(1)
        else:
            check.version = version_text.split("\n")[0].strip() or "unknown"

    return check


def check_git(verbose: bool = False) -> ToolCheck:
    """Check git availability (optional)."""
    check = ToolCheck(
        name="git",
        required=False,
        purpose="Optional for commit tracking",
        install_hint=get_install_hint("git"),
    )

    git_path = shutil.which("git")
    if not git_path:
        return check

    check.path = git_path
    returncode, stdout, _ = run_command(["git", "--version"])

    if returncode == 0:
        check.found = True
        # Parse "git version 2.43.0"
        match = re.search(r"git version\s+(\d+\.\d+\.\d+)", stdout)
        if match:
            check.version = match.group(1)
        else:
            check.version = stdout.strip()

    return check


def check_jsonschema(verbose: bool = False) -> ToolCheck:
    """Check jsonschema Python package availability."""
    check = ToolCheck(
        name="jsonschema",
        required=True,
        purpose="Required for schema validation",
        install_hint=get_install_hint("jsonschema"),
    )

    try:
        import jsonschema as js
        from importlib.metadata import version as get_version

        check.found = True
        try:
            check.version = get_version("jsonschema")
        except Exception:
            check.version = getattr(js, "__version__", "unknown")
        check.path = str(Path(js.__file__).parent)
    except ImportError:
        pass

    return check


def check_pytest(verbose: bool = False) -> ToolCheck:
    """Check pytest availability (optional for local dev)."""
    check = ToolCheck(
        name="pytest",
        required=False,
        purpose="Optional for running unit tests locally",
        install_hint="pip install pytest",
    )

    try:
        import pytest
        from importlib.metadata import version as get_version

        check.found = True
        try:
            check.version = get_version("pytest")
        except Exception:
            check.version = getattr(pytest, "__version__", "unknown")
        check.path = str(Path(pytest.__file__).parent)
    except ImportError:
        pass

    return check


def run_doctor(verbose: bool = False) -> DoctorResult:
    """Run all tool checks."""
    result = DoctorResult()

    log("Checking toolchain requirements...")

    # Required checks
    for check_fn in [
        check_python_version,
        check_ripgrep,
        check_jsonschema,
    ]:
        check = check_fn(verbose)
        result.checks.append(check)

        status = "FOUND" if check.found else "NOT FOUND"
        version_info = f" {check.version}" if check.version else ""
        path_info = f" at {check.path}" if check.path else ""

        log(f"{check.name}: {status}{version_info}{path_info}")

        if not check.found:
            if check.install_hint:
                log(f"Install: {check.install_hint}", indent=1)
            if check.purpose:
                log(f"Required for: {check.purpose}", indent=1)

    # Optional checks
    for check_fn in [
        check_cm_cli,
        check_git,
        check_pytest,
    ]:
        check = check_fn(verbose)
        result.checks.append(check)

        status = "FOUND" if check.found else "NOT FOUND"
        version_info = f" {check.version}" if check.version else ""
        path_info = f" at {check.path}" if check.path else ""
        optional_marker = " (optional)" if not check.required else ""

        log(f"{check.name}: {status}{version_info}{path_info}{optional_marker}")

        if not check.found and verbose:
            if check.install_hint:
                log(f"Install: {check.install_hint}", indent=1)
            if check.purpose:
                log(f"Purpose: {check.purpose}", indent=1)

    return result


def print_summary(result: DoctorResult) -> None:
    """Print summary of check results."""
    log("=== SUMMARY ===")
    log(f"Required: {result.required_found}/{result.required_total} found")
    log(f"Optional: {result.optional_found}/{result.optional_total} found")

    if result.is_ready:
        log("Status: READY")
    else:
        log("Status: MISSING DEPENDENCIES - fix before proceeding")

        # List missing required
        missing = [c for c in result.checks if c.required and not c.found]
        if missing:
            log("Missing required tools:")
            for c in missing:
                log(f"- {c.name}: {c.install_hint}", indent=1)


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(description="Validate toolchain requirements")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")
    args = parser.parse_args()

    result = run_doctor(args.verbose)

    if args.json:
        print(json.dumps(result.to_dict(), indent=2))
    else:
        print_summary(result)

    return 0 if result.is_ready else 1


if __name__ == "__main__":
    sys.exit(main())
