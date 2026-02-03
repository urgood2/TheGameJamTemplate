# Cass Memory Update Plan v2 — Proposed Revisions (Review of v1)

This document reviews **“Cass Memory Update Plan v1 (Revised with Automation & Drift Prevention)”** and proposes targeted upgrades to make it:

- **More reliable** (less flaky, fewer false positives, deterministic outputs)
- **More maintainable** (less drift between docs/tests/registry/inventories/cm rules)
- **More performant** (faster execution, CI sharding, fewer manual steps)
- **More compelling/useful** (better discoverability, better CI reporting, better IDE integration)

For each proposed change you’ll get:

1. **Analysis + rationale** (what v1 risks or leaves ambiguous, and why the change helps)
2. A **git-diff style patch** against the v1 plan text (snippets, scoped to the impacted sections)

> Notes:
> - I don’t have the repo, so anything repo-specific is expressed as a **Phase 1-resolved variable** (e.g., `<TEST_ROOT>`).
> - Diffs are **intentionally scoped**. Apply them mechanically if you keep the plan as a file, or use them as patch guidance when rewriting v1 into v2.

---

## High-level diagnosis (what to fix)

v1 is already unusually strong for an execution plan. The remaining “sharp edges” are mostly about **scale** and **long-term hygiene**:

1. **Naming and path drift risk**
   - `binding_tests.lua` is named like it only covers bindings, but the suite becomes broader by Phase 4/5/7.
   - Appendix shows a `tests/` directory while most of the plan uses `test/`. That’s fine as an estimate, but it’s also a real way to get accidental split-brain directories.

2. **Too many “truth sources” without a strong generator story**
   - v1 has docs, inventories, `test_registry.lua`, `cm_rules_candidates.yaml`, stubs… plus validators.
   - Validators are great, but **generation** is better: drift prevention improves drastically when you generate derived artifacts instead of hand-editing them.

3. **CI ergonomics & performance**
   - Without **JUnit XML**, CI test UIs are worse; failures are harder to skim.
   - Without **sharding**, the suite will become slow as coverage grows.

4. **Visual testing still under-specified**
   - You already mention baselines and tolerance, but you’ll want:
     - per-platform baseline layout
     - diff artifacts
     - a quarantine mechanism for genuinely GPU-flaky tests (or you’ll disable them entirely later)

5. **Manual inventories are going to be expensive**
   - Manually enumerating ~390 bindings is doable once, but maintaining it is where it gets painful.
   - You’ll get better ROI by **automating Tier 0 extraction** (even if imperfect) and letting humans add Tier 1/2 semantics.

---

## Summary of proposed changes

| # | Change | Primary win |
|---:|---|---|
| 01 | Rename harness + parameterize `<TEST_ROOT>` | Clarity, prevents directory drift |
| 02 | Capability detection + SKIP semantics | Fewer false failures across environments |
| 03 | Schema versioning + JSON Schemas + JUnit XML | CI friendliness + future-proofing |
| 04 | Test sharding + enforced timeouts | Faster CI + no hung runs |
| 05 | Visual baselines: per-platform + diffs + tolerance config + quarantine | Stable visual verification |
| 06 | Automated Sol2 inventory extraction (Tier 0) | Massive labor reduction + drift control |
| 07 | Automated ECS component extraction (Tier 0) | Same as above for components |
| 08 | Auto-generated scope stats (single source) | Keeps counts consistent, kills stale tables |
| 09 | One-command “check all” script + optional pre-commit | Makes hygiene cheap enough to run always |
| 10 | cm rule governance: richer schema + idempotent importer | Prevents duplicate clutter + improves traceability |
| 11 | Lua DX: `.luarc.json`, stub packaging, regen docs | Stubs actually get used |
| 12 | Doc discoverability + link integrity checks | People can find and trust the knowledge base |

---

# Change 01 — Rename harness + parameterize `<TEST_ROOT>` to stop path drift

### What’s weak in v1
- `assets/scripts/test/binding_tests.lua` becomes misleading the moment you add non-binding tests (UI patterns, entity lifecycle).
- Appendix implies there’s already a `tests/` directory. Even if that’s just estimates, it highlights a real risk: people will create both `test/` and `tests/` over time.
- Dozens of hardcoded paths in the plan create churn if Phase 1 discovers different conventions.

### Revision
- Introduce a plan-level variable: **`<TEST_ROOT>`** determined in Phase 1 and used everywhere.
- Rename `binding_tests.lua` → **`test_runner.lua`** to reflect that it’s the runner for *all* tests.

### Why this makes the project better
- **Reduced confusion**: new contributors won’t assume “binding_tests” is irrelevant to them.
- **Less churn**: Phase 1 can lock the test folder path once; the rest of the plan stays stable.
- **Less accidental divergence**: fewer “why are there two test folders?” problems.

### Tradeoffs
- Small rename churn early, but *far* cheaper than later once many tests exist.

