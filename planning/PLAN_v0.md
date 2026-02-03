# Master Plan: End-to-End (E2E) Game Testing System

## 0) Outcomes & Non‑Goals
- **Outcomes**
  - Run tests via `./game --test-mode [--headless] [--test-script <file> | --test-suite <dir>]`.
  - Tests can **drive input**, **wait deterministically by frames**, **query/set state**, **assert logs**, and **assert screenshots** (baseline + diff artifacts).
  - CI runs headless, uploads artifacts, and reports results (JUnit/JSON).
- **Non‑Goals (v1)**
  - Web/Emscripten support, perceptual diff/ML diffing, full UI automation framework, multiplayer/network determinism.

---

## 1) Canonical Naming, Structure, and Paths

### 1.1 C++ (engine)
- `src/testing/`
  - `test_mode_config.{hpp,cpp}`
  - `test_mode.{hpp,cpp}`
  - `test_input_provider.{hpp,cpp}`
  - `test_harness_lua.{hpp,cpp}`
  - `lua_state_query.{hpp,cpp}`
  - `screenshot_capture.{hpp,cpp}`
  - `screenshot_compare.{hpp,cpp}`
  - `log_capture.{hpp,cpp}`
  - `baseline_manager.{hpp,cpp}`

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
- Baselines (versioned): `tests/baselines/<platform>/<WxH>/...png`
  - `<platform>`: `linux|windows|mac|unknown`
  - `<WxH>`: `1280x720` etc.
- Outputs (ignored by git): `tests/out/<run_id>/`
  - `report.json`
  - `report.junit.xml`
  - `artifacts/` (screenshots, diffs, logs, per-test debug)

---

## 2) CLI Contract (Single Source of Truth)
Implement these flags (all optional unless noted):
- `--test-mode` (enables all test systems)
- `--headless` (offscreen/hidden rendering path; CI-friendly)
- `--test-script <path>` (run one test file)
- `--test-suite <dir>` (discover and run all tests under directory)
- `--seed <u32>` (default: fixed, e.g. `12345`)
- `--fixed-fps <int>` (default: `60`; forces fixed timestep)
- `--resolution <WxH>` (default: `1280x720`)
- `--artifacts <dir>` (default: `tests/out/<run_id>/artifacts`)
- `--report-json <path>` (default: `tests/out/<run_id>/report.json`)
- `--report-junit <path>` (default: `tests/out/<run_id>/report.junit.xml`)
- `--update-baselines` (accept missing/mismatched baselines by copying actual → baseline)
- `--fail-on-missing-baseline` (default: `true`; ignored if `--update-baselines`)
- `--shard <n>` and `--total-shards <k>` (default: `1/1`; deterministic sharding)
- `--timeout-seconds <int>` (default: `600`; hard kill to avoid hung CI)

**Behavior rules**
- `--test-mode` with neither `--test-script` nor `--test-suite` loads `assets/scripts/tests/framework/bootstrap.lua` and defaults to `--test-suite assets/scripts/tests/e2e`.
- Unknown/invalid flags print usage and exit `1`.
- All artifact/report paths are created if missing; path traversal outside repo/output roots is rejected.

---

## 3) `test_harness` Lua API Contract (Stable Interface)
Expose a global table `test_harness` **only in test mode**.

### 3.1 Frame/time control (coroutine-friendly)
- `test_harness.wait_frames(n)`  
  - Validates `n >= 0`; **yields** the test coroutine until `n` frames have advanced.
- `test_harness.now_frame() -> integer`
- `test_harness.exit(code)`  
  - Requests engine shutdown with process exit code.

### 3.2 Input injection (applied at frame boundaries)
- `test_harness.press_key(keycode)`
- `test_harness.release_key(keycode)`
- `test_harness.tap_key(keycode, frames_down=2)` (helper)
- `test_harness.move_mouse(x, y)`
- `test_harness.mouse_down(button)`
- `test_harness.mouse_up(button)`
- `test_harness.click(x, y, button=1, frames_down=1)` (helper)

