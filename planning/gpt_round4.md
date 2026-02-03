# Review & Revisions: E2E Game Testing System Master Plan v3 → **v3.1 (proposed)**

Date: 2026-02-02  
Scope: Architectural upgrades, robustness/reliability improvements, scalability/performance improvements, and usability/debuggability upgrades.

This document proposes **targeted, high-leverage changes** to the original v3 plan you provided. For each change:

- what to change (and why),
- practical impact/tradeoffs,
- and a **git-diff–style patch hunk** showing how the plan text would change.

> Note: Diffs are presented as focused hunks (not a single monolithic patch) so each change is reviewable and can be applied independently.

---

## Executive diagnosis of the current v3 plan

v3 is already strong: deterministic contract, versioned schemas, supervisor, baseline staging, tripwires, sharding/retries, forensics bundle, and a narrow Test API Surface.

The main remaining systemic risks/opportunities:

1. **Crash containment vs. throughput**: process-per-test isolation is mentioned but not fully integrated into the *runner/orchestrator design*. Today, the “single game process runs the suite” model is still the implicit default.
2. **Test metadata sprawl**: timeouts, retries, quarantine, baseline masks/ROI, allowed logs, etc., will end up duplicated across Lua files and meta JSONs unless you centralize it.
3. **Debuggability gaps when things go wrong**: you have artifacts and diffs, but you’re missing *structured “steps”*, *pre-kill hang dumps*, and *divergence diffs* that point to what changed.
4. **API surface drift risk**: queries/commands are “whitelisted” but not *described/validated* as a first-class schema—so maintainability and tooling are limited.
5. **Performance regressions**: you have budgets but no standard trace output (Chrome trace) and no clean way to compare “today vs. baseline” without extra work.
6. **Security / determinism holes**: network access and OS side effects aren’t explicitly pinned/guarded in test mode.

The changes below directly address these.

---

# Change 1 — Upgrade the Supervisor into a real **Orchestrator** (CI + optional local)

### What changes
Evolve `tools/e2e_supervisor` into a **test orchestrator** that can:
- enumerate tests (`--list-tests`) in machine-readable form,
- shard at the orchestrator layer,
- run **process-per-test** (or per file) reliably,
- merge per-test reports into one run report,
- and still enforce hard timeouts/crash salvage.

### Why this makes the project better
- **Reliability**: a crash only kills one test, not the whole suite.
- **Performance**: orchestrator can parallelize tests across CPU cores *on one machine* (not only via CI job sharding).
- **Better flake triage**: retry logic is more trustworthy when each attempt is a fresh process.
- **Cleaner architecture**: game process becomes “run one test / run one shard”, orchestrator does orchestration.

### Tradeoffs
- Higher total startup overhead (process launch per test). Mitigate with:
  - `process-per-file` as a middle ground,
  - and running “smoke” suites in-process locally.

### Implementation notes
- Add an **exact** single-test flag: `--run-test-exact <full_name>` or `--run-test-id <id>`.
- Add a JSON list-tests output: `--list-tests --list-tests-json <path>` to avoid parsing stdout.
- Add report merge logic: orchestrator merges `report.json` files into a single authoritative one.

### Diff (plan changes)
```diff
diff --git a/docs/e2e_master_plan_v3.md b/docs/e2e_master_plan_v3.md
--- a/docs/e2e_master_plan_v3.md
+++ b/docs/e2e_master_plan_v3.md
@@
-### Supervisor (recommended for CI)
-Add a thin launcher tool:
-- `./tools/e2e_supervisor -- <game args...>`
+### Supervisor/Orchestrator (recommended for CI; useful locally too)
+Evolve the launcher into a **suite orchestrator**:
+- `./tools/e2e_supervisor run -- <game args...>`
+- `./tools/e2e_supervisor list -- <game args...>`
@@
-Responsibilities:
-1. Spawn game process with the requested flags.
-2. Enforce hard wall-clock timeouts externally (SIGKILL / TerminateProcess).
-3. On crash/timeout, ensure `tests/out/<run_id>/forensics/` exists:
-   - if the game failed to write it, the supervisor writes a minimal manifest + tail of stderr.
-4. Optionally collect OS crash artifacts:
-   - Linux: core dump path if configured
-   - Windows: minidump (if enabled)
-5. Normalize exit codes to the same contract (0/1/2/3/4).
+Responsibilities (Orchestrator):
+1. Discover tests in machine-readable form (`list`).
+2. Compute deterministic sharding at the orchestrator layer.
+3. Run tests with isolation:
+   - `process-per-test` (default in CI) or `process-per-file`.
+   - optional parallel workers per machine.
+4. Enforce hard wall-clock timeouts externally (SIGKILL / TerminateProcess).
+5. On crash/timeout, ensure `tests/out/<run_id>/forensics/` exists:
+   - if the game failed to write it, write a minimal manifest + stderr tail.
+6. Collect OS crash artifacts (optional):
+   - Linux: core dump path if configured
+   - Windows: minidump (if enabled)
+7. Merge child reports into one authoritative run report (JSON + JUnit).
+8. Normalize exit codes to the same contract (0/1/2/3/4).
@@
-CI should call the supervisor rather than invoking the game directly.
+CI should call the supervisor/orchestrator rather than invoking the game directly.
```

