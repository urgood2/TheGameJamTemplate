# Master Plan: End-to-End (E2E) Game Testing System

## 0) Outcomes & Non‑Goals
- **Outcomes**
  - Run tests via `./game --test-mode [--headless] [--test-script <file> | --test-suite <dir>]`.
  - Tests can **drive input**, **wait deterministically by frames**, **query/set state**, **assert logs**, and **assert screenshots** (baseline + diff artifacts).
  - CI runs headless, uploads artifacts, and reports results (JUnit/JSON).

### 0.1 Determinism Contract (Test Mode)

In `--test-mode`, the engine must behave as a **deterministic simulator** given:
- the same binary + content, the same `--seed`, the same resolution, and the same test script(s).

**Rules (enforced where feasible):**
1. **Wall-clock time must not affect simulation.** No `now()` driving gameplay. Simulation time == `frame_count / fixed_dt`.
2. **Randomness must be routed through seeded RNG(s).** No unseeded RNG, no `random_device` in gameplay paths.
3. **Update ordering must be stable.** No unordered container iteration affecting gameplay outcomes.
4. **Asynchronous jobs must be deterministic.** Either disabled in test mode, forced single-thread, or completion order made stable.
5. **Asset streaming/loading must have deterministic completion points.** Explicit "ready" signals for tests to wait on.

**Rendering caveat:**
- Pixel-perfect screenshot baselines are only guaranteed on a controlled render stack (same backend/driver/software renderer).
- If the render stack varies, use masking/ROI or run screenshot tests on a canonical CI renderer only.

- **Non‑Goals (v1)**
  - Web/Emscripten support, perceptual diff/ML diffing, full UI automation framework, multiplayer/network determinism.
  - Cross-GPU pixel-perfect equivalence (unless running a canonical software renderer / fixed backend in CI).

---

## 1) Canonical Naming, Structure, and Paths

### 1.1 C++ (engine)
- `src/testing/`
  - `test_mode_config.{hpp,cpp}`
  - `test_runtime.{hpp,cpp}`           — **owns all test subsystems + lifecycle**
  - `test_mode.{hpp,cpp}`              — thin integration layer into engine loop
  - `test_input_provider.{hpp,cpp}`
  - `test_harness_lua.{hpp,cpp}`       — Lua bindings; delegates to TestRuntime
  - `lua_state_query.{hpp,cpp}`
  - `screenshot_capture.{hpp,cpp}`
  - `screenshot_compare.{hpp,cpp}`
  - `log_capture.{hpp,cpp}`
  - `baseline_manager.{hpp,cpp}`
  - `artifact_store.{hpp,cpp}`         — **atomic writes, relative paths, manifest**
  - `path_sandbox.{hpp,cpp}`           — **canonicalize + restrict output roots**
  - `test_forensics.{hpp,cpp}`         — **crash/timeout bundles: logs + last frames**

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
  - **Optional per-baseline metadata (versioned):**
    - `.../<name>.meta.json` (thresholds, ROI, masks, notes)
- Outputs (ignored by git): `tests/out/<run_id>/`
  - `report.json`
  - `report.junit.xml`
  - `artifacts/` (screenshots, diffs, logs, per-test debug)
  - `forensics/`
    - `run_manifest.json`   — args, seed, platform, renderer, git sha
    - `input_trace.jsonl`   — frame-indexed injected inputs
    - `last_logs.txt`       — tail of log buffer

---

## 2) CLI Contract (Single Source of Truth)

Implement these flags (all optional unless noted):
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
- `--artifacts <dir>` (default: `tests/out/<run_id>/artifacts`)
- `--report-json <path>` (default: `tests/out/<run_id>/report.json`)
- `--report-junit <path>` (default: `tests/out/<run_id>/report.junit.xml`)
- `--update-baselines` (accept missing/mismatched baselines by copying actual → baseline)
- `--fail-on-missing-baseline` (default: `true`; ignored if `--update-baselines`)
- `--shard <n>` and `--total-shards <k>` (default: `1/1`; deterministic sharding)
- `--timeout-seconds <int>` (default: `600`; hard kill to avoid hung CI)
- `--retry-failures <n>` (default: `0`; rerun failing tests up to N times)
- `--allow-flaky` (default: `false`; if false, flaky tests still fail CI)

