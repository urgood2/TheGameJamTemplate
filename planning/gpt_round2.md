# Master Plan: End-to-End (E2E) Game Testing System — Revised v2

This document is a revised version of the original plan with **architecture hardening, determinism upgrades, better failure forensics, faster iteration, and real-world CI survivability** (skip/xfail/quarantine, per-test timeouts, determinism audit, snapshot isolation, baseline keying, etc.).

---

## 0) Outcomes & Non-Goals

### Outcomes
- Run tests via:
  - `./game --test-mode [--headless] [--test-script <file> | --test-suite <dir>]`
- Tests can:
  - **drive input**
  - **wait deterministically by frames**
  - **query/set state**
  - **assert logs**
  - **assert screenshots** (baseline + diff artifacts)
- CI runs headless, uploads artifacts, and reports results (JUnit + JSON).

### Non-Goals (v1)
- Web/Emscripten support, perceptual diff/ML diffing, full UI automation framework, multiplayer/network determinism.
- Cross-GPU pixel-perfect equivalence (unless running a canonical software renderer / fixed backend in CI).

---

## 0.1 Determinism Contract (Test Mode)

In `--test-mode`, the engine must behave as a **deterministic simulator** given:
- the same binary + content, the same `--seed`, the same resolution, and the same test script(s).

### Rules (enforced where feasible)
1. **Wall-clock time must not affect simulation.**
   - No `now()` driving gameplay. Simulation time == `frame_count / fixed_dt`.
2. **Randomness must be routed through seeded RNG(s).**
   - No unseeded RNG, no `random_device` in gameplay paths.
3. **Update ordering must be stable.**
   - No unordered container iteration affecting gameplay outcomes.
4. **Asynchronous jobs must be deterministic.**
   - Either disabled in test mode, forced single-thread, or completion order made stable.
5. **Asset streaming/loading must have deterministic completion points.**
   - Explicit "ready" signals for tests to wait on.
6. **Floating point behavior must be pinned in test mode.**
   - Set consistent FP environment (rounding mode, FTZ/DAZ) at startup in `--test-mode`.
   - Avoid fast-math in determinism-critical codepaths (or document/contain it).
   - If physics relies on FP, require a deterministic physics step (fixed dt, fixed iteration counts).
7. **Process environment must be pinned.**
   - Freeze locale/timezone in test mode (or explicitly set to a known value).
   - Avoid environment-dependent formatting/parsing affecting state or UI layout.
8. **Filesystem nondeterminism must be eliminated.**
   - Never rely on directory enumeration order; always sort deterministically.
   - Avoid using file mtimes / “latest file” logic in test-mode gameplay paths.
9. **GPU/renderer synchronization points must be explicit for screenshots.**
   - Screenshot capture occurs at a defined frame boundary after a completed present/render pass.
   - If async readback is used, completion must be deterministic and frame-indexed.

### Diagnostics stance
- In `--test-mode`, determinism violations should produce an explicit warning/error category (easy to grep in CI).

### Rendering caveat
- Pixel-perfect screenshot baselines are only guaranteed on a controlled render stack (same backend/driver/software renderer).
- If the render stack varies, use masking/ROI or run screenshot tests on a canonical CI renderer only.

---

## 1) Canonical Naming, Structure, and Paths

### 1.1 C++ (engine)
- `src/testing/`
  - `test_mode_config.{hpp,cpp}`
  - `test_runtime.{hpp,cpp}`           — owns all test subsystems + lifecycle
  - `test_mode.{hpp,cpp}`              — thin integration layer into engine loop
  - `test_input_provider.{hpp,cpp}`
  - `test_harness_lua.{hpp,cpp}`       — Lua bindings; delegates to TestRuntime
  - `lua_state_query.{hpp,cpp}`
  - `screenshot_capture.{hpp,cpp}`
  - `screenshot_compare.{hpp,cpp}`
  - `log_capture.{hpp,cpp}`
  - `baseline_manager.{hpp,cpp}`
  - `artifact_store.{hpp,cpp}`         — atomic writes, relative paths, manifest
  - `path_sandbox.{hpp,cpp}`           — canonicalize + restrict output roots
  - `test_forensics.{hpp,cpp}`         — crash/timeout bundles: logs + last frames
  - `determinism_audit.{hpp,cpp}`      — optional: repeat runs + divergence detection

