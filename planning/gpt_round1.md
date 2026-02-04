# Cass Memory Update Plan v1 — Review, Revisions, and Patchset

This is a **hard-nosed review** of your v0 plan plus a set of revisions that make it **more maintainable**, **less fragile**, **more CI-friendly**, and **more compelling** as an evergreen “docs + tests + memory” system.

The v0 plan is already unusually strong: it’s explicit about determinism, it defines “Verified” precisely, and it protects parallel work with ownership rules. The biggest remaining problems aren’t “missing bullets” — they’re **long-term correctness and drift**:

- **Drift risk**: docs, test registry, and cm rules can diverge because they are updated manually in different phases by different people.
- **Verification weakness for visuals**: “screenshot exists” doesn’t prove correctness (it proves only that you took a screenshot).
- **Harness isolation**: without explicit world/reset boundaries, tests will become order-dependent and flaky.
- **Reproducibility gaps**: frequency counting and binding/component inventory are manual, which is where silent errors creep in.
- **Maintenance story**: the plan is great for “one big push,” but it doesn’t fully define how it stays correct when the codebase evolves.

Below are targeted changes that address those issues while staying within your stated non-goals (no gameplay refactors, only test hooks/helpers).

---

## Change 1 — Make docs/registry consistency enforceable (add a validator + fail the build)

### What’s wrong in v0
You correctly designate `assets/scripts/test/test_registry.lua` as the source of truth for coverage mapping — but you also require every doc section to include `doc_id` and `Verified/Test:` references. That means there are **two places** where truth can diverge:
- docs say something is Verified, but registry doesn’t map it (or maps a different test),
- registry maps a doc_id that no longer exists or has been renamed,
- duplicated `doc_id` across docs (easy to do in parallel).

This is the single highest risk to long-term reliability.

### Revision
Add a small **validator** that runs in Phase 7 (and in CI) to enforce invariants:
- every `doc_id` referenced in docs exists exactly once,
- every `Verified: Test: <file>::<test_id>` exists in the harness registration list (or executed list),
- registry entries reference existing docs OR are explicitly marked “orphaned” (temporary allowed state),
- no doc section claims Verified without a registry mapping to a passing test id.

### Why this makes the project better
- Eliminates “confidence theater” (docs claiming Verified when it’s not actually backed by the suite).
- Converts drift from a silent failure mode into an immediate, fixable CI failure.
- Reduces consolidation workload and review burden in Phase 6–8.

### Trade-offs
- Requires a little up-front scripting. But it’s a one-time cost that pays forever.

### Git-diff patch (plan change)
```diff
diff --git a/planning/cass_memory_update_plan_v0.md b/planning/cass_memory_update_plan_v1.md
--- a/planning/cass_memory_update_plan_v0.md
+++ b/planning/cass_memory_update_plan_v1.md
@@
 ### Phase 7: Test Suite Finalization
@@
 **Tasks:**
@@
 6. **Deterministic module loading (implementability):** if filesystem globbing is unavailable in Lua, add a single maintained module list (e.g., `assets/scripts/test/test_modules.lua`) that enumerates all `test_*.lua` modules in deterministic order for `run_all_tests.lua` to require.
+7. **Consistency validation (new, required):** add a validator that fails the run if docs/registry/tests drift:
+   - duplicate `doc_id` in docs,
+   - `Verified:` in docs without matching `test_registry.lua` entry,
+   - registry entry pointing at non-existent docs,
+   - registry `test_id` that was not registered by the harness.
@@
 **Deliverables:**
 1. `assets/scripts/test/run_all_tests.lua`
 2. `test_output/coverage_report.md`
 3. CI-friendly test script (exit codes)
+4. `scripts/validate_docs_and_registry.lua` (or `.py`) and a documented invocation
@@
 **Acceptance Criteria:**
@@
 - [ ] `assets/scripts/test/test_registry.lua` is the single source of truth for doc→test mapping and is updated without concurrent edits
+- [ ] The validator passes (docs/test_registry/tests consistent) and runs in CI
```

---

## Change 2 — Add a **machine-readable inventory** (bindings/components/patterns) and treat markdown as a view

### What’s wrong in v0
Your plan depends on humans extracting hundreds of bindings/components and manually maintaining “counts,” “frequency,” and “tier.” Markdown-only inventories become hard to diff and easy to partially update.