### 3.3 State query/set
- `test_harness.get_state(path) -> value|nil, err?`  
  - Path supports: `a.b.c`, numeric segments (`enemies.1.health`), and optional bracket form (`inventory[1].name`).
- `test_harness.set_state(path, value) -> true|nil, err?`

### 3.4 Screenshots & comparisons
- `test_harness.screenshot(path) -> true|nil, err?`
- `test_harness.assert_screenshot(name, opts?) -> true|error`
  - `name`: logical name like `main_menu_idle.png`
  - `opts`: `{ threshold_percent=0.1, per_channel_tolerance=2, generate_diff=true }`
  - Writes: actual + diff into artifacts; reads baseline from platform/resolution baseline dir.
  - If `--update-baselines`, copies actual → baseline and records “updated baseline” in report.

### 3.5 Logs
- `test_harness.log_mark() -> index`
- `test_harness.find_log(substr_or_regex, opts?) -> found, index, line`
  - `opts`: `{ since=index, regex=false }`
- `test_harness.clear_logs()`

### 3.6 Runtime args surfaced to Lua
- `test_harness.args` table: `{ seed, fixed_fps, resolution, shard, total_shards, update_baselines, baseline_dir, artifacts_dir, report_json, report_junit }`
- Key constants (at least): `KEY_*` and mouse buttons, mapped to the engine’s input system codes.

---

## 4) Execution Model (Deterministic + Blocking Waits)
- In `--test-mode`, engine loads `assets/scripts/tests/framework/bootstrap.lua`.
- `bootstrap.lua` creates a **coroutine** that runs discovery + `TestRunner.run()`.
- Each frame, the engine:
  1. Applies queued test input events scheduled for this frame.
  2. Advances the game with a fixed `dt = 1/fixed_fps`.
  3. Resumes the test coroutine until it yields (typically via `wait_frames`) or completes.
- A hard watchdog (`--timeout-seconds`) aborts with a clear report if the test run never exits.

---

## 5) Implementation Phases (with acceptance gates)

### Phase 0 — Recon + Interface Freeze (enables parallel work)
1. Locate integration points: CLI parsing, game loop timestep control, input backend, renderer readback, logger sink, Lua binding registry.
2. Add stub headers/skeletons for all `src/testing/*` files and Lua framework files so agents can work in parallel.
**Gate:** repo compiles with stubs; contracts above are committed as docs/comments.

### Phase 1 — Test Mode Core (C++)
1. `test_mode_config`: parse flags, validate, compute `<run_id>`, create output dirs.
2. `test_mode`: enable determinism (seed RNG, fixed timestep, disable vsync, optional audio off), track `now_frame`.
3. Engine loop integration: load `bootstrap.lua`, run coroutine per frame, honor `exit(code)`, honor watchdog.
4. Headless path: prefer true offscreen; fallback to hidden window + CI `xvfb-run`.
**Gate:** `./game --test-mode --test-script <minimal.lua>` can `wait_frames`, log, and `exit(0)`.

### Phase 2 — Input Injection (C++)
1. `test_input_provider`: per-frame scheduled event queue (KeyDown/KeyUp/MouseMove/MouseDown/MouseUp/Wait optional).
2. Input system override in test mode (normal device input ignored or merged by policy; default ignore).
3. Bind input functions in `test_harness_lua`.
**Gate:** a Lua script can press/hold/release keys and click reliably, with frame-accurate timing.

### Phase 3 — Lua Test Framework (Lua)
1. `test_runner.lua`: `describe/it`, hooks, deterministic ordering, per-test results, per-test frame budgets.
2. `discovery.lua`: load `--test-script` or enumerate `--test-suite` deterministically (via engine-provided `list_files` if needed).
3. `assertions.lua` + `matchers.lua`: consistent errors, includes suite/test names and frame/time context.
4. Reporters: JSON + JUnit (TAP optional).
5. Sharding: run only tests where `(test_index % total_shards) == (shard-1)` (stable enumeration required).
**Gate (MVP):** one example E2E test runs and produces `report.json` + correct exit code.