### Git diff vs v1 plan
```diff
diff --git a/Cass_Memory_Update_Plan.md b/Cass_Memory_Update_Plan.md
--- a/Cass_Memory_Update_Plan.md
+++ b/Cass_Memory_Update_Plan.md
@@
 ### Phase 1: Test Infrastructure Setup
 **Effort:** M (Medium)
 **Parallelizable:** No (Foundation for other phases)

+> **(New) Canonical test root (prevent directory drift):**
+> - Phase 1 must select the canonical test folder and record it once as `<TEST_ROOT>`.
+> - All references below use `<TEST_ROOT>` (e.g., `<TEST_ROOT>/test_runner.lua`).
+
 Create the verification pipeline that all subsequent phases depend on.

 **Deliverables:**
-1. `assets/scripts/test/binding_tests.lua` - Main test harness
-2. `assets/scripts/test/test_utils.lua` - Assertion helpers, screenshot capture
-3. `assets/scripts/test/test_registry.lua` - Track which patterns have been tested
+1. `<TEST_ROOT>/test_runner.lua` - Main test harness (runner implementation)
+2. `<TEST_ROOT>/test_utils.lua` - Assertion helpers, screenshot capture
+3. `<TEST_ROOT>/test_registry.lua` - Track which patterns have been tested
@@
-6. Test run documentation update: `assets/scripts/test/README.md` (or closest existing test README referenced by Phase 1 "How-to-run capture")
+6. Test run documentation update: `<TEST_ROOT>/README.md` (or closest existing test README referenced by Phase 1 "How-to-run capture")
@@
 > **Test file layout convention (clarity + implementability):**
-> - `assets/scripts/test/binding_tests.lua` provides the `TestRunner` implementation and shared runner logic.
-> - `assets/scripts/test/test_*.lua` files are *modules* that only register tests (no direct execution side effects besides registration).
-> - `assets/scripts/test/run_all_tests.lua` (Phase 7 deliverable) is the canonical execution entrypoint that requires `binding_tests.lua`, requires all `test_*.lua` modules, calls `TestRunner:run(...)`, and writes reports.
+> - `<TEST_ROOT>/test_runner.lua` provides the `TestRunner` implementation and shared runner logic.
+> - `<TEST_ROOT>/test_*.lua` files are *modules* that only register tests (no direct execution side effects besides registration).
+> - `<TEST_ROOT>/run_all_tests.lua` (Phase 7 deliverable) is the canonical execution entrypoint that requires `test_runner.lua`, requires all `test_*.lua` modules, calls `TestRunner:run(...)`, and writes reports.
```

---

# Change 02 — Add capability detection + SKIP semantics (make the suite portable)

### What’s weak in v1
- v1 has “Go/No-Go gates” but they’re human text only.
- Missing screenshot capture, missing write permissions, or missing log interception can turn into confusing failures.
- There’s no consistent SKIP definition: you need “skip with reason” to keep the suite runnable in multiple environments (dev machine vs CI).

### Revision
- Phase 1 writes a machine-readable **capabilities file**:
  - `test_output/capabilities.json`
- Each test can declare required capabilities (e.g., `requires={"screenshot"}`).
- Harness uses SKIP status instead of FAIL when a required capability is missing.

### Why this makes the project better
- **Fewer false negatives**: tests won’t “fail” just because CI is headless or permissions differ.
- **Better debugging**: capabilities are explicit; reviewers know why a test skipped.
- **More realistic scaling**: you can still run non-visual tests in more environments, keeping signal high.

### Tradeoffs
- You must decide which missing features are “fail the suite” vs “skip the tests that need it”.
  - Recommendation: missing “core determinism” should fail Phase 1 Go/No-Go; missing screenshot capture should skip visual tests but still allow non-visual CI.

### Git diff vs v1 plan
```diff
diff --git a/Cass_Memory_Update_Plan.md b/Cass_Memory_Update_Plan.md
--- a/Cass_Memory_Update_Plan.md
+++ b/Cass_Memory_Update_Plan.md
@@
 > **Go/No-Go gates (new, required outputs of Phase 1):**
 > - Deterministic test scene runnable: Yes/No (with exact procedure)
 > - `test_output/` writable: Yes/No (with constraints)
 > - Screenshot capture callable: Yes/No (with safe call timing)
 > - Log capture workable: Yes/No (engine hook or fallback)
 > - World reset between tests: Yes/No (preferred) / Strategy documented
+> - **(New)** Write `test_output/capabilities.json` capturing the above gates in machine-readable form (so CI/tools can act on it).
@@
 > **Report/status schema requirement (testability + CI-friendliness):**
 > - `test_output/status.json` must be machine-readable and stable. Minimum schema:
->   - `{"passed": true/false, "failed": <int>, "passed_count": <int>, "total": <int>, "generated_at": "<iso8601>" }`
+>   - `{"passed": true/false, "failed": <int>, "skipped": <int>, "passed_count": <int>, "total": <int>, "generated_at": "<iso8601>" }`
@@
 > - **(New, required)** Write `test_output/results.json` with per-test objects:
->   - `{"test_id": "...", "test_file": "...", "category": "...", "status":"pass|fail|skip", "duration_ms":123, "artifacts":[...], "error":{...}}`
+>   - `{"test_id": "...", "test_file": "...", "category": "...", "status":"pass|fail|skip", "duration_ms":123, "artifacts":[...], "skip_reason":"...", "error":{...}}`
@@
 > **Register API naming clarity (implementability):**
 > - Treat `name` in the stub above as the canonical `test_id` (string) following `{system}.{feature}.{case}`.
 > - If the repo prefers a human-friendly display name, add it as `opts.display_name` rather than changing the canonical `test_id`.
+>
+> **(New) Capability requirements per test (reliability across environments):**
+> - `register(test_id, category, testFn, opts)` supports `opts.requires = {"screenshot", "log_capture", ...}`.
+> - Harness checks `test_output/capabilities.json` (or in-memory equivalent) and emits `SKIP` with reason if requirements are missing.
```

