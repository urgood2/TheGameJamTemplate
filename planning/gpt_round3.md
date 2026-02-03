
# Revisions to “Master Plan: End-to-End (E2E) Game Testing System — v2”
**Goal:** make the plan *more deterministic, more diagnosable, safer to operate in CI, and easier for humans to use* without turning it into a giant UI automation product.

Below are targeted change proposals. Each includes:
- **Rationale / tradeoffs**
- **A focused git-diff** against the *original plan text* (assumed stored as `docs/e2e_testing_master_plan_v2.md`)

---

## Quick diagnosis (what’s already strong vs. what’s missing)

### Already strong
- Determinism contract is explicit and pragmatic (includes FP/env/fs/GPU sync).
- Output layout + forensics bundle is a solid foundation for debugging.
- Capabilities handshake + `null` renderer mode is the right flexibility.
- Sharding + retries + quarantine are the right CI hygiene primitives.

### Key gaps to close
1. **There’s no “single source of truth” schema for `report.json` and `run_manifest.json`.** This will rot quickly across refactors and CI tooling.
2. **Baseline updates are too easy to do accidentally** (or to do differently on different machines).
3. **Timeouts/crashes are handled in-process only.** If the game deadlocks inside the watchdog mechanism or hard-hangs the render thread, you want an *external* supervisor.
4. **No performance regression hooks** (frame time, memory/allocs, load time). E2E tests are where perf regressions hide.
5. **Flake handling is policy-only, not diagnostic.** If you retry, you should auto-collect “why” signals.
6. **Lua test scripts are powerful enough to accidentally cause nondeterminism** (filesystem access, `os.time`, etc.).
7. **Order-dependence is common**; you want an optional “seeded shuffle” mode to detect hidden coupling.

---

# Proposed Changes

## 1) Versioned schemas for reports + stable failure taxonomy (prevents tooling rot)

### What
- Add **versioned, documented schemas** for `report.json` and `run_manifest.json`.
- Add a stable **failure taxonomy** (`failure_kind`) so CI and dashboards can classify failures reliably.
- Add `engine_version` and `content_hash` (or “build/content fingerprint”) to the manifest so “same binary + content” is actually verifiable.

### Why this makes it better
- **Robustness:** your CI parsing won’t silently break when fields move.
- **Reliability:** you can compare runs across machines and know whether they were *actually comparable*.
- **Usefulness:** consistent classification enables trend tracking (flake rate, crash rate, perf regression rate).

### Tradeoffs
- Slight upfront work to define schemas, but it saves *months* of future glue-code churn.

### Diff
```diff
diff --git a/docs/e2e_testing_master_plan_v2.md b/docs/e2e_testing_master_plan_v2.md
--- a/docs/e2e_testing_master_plan_v2.md
+++ b/docs/e2e_testing_master_plan_v2.md
@@
 ## 0) Outcomes & Non-Goals
@@
 ### Non-Goals (v1)
@@
 - Cross-GPU pixel-perfect equivalence (unless running a canonical software renderer / fixed backend in CI).
+
+---
+
+## 0.2 Report + Manifest Contracts (Versioned)
+
+### Goals
+- Make `report.json` and `run_manifest.json` machine-validated and forwards-compatible.
+- Stabilize failure classification so CI tooling can key off it reliably.
+
+### Additions
+- `report.json` includes:
+  - `schema_version` (semver)
+  - `failure_kind` (stable enum: `assertion|timeout|crash|harness_error|determinism_divergence|log_gating|baseline_missing|baseline_mismatch|capability_missing|unknown`)
+  - `engine_version` + `content_fingerprint` (hashes)
+  - per-test: `status`, `attempts`, `artifacts`, `timings_frames`, `timings_ms` (optional)
+- `run_manifest.json` includes:
+  - `schema_version`
+  - `engine_version`, `git_sha`, `build_id`
+  - `content_fingerprint` (hash of content pak / asset manifest)
+  - `renderer_fingerprint` (backend + device + driver + colorspace)
+  - `determinism_pins` (FTZ/DAZ, rounding, locale, TZ, thread mode, etc.)
+
+### Schemas (checked-in)
+- `tests/schemas/report.schema.json`
+- `tests/schemas/run_manifest.schema.json`
+The harness validates outputs against these schemas in `--test-mode` and exits `2` on schema violation.
```