---

# Change 2 — Add a stable **Test ID** (explicit) separate from display name

### What changes
Allow `it()` definitions to optionally provide a stable `id` (e.g., `menu.main_loads`), and treat it as the canonical identity for:
- filtering,
- baselines,
- trend tracking,
- flake history.

### Why this makes the project better
- **Renames stop breaking history**: `name` can change without losing longitudinal data.
- **Baselines become stable**: baselines keyed to `test_id` don’t churn when a human rephrases a test name.
- **Better tooling**: orchestrator can run exact tests without regex ambiguity.

### Tradeoffs
- Slight authoring overhead. Mitigate by:
  - making `id` optional,
  - and warning when missing for screenshot tests or perf-budget tests.

### Diff
```diff
diff --git a/docs/e2e_master_plan_v3.md b/docs/e2e_master_plan_v3.md
--- a/docs/e2e_master_plan_v3.md
+++ b/docs/e2e_master_plan_v3.md
@@
-1. `test_runner.lua`: `describe/it`, hooks, deterministic ordering (or deterministic shuffle), per-test results, timeouts, frame budgets.
-   - tags: `it("does X", { tags={"ui","smoke"} }, function() ... end)`
+1. `test_runner.lua`: `describe/it`, hooks, deterministic ordering (or deterministic shuffle), per-test results, timeouts, frame budgets.
+   - stable identity:
+     - `it("does X", { id="menu.main_loads", tags={"ui","smoke"} }, function() ... end)`
+     - `id` is optional but strongly recommended for screenshot/perf tests.
@@
-### Baselines (versioned)
-- `tests/baselines/<platform>/<baseline_key>/<WxH>/...png`
+### Baselines (versioned)
+- `tests/baselines/<platform>/<baseline_key>/<WxH>/<test_id>/...png`
@@
-  - Optional per-baseline metadata (versioned):
-    - `.../<name>.meta.json` (thresholds, ROI, masks, notes)
+  - Optional per-baseline metadata (versioned):
+    - `.../<test_id>/<name>.meta.json` (thresholds, ROI, masks, notes)
```

---

# Change 3 — Introduce a **Test Metadata Manifest** (central policy + overrides)

### What changes
Add a repo-managed manifest file (JSON/TOML) that defines policy and per-test overrides without editing test code:
- timeouts,
- quarantine,
- retries,
- allowed log categories/levels,
- baseline meta defaults (ROI/masks),
- perf budgets.

Example: `tests/test_manifest.json`.

### Why this makes the project better
- **Governance**: quarantine and timeouts become reviewable diffs in one place.
- **Less code churn**: baseline mask edits don’t require Lua changes.
- **Scales to 100s–1000s of tests** cleanly.

### Tradeoffs
- Another file to maintain.
- Requires an override resolution order (“defaults → suite → test → CLI”).