### 1.2 Lua (tests)
- `assets/scripts/tests/`
  - `framework/`
    - `bootstrap.lua` (entrypoint loaded by engine in test mode)
    - `test_runner.lua` (DSL + execution + sharding)
    - `assertions.lua`
    - `matchers.lua` (optional, for consistent error formatting)
    - `actions.lua` (high-level game actions)
    - `discovery.lua`
    - `reporters/`
      - `json.lua`
      - `junit.lua`
      - `tap.lua` (optional)
  - `e2e/`
    - `menu_test.lua`
    - `combat_test.lua`
    - `ui_test.lua`

### 1.3 Baselines & outputs

#### Baselines (versioned)
- `tests/baselines/<platform>/<baseline_key>/<WxH>/...png`
  - `<platform>`: `linux|windows|mac|unknown`
  - `<baseline_key>`: `renderer+colorspace` (e.g. `vulkan_sdr_srgb`, `software_sdr_srgb`)
  - `<WxH>`: `1280x720` etc.
  - Optional per-baseline metadata (versioned):
    - `.../<name>.meta.json` (thresholds, ROI, masks, notes)

#### Outputs (ignored by git)
- `tests/out/<run_id>/`
  - `report.json`
  - `report.junit.xml`
  - `artifacts/` (screenshots, diffs, logs, per-test debug)
  - `forensics/`
    - `run_manifest.json`   — args, seed, platform, renderer, git sha
    - `input_trace.jsonl`   — frame-indexed injected inputs
    - `logs.jsonl`          — structured logs (frame, level, category, message)
    - `last_logs.txt`       — tail of log buffer
    - `final_frame.png`     — crash/timeout screenshot if available
    - `last_frames/`        — optional ring buffer (e.g. last 30 frames) captured only on failure
    - `repro.sh`            — per-run (and/or per-test) repro script
    - `repro.ps1`           — PowerShell repro
    - `forensics.zip`       — optional zipped bundle for easy CI download

---

## 2) CLI Contract (Single Source of Truth)

All flags optional unless noted:

### Core
- `--test-mode` (enables all test systems)
- `--headless` (offscreen/hidden rendering path; CI-friendly)
- `--test-script <path>` (run one test file)
- `--test-suite <dir>` (discover and run all tests under directory)
- `--list-tests` (discover tests, print stable full names, exit 0)
- `--test-filter <glob_or_regex>` (run matching tests only)
- `--exclude-tag <tag>` / `--include-tag <tag>` (tag-based selection)
- `--seed <u32>` (default: fixed, e.g. `12345`)
- `--fixed-fps <int>` (default: `60`; forces fixed timestep)
- `--resolution <WxH>` (default: `1280x720`)

### Output paths
- `--artifacts <dir>` (default: `tests/out/<run_id>/artifacts`)
- `--report-json <path>` (default: `tests/out/<run_id>/report.json`)
- `--report-junit <path>` (default: `tests/out/<run_id>/report.junit.xml`)

### Baselines
- `--update-baselines` (accept missing/mismatched baselines by copying actual → baseline)
- `--fail-on-missing-baseline` (default: `true`; ignored if `--update-baselines`)
- `--baseline-key <key>` (default: auto-detected from renderer/colorspace)

### Sharding + timeouts
- `--shard <n>` and `--total-shards <k>` (default: `1/1`; deterministic sharding)
- `--timeout-seconds <int>` (default: `600`; hard kill to avoid hung CI)
- `--default-test-timeout-frames <int>` (default: `1800`; per-test timeout measured in frames)

### Retries + flake policy
- `--retry-failures <n>` (default: `0`; rerun failing tests up to N times)
- `--allow-flaky` (default: `false`; if false, flaky tests still fail CI)

### Suite control / hygiene
- `--run-quarantined` (default: `false`; include tests tagged `quarantine`)
- `--fail-fast` (default: `false`; stop after first failure)
- `--max-failures <n>` (default: `0`; 0 means unlimited)