```diff
diff --git a/tests/schemas/report.schema.json b/tests/schemas/report.schema.json
new file mode 100644
--- /dev/null
+++ b/tests/schemas/report.schema.json
@@
+{
+  "$schema": "https://json-schema.org/draft/2020-12/schema",
+  "title": "E2E test report",
+  "type": "object",
+  "required": ["schema_version", "run", "tests", "summary"],
+  "properties": {
+    "schema_version": { "type": "string" },
+    "run": {
+      "type": "object",
+      "required": ["run_id", "seed", "platform", "resolution", "baseline_key"],
+      "properties": {
+        "run_id": { "type": "string" },
+        "seed": { "type": "integer" },
+        "platform": { "type": "string" },
+        "engine_version": { "type": "string" },
+        "content_fingerprint": { "type": "string" },
+        "renderer_fingerprint": { "type": "string" },
+        "resolution": { "type": "string" },
+        "baseline_key": { "type": "string" }
+      },
+      "additionalProperties": true
+    },
+    "tests": {
+      "type": "array",
+      "items": {
+        "type": "object",
+        "required": ["name", "status"],
+        "properties": {
+          "name": { "type": "string" },
+          "status": { "type": "string" },
+          "failure_kind": { "type": "string" },
+          "attempts": { "type": "integer" },
+          "artifacts": { "type": "array", "items": { "type": "string" } }
+        },
+        "additionalProperties": true
+      }
+    },
+    "summary": {
+      "type": "object",
+      "required": ["passed", "failed", "skipped"],
+      "properties": {
+        "passed": { "type": "integer" },
+        "failed": { "type": "integer" },
+        "skipped": { "type": "integer" }
+      },
+      "additionalProperties": true
+    }
+  },
+  "additionalProperties": true
+}
```

---

## 2) Add an external supervisor/launcher (hardens timeouts + crash capture)

### What
Introduce a small **`e2e_supervisor` launcher** that can:
- start the game in `--test-mode`
- enforce *OS-level* timeouts (cannot be bypassed by in-process deadlocks)
- capture exit status, stderr, and (optionally) core dumps/minidumps
- support process-per-test isolation efficiently (especially on Linux via forkserver-like patterns)

Keep `./game --test-mode ...` working for local iteration, but **CI should call the supervisor**.

### Why this makes it better
- **Reliability:** in-process watchdogs fail exactly when you need them most (deadlocks, GPU hangs).
- **Better crash forensics:** you can guarantee bundle collection even if the game can’t.
- **CI survivability:** fewer “hung job until GitHub kills it”.

### Tradeoffs
- Adds a small tool and some wiring. Worth it.

### Diff
```diff
diff --git a/docs/e2e_testing_master_plan_v2.md b/docs/e2e_testing_master_plan_v2.md
--- a/docs/e2e_testing_master_plan_v2.md
+++ b/docs/e2e_testing_master_plan_v2.md
@@
 ## 2) CLI Contract (Single Source of Truth)
@@
 ### Exit code contract
@@
 | `4`  | Crash (unhandled exception / fatal error) |
+
+---
+
+### Supervisor (recommended for CI)
+Add a thin launcher tool:
+- `./tools/e2e_supervisor -- <game args...>`
+Responsibilities:
+1. Spawn game process with the requested flags.
+2. Enforce hard wall-clock timeouts externally (SIGKILL / TerminateProcess).
+3. On crash/timeout, ensure `tests/out/<run_id>/forensics/` exists:
+   - if the game failed to write it, the supervisor writes a minimal manifest + tail of stderr.
+4. Optionally collect OS crash artifacts:
+   - Linux: core dump path if configured
+   - Windows: minidump (if enabled)
+5. Normalize exit codes to the same contract (0/1/2/3/4).
+
+CI should call the supervisor rather than invoking the game directly.
@@
 ### Crash containment (optional hardening)
 - `--isolate-tests <mode>` (default: `none`; `none|process-per-file|process-per-test`)
+  - In CI, prefer `--isolate-tests=process-per-test` *via the supervisor* so a single crash only kills one test.
```

