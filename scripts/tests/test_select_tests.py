"""Tests for select_tests.py."""
from __future__ import annotations

from select_tests import (
    LOG_PREFIX,
    format_runner_args,
    match_rules,
    nightly_args,
)


def test_log_prefix_stable() -> None:
    assert LOG_PREFIX == "[SELECT]"


def test_default_smoke_included() -> None:
    impact_map = {
        "default": {"categories": ["smoke"], "tags": []},
        "impact_rules": [],
    }
    categories, tags, skip = match_rules([], impact_map)
    assert "smoke" in categories
    assert skip is False


def test_glob_matching_selects_expected_filters() -> None:
    impact_map = {
        "default": {"categories": ["smoke"], "tags": []},
        "impact_rules": [
            {
                "name": "ui_system",
                "globs": ["assets/scripts/ui/**"],
                "filters": {"categories": ["ui"], "tags": ["ui", "visual"]},
            }
        ],
    }
    categories, tags, _ = match_rules(["assets/scripts/ui/panel.lua"], impact_map)
    assert "ui" in categories
    assert "visual" in tags


def test_wildcard_category_behavior() -> None:
    args = format_runner_args({"*"}, {"visual"}, False)
    assert "--all-categories" in args


def test_skip_tests_validators_only() -> None:
    args = format_runner_args({"ui"}, {"visual"}, True)
    assert args == "--skip-tests --validators-only"


def test_nightly_args_include_flags() -> None:
    impact_map = {
        "nightly": {"include_slow": True, "include_visual": True},
    }
    args = nightly_args(impact_map)
    assert "--all-categories" in args
    assert "--include-slow" in args
    assert "--include-visual" in args