### Diff
```diff
diff --git a/docs/e2e_master_plan_v3.md b/docs/e2e_master_plan_v3.md
--- a/docs/e2e_master_plan_v3.md
+++ b/docs/e2e_master_plan_v3.md
@@
 ## 2) CLI Contract (Single Source of Truth)
@@
 ### Suite control / hygiene
@@
 - `--shuffle-seed <u32>` (default: derived from `--seed`)
+ - `--test-manifest <path>` (default: `tests/test_manifest.json`)
+   - Central policies + per-test overrides (timeouts, quarantine, retries, log allowlists, baseline ROI/masks defaults, perf budgets).
@@
 ### Phase 3 — Lua Test Framework (Lua)
@@
-1. `test_runner.lua`: `describe/it`, hooks, deterministic ordering (or deterministic shuffle), per-test results, timeouts, frame budgets.
+1. `test_runner.lua`: `describe/it`, hooks, deterministic ordering (or deterministic shuffle), per-test results, timeouts, frame budgets.
+   - Load `--test-manifest` once; merge config:
+     - global defaults → suite defaults → per-test overrides → inline opts → CLI overrides.
```

---

# Change 4 — Add **Step annotations** + structured “attachments” to reports

### What changes
Add APIs so tests can produce structured steps and attach diagnostic text/files that show up in JSON/JUnit/HTML:
- `test_harness.step("open menu", function() ... end)`
- `test_harness.attach_text("ui_tree", dump)`
- `test_harness.attach_file("savegame", path)`

### Why this makes the project better
- **Compelling usability**: failures become readable narratives.
- **Faster debugging**: steps narrow where it failed; attachments preserve context.
- **Better CI UX**: JUnit can show step names; HTML gallery can group artifacts by step.

### Tradeoffs
- Requires reporters to support steps.
- Need limits to prevent huge attachments (cap size, truncate, compress).

### Diff
```diff
diff --git a/docs/e2e_master_plan_v3.md b/docs/e2e_master_plan_v3.md
--- a/docs/e2e_master_plan_v3.md
+++ b/docs/e2e_master_plan_v3.md
@@
 ## 3) `test_harness` Lua API Contract (Stable Interface)
@@
 ### 3.1 Frame/time control (coroutine-friendly)
@@
 - `test_harness.xfail(reason)` (expected fail; fail→XFAIL, pass→XPASS)
+
+### 3.1.1 Steps + attachments (debuggability)
+- `test_harness.step(name, fn) -> returns fn result`
+  - Emits structured step start/end events (with frame + timings) into `timeline.jsonl` and `report.json`.
+- `test_harness.attach_text(name, text, opts?)`
+- `test_harness.attach_file(name, path, opts?)`
+  - `opts`: `{ mime="text/plain", max_bytes=1048576 }`
@@
 ### 4) Execution Model (Deterministic + Blocking Waits)
@@
 - `timeline_writer`: merged `timeline.jsonl` with inputs/logs/screenshots/hashes.
+ - `timeline_writer`: merged `timeline.jsonl` with inputs/logs/screenshots/hashes/**steps/attachments**.
```

---

# Change 5 — Formalize the Test API Surface as a **typed registry + schema**

### What changes
Add a `test_api_registry` in C++ with explicit registration for:
- state paths (read/write),
- queries,
- commands,
- capabilities,
- versioning.

Generate a machine-readable description at runtime (`test_api.json`) and validate it in CI.

### Why this makes the project better
- **Robustness**: fewer “mystery string paths”; wrong calls fail early with good errors.
- **Tooling**: auto-generate documentation, autocomplete stubs, and static checks.
- **Backwards compatibility**: you can enforce semantic versioning rules at registration time.

### Tradeoffs
- Some up-front engineering.
- Requires discipline: all test-visible hooks must go through the registry.

### Diff
```diff
diff --git a/docs/e2e_master_plan_v3.md b/docs/e2e_master_plan_v3.md
--- a/docs/e2e_master_plan_v3.md
+++ b/docs/e2e_master_plan_v3.md
@@
 ## 1) Canonical Naming, Structure, and Paths
@@
 - `src/testing/`
+  - `test_api_registry.{hpp,cpp}`      — typed registry for state paths/queries/commands + versioning
+  - `test_api_dump.{hpp,cpp}`          — writes `test_api.json` description artifact
@@
 ## 0.2 Report + Manifest Contracts (Versioned)
@@
 - `run_manifest.json` includes:
+ - `run_manifest.json` includes:
@@
   - `determinism_pins` (FTZ/DAZ, rounding, locale, TZ, thread mode, etc.)
+  - `test_api_fingerprint` (hash of exported Test API registry descriptor)
@@
 ## 5) Implementation Phases (with acceptance gates)
@@
 ### Phase 0 — Recon + Interface Freeze (enables parallel work)
@@
-4. Define and commit JSON schemas for `report.json` and `run_manifest.json`.
+4. Define and commit JSON schemas for `report.json` and `run_manifest.json`.
+5. Define a schema for `test_api.json` (registry descriptor) and commit it.
```