### Exit code contract
| Code | Meaning |
|------|---------|
| `0`  | All tests passed |
| `1`  | One or more tests failed |
| `2`  | Harness/configuration error (bad flags, missing scripts, invalid paths) |
| `3`  | Timeout/watchdog abort |
| `4`  | Crash (unhandled exception / fatal error) |

**Behavior rules**
- `--test-mode` with neither `--test-script` nor `--test-suite` loads `assets/scripts/tests/framework/bootstrap.lua` and defaults to `--test-suite assets/scripts/tests/e2e`.
- Unknown/invalid flags print usage and exit `2`.
- All artifact/report paths are created if missing; path traversal outside repo/output roots is rejected.
  - **Enforcement is centralized in `path_sandbox` + `artifact_store` (no ad-hoc checks).**

---

## 3) `test_harness` Lua API Contract (Stable Interface)

Expose a global table `test_harness` **only in test mode**.

### 3.1 Frame/time control (coroutine-friendly)
- `test_harness.wait_frames(n)`
  - Validates `n >= 0`; **yields** the test coroutine until `n` frames have advanced.
- `test_harness.now_frame() -> integer`
- `test_harness.wait_until(predicate_fn, opts?) -> true|error`
  - Polls `predicate_fn()` once per frame until it returns truthy.
  - `opts`: `{ timeout_frames=300, fail_message="...", poll_every_frames=1 }`
  - **Deterministic:** timeout measured in frames, not wall-clock.
- `test_harness.wait_until_state(path, expected, opts?) -> true|error`
  - Equivalent to `wait_until(function() return get_state(path) == expected end, ...)`
- `test_harness.wait_until_log(substr_or_regex, opts?) -> true|error`
  - Waits until a matching log line appears (supports `since=mark`).
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
- `test_harness.text_input(str)` — inject text as OS/input-layer events (not `set_state` hacks)
- `test_harness.gamepad_button_down(pad, button)`
- `test_harness.gamepad_button_up(pad, button)`
- `test_harness.gamepad_set_axis(pad, axis, value)` — value in `[-1, 1]`

### 3.3 State query/set (via Test API Surface)
- `test_harness.get_state(path) -> value|nil, err?`
  - Reads from the **Test API Surface** (a stable property bag exported by the game in test mode), **not** arbitrary internal engine objects.
  - Path supports: `a.b.c`, numeric segments (`enemies.1.health`), and optional bracket form (`inventory[1].name`).
- `test_harness.set_state(path, value) -> true|nil, err?`
  - Writes to the Test API Surface only (or invokes explicit test commands).

#### 3.3.1 Explicit queries/commands (preferred over raw path access)
- `test_harness.query(name, args?) -> value|nil, err?`
  - Examples: `query("current_scene")`, `query("ui_element_rect", { name="inventory_button" })`
- `test_harness.command(name, args?) -> true|nil, err?`
  - Examples: `command("load_scene", { name="combat_arena" })`,
              `command("spawn_enemy", { archetype="slime", x=10, y=5 })`
  - Commands are deterministic and can be validated/whitelisted.

### 3.4 Screenshots & comparisons
- `test_harness.screenshot(path) -> true|nil, err?`
- `test_harness.assert_screenshot(name, opts?) -> true|error`
  - `name`: logical name like `main_menu_idle.png`
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
  - Writes: actual + diff into artifacts; reads baseline from platform/resolution baseline dir.
  - If `--update-baselines`, copies actual → baseline and records "updated baseline" in report.
  - **If `<name>.meta.json` exists, it merges into `opts` as defaults (test can override).**

### 3.5 Logs
- `test_harness.log_mark() -> index`
- `test_harness.find_log(substr_or_regex, opts?) -> found, index, line`
  - `opts`: `{ since=index, regex=false }`
