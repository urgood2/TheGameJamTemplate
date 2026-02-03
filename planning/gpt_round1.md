
# Revisions to “Master Plan: End-to-End (E2E) Game Testing System”

This document contains my proposed revisions to the plan to make it **more robust/reliable**, **less flaky**, **more maintainable**, and **more useful in CI**. For each change: rationale + a **git-diff style patch** against the original plan text you provided.

---

## Change 1 — Make determinism a first-class contract (and enforce it)

### Rationale
Determinism exists in your plan, but it’s *implicit*. In real-world E2E, flakes usually come from:
- wall-clock time leaking into gameplay
- async job completion order
- unstable iteration order (unordered containers)
- multithread scheduling
- GPU/render backend differences impacting screenshots

Codifying a determinism contract early prevents months of “random CI failures”.

### Git diff
```diff
diff --git a/MASTER_PLAN.md b/MASTER_PLAN.md
--- a/MASTER_PLAN.md
+++ b/MASTER_PLAN.md
@@ -1,16 +1,45 @@
 # Master Plan: End-to-End (E2E) Game Testing System

 ## 0) Outcomes & Non‑Goals
 - **Outcomes**
   - Run tests via `./game --test-mode [--headless] [--test-script <file> | --test-suite <dir>]`.
   - Tests can **drive input**, **wait deterministically by frames**, **query/set state**, **assert logs**, and **assert screenshots** (baseline + diff artifacts).
   - CI runs headless, uploads artifacts, and reports results (JUnit/JSON).
+
+## 0.1 Determinism Contract (Test Mode)
+In `--test-mode`, the engine must behave as a deterministic simulator given:
+- the same binary + content, the same `--seed`, the same resolution, and the same test script(s).
+
+Rules (enforced where feasible):
+- Wall-clock time must not affect simulation (no `now()` driving gameplay). Simulation time == frame count / fixed dt.
+- Randomness must be routed through seeded RNG(s) (no unseeded RNG, no random_device).
+- Update ordering must be stable (no unordered container iteration affecting gameplay).
+- Asynchronous jobs must be deterministic (either disabled, forced single-thread, or completion order made stable).
+- Asset streaming/loading must have a deterministic completion point for tests (explicit “ready” signals).
+
+Rendering caveat:
+- Pixel-perfect screenshot baselines are only guaranteed on a controlled render stack (same backend/driver/software renderer).
+- If the render stack varies, use masking/ROI or run screenshot tests on a canonical CI renderer.

 - **Non‑Goals (v1)**
   - Web/Emscripten support, perceptual diff/ML diffing, full UI automation framework, multiplayer/network determinism.
+  - Cross-GPU pixel-perfect equivalence (unless running a canonical software renderer / fixed backend in CI).
```

---

## Change 2 — Add a `TestRuntime` core + central path/artifact sandboxing

### Rationale
Without a unifying runtime object, test subsystems tend to become a tangle of global-ish state:
- CLI parsing sets globals
- input queue is separate
- screenshots separate
- logs separate
- baselines separate

A single `TestRuntime` (owned by the engine in test mode) improves:
- lifecycle clarity
- reset/isolation between tests (reduces cascading failures)
- future extensibility (trace/forensics, replay, etc.)

Centralizing file safety in `path_sandbox` + `artifact_store` prevents a slow drip of duplicated security checks.

### Git diff
```diff
diff --git a/MASTER_PLAN.md b/MASTER_PLAN.md
--- a/MASTER_PLAN.md
+++ b/MASTER_PLAN.md
@@ -19,17 +19,23 @@
 ### 1.1 C++ (engine)
 - `src/testing/`
   - `test_mode_config.{hpp,cpp}`
-  - `test_mode.{hpp,cpp}`
+  - `test_runtime.{hpp,cpp}`              # owns all test subsystems + lifecycle
+  - `test_mode.{hpp,cpp}`                 # thin integration layer into engine loop
   - `test_input_provider.{hpp,cpp}`
-  - `test_harness_lua.{hpp,cpp}`
+  - `test_harness_lua.{hpp,cpp}`          # Lua bindings; delegates to TestRuntime
   - `lua_state_query.{hpp,cpp}`
   - `screenshot_capture.{hpp,cpp}`
   - `screenshot_compare.{hpp,cpp}`
   - `log_capture.{hpp,cpp}`
   - `baseline_manager.{hpp,cpp}`
+  - `artifact_store.{hpp,cpp}`            # atomic writes, relative paths, manifest
+  - `path_sandbox.{hpp,cpp}`              # canonicalize + restrict output roots
+  - `test_forensics.{hpp,cpp}`            # crash/timeout bundles: logs + last frames

@@ -86,7 +92,9 @@
 - All artifact/report paths are created if missing; path traversal outside repo/output roots is rejected.
+  - Enforcement is centralized in `path_sandbox` + `artifact_store` (no ad-hoc checks).
```