```diff
diff --git a/docs/e2e_testing_master_plan_v2.md b/docs/e2e_testing_master_plan_v2.md
--- a/docs/e2e_testing_master_plan_v2.md
+++ b/docs/e2e_testing_master_plan_v2.md
@@
 ### 1.1 C++ (engine)
 - `src/testing/`
@@
   - `determinism_audit.{hpp,cpp}`      — optional: repeat runs + divergence detection
+
+### 1.1.1 Tools (host-side)
+- `tools/e2e_supervisor/`
+  - `main.cpp` (spawn + timeout + crash/timeout salvage)
+  - `process_utils.*` (portable process management)
+  - `artifact_salvage.*` (write minimal forensics if game can’t)
```

---

## 3) Make snapshot/restore a *first-class* requirement (test isolation becomes real)

### What
Right now snapshotting is “preferred if supported”. For a serious E2E suite, **it should be a milestone gate**:
- Define `snapshot_create`, `snapshot_restore`, and `reset_to_known_state` semantics clearly.
- Require at least one reliable isolation mechanism by M2/M3 (or mark tests that require it).

### Why this makes it better
- **Stability:** most E2E flakes are state leakage between tests.
- **Performance:** snapshot restore is faster than reloading content per test.
- **Determinism:** resets are a determinism boundary.

### Tradeoffs
- Implementing a snapshot system can be real work. But you can start with “coarse snapshot” (scene + entity state) and refine.

### Diff
```diff
diff --git a/docs/e2e_testing_master_plan_v2.md b/docs/e2e_testing_master_plan_v2.md
--- a/docs/e2e_testing_master_plan_v2.md
+++ b/docs/e2e_testing_master_plan_v2.md
@@
 ### Test isolation rules
 Before each `it(...)`, runner performs deterministic cleanup:
@@
-3. Prefer snapshot restore if supported:
-   - If `command("snapshot_restore", { name="suite_start" })` succeeds, use it.
-   - Else call `command("reset_to_known_state")`.
+3. Isolation MUST be available:
+   - Required: either `snapshot_restore` OR a proven `reset_to_known_state` that fully resets gameplay + UI.
+   - If neither exists, tests that rely on isolation must be tagged `requires_isolation` and SKIP with a clear message.
+   - For performance and reliability, snapshot restore is strongly recommended for most suites.
@@
 Suite setup (recommended):
 - At suite start: attempt `command("snapshot_create", { name="suite_start" })`.
+
+#### Snapshot semantics (contract)
+- `snapshot_create(name)`:
+  - Captures enough state to replay deterministically from that point (scene graph, ECS state, RNG streams, scripted timers).
+  - Must include any state visible to the Test API Surface.
+- `snapshot_restore(name)`:
+  - Restores the snapshot and guarantees the next frame begins from that exact state.
+  - Must flush async jobs or deterministically reinitialize them.
+- Errors:
+  - On unsupported: return explicit error `capability_missing:snapshot`.
+  - On corrupted/unavailable snapshot: return `snapshot_error:<reason>`.
```

