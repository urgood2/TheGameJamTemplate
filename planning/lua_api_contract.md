# Test Harness Lua API Contract

The `test_harness` global table is exposed only in `--test-mode`. This contract defines the stable interface between tests and the engine.

## 1) Frame/Time Control

- `test_harness.wait_frames(n)`
  - Validates `n >= 0`.
  - Yields until `n` frames have advanced.
- `test_harness.now_frame() -> integer`
- `test_harness.wait_until(predicate_fn, opts?) -> true|error`
  - Polls `predicate_fn()` once per frame until it returns truthy.
  - `opts`: `{ timeout_frames=300, fail_message="...", poll_every_frames=1 }`
- `test_harness.wait_until_state(path, expected, opts?) -> true|error`
- `test_harness.wait_until_log(substr_or_regex, opts?) -> true|error`
- `test_harness.exit(code)`
  - Ends the run immediately after the current frame boundary.
- `test_harness.skip(reason)`
  - Marks the current test skipped.
- `test_harness.xfail(reason)`
  - Expected failure: fail -> XFAIL, pass -> XPASS.

`skip` and `xfail` must be represented in `report.json.tests[].status` and JUnit output.

## 2) Steps and Attachments

- `test_harness.step(name, fn) -> any`
  - Emits structured step start/end events (frame + timing) into `timeline.jsonl` and `report.json`.
- `test_harness.attach_text(name, text, opts?)`
- `test_harness.attach_file(name, path, opts?)`
  - `opts`: `{ mime="text/plain", max_bytes=1048576 }`

Attachment safety:
- `attach_file` must read only from approved read roots.
- Attachments must be copied under the run root so reports never reference arbitrary paths.

## 3) Input Injection

Inputs are applied at frame boundaries.

- `press_key(key)`
- `release_key(key)`
- `tap_key(key)`
- `move_mouse(x, y)`
- `mouse_down(button)`
- `mouse_up(button)`
- `click(x, y, button)`
- `text_input(str)`
- `gamepad_button_down(btn)`
- `gamepad_button_up(btn)`
- `gamepad_set_axis(axis, val)`

Input coordinate contract:
- `move_mouse(x, y)` uses render target pixel coordinates under `--resolution` (0..W-1, 0..H-1).
- UI scaling must be applied via transform helpers, not implicit guessing.

## 4) Input State and Transforms

- `test_harness.input_state() -> table`
  - Snapshot of effective input state for the current frame.
- `test_harness.screen_to_ui(x, y) -> ux, uy`
- `test_harness.ui_to_screen(ux, uy) -> x, y`

If there is no UI system, these may delegate to `query("ui.transform", ...)`.

## 5) State Query and Commands

- `test_harness.get_state(path) -> value|nil, err?`
- `test_harness.set_state(path, value) -> true|nil, err?`
- `test_harness.query(name, args?) -> value|nil, err?`
- `test_harness.command(name, args?) -> true|nil, err?`

Error contract (stable string prefixes):
- `capability_missing:<name>`
- `invalid_path:<path>`
- `type_error:<details>`

## 6) Screenshots and Comparisons

- `test_harness.screenshot(path) -> true|nil, err?`
- `test_harness.assert_screenshot(name, opts?) -> true|error`
  - `opts`:
    ```lua
    {
      threshold_percent = 0.1,
      per_channel_tolerance = 2,
      generate_diff = true,
      region = nil,              -- {x,y,w,h} OR { selector="ui:<name>" }
      masks = nil,               -- list of {x,y,w,h} OR { selector="ui:<name>" }
      ignore_alpha = true,
      stabilize_frames = 0
    }
    ```

Behavior rules:
- If `--update-baselines` is set, copy actual to baseline (staging or apply per `--baseline-write-mode`).
- If `<name>.meta.json` exists, merge as defaults (test overrides allowed).
- If renderer is `null`, this must SKIP via capabilities.
- Baseline naming: `<test_id>/<name>.png`, optional `<name>.meta.json`.

## 7) Logs

- `test_harness.log_mark() -> index`
- `test_harness.find_log(substr_or_regex, opts?) -> found, index, line`
  - `opts`: `{ since=index, regex=false }`
- `test_harness.clear_logs()`
- `test_harness.assert_no_log_level(level, opts?) -> true|error`
  - Example: `assert_no_log_level("error", { since=mark })`

## 8) Runtime Args and Capabilities

- `test_harness.args` table
  - `{ seed, fixed_fps, resolution, shard, total_shards, update_baselines, baseline_dir, artifacts_dir, report_json, report_junit }`
- `test_harness.capabilities` (read-only)
  - Example: `{ screenshots=true, headless=true, render_hash=false, gamepad=true, perf=true, perf_allocs=false, perf_memory=true }`
- `test_harness.test_api_version` string (e.g. `"1.0.0"`)
- `test_harness.require(opts) -> true|error`
  - `opts`: `{ min_test_api_version="1.0.0", requires={"screenshots","gamepad"} }`

Capabilities must be written into `run_manifest.json` and the JSON report for CI to interpret skips.

## 9) Determinism Hashing

- `test_harness.frame_hash(scope?) -> string`
  - `test_api` (default)
  - `engine`
  - `render_hash`

Hashes must use a stable algorithm (e.g., SHA-256) and canonical serialization (stable key ordering, stable float formatting).

## 10) Performance Hooks

- `test_harness.perf_mark() -> token`
- `test_harness.perf_since(token) -> table`
- `test_harness.assert_perf(metric, op, value, opts?) -> true|error`
  - `opts`: `{ since=token, fail_message="..." }`

## 11) Script Sandboxing

In `--test-mode`, Lua runs in a restricted environment:
- `os.execute` and `io.popen` disabled.
- `os.time` and `os.clock` removed or deterministic stubs.
- `require` search path restricted to test framework + test suites.

Sandbox control:
- `--lua-sandbox=on|off` (default `on`; CI should force `on`).