---

## Change 3 — Add deterministic “wait until condition” APIs

### Rationale
If tests lean on `wait_frames(n)` as the only sync primitive, you’ll get:
- slow tests (big waits “just in case”)
- flakes (sometimes the condition takes longer)
- brittleness across machine speed differences

Condition waits with *frame-based* timeouts keep determinism and reduce flake rate.

### Git diff
```diff
diff --git a/MASTER_PLAN.md b/MASTER_PLAN.md
--- a/MASTER_PLAN.md
+++ b/MASTER_PLAN.md
@@ -95,12 +95,35 @@
 ## 3) `test_harness` Lua API Contract (Stable Interface)
 Expose a global table `test_harness` **only in test mode**.

 ### 3.1 Frame/time control (coroutine-friendly)
 - `test_harness.wait_frames(n)`  
   - Validates `n >= 0`; **yields** the test coroutine until `n` frames have advanced.
 - `test_harness.now_frame() -> integer`
+- `test_harness.wait_until(predicate_fn, opts?) -> true|error`
+  - Polls `predicate_fn()` once per frame until it returns truthy.
+  - `opts`: `{ timeout_frames=300, fail_message="...", poll_every_frames=1 }`
+  - Deterministic: timeout measured in frames, not wall-clock.
+- `test_harness.wait_until_state(path, expected, opts?) -> true|error`
+  - Equivalent to `wait_until(function() return get_state(path) == expected end, ...)`
+- `test_harness.wait_until_log(substr_or_regex, opts?) -> true|error`
+  - Waits until a matching log line appears (supports `since=mark`).
 - `test_harness.exit(code)`  
   - Requests engine shutdown with process exit code.
```

---

## Change 4 — Make state access stable via a “Test API Surface” + explicit query/command APIs

### Rationale
A generic `get_state("a.b.c")` becomes a maintenance trap if it reaches into internal engine object graphs. Internal refactors then break tests constantly.

Instead:
- expose a small “Test API Surface” (property bag + whitelisted queries/commands)
- keep it stable/versioned like a public API
- let `get_state/set_state` operate on *that* surface, not random internal objects

### Git diff
```diff
diff --git a/MASTER_PLAN.md b/MASTER_PLAN.md
--- a/MASTER_PLAN.md
+++ b/MASTER_PLAN.md
@@ -119,10 +119,30 @@
 ### 3.3 State query/set
 - `test_harness.get_state(path) -> value|nil, err?`  
-  - Path supports: `a.b.c`, numeric segments (`enemies.1.health`), and optional bracket form (`inventory[1].name`).
+  - Reads from the **Test API Surface** (a stable property bag exported by the game in test mode),
+    not arbitrary internal engine objects.
+  - Path supports: `a.b.c`, numeric segments (`enemies.1.health`), and optional bracket form (`inventory[1].name`).
 - `test_harness.set_state(path, value) -> true|nil, err?`
+  - Writes to the Test API Surface only (or invokes explicit test commands).
+
+### 3.3.1 Explicit queries/commands (preferred over raw path access)
+- `test_harness.query(name, args?) -> value|nil, err?`
+  - Examples: `query("current_scene")`, `query("ui_element_rect", { name="inventory_button" })`
+- `test_harness.command(name, args?) -> true|nil, err?`
+  - Examples: `command("load_scene", { name="combat_arena" })`,
+              `command("spawn_enemy", { archetype="slime", x=10, y=5 })`
+  - Commands are deterministic and can be validated/whitelisted.

@@ -213,11 +233,14 @@
 ### Phase 5 — Example Tests + Test Hooks (Game Lua/C++)
 1. Add minimal “test-visible” state hooks (only in test mode) to expose stable signals:
-   - `game.initialized`, `game.current_scene`, `game.paused`, `ui.elements.<name> = {x,y,w,h}`, etc.
+   - Export a **Test API Surface**:
+     - Properties: `game.initialized`, `game.current_scene`, `game.paused`
+     - Queries: `ui.element_rect(name)`, `ui.element_visible(name)`
+     - Commands: `scene.load(name)`, `combat.spawn_enemy(...)`, etc.
+   - Keep this surface small and versioned; treat it like a public API.
```