```diff
diff --git a/docs/e2e_testing_master_plan_v2.md b/docs/e2e_testing_master_plan_v2.md
--- a/docs/e2e_testing_master_plan_v2.md
+++ b/docs/e2e_testing_master_plan_v2.md
@@
 ## 7) Milestones (Definition of Done)
@@
-3. **M2 (MVP E2E):** one real test drives input + asserts state + produces JSON report.
+3. **M2 (MVP E2E):** one real test drives input + asserts state + produces JSON report; isolation mechanism proven (`reset_to_known_state` or snapshot restore).
@@
-4. **M3 (Visual verification):** screenshot capture + baseline compare + diff artifacts + update-baselines; ROI/masks work; baseline_key works.
+4. **M3 (Visual verification):** screenshot capture + baseline compare + diff artifacts + update-baselines; ROI/masks work; baseline_key works; snapshot restore used for suite isolation on at least one suite.
```

---

## 4) Determinism enforcement: runtime “tripwires” + static checks (find problems early)

### What
Add a `determinism_guard` layer that:
- In `--test-mode`, **hard-errors** on banned nondeterministic calls (time, RNG, filesystem order) in gameplay paths.
- Optionally logs stack traces for violations.
- Add a lightweight **static check** (clang-tidy / ripgrep CI) to catch calls like `std::random_device`, `system_clock::now`, and unordered iteration in determinism-critical modules.

### Why this makes it better
- **Reliability:** determinism bugs are expensive when discovered via flaky tests.
- **Performance:** finding the offender early prevents wasted CI.
- **Developer UX:** violations become actionable (“here’s the stack”).

### Tradeoffs
- Some false positives at first; you’ll need a small allowlist for legitimate uses (e.g., logging timestamps that don’t affect sim).

### Diff
```diff
diff --git a/docs/e2e_testing_master_plan_v2.md b/docs/e2e_testing_master_plan_v2.md
--- a/docs/e2e_testing_master_plan_v2.md
+++ b/docs/e2e_testing_master_plan_v2.md
@@
 ## 0.1 Determinism Contract (Test Mode)
@@
 ### Diagnostics stance
-- In `--test-mode`, determinism violations should produce an explicit warning/error category (easy to grep in CI).
+- In `--test-mode`, determinism violations should produce an explicit warning/error category (easy to grep in CI).
+- Additionally, the engine should provide determinism “tripwires”:
+  - fail-fast option: `--determinism-violation=fatal|warn` (default: `fatal` in CI, `warn` locally)
+  - each violation includes a stable code (`DET_TIME`, `DET_RNG`, `DET_FS_ORDER`, `DET_ASYNC_ORDER`, ...)
+  - optional stack trace when available
@@
 ### 1.1 C++ (engine)
 - `src/testing/`
@@
   - `determinism_audit.{hpp,cpp}`      — optional: repeat runs + divergence detection
+  - `determinism_guard.{hpp,cpp}`      — runtime tripwires (time/RNG/fs/async checks)
+
+### CI linting (recommended)
+- Add a CI job that greps or clang-tidy checks determinism-critical modules for banned APIs:
+  - `std::random_device`, `system_clock::now`, `time()`, `rand()`, directory iteration without sort, etc.
```

---

## 5) Baseline updates: make them safe + reviewable (avoid “oops I updated baselines”)

### What
Change baseline updating to be **explicitly opt-in and reviewable**:
- `--update-baselines` writes to a **staging directory** by default (`tests/baselines_staging/...`)
- A separate tool (or explicit flag) applies staged baselines into `tests/baselines/...`
- Add `--baseline-write-mode <mode>`: `deny|stage|apply` (default `deny` in CI)
- Add `--baseline-approve-token` environment gate to prevent accidental writes in CI.

### Why this makes it better
- **Robustness:** prevents accidental baseline churn and noisy diffs.
- **Process:** reviewers can inspect staged diffs (gallery) before committing.
- **Reliability:** avoids “local machine updated baseline with different renderer fingerprint”.

### Tradeoffs
- Slightly more steps when intentionally updating baselines (but that’s exactly when you want friction).