---

# Change 6 — Add a **network sandbox** + explicit network determinism policy

### What changes
In `--test-mode`, default to **no external network** (or “localhost only”), unless explicitly enabled.
Add runtime tripwires for socket usage when disabled.

### Why this makes the project better
- **Determinism**: network timing introduces unavoidable nondeterminism.
- **Security**: CI runs PR code; disallowing outbound network reduces risk.
- **Reliability**: tests don’t silently depend on services.

### Tradeoffs
- If your game genuinely needs network for some flows, you can:
  - mock it in test mode,
  - or add `--allow-network=localhost` for controlled use.

### Diff
```diff
diff --git a/docs/e2e_master_plan_v3.md b/docs/e2e_master_plan_v3.md
--- a/docs/e2e_master_plan_v3.md
+++ b/docs/e2e_master_plan_v3.md
@@
 ## 0.1 Determinism Contract (Test Mode)
@@
 9. **GPU/renderer synchronization points must be explicit for screenshots.**
@@
+10. **External network access must be pinned/disabled.**
+    - Default: outbound network disabled in `--test-mode` to avoid nondeterminism and CI risk.
+    - If needed: allow `localhost` only via explicit flag.
@@
 ## 2) CLI Contract (Single Source of Truth)
@@
 ### Core
@@
 - `--resolution <WxH>` (default: `1280x720`)
+ - `--allow-network <mode>` (default: `deny`; `deny|localhost|any`)
@@
 ### Determinism audit (tripwire)
@@
 - `--determinism-violation <mode>` (default: `fatal`; `fatal|warn`)
+ - `--determinism-violation <mode>` (default: `fatal`; `fatal|warn`)
+   - includes `DET_NET` for network violations when `--allow-network=deny|localhost`.
```

---

# Change 7 — Add “pre-kill” **hang diagnostics** on watchdog timeout

### What changes
Before the supervisor hard-kills a hung game, attempt a cooperative “dump now”:
- send a platform signal/IPC ping to request:
  - thread backtraces (where possible),
  - last-frame screenshot,
  - log flush,
  - and a `hang_dump.json`.

If the game ignores it, the supervisor still kills after a short grace interval (e.g., 3–5 seconds).

### Why this makes the project better
- **Big reliability win in practice**: timeouts are the worst failures to debug.
- **Less rerun churn**: you often get the root cause in the first failing CI artifact.

### Tradeoffs
- Some platform-specific work for stack traces.
- Must be careful not to deadlock further while dumping; keep it best-effort and bounded.

### Diff
```diff
diff --git a/docs/e2e_master_plan_v3.md b/docs/e2e_master_plan_v3.md
--- a/docs/e2e_master_plan_v3.md
+++ b/docs/e2e_master_plan_v3.md
@@
 ### Supervisor/Orchestrator (recommended for CI; useful locally too)
@@
-4. Enforce hard wall-clock timeouts externally (SIGKILL / TerminateProcess).
+4. Enforce hard wall-clock timeouts externally (SIGKILL / TerminateProcess).
+   - Before kill: attempt a bounded cooperative dump request (best-effort) to capture hang diagnostics.
@@
 ## Appendix B: Forensics Bundle Specification
@@
 | File | Description |
@@
 | `forensics.zip` | Optional zipped bundle |
+| `hang_dump.json` | Optional: watchdog-triggered hang diagnostics (thread states, last known frame, watchdog reason) |
```

---

# Change 8 — Improve determinism-audit failures with a **state diff** (not just hashes)

### What changes
On determinism divergence:
- store the last N frames of `frame_hash` (already implied),
- **and** store a structured diff of the Test API Surface snapshot:
  - which keys changed,
  - old/new values,
  - plus optional “top offenders” (entity counts, RNG stream positions, etc.).

### Why this makes the project better
- Hash tells you “something changed.” Diff tells you **what changed**.
- Helps quickly detect common nondeterminism sources: RNG, ordering, floating point drift, async completion.

### Tradeoffs
- Requires being able to snapshot the Test API Surface as a stable JSON structure.
- Need limits to avoid giant diffs (cap size, summarize).

