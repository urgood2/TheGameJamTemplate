# Executive Summary (TL;DR)
This plan delivers an end-to-end deterministic game testing system with a stable Lua `test_harness` API, frame-accurate input injection, state/log/screenshot assertions, baseline management, and CI reporting. Work is structured into phased, parallelizable tasks with clear dependencies and acceptance criteria. Core C++ systems live under `src/testing/`, Lua framework under `assets/scripts/tests/`, and artifacts under `tests/out/<run_id>/`. The critical path is: contracts + stubs → test mode core → Lua runner/reporters → verification systems → CI.

# Architecture Overview
The engine enables `--test-mode`, initializes deterministic runtime (seed, fixed timestep, optional headless rendering), and exposes a Lua `test_harness` table. Each frame, queued test input events are applied, the game advances by fixed dt, and the test coroutine resumes until it yields (e.g., `wait_frames`). C++ subsystems handle config parsing, input injection, state query/set, screenshot capture/compare, log capture, and baseline management. Lua framework handles discovery, execution, assertions, sharding, and reporting.

Key modules and paths:
- C++: `src/testing/test_mode_config.{hpp,cpp}`, `src/testing/test_mode.{hpp,cpp}`, `src/testing/test_input_provider.{hpp,cpp}`, `src/testing/test_harness_lua.{hpp,cpp}`, `src/testing/lua_state_query.{hpp,cpp}`, `src/testing/screenshot_capture.{hpp,cpp}`, `src/testing/screenshot_compare.{hpp,cpp}`, `src/testing/log_capture.{hpp,cpp}`, `src/testing/baseline_manager.{hpp,cpp}`
- Lua: `assets/scripts/tests/framework/bootstrap.lua`, `assets/scripts/tests/framework/test_runner.lua`, `assets/scripts/tests/framework/assertions.lua`, `assets/scripts/tests/framework/matchers.lua`, `assets/scripts/tests/framework/actions.lua`, `assets/scripts/tests/framework/discovery.lua`, `assets/scripts/tests/framework/reporters/json.lua`, `assets/scripts/tests/framework/reporters/junit.lua`
- Baselines: `tests/baselines/<platform>/<WxH>/...png`
- Outputs: `tests/out/<run_id>/report.json`, `tests/out/<run_id>/report.junit.xml`, `tests/out/<run_id>/artifacts/`

# Phase Breakdown With Numbered Tasks

## Phase 0 — Recon + Interface Freeze (enables parallel work)
0.1 Document integration points and contract freeze in `docs/testing/e2e.md` with explicit references to CLI flags, `test_harness` API, and output paths. Dependencies: none. Complexity: S. Acceptance: document lists entrypoints for CLI parsing, game loop tick, input backend, renderer readback, logging sink, and Lua binding registry; contract text matches master plan. Edge cases: multiple game loop variants; Failure modes: missed hook points cause rework later.

0.2 Add stub C++ headers/sources for all `src/testing/*` and stub Lua files under `assets/scripts/tests/framework/` with placeholders. Dependencies: 0.1. Complexity: M. Acceptance: project compiles with stubs; symbols are defined for planned functions and classes; Lua bootstrap can be loaded without runtime errors. Edge cases: build system not picking up new files; Failure modes: link errors or missing file registrations.

0.3 Freeze data structures in headers: `struct TestModeConfig`, `struct ScreenshotCompareOptions`, `struct LogEntry`, `struct TestInputEvent`, `struct PathSegment`. Dependencies: 0.1. Complexity: S. Acceptance: all structs declared with fields required by contracts; comments describe invariants and defaults; no ABI blockers. Edge cases: platform-specific fields; Failure modes: later API mismatch between C++ and Lua.