### Revision
Introduce a **JSON (or YAML) inventory artifact** per domain:
- Bindings: `planning/inventory/bindings.{system}.json`
- Components: `planning/inventory/components.{category}.json`
- Patterns: `planning/inventory/patterns.{area}.json`

Markdown docs remain the human-facing output, but JSON becomes the **diffable, toolable source** for:
- generating summary tables,
- validating uniqueness of names/doc_ids,
- generating EmmyLua stubs (see Change 3),
- snapshot-diffing between commits (see Change 10).

### Why this makes the project better
- You can diff inventories between commits and immediately see what changed.
- Consolidation becomes safer (scripts can merge and validate).
- Enables automation without requiring you to reformat all docs.

### Trade-offs
- Slight increase in deliverables and scripting.

### Git-diff patch
```diff
diff --git a/planning/cass_memory_update_plan_v0.md b/planning/cass_memory_update_plan_v1.md
--- a/planning/cass_memory_update_plan_v0.md
+++ b/planning/cass_memory_update_plan_v1.md
@@
 ### Phase 2: Sol2 Binding Inventory
@@
 **Deliverables per agent:**
 1. Binding list: `planning/bindings/{system}_bindings.md`
 2. Test file: `assets/scripts/test/test_{system}_bindings.lua`
 3. cm rules for high-frequency bindings
+4. **(New)** Machine-readable binding inventory: `planning/inventory/bindings.{system}.json`
@@
 ### Phase 3: ECS Component Documentation
@@
 **Deliverables:**
 1. Component reference: `planning/components/{category}_components.md`
 2. Lua accessibility matrix (which components can be accessed from Lua)
 3. cm rules for component access patterns
+4. **(New)** Machine-readable component inventory: `planning/inventory/components.{category}.json`
@@
 ### Phase 5: Pattern Mining from Working Code
@@
 **Deliverables:**
 1. Pattern catalog: `planning/patterns/{area}_patterns.md`
 2. cm rules for each verified pattern
 3. Updates to existing docs where code diverges
+4. **(New)** Machine-readable pattern inventory: `planning/inventory/patterns.{area}.json`
```

---

## Change 3 — Generate **EmmyLua/IDE stubs** from the binding inventory

### What’s wrong in v0
Your outputs help agents, but developers still lack IDE autocomplete / type hints. That keeps Lua-side work slower than it needs to be and increases misuse of bindings.

### Revision
Add a generated artifact:
- `docs/lua_stubs/` (or `tools/lua_stubs/`) containing **EmmyLua annotations** (`---@class`, `---@param`, `---@return`) for the Lua-exposed API.

Generate it from the machine-readable binding inventory (Change 2). Even partial stubs are valuable.

### Why this makes the project better
- Makes the project more compelling for humans (not just cm agents).
- Reduces bug rate (wrong param order/types become obvious).
- Encourages adoption: autocomplete is addictive.

### Trade-offs
- Stubs can get stale if not CI-gated (Change 10 solves this).

### Git-diff patch
```diff
diff --git a/planning/cass_memory_update_plan_v0.md b/planning/cass_memory_update_plan_v1.md
--- a/planning/cass_memory_update_plan_v0.md
+++ b/planning/cass_memory_update_plan_v1.md
@@
 ## Executive Summary
@@
 Extract, verify, and document all Lua/C++ bindings, patterns, and quirks from TheGameJamTemplate into the `cm` (procedural memory) system. This creates a searchable knowledge base that reduces agent errors and accelerates development.
+
+**New developer-facing output (high leverage):**
+- Generate IDE stubs (EmmyLua) for Lua-facing API from the binding inventory so humans get autocomplete and signatures.
@@
 ### Phase 7: Test Suite Finalization
@@
 **Deliverables:**
@@
 3. CI-friendly test script (exit codes)
+4. **(New)** Generated EmmyLua stubs: `docs/lua_stubs/` (generated, not hand-edited)
```

---

## Change 4 — Make test execution order-independent (add reset/isolation semantics)

### What’s wrong in v0
The harness spec focuses on reporting and determinism, but it does not define **isolation**. In real engine contexts, tests will accidentally:
- leave entities/components behind,
- alter global tables/singletons,
- mutate UI registries,
- “poison” later tests.

That creates flakiness and makes failures non-local.