### Diff
```diff
diff --git a/docs/e2e_testing_master_plan_v2.md b/docs/e2e_testing_master_plan_v2.md
--- a/docs/e2e_testing_master_plan_v2.md
+++ b/docs/e2e_testing_master_plan_v2.md
@@
 ### Baselines
-- `--update-baselines` (accept missing/mismatched baselines by copying actual → baseline)
+- `--update-baselines` (accept missing/mismatched baselines by writing actual → staging)
 - `--fail-on-missing-baseline` (default: `true`; ignored if `--update-baselines`)
 - `--baseline-key <key>` (default: auto-detected from renderer/colorspace)
+  - `--baseline-write-mode <mode>` (default: `deny`; `deny|stage|apply`)
+    - `deny`: never write to baselines (CI default)
+    - `stage`: write updated baselines under `tests/baselines_staging/...` (local default when `--update-baselines`)
+    - `apply`: write directly to `tests/baselines/...` (requires explicit opt-in)
+  - `--baseline-staging-dir <dir>` (default: `tests/baselines_staging`)
+  - `--baseline-approve-token <token>` (default: empty; if set, require matching env var `E2E_BASELINE_APPROVE=<token>` to write)
@@
 #### Baselines (versioned)
 - `tests/baselines/<platform>/<baseline_key>/<WxH>/...png`
+  - Baseline updates should be created on canonical render stacks only.
+  - Non-canonical machines should default to staging updates to avoid poisoning baselines.
```

---

## 6) Generate an HTML “diff gallery” index (makes failures instantly actionable)

### What
On every run, generate `tests/out/<run_id>/index.html` that links:
- failing tests
- expected/actual/diff images
- log tail
- repro commands
- download link to `forensics.zip`

### Why this makes it better
- **Compelling/useful:** humans debug faster with a one-click artifact page.
- **CI friendliness:** GitHub artifacts are painful to browse as raw folders.
- **No new infra required:** just a static html file in artifacts.

### Tradeoffs
- Small implementation time, big UX win.

### Diff
```diff
diff --git a/docs/e2e_testing_master_plan_v2.md b/docs/e2e_testing_master_plan_v2.md
--- a/docs/e2e_testing_master_plan_v2.md
+++ b/docs/e2e_testing_master_plan_v2.md
@@
 #### Outputs (ignored by git)
 - `tests/out/<run_id>/`
   - `report.json`
   - `report.junit.xml`
+  - `index.html`              — static run summary + artifact links (diff gallery)
   - `artifacts/` (screenshots, diffs, logs, per-test debug)
@@
 ### Phase 4 — Verification Systems (C++ + Lua wiring)
@@
 7. `test_forensics`: bundles with seed/args/trace/last frames/repro scripts.
+8. `artifact_index`: generate `index.html` linking per-test artifacts and repro commands.
-8. Condition waits: `wait_until`, `wait_until_state`, `wait_until_log`.
+9. Condition waits: `wait_until`, `wait_until_state`, `wait_until_log`.
```

---

## 7) Optional seeded test order shuffle (find order-dependence without losing reproducibility)

### What
Add:
- `--shuffle-tests` (boolean)
- `--shuffle-seed <u32>` (default: derived from run seed)

Ordering stays deterministic and reproducible; it’s just a *different* deterministic order.

### Why this makes it better
- **Robustness:** exposes hidden coupling between tests.
- **More compelling:** confidence increases when tests are order-independent.
- **No downside by default:** keep stable order unless explicitly enabled.

### Tradeoffs
- When enabled, failures may look “new” because the order changed — but that’s the point.