---

# Change 03 — Add schema versioning + JSON Schemas + JUnit XML (CI-grade reporting)

### What’s weak in v1
- v1 defines JSON output formats, but without schema versioning future changes become silent breaking changes.
- CI visibility is limited without a standardized format like **JUnit XML**.

### Revision
- Add `schema_version` + `runner_version` to all machine-readable outputs.
- Commit JSON Schema files for validation.
- Generate `test_output/junit.xml` on every run.

### Why this makes the project better
- **Forward-compatible outputs**: tools can handle schema evolution safely.
- **Better CI UX**: JUnit gives first-class red/green, timing, and failure details in most CI systems.
- **Harder to regress**: schema validation catches accidental format drift.

### Tradeoffs
- Slight extra implementation, but you only do it once. Benefits continue forever.

### Git diff vs v1 plan
```diff
diff --git a/Cass_Memory_Update_Plan.md b/Cass_Memory_Update_Plan.md
--- a/Cass_Memory_Update_Plan.md
+++ b/Cass_Memory_Update_Plan.md
@@
 > **Report/status schema requirement (testability + CI-friendliness):**
 > - `test_output/status.json` must be machine-readable and stable. Minimum schema:
->   - `{"passed": true/false, "failed": <int>, "passed_count": <int>, "total": <int>, "generated_at": "<iso8601>" }`
+>   - `{"schema_version":"1.0", "runner_version":"<semver>", "passed": true/false, "failed": <int>, "skipped": <int>, "passed_count": <int>, "total": <int>, "generated_at": "<iso8601>" }`
@@
 > - **(New, required)** Write `test_output/results.json` with per-test objects:
->   - `{"test_id": "...", "test_file": "...", "category": "...", "status":"pass|fail|skip", "duration_ms":123, "artifacts":[...], "error":{...}}`
+>   - `{"schema_version":"1.0", "runner_version":"<semver>", "tests":[{"test_id": "...", "test_file": "...", "category": "...", "status":"pass|fail|skip", "duration_ms":123, "artifacts":[...], "skip_reason":"...", "error":{...}}]}`
+>
+> **(New) Schema validation deliverable (drift prevention):**
+> - Commit JSON Schemas under `planning/schemas/` (or `scripts/schemas/` if preferred):
+>   - `planning/schemas/status.schema.json`
+>   - `planning/schemas/results.schema.json`
+>   - `planning/schemas/capabilities.schema.json`
@@
 ### Phase 7: Test Suite Finalization
@@
 **Deliverables:**
 1. `assets/scripts/test/run_all_tests.lua`
 2. `test_output/coverage_report.md`
 3. CI-friendly test script (exit codes)
 4. **(New)** `scripts/validate_docs_and_registry.lua` (or `.py`) and a documented invocation
 5. **(New)** Generated EmmyLua stubs: `docs/lua_stubs/` (generated, not hand-edited)
+6. **(New)** JUnit report: `test_output/junit.xml` generated every run for CI consumption
+7. **(New)** Schema validation step in CI that validates `status.json`, `results.json`, and `capabilities.json` against committed schemas
```

---

# Change 04 — Add test sharding + enforced timeouts (scale the suite without slowing CI)

### What’s weak in v1
- As coverage grows, a single run becomes slow. Filtering exists, but sharding is not explicitly designed.
- Hung tests are a real risk once you add UI timing, event waits, or entity lifecycle edge cases.

### Revision
- Add **deterministic sharding**: `--shard-count`, `--shard-index` (hash by `test_id`).
- Enforce default timeouts (`timeout_frames` or `timeout_ms`) for every test.

### Why this makes the project better
- **CI gets faster** by parallelizing runs across workers.
- **No “infinite loop” stalls**: timeouts turn hangs into actionable failures.
- **Deterministic**: the same test always lands in the same shard.

### Tradeoffs
- Requires a small amount of “runner CLI” surface area (even if it’s just a Lua config table).

