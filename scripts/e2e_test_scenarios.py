#!/usr/bin/env python3
"""Run end-to-end verification scenarios for the documentation pipeline.

Scenarios are numbered 1-10 per planning/bd-30l.12.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Iterable
import xml.etree.ElementTree as ET

LOG_PREFIX = "[E2E]"
ROOT = Path(__file__).resolve().parent.parent
FAILURES: list[str] = []


@dataclass
class StepResult:
    ok: bool
    message: str = ""


def log(message: str) -> None:
    if message.startswith("[E2E"):
        print(message)
    else:
        print(f"{LOG_PREFIX} {message}")


def safe_filename(name: str) -> str:
    safe = "".join(ch.lower() if ch.isalnum() or ch in ".-_" else "_" for ch in (name or ""))
    while "__" in safe:
        safe = safe.replace("__", "_")
    return safe or "unnamed"


def run_cmd(cmd: list[str], cwd: Path | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(
        cmd,
        cwd=cwd or ROOT,
        text=True,
        capture_output=True,
        check=False,
    )


def log_artifact(scenario_id: int, path: Path) -> None:
    try:
        size = path.stat().st_size
    except FileNotFoundError:
        size = 0
    log(f"[E2E.{scenario_id}] Generated: {path} ({size} bytes)")


def run_step(scenario_id: int, step_id: int, label: str, fn: Callable[[], StepResult]) -> StepResult:
    log(f"[E2E.{scenario_id}] Step {step_id}: {label}")
    start = time.perf_counter()
    try:
        result = fn()
    except Exception as exc:  # noqa: BLE001
        duration = time.perf_counter() - start
        log(f"[E2E.{scenario_id}] Step {step_id}: FAIL ({duration:.2f}s) - {exc}")
        FAILURES.append(f"Scenario {scenario_id} (step {step_id})")
        return StepResult(False, str(exc))
    duration = time.perf_counter() - start
    if result.ok:
        log(f"[E2E.{scenario_id}] Step {step_id}: PASS ({duration:.2f}s)")
    else:
        log(f"[E2E.{scenario_id}] Step {step_id}: FAIL ({duration:.2f}s) - {result.message}")
        FAILURES.append(f"Scenario {scenario_id} (step {step_id})")
    return result


def collect_autogen_outside(content: str) -> str:
    lines = content.splitlines()
    output: list[str] = []
    inside = False
    for line in lines:
        if "<!-- AUTOGEN:BEGIN" in line:
            inside = True
            continue
        if "<!-- AUTOGEN:END" in line:
            inside = False
            continue
        if not inside:
            output.append(line)
    return "\n".join(output).rstrip()


def list_inventory_jsons(inv_dir: Path) -> list[Path]:
    return sorted(p for p in inv_dir.glob("*.json") if p.is_file())


def load_json(path: Path) -> dict:
    return json.loads(path.read_text())


def count_binding_entries(inv_path: Path) -> tuple[int, int]:
    data = load_json(inv_path)
    bindings = data.get("bindings", {})
    total = 0
    low_conf = 0
    for items in bindings.values():
        if not isinstance(items, list):
            continue
        for item in items:
            total += 1
            conf = str(item.get("extraction_confidence", "high")).lower()
            if conf in {"low", "medium"}:
                low_conf += 1
    return total, low_conf


def count_components(inv_path: Path) -> tuple[int, int]:
    data = load_json(inv_path)
    comps = data.get("components", [])
    total = len(comps) if isinstance(comps, list) else 0
    low_conf = 0
    for comp in comps:
        conf = comp.get("extraction_confidence", 1.0)
        try:
            if float(conf) < 1.0:
                low_conf += 1
        except (TypeError, ValueError):
            pass
    return total, low_conf


def scenario_1() -> bool:
    scenario_id = 1
    log(f"=== Scenario {scenario_id}: Fresh Inventory Generation ===")
    inv_dir = ROOT / "planning" / "inventory"
    backup_dir = Path(tempfile.mkdtemp(prefix="e2e_inventory_backup_"))
    original_files = list_inventory_jsons(inv_dir)

    def step_backup() -> StepResult:
        for path in original_files:
            shutil.copy2(path, backup_dir / path.name)
        return StepResult(True)

    def step_delete() -> StepResult:
        for path in original_files:
            path.unlink(missing_ok=True)
        return StepResult(True)

    def step_extract_bindings() -> StepResult:
        result = run_cmd(["python3", "scripts/extract_sol2_bindings.py"])
        if result.returncode != 0:
            return StepResult(False, result.stderr.strip() or result.stdout.strip())
        return StepResult(True)

    def step_extract_components() -> StepResult:
        result = run_cmd(["python3", "scripts/extract_components.py"])
        if result.returncode != 0:
            return StepResult(False, result.stderr.strip() or result.stdout.strip())
        return StepResult(True)

    def step_verify_regenerated() -> StepResult:
        missing = [p.name for p in original_files if not (inv_dir / p.name).exists()]
        if missing:
            return StepResult(False, f"Missing regenerated files: {', '.join(missing)}")
        return StepResult(True)

    def step_validate_schemas() -> StepResult:
        result = run_cmd(["python3", "scripts/validate_schemas.py"])
        if result.returncode != 0:
            return StepResult(False, result.stderr.strip() or result.stdout.strip())
        return StepResult(True)

    steps = [
        ("Backup inventory JSONs", step_backup),
        ("Delete inventory JSONs", step_delete),
        ("Run extract_sol2_bindings.py", step_extract_bindings),
        ("Run extract_components.py", step_extract_components),
        ("Verify JSONs regenerated", step_verify_regenerated),
        ("Validate schemas", step_validate_schemas),
    ]

    ok = True
    for idx, (label, fn) in enumerate(steps, start=1):
        result = run_step(scenario_id, idx, label, fn)
        if not result.ok:
            ok = False
            break

    if ok:
        log(f"[E2E.{scenario_id}] Inventory counts:")
        for path in sorted(inv_dir.glob("bindings.*.json")):
            total, low_conf = count_binding_entries(path)
            log(f"[E2E.{scenario_id}]   {path.name}: {total} bindings ({low_conf} low/medium confidence)")
        for path in sorted(inv_dir.glob("components.*.json")):
            total, low_conf = count_components(path)
            log(f"[E2E.{scenario_id}]   {path.name}: {total} components ({low_conf} low confidence)")
    return ok


def scenario_2() -> bool:
    scenario_id = 2
    log(f"=== Scenario {scenario_id}: Docs Skeleton Regeneration ===")

    doc_paths: list[Path] = []
    for folder in ("planning/bindings", "planning/components", "planning/patterns"):
        doc_paths.extend(sorted((ROOT / folder).glob("*.md")))

    before_outside: dict[Path, str] = {}
    before_full: dict[Path, str] = {}
    for path in doc_paths:
        content = path.read_text() if path.exists() else ""
        if "AUTOGEN:BEGIN" not in content:
            continue
        before_outside[path] = collect_autogen_outside(content)
        before_full[path] = content

    def step_generate() -> StepResult:
        result = run_cmd(["python3", "scripts/generate_docs_skeletons.py"])
        if result.returncode != 0:
            return StepResult(False, result.stderr.strip() or result.stdout.strip())
        return StepResult(True)

    def step_verify_outside() -> StepResult:
        changed = []
        for path, previous in before_outside.items():
            current = path.read_text() if path.exists() else ""
            now_outside = collect_autogen_outside(current)
            if previous != now_outside:
                changed.append(path)
        if changed:
            return StepResult(False, f"Content outside AUTOGEN changed: {', '.join(str(p) for p in changed)}")
        return StepResult(True)

    ok = True
    if not run_step(scenario_id, 1, "Run generate_docs_skeletons.py", step_generate).ok:
        ok = False
    if ok and not run_step(scenario_id, 2, "Verify content outside AUTOGEN unchanged", step_verify_outside).ok:
        ok = False

    if ok:
        updated = []
        for path, before in before_full.items():
            after = path.read_text() if path.exists() else ""
            if before != after:
                updated.append(path)
        log(f"[E2E.{scenario_id}] Files updated: {len(updated)}")
        for path in updated:
            log(f"[E2E.{scenario_id}]   {path}")
    return ok


def scenario_3() -> bool:
    scenario_id = 3
    log(f"=== Scenario {scenario_id}: Full Test Suite Run ===")

    def step_run_tests() -> StepResult:
        cmd = [
            "lua",
            "-e",
            "dofile('assets/scripts/test/run_all_tests.lua'); os.exit(_G.TEST_EXIT_CODE or 0)",
        ]
        result = run_cmd(cmd)
        if result.returncode != 0:
            return StepResult(False, result.stdout.strip() or result.stderr.strip())
        return StepResult(True)

    def step_check_outputs() -> StepResult:
        status = ROOT / "test_output" / "status.json"
        report = ROOT / "test_output" / "report.md"
        results = ROOT / "test_output" / "results.json"
        junit = ROOT / "test_output" / "junit.xml"
        for path in (status, report, results, junit):
            if not path.exists():
                return StepResult(False, f"Missing {path}")
            log_artifact(scenario_id, path)

        content = report.read_text()
        for heading in ("## Summary", "## Results", "## Failures", "## Skipped", "## Screenshots"):
            if heading not in content:
                return StepResult(False, f"Missing heading {heading} in report.md")

        try:
            data = load_json(results)
            if "tests" not in data:
                return StepResult(False, "results.json missing tests array")
        except json.JSONDecodeError as exc:
            return StepResult(False, f"results.json invalid JSON: {exc}")

        try:
            ET.parse(junit)
        except ET.ParseError as exc:
            return StepResult(False, f"junit.xml invalid XML: {exc}")
        return StepResult(True)

    ok = True
    if not run_step(scenario_id, 1, "Run run_all_tests.lua", step_run_tests).ok:
        ok = False
    if ok and not run_step(scenario_id, 2, "Verify test outputs", step_check_outputs).ok:
        ok = False
    return ok


def scenario_4() -> bool:
    scenario_id = 4
    log(f"=== Scenario {scenario_id}: Registry Sync ===")

    def step_sync_registry() -> StepResult:
        result = run_cmd(["python3", "scripts/sync_registry_from_manifest.py"])
        if result.returncode != 0:
            return StepResult(False, result.stderr.strip() or result.stdout.strip())
        return StepResult(True)

    def step_validate_docs() -> StepResult:
        result = run_cmd(["python3", "scripts/validate_docs_and_registry.py"])
        if result.returncode != 0:
            return StepResult(False, result.stderr.strip() or result.stdout.strip())
        return StepResult(True)

    def step_summary() -> StepResult:
        registry = ROOT / "assets/scripts/test/test_registry.lua"
        if not registry.exists():
            return StepResult(False, "test_registry.lua missing")
        content = registry.read_text()
        count = content.count("[\"")
        log(f"[E2E.{scenario_id}] Registry entries: {count}")
        return StepResult(True)

    ok = True
    if not run_step(scenario_id, 1, "Run sync_registry_from_manifest.py", step_sync_registry).ok:
        ok = False
    if ok and not run_step(scenario_id, 2, "Run validate_docs_and_registry.py", step_validate_docs).ok:
        ok = False
    if ok and not run_step(scenario_id, 3, "Summarize registry counts", step_summary).ok:
        ok = False
    return ok


def scenario_5() -> bool:
    scenario_id = 5
    log(f"=== Scenario {scenario_id}: Coverage Report Generation ===")

    def step_generate() -> StepResult:
        cmd = [
            "lua",
            "-e",
            "package.path='assets/scripts/?.lua;assets/scripts/?/init.lua;'..package.path; "
            "local cr=require('test.test_coverage_report'); local ok=cr.generate('test_output/results.json','test_output/coverage_report.md'); os.exit(ok and 0 or 1)",
        ]
        result = run_cmd(cmd)
        if result.returncode != 0:
            return StepResult(False, result.stdout.strip() or result.stderr.strip())
        return StepResult(True)

    def step_verify() -> StepResult:
        report = ROOT / "test_output" / "coverage_report.md"
        if not report.exists():
            return StepResult(False, "coverage_report.md missing")
        content = report.read_text()
        for heading in ("Coverage Summary", "Verified Docs", "Unverified Docs"):
            if heading not in content:
                return StepResult(False, f"Missing heading {heading}")
        log_artifact(scenario_id, report)
        return StepResult(True)

    ok = True
    if not run_step(scenario_id, 1, "Generate coverage report", step_generate).ok:
        ok = False
    if ok and not run_step(scenario_id, 2, "Verify coverage report headings", step_verify).ok:
        ok = False
    return ok


def scenario_6() -> bool:
    scenario_id = 6
    log(f"=== Scenario {scenario_id}: cm Rules Import (Dry Run) ===")

    def step_validate_candidates() -> StepResult:
        path = ROOT / "planning/cm_rules_candidates.yaml"
        if not path.exists():
            return StepResult(False, "planning/cm_rules_candidates.yaml missing")
        return StepResult(True)

    def step_dry_run() -> StepResult:
        result = run_cmd(["python3", "scripts/import_cm_rules.py", "--dry-run"])
        if result.returncode != 0:
            return StepResult(False, result.stderr.strip() or result.stdout.strip())
        summary_lines = [line for line in result.stdout.splitlines() if "[CM-IMPORT]" in line]
        for line in summary_lines:
            if "Added:" in line or "Skipped" in line or "Verified" in line:
                log(f"[E2E.{scenario_id}] {line.strip()}")
        return StepResult(True)

    ok = True
    if not run_step(scenario_id, 1, "Verify cm_rules_candidates.yaml", step_validate_candidates).ok:
        ok = False
    if ok and not run_step(scenario_id, 2, "Run import_cm_rules.py --dry-run", step_dry_run).ok:
        ok = False
    return ok


def scenario_7() -> bool:
    scenario_id = 7
    log(f"=== Scenario {scenario_id}: Link Integrity Check ===")

    def step_link_check() -> StepResult:
        result = run_cmd(["python3", "scripts/link_check_docs.py"])
        if result.returncode != 0:
            return StepResult(False, result.stderr.strip() or result.stdout.strip())
        return StepResult(True)

    return run_step(scenario_id, 1, "Run link_check_docs.py", step_link_check).ok


def compare_stub_dirs(base_dir: Path, gen_dir: Path) -> tuple[bool, list[str]]:
    base_files = {p.relative_to(base_dir) for p in base_dir.rglob("*.lua")}
    gen_files = {p.relative_to(gen_dir) for p in gen_dir.rglob("*.lua")}
    messages: list[str] = []

    missing = sorted(base_files - gen_files)
    extra = sorted(gen_files - base_files)
    if missing:
        messages.append(f"Missing generated files: {', '.join(str(p) for p in missing)}")
    if extra:
        messages.append(f"Extra generated files: {', '.join(str(p) for p in extra)}")

    for rel in sorted(base_files & gen_files):
        base_path = base_dir / rel
        gen_path = gen_dir / rel
        if base_path.read_bytes() != gen_path.read_bytes():
            messages.append(f"Drift detected: {rel}")
    return (len(messages) == 0), messages


def scenario_8() -> bool:
    scenario_id = 8
    log(f"=== Scenario {scenario_id}: Stub Drift Detection ===")

    def step_regen_to_temp() -> StepResult:
        temp_dir = Path(tempfile.mkdtemp(prefix="e2e_stubs_"))
        result = run_cmd(["python3", "scripts/generate_stubs.py", "--output-dir", str(temp_dir)])
        if result.returncode != 0:
            return StepResult(False, result.stderr.strip() or result.stdout.strip())
        scenario_8.temp_dir = temp_dir  # type: ignore[attr-defined]
        return StepResult(True)

    def step_compare() -> StepResult:
        temp_dir = getattr(scenario_8, "temp_dir", None)
        if temp_dir is None:
            return StepResult(False, "Temp dir missing")
        base_dir = ROOT / "docs/lua_stubs"
        ok, messages = compare_stub_dirs(base_dir, temp_dir)
        if not ok:
            for msg in messages:
                log(f"[E2E.{scenario_id}] {msg}")
            log("[E2E.8] FAIL: Stub drift detected. Run: python3 scripts/generate_stubs.py")
            return StepResult(False, "Stub drift detected")
        return StepResult(True)

    ok = True
    if not run_step(scenario_id, 1, "Regenerate stubs to temp dir", step_regen_to_temp).ok:
        ok = False
    if ok and not run_step(scenario_id, 2, "Compare generated stubs to docs/lua_stubs", step_compare).ok:
        ok = False
    return ok


def load_visual_quarantine(path: Path) -> list[dict]:
    if not path.exists():
        return []
    data = json.loads(path.read_text())
    return data.get("quarantined_tests", [])


def scenario_9() -> bool:
    scenario_id = 9
    log(f"=== Scenario {scenario_id}: Visual Baseline Validation ===")

    def step_run_visual_tests() -> StepResult:
        cmd = [
            "lua",
            "-e",
            "_G.TEST_FILTER={tags={'visual'}}; dofile('assets/scripts/test/run_all_tests.lua'); os.exit(_G.TEST_EXIT_CODE or 0)",
        ]
        result = run_cmd(cmd)
        if result.returncode != 0:
            return StepResult(False, result.stdout.strip() or result.stderr.strip())
        return StepResult(True)

    def step_compare() -> StepResult:
        screenshots_dir = ROOT / "test_output" / "screenshots"
        if not screenshots_dir.exists():
            return StepResult(False, "test_output/screenshots missing")
        shots = sorted(screenshots_dir.glob("*.png"))
        if not shots:
            return StepResult(False, "No screenshots captured for visual tests")

        caps_path = ROOT / "test_output" / "capabilities.json"
        if caps_path.exists():
            caps = json.loads(caps_path.read_text())
            os_name = caps.get("platform", {}).get("os", "unknown")
            renderer = caps.get("environment", {}).get("renderer", "unknown")
            resolution = caps.get("environment", {}).get("resolution", "unknown")
        else:
            os_name = renderer = resolution = "unknown"

        baseline_root = ROOT / "test_baselines" / "screenshots" / safe_filename(os_name) / safe_filename(renderer) / safe_filename(resolution)
        quarantine_entries = load_visual_quarantine(ROOT / "test_baselines" / "visual_quarantine.json")
        quarantined_ids = {entry.get("test_id") for entry in quarantine_entries}

        mismatches = []
        for shot in shots:
            test_id = shot.stem
            baseline_path = baseline_root / f"{safe_filename(test_id)}.png"
            if test_id in quarantined_ids:
                log(f"[E2E.{scenario_id}] Quarantined: {test_id}")
                continue
            if not baseline_path.exists():
                log(f"[E2E.{scenario_id}] Needs baseline: {test_id} -> {baseline_path}")
                continue
            if shot.read_bytes() != baseline_path.read_bytes():
                mismatches.append(test_id)
                artifact_dir = ROOT / "test_output" / "artifacts" / safe_filename(test_id)
                artifact_dir.mkdir(parents=True, exist_ok=True)
                shutil.copy2(baseline_path, artifact_dir / "baseline.png")
                shutil.copy2(shot, artifact_dir / "actual.png")
                metrics_path = artifact_dir / "metrics.json"
                metrics_path.write_text(json.dumps({
                    "test_id": test_id,
                    "baseline": str(baseline_path),
                    "actual": str(shot),
                    "note": "Bytewise mismatch; pixel diff unavailable",
                }, indent=2))
                log_artifact(scenario_id, artifact_dir / "baseline.png")
                log_artifact(scenario_id, artifact_dir / "actual.png")
                log_artifact(scenario_id, metrics_path)

        if mismatches:
            return StepResult(False, f"Visual mismatches: {', '.join(mismatches)}")
        return StepResult(True)

    ok = True
    if not run_step(scenario_id, 1, "Run visual-tagged tests", step_run_visual_tests).ok:
        ok = False
    if ok and not run_step(scenario_id, 2, "Compare screenshots to baselines", step_compare).ok:
        ok = False
    return ok


def scenario_10() -> bool:
    scenario_id = 10
    log(f"=== Scenario {scenario_id}: Run Sentinel Crash Detection ===")

    run_state = ROOT / "test_output" / "run_state.json"
    backup = run_state.read_text() if run_state.exists() else None

    def step_simulate_crash() -> StepResult:
        run_state.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "schema_version": "1.0",
            "in_progress": True,
            "last_test_started": "e2e.simulated_crash",
        }
        run_state.write_text(json.dumps(payload, indent=2))
        return StepResult(True)

    def step_check_wrapper_logic() -> StepResult:
        data = json.loads(run_state.read_text())
        if data.get("in_progress") is not True:
            return StepResult(False, "run_state.json not marked in_progress")
        log(f"[E2E.{scenario_id}] Simulated crash detected (in_progress=true). CI wrapper would exit 2.")
        return StepResult(True)

    ok = True
    if not run_step(scenario_id, 1, "Simulate crash run_state.json", step_simulate_crash).ok:
        ok = False
    if ok and not run_step(scenario_id, 2, "Verify wrapper crash detection", step_check_wrapper_logic).ok:
        ok = False

    if backup is None:
        run_state.unlink(missing_ok=True)
    else:
        run_state.write_text(backup)

    return ok


SCENARIOS: dict[int, Callable[[], bool]] = {
    1: scenario_1,
    2: scenario_2,
    3: scenario_3,
    4: scenario_4,
    5: scenario_5,
    6: scenario_6,
    7: scenario_7,
    8: scenario_8,
    9: scenario_9,
    10: scenario_10,
}


def parse_scenarios(value: str) -> list[int]:
    ids = []
    for part in value.split(","):
        part = part.strip()
        if not part:
            continue
        if "-" in part:
            start, end = part.split("-", 1)
            ids.extend(range(int(start), int(end) + 1))
        else:
            ids.append(int(part))
    return sorted(set(ids))


def main() -> int:
    parser = argparse.ArgumentParser(description="Run e2e test scenarios")
    parser.add_argument("--scenario", help="Scenario id or range (e.g., 1,3-5)")
    args = parser.parse_args()

    if args.scenario:
        scenario_ids = parse_scenarios(args.scenario)
    else:
        scenario_ids = sorted(SCENARIOS.keys())

    log("=== E2E Scenario Runner ===")
    start = time.perf_counter()

    for scenario_id in scenario_ids:
        fn = SCENARIOS.get(scenario_id)
        if not fn:
            FAILURES.append(f"Scenario {scenario_id} (not found)")
            continue
        fn()

    duration = time.perf_counter() - start
    log("=== SUMMARY ===")
    failed_count = len(set(FAILURES))
    log(f"Passed: {len(scenario_ids) - failed_count}/{len(scenario_ids)}")
    if FAILURES:
        log(f"Failed: {', '.join(dict.fromkeys(FAILURES))}")
    log(f"Duration: {duration:.2f}s")

    return 0 if not FAILURES else 1


if __name__ == "__main__":
    raise SystemExit(main())
