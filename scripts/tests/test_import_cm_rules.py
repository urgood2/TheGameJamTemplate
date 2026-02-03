import json
from pathlib import Path

import pytest

import import_cm_rules


class FakeCompleted:
    def __init__(self, returncode=0, stdout="", stderr=""):
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr


class FakeCm:
    def __init__(self, rules=None):
        self.rules = rules or []
        self.calls = []

    def handle(self, args):
        self.calls.append(args)
        if args[:3] == ["cm", "playbook", "list"]:
            payload = {"rules": self.rules}
            return FakeCompleted(stdout=json.dumps(payload))
        if args[:3] == ["cm", "playbook", "add"]:
            text = args[3]
            category = args[5] if "--category" in args else "unknown"
            rule_id = None
            if "--rule-id" in args:
                idx = args.index("--rule-id")
                rule_id = args[idx + 1]
            self.rules.append({
                "rule_id": rule_id or f"auto-{len(self.rules)+1}",
                "category": category,
                "rule_text": text,
            })
            return FakeCompleted()
        if args[:3] == ["cm", "playbook", "update"]:
            rule_id = args[3]
            text = args[5]
            category = args[7] if len(args) > 7 else "unknown"
            for rule in self.rules:
                if rule.get("rule_id") == rule_id:
                    rule["rule_text"] = text
                    rule["category"] = category
                    return FakeCompleted()
            return FakeCompleted(returncode=1, stderr="missing rule")
        return FakeCompleted(returncode=1, stderr="unknown")


def build_candidate(rule_id="rule-1", status="verified", category="ui-gotchas", text="Hello"):
    return {
        "rule_id": rule_id,
        "category": category,
        "rule_text": text,
        "status": status,
        "test_ref": "test_file.lua::test.id",
    }


def test_import_only_verified(monkeypatch):
    fake = FakeCm([])
    monkeypatch.setattr(import_cm_rules, "run_cm_command", fake.handle)
    candidates = [
        build_candidate("ok", "verified", text="Good"),
        build_candidate("skip", "pending", text="Skip"),
    ]
    stats = import_cm_rules.import_rules(candidates, [], dry_run=False, verbose=False)
    assert stats.added == 1
    assert stats.skipped_unverified == 1
    assert len(fake.rules) == 1


def test_deduplication_fingerprint(monkeypatch):
    fake = FakeCm([])
    monkeypatch.setattr(import_cm_rules, "run_cm_command", fake.handle)
    candidates = [
        build_candidate("r1", "verified", text="Same text"),
        build_candidate("r2", "verified", text="Same text"),
    ]
    stats = import_cm_rules.import_rules(candidates, [], dry_run=False, verbose=False)
    assert stats.added == 1
    assert stats.skipped_duplicate == 1


def test_idempotent_second_run(monkeypatch):
    existing = [
        import_cm_rules.CmRule(
            rule_id="r1",
            category="ui-gotchas",
            rule_text="Text (Verified: Test: test_file.lua::test.id)",
        )
    ]
    fake = FakeCm([{"rule_id": "r1", "category": "ui-gotchas", "rule_text": existing[0].rule_text}])
    monkeypatch.setattr(import_cm_rules, "run_cm_command", fake.handle)
    candidates = [build_candidate("r1", "verified", text="Text")]

    stats = import_cm_rules.import_rules(candidates, existing, dry_run=False, verbose=False)
    assert stats.unchanged == 1
    assert all(call[2] != "update" for call in fake.calls)


def test_backup_export_before_mutation(monkeypatch, tmp_path):
    events = []

    def fake_export(_, __, ___):
        events.append("backup")

    def fake_import_rules(*args, **kwargs):
        events.append("import")
        return import_cm_rules.ImportStats()

    monkeypatch.setattr(import_cm_rules, "export_backup", fake_export)
    monkeypatch.setattr(import_cm_rules, "import_rules", fake_import_rules)

    candidates_path = tmp_path / "candidates.yaml"
    candidates_path.write_text("rules: []", encoding="utf-8")

    import_cm_rules.run_import(candidates_path=candidates_path, backup_path=tmp_path / "backup.json")

    assert events == ["backup", "import"]


def test_dry_run_no_mutations(monkeypatch):
    fake = FakeCm([])
    monkeypatch.setattr(import_cm_rules, "run_cm_command", fake.handle)
    candidates = [build_candidate("r1", "verified", text="Text")]
    stats = import_cm_rules.import_rules(candidates, [], dry_run=True, verbose=False)
    assert stats.added == 1
    assert len(fake.rules) == 0


def test_logging_prefix(capsys):
    import_cm_rules.log("Test message", verbose=True)
    captured = capsys.readouterr()
    assert captured.out.startswith(import_cm_rules.LOG_PREFIX)
    assert "Test message" in captured.out


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
