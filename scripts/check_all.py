#!/usr/bin/env python3
"""Full verification pipeline runner with deterministic logging."""

from __future__ import annotations

import argparse
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

LOG_PREFIX = "[CHECK]"


@dataclass(frozen=True)
class Step:
    name: str
    commands: list[list[str]]


def log(message: str) -> None:
    print(f"{LOG_PREFIX} {message}")


def format_duration(seconds: float) -> str:
    return f"{seconds:.1f}s"


def run_command(cmd: list[str], dry_run: bool) -> bool:
    log(f"  Running {' '.join(cmd)}...")
    if dry_run:
        return True
    result = subprocess.run(cmd, check=False)
    return result.returncode == 0


def run_step(
    index: int,
    total: int,
    step: Step,
    dry_run: bool,
    fail_step: int | None,
) -> tuple[bool, float]:
    log(f"[{index}/{total}] {step.name}...")
    start = time.time()
    ok = True

    if fail_step == index:
        log("  Forced failure (fail-step)")
        ok = False
    else:
        for cmd in step.commands:
            if not run_command(cmd, dry_run):
                ok = False
                break

    duration = time.time() - start
    if ok:
        log(f"  PASS ({format_duration(duration)})")
    else:
        log(f"  FAIL ({format_duration(duration)})")
    return ok, duration


def build_steps(python: str) -> list[Step]:
    lua_expr = "dofile('assets/scripts/test/run_all_tests.lua'); os.exit(_G.TEST_EXIT_CODE or 0)"
    coverage_expr = (
        "package.path='assets/scripts/?.lua;assets/scripts/?/init.lua;'..package.path; "
        "local ok, mod = pcall(require, 'test.test_coverage_report'); "
        "if ok and mod and mod.generate then "
        "  local out_ok = mod.generate('test_output/results.json','test_output/coverage_report.md'); "
        "  if not out_ok then error('coverage_report generation failed') end "
        "else error('coverage_report module missing') end"
    )
    return [
        Step("Validating toolchain", [[python, "scripts/doctor.py"]]),
        Step(
            "Regenerating inventories",
            [
                [python, "scripts/extract_sol2_bindings.py"],
                [python, "scripts/extract_components.py"],
            ],
        ),
        Step("Regenerating scope stats", [[python, "scripts/recount_scope_stats.py"]]),
        Step("Regenerating doc skeletons", [[python, "scripts/generate_docs_skeletons.py"]]),
        Step("Validating schemas", [[python, "scripts/validate_schemas.py"]]),
        Step("Syncing registry from manifest", [[python, "scripts/sync_registry_from_manifest.py"]]),
        Step(
            "Validating docs consistency",
            [
                [python, "scripts/validate_docs_and_registry.py"],
                [python, "scripts/link_check_docs.py"],
            ],
        ),
        Step("Checking evidence blocks", [[python, "scripts/sync_docs_evidence.py", "--check"]]),
        Step(
            "Running test suite",
            [
                ["lua", "-e", lua_expr],
                ["lua", "-e", coverage_expr],
            ],
        ),
    ]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run the full verification pipeline.")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Log steps without executing commands.",
    )
    parser.add_argument(
        "--fail-step",
        type=int,
        default=None,
        help="Force a specific step to fail (1-based index).",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    project_root = Path(__file__).resolve().parent.parent
    python = sys.executable or "python3"
    steps = build_steps(python)

    # Ensure commands run from repo root.
    try:
        project_root.chdir()
    except AttributeError:
        # Python <3.12 compatibility
        import os
        os.chdir(project_root)

    log("==========================================")
    log("=== Full Verification Pipeline ===")
    log("==========================================")
    log(f"Started at: {datetime.now(timezone.utc).isoformat()}")
    log("")

    total_steps = len(steps)
    failed_steps: list[str] = []
    passed_steps = 0
    overall_start = time.time()

    for idx, step in enumerate(steps, start=1):
        ok, _ = run_step(idx, total_steps, step, args.dry_run, args.fail_step)
        if ok:
            passed_steps += 1
        else:
            failed_steps.append(f"[{idx}/{total_steps}] {step.name}")
            if not args.dry_run:
                break

    total_duration = time.time() - overall_start

    log("==========================================")
    if failed_steps:
        log("=== FINAL RESULT: FAIL ===")
        log("Failed steps:")
        for step in failed_steps:
            log(f"  - {step}")
        log(f"Total time: {format_duration(total_duration)}")
        log(f"Passed steps: {passed_steps}/{total_steps}")
        return 1

    log("=== FINAL RESULT: PASS ===")
    log(f"Total time: {format_duration(total_duration)}")
    log(f"Passed steps: {passed_steps}/{total_steps}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