### RNG scope
- `--rng-scope <scope>` (default: `test`; `test|run`)
  - `test`: reseed deterministic RNG streams per test using `hash(seed, test_id)`
  - `run`: single global RNG seed for the whole run

### Renderer control
- `--renderer <mode>` (default: `offscreen`; `null|offscreen|windowed`)
  - `null`: logic-only; screenshot APIs unsupported (capabilities reflect this)

### Determinism audit (tripwire)
- `--determinism-audit` (default: `false`)
- `--determinism-audit-runs <n>` (default: `2`)
- `--determinism-audit-scope <scope>` (default: `test_api`; `test_api|engine|render_hash`)

### Log gating
- `--fail-on-log-level <level>` (default: empty; if set, fail if logs at/above level occur during a test)
- `--fail-on-log-category <glob>` (default: empty; optional filter)

### Input record/replay (optional, but huge productivity win)
- `--record-input <path>` (default: empty; record effective input events to JSONL)
- `--replay-input <path>` (default: empty; replay a recorded input trace)

### Crash containment (optional hardening)
- `--isolate-tests <mode>` (default: `none`; `none|process-per-file|process-per-test`)

### Exit code contract
| Code | Meaning |
|------|---------|
| `0`  | All tests passed (and no gating policy violations) |
| `1`  | One or more tests failed (including gating policy violations) |
| `2`  | Harness/configuration error (bad flags, missing scripts, invalid paths) |
| `3`  | Timeout/watchdog abort |
| `4`  | Crash (unhandled exception / fatal error) |

### Behavior rules
- `--test-mode` with neither `--test-script` nor `--test-suite` loads `assets/scripts/tests/framework/bootstrap.lua` and defaults to `--test-suite assets/scripts/tests/e2e`.
- Unknown/invalid flags print usage and exit `2`.
- All artifact/report paths are created if missing; path traversal outside repo/output roots is rejected.
  - Enforcement centralized in `path_sandbox` + `artifact_store` (no ad-hoc checks).

---

## 3) `test_harness` Lua API Contract (Stable Interface)

Expose a global table `test_harness` only in test mode.

### 3.1 Frame/time control (coroutine-friendly)
- `test_harness.wait_frames(n)`
  - Validates `n >= 0`; yields until `n` frames have advanced.
- `test_harness.now_frame() -> integer`
- `test_harness.wait_until(predicate_fn, opts?) -> true|error`
  - Polls `predicate_fn()` once per frame until truthy.
  - `opts`: `{ timeout_frames=300, fail_message="...", poll_every_frames=1 }`
- `test_harness.wait_until_state(path, expected, opts?) -> true|error`
- `test_harness.wait_until_log(substr_or_regex, opts?) -> true|error`
- `test_harness.exit(code)`
- `test_harness.skip(reason)` (marks current test skipped safely)
- `test_harness.xfail(reason)` (expected fail; fail->XFAIL, pass->XPASS)

### 3.2 Input injection (applied at frame boundaries)
- `press_key`, `release_key`, `tap_key`
- `move_mouse`, `mouse_down`, `mouse_up`, `click`
- `text_input(str)`
- `gamepad_button_down/up`, `gamepad_set_axis`

### 3.3 State query/set (via Test API Surface)
- `get_state(path) -> value|nil, err?`
- `set_state(path, value) -> true|nil, err?`

#### 3.3.1 Explicit queries/commands (preferred)
- `query(name, args?) -> value|nil, err?`
- `command(name, args?) -> true|nil, err?`

### 3.4 Screenshots & comparisons
- `screenshot(path) -> true|nil, err?`
- `assert_screenshot(name, opts?) -> true|error`
  - `opts`:
    ```lua
    {
      threshold_percent = 0.1,
      per_channel_tolerance = 2,
      generate_diff = true,
      region = nil,              -- {x,y,w,h} compare ROI only
      masks = nil,               -- list of {x,y,w,h} areas to ignore
      ignore_alpha = true,
      stabilize_frames = 0       -- optional: require N identical frames before capture
    }
    ```
  - If `--update-baselines`, copy actual → baseline and record baseline update in report.
  - If `<name>.meta.json` exists, merge as defaults (test overrides allowed).
  - If renderer is `null`, this must SKIP via capabilities.