## Phase 1 — Test Mode Core (C++)
1.1 Implement `TestModeConfig` parsing in `src/testing/test_mode_config.cpp` with `bool parse_test_mode_args(int argc, char** argv, TestModeConfig& out, std::string& err)` and `bool validate_and_finalize(TestModeConfig&, std::string& err)`. Dependencies: 0.3. Complexity: M. Acceptance: all CLI flags parsed; unknown flags error with usage and exit code 1; default values applied; invalid `--resolution` and shard values rejected. Edge cases: `--update-baselines` overrides `--fail-on-missing-baseline`; missing suite/script uses default suite. Failure modes: path traversal in artifacts/report paths; config accepts invalid shard ranges.

1.2 Add path safety utilities in `src/testing/test_mode_config.cpp` using `std::filesystem`: `bool is_under_root(root, candidate)` and `bool ensure_dir(path, err)`. Dependencies: 1.1. Complexity: S. Acceptance: artifacts/report dirs are created; traversal outside repo or output root rejected with error. Edge cases: symlinks; Failure modes: directory creation failures not reported.

1.3 Implement `TestMode` in `src/testing/test_mode.{hpp,cpp}` with lifecycle: `initialize`, `begin_frame`, `advance_frame`, `resume_lua`, `request_exit(int code)`, `get_now_frame`. Dependencies: 1.1. Complexity: M. Acceptance: deterministic fixed timestep applied; `now_frame` increments per tick; watchdog timeout `--timeout-seconds` terminates run with clear error. Edge cases: `wait_frames(0)` yields immediately; Failure modes: coroutine never yields; timeout not enforced.

1.4 Integrate test mode into main loop and startup: add hook to load `assets/scripts/tests/framework/bootstrap.lua` when `--test-mode` is set and create a Lua coroutine. Dependencies: 1.3. Complexity: M. Acceptance: `./game --test-mode --test-script minimal.lua` can `wait_frames` and `exit(0)`; normal mode unaffected. Edge cases: missing bootstrap file; Failure modes: Lua errors not captured in report.

1.5 Headless path support: implement renderer/window configuration for `--headless` with fallback to hidden window and CI `xvfb-run` compatibility. Dependencies: 1.3. Complexity: M. Acceptance: headless runs renderable frames and screenshots; no visible window in CI; renderer readback available. Edge cases: platform-specific headless limitations; Failure modes: readback returns blank frames.

## Phase 2 — Input Injection (C++)
2.1 Implement `TestInputProvider` in `src/testing/test_input_provider.{hpp,cpp}` with `struct TestInputEvent { enum Type; uint64_t frame; data... }` and queue scheduling. Dependencies: 0.3. Complexity: M. Acceptance: events schedule by frame; multiple events in same frame apply deterministically in insertion order. Edge cases: events scheduled in past frame; Failure modes: queue not cleared between tests.

2.2 Add test mode input override in input backend (e.g., `src/input/*`): route input from `TestInputProvider` when test mode is active, optionally ignoring physical input. Dependencies: 2.1. Complexity: M. Acceptance: hardware input ignored by default; test input applied at frame boundary only. Edge cases: mixed input policies; Failure modes: double-application of input.

2.3 Bind input APIs in `src/testing/test_harness_lua.{hpp,cpp}`: `press_key`, `release_key`, `tap_key`, `move_mouse`, `mouse_down`, `mouse_up`, `click` and key constants. Dependencies: 2.1. Complexity: M. Acceptance: Lua calls enqueue correct events; invalid key/mouse values return `nil, err`; constants exposed in `test_harness`. Edge cases: unsupported keycodes; Failure modes: no-ops without error.

## Phase 3 — Lua Test Framework (Lua)
3.1 Implement `assets/scripts/tests/framework/test_runner.lua` with `describe`, `it`, `before_each`, `after_each`, deterministic order, and per-test result tracking; store `TestCase { id, name, fn, status, error, frames, start_frame, end_frame }`. Dependencies: 0.2, 1.4. Complexity: M. Acceptance: deterministic enumeration; failures capture stack traces; suite/test names included in errors. Edge cases: nested describes; Failure modes: hook errors masked.