---

## Change 5 — Upgrade screenshot testing: ROI/masks + canonical renderer strategy + baseline metadata

### Rationale
Pixel diffs are the #1 source of flakiness. Practical features you’ll want immediately:
- ROI compare (only compare the panel under test)
- masks (ignore known nondeterministic regions)
- optional stabilization (capture after N stable frames)
- baseline metadata (`.meta.json`) so tests stay clean
- canonical CI renderer for visual assertions

### Git diff
```diff
diff --git a/MASTER_PLAN.md b/MASTER_PLAN.md
--- a/MASTER_PLAN.md
+++ b/MASTER_PLAN.md
@@ -55,10 +55,16 @@
 ### 1.3 Baselines & outputs
 - Baselines (versioned): `tests/baselines/<platform>/<WxH>/...png`
   - `<platform>`: `linux|windows|mac|unknown`
   - `<WxH>`: `1280x720` etc.
+  - Optional per-baseline metadata (versioned):
+    - `.../<name>.meta.json` (thresholds, ROI, masks, notes)
 - Outputs (ignored by git): `tests/out/<run_id>/`
   - `report.json`
   - `report.junit.xml`
   - `artifacts/` (screenshots, diffs, logs, per-test debug)
@@ -130,11 +136,22 @@
 ### 3.4 Screenshots & comparisons
 - `test_harness.screenshot(path) -> true|nil, err?`
 - `test_harness.assert_screenshot(name, opts?) -> true|error`
   - `name`: logical name like `main_menu_idle.png`
-  - `opts`: `{ threshold_percent=0.1, per_channel_tolerance=2, generate_diff=true }`
+  - `opts`: {
+      threshold_percent=0.1,
+      per_channel_tolerance=2,
+      generate_diff=true,
+      region=nil,                 -- {x,y,w,h} compare ROI only
+      masks=nil,                  -- list of {x,y,w,h} areas to ignore
+      ignore_alpha=true,
+      stabilize_frames=0          -- optional: require N identical frames before capture
+    }
   - Writes: actual + diff into artifacts; reads baseline from platform/resolution baseline dir.
   - If `--update-baselines`, copies actual → baseline and records “updated baseline” in report.
+  - If `<name>.meta.json` exists, it merges into `opts` as defaults (test can override).

@@ -248,6 +265,13 @@
 ### Phase 6 — CI (GitHub Actions) + Parallelism
@@
 3. Optional PR summary from JSON report (job summary or PR comment).
+4. Canonical screenshot strategy:
+   - Run screenshot assertions only on a single canonical CI runner/backend (e.g. Linux + fixed renderer/software).
+   - Run logic-only tests on other platforms if desired (no screenshot asserts).
```

---

## Change 6 — Add a forensics bundle (seed + trace + tail logs) for reproducible CI failures

### Rationale
If CI fails and you can’t reproduce, the suite loses credibility fast. A small forensics bundle solves this:
- seed, exact args, discovered ordering hash
- input trace (frame-indexed injected inputs)
- last logs tail
- final screenshot (best-effort)

### Git diff
```diff
diff --git a/MASTER_PLAN.md b/MASTER_PLAN.md
--- a/MASTER_PLAN.md
+++ b/MASTER_PLAN.md
@@ -69,6 +69,11 @@
 - Outputs (ignored by git): `tests/out/<run_id>/`
   - `report.json`
   - `report.junit.xml`
   - `artifacts/` (screenshots, diffs, logs, per-test debug)
+  - `forensics/`
+    - `run_manifest.json`   (args, seed, platform, renderer, git sha)
+    - `input_trace.jsonl`   (frame-indexed injected inputs)
+    - `last_logs.txt`       (tail of log buffer)

@@ -170,6 +175,14 @@
 ## 4) Execution Model (Deterministic + Blocking Waits)
@@
 - A hard watchdog (`--timeout-seconds`) aborts with a clear report if the test run never exits.
+  - On timeout/crash, write a **forensics bundle**:
+    - final screenshot (if possible) + last N log lines + input trace tail
+    - the exact CLI args and resolved paths
+    - shard info + discovered test ordering
```