- `test_harness.clear_logs()`

### 3.6 Runtime args surfaced to Lua
- `test_harness.args` table: `{ seed, fixed_fps, resolution, shard, total_shards, update_baselines, baseline_dir, artifacts_dir, report_json, report_junit }`
- Key constants (at least): `KEY_*` and mouse buttons, mapped to the engine's input system codes.

---

## 4) Execution Model (Deterministic + Blocking Waits)

- In `--test-mode`, engine loads `assets/scripts/tests/framework/bootstrap.lua`.
- `bootstrap.lua` creates a **coroutine** that runs discovery + `TestRunner.run()`.
- Each frame, the engine:
  1. Applies queued test input events scheduled for this frame.
  2. Advances the game with a fixed `dt = 1/fixed_fps`.
  3. Resumes the test coroutine until it yields (typically via `wait_frames`) or completes.
- A hard watchdog (`--timeout-seconds`) aborts with a clear report if the test run never exits.
  - **On timeout/crash, write a forensics bundle:**
    - final screenshot (if possible) + last N log lines + input trace tail
    - the exact CLI args and resolved paths
    - shard info + discovered test ordering

### Test isolation rules

Before each `it(...)`, the runner performs a **deterministic cleanup step**:
1. Clear pending injected inputs + reset input down-state.
2. `log_mark()` to create a clean log window for assertions.
3. (Optional) Call a game-defined `command("reset_to_known_state")` hook.

---

## 5) Implementation Phases (with acceptance gates)

### Phase 0 — Recon + Interface Freeze (enables parallel work)
1. Locate integration points: CLI parsing, game loop timestep control, input backend, renderer readback, logger sink, Lua binding registry.
2. Add stub headers/skeletons for all `src/testing/*` files and Lua framework files so agents can work in parallel.
3. **Document the Determinism Contract (Section 0.1) and confirm engine can meet each rule.**
**Gate:** repo compiles with stubs; contracts above are committed as docs/comments.

### Phase 1 — Test Mode Core (C++)
1. `test_mode_config`: parse flags, validate, compute `<run_id>`, create output dirs.
2. `test_runtime`: **central object owning all test subsystems + lifecycle.**
3. `test_mode`: enable determinism (seed RNG, fixed timestep, disable vsync, optional audio off), track `now_frame`.
4. Engine loop integration: load `bootstrap.lua`, run coroutine per frame, honor `exit(code)`, honor watchdog.
5. Headless path: prefer true offscreen; fallback to hidden window + CI `xvfb-run`.
6. `path_sandbox` + `artifact_store`: centralized path safety and atomic artifact writes.
**Gate:** `./game --test-mode --test-script <minimal.lua>` can `wait_frames`, log, and `exit(0)`.

### Phase 2 — Input Injection (C++)
1. `test_input_provider`: per-frame scheduled event queue (KeyDown/KeyUp/MouseMove/MouseDown/MouseUp/Wait optional).
2. Input system override in test mode (normal device input ignored or merged by policy; default ignore).
3. Bind input functions in `test_harness_lua`, including **text input and gamepad**.
4. **Record all injected inputs to `input_trace.jsonl` for forensics.**
**Gate:** a Lua script can press/hold/release keys, enter text, use gamepad, and click reliably, with frame-accurate timing.

### Phase 3 — Lua Test Framework (Lua)
1. `test_runner.lua`: `describe/it`, hooks, deterministic ordering, per-test results, per-test frame budgets.
   - **Support tags:** `it("does X", { tags={"ui","smoke"} }, function() ... end)`
   - **Implement `--include-tag/--exclude-tag` and `--test-filter`.**
   - **Implement `--list-tests` for debugging and shard verification.**
   - **Implement test isolation (cleanup before each test).**