### Revision
Add explicit harness hooks and a required isolation policy:
- `TestRunner:before_each(test)` and `TestRunner:after_each(test)`
- A mandatory `test_utils.reset_world()` or `test_utils.reset_scene()` contract (even if it is “reload test scene”)
- A default rule: tests must be runnable in any order (except those tagged `serial`)

### Why this makes the project better
- Eliminates order-dependent bugs, which are the worst kind of test failures.
- Makes parallel execution and future sharding possible.

### Trade-offs
- You may need a minimal engine helper to reset the test world. If not possible, the fallback is “restart engine per category,” which is slower but deterministic.

### Git-diff patch
```diff
diff --git a/planning/cass_memory_update_plan_v0.md b/planning/cass_memory_update_plan_v1.md
--- a/planning/cass_memory_update_plan_v0.md
+++ b/planning/cass_memory_update_plan_v1.md
@@
 ### Phase 1: Test Infrastructure Setup
@@
 **Required behavior details (for specificity + CI-friendliness):**
@@
 - **Error handling requirement (testability):**
@@
 - Wrap each test function in `pcall` (or equivalent) so one crash produces a single test failure with stack trace captured in the report.
 - Normalize failures to include: `test_id`, `error_message`, and `stack_trace` (if available).
+
+> **Isolation requirement (new, critical for reliability):**
+> - Tests must be order-independent by default.
+> - The harness must support `before_each` / `after_each` hooks and call them around every test.
+> - Provide a `test_utils.reset_world()` (or `reset_scene()`) contract:
+>   - clears spawned test entities,
+>   - resets global registries used by UI/physics where feasible,
+>   - resets RNG seed(s),
+>   - and returns to a known camera/UI root state.
+> - If full reset is impossible, require `tags = {"serial"}` and run those tests in a dedicated engine session or in a fixed order.
```

---

## Change 5 — Upgrade reporting: add per-test JSON results + run metadata

### What’s wrong in v0
`status.json` + `report.md` are good starts, but you will eventually want:
- per-test duration,
- per-test artifacts (screenshots, logs),
- run metadata (commit SHA, branch, engine build),
- a stable machine-readable failure list for CI.

### Revision
Add:
- `test_output/results.json` (array of per-test results)
- Extend `status.json` to include:
  - `commit`, `branch`, `platform`, `engine_version`, `duration_ms`
- Define artifact layout:
  - `test_output/artifacts/<safe_test_id>/...`

### Why this makes the project better
- Faster debugging (jump straight to failing test artifact folder).
- Enables future dashboards/trend tracking.
- Makes CI integration painless.

### Trade-offs
- Slightly more file I/O.

### Git-diff patch
```diff
diff --git a/planning/cass_memory_update_plan_v0.md b/planning/cass_memory_update_plan_v1.md
--- a/planning/cass_memory_update_plan_v0.md
+++ b/planning/cass_memory_update_plan_v1.md
@@
 > **Report/status schema requirement (testability + CI-friendliness):**
 > - `test_output/status.json` must be machine-readable and stable. Minimum schema:
 >   - `{"passed": true/false, "failed": <int>, "passed_count": <int>, "total": <int>, "generated_at": "<iso8601>" }`
+> - **(New, recommended)** Extend schema for traceability:
+>   - `commit` (git SHA if available), `branch`, `platform`, `engine_version`, `duration_ms`
+> - **(New, required)** Write `test_output/results.json` with per-test objects:
+>   - `{"test_id": "...", "test_file": "...", "category": "...", "status":"pass|fail|skip", "duration_ms":123, "artifacts":[...], "error":{...}}`
@@
 > **Screenshots**
@@
 - **Screenshot list with exact file paths.**
+ - **Screenshot list with exact file paths** and (if present) links to per-test artifact folders:
+   - `test_output/artifacts/<safe_test_id>/`
```

---

## Change 6 — Make “Visual Verified” actually mean something (optional screenshot diff)

### What’s wrong in v0
A screenshot existing is weak verification. It proves the code ran and captured an image, not that the UI/layout is correct.

### Revision
Introduce an optional-but-strong “golden” baseline mode:
- Store baselines under `test_baselines/screenshots/<platform>/...` (or a single folder if you only support one platform).
- Add a pixel diff tool (even a simple threshold-based comparator).
- The harness can run in:
  - **record mode**: writes new baselines (gated to manual runs)
  - **compare mode**: compares output to baselines (CI default for `visual` tests)

If baseline diff is too heavy right now, you can keep it as “Phase 9” — but the plan should at least reserve space and structure so you don’t have to reorganize later.