---

## Change 7 — Define exit codes + make JSON report authoritative and richer

### Rationale
Clear exit codes make CI and local scripting cleaner:
- failures vs harness error vs timeout vs crash are different problems

Also: JUnit is useful but lossy. JSON should be the authoritative artifact containing all useful details, with JUnit as an adapter.

### Git diff
```diff
diff --git a/MASTER_PLAN.md b/MASTER_PLAN.md
--- a/MASTER_PLAN.md
+++ b/MASTER_PLAN.md
@@ -74,6 +74,20 @@
 ## 2) CLI Contract (Single Source of Truth)
 Implement these flags (all optional unless noted):
@@
 - `--timeout-seconds <int>` (default: `600`; hard kill to avoid hung CI)
+
+Exit code contract:
+- `0` = all tests passed
+- `1` = one or more tests failed
+- `2` = harness/configuration error (bad flags, missing scripts, invalid paths)
+- `3` = timeout/watchdog abort
+- `4` = crash (unhandled exception / fatal error)

@@ -199,6 +213,16 @@
 ### Phase 3 — Lua Test Framework (Lua)
@@
 4. Reporters: JSON + JUnit (TAP optional).
+   - JSON is authoritative and includes:
+     - environment (platform, cpu, renderer/backend, resolution)
+     - resolved baseline/artifact roots
+     - per-test: duration_frames, duration_ms (optional), artifacts list, failure kind
+     - run-level: seed, shard info, discovered ordering hash
 5. Sharding: run only tests where `(test_index % total_shards) == (shard-1)` (stable enumeration required).
```

---

## Change 8 — Add listing/filtering/tags/quarantine controls for suite scalability

### Rationale
As soon as you have a non-trivial suite, you’ll need:
- run one test / group
- run only “smoke”
- exclude “visual”
- quarantine known flakes without deleting them
- list tests for shard debugging

### Git diff
```diff
diff --git a/MASTER_PLAN.md b/MASTER_PLAN.md
--- a/MASTER_PLAN.md
+++ b/MASTER_PLAN.md
@@ -74,6 +74,10 @@
 ## 2) CLI Contract (Single Source of Truth)
 Implement these flags (all optional unless noted):
@@
 - `--test-suite <dir>` (discover and run all tests under directory)
+- `--list-tests` (discover tests, print stable full names, exit 0)
+- `--test-filter <glob_or_regex>` (run matching tests only)
+- `--exclude-tag <tag>` / `--include-tag <tag>` (tag-based selection)
@@
 - `--shard <n>` and `--total-shards <k>` (default: `1/1`; deterministic sharding)
 - `--timeout-seconds <int>` (default: `600`; hard kill to avoid hung CI)

@@ -191,10 +195,16 @@
 ### Phase 3 — Lua Test Framework (Lua)
 1. `test_runner.lua`: `describe/it`, hooks, deterministic ordering, per-test results, per-test frame budgets.
+   - Support tags: `it("does X", { tags={"ui","smoke"} }, function() ... end)`
+   - Implement `--include-tag/--exclude-tag` and `--test-filter`.
+   - Implement `--list-tests` for debugging and shard verification.
 2. `discovery.lua`: load `--test-script` or enumerate `--test-suite` deterministically (via engine-provided `list_files` if needed).
```

---

## Change 9 — Add retry-on-failure with explicit flaky labeling

### Rationale
Retries are a pragmatic pressure valve during the early life of an E2E suite. The key is **honesty**:
- rerun failures once
- if it passes on retry, mark as `flaky`
- by default still fail CI unless explicitly allowed

### Git diff
```diff
diff --git a/MASTER_PLAN.md b/MASTER_PLAN.md
--- a/MASTER_PLAN.md
+++ b/MASTER_PLAN.md
@@ -74,6 +74,9 @@
 Implement these flags (all optional unless noted):
@@
 - `--timeout-seconds <int>` (default: `600`; hard kill to avoid hung CI)
+- `--retry-failures <n>` (default: `0`; rerun failing tests up to N times)
+- `--allow-flaky` (default: `false`; if false, flaky == CI failure)

@@ -199,6 +202,12 @@
 ### Phase 3 — Lua Test Framework (Lua)
@@
 4. Reporters: JSON + JUnit (TAP optional).
+   - If retries are enabled:
+     - Mark tests that fail then pass as `status="flaky"`
+     - Include attempt logs and artifacts per attempt (or at least for the failing attempt)
+     - If `--allow-flaky=false`, exit non-zero even if all ended passing after retries
```