2. `discovery.lua`: load `--test-script` or enumerate `--test-suite` deterministically (via engine-provided `list_files` if needed).
3. `assertions.lua` + `matchers.lua`: consistent errors, includes suite/test names and frame/time context.
4. Reporters: JSON + JUnit (TAP optional).
   - **JSON is authoritative** and includes:
     - environment (platform, cpu, renderer/backend, resolution)
     - resolved baseline/artifact roots
     - per-test: `duration_frames`, `duration_ms` (optional), artifacts list, failure kind
     - run-level: seed, shard info, discovered ordering hash
   - **If retries are enabled:**
     - Mark tests that fail then pass as `status="flaky"`
     - Include attempt logs and artifacts per attempt (or at least for the failing attempt)
     - If `--allow-flaky=false`, exit non-zero even if all ended passing after retries
5. Sharding: run only tests where `(test_index % total_shards) == (shard-1)` (stable enumeration required).
**Gate (MVP):** one example E2E test runs and produces `report.json` + correct exit code.

### Phase 4 — Verification Systems (C++ + Lua wiring)
1. `lua_state_query`: robust path traversal (dot + numeric + bracket) **against the Test API Surface**, `get_state` + `set_state`.
2. **`query` / `command` explicit APIs for stable, versioned test interactions.**
3. `screenshot_capture`: framebuffer readback to PNG (windowed + headless).
4. `screenshot_compare`: pixel diff + threshold + diff image; **support ROI, masks, stabilization**; return rich error context.
5. `baseline_manager`: resolve baseline dir by platform/resolution; implement `--update-baselines` behavior; **read/merge `.meta.json`**.
6. `log_capture`: ring buffer sink integrated into engine logging; implement mark/find/clear.
7. `test_forensics`: **crash/timeout bundles with seed, args, trace, last frames.**
8. **Condition wait APIs**: `wait_until`, `wait_until_state`, `wait_until_log`.
**Gate:** `assert_state`, `assert_log_contains`, and `assert_screenshot` work end-to-end and generate artifacts on failure.

### Phase 5 — Example Tests + Test Hooks (Game Lua/C++)
1. Add minimal "test-visible" state hooks (only in test mode) to expose stable signals:
   - **Export a Test API Surface:**
     - Properties: `game.initialized`, `game.current_scene`, `game.paused`
     - Queries: `ui.element_rect(name)`, `ui.element_visible(name)`
     - Commands: `scene.load(name)`, `combat.spawn_enemy(...)`, etc.
   - **Keep this surface small and versioned; treat it like a public API.**
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
3. **Job summary (recommended, not optional):**
   - Parse JSON report and print:
     - failing test full names
     - seed + resolution + shard info
     - "repro command" line (copy/paste)
     - artifact relative paths for diff images / logs
4. **Canonical screenshot strategy:**
   - Run screenshot assertions only on a single canonical CI runner/backend (e.g., Linux + fixed renderer/software).
   - Run logic-only tests on other platforms if desired (no screenshot asserts).
**Gate:** CI reliably runs on PRs; failures show failing test names + downloadable diffs.

---

## 6) Parallel Execution Plan (3–5 agents)

### Shared prerequisite (all agents)
- Complete **Phase 0** interface freeze: CLI flags, `test_harness` contract, output paths, report schema, **Determinism Contract**.

### Agent A — Engine/Test Mode Core
- Phase 1: CLI parsing, determinism, coroutine-per-frame runner, exit/watchdog, args surfaced to Lua.
- **Also:** `test_runtime`, `path_sandbox`, `artifact_store`.

### Agent B — Input + Harness Bindings
- Phase 2: `TestInputProvider` + input system override + `test_harness` input APIs + key constants.
- **Also:** text input, gamepad, input trace recording.

### Agent C — Headless + Screenshot Capture
- Phase 1.4/1.5: headless path + framebuffer readback + PNG writing + directory/path safety.
- **Also:** ROI/mask support, stabilization, `.meta.json` loading.

### Agent D — Lua Framework + Example Tests
- Phase 3 + Phase 5: runner/discovery/assertions/actions/reporters + write initial tests (using contract stubs until C++ lands).
- **Also:** tags, filtering, retries/flaky marking, test isolation.