### 3.5 Logs
- `log_mark() -> index`
- `find_log(substr_or_regex, opts?) -> found, index, line`
  - `opts`: `{ since=index, regex=false }`
- `clear_logs()`
- `assert_no_log_level(level, opts?) -> true|error`
  - Example: `assert_no_log_level("error", { since=mark })`

### 3.6 Runtime args and capability handshake
- `test_harness.args` table: `{ seed, fixed_fps, resolution, shard, total_shards, update_baselines, baseline_dir, artifacts_dir, report_json, report_junit }`
- `test_harness.capabilities` (read-only), e.g. `{ screenshots=true, headless=true, render_hash=false, gamepad=true }`
- `test_harness.test_api_version` string, e.g. `"1.2.0"`
- `test_harness.require(opts) -> true|error`
  - `opts`: `{ min_test_api_version="1.2.0", requires={"screenshots","gamepad"} }`

### 3.7 Determinism hashing (audit support)
- `test_harness.frame_hash(scope?) -> string`
  - `test_api` (default): hash of Test API Surface snapshot
  - `engine`: optional internal deterministic hash
  - `render_hash`: optional hash of backbuffer (canonical renderer only)

---

## 4) Execution Model (Deterministic + Blocking Waits)

- In `--test-mode`, engine loads `assets/scripts/tests/framework/bootstrap.lua`.
- `bootstrap.lua` creates a coroutine that runs discovery + `TestRunner.run()`.
- Each frame, engine:
  1. Applies queued test input events scheduled for this frame.
  2. Advances the game with fixed `dt = 1/fixed_fps`.
  3. Resumes test coroutine until it yields or completes.

### Watchdogs
- Run-level watchdog: `--timeout-seconds`.
- Per-test watchdog: `--default-test-timeout-frames` (overrideable per test).

### Forensics on crash/timeout/failure
- Write a forensics bundle (logs + last frames + input trace + manifest + repro scripts).
- Optionally zip for easy CI download.

### Test isolation rules
Before each `it(...)`, runner performs deterministic cleanup:
1. Clear pending injected inputs + reset input down-state.
2. `log_mark()` to create a clean log window.
3. Prefer snapshot restore if supported:
   - If `command("snapshot_restore", { name="suite_start" })` succeeds, use it.
   - Else call `command("reset_to_known_state")`.
4. If `--rng-scope=test`, reseed RNG streams to `hash(run_seed, test_full_name)`.

Suite setup (recommended):
- At suite start: attempt `command("snapshot_create", { name="suite_start" })`.

### Determinism audit mode
If `--determinism-audit`:
- Each selected test is executed `--determinism-audit-runs` times.
- Runner records `frame_hash()` each frame (or configurable cadence).
- Any divergence fails with:
  - first divergent frame
  - hashes before/after
  - repro command + artifacts

---

## 5) Implementation Phases (with acceptance gates)

### Phase 0 — Recon + Interface Freeze (enables parallel work)
1. Locate integration points: CLI parsing, game loop timestep, input backend, renderer readback, logger sink, Lua registry.
2. Add stub headers/skeletons for all `src/testing/*` files and Lua framework files.
3. Document determinism contract; confirm engine can meet rules incl. FP/environment/filesystem notes.
**Gate:** repo compiles with stubs; contracts committed as docs/comments.

### Phase 1 — Test Mode Core (C++)
1. `test_mode_config`: parse flags, validate, compute `<run_id>`, create output dirs.
2. `test_runtime`: owns all test subsystems + lifecycle.
3. `test_mode`: enable determinism (seed RNG, fixed timestep, disable vsync, optional audio off), set pinned FP/env.
4. Engine loop integration: load `bootstrap.lua`, run coroutine per frame, honor `exit(code)`, honor watchdogs.
5. Headless path: true offscreen preferred; fallback hidden window + CI `xvfb-run`.
6. `path_sandbox` + `artifact_store`: path safety + atomic writes.
**Gate:** `./game --test-mode --test-script <minimal.lua>` can wait frames, log, and exit(0).