### Git diff vs v1 plan
```diff
diff --git a/Cass_Memory_Update_Plan.md b/Cass_Memory_Update_Plan.md
--- a/Cass_Memory_Update_Plan.md
+++ b/Cass_Memory_Update_Plan.md
@@
 > **Harness API specifics (so it is actually implementable):**
 > - `register(name, category, testFn, opts)` where `opts` may include `tags`, `source_ref`, and `timeout_frames` (if frame-driven).
 > - `run(filter)` where `filter` supports:
 >   - `category` exact match OR list
 >   - `name_substr` match
 >   - `tags_any` / `tags_all` (optional but recommended)
+>   - **(New)** `shard_count` / `shard_index` (optional): deterministically shard by `test_id` hash
+> - **Timeout requirement:** Every test must have a timeout (default `timeout_frames = 600` unless overridden).
@@
 > **Phase 1 implementation checklist (specificity):**
@@
 > - Decide how failures are surfaced:
 >   - report + `TEST_FAIL:` marker lines, plus a final pass/fail marker.
+> - **(New)** Decide and document sharding inputs:
+>   - how to pass `--shard-count` and `--shard-index` into Lua runner (CLI args / config file / env vars)
@@
 > **CI-friendly specifics (so it is actually implementable):**
 > - The runner must return/emit a clear pass/fail signal:
@@
 > - Coverage report must include:
@@
+> **(New) CI scaling recommendation:**
+> - Add CI jobs that run shards in parallel (e.g., 4 shards):
+>   - shard 0: `--shard-count 4 --shard-index 0`
+>   - shard 1: `--shard-count 4 --shard-index 1`
+>   - ...
+> - Merge `results.json` from shards for a unified coverage report (or generate per-shard coverage with a final aggregation step).
```

---

# Change 05 — Visual testing: per-platform baselines + diff artifacts + tolerance config + quarantine

### What’s weak in v1
- Baselines are mentioned but the lifecycle is still fuzzy:
  - where baselines live when multiple platforms/renderers exist
  - what to do on mismatch (you need a diff image + metric, otherwise debugging is painful)
- Without a quarantine mechanism, the likely “future outcome” is disabling visual tests entirely once they flake on a teammate’s GPU.

### Revision
- Standardize baseline layout:
  - `test_baselines/screenshots/<platform>/<renderer>/<safe_test_id>.png`
- Add a tolerance config:
  - `test_baselines/visual_tolerances.json` (per test or per category)
- On mismatch, emit diff artifacts:
  - `test_output/artifacts/<safe_test_id>/baseline.png`
  - `test_output/artifacts/<safe_test_id>/actual.png`
  - `test_output/artifacts/<safe_test_id>/diff.png`
  - plus a numeric metric in `results.json`
- Add quarantine file for visual flakes:
  - `test_baselines/visual_quarantine.json` with reasons + issue links
  - Quarantined visual tests run and report, but do **not** fail PR CI (still fail on scheduled “full verification” runs).

### Why this makes the project better
- **Debuggability**: baseline diffs reduce “works on my machine” debates.
- **Reality-proof**: per-platform storage avoids false failures due to rasterization differences.
- **You keep signal**: quarantine keeps coverage visible without making PR CI unusable.

### Tradeoffs
- Slightly more structure and files in the repo.
- You must set policy: who can quarantine, how long quarantine lasts, how to unquarantine (recommendation below).

### Git diff vs v1 plan
```diff
diff --git a/Cass_Memory_Update_Plan.md b/Cass_Memory_Update_Plan.md
--- a/Cass_Memory_Update_Plan.md
+++ b/Cass_Memory_Update_Plan.md
@@
 > **Stronger Visual Verified (recommended):**
-> - If a baseline exists at `test_baselines/screenshots/<safe_test_id>.png` (or per-platform subfolder),
->   the harness must compare and mark the test failed on mismatch (with tolerance).
+> - If a baseline exists at `test_baselines/screenshots/<platform>/<renderer>/<safe_test_id>.png`,
+>   the harness must compare and mark the test failed on mismatch (with tolerance).
@@
 > **Baseline management (new):**
 > - Add a harness flag `--record-baselines` (manual only) to write/update baseline images.
 > - CI must never run in record mode.
+> - **(New)** Store tolerance config in `test_baselines/visual_tolerances.json`:
+>   - default tolerance (pixel diff / SSIM threshold)
+>   - optional per-test overrides for known nondeterminism.
+> - **(New)** On mismatch, write diff artifacts to `test_output/artifacts/<safe_test_id>/` (baseline/actual/diff + metrics).
+> - **(New, recommended)** Maintain `test_baselines/visual_quarantine.json`:
+>   - quarantined tests run but do not fail PR CI; they still fail scheduled full runs.
@@
 > **Report/status schema requirement (testability + CI-friendliness):**
@@
 > - `test_output/report.md` must include:
@@
 >     - `test_output/artifacts/<safe_test_id>/`
+> - **(New)** For visual failures, report must link to diff artifacts (baseline/actual/diff) and include the tolerance used.
```