### Phase 4 — Verification Systems (C++ + Lua wiring)
1. `lua_state_query`: robust path traversal (dot + numeric + bracket), `get_state` + `set_state`.
2. `screenshot_capture`: framebuffer readback to PNG (windowed + headless).
3. `screenshot_compare`: pixel diff + threshold + diff image; return rich error context.
4. `baseline_manager`: resolve baseline dir by platform/resolution; implement `--update-baselines` behavior.
5. `log_capture`: ring buffer sink integrated into engine logging; implement mark/find/clear.
**Gate:** `assert_state`, `assert_log_contains`, and `assert_screenshot` work end-to-end and generate artifacts on failure.

### Phase 5 — Example Tests + Test Hooks (Game Lua/C++)
1. Add minimal “test-visible” state hooks (only in test mode) to expose stable signals:
   - `game.initialized`, `game.current_scene`, `game.paused`, `ui.elements.<name> = {x,y,w,h}`, etc.
2. Implement 3 tests:
   - Menu navigation + screenshot baseline
   - Combat interaction via deterministic setup + log/state asserts
   - UI (pause/inventory) with state + screenshot asserts
3. Create baselines per platform/resolution (initially one canonical CI platform/resolution).
**Gate:** 3 tests pass locally and headless; reruns are stable.

### Phase 6 — CI (GitHub Actions) + Parallelism
1. Workflow `.github/workflows/e2e-tests.yml`:
   - Build (cache dependencies/build if feasible)
   - Run `./build/game --test-mode --headless --test-suite ... --report-* ... --artifacts ...`
   - Upload `tests/out/**` artifacts (always), highlight diffs on failure
   - Publish JUnit results
2. Matrix sharding (4 shards default), `fail-fast: false`, per-shard artifacts.
3. Optional PR summary from JSON report (job summary or PR comment).
**Gate:** CI reliably runs on PRs; failures show failing test names + downloadable diffs.

---

## 6) Parallel Execution Plan (3–5 agents)

### Shared prerequisite (all agents)
- Complete **Phase 0** interface freeze: CLI flags, `test_harness` contract, output paths, report schema.

### Agent A — Engine/Test Mode Core
- Phase 1: CLI parsing, determinism, coroutine-per-frame runner, exit/watchdog, args surfaced to Lua.

### Agent B — Input + Harness Bindings
- Phase 2: `TestInputProvider` + input system override + `test_harness` input APIs + key constants.

### Agent C — Headless + Screenshot Capture
- Phase 1.4/1.5: headless path + framebuffer readback + PNG writing + directory/path safety.

### Agent D — Lua Framework + Example Tests
- Phase 3 + Phase 5: runner/discovery/assertions/actions/reporters + write initial tests (using contract stubs until C++ lands).

### Agent E (optional) — Verification + CI
- Phase 4 + Phase 6: state query, screenshot diff, baseline manager, log capture, GitHub Actions, sharding/summary.

---

## 7) Milestones (Definition of Done)
1. **M0 (Contracts frozen):** flags + `test_harness` API + paths + report schema agreed and stubbed.
2. **M1 (First runnable test):** `--test-mode --test-script minimal.lua` can wait frames and exit deterministically.
3. **M2 (MVP E2E):** one real test drives input + asserts state + produces JSON report.
4. **M3 (Visual verification):** screenshot capture + baseline compare + diff artifacts + update-baselines flow.
5. **M4 (CI green):** GitHub Actions runs headless tests, publishes results, uploads artifacts.
6. **M5 (Coverage):** 3 stable example tests + docs for adding new tests and updating baselines.