### Diff
```diff
diff --git a/docs/e2e_testing_master_plan_v2.md b/docs/e2e_testing_master_plan_v2.md
--- a/docs/e2e_testing_master_plan_v2.md
+++ b/docs/e2e_testing_master_plan_v2.md
@@
 ### Suite control / hygiene
@@
 - `--max-failures <n>` (default: `0`; 0 means unlimited)
+  - `--shuffle-tests` (default: `false`; deterministic shuffle to detect order-dependence)
+  - `--shuffle-seed <u32>` (default: derived from `--seed`)
@@
 ### Phase 3 — Lua Test Framework (Lua)
@@
-1. `test_runner.lua`: `describe/it`, hooks, deterministic ordering, per-test results, timeouts, frame budgets.
+1. `test_runner.lua`: `describe/it`, hooks, deterministic ordering (or deterministic shuffle), per-test results, timeouts, frame budgets.
```

---

## 8) Perf budgets + regression signals (E2E is the best place to catch perf cliffs)

### What
Add optional perf tracking that is cheap enough for CI:
- per-test: total frames, total sim ms, max frame ms (in test mode), asset load ms, peak RSS, allocation counts (if instrumented)
- CLI: `--perf-budget <path.json>` and `--perf-mode off|collect|enforce`
- Lua API: `test_harness.perf_mark()` and `test_harness.assert_perf(metric, op, value)`

### Why this makes it better
- **Performance:** catches “menu test now loads 2GB of assets” immediately.
- **Reliability:** perf regressions often correlate with timeouts/flakes.
- **Compelling:** E2E suite becomes a “quality gate” not just correctness.

### Tradeoffs
- You need to decide which metrics are stable enough across machines. Prefer CPU-time in test mode and frame counts; use generous budgets where needed.

### Diff
```diff
diff --git a/docs/e2e_testing_master_plan_v2.md b/docs/e2e_testing_master_plan_v2.md
--- a/docs/e2e_testing_master_plan_v2.md
+++ b/docs/e2e_testing_master_plan_v2.md
@@
 ## 2) CLI Contract (Single Source of Truth)
@@
 ### Sharding + timeouts
@@
 - `--default-test-timeout-frames <int>` (default: `1800`; per-test timeout measured in frames)
+
+### Performance (optional but recommended)
+- `--perf-mode <mode>` (default: `off`; `off|collect|enforce`)
+- `--perf-budget <path>` (default: empty; JSON budget file)
+  - Example budgets: max frames for a test, max sim-ms, max asset-load-ms, max allocations, max peak memory.
@@
 ## 3) `test_harness` Lua API Contract (Stable Interface)
@@
 ### 3.6 Runtime args and capability handshake
@@
 - `test_harness.capabilities` (read-only), e.g. `{ screenshots=true, headless=true, render_hash=false, gamepad=true }`
+  - Add perf capability flags and metric availability:
+    - `{ perf=true, perf_allocs=false, perf_memory=true }`
@@
+### 3.8 Performance hooks (optional)
+- `test_harness.perf_mark() -> token`
+- `test_harness.perf_since(token) -> table`
+  - returns collected metrics since the token (frames, sim_ms, max_frame_ms, asset_load_ms, peak_rss_mb, alloc_count, ...)
+- `test_harness.assert_perf(metric, op, value, opts?) -> true|error`
+  - `opts`: `{ since=token, fail_message="..." }`
```

---

## 9) Flake triage automation (don’t just retry; learn why it flaked)

### What
When retries are enabled and a test fails then passes:
- mark it `flaky`
- automatically collect extra signals on the failing attempt:
  - frame_hash trace around divergence window
  - additional screenshot and log tail
  - input trace (already)
- optionally auto-run determinism audit on that test: `--auto-audit-on-flake`

### Why this makes it better
- **Reliability:** flakes don’t hide; they come with diagnosis breadcrumbs.
- **Developer time:** fewer “can’t repro” dead ends.
- **CI cost control:** audit only when needed.

### Tradeoffs
- Slight extra runtime on flake occurrences (rare, and worth it).