3.2 Implement `assets/scripts/tests/framework/discovery.lua` to resolve `--test-script` or enumerate `--test-suite` in stable order; stable sorting required for sharding. Dependencies: 1.1. Complexity: S. Acceptance: deterministic file list; invalid paths error; empty suite produces clean report. Edge cases: non-Lua files; Failure modes: nondeterministic ordering breaks sharding.

3.3 Implement assertions and matchers in `assets/scripts/tests/framework/assertions.lua` and `assets/scripts/tests/framework/matchers.lua` with uniform error formatting. Dependencies: 3.1. Complexity: S. Acceptance: assertions include suite/test/frame context; errors propagate to runner. Edge cases: expected nil values; Failure modes: assertion pass/fail inverted.

3.4 Implement reporters `assets/scripts/tests/framework/reporters/json.lua` and `assets/scripts/tests/framework/reporters/junit.lua` to write to `test_harness.args.report_json` and `report_junit`. Dependencies: 3.1. Complexity: M. Acceptance: JSON includes run metadata, per-test status, durations; JUnit schema valid and accepted by CI. Edge cases: skipped tests; Failure modes: invalid XML escaping.

3.5 Implement sharding in `test_runner.lua` using `(test_index % total_shards) == (shard-1)` and expose shard info in report. Dependencies: 3.1, 3.2. Complexity: S. Acceptance: shard selection stable across runs; invalid shard values error. Edge cases: total_shards=1; Failure modes: off-by-one leads to missing tests.

## Phase 4 — Verification Systems (C++ + Lua wiring)
4.1 Implement `lua_state_query` with `parse_path(const std::string&) -> std::vector<PathSegment>` supporting dot, numeric, bracket forms; functions `get_state(path)` and `set_state(path,value)` exposed in `test_harness`. Dependencies: 1.4. Complexity: M. Acceptance: reads/writes Lua globals and nested tables; returns `nil, err` on missing or invalid path. Edge cases: mixed numeric keys and string keys; Failure modes: unexpected type mutation.

4.2 Implement `screenshot_capture` with `bool capture_png(const std::filesystem::path& path, std::string& err)` using renderer readback; ensure resolution matches config. Dependencies: 1.5. Complexity: M. Acceptance: PNG written to artifacts dir; error returned on readback failure. Edge cases: headless readback unavailable; Failure modes: image alpha/format mismatch.

4.3 Implement `screenshot_compare` with `ScreenshotCompareOptions { threshold_percent, per_channel_tolerance, generate_diff }` and `compare_images(baseline, actual, diff)`. Dependencies: 4.2. Complexity: M. Acceptance: mismatches produce diff PNG and error message with pixel counts; zero diff passes. Edge cases: different image sizes; Failure modes: threshold applied incorrectly.

4.4 Implement `baseline_manager` with `std::filesystem::path resolve_baseline_dir(platform, resolution)` and `handle_update_baseline(...)`. Dependencies: 1.1, 4.2. Complexity: S. Acceptance: correct platform tag `linux|windows|mac|unknown`; `--update-baselines` copies actual to baseline and records in report; missing baseline fails if `--fail-on-missing-baseline`. Edge cases: baseline dir missing; Failure modes: copy to wrong platform folder.

4.5 Implement `log_capture` with ring buffer in `src/testing/log_capture.{hpp,cpp}` and hooks to logger sink; provide `log_mark`, `find_log`, `clear_logs`. Dependencies: 1.3. Complexity: M. Acceptance: logs captured during test mode only; `find_log` respects `since` and `regex` option. Edge cases: invalid regex; Failure modes: log buffer overflow not handled.

4.6 Bind verification APIs in `test_harness_lua` for `get_state`, `set_state`, `screenshot`, `assert_screenshot`, `log_mark`, `find_log`, `clear_logs`. Dependencies: 4.1–4.5. Complexity: M. Acceptance: Lua functions return `true` on success or `nil, err`; `assert_screenshot` writes actual/diff artifacts and reports baseline updates. Edge cases: invalid options table; Failure modes: errors not surfaced.