Recommended quarantine policy (add this in the plan text near Phase 7 or Maintenance Mode):

- Quarantine entries require:
  - a reason,
  - an owner,
  - and an issue/task link.
- Quarantine expires after N days unless renewed (forces cleanup).

---

# Change 06 — Automate Sol2 binding extraction (Tier 0) to reduce manual labor and drift

### What’s weak in v1
- Manually enumerating 390+ bindings is doable but:
  - it’s slow,
  - it’s error-prone,
  - and it tends to drift after the first big pass.
- “Maintenance Mode” wants to regenerate inventories, but v1 does not define how they’re generated (manual vs scripted).

### Revision
- Add a binding inventory extractor script:
  - `scripts/extract_sol2_bindings.py` (or `.lua` if you prefer)
- The extractor produces Tier 0 output for `planning/inventory/bindings.*.json`:
  - lua_name, type, source_ref, inferred signature (best effort), plus an “extraction_confidence” field.
- Humans then add Tier 1/2 semantics in docs, but the inventory baseline stays accurate and cheap to update.

### Why this makes the project better
- **Order-of-magnitude faster** to keep inventories current.
- **Better correctness** on boring data (names, source locations).
- **More robust maintenance**: changes to binding files automatically surface as inventory diffs in PRs.

### Tradeoffs
- Extraction won’t be perfect (dynamic table assignments, computed names). That’s fine:
  - mark those as `extraction_confidence: low` and require manual review.

### Git diff vs v1 plan
```diff
diff --git a/Cass_Memory_Update_Plan.md b/Cass_Memory_Update_Plan.md
--- a/Cass_Memory_Update_Plan.md
+++ b/Cass_Memory_Update_Plan.md
@@
 ### Phase 2: Sol2 Binding Inventory
@@
 **Deliverables per agent:**
 1. Binding list: `planning/bindings/{system}_bindings.md`
 2. Test file: `assets/scripts/test/test_{system}_bindings.lua`
 3. cm rules for high-frequency bindings
 4. **(New)** Machine-readable binding inventory: `planning/inventory/bindings.{system}.json`
+5. **(New, recommended)** Automated extractor: `scripts/extract_sol2_bindings.py` (single-owner, used by all agents)
@@
 **Binding extraction requirements (specific + repeatable):**
-- For each source C++ file listed, enumerate:
-  - usertypes (types), methods, properties, constants, and free functions.
+**Automation-first rule (reduce drift):**
+- First, run `scripts/extract_sol2_bindings.py` to generate/update `planning/inventory/bindings.{system}.json`.
+- Then, humans validate and enrich the output (Tier 1/2 docs + tests).
+- Any binding not captured by the extractor must be documented under **“Extractor gaps”** with `source_ref` so the script can be improved later.
@@
 **Machine-readable inventory schema (new):**
@@
   "bindings": [
     {
       "lua_name": "physics.segment_query",
       "type": "function",
       "signature": "physics.segment_query(world, start_point, end_point, callback)",
       "doc_id": "binding:physics.segment_query",
       "source_ref": "src/systems/physics/physics_lua_bindings.cpp:segment_query",
+      "extraction_confidence": "high",  // high | medium | low
       "frequency": {
@@
       "tier": 2,
       "verified": true,
       "test_id": "physics.segment_query.hit_entity"
     }
   ]
 }
```

---

# Change 07 — Automate ECS component extraction (Tier 0) + generate the matrix skeleton

### What’s weak in v1
- Component docs are large and easy to get subtly wrong (field lists and types drift).
- The accessibility matrix is manual; it will drift unless derived from a single source.

### Revision
- Add `scripts/extract_components.py` that:
  - parses the component definitions file(s) (regex or clang-based)
  - produces `planning/inventory/components.*.json`
  - optionally emits a **matrix skeleton** (markdown) listing all components discovered, ready for agents to fill Lua accessibility.

### Why this makes the project better
- Completeness becomes cheap to verify.
- Drift becomes obvious: changes in `components.hpp` immediately change the extracted inventory in PRs.

### Tradeoffs
- Type extraction might be imperfect. That’s OK; treat extraction as Tier 0 baseline and let humans refine.

### Git diff vs v1 plan
```diff
diff --git a/Cass_Memory_Update_Plan.md b/Cass_Memory_Update_Plan.md
--- a/Cass_Memory_Update_Plan.md
+++ b/Cass_Memory_Update_Plan.md
@@
 ### Phase 3: ECS Component Documentation
@@
 **Deliverables:**
 1. Component reference: `planning/components/{category}_components.md`
 2. Lua accessibility matrix (which components can be accessed from Lua)
 3. cm rules for component access patterns
 4. **(New)** Machine-readable component inventory: `planning/inventory/components.{category}.json`
+5. **(New, recommended)** Automated extractor: `scripts/extract_components.py` (single-owner) that generates Tier 0 component lists and a matrix skeleton.
@@
 **Lua accessibility matrix requirements (testable + explicit):**
 - For each component:
   - Mark `Lua Access: Yes/No/Partial`.
@@
 > **Matrix artifact specificity (implementability):**
 > - The "Lua accessibility matrix" must have a concrete file destination. Default recommendation:
 >   - `planning/components/lua_accessibility_matrix.md`
+> - **(New)** Generate the initial `lua_accessibility_matrix.md` skeleton from the extractor so it always lists all discovered components.
```

