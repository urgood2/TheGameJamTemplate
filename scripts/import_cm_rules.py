#!/usr/bin/env python3
"""Import verified cm rule candidates into the cm playbook.

Requirements:
- Idempotent updates by rule_id
- Dedup by normalized fingerprint (category + rule_text)
- Import only status=verified
- Append traceability (Verified: Test: <test_ref>) to rule text
- Backup existing rules before mutation

Logging prefix: [CM-IMPORT]
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import yaml

LOG_PREFIX = "[CM-IMPORT]"

CANDIDATES_PATH = Path("planning/cm_rules_candidates.yaml")
BACKUP_PATH = Path("planning/cm_rules_backup.json")


@dataclass
class CmRule:
    rule_id: str | None
    category: str | None
    rule_text: str


@dataclass
class ImportStats:
    added: int = 0
    updated: int = 0
    skipped_unverified: int = 0
    skipped_duplicate: int = 0
    unchanged: int = 0


class ImportError(RuntimeError):
    """Custom error for import failures."""


def log(message: str, verbose: bool = True) -> None:
    if verbose:
        print(f"{LOG_PREFIX} {message}")


def get_iso8601() -> str:
    now = datetime.now(UTC)
    return now.strftime("%Y-%m-%dT%H:%M:%SZ")


def load_candidates(path: Path, verbose: bool = True) -> dict[str, Any]:
    log(f"Loading {path}...", verbose)
    with path.open(encoding="utf-8") as handle:
        return yaml.safe_load(handle) or {}


def normalize_text(text: str) -> str:
    normalized = text.lower()
    normalized = re.sub(r"\s+", " ", normalized)
    normalized = re.sub(r"[^\w\s]", "", normalized)
    return normalized.strip()


def strip_verification_suffix(text: str) -> str:
    return re.sub(r"\s*\(Verified: Test: .*\)\s*$", "", text).strip()


def compute_fingerprint(category: str | None, rule_text: str) -> str:
    base = f"{category or ''}:{rule_text}"
    normalized = normalize_text(base)
    digest = hashlib.sha256(normalized.encode("utf-8")).hexdigest()
    return digest[:16]


def format_rule_text(rule: dict[str, Any]) -> str:
    text = (rule.get("rule_text") or "").strip()
    test_ref = rule.get("test_ref")
    if test_ref:
        marker = f"Verified: Test: {test_ref}"
        if marker not in text:
            text = f"{text} ({marker})"
    return text


def run_cm_command(args: list[str]) -> subprocess.CompletedProcess:
    try:
        return subprocess.run(args, capture_output=True, text=True, check=False)
    except FileNotFoundError as exc:
        raise ImportError("cm command not found") from exc


def parse_existing_rules(payload: Any) -> list[CmRule]:
    if isinstance(payload, dict):
        rules = payload.get("rules")
        if rules is None:
            rules = payload.get("items")
        if rules is None:
            rules = payload.get("playbook")
        if rules is None:
            rules = []
    elif isinstance(payload, list):
        rules = payload
    else:
        rules = []

    parsed: list[CmRule] = []
    for item in rules:
        if not isinstance(item, dict):
            continue
        rule_id = item.get("rule_id") or item.get("id") or item.get("ruleId")
        category = item.get("category") or item.get("category_id") or item.get("group")
        rule_text = (
            item.get("rule_text")
            or item.get("text")
            or item.get("rule")
            or item.get("content")
            or ""
        )
        if not rule_text:
            continue
        parsed.append(CmRule(rule_id=rule_id, category=category, rule_text=rule_text))
    return parsed


def get_existing_rules(verbose: bool = True) -> list[CmRule]:
    try:
        result = run_cm_command(["cm", "playbook", "list", "--json"])
    except ImportError:
        log("WARNING: cm command not found; assuming empty playbook", verbose)
        return []

    if result.returncode != 0:
        log("WARNING: Failed to load existing rules; assuming empty playbook", verbose)
        return []

    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise ImportError("Failed to parse cm playbook list output") from exc
    return parse_existing_rules(payload)


def export_backup(existing: list[CmRule], path: Path, verbose: bool = True) -> None:
    log(f"Exporting backup to {path}...", verbose)
    payload = {
        "exported_at": get_iso8601(),
        "rule_count": len(existing),
        "rules": [
            {
                "rule_id": rule.rule_id,
                "category": rule.category,
                "rule_text": rule.rule_text,
            }
            for rule in existing
        ],
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")
    log("Backup complete.", verbose)


def build_existing_indexes(existing: list[CmRule]) -> tuple[dict[str, CmRule], set[str]]:
    by_id: dict[str, CmRule] = {}
    fingerprints: set[str] = set()

    for rule in existing:
        if rule.rule_id:
            by_id[rule.rule_id] = rule
        base_text = strip_verification_suffix(rule.rule_text)
        fp = compute_fingerprint(rule.category, base_text)
        fingerprints.add(fp)

    return by_id, fingerprints


def attempt_add_rule(rule_id: str | None, text: str, category: str) -> subprocess.CompletedProcess:
    base_cmd = ["cm", "playbook", "add", text, "--category", category]
    if rule_id:
        cmd_with_id = base_cmd + ["--rule-id", rule_id]
        result = run_cm_command(cmd_with_id)
        if result.returncode == 0:
            return result
        if "unknown flag" not in (result.stderr or "").lower():
            return result
    return run_cm_command(base_cmd)


def update_rule(rule_id: str, text: str, category: str) -> subprocess.CompletedProcess:
    cmd = ["cm", "playbook", "update", rule_id, "--text", text, "--category", category]
    return run_cm_command(cmd)


def import_rules(
    candidates: list[dict[str, Any]],
    existing: list[CmRule],
    dry_run: bool = False,
    verbose: bool = True,
) -> ImportStats:
    stats = ImportStats()
    by_id, existing_fingerprints = build_existing_indexes(existing)
    seen_fingerprints = set(existing_fingerprints)

    log("Importing verified rules...", verbose)
    for rule in candidates:
        rule_id = rule.get("rule_id")
        status = (rule.get("status") or "").lower()
        if status != "verified":
            log(f"  {rule_id}: SKIPPED - not verified", verbose)
            stats.skipped_unverified += 1
            continue

        category = rule.get("category") or ""
        formatted_text = format_rule_text(rule)
        base_text = strip_verification_suffix(formatted_text)

        if rule_id and rule_id in by_id:
            existing_rule = by_id[rule_id]
            existing_text = existing_rule.rule_text
            existing_category = existing_rule.category or ""
            if existing_text == formatted_text and existing_category == category:
                log(f"  {rule_id}: unchanged (idempotent)", verbose)
                stats.unchanged += 1
                continue
            if dry_run:
                log(f"  {rule_id}: would update existing rule (idempotent)", verbose)
                stats.updated += 1
                continue
            result = update_rule(rule_id, formatted_text, category)
            if result.returncode != 0:
                raise ImportError(f"Failed to update rule {rule_id}: {result.stderr}")
            log(f"  {rule_id}: updating existing rule (idempotent)", verbose)
            stats.updated += 1
            continue

        fingerprint = compute_fingerprint(category, base_text)
        if fingerprint in seen_fingerprints:
            log(f"  {rule_id}: SKIPPED - duplicate fingerprint", verbose)
            stats.skipped_duplicate += 1
            continue

        seen_fingerprints.add(fingerprint)

        if dry_run:
            log(f"  {rule_id}: would add to category {category}", verbose)
            stats.added += 1
            continue

        result = attempt_add_rule(rule_id, formatted_text, category)
        if result.returncode != 0:
            raise ImportError(f"Failed to add rule {rule_id}: {result.stderr}")
        log(f"  {rule_id}: adding to category {category}", verbose)
        stats.added += 1

    return stats


def summarize_status_counts(candidates: list[dict[str, Any]]) -> dict[str, int]:
    counts = {"verified": 0, "unverified": 0, "pending": 0}
    for rule in candidates:
        status = (rule.get("status") or "").lower()
        if status == "verified":
            counts["verified"] += 1
        elif status == "unverified":
            counts["unverified"] += 1
        else:
            counts["pending"] += 1
    return counts


def run_import(
    candidates_path: Path = CANDIDATES_PATH,
    backup_path: Path = BACKUP_PATH,
    dry_run: bool = False,
    verbose: bool = True,
) -> ImportStats:
    log("=== cm Rules Import ===", verbose)
    candidates_data = load_candidates(candidates_path, verbose)
    candidates = candidates_data.get("rules", []) or []

    log(f"Found {len(candidates)} rule candidates", verbose)
    counts = summarize_status_counts(candidates)
    log(f"  Verified: {counts['verified']}", verbose)
    log(f"  Unverified: {counts['unverified']} (will skip)", verbose)
    log(f"  Pending: {counts['pending']} (will skip)", verbose)

    existing_rules = get_existing_rules(verbose)

    if not dry_run:
        export_backup(existing_rules, backup_path, verbose)

    candidates_sorted = sorted(
        candidates,
        key=lambda r: (r.get("category") or "", r.get("rule_id") or ""),
    )

    stats = import_rules(candidates_sorted, existing_rules, dry_run=dry_run, verbose=verbose)

    log("=== SUMMARY ===", verbose)
    log(f"Added: {stats.added}", verbose)
    log(f"Updated: {stats.updated}", verbose)
    log(f"Skipped (duplicate): {stats.skipped_duplicate}", verbose)
    log(f"Skipped (not verified): {stats.skipped_unverified}", verbose)

    return stats


def main() -> int:
    parser = argparse.ArgumentParser(description="Import verified cm rule candidates")
    parser.add_argument("--dry-run", action="store_true", help="Show what would change")
    parser.add_argument(
        "--import",
        dest="do_import",
        action="store_true",
        help="Apply changes (default behavior)",
    )
    parser.add_argument("--verbose", action="store_true", help="Verbose logging")
    args = parser.parse_args()

    if args.dry_run and args.do_import:
        raise SystemExit("Cannot combine --dry-run with --import")

    run_import(dry_run=args.dry_run is True, verbose=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