### Diff
```diff
diff --git a/docs/e2e_testing_master_plan_v2.md b/docs/e2e_testing_master_plan_v2.md
--- a/docs/e2e_testing_master_plan_v2.md
+++ b/docs/e2e_testing_master_plan_v2.md
@@
 ### Retries + flake policy
 - `--retry-failures <n>` (default: `0`; rerun failing tests up to N times)
 - `--allow-flaky` (default: `false`; if false, flaky tests still fail CI)
+  - `--auto-audit-on-flake` (default: `false`; run determinism audit for tests that flake)
+  - `--flake-artifacts` (default: `true`; preserve failing-attempt artifacts even if later pass)
@@
 ### Phase 3 — Lua Test Framework (Lua)
@@
 4. Reporters: JSON + JUnit (TAP optional).
@@
-   - retries: mark flaky; if `--allow-flaky=false`, still fail CI even if passing after retries.
+   - retries: mark flaky and preserve first-failure attempt artifacts if `--flake-artifacts=true`.
+   - if `--auto-audit-on-flake`, re-run that test in determinism-audit mode and attach divergence info if found.
```

---

## 10) Unified timeline event log (better forensics with less guessing)

### What
Add a single `timeline.jsonl` that merges:
- frame index
- injected input events
- key logs (optional)
- screenshot captures and comparison results
- frame_hash at a chosen cadence

This becomes the “one file to read first”.

### Why this makes it better
- **Forensics:** you can reconstruct what happened without correlating 4 different files manually.
- **Tooling:** easy to build viewers later.
- **Performance:** JSONL is streamable and append-only.

### Tradeoffs
- Slight duplication of data, but you can link to existing files as entries.

### Diff
```diff
diff --git a/docs/e2e_testing_master_plan_v2.md b/docs/e2e_testing_master_plan_v2.md
--- a/docs/e2e_testing_master_plan_v2.md
+++ b/docs/e2e_testing_master_plan_v2.md
@@
 #### Outputs (ignored by git)
@@
   - `forensics/`
     - `run_manifest.json`   — args, seed, platform, renderer, git sha
     - `input_trace.jsonl`   — frame-indexed injected inputs
     - `logs.jsonl`          — structured logs (frame, level, category, message)
+    - `timeline.jsonl`      — merged frame timeline (inputs/logs/screenshot events/hashes)
     - `last_logs.txt`       — tail of log buffer
@@
 ## Appendix B: Forensics Bundle Specification
@@
 | `input_trace.jsonl` | All injected inputs with frame numbers |
 | `logs.jsonl` | Structured logs `{ frame, level, category, message }` |
+| `timeline.jsonl` | Merged events `{ frame, type, ... }` to correlate everything |
```

---

## 11) Lua sandboxing + deterministic standard library (stop tests from creating nondeterminism)

### What
In test mode, load Lua scripts with a **restricted environment**:
- disable `os.execute`, `io.popen`, arbitrary file writes
- replace `os.time`, `os.clock` with deterministic stubs (or remove them)
- restrict `require` paths to `assets/scripts/tests/**` and optionally readonly fixture dirs

### Why this makes it better
- **Determinism:** prevents accidental wall-clock or filesystem side-effects.
- **Security:** stops tests from doing “oops, delete files” locally or in CI.
- **Consistency:** the harness provides deterministic APIs; scripts should use those.

### Tradeoffs
- Some developers will want “power-user” access; you can add an opt-out flag for local runs only.

### Diff
```diff
diff --git a/docs/e2e_testing_master_plan_v2.md b/docs/e2e_testing_master_plan_v2.md
--- a/docs/e2e_testing_master_plan_v2.md
+++ b/docs/e2e_testing_master_plan_v2.md
@@
 ### 1.1 C++ (engine)
 - `src/testing/`
@@
   - `test_harness_lua.{hpp,cpp}`       — Lua bindings; delegates to TestRuntime
+  - `lua_sandbox.{hpp,cpp}`            — restricted Lua stdlib + require path controls
@@
 ## 3) `test_harness` Lua API Contract (Stable Interface)
@@
 ### 3.6 Runtime args and capability handshake
@@
 - `test_harness.require(opts) -> true|error`
+ - `test_harness.require(opts) -> true|error`
+
+### 3.9 Script sandboxing (behavior)
+- In `--test-mode`, Lua runs in a restricted environment:
+  - `os.execute`, `io.popen` disabled
+  - `os.time`, `os.clock` removed or deterministic stubs
+  - `require` search path restricted to test framework + test suites
+- Optional local-only escape hatch:
+  - `--lua-sandbox=on|off` (default: `on`; CI should force `on`)
```