### Why this makes the project better
- Prevents regressions in the exact area you care about most (UI gotchas).
- Makes screenshots actionable evidence, not just decorative artifacts.

### Trade-offs
- Cross-platform rendering differences may require tolerance or platform-specific baselines.
- Increases repo size if many baselines are committed (mitigate by limiting to high-value tests).

### Git-diff patch
```diff
diff --git a/planning/cass_memory_update_plan_v0.md b/planning/cass_memory_update_plan_v1.md
--- a/planning/cass_memory_update_plan_v0.md
+++ b/planning/cass_memory_update_plan_v1.md
@@
 > **Visual Verified** requires: non-visual requirements **plus** a screenshot file exists at `test_output/screenshots/<safe_test_id>.png` and is referenced in the report (image comparison is optional unless later added).
+> **Stronger Visual Verified (recommended):**
+> - If a baseline exists at `test_baselines/screenshots/<safe_test_id>.png` (or per-platform subfolder),
+>   the harness must compare and mark the test failed on mismatch (with tolerance).
+> - If no baseline exists, mark the test `PASS (no baseline)` but flag it in the report as **NeedsBaseline**.
+
+> **Baseline management (new):**
+> - Add a harness flag `--record-baselines` (manual only) to write/update baseline images.
+> - CI must never run in record mode.
```

---

## Change 7 — Standardize artifact layout per test (screenshots, logs, dumps)

### What’s wrong in v0
Everything goes into `test_output/` and a shared screenshots folder. As the suite grows, you’ll want per-test logs (especially for flaky or lifecycle bugs).

### Revision
Adopt:
- `test_output/artifacts/<safe_test_id>/`
  - `screenshot.png`
  - `log.txt`
  - `dump.json` (optional engine state snapshot)
  - `stacktrace.txt` (on fail)

Keep the existing `test_output/screenshots/` only as a convenience index (symlink/copy).

### Why this makes the project better
- Reviewing failures becomes fast and reliable.
- You can attach the entire artifacts folder to CI logs.

### Trade-offs
- More files, but they’re all under ignored `test_output/` anyway.

### Git-diff patch
```diff
diff --git a/planning/cass_memory_update_plan_v0.md b/planning/cass_memory_update_plan_v1.md
--- a/planning/cass_memory_update_plan_v0.md
+++ b/planning/cass_memory_update_plan_v1.md
@@
 **Deliverables:**
@@
 4. Screenshot output directory: `test_output/screenshots/`
+4b. **(New)** Per-test artifacts directory: `test_output/artifacts/<safe_test_id>/`
@@
 > **Evidence storage clarity (implementability):**
 > - If screenshots are produced, ensure `test_output/report.md` lists the exact screenshot path per test id so reviewers can locate evidence without guessing.
+> - **(New)** If a test fails, ensure the report also lists the artifact folder path for that test id.
```

---

## Change 8 — Automate frequency scanning (stop doing it manually)

### What’s wrong in v0
You require “record exact commands used,” but you’re still relying on humans to run them and paste results. In parallel work, that becomes inconsistent and error-prone.

### Revision
Add a small script that:
- takes a list of patterns (Lua-facing names),
- runs ripgrep across the canonical script directories,
- outputs `files_with_match` and `total_occurrences`,
- optionally ignores comments,
- writes results to JSON that agents can reference.

### Why this makes the project better
- Consistent measurement across agents.
- Easy re-run when scripts change.
- Lets you compute “high-frequency” automatically and deterministically.

### Trade-offs
- Requires scripting; but this is exactly the kind of thing computers are good at.

### Git-diff patch
```diff
diff --git a/planning/cass_memory_update_plan_v0.md b/planning/cass_memory_update_plan_v1.md
--- a/planning/cass_memory_update_plan_v0.md
+++ b/planning/cass_memory_update_plan_v1.md
@@
 > **Frequency measurement requirement (repeatable):** Record the exact search method used (tool/command/pattern) per system, so another agent can reproduce the counts.
+> **Frequency automation (new, recommended):**
+> - Provide `scripts/frequency_scan.(py|lua)` that accepts:
+>   - an input list of Lua-facing names/patterns,
+>   - a set of search roots (default: `assets/scripts/`),
+>   - optional comment-ignore mode,
+> - and outputs `planning/inventory/frequency.{system}.json`.
+> - Agents must reference the JSON output in docs rather than hand-copied counts.
```