---

## Change 10 — Expand input injection to cover text and gamepad

### Rationale
Keyboard/mouse is good, but E2E often needs:
- text entry (name fields, search)
- controller navigation
- analog axes

If you don’t support these, you’ll end up with fragile `set_state` hacks.

### Git diff
```diff
diff --git a/MASTER_PLAN.md b/MASTER_PLAN.md
--- a/MASTER_PLAN.md
+++ b/MASTER_PLAN.md
@@ -103,6 +103,13 @@
 ### 3.2 Input injection (applied at frame boundaries)
 - `test_harness.press_key(keycode)`
 - `test_harness.release_key(keycode)`
 - `test_harness.tap_key(keycode, frames_down=2)` (helper)
 - `test_harness.move_mouse(x, y)`
 - `test_harness.mouse_down(button)`
 - `test_harness.mouse_up(button)`
 - `test_harness.click(x, y, button=1, frames_down=1)` (helper)
+ - `test_harness.text_input(str)`  -- inject text as OS/input-layer events (not set_state hacks)
+ - `test_harness.gamepad_button_down(pad, button)`
+ - `test_harness.gamepad_button_up(pad, button)`
+ - `test_harness.gamepad_set_axis(pad, axis, value)` -- value in [-1,1]
```

---

## Change 11 — Make test isolation/reset rules explicit

### Rationale
E2E suites often fail because tests contaminate each other:
- stuck inputs
- leftover entities
- logs containing previous test noise
- scene not fully reset

Define a deterministic “between tests” cleanup step to reduce cascade failures.

### Git diff
```diff
diff --git a/MASTER_PLAN.md b/MASTER_PLAN.md
--- a/MASTER_PLAN.md
+++ b/MASTER_PLAN.md
@@ -167,6 +167,12 @@
 ## 4) Execution Model (Deterministic + Blocking Waits)
@@
 - A hard watchdog (`--timeout-seconds`) aborts with a clear report if the test run never exits.
+ 
+Test isolation rules:
+- Before each `it(...)`, the runner performs a deterministic cleanup step:
+  - clear pending injected inputs + reset input down-state
+  - log_mark() to create a clean log window for assertions
+  - optional: call a game-defined `command("reset_to_known_state")` hook
```

---

## Change 12 — CI summaries should be actionable by default + keep visual tests canonical

### Rationale
“Artifacts uploaded” is not enough. People need:
- failing test names
- seed
- shard info
- copy/paste repro command
- artifact paths for diffs/logs

Also: run screenshot asserts on a canonical runner/backend, not across a random OS/GPU matrix.

### Git diff
```diff
diff --git a/MASTER_PLAN.md b/MASTER_PLAN.md
--- a/MASTER_PLAN.md
+++ b/MASTER_PLAN.md
@@ -246,13 +246,22 @@
 ### Phase 6 — CI (GitHub Actions) + Parallelism
 1. Workflow `.github/workflows/e2e-tests.yml`:
    - Build (cache dependencies/build if feasible)
    - Run `./build/game --test-mode --headless --test-suite ... --report-* ... --artifacts ...`
    - Upload `tests/out/**` artifacts (always), highlight diffs on failure
    - Publish JUnit results
 2. Matrix sharding (4 shards default), `fail-fast: false`, per-shard artifacts.
-3. Optional PR summary from JSON report (job summary or PR comment).
+3. Job summary (recommended, not optional):
+   - Parse JSON report and print:
+     - failing test full names
+     - seed + resolution + shard info
+     - “repro command” line (copy/paste)
+     - artifact relative paths for diff images / logs
+4. Keep screenshot tests canonical:
+   - run visual assertions only on a single CI runner/backend
+   - optionally run non-visual smoke tests on other platforms
```

---

# Blunt, practical guidance (based on how these systems fail)

- **Cross-GPU pixel-perfect screenshots are a trap.** Constrain the render stack in CI or use ROI/masks + looser thresholds.
- **Condition waits are mandatory** if you want stable + fast tests. `wait_frames` alone leads to either flakes or slow suites.
- **State APIs must be a stable surface** or your tests become a refactor tax.
- **Forensics bundles** save enormous time. They turn “can’t repro” into “repro instantly”.