### Agent E (optional) — Verification + CI
- Phase 4 + Phase 6: state query, screenshot diff, baseline manager, log capture, GitHub Actions, sharding/summary.
- **Also:** forensics, condition waits, CI job summary script.

---

## 7) Milestones (Definition of Done)

1. **M0 (Contracts frozen):** flags + `test_harness` API + paths + report schema agreed and stubbed; **Determinism Contract documented**.
2. **M1 (First runnable test):** `--test-mode --test-script minimal.lua` can wait frames and exit deterministically.
3. **M2 (MVP E2E):** one real test drives input + asserts state + produces JSON report.
4. **M3 (Visual verification):** screenshot capture + baseline compare + diff artifacts + update-baselines flow; **ROI/masks work**.
5. **M4 (CI green):** GitHub Actions runs headless tests, publishes results, uploads artifacts; **job summary is actionable**.
6. **M5 (Coverage):** 3 stable example tests + docs for adding new tests and updating baselines; **forensics bundle generated on failures**.

---

## Appendix A: Test API Surface Design Principles

The **Test API Surface** is a deliberately narrow interface exported by the game specifically for test automation. It acts as a contract between tests and the game code.

**Design principles:**
1. **Stability:** Changes to the Test API Surface are versioned and documented, similar to a public API.
2. **Minimalism:** Only expose what tests actually need. Don't mirror internal object graphs.
3. **Determinism:** Every query returns the same result given the same game state. Every command produces the same outcome given the same inputs.
4. **Whitelisting:** `get_state`/`set_state` paths and `query`/`command` names are validated against a whitelist. Unknown paths/names fail explicitly.

**Anti-patterns to avoid:**
- Generic access to arbitrary engine internals (fragile, breaks on refactor).
- Time-of-check vs time-of-use races (all state access is frame-synchronized).
- Test code calling internal functions directly (couples tests to implementation).

---

## Appendix B: Forensics Bundle Specification

When a test run fails (exit code ≠ 0) or times out/crashes, a forensics bundle is written to help reproduce the failure.

**Contents of `tests/out/<run_id>/forensics/`:**

| File | Description |
|------|-------------|
| `run_manifest.json` | CLI args, seed, platform, renderer, resolution, git SHA, test ordering hash |
| `input_trace.jsonl` | All injected inputs with frame numbers |
| `last_logs.txt` | Tail of log buffer (last 500 lines or so) |
| `final_frame.png` | Screenshot at crash/timeout (if available) |

**`run_manifest.json` example:**
```json
{
  "args": ["--test-mode", "--headless", "--seed", "12345", "--test-suite", "e2e"],
  "seed": 12345,
  "platform": "linux",
  "renderer": "vulkan",
  "resolution": "1280x720",
  "git_sha": "abc123",
  "test_ordering_hash": "sha256:...",
  "shard": 1,
  "total_shards": 4,
  "timeout_seconds": 600,
  "timestamp": "2026-02-02T12:00:00Z"
}
```

**Repro command (printed in CI summary):**
```bash
./build/game --test-mode --seed 12345 --resolution 1280x720 --test-script tests/e2e/combat_test.lua
```

---

## Appendix C: Screenshot Comparison Strategy

**Recommended CI approach:**

1. **Canonical runner:** All screenshot assertions run on a single CI runner with a fixed render stack (e.g., Linux + Mesa software renderer or a specific GPU driver version).

2. **Non-canonical runners:** Run the same tests but skip screenshot assertions (or run them with very loose thresholds + no failure).

3. **ROI/mask usage:** For UI tests, compare only the region of interest (e.g., the dialog box, not the full screen). Mask dynamic elements (timers, particle effects).

4. **Stabilization:** For animated content, use `stabilize_frames=5` to wait until the frame is stable before capturing.

5. **Per-baseline metadata:** Store thresholds and masks in `<baseline>.meta.json` rather than hardcoding in tests. This allows adjusting tolerances without changing test code.