---

## Change 9 — Treat cm rules as code (declarative candidates + deterministic import)

### What’s wrong in v0
Phase 8 “cm playbook add …” is imperative and manual. That’s fragile:
- hard to review,
- easy to accidentally import unverified rules,
- hard to reproduce exactly.

### Revision
Define a declarative rules file:
- `planning/cm_rules_candidates.yaml` (or `.json`)
Each entry includes:
- `rule_id` (stable), `category`, `rule_text`, `doc_id`, `test_ref`, `status`

Phase 8 runs a script that:
- filters to `status=verified`,
- imports into cm playbook,
- exports `planning/cm_rules_backup.json`,
- and writes an audit report linking rule_id ↔ cm internal id (if available).

### Why this makes the project better
- Rules become reviewable in PRs like code.
- Import is reproducible (same input → same rules).
- You can diff rules over time and avoid playbook clutter.

### Trade-offs
- Adds a small import script, but saves you from “cm clickops” forever.

### Git-diff patch
```diff
diff --git a/planning/cass_memory_update_plan_v0.md b/planning/cass_memory_update_plan_v1.md
--- a/planning/cass_memory_update_plan_v0.md
+++ b/planning/cass_memory_update_plan_v1.md
@@
 ### Phase 8: cm Playbook Population
@@
 **Deliverables:**
 1. All rules added to cm playbook
 2. Rule export for backup: `planning/cm_rules_backup.json`
 3. Verification that `cm context "<task>"` returns relevant rules
+4. **(New)** Declarative rules source: `planning/cm_rules_candidates.yaml`
+5. **(New)** Deterministic importer script: `scripts/import_cm_rules.(py|lua)`
@@
 > **Rule traceability requirement (clarity):** Append ` (Verified: Test: <file>::<test_id>)` to rule text unless `cm` supports structured metadata; if metadata exists, store `test_id` in metadata and keep the rule text clean.
+> **Rule traceability upgrade (new, recommended):**
+> - Store `doc_id`, `test_ref`, and `quirks_anchor` in the declarative candidates file even if `cm` can't store metadata.
+> - The importer can then embed traceability consistently (either as metadata or as a suffix).
```

---

## Change 10 — Add an explicit “Maintenance / Drift Prevention” loop (after Phase 8)

### What’s wrong in v0
The plan is a great one-time push, but it doesn’t explicitly define how to keep everything correct when:
- new bindings are added,
- components change fields,
- UI gotchas evolve.

### Revision
Add a **Maintenance Mode** section:
- On every PR that changes binding files or component headers:
  - update the machine-readable inventory snapshot,
  - run validator (Change 1),
  - run affected tests.

Optionally: add a “snapshot diff” step that fails CI if inventories changed but docs/registry didn’t.

### Why this makes the project better
- Prevents the “docs rot” that kills these systems.
- Turns the work into an evergreen asset rather than a one-off project.

### Trade-offs
- Slight CI burden, but you can scope it to only when relevant files change.