### Phase 2 — Input Injection (C++)
1. `test_input_provider`: per-frame scheduled event queue.
2. Input system override in test mode (normal device input ignored or merged by policy; default ignore).
3. Bind input functions in `test_harness_lua` incl. text input + gamepad.
4. Record injected inputs to `input_trace.jsonl`.
5. Optional: record/replay integration via `--record-input` / `--replay-input`.
**Gate:** Lua script can press/hold/release keys, enter text, use gamepad, click reliably with frame-accurate timing.

### Phase 3 — Lua Test Framework (Lua)
1. `test_runner.lua`: `describe/it`, hooks, deterministic ordering, per-test results, timeouts, frame budgets.
   - tags: `it("does X", { tags={"ui","smoke"} }, function() ... end)`
   - selection: include/exclude tags, filter
   - `--list-tests`
   - isolation before each test
   - quarantine handling: `tags={"quarantine"}`
2. `discovery.lua`: load `--test-script` or enumerate `--test-suite` deterministically (sorted).
3. `assertions.lua` + `matchers.lua`: consistent errors with suite/test name + frame context.
4. Reporters: JSON + JUnit (TAP optional).
   - JSON authoritative includes environment, resolved roots, per-test durations, artifacts, failure kind.
   - retries: mark flaky; if `--allow-flaky=false`, still fail CI even if passing after retries.
   - statuses: `pass|fail|skipped|xfail|xpass|flaky|quarantined`
5. Sharding: `(test_index % total_shards) == (shard-1)` (stable enumeration required).
**Gate:** one example E2E test runs and produces `report.json` + correct exit code.

### Phase 4 — Verification Systems (C++ + Lua wiring)
1. `lua_state_query`: robust traversal (dot + numeric + bracket) against Test API Surface.
2. `query` / `command` APIs stable + whitelisted.
3. `screenshot_capture`: framebuffer readback to PNG (windowed + headless).
4. `screenshot_compare`: pixel diff + threshold + diff image; ROI + masks + stabilization.
   - Ensure comparisons are in a defined color space (explicit sRGB handling).
5. `baseline_manager`: resolve baseline dir by platform/baseline_key/resolution; implement update-baselines; merge `.meta.json`.
6. `log_capture`: ring buffer + structured JSONL logs; mark/find/clear.
7. `test_forensics`: bundles with seed/args/trace/last frames/repro scripts.
8. Condition waits: `wait_until`, `wait_until_state`, `wait_until_log`.
**Gate:** `assert_state`, `assert_log_contains`, `assert_screenshot` work end-to-end and generate artifacts on failure.

### Phase 5 — Example Tests + Test Hooks (Game Lua/C++)
1. Add minimal test-visible state hooks (test mode only):
   - Test API Surface (small, versioned):
     - properties: `game.initialized`, `game.current_scene`, `game.paused`
     - queries: `ui.element_rect(name)`, `ui.element_visible(name)`
     - commands: `scene.load(name)`, `combat.spawn_enemy(...)`, etc.
   - expose `test_api_version` and capabilities.
2. Implement 3 tests:
   - menu nav + screenshot baseline
   - combat deterministic setup + log/state asserts
   - UI pause/inventory + state + screenshot asserts
3. Create baselines for canonical CI runner (single platform/resolution/backend).
**Gate:** 3 tests pass locally and headless; reruns stable.

### Phase 6 — CI (GitHub Actions) + Parallelism
1. Workflow `.github/workflows/e2e-tests.yml`:
   - build + cache
   - run headless tests
   - upload `tests/out/**` artifacts (always)
   - publish JUnit
2. Matrix sharding (4 shards default), `fail-fast: false`.
3. Job summary (required):
   - failing test names
   - seed + resolution + shard info
   - copy/paste repro command
   - artifact relative paths for diffs/logs
4. Canonical screenshot strategy:
   - run screenshot assertions only on canonical runner/backend (Linux + fixed renderer/software).
   - run logic-only elsewhere (no screenshot asserts).
**Gate:** CI reliable on PRs; failures show names + downloadable diffs + repro.

---

## 6) Parallel Execution Plan (3–5 agents)

### Shared prerequisite (all agents)
- Phase 0 interface freeze: flags, `test_harness` contract, output paths, report schema, determinism contract (incl FP/env/fs).