---

## 12) Input system: add “authoritative input state” + coordinate-space clarity

### What
Input injection APIs are good, but E2E tests also need:
- a way to read what the game thinks the input state is (for debugging and determinism)
- explicit coordinate spaces (window pixels vs. logical UI coords vs. world coords)

Add:
- `test_harness.input_state()` returning key/mouse/gamepad states for the current frame
- `test_harness.screen_to_ui(x,y)` and `ui_to_screen(x,y)` (or `query("ui.transform", ...)`)
- define whether `move_mouse(x,y)` is in screen pixels at `--resolution` or logical units

### Why this makes it better
- **Reliability:** eliminates “click is off by UI scale factor” flakes.
- **Debuggability:** input trace + authoritative state tells you if events were dropped.
- **Portability:** makes tests less fragile across DPI/UI scaling.

### Tradeoffs
- Requires a small amount of UI/input plumbing, but it pays back immediately.

### Diff
```diff
diff --git a/docs/e2e_testing_master_plan_v2.md b/docs/e2e_testing_master_plan_v2.md
--- a/docs/e2e_testing_master_plan_v2.md
+++ b/docs/e2e_testing_master_plan_v2.md
@@
 ### 3.2 Input injection (applied at frame boundaries)
 - `press_key`, `release_key`, `tap_key`
 - `move_mouse`, `mouse_down`, `mouse_up`, `click`
 - `text_input(str)`
 - `gamepad_button_down/up`, `gamepad_set_axis`
+  - Input coordinate contract:
+    - `move_mouse(x,y)` uses **render target pixel coordinates** under `--resolution` (0..W-1, 0..H-1).
+    - UI scaling must be applied via helper transforms (below) rather than implicit guessing.
+
+### 3.2.1 Input state + transforms (new)
+- `test_harness.input_state() -> table`
+  - snapshot of effective input state for the current frame (keys down, mouse pos/buttons, gamepad).
+- `test_harness.screen_to_ui(x,y) -> ux, uy`
+- `test_harness.ui_to_screen(ux,uy) -> x, y`
+  - If the engine has no UI system, implement as `query("ui.transform", ...)` instead.
```

---

# Extra “nice but high impact” additions (optional)

These are not strictly required, but they tend to move a test system from “works” to “teams rely on it”.

### A) Add a `tests/fixtures/` directory + a fixture API
Use fixtures to load deterministic state (saves, configs, input traces). Prevent “tests depend on my local save file”.

### B) Add a dedicated “logic-only” workflow
Run `--renderer=null` on more platforms quickly, then run canonical screenshot workflow once.

### C) Add sanitizer workflows
ASan/UBSan/TSan builds catch the crashes before they become “random CI hangs”.

---

# Combined revised outline (v2.1 summary)

If you apply the changes above, your “v2” plan essentially becomes “v2.1” with these upgrades:
- schemas + failure taxonomy
- external supervisor for CI
- snapshot/restore elevated to milestone gate
- determinism tripwires + linting
- baseline staging + approval gate
- HTML artifact index
- seeded shuffle option
- perf budgets
- flake triage automation
- unified timeline log
- Lua sandboxing
- input state + coordinate transforms

That’s the set of changes that most directly increases **robustness**, **diagnosability**, and **team adoption** without turning the scope into “build Selenium for games”.

---