### Diff
```diff
diff --git a/docs/e2e_master_plan_v3.md b/docs/e2e_master_plan_v3.md
--- a/docs/e2e_master_plan_v3.md
+++ b/docs/e2e_master_plan_v3.md
@@
 ### Determinism audit mode
 If `--determinism-audit`:
@@
 - Any divergence fails with:
-  - first divergent frame
-  - hashes before/after
-  - repro command + artifacts
+ - Any divergence fails with:
+   - first divergent frame
+   - hashes before/after
+   - **Test API Surface snapshot diff** (bounded and summarized)
+   - repro command + artifacts
@@
 ## Appendix B: Forensics Bundle Specification
@@
 | `timeline.jsonl` | Merged events `{ frame, type, ... }` to correlate everything |
+| `determinism_diff.json` | Optional: divergence diff of Test API Surface snapshots (bounded) |
```

---

# Change 9 — Add a standardized **Chrome Trace** export (perf + stalls + loading)

### What changes
Add an optional output compatible with `chrome://tracing` / Perfetto:
- run-level trace: `trace.json`
- optionally per-test trace slices.

This should include:
- frame boundaries,
- main thread update,
- render submit,
- asset loads,
- GC/alloc spikes (where supported).

### Why this makes the project better
- Makes performance budgets actionable: you can *see* what regressed.
- Helps track intermittent stalls that cause timeouts/flakes.

### Tradeoffs
- Instrumentation overhead; keep it opt-in or low-frequency.
- Need size caps and filtering.

### Diff
```diff
diff --git a/docs/e2e_master_plan_v3.md b/docs/e2e_master_plan_v3.md
--- a/docs/e2e_master_plan_v3.md
+++ b/docs/e2e_master_plan_v3.md
@@
 ### Performance (optional but recommended)
@@
 - `--perf-budget <path>` (default: empty; JSON budget file)
+ - `--perf-trace <path>` (default: empty; writes Chrome Trace JSON for the run)
@@
 ## Appendix B: Forensics Bundle Specification
@@
 | `forensics.zip` | Optional zipped bundle |
+| `trace.json` | Optional: Chrome Trace JSON (Perfetto-compatible) for perf/stall debugging |
```

---

# Change 10 — Add failure-focused **video capture** (small, bounded, optional)

### What changes
Instead of (or in addition to) “last_frames/ as PNGs”, optionally produce a short encoded clip (e.g., WebM/MP4/GIF) on failure:
- last N seconds or last N frames,
- low-res option to keep artifacts small.

### Why this makes the project better
- Screenshot diffs are great; videos often make “what happened?” obvious in 5 seconds.
- Especially valuable for UI flows, camera motion, and timing issues.

### Tradeoffs
- Encoding adds complexity and dependencies.
- Make it optional and best-effort; fall back to PNG ring buffer if encoder missing.

### Diff
```diff
diff --git a/docs/e2e_master_plan_v3.md b/docs/e2e_master_plan_v3.md
--- a/docs/e2e_master_plan_v3.md
+++ b/docs/e2e_master_plan_v3.md
@@
 ## 2) CLI Contract (Single Source of Truth)
@@
 ### Sharding + timeouts
@@
 - `--default-test-timeout-frames <int>` (default: `1800`; per-test timeout measured in frames)
+ - `--default-test-timeout-frames <int>` (default: `1800`; per-test timeout measured in frames)
+ - `--failure-video <mode>` (default: `off`; `off|on`)
+ - `--failure-video-frames <n>` (default: `180`; number of frames to retain/encode on failure)
@@
 ## Appendix B: Forensics Bundle Specification
@@
 | `last_frames/` | Optional ring buffer of last N frames captured only on failure |
+| `failure_clip.webm` | Optional: encoded clip of last N frames on failure (if enabled) |
```

---

# Change 11 — Make screenshot assertions less brittle with **semantic ROI** and UI selectors

### What changes
Augment `assert_screenshot()` to accept ROI/masks by **semantic selectors**, not just pixel rectangles:
- `region = { selector="ui:InventoryPanel" }`
- `masks = { { selector="ui:ClockLabel" }, ... }`

Also add common high-level actions in `actions.lua` that click UI elements by name using `ui.element_rect()`.