### Git-diff patch
```diff
diff --git a/planning/cass_memory_update_plan_v0.md b/planning/cass_memory_update_plan_v1.md
--- a/planning/cass_memory_update_plan_v0.md
+++ b/planning/cass_memory_update_plan_v1.md
@@
 ## Risk Mitigation
@@
 | cm playbook gets cluttered | Use strict categories, review before adding |
+
+## Maintenance Mode (new, post-Phase 8)
+After the initial rollout, keep the system correct with lightweight, automated checks:
+- If files under `src/**lua_bindings**` (or the repo’s actual binding locations) change:
+  - regenerate `planning/inventory/bindings.*.json`,
+  - run `scripts/validate_docs_and_registry`,
+  - and run the affected `test_*_bindings.lua` categories.
+- If component definition headers change:
+  - regenerate `planning/inventory/components.*.json`,
+  - re-run component accessibility tests (where applicable).
+- CI should fail if inventories changed but:
+  - docs were not updated, or
+  - registry mappings are missing for previously verified doc_ids.
```

---

## Change 11 — Tighten Phase 1’s “assumptions” into explicit go/no-go gates

### What’s wrong in v0
Phase 1 has a good pre-flight checklist, but it doesn’t have explicit “stop conditions.” If the harness can’t do X, people will push ahead anyway and you’ll end up with a half-working verification story.

### Revision
Add explicit go/no-go outputs to Phase 1:
- “We can run Lua in a deterministic test scene” (Yes/No + how)
- “We can write files to test_output” (Yes/No)
- “We can take screenshots” (Yes/No + constraints)
- “We can intercept logs OR we have a stable fallback” (Yes/No)
- “We can reset world between tests” (Yes/No + strategy)

If any is “No,” Phase 1 must record the fallback and update downstream phases accordingly.

### Why this makes the project better
- Prevents sunk-cost drift (“we already wrote 80 tests but CI can’t run them”).
- Makes Phase 1 truly the foundation it claims to be.

### Trade-offs
- Slightly more upfront documentation.

### Git-diff patch
```diff
diff --git a/planning/cass_memory_update_plan_v0.md b/planning/cass_memory_update_plan_v1.md
--- a/planning/cass_memory_update_plan_v0.md
+++ b/planning/cass_memory_update_plan_v1.md
@@
 **Pre-flight environment verification (must complete before writing lots of tests):**
@@
 > **Pre-flight discovery requirement (make Phase 1 actionable):**
@@
 > - During Phase 1, record *exactly* where the “entrypoint” is chosen (file path + function/identifier) and how to switch to a test entrypoint.
 > - Record the exact run procedure in the README (Phase 1 deliverable), including any CLI flags or scene names (even if it’s “open the project and select scene X”).
+
+> **Go/No-Go gates (new, required outputs of Phase 1):**
+> - Deterministic test scene runnable: Yes/No (with exact procedure)
+> - `test_output/` writable: Yes/No (with constraints)
+> - Screenshot capture callable: Yes/No (with safe call timing)
+> - Log capture workable: Yes/No (engine hook or fallback)
+> - World reset between tests: Yes/No (preferred) / Strategy documented
+> - If any is **No**, Phase 1 must update downstream phases to avoid false promises (e.g., mark all visual verification as “no baselines, screenshot-only”).
```

---

## Change 12 — Clarify “UBS” (right now it’s a dangling acronym)

### What’s wrong in v0
“Run UBS before commits” is a requirement, but the plan never defines what UBS is or how to run it. That will block execution or cause someone to “pretend they ran it.”

### Revision
Force Phase 1 to locate/define UBS:
- what it stands for,
- where the script lives,
- exact invocation on each supported OS,
- what constitutes success,
- and where output is stored.

### Why this makes the project better
- Removes an ambiguity that can derail the final consolidation.
- Makes “UBS completed” actually auditable.

### Trade-offs
- None — this is just making implicit reality explicit.

### Git-diff patch
```diff
diff --git a/planning/cass_memory_update_plan_v0.md b/planning/cass_memory_update_plan_v1.md
--- a/planning/cass_memory_update_plan_v0.md
+++ b/planning/cass_memory_update_plan_v1.md
@@
 ### Phase 8: cm Playbook Population
@@
 > **UBS requirement (repo instruction alignment):** Run UBS before commits. If Phase 8 includes scripted bulk imports or touches many files, schedule UBS as a gating step before final merge/commit.
@@
 > **UBS specificity requirement (clarity):**
-> - In Phase 1 or Phase 8 preflight, identify the concrete UBS invocation (command/script), record it in the test README (or closest appropriate doc), and treat it as a release gate for Phase 8 changes.
+> - **Phase 1 preflight (required):** identify what “UBS” is in this repo and the concrete invocation(s) (command/script). Record in the test README and treat as a release gate for Phase 8 changes.
```

---

## Additional smaller-but-worthwhile edits (optional)

These aren’t as high-leverage as the 12 changes above, but they’re cheap wins:

- Add `tags={"slow","visual","serial","requires_input"}` conventions and default filters (so local dev runs stay fast).
- Add a “Known non-determinism sources” appendix (GPU, font rasterization, time-based animations).
- Add `docs/quirks.md` rule to include “Scope: affected systems/versions” for each quirk.
- Add a `docs/REFERENCE_INDEX.md` (or `planning/api_reference.md`) that auto-links to inventories.

---

## If you want one “single patch” instead of per-change hunks

The hunks above are written to be copy/paste friendly. If you prefer a single combined diff, I can produce it — but it will be long and harder to review than the per-change patchlets.

---

## Recommended next step

Apply Changes **1, 4, 5, 8, 9, 10** first. Those are the “stops the project from rotting” changes. The rest are quality boosts.