### Agent A — Engine/Test Mode Core
- Phase 1: CLI parsing, determinism pins (FP/env), coroutine-per-frame runner, exit/watchdogs, args to Lua.
- Also: `test_runtime`, `path_sandbox`, `artifact_store`.

### Agent B — Input + Harness Bindings
- Phase 2: input event queue + input override + `test_harness` input APIs + constants.
- Also: text input, gamepad, input trace, record/replay hooks.

### Agent C — Headless + Screenshot Capture
- Headless path + framebuffer readback + PNG writing + path safety.
- Also: ROI/masks/stabilization + `.meta.json` loading + baseline_key support.

### Agent D — Lua Framework + Example Tests
- Phase 3 + Phase 5: runner/discovery/assertions/actions/reporters + initial tests.
- Also: tags/filtering, retries/flaky marking, skip/xfail/quarantine, per-test timeouts.

### Agent E (optional) — Verification + CI + Hardening
- Phase 4 + Phase 6: state query, screenshot diff, baseline manager, log capture, GitHub Actions, summary script.
- Optional: determinism audit + `--isolate-tests` launcher strategy.

---

## 7) Milestones (Definition of Done)

1. **M0 (Contracts frozen):** flags + `test_harness` API + paths + report schema agreed and stubbed; determinism contract documented (incl FP/env/fs).
2. **M1 (First runnable test):** `--test-mode --test-script minimal.lua` waits frames + exits deterministically.
3. **M2 (MVP E2E):** one real test drives input + asserts state + produces JSON report.
4. **M3 (Visual verification):** screenshot capture + baseline compare + diff artifacts + update-baselines; ROI/masks work; baseline_key works.
5. **M4 (CI green):** GitHub Actions runs headless, publishes results, uploads artifacts; job summary actionable (repro command, seed, diff paths).
6. **M5 (Coverage):** 3 stable example tests + docs for adding tests/updating baselines; forensics bundle on failures.
7. **M6 (Hardening):** determinism audit tripwire + per-test timeouts + skip/xfail/quarantine fully wired; optional isolate-tests mode.

---

## Appendix A: Test API Surface Design Principles

The Test API Surface is a deliberately narrow interface exported by the game for test automation. It is a contract between tests and game code.

### Design principles
1. Stability: versioned + documented like a public API.
2. Minimalism: expose only what tests need.
3. Determinism: queries/commands produce same results given same state.
4. Whitelisting: unknown paths/names fail explicitly.

### Versioning requirement (hard)
- Expose `test_api_version` and a changelog entry for breaking changes.
- Tests can declare minimum version/capabilities and fail/skip early.

### Anti-patterns
- Arbitrary access to internal engine graphs.
- TOCTOU races (all state access frame-synchronized).
- Tests calling internal functions directly.

---

## Appendix B: Forensics Bundle Specification

When a test run fails (exit code ≠ 0) or times out/crashes, write a forensics bundle.

### Contents of `tests/out/<run_id>/forensics/`
| File | Description |
|------|-------------|
| `run_manifest.json` | CLI args, seed, platform, renderer, resolution, git SHA, ordering hash |
| `input_trace.jsonl` | All injected inputs with frame numbers |
| `logs.jsonl` | Structured logs `{ frame, level, category, message }` |
| `last_logs.txt` | Tail of log buffer (e.g. last 500 lines) |
| `final_frame.png` | Screenshot at crash/timeout (if available) |
| `last_frames/` | Optional ring buffer of last N frames captured only on failure |
| `repro.sh` | Copy/paste repro script |
| `repro.ps1` | PowerShell repro script |
| `forensics.zip` | Optional zipped bundle |

### `run_manifest.json` example
```json
{
  "args": ["--test-mode", "--headless", "--seed", "12345", "--test-suite", "e2e"],
  "seed": 12345,
  "platform": "linux",
  "renderer": "vulkan",
  "baseline_key": "software_sdr_srgb",
  "resolution": "1280x720",
  "git_sha": "abc123",
  "test_ordering_hash": "sha256:...",
  "shard": 1,
  "total_shards": 4,
  "timeout_seconds": 600,
  "timestamp": "2026-02-02T12:00:00Z"
}