### Why this makes the project better
- Reduces maintenance cost when UI layout shifts slightly.
- Makes tests more readable and less dependent on coordinate transforms.

### Tradeoffs
- Requires UI query hooks to be reliable.
- Needs clear failure messages when selector missing.

### Diff
```diff
diff --git a/docs/e2e_master_plan_v3.md b/docs/e2e_master_plan_v3.md
--- a/docs/e2e_master_plan_v3.md
+++ b/docs/e2e_master_plan_v3.md
@@
 ### 3.4 Screenshots & comparisons
@@
   - `opts`:
     ```lua
     {
@@
-      region = nil,              -- {x,y,w,h} compare ROI only
-      masks = nil,               -- list of {x,y,w,h} areas to ignore
+      region = nil,              -- {x,y,w,h} OR { selector="ui:<name>" }
+      masks = nil,               -- list of {x,y,w,h} OR { selector="ui:<name>" } areas to ignore
@@
     }
     ```
@@
 ### Phase 5 — Example Tests + Test Hooks (Game Lua/C++)
@@
    - queries: `ui.element_rect(name)`, `ui.element_visible(name)`
+   - queries: `ui.element_rect(name)`, `ui.element_visible(name)`, `ui.element_center(name)`
```

---

# Change 12 — Make report artifacts and attempts **fully structured** (paths + metadata)

### What changes
Right now `artifacts` is just a list of strings. Upgrade to include structured metadata:
- `kind` (`screenshot`, `diff`, `log`, `trace`, `repro`, `video`, `attachment`, ...),
- `path`,
- `attempt`,
- `step` (optional),
- `description` (optional).

### Why this makes the project better
- HTML gallery can be smarter automatically.
- CI summaries become programmatic and consistent.
- Makes it easy to attach new artifact types without breaking clients.

### Tradeoffs
- Schema bump required (`report.schema.json` semver).

### Diff
```diff
diff --git a/docs/e2e_master_plan_v3.md b/docs/e2e_master_plan_v3.md
--- a/docs/e2e_master_plan_v3.md
+++ b/docs/e2e_master_plan_v3.md
@@
 ## 0.2 Report + Manifest Contracts (Versioned)
@@
 - per-test: `status`, `attempts`, `artifacts`, `timings_frames`, `timings_ms` (optional)
+ - per-test: `status`, `attempts`, `artifacts[]` (structured), `timings_frames`, `timings_ms` (optional)
@@
 ## Appendix D: Report Schema
@@
   "tests": [
     {
@@
-      "artifacts": ["artifacts/menu_test/screenshot.png"],
+      "artifacts": [
+        { "kind": "screenshot", "path": "artifacts/menu_test/screenshot.png", "attempt": 1, "step": null }
+      ],
       "timings_frames": 120,
       "timings_ms": 2000
     }
   ],
```

---

# Change 13 — Add an explicit **exact-match** single-test execution mode for orchestrated runs

### What changes
Add a CLI mode that guarantees running exactly one test (by id or full name) and fails if it matches zero or >1 tests:
- `--run-test-id <id>`
- `--run-test-exact <full_name>`

### Why this makes the project better
- Orchestrator can safely run individual tests without regex ambiguity.
- Makes repro commands safer and more copy/paste friendly.

### Tradeoffs
- More flags to document; worth it.

### Diff
```diff
diff --git a/docs/e2e_master_plan_v3.md b/docs/e2e_master_plan_v3.md
--- a/docs/e2e_master_plan_v3.md
+++ b/docs/e2e_master_plan_v3.md
@@
 ### Core
@@
 - `--test-filter <glob_or_regex>` (run matching tests only)
+ - `--test-filter <glob_or_regex>` (run matching tests only)
+ - `--run-test-id <id>` (run exactly one test by stable id; errors if not exactly one match)
+ - `--run-test-exact <full_name>` (run exactly one test by full name; errors if not exactly one match)
```

---

# Change 14 — Tighten artifact/path safety: **read roots vs write roots**

### What changes
Right now path sandbox focuses on output path traversal. Add a second dimension:
- **read roots** (assets/tests/baselines only),
- **write roots** (tests/out, baselines staging only),
and enforce them everywhere Lua might read/write through the harness.

### Why this makes the project better
- Prevents accidental reads from user home directories and other nondeterministic sources.
- Strengthens security posture in CI (especially for fork PRs).