---

# Change 08 — Auto-generate scope stats to eliminate stale tables and inconsistent counts

### What’s weak in v1
- The plan includes multiple count tables (Scope, Acceptance Criteria, Appendix), and they already don’t fully match (Lua script counts).
- v1 introduces reconciliation rules, but that still relies on humans to update several places correctly.

### Revision
- Add a stats generator script:
  - `scripts/recount_scope_stats.py`
- Output:
  - `planning/inventory/stats.json`
  - `planning/stats.md`
- Replace in-plan numeric tables with:
  - “Generated from `planning/inventory/stats.json` on <date>”
  - and keep the Appendix as a *snapshot* or remove it entirely to avoid duplication.

### Why this makes the project better
- **Truthfulness**: counts don’t drift.
- **Less busywork**: no one has to remember to update three tables in sync.
- **Better CI drift detection**: if stats change, CI can require a doc update.

### Tradeoffs
- You lose “static plan numbers” inside the plan, but you gain correctness.

### Git diff vs v1 plan
```diff
diff --git a/Cass_Memory_Update_Plan.md b/Cass_Memory_Update_Plan.md
--- a/Cass_Memory_Update_Plan.md
+++ b/Cass_Memory_Update_Plan.md
@@
 ### Scope
-| Category | Count | Status |
-|----------|-------|--------|
-| Sol2 Bindings | ~58 types, ~390 functions | To document |
-| ECS Components | ~128 components | To document |
-| Lua Scripts | ~280 files | To mine for patterns |
-| Existing Docs | 30+ markdown files | To verify/update |
+| Category | Count | Status |
+|----------|-------|--------|
+| Sol2 Bindings | **Generated** (see `planning/inventory/stats.json`) | To document |
+| ECS Components | **Generated** (see `planning/inventory/stats.json`) | To document |
+| Lua Scripts | **Generated** (see `planning/inventory/stats.json`) | To mine for patterns |
+| Existing Docs | **Generated** (see `planning/inventory/stats.json`) | To verify/update |
@@
 > **Scope validation requirement (for completeness + truthfulness):** The counts above are *estimates* and must be validated during Phase 2/3 inventory passes.
+>
+> **(New) Automation requirement (stop stale counts):**
+> - Add `scripts/recount_scope_stats.py` that writes:
+>   - `planning/inventory/stats.json` (machine-readable)
+>   - `planning/stats.md` (human summary)
+> - CI should fail if `stats.json` changes but the derived docs (inventories/stubs/index) are not regenerated.
@@
 ## Appendix: Codebase Statistics
-### Sol2 Bindings by File
+### Codebase Statistics (generated snapshot)
+These figures must be treated as *generated output* from `scripts/recount_scope_stats.py` to prevent drift.
```

---

# Change 09 — Add a one-command “check all” workflow (make hygiene cheap)

### What’s weak in v1
- v1 defines many moving pieces:
  - inventories, stubs, validator, tests, cm rules importer
- Without a single “do the right thing” command, people will run subsets and drift will creep in.

### Revision
- Add `scripts/check_all.(sh|ps1)` (or `justfile`/`Makefile`) that runs:
  1. regenerate inventories
  2. regenerate stubs
  3. run validator(s)
  4. run tests (optionally shard-aware)
  5. validate schemas
  6. regenerate index docs
- Optionally add pre-commit hook to call a subset (fast checks only).

### Why this makes the project better
- **Human behavior**: people do the easy thing. Make the correct process easy.
- **Less CI churn**: fewer “why did CI fail?” because local checks match CI checks.

### Tradeoffs
- Some cross-platform scripting work (sh + ps1). Keep it minimal.

### Git diff vs v1 plan
```diff
diff --git a/Cass_Memory_Update_Plan.md b/Cass_Memory_Update_Plan.md
--- a/Cass_Memory_Update_Plan.md
+++ b/Cass_Memory_Update_Plan.md
@@
 ### Phase 7: Test Suite Finalization
@@
 **Deliverables:**
@@
 5. **(New)** Generated EmmyLua stubs: `docs/lua_stubs/` (generated, not hand-edited)
+6. **(New)** One-command developer workflow:
+   - `scripts/check_all.(sh|ps1)` that regenerates inventories/stubs, runs validators, runs tests, and validates schemas.
@@
 ## Maintenance Mode (new, post-Phase 8)
@@
 ### CI enforcement:
 - CI should fail if inventories changed but:
   - docs were not updated, or
   - registry mappings are missing for previously verified doc_ids.
+  
+### Developer workflow enforcement (new):
+- Recommend running `scripts/check_all` before opening a PR.
+- Optional: install a pre-commit hook that runs a **fast subset** (validators + schema checks, no visual tests).
```

