```markdown
# Master Plan: End-to-End (E2E) Game Testing System — v4

This document integrates GPT Pro's v3.1 revisions into the v3 plan, adding:
- Orchestrator-based test execution with process isolation
- Stable test IDs and centralized test metadata manifest
- Step annotations and structured artifact metadata
- Typed Test API registry with schema validation
- Network sandbox and enhanced path safety
- Hang diagnostics and determinism state diffs
- Chrome Trace export and optional failure video capture
- Semantic UI selectors for screenshot assertions
- Exact single-test execution mode
- Enhanced clang-tidy determinism profile

---

## 0) Outcomes & Non-Goals

### Outcomes
- Run tests via:
  - `./game --test-mode [--headless] [--test-script <file> | --test-suite <dir>]`
  - (CI recommended): `./tools/e2e_supervisor run -- <game args...>` for hardened timeout/crash handling and test orchestration
- Tests can:
  - **drive input**
  - **wait deterministically by frames**
  - **query/set state**
  - **assert logs**
  - **assert screenshots** (baseline + diff artifacts)
  - **assert performance budgets** (optional)
  - **produce structured steps and attachments** for debuggability
- CI runs headless, uploads artifacts, and reports results (JUnit + JSON + HTML gallery).

### Non-Goals (v1)
- Web/Emscripten support, perceptual diff/ML diffing, full UI automation framework, multiplayer/network determinism.
- Cross-GPU pixel-perfect equivalence (unless running a canonical software renderer / fixed backend in CI).

### Conventions (for implementability)
- **MUST** = required for correctness/CI reliability.
- **SHOULD** = strongly recommended; may be staged after MVP if necessary.
- All file paths written by the harness **MUST** be **relative** to the run root and validated against allowed roots (see §2 Behavior rules).

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
   - Implementation pinning checklist (SHOULD, to make this testable):
     - Record FP config in `run_manifest.json.determinism_pins` (FTZ/DAZ, rounding, flush mode).
     - Ensure the pin is applied once at startup before any simulation or scripts run.

7. **Process environment must be pinned.**
   - Freeze locale/timezone in test mode (or explicitly set to a known value).
   - Avoid environment-dependent formatting/parsing affecting state or UI layout.
   - Concrete target (SHOULD):
     - Locale: `C`
     - Timezone: `UTC`
     - Record both in `run_manifest.json.determinism_pins`.

8. **Filesystem nondeterminism must be eliminated.**
   - Never rely on directory enumeration order; always sort deterministically.
   - Avoid using file mtimes / "latest file" logic in test-mode gameplay paths.

9. **GPU/renderer synchronization points must be explicit for screenshots.**
   - Screenshot capture occurs at a defined frame boundary after a completed present/render pass.
   - If async readback is used, completion must be deterministic and frame-indexed.

10. **External network access must be pinned/disabled.**
    - Default: outbound network disabled in `--test-mode` to avoid nondeterminism and CI risk.
    - If needed: allow `localhost` only via explicit flag (`--allow-network=localhost`).
    - Enforcement MUST be observable (testable):
      - Violations produce `DET_NET` determinism tripwire output and `failure_kind=harness_error` (or `determinism_divergence` if caught during audit) with clear message.

### Diagnostics stance
- In `--test-mode`, determinism violations should produce an explicit warning/error category (easy to grep in CI).
- Additionally, the engine provides determinism "tripwires":
  - fail-fast option: `--determinism-violation=fatal|warn` (default: `fatal` in CI, `warn` locally)
  - each violation includes a stable code (`DET_TIME`, `DET_RNG`, `DET_FS_ORDER`, `DET_ASYNC_ORDER`, `DET_NET`, ...)
  - optional stack trace when available
- Testability requirement (SHOULD):
  - Each tripwire code maps to a stable `failure_kind` and includes enough context to reproduce (e.g., offending call site, frame number).

### Rendering caveat
- Pixel-perfect screenshot baselines are only guaranteed on a controlled render stack (same backend/driver/software renderer).
- If the render stack varies, use masking/ROI or run screenshot tests on a canonical CI renderer only.

---

## 0.2 Report + Manifest Contracts (Versioned)

### Goals
- Make `report.json` and `run_manifest.json` machine-validated and forwards-compatible.
- Stabilize failure classification so CI tooling can key off it reliably.

### Additions
- `report.json` includes:
  - `schema_version` (semver)
  - `failure_kind` (stable enum):
    - `assertion`
    - `timeout`
    - `crash`
    - `harness_error`
    - `determinism_divergence`
    - `log_gating`
    - `baseline_missing`
    - `baseline_mismatch`
    - `capability_missing`
    - `perf_budget_exceeded`
    - `unknown`
  - `engine_version` + `content_fingerprint` (hashes)
  - per-test: `status`, `attempts`, `artifacts[]` (structured), `timings_frames`, `timings_ms` (optional)
- `run_manifest.json` includes:
  - `schema_version`
  - `engine_version`, `git_sha`, `build_id`
  - `content_fingerprint` (hash of content pak / asset manifest)
  - `renderer_fingerprint` (backend + device + driver + colorspace)
  - `determinism_pins` (FTZ/DAZ, rounding, locale, TZ, thread mode, etc.)
  - `test_api_fingerprint` (hash of exported Test API registry descriptor)

### Schema/versioning rules (to make this implementable)
- `schema_version` MUST follow semver:
  - Major bump: breaking changes (field removal/meaning change).
  - Minor bump: additive/backwards-compatible fields.
  - Patch bump: clarifications/bugfixes with no consumer impact.
- JSON schemas SHOULD specify:
  - `additionalProperties` policy (explicitly allow or disallow unknown fields).
  - Required fields and stable enums.
  - File path fields as **relative paths** (no absolute paths in reports).

### Schemas (checked-in)
- `tests/schemas/report.schema.json`
- `tests/schemas/run_manifest.schema.json`
- `tests/schemas/test_api.schema.json`
The harness validates outputs against these schemas in `--test-mode` and exits `2` on schema violation.

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
  - `lua_sandbox.{hpp,cpp}`            — restricted Lua stdlib + require path controls
  - `screenshot_capture.{hpp,cpp}`
  - `screenshot_compare.{hpp,cpp}`
  - `log_capture.{hpp,cpp}`
  - `baseline_manager.{hpp,cpp}`
  - `artifact_store.{hpp,cpp}`         — atomic writes, relative paths, manifest
  - `path_sandbox.{hpp,cpp}`           — canonicalize + restrict output roots
  - `test_forensics.{hpp,cpp}`         — crash/timeout bundles: logs + last frames
  - `determinism_audit.{hpp,cpp}`      — optional: repeat runs + divergence detection
  - `determinism_guard.{hpp,cpp}`      — runtime tripwires (time/RNG/fs/async/network checks)
  - `perf_tracker.{hpp,cpp}`           — performance metrics collection + budgets
  - `test_api_registry.{hpp,cpp}`      — typed registry for state paths/queries/commands + versioning
  - `test_api_dump.{hpp,cpp}`          — writes `test_api.json` description artifact
  - (Added for completeness; referenced later in Phase 4)
    - `artifact_index.{hpp,cpp}`       — generates `index.html` linking per-test artifacts and repro commands
    - `timeline_writer.{hpp,cpp}`      — writes merged `timeline.jsonl`

### 1.1.1 Tools (host-side)
- `tools/e2e_supervisor/`
  - `main.cpp` (spawn + timeout + crash/timeout salvage + orchestration)
  - `process_utils.*` (portable process management)
  - `artifact_salvage.*` (write minimal forensics if game can't)
  - `orchestrator.*` (test enumeration, sharding, report merging)

### 1.2 Lua (tests)
- `assets/scripts/tests/`
  - `framework/`
    - `bootstrap.lua` (entrypoint loaded by engine in test mode)
    - `test_runner.lua` (DSL + execution + sharding + optional seeded shuffle)
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
  - `fixtures/` (deterministic saves, configs, input traces)

### 1.3 Baselines & outputs

#### Baselines (versioned)
- `tests/baselines/<platform>/<baseline_key>/<WxH>/<test_id>/...png`
  - `<platform>`: `linux|windows|mac|unknown`
  - `<baseline_key>`: `renderer+colorspace` (e.g. `vulkan_sdr_srgb`, `software_sdr_srgb`)
  - `<WxH>`: `1280x720` etc.
  - `<test_id>`: stable test identifier (e.g., `menu.main_loads`)
  - Optional per-baseline metadata (versioned):
    - `.../<test_id>/<name>.meta.json` (thresholds, ROI, masks, notes)
  - Baseline updates should be created on canonical render stacks only.
  - Non-canonical machines should default to staging updates to avoid poisoning baselines.
  - Testability requirement (SHOULD):
    - Baseline path resolution is pure and deterministic given (`platform`, `baseline_key`, `resolution`, `test_id`, `name`).

#### Baseline staging
- `tests/baselines_staging/` — staging area for baseline updates (not committed by default)

#### Outputs (ignored by git)
- `tests/out/<run_id>/`
  - `report.json`
  - `report.junit.xml`
  - `index.html`              — static run summary + artifact links (diff gallery)
  - `artifacts/` (screenshots, diffs, logs, per-test debug)
  - `forensics/`
    - `run_manifest.json`   — args, seed, platform, renderer, git sha, fingerprints
    - `input_trace.jsonl`   — frame-indexed injected inputs
    - `logs.jsonl`          — structured logs (frame, level, category, message)
    - `timeline.jsonl`      — merged frame timeline (inputs/logs/screenshot events/hashes/steps/attachments)
    - `last_logs.txt`       — tail of log buffer
    - `final_frame.png`     — crash/timeout screenshot if available
    - `last_frames/`        — optional ring buffer (e.g. last 30 frames) captured only on failure
    - `failure_clip.webm`   — optional: encoded clip of last N frames on failure (if enabled)
    - `hang_dump.json`      — optional: watchdog-triggered hang diagnostics (thread states, last known frame, watchdog reason)
    - `determinism_diff.json` — optional: divergence diff of Test API Surface snapshots (bounded)
    - `trace.json`          — optional: Chrome Trace JSON (Perfetto-compatible) for perf/stall debugging
    - `test_api.json`       — Test API registry descriptor
    - `repro.sh`            — per-run (and/or per-test) repro script
    - `repro.ps1`           — PowerShell repro script
    - `forensics.zip`       — optional zipped bundle for easy CI download
  - Clarification for implementability:
    - `run_id` uniqueness MAY use wall-clock time, but MUST NOT affect simulation determinism (only output paths).

---

## 2) CLI Contract (Single Source of Truth)

All flags optional unless noted:

### Core
- `--test-mode` (enables all test systems)
- `--headless` (offscreen/hidden rendering path; CI-friendly)
- `--test-script <path>` (run one test file)
- `--test-suite <dir>` (discover and run all tests under directory)
- `--list-tests` (discover tests, print stable full names, exit 0)
- `--list-tests-json <path>` (write test list as JSON for orchestrator consumption)
- `--test-filter <glob_or_regex>` (run matching tests only)
- `--run-test-id <id>` (run exactly one test by stable id; errors if not exactly one match)
- `--run-test-exact <full_name>` (run exactly one test by full name; errors if not exactly one match)
- `--exclude-tag <tag>` / `--include-tag <tag>` (tag-based selection)
- `--seed <u32>` (default: fixed, e.g. `12345`)
- `--fixed-fps <int>` (default: `60`; forces fixed timestep)
- `--resolution <WxH>` (default: `1280x720`)
- `--allow-network <mode>` (default: `deny`; `deny|localhost|any`)
- Clarifications (testability/clarity):
  - If both `--test-script` and `--test-suite` are provided, treat as configuration error and exit `2` (explicitly reject ambiguity).
  - `--test-filter` MUST define matching semantics:
    - Either accept a `regex:` prefix to force regex, otherwise treat as glob.
    - Or accept both and document precedence; in any case, it MUST be deterministic and tested.

### Output paths
- `--artifacts <dir>` (default: `tests/out/<run_id>/artifacts`)
- `--report-json <path>` (default: `tests/out/<run_id>/report.json`)
- `--report-junit <path>` (default: `tests/out/<run_id>/report.junit.xml`)
- Path requirements (MUST):
  - All paths are validated via `path_sandbox` and written via `artifact_store` atomically.
  - Report fields store **relative** paths under the run root.

### Baselines
- `--update-baselines` (accept missing/mismatched baselines by writing actual → staging)
- `--fail-on-missing-baseline` (default: `true`; ignored if `--update-baselines`)
- `--baseline-key <key>` (default: auto-detected from renderer/colorspace)
- `--baseline-write-mode <mode>` (default: `deny`; `deny|stage|apply`)
  - `deny`: never write to baselines (CI default)
  - `stage`: write updated baselines under `tests/baselines_staging/...` (local default when `--update-baselines`)
  - `apply`: write directly to `tests/baselines/...` (requires explicit opt-in)
- `--baseline-staging-dir <dir>` (default: `tests/baselines_staging`)
- `--baseline-approve-token <token>` (default: empty; if set, require matching env var `E2E_BASELINE_APPROVE=<token>` to write)
- Baseline key computation (SHOULD, for clarity):
  - Define canonical string format: `<backend>_<dynamic_range>_<colorspace>` (e.g. `vulkan_sdr_srgb`).
  - Record chosen `baseline_key` in `run_manifest.json` and `report.json.run.baseline_key`.

### Sharding + timeouts
- `--shard <n>` and `--total-shards <k>` (default: `1/1`; deterministic sharding)
- `--timeout-seconds <int>` (default: `600`; hard kill to avoid hung CI)
- `--default-test-timeout-frames <int>` (default: `1800`; per-test timeout measured in frames)
- `--failure-video <mode>` (default: `off`; `off|on`)
- `--failure-video-frames <n>` (default: `180`; number of frames to retain/encode on failure)
- Shard determinism (MUST):
  - Sharding is based on stable ordering of discovered tests (after filters/tags), then the stable predicate `(test_index % total_shards) == (shard-1)` (see §5 Phase 3).

### Retries + flake policy
- `--retry-failures <n>` (default: `0`; rerun failing tests up to N times)
- `--allow-flaky` (default: `false`; if false, flaky tests still fail CI)
- `--auto-audit-on-flake` (default: `false`; run determinism audit for tests that flake)
- `--flake-artifacts` (default: `true`; preserve failing-attempt artifacts even if later pass)

### Suite control / hygiene
- `--run-quarantined` (default: `false`; include tests tagged `quarantine`)
- `--fail-fast` (default: `false`; stop after first failure)
- `--max-failures <n>` (default: `0`; 0 means unlimited)
- `--shuffle-tests` (default: `false`; deterministic shuffle to detect order-dependence)
- `--shuffle-seed <u32>` (default: derived from `--seed`)
- `--test-manifest <path>` (default: `tests/test_manifest.json`)
  - Central policies + per-test overrides (timeouts, quarantine, retries, log allowlists, baseline ROI/masks defaults, perf budgets).

### RNG scope
- `--rng-scope <scope>` (default: `test`; `test|run`)
  - `test`: reseed deterministic RNG streams per test using `hash(seed, test_id)`
  - `run`: single global RNG seed for the whole run

### Renderer control
- `--renderer <mode>` (default: `offscreen`; `null|offscreen|windowed`)
  - `null`: logic-only; screenshot APIs unsupported (capabilities reflect this)
- Clarify interaction (SHOULD):
  - `--headless` SHOULD imply `--renderer=offscreen` unless explicitly overridden.
  - If `--renderer=null`, then `--headless` is allowed but screenshots MUST be reported as `capability_missing`.

### Determinism audit (tripwire)
- `--determinism-audit` (default: `false`)
- `--determinism-audit-runs <n>` (default: `2`)
- `--determinism-audit-scope <scope>` (default: `test_api`; `test_api|engine|render_hash`)
- `--determinism-violation <mode>` (default: `fatal`; `fatal|warn`)
  - includes `DET_NET` for network violations when `--allow-network=deny|localhost`.

### Log gating
- `--fail-on-log-level <level>` (default: empty; if set, fail if logs at/above level occur during a test)
- `--fail-on-log-category <glob>` (default: empty; optional filter)
- Testability detail (SHOULD):
  - Define log level ordering and normalization (e.g., `trace<debug<info<warn<error<fatal`).

### Input record/replay (optional, but significant productivity gain)
- `--record-input <path>` (default: empty; record effective input events to JSONL)
- `--replay-input <path>` (default: empty; replay a recorded input trace)

### Crash containment (optional hardening)
- `--isolate-tests <mode>` (default: `none`; `none|process-per-file|process-per-test`)
  - In CI, prefer `--isolate-tests=process-per-test` *via the supervisor* so a single crash only kills one test.

### Lua sandbox control
- `--lua-sandbox <mode>` (default: `on`; `on|off`; CI should force `on`)

### Performance (optional but recommended)
- `--perf-mode <mode>` (default: `off`; `off|collect|enforce`)
- `--perf-budget <path>` (default: empty; JSON budget file)
  - Example budgets: max frames for a test, max sim-ms, max asset-load-ms, max allocations, max peak memory.
- `--perf-trace <path>` (default: empty; writes Chrome Trace JSON for the run)

### Exit code contract
| Code | Meaning |
|------|---------|
| `0`  | All tests passed (and no gating policy violations) |
| `1`  | One or more tests failed (including gating policy violations) |
| `2`  | Harness/configuration error (bad flags, missing scripts, invalid paths, schema violation) |
| `3`  | Timeout/watchdog abort |
| `4`  | Crash (unhandled exception / fatal error) |

---

### Supervisor/Orchestrator (recommended for CI; useful locally too)
Evolve the launcher into a **suite orchestrator**:
- `./tools/e2e_supervisor run -- <game args...>`
- `./tools/e2e_supervisor list -- <game args...>`

Responsibilities (Orchestrator):
1. Discover tests in machine-readable form (`list`).
2. Compute deterministic sharding at the orchestrator layer.
3. Run tests with isolation:
   - `process-per-test` (default in CI) or `process-per-file`.
   - optional parallel workers per machine.
4. Enforce hard wall-clock timeouts externally (SIGKILL / TerminateProcess).
   - Before kill: attempt a bounded cooperative dump request (best-effort) to capture hang diagnostics.
5. On crash/timeout, ensure `tests/out/<run_id>/forensics/` exists:
   - if the game failed to write it, write a minimal manifest + stderr tail.
6. Collect OS crash artifacts (optional):
   - Linux: core dump path if configured
   - Windows: minidump (if enabled)
7. Merge child reports into one authoritative run report (JSON + JUnit).
8. Normalize exit codes to the same contract (0/1/2/3/4).
9. Testability requirement (SHOULD):
   - Each child process writes into a distinct `tests/out/<run_id>/` (or `tests/out/<run_id>/shard_<i>/test_<id>/`) so merging is deterministic and artifact paths do not collide.

CI should call the supervisor/orchestrator rather than invoking the game directly.

---

### Behavior rules
- `--test-mode` with neither `--test-script` nor `--test-suite` loads `assets/scripts/tests/framework/bootstrap.lua` and defaults to `--test-suite assets/scripts/tests/e2e`.
- Unknown/invalid flags print usage and exit `2`.
- All artifact/report paths are created if missing; path traversal outside approved roots is rejected.
  - Approved **write roots**: `tests/out/**`, `tests/baselines_staging/**` (and `tests/baselines/**` only with explicit apply token).
  - Approved **read roots**: `assets/**`, `tests/baselines/**`, `tests/baselines_staging/**`, `assets/scripts/tests/fixtures/**`.
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
- `test_harness.xfail(reason)` (expected fail; fail→XFAIL, pass→XPASS)
- Clarifications (testability):
  - `exit(code)` ends the run immediately after the current frame boundary; the runner writes reports/forensics before exiting where possible.
  - `skip/xfail` MUST be represented in `report.json.tests[].status` and in JUnit in a conventional way (skipped/expected failure).

### 3.1.1 Steps + attachments (debuggability)
- `test_harness.step(name, fn) -> returns fn result`
  - Emits structured step start/end events (with frame + timings) into `timeline.jsonl` and `report.json`.
- `test_harness.attach_text(name, text, opts?)`
- `test_harness.attach_file(name, path, opts?)`
  - `opts`: `{ mime="text/plain", max_bytes=1048576 }`
- Attachment/path safety (MUST):
  - `attach_file` MUST read only from approved **read roots** and write an artifact copy under the run root so reports never reference arbitrary filesystem paths.

### 3.2 Input injection (applied at frame boundaries)
- `press_key`, `release_key`, `tap_key`
- `move_mouse`, `mouse_down`, `mouse_up`, `click`
- `text_input(str)`
- `gamepad_button_down/up`, `gamepad_set_axis`
- Clarification (SHOULD):
  - All injected inputs are scheduled against explicit frames (current or future) and applied deterministically at the start of the frame (see §4).

**Input coordinate contract:**
- `move_mouse(x,y)` uses **render target pixel coordinates** under `--resolution` (0..W-1, 0..H-1).
- UI scaling must be applied via helper transforms (below) rather than implicit guessing.

### 3.2.1 Input state + transforms
- `test_harness.input_state() -> table`
  - snapshot of effective input state for the current frame (keys down, mouse pos/buttons, gamepad).
- `test_harness.screen_to_ui(x,y) -> ux, uy`
- `test_harness.ui_to_screen(ux,uy) -> x, y`
  - If the engine has no UI system, implement as `query("ui.transform", ...)` instead.

### 3.3 State query/set (via Test API Surface)
- `get_state(path) -> value|nil, err?`
- `set_state(path, value) -> true|nil, err?`
- Error contract (SHOULD, for clarity):
  - Errors are strings with stable prefixes (e.g., `capability_missing:<name>`, `invalid_path:<path>`, `type_error:<details>`).

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
      region = nil,              -- {x,y,w,h} OR { selector="ui:<name>" }
      masks = nil,               -- list of {x,y,w,h} OR { selector="ui:<name>" } areas to ignore
      ignore_alpha = true,
      stabilize_frames = 0       -- optional: require N identical frames before capture
    }
    ```
  - If `--update-baselines`, copy actual → baseline (staging or apply per `--baseline-write-mode`) and record baseline update in report.
  - If `<name>.meta.json` exists, merge as defaults (test overrides allowed).
  - If renderer is `null`, this must SKIP via capabilities.
  - Baseline naming clarity (SHOULD):
    - Baseline image path convention under `<test_id>/` SHOULD be `<name>.png` and meta file `<name>.meta.json`.
    - `name` MUST be stable within the test to avoid baseline churn.

### 3.5 Logs
- `log_mark() -> index`
- `find_log(substr_or_regex, opts?) -> found, index, line`
  - `opts`: `{ since=index, regex=false }`
- `clear_logs()`
- `assert_no_log_level(level, opts?) -> true|error`
  - Example: `assert_no_log_level("error", { since=mark })`

### 3.6 Runtime args and capability handshake
- `test_harness.args` table: `{ seed, fixed_fps, resolution, shard, total_shards, update_baselines, baseline_dir, artifacts_dir, report_json, report_junit }`
- `test_harness.capabilities` (read-only), e.g. `{ screenshots=true, headless=true, render_hash=false, gamepad=true, perf=true, perf_allocs=false, perf_memory=true }`
- `test_harness.test_api_version` string, e.g. `"1.0.0"`
- `test_harness.require(opts) -> true|error`
  - `opts`: `{ min_test_api_version="1.0.0", requires={"screenshots","gamepad"} }`
- Testability requirement (SHOULD):
  - Capabilities are also written into `run_manifest.json` and the JSON report so CI can interpret skips.

### 3.7 Determinism hashing (audit support)
- `test_harness.frame_hash(scope?) -> string`
  - `test_api` (default): hash of Test API Surface snapshot
  - `engine`: optional internal deterministic hash
  - `render_hash`: optional hash of backbuffer (canonical renderer only)
- Hashing clarity (SHOULD):
  - Use a stable algorithm (e.g., `sha256`) and a canonical serialization (stable key ordering, stable float formatting).

### 3.8 Performance hooks (optional)
- `test_harness.perf_mark() -> token`
- `test_harness.perf_since(token) -> table`
  - returns collected metrics since the token (frames, sim_ms, max_frame_ms, asset_load_ms, peak_rss_mb, alloc_count, ...)
- `test_harness.assert_perf(metric, op, value, opts?) -> true|error`
  - `opts`: `{ since=token, fail_message="..." }`

### 3.9 Script sandboxing (behavior)
- In `--test-mode`, Lua runs in a restricted environment:
  - `os.execute`, `io.popen` disabled
  - `os.time`, `os.clock` removed or deterministic stubs
  - `require` search path restricted to test framework + test suites
- Optional local-only escape hatch:
  - `--lua-sandbox=on|off` (default: `on`; CI should force `on`)

---

## 4) Execution Model (Deterministic + Blocking Waits)

- In `--test-mode`, engine loads `assets/scripts/tests/framework/bootstrap.lua`.
- `bootstrap.lua` creates a coroutine that runs discovery + `TestRunner.run()`.
- Each frame, engine:
  1. Applies queued test input events scheduled for this frame.
  2. Advances the game with fixed `dt = 1/fixed_fps`.
  3. Resumes test coroutine until it yields or completes.
- Clarification (MUST):
  - Ordering above is invariant and documented, since it defines determinism semantics for input timing and waits.

### Watchdogs
- Run-level watchdog: `--timeout-seconds`.
- Per-test watchdog: `--default-test-timeout-frames` (overrideable per test).
- External supervisor: OS-level hard timeout (cannot be bypassed by deadlocks).

### Forensics on crash/timeout/failure
- Write a forensics bundle (logs + timeline + last frames + input trace + manifest + repro scripts).
- Optionally zip for easy CI download.
- If game can't write forensics (hard crash), supervisor writes minimal salvage.

### Test isolation rules
Before each `it(...)`, runner performs deterministic cleanup:
1. Clear pending injected inputs + reset input down-state.
2. `log_mark()` to create a clean log window.
3. Isolation MUST be available:
   - Required: either `snapshot_restore` OR a proven `reset_to_known_state` that fully resets gameplay + UI.
   - If neither exists, tests that rely on isolation must be tagged `requires_isolation` and SKIP with a clear message.
   - For performance and reliability, snapshot restore is strongly recommended for most suites.
4. If `--rng-scope=test`, reseed RNG streams to `hash(run_seed, test_full_name)`.

Suite setup (recommended):
- At suite start: attempt `command("snapshot_create", { name="suite_start" })`.

#### Snapshot semantics (contract)
- `snapshot_create(name)`:
  - Captures enough state to replay deterministically from that point (scene graph, ECS state, RNG streams, scripted timers).
  - Must include any state visible to the Test API Surface.
- `snapshot_restore(name)`:
  - Restores the snapshot and guarantees the next frame begins from that exact state.
  - Must flush async jobs or deterministically reinitialize them.
- Errors:
  - On unsupported: return explicit error `capability_missing:snapshot`.
  - On corrupted/unavailable snapshot: return `snapshot_error:<reason>`.

### Determinism audit mode
If `--determinism-audit`:
- Each selected test is executed `--determinism-audit-runs` times.
- Runner records `frame_hash()` each frame (or configurable cadence).
- Any divergence fails with:
  - first divergent frame
  - hashes before/after
  - **Test API Surface snapshot diff** (bounded and summarized)
  - repro command + artifacts

### Flake handling
When retries are enabled and a test fails then passes:
- Mark it `flaky` in report.
- Preserve first-failure attempt artifacts if `--flake-artifacts=true`.
- If `--auto-audit-on-flake`, re-run that test in determinism-audit mode and attach divergence info if found.

---

## 5) Implementation Phases (with acceptance gates)

### Phase 0 — Recon + Interface Freeze (enables parallel work)
1. Locate integration points: CLI parsing, game loop timestep, input backend, renderer readback, logger sink, Lua registry.
2. Add stub headers/skeletons for all `src/testing/*` files and Lua framework files.
3. Document determinism contract; confirm engine can meet rules incl. FP/environment/filesystem/network notes.
4. Define and commit JSON schemas for `report.json` and `run_manifest.json`.
5. Define a schema for `test_api.json` (registry descriptor) and commit it.
**Gate:** repo compiles with stubs; contracts committed as docs/comments; schemas validated.
- Gate testability (SHOULD):
  - Add a minimal schema-validation step in test mode that exits `2` on invalid schema outputs (even if tests are stubbed).

### Phase 1 — Test Mode Core (C++)
1. `test_mode_config`: parse flags, validate, compute `<run_id>`, create output dirs.
2. `test_runtime`: owns all test subsystems + lifecycle.
3. `test_mode`: enable determinism (seed RNG, fixed timestep, disable vsync, optional audio off), set pinned FP/env.
4. Engine loop integration: load `bootstrap.lua`, run coroutine per frame, honor `exit(code)`, honor watchdogs.
5. Headless path: true offscreen preferred; fallback hidden window + CI `xvfb-run`.
6. `path_sandbox` + `artifact_store`: path safety + atomic writes.
7. `lua_sandbox`: restricted Lua environment with deterministic stubs.
8. `determinism_guard`: runtime tripwires for time/RNG/fs/async/network violations.
9. `test_api_registry`: typed registration for state paths, queries, commands.
**Gate:** `./game --test-mode --test-script <minimal.lua>` can wait frames, log, and exit(0).
- Gate testability (SHOULD):
  - The minimal script produces a schema-valid `report.json` (even if it contains 0 tests) and a `run_manifest.json`.
  - Exit code is `0` and deterministic across repeated invocations with the same flags.

### Phase 2 — Input Injection (C++)
1. `test_input_provider`: per-frame scheduled event queue.
2. Input system override in test mode (normal device input ignored or merged by policy; default ignore).
3. Bind input functions in `test_harness_lua` incl. text input + gamepad.
4. Record injected inputs to `input_trace.jsonl`.
5. Add `input_state()` and coordinate transform APIs.
6. Optional: record/replay integration via `--record-input` / `--replay-input`.
**Gate:** Lua script can press/hold/release keys, enter text, use gamepad, click reliably with frame-accurate timing.
- Gate testability (SHOULD):
  - Provide a deterministic input trace fixture that replays identically and asserts on input_state snapshots.

### Phase 3 — Lua Test Framework (Lua)
1. `test_runner.lua`: `describe/it`, hooks, deterministic ordering (or deterministic shuffle), per-test results, timeouts, frame budgets.
   - stable identity:
     - `it("does X", { id="menu.main_loads", tags={"ui","smoke"} }, function() ... end)`
     - `id` is optional but strongly recommended for screenshot/perf tests.
   - selection: include/exclude tags, filter
   - `--list-tests`
   - isolation before each test (require snapshot_restore or reset_to_known_state)
   - quarantine handling: `tags={"quarantine"}`
   - Load `--test-manifest` once; merge config:
     - global defaults → suite defaults → per-test overrides → inline opts → CLI overrides.
2. `discovery.lua`: load `--test-script` or enumerate `--test-suite` deterministically (sorted).
3. `assertions.lua` + `matchers.lua`: consistent errors with suite/test name + frame context.
4. Reporters: JSON + JUnit (TAP optional).
   - JSON authoritative includes environment, resolved roots, per-test durations, artifacts (structured), `failure_kind`.
   - retries: mark flaky and preserve first-failure attempt artifacts if `--flake-artifacts=true`.
   - if `--auto-audit-on-flake`, re-run that test in determinism-audit mode and attach divergence info if found.
   - statuses: `pass|fail|skipped|xfail|xpass|flaky|quarantined`
5. Sharding: `(test_index % total_shards) == (shard-1)` (stable enumeration required).
**Gate:** one example E2E test runs and produces `report.json` + correct exit code.
- Gate testability (SHOULD):
  - Add a tiny example test that deterministically passes and includes at least one `step()` and one attachment, verifying report fields.

### Phase 4 — Verification Systems (C++ + Lua wiring)
1. `lua_state_query`: robust traversal (dot + numeric + bracket) against Test API Surface.
2. `query` / `command` APIs stable + whitelisted via `test_api_registry`.
3. `screenshot_capture`: framebuffer readback to PNG (windowed + headless).
4. `screenshot_compare`: pixel diff + threshold + diff image; ROI + masks + stabilization.
   - Ensure comparisons are in a defined color space (explicit sRGB handling).
   - Support semantic selectors for ROI/masks (e.g., `{ selector="ui:InventoryPanel" }`).
5. `baseline_manager`: resolve baseline dir by platform/baseline_key/resolution/test_id; implement update-baselines with staging; merge `.meta.json`.
6. `log_capture`: ring buffer + structured JSONL logs; mark/find/clear.
7. `test_forensics`: bundles with seed/args/trace/last frames/repro scripts.
8. `artifact_index`: generate `index.html` linking per-test artifacts and repro commands.
9. `timeline_writer`: merged `timeline.jsonl` with inputs/logs/screenshots/hashes/steps/attachments.
10. Condition waits: `wait_until`, `wait_until_state`, `wait_until_log`.
11. `perf_tracker`: collect and optionally enforce performance budgets.
12. `test_api_dump`: generate `test_api.json` descriptor for validation/tooling.
**Gate:** `assert_state`, `assert_log_contains`, `assert_screenshot` work end-to-end and generate artifacts on failure; HTML gallery renders.
- Clarification (to resolve ambiguity):
  - `assert_state` and `assert_log_contains` are framework-level helpers (e.g., in `assertions.lua`) implemented on top of `get_state`/`wait_until_state` and `find_log`/`wait_until_log`.
- Gate testability (SHOULD):
  - Add a known-failing screenshot assertion run that produces: actual, baseline (if present), diff, and report entries with correct `failure_kind` (`baseline_missing` or `baseline_mismatch`).

### Phase 4.5 — Orchestrated Isolation
1. Build orchestrator mode into `tools/e2e_supervisor`:
   - `list` subcommand: enumerate tests in JSON
   - `run` subcommand: execute with `process-per-test` or `process-per-file` isolation
   - parallel workers support
2. Implement report merging from child processes.
3. Add hang diagnostics: cooperative dump request before hard kill.
4. Verify per-test forensics on crash/timeout.
**Gate:** CI runs via orchestrator in `process-per-test` mode, merges reports, and produces per-test forensics on crash/timeout.
- Gate testability (SHOULD):
  - Induce a controlled crash in a single test process and verify only that test is marked `crash` and the suite continues.

### Phase 5 — Example Tests + Test Hooks (Game Lua/C++)
1. Add minimal test-visible state hooks (test mode only):
   - Test API Surface (small, versioned):
     - properties: `game.initialized`, `game.current_scene`, `game.paused`
     - queries: `ui.element_rect(name)`, `ui.element_visible(name)`, `ui.element_center(name)`
     - commands: `scene.load(name)`, `combat.spawn_enemy(...)`, etc.
   - expose `test_api_version` and capabilities.
2. Implement 3 tests:
   - menu nav + screenshot baseline
   - combat deterministic setup + log/state asserts
   - UI pause/inventory + state + screenshot asserts
3. Create baselines for canonical CI runner (single platform/resolution/backend).
4. Create initial test fixtures in `assets/scripts/tests/fixtures/`.
**Gate:** 3 tests pass locally and headless; reruns stable.

### Phase 6 — CI (GitHub Actions) + Supervisor + Parallelism
1. Workflow `.github/workflows/e2e-tests.yml`:
   - build + cache
   - run headless tests via supervisor/orchestrator
   - upload `tests/out/**` artifacts (always)
   - publish JUnit
2. Matrix sharding (4 shards default), `fail-fast: false`.
3. Job summary (required):
   - failing test names
   - seed + resolution + shard info
   - copy/paste repro command
   - artifact relative paths for diffs/logs
   - link to `index.html` gallery
4. Canonical screenshot strategy:
   - run screenshot assertions only on canonical runner/backend (Linux + fixed renderer/software).
   - run logic-only elsewhere (no screenshot asserts).
5. Build and integrate `tools/e2e_supervisor`:
   - OS-level timeout enforcement
   - crash artifact salvage
   - core dump / minidump collection (optional)
**Gate:** CI reliable on PRs; failures show names + downloadable diffs + repro + HTML gallery.

---

## 6) Parallel Execution Plan (3–5 agents)

### Shared prerequisite (all agents)
- Phase 0 interface freeze: flags, `test_harness` contract, output paths, report schema, determinism contract (incl FP/env/fs/network), JSON schemas.

### Agent A — Engine/Test Mode Core
- Phase 1: CLI parsing, determinism pins (FP/env/network), coroutine-per-frame runner, exit/watchdogs, args to Lua.
- Also: `test_runtime`, `path_sandbox`, `artifact_store`, `lua_sandbox`, `determinism_guard`, `test_api_registry`.

### Agent B — Input + Harness Bindings
- Phase 2: input event queue + input override + `test_harness` input APIs + constants.
- Also: text input, gamepad, input trace, record/replay hooks, `input_state()`, coordinate transforms.

### Agent C — Headless + Screenshot Capture
- Headless path + framebuffer readback + PNG writing + path safety.
- Also: ROI/masks/stabilization + `.meta.json` loading + baseline_key support + baseline staging.
- Also: semantic UI selectors for ROI/masks.

### Agent D — Lua Framework + Example Tests
- Phase 3 + Phase 5: runner/discovery/assertions/actions/reporters + initial tests.
- Also: tags/filtering, retries/flaky marking, skip/xfail/quarantine, per-test timeouts, shuffle mode.
- Also: stable test IDs, test manifest loading, step/attachment APIs.

### Agent E (optional) — Verification + CI + Hardening
- Phase 4 + Phase 4.5 + Phase 6: state query, screenshot diff, baseline manager, log capture, GitHub Actions, summary script, supervisor/orchestrator.
- Also: determinism audit + `--isolate-tests` launcher strategy + HTML gallery + timeline.jsonl + perf hooks.
- Also: hang diagnostics, determinism diff, Chrome Trace export, failure video.

---

## 7) Milestones (Definition of Done)

1. **M0 (Contracts frozen):** flags + `test_harness` API + paths + report schema agreed and stubbed; determinism contract documented (incl FP/env/fs/network); JSON schemas committed and validated.
2. **M1 (First runnable test):** `--test-mode --test-script minimal.lua` waits frames + exits deterministically.
3. **M2 (MVP E2E):** one real test drives input + asserts state + produces JSON report; isolation mechanism proven (`reset_to_known_state` or snapshot restore).
4. **M3 (Visual verification):** screenshot capture + baseline compare + diff artifacts + update-baselines with staging; ROI/masks work; baseline_key works; snapshot restore used for suite isolation on at least one suite.
5. **M4 (CI green):** GitHub Actions runs headless via supervisor, publishes results, uploads artifacts; job summary actionable (repro command, seed, diff paths, HTML gallery link).
6. **M4.5 (Orchestrated isolation):** CI runs via orchestrator in `process-per-test` mode, merges reports, and produces per-test forensics on crash/timeout.
7. **M5 (Coverage):** 3 stable example tests + docs for adding tests/updating baselines; forensics bundle on failures; timeline.jsonl written.
8. **M6 (Hardening):** determinism audit tripwire + per-test timeouts + skip/xfail/quarantine fully wired; optional isolate-tests mode; Lua sandbox enforced; flake triage automation.
9. **M7 (Polish):** perf budgets optional; seeded shuffle mode; full HTML gallery with all artifact types; Chrome Trace export; optional failure video.

---

## Appendix A: Test API Surface Design Principles

The Test API Surface is a deliberately narrow interface exported by the game for test automation. It is a contract between tests and game code.

### Design principles
1. **Stability:** versioned + documented like a public API.
2. **Minimalism:** expose only what tests need.
3. **Determinism:** queries/commands produce same results given same state.
4. **Whitelisting:** unknown paths/names fail explicitly via `test_api_registry`.

### Typed Registry (`test_api_registry`)
- Explicit registration for state paths (read/write), queries, commands, capabilities, versioning.
- Machine-readable description at runtime (`test_api.json`).
- CI validation ensures registry matches expectations.
- Enables auto-generation of documentation, autocomplete stubs, and static checks.
- Backwards compatibility enforcement via semantic versioning rules at registration time.

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
| `run_manifest.json` | CLI args, seed, platform, renderer, resolution, git SHA, fingerprints, ordering hash, test_api_fingerprint |
| `input_trace.jsonl` | All injected inputs with frame numbers |
| `logs.jsonl` | Structured logs `{ frame, level, category, message }` |
| `timeline.jsonl` | Merged events `{ frame, type, ... }` to correlate everything (incl. steps/attachments) |
| `last_logs.txt` | Tail of log buffer (e.g. last 500 lines) |
| `final_frame.png` | Screenshot at crash/timeout (if available) |
| `last_frames/` | Optional ring buffer of last N frames captured only on failure |
| `failure_clip.webm` | Optional: encoded clip of last N frames on failure (if enabled) |
| `hang_dump.json` | Optional: watchdog-triggered hang diagnostics (thread states, last known frame, watchdog reason) |
| `determinism_diff.json` | Optional: divergence diff of Test API Surface snapshots (bounded) |
| `trace.json` | Optional: Chrome Trace JSON (Perfetto-compatible) for perf/stall debugging |
| `test_api.json` | Test API registry descriptor |
| `repro.sh` | Copy/paste repro script |
| `repro.ps1` | PowerShell repro script |
| `forensics.zip` | Optional zipped bundle |

### `run_manifest.json` example
```json
{
  "schema_version": "1.0.0",
  "args": ["--test-mode", "--headless", "--seed", "12345", "--test-suite", "e2e"],
  "seed": 12345,
  "platform": "linux",
  "engine_version": "1.2.3",
  "content_fingerprint": "sha256:abc123...",
  "renderer": "vulkan",
  "renderer_fingerprint": "vulkan_mesa_24.1_intel_srgb",
  "baseline_key": "software_sdr_srgb",
  "resolution": "1280x720",
  "git_sha": "abc123",
  "build_id": "ci-12345",
  "determinism_pins": {
    "ftz_daz": true,
    "rounding": "nearest",
    "locale": "C",
    "timezone": "UTC",
    "thread_mode": "single"
  },
  "test_api_fingerprint": "sha256:def456...",
  "test_ordering_hash": "sha256:...",
  "shard": 1,
  "total_shards": 4,
  "timeout_seconds": 600,
  "timestamp": "2026-02-02T12:00:00Z"
}
```

---

## Appendix C: Screenshot Comparison Strategy

### Recommended CI approach

1. **Canonical runner:** All screenshot assertions run on a single CI runner with a fixed render stack (e.g., Linux + Mesa software renderer or a specific GPU driver version).

2. **Non-canonical runners:** Run the same tests but skip screenshot assertions (or run them with very loose thresholds + no failure).

3. **ROI/mask usage:** For UI tests, compare only the region of interest (e.g., the dialog box, not the full screen). Mask dynamic elements (timers, particle effects). Use semantic selectors when available (e.g., `{ selector="ui:DialogBox" }`).

4. **Stabilization:** For animated content, use `stabilize_frames=5` to wait until the frame is stable before capturing.

5. **Per-baseline metadata:** Store thresholds and masks in `<baseline>.meta.json` rather than hardcoding in tests. This allows adjusting tolerances without changing test code.

6. **Baseline updates:** Use the staging workflow (`--baseline-write-mode=stage`) to review baseline changes before committing. Non-canonical machines cannot poison baselines.

---

## Appendix D: Report Schema

The authoritative schema lives at `tests/schemas/report.schema.json`. Key fields:

```json
{
  "schema_version": "1.1.0",
  "run": {
    "run_id": "...",
    "seed": 12345,
    "platform": "linux",
    "engine_version": "1.2.3",
    "content_fingerprint": "sha256:...",
    "renderer_fingerprint": "...",
    "resolution": "1280x720",
    "baseline_key": "software_sdr_srgb"
  },
  "tests": [
    {
      "name": "menu_test::loads main menu",
      "id": "menu.main_loads",
      "status": "pass|fail|skipped|xfail|xpass|flaky|quarantined",
      "failure_kind": "assertion|timeout|crash|...|null",
      "attempts": 1,
      "artifacts": [
        { "kind": "screenshot", "path": "artifacts/menu_test/screenshot.png", "attempt": 1, "step": null },
        { "kind": "diff", "path": "artifacts/menu_test/screenshot_diff.png", "attempt": 1, "step": null }
      ],
      "steps": [
        { "name": "navigate to menu", "start_frame": 0, "end_frame": 30, "status": "pass" },
        { "name": "verify layout", "start_frame": 31, "end_frame": 60, "status": "pass" }
      ],
      "timings_frames": 120,
      "timings_ms": 2000
    }
  ],
  "summary": {
    "passed": 10,
    "failed": 1,
    "skipped": 2,
    "flaky": 0
  }
}
```

### Failure taxonomy (`failure_kind`)
| Kind | Description |
|------|-------------|
| `assertion` | Test assertion failed |
| `timeout` | Test exceeded frame/time budget |
| `crash` | Unhandled exception or fatal error |
| `harness_error` | Test framework/configuration error |
| `determinism_divergence` | Determinism audit detected divergence |
| `log_gating` | Forbidden log level/category emitted |
| `baseline_missing` | Expected baseline not found |
| `baseline_mismatch` | Screenshot differs from baseline |
| `capability_missing` | Required capability not available |
| `perf_budget_exceeded` | Performance budget violation |
| `unknown` | Unclassified failure |

---

## Appendix E: CI Linting (Determinism)

Add a CI job that greps **and** clang-tidy checks determinism-critical modules for banned APIs:
- `std::random_device`, `system_clock::now`, `time()`, `rand()`, directory iteration without sort, etc.

Example `.github/workflows/lint-determinism.yml`:
```yaml
name: Determinism Lint
on: [pull_request]
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Check for banned APIs
        run: |
          ! grep -rn --include='*.cpp' --include='*.hpp' \
            -e 'std::random_device' \
            -e 'system_clock::now' \
            -e '\btime(' \
            -e '\brand(' \
            src/game/ src/engine/ || exit 1
      - name: clang-tidy determinism profile (optional but recommended)
        run: |
          # Run clang-tidy on determinism-critical targets with a dedicated config.
          # Start as non-blocking; promote to blocking once stable.
          ./tools/run_clang_tidy_determinism.sh || true
```

---

## Appendix F: Test Metadata Manifest

The test manifest (`tests/test_manifest.json`) provides centralized policy and per-test overrides without editing test code.

### Structure
```json
{
  "schema_version": "1.0.0",
  "defaults": {
    "timeout_frames": 1800,
    "retry_count": 0,
    "allowed_log_levels": ["info", "warn"],
    "perf_budgets": {}
  },
  "suites": {
    "e2e/menu_test.lua": {
      "timeout_frames": 3600
    }
  },
  "tests": {
    "menu.main_loads": {
      "timeout_frames": 900,
      "quarantine": false,
      "retry_count": 2,
      "baseline_masks": [
        { "selector": "ui:ClockLabel" }
      ],
      "perf_budgets": {
        "max_frames": 300
      }
    }
  }
}
```

### Override resolution order
1. Global defaults (from manifest `defaults`)
2. Suite defaults (from manifest `suites`)
3. Per-test overrides (from manifest `tests`)
4. Inline opts (in `it()` call)
5. CLI overrides

---

## Appendix G: Changelog from v3

### Major Additions (v4)
1. **Orchestrator upgrade (Change 1):** Supervisor evolved into full orchestrator with `run`/`list` subcommands, process-per-test isolation, parallel workers, report merging.
2. **Stable test IDs (Change 2):** Optional `id` field in `it()` for stable identity across renames; baselines keyed by test_id.
3. **Test metadata manifest (Change 3):** Centralized `tests/test_manifest.json` for timeouts, quarantine, retries, log allowlists, baseline ROI/masks defaults, perf budgets.
4. **Step annotations + attachments (Change 4):** `test_harness.step()`, `attach_text()`, `attach_file()` for structured debuggability.
5. **Typed Test API registry (Change 5):** `test_api_registry.{hpp,cpp}`, `test_api_dump.{hpp,cpp}`, `test_api.json` schema, `test_api_fingerprint` in manifest.
6. **Network sandbox (Change 6):** `--allow-network` flag (default: `deny`), `DET_NET` tripwire code.
7. **Hang diagnostics (Change 7):** Pre-kill cooperative dump request, `hang_dump.json` artifact.
8. **Determinism state diff (Change 8):** `determinism_diff.json` with Test API Surface snapshot diff on divergence.
9. **Chrome Trace export (Change 9):** `--perf-trace` flag, `trace.json` artifact.
10. **Failure video capture (Change 10):** `--failure-video` flag, `failure_clip.webm` artifact.
11. **Semantic ROI/masks (Change 11):** Support for `{ selector="ui:<name>" }` in screenshot assertions.
12. **Structured artifacts (Change 12):** Artifacts array contains objects with `kind`, `path`, `attempt`, `step`, `description`.
13. **Exact single-test mode (Change 13):** `--run-test-id` and `--run-test-exact` flags.
14. **Tightened path safety (Change 14):** Explicit read roots vs write roots.
15. **clang-tidy determinism profile (Change 15):** Added to CI linting alongside grep.

### Structural Changes
1. New Phase 4.5 (Orchestrated isolation) inserted between Phase 4 and Phase 5.
2. New Milestone M4.5 for orchestrated isolation.
3. Appendix F added for Test Metadata Manifest.
4. Appendix G added for changelog from v3.
5. Report schema version bumped to 1.1.0 for structured artifacts.
6. Forensics bundle expanded with new artifact types.
```