### Tradeoffs
- Requires a clear “approved roots” set and some integration work.

### Diff
```diff
diff --git a/docs/e2e_master_plan_v3.md b/docs/e2e_master_plan_v3.md
--- a/docs/e2e_master_plan_v3.md
+++ b/docs/e2e_master_plan_v3.md
@@
 ### Behavior rules
@@
-- All artifact/report paths are created if missing; path traversal outside repo/output roots is rejected.
-  - Enforcement centralized in `path_sandbox` + `artifact_store` (no ad-hoc checks).
+- All artifact/report paths are created if missing; path traversal outside approved roots is rejected.
+  - Approved **write roots**: `tests/out/**`, `tests/baselines_staging/**` (and `tests/baselines/**` only with explicit apply token).
+  - Approved **read roots**: `assets/**`, `tests/baselines/**`, `tests/baselines_staging/**`, `assets/scripts/tests/fixtures/**`.
+  - Enforcement centralized in `path_sandbox` + `artifact_store` (no ad-hoc checks).
```

---

# Change 15 — Extend determinism linting beyond grep: add a clang-tidy “determinism” profile

### What changes
Keep the grep job, but add a real static analysis path:
- a clang-tidy config that flags banned calls and risky containers in determinism-critical modules.

### Why this makes the project better
- Grep is easy to evade unintentionally (wrappers, typedefs, indirection).
- clang-tidy catches more and can be targeted to `src/testing/` + core sim modules.

### Tradeoffs
- Requires clang-tidy setup; may be slower in CI.
- Keep it as “warnings” initially; ramp to “errors” later.

### Diff
```diff
diff --git a/docs/e2e_master_plan_v3.md b/docs/e2e_master_plan_v3.md
--- a/docs/e2e_master_plan_v3.md
+++ b/docs/e2e_master_plan_v3.md
@@
 ## Appendix E: CI Linting (Determinism)
@@
-Add a CI job that greps or clang-tidy checks determinism-critical modules for banned APIs:
+Add a CI job that greps **and** clang-tidy checks determinism-critical modules for banned APIs:
@@
 Example `.github/workflows/lint-determinism.yml`:
@@
       - name: Check for banned APIs
         run: |
@@
           src/game/ src/engine/ || exit 1
+      - name: clang-tidy determinism profile (optional but recommended)
+        run: |
+          # Run clang-tidy on determinism-critical targets with a dedicated config.
+          # Start as non-blocking; promote to blocking once stable.
+          ./tools/run_clang_tidy_determinism.sh || true
```

---

## Suggested small but high-value plan edits (no full diffs included)

These are deliberately smaller; add them if you want extra polish:

- Add `--continue-on-assert` vs “fail-fast” semantics inside a test (useful for screenshot suites).
- Add `test_harness.assume(predicate, reason)` as a soft precondition that SKIPs.
- Add `--artifact-max-mb` and `--artifact-compress=on|off` to avoid CI artifact blowups.
- Add a “capabilities override” mechanism for local testing (e.g., pretend screenshots unsupported) to catch graceful skipping.

---

## Revised milestone impacts

If you adopt changes 1–5, you should update milestones:

- **M2/M3** become easier to harden because orchestrator + exact single-test run improves reproducibility and crash isolation.
- Add a new milestone between M4 and M6:

**M4.5 (Orchestrated isolation):** CI runs via orchestrator in `process-per-test` mode, merges reports, and produces per-test forensics on crash/timeout.

---

## Practical adoption order (recommended)

If you want maximum ROI with minimum thrash:

1) **Change 13 + Change 1** (exact single-test + orchestrator)  
2) **Change 4 + Change 12** (steps + structured artifacts)  
3) **Change 3** (test manifest)  
4) **Change 6 + Change 14** (network + read/write sandbox)  
5) **Change 8** (determinism diff)  
6) **Change 9** (Chrome trace)  
7) **Change 10** (failure video)

---

## Closing note

These changes are designed to keep the spirit of your v3 plan (deterministic embedded harness + strong artifacts), while fixing the two big pain points that usually kill E2E systems in real production:

- **uncontained crashes/timeouts**, and  
- **poor debugging signal when tests fail**.

If you implement only a subset, prioritize the orchestrator + steps + structured artifacts—the payoff is immediate.