---

# Change 10 — Strengthen cm rule governance: richer schema + idempotent importer + dedupe

### What’s weak in v1
- `cm_rules_candidates.yaml` is a good start but:
  - `rule_id` isn’t guaranteed unique (no enforcement described)
  - importer behavior isn’t specified (add vs update vs skip)
  - rule text can duplicate across categories and slowly clutter cm.

### Revision
- Expand schema to support:
  - unique `rule_id` (enforced)
  - `severity` (info/warn/error)
  - `tags`
  - `rationale` (short, human explanation)
  - `example_good` / `example_bad` (optional)
  - `last_verified_commit` (helps decide if rule needs re-verification)
- Importer becomes **idempotent**:
  - same `rule_id` updates existing rule (or replaces it deterministically)
  - avoids duplicates by hashing normalized rule_text + category
- Export becomes reproducible from YAML too (cm export remains useful but not the only source).

### Why this makes the project better
- **No playbook clutter**: duplicates are eliminated at the source.
- **Traceability improves**: you know which commit last verified the rule’s test.
- **Long-term maintenance**: rules become manageable as the project grows.

### Tradeoffs
- Slightly larger YAML file, but it’s still the best place for this metadata.

### Git diff vs v1 plan
```diff
diff --git a/Cass_Memory_Update_Plan.md b/Cass_Memory_Update_Plan.md
--- a/Cass_Memory_Update_Plan.md
+++ b/Cass_Memory_Update_Plan.md
@@
 > **Declarative rules file schema (new):**
 ```yaml
 # planning/cm_rules_candidates.yaml
 rules:
   - rule_id: "ui-gotcha-001"
     category: "ui-gotchas"
     rule_text: "When using ChildBuilder.setOffset on UIBox containers, always call ui.box.RenewAlignment(registry, container) afterward to force child layout update"
     doc_id: "pattern:ui.uibox_alignment.renew_after_offset"
     test_ref: "test_ui_patterns.lua::ui.uibox_alignment.renew_after_offset"
     quirks_anchor: "uibox-alignment"
-    status: "verified"  # verified | unverified | pending
+    status: "verified"  # verified | unverified | pending
+    severity: "error"   # info | warn | error
+    tags: ["ui", "layout", "ordering"]
+    rationale: "UIBox does not recompute child layout after offset changes unless RenewAlignment is called."
+    example_good: |
+      ChildBuilder.setOffset(...)
+      ui.box.RenewAlignment(registry, container)
+    example_bad: |
+      ChildBuilder.setOffset(...) -- missing RenewAlignment, children remain stale
+    last_verified_commit: "<git_sha>"
@@
 > **(New)** Deterministic importer script: `scripts/import_cm_rules.(py|lua)`
+> - **Idempotency requirement:** importer must treat `rule_id` as the primary key:
+>   - if rule exists, update/replace deterministically
+>   - if rule does not exist, add
+> - **Dedupe requirement:** importer must prevent duplicates by normalized (category + rule_text) fingerprint.
+> - **Safety requirement:** importer must import only `status: verified` rules (same as v1), but may optionally emit a report listing pending/unverified rules.
```

---

# Change 11 — Lua developer experience: integrate stubs into LSP, document regen, and enforce in CI

### What’s weak in v1
- “Generate EmmyLua stubs” is great, but adoption depends on:
  - a Lua language server config pointing at `docs/lua_stubs/`
  - regen docs so developers know how to update stubs
  - CI enforcement so stubs don’t drift silently

### Revision
- Add `.luarc.json` (or project LSP config) that includes:
  - `docs/lua_stubs/` in workspace library
- Add `docs/lua_stubs/README.md` describing regeneration command.
- Enforce stub regen + diff check in CI.

### Why this makes the project better
- **Stubs become used**, not just generated.
- **Autocomplete and signature help** reduces mistakes and speeds up dev.
- **Drift detection** keeps IDE hints accurate.

### Tradeoffs
- Minor config maintenance. Worth it.

### Git diff vs v1 plan
```diff
diff --git a/Cass_Memory_Update_Plan.md b/Cass_Memory_Update_Plan.md
--- a/Cass_Memory_Update_Plan.md
+++ b/Cass_Memory_Update_Plan.md
@@
 ## Executive Summary
@@
 **New developer-facing output (high leverage):**
 - Generate IDE stubs (EmmyLua) for Lua-facing API from the binding inventory so humans get autocomplete and signatures.
+ - **(New)** Ship Lua language-server config pointing at generated stubs so the stubs are actually used (`.luarc.json` or repo-equivalent).
@@
 ### Phase 7: Test Suite Finalization
@@
 **Deliverables:**