## Phase 5 — Example Tests + Test Hooks (Game Lua/C++)
5.1 Add minimal test-visible state hooks in game Lua/C++ only under `--test-mode`, e.g., `game.initialized`, `game.current_scene`, `game.paused`, `ui.elements.<name>`. Dependencies: 4.1. Complexity: M. Acceptance: state is stable and deterministic across runs; no leaks into normal mode. Edge cases: state not yet available at frame 0; Failure modes: coupling to unstable internal IDs.

5.2 Create three E2E tests under `assets/scripts/tests/e2e/` using `test_harness`: `menu_test.lua`, `combat_test.lua`, `ui_test.lua`. Dependencies: 2.3, 3.1, 4.6, 5.1. Complexity: M. Acceptance: tests pass locally with deterministic outputs; failure produces artifacts. Edge cases: timing variability; Failure modes: non-deterministic input timing.

5.3 Generate initial baselines under `tests/baselines/<platform>/<WxH>/` for CI platform and resolution. Dependencies: 4.4, 5.2. Complexity: S. Acceptance: baseline images present and used by `assert_screenshot`; no missing baseline failures. Edge cases: differing GPU output; Failure modes: baselines overwritten unintentionally.

## Phase 6 — CI (GitHub Actions) + Parallelism
6.1 Add `.github/workflows/e2e-tests.yml` with build, run, artifact upload, and JUnit publish; use `--headless` and shard matrix. Dependencies: 3.4, 5.2. Complexity: M. Acceptance: CI runs on PRs, uploads artifacts always, and reports JUnit results. Edge cases: cache invalidation; Failure modes: artifacts not uploaded on failure.

6.2 Add shard matrix (default 4) with `--shard` and `--total-shards`; set `fail-fast: false` and per-shard artifact naming. Dependencies: 3.5, 6.1. Complexity: S. Acceptance: each shard runs disjoint tests; combined results cover full suite. Edge cases: test count < shards; Failure modes: shard mismatch due to nondeterministic ordering.

# Parallel Execution Plan (Agents and Dependencies)
- Shared prerequisite: Phase 0 complete, especially stubs and contract docs.
- Agent A: Phase 1 (test mode core, CLI parsing, coroutine lifecycle, watchdog) depends on 0.2/0.3.
- Agent B: Phase 2 (input injection, Lua bindings for input) depends on 0.2/0.3.
- Agent C: Phase 1.5 + Phase 4.2/4.3/4.4 (headless, capture, compare, baselines) depends on 1.5 and 0.3.
- Agent D: Phase 3 + Phase 5.2 (Lua framework and tests) depends on 0.2 and API stubs; can proceed in parallel with C++.
- Agent E: Phase 4.1/4.5/4.6 + Phase 6 (state/log/screenshot wiring and CI) depends on Phase 1 and 4.2/4.4.

# Critical Path and Dependencies
Critical path: 0.2/0.3 → 1.1/1.3/1.4 → 3.1/3.4 → 4.2/4.3/4.4/4.6 → 5.2 → 6.1. Any delay in test mode core (Phase 1) or screenshot/baseline systems (Phase 4) blocks visual verification and CI readiness. Sharding and CI can proceed after stable Lua reports and test execution.

# Risk Mitigation
- Determinism drift: enforce fixed timestep in `TestMode::advance_frame`, seed RNG from `TestModeConfig`, disable vsync; add frame count to reports.
- Headless instability: provide fallback to hidden window; log explicit warning when true offscreen is unavailable; verify readback on a known frame.
- Baseline churn: require `--update-baselines` for baseline changes; include baseline update list in JSON report.
- Path safety: validate all output paths via `is_under_root` and reject traversal or absolute paths outside root.
- Nondeterministic discovery: sort test file paths and test names deterministically in `discovery.lua` and `test_runner.lua`.
- Regression in normal mode: isolate all hooks behind `--test-mode` checks; ensure stubs do not alter non-test paths.