@@
 5. **(New)** Generated EmmyLua stubs: `docs/lua_stubs/` (generated, not hand-edited)
+6. **(New)** Lua LSP configuration file (recommended):
+   - `.luarc.json` (or repo standard) referencing `docs/lua_stubs/`
+7. **(New)** `docs/lua_stubs/README.md` documenting stub regeneration and expected CI behavior
@@
 > **EmmyLua stub generation (new):**
@@
 > - Even partial stubs are valuable; CI should regenerate stubs and fail if they differ from committed version (drift detection).
+> - **(New)** CI should also validate `.luarc.json` (or equivalent) continues to reference the stub path so developer tooling remains functional.
```

---

# Change 12 — Make docs easy to find + enforce link integrity (prevent “knowledge rot”)

### What’s weak in v1
- You will end up with many docs:
  - `planning/bindings/*.md`
  - `planning/components/*.md`
  - `planning/patterns/*.md`
  - `docs/quirks.md`
- Without a *generated* index and link checker, people won’t find the right doc, and anchors/test references will drift.

### Revision
- Add a generated “reference index”:
  - `docs/reference/index.md` (or `planning/api_reference.md`) that links to everything and groups by system.
- Add link integrity checks:
  - `scripts/link_check_docs.py` (or `.lua`)
  - checks:
    - `doc_id` uniqueness
    - `Test:` references point to real tests
    - `quirks_anchor` exists
    - markdown links resolve within repo

### Why this makes the project better
- **Compelling/useful**: developers can actually navigate the knowledge base.
- **Trustworthiness**: links are correct; evidence references are real.
- **Cheaper maintenance**: CI catches broken anchors before merge.

### Tradeoffs
- Slight build-time overhead; trivial compared to the value.

### Git diff vs v1 plan
```diff
diff --git a/Cass_Memory_Update_Plan.md b/Cass_Memory_Update_Plan.md
--- a/Cass_Memory_Update_Plan.md
+++ b/Cass_Memory_Update_Plan.md
@@
 > **API reference deliverable clarification (completeness + implementability):**
@@
 > as the "API Reference" output. Optionally add `planning/api_reference.md` as a stable index linking to those files.
+>
+> **(New) Discoverability requirement (make docs usable):**
+> - Add a generated index file:
+>   - `docs/reference/index.md` (preferred if docs are user-facing) OR `planning/api_reference.md` (if planning area is preferred)
+> - Index must group by system and include links to:
+>   - bindings docs, component docs, pattern docs, quirks sections, and stubs.
@@
 ### Phase 7: Test Suite Finalization
@@
 **Deliverables:**
@@
 4. **(New)** `scripts/validate_docs_and_registry.lua` (or `.py`) and a documented invocation
 5. **(New)** Generated EmmyLua stubs: `docs/lua_stubs/` (generated, not hand-edited)
+6. **(New)** `scripts/link_check_docs.(py|lua)` that validates:
+   - no duplicate `doc_id` in docs,
+   - all `Test:` references exist in the harness registration,
+   - all `quirks_anchor` targets exist in `docs/quirks.md`,
+   - and no broken intra-repo markdown links.
+7. **(New)** Generated reference index: `docs/reference/index.md` (or `planning/api_reference.md`)
```

---

## Optional “v2 polish” add-ons (if you want even more robustness)

These are not strictly necessary, but are high leverage if you want the system to age well:

1. **“Fast PR vs Full Verification” CI split**
   - PR CI runs: non-visual + no slow tests + validators.
   - Nightly runs: visual + slow + full suite.

2. **Quirk scope metadata**
   - Add `Applies to:` fields with engine version / commit ranges, so outdated quirks get pruned.

3. **Binding deprecations**
   - Add `deprecated: true` and `replacement: ...` in inventories; stubs can mark `---@deprecated`.

If you want these, they fit naturally into the earlier changes (schemas + index + stubs + maintenance).

---

## Implementation order (recommendation)

These changes are designed to be additive. A practical order:

1. **Change 01 + 02** in Phase 1 (naming, TEST_ROOT, capabilities)
2. **Change 03 + 04** in Phase 1/7 (schemas, junit, sharding, timeouts)
3. **Change 05** once screenshots work
4. **Change 06 + 07 + 08** before large-scale documentation authoring (automation pays immediately)
5. **Change 09 + 12** to keep the repo healthy as files multiply
6. **Change 10 + 11** in Phase 7/8 once pipelines exist

---

## What you get if you apply all 12 changes

A project where:
- inventories are **cheap to regenerate**, and drift is caught immediately
- tests are **portable** (SKIP with reason), **scalable** (shards), and **CI-friendly** (JUnit)
- visual verification is **debuggable** (diff artifacts) instead of frustrating
- docs are **discoverable** and **trustworthy** (index + link checks)
- cm rules are **governed** and **traceable** (idempotent importer + metadata)
- dev UX is **meaningfully improved** (stubs + LSP config used by default)
