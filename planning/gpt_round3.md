# Cass Memory Update Plan v2 — Review & Proposed Revisions (v3 draft)

This document proposes concrete revisions to the plan you provided. Each revision includes:

- **Problem observed in v2**
- **Proposed change**
- **Why it improves the project** (robustness, reliability, performance, developer experience)
- **Tradeoffs / risks**
- **Git-diff style patch** showing the change against the original plan text

> Notes on the diffs:
> - Diffs are shown as if the original plan lived at `planning/cass_memory_update_plan_v2.md`.
> - Hunks are intentionally **small and localized** so they’re easy to apply manually even if your file path differs.

---

## Overall read: what’s already strong vs what’s most risky

### Strong in v2
- Clear **phase structure** and responsibility boundaries.
- Correct instincts on **automation-first**, **schemas**, **determinism**, and **drift prevention**.
- Good separation between:
  - human-readable docs,
  - machine-readable inventories,
  - verification artifacts,
  - and cm “memory” rules.

### Biggest risks / failure modes
1. **Silent crash / hang** yields ambiguous CI failures (missing `status.json`, half-written results).
2. **Drift from duplicated truths** (docs show Verified, registry maps doc→test, tests exist separately).
3. **Tooling/environment drift** (extractors/validators depend on Python + tools with unspecified versions).
4. Visual baseline management can **explode repo size**, and nondeterminism can turn the suite into noise.
5. CI runtime will grow unless you add **impact-based selection** (sharding alone only parallelizes slowness).

The revisions below target these risks while keeping the spirit and structure of v2.

---

## Revision index (quick scan)

| ID | Theme | Primary win |
|---:|---|---|
| R01 | Add Phase 0: Toolchain bootstrap + pinned dependencies | Reproducible automation & less CI flake |
| R02 | Crash/hang detection via run sentinel + progress flushing | CI correctness + faster debugging |
| R03 | Reporter architecture from one canonical result model | No drift between report/md/json/junit |
| R04 | Reduce “triple truth” drift (docs/registry/tests) via synchronization tooling | Lower maintenance burden, higher trust |
| R05 | Add schemas for inventories + cm candidates + validate in CI | Tool compatibility & future-proofing |
| R06 | Generate Tier-0 docs skeletons from inventories (preserving manual blocks) | Massive labor reduction + consistency |
| R07 | Token-aware frequency scanning + alias config | Fewer false counts + reproducibility |
| R08 | Visual baseline storage policy + size governance (optionally Git LFS) | Prevent repo bloat + stable visuals |
| R09 | Deterministic rendering config + richer environment capture | Less nondeterminism, better baseline routing |
| R10 | Impact-based test selection for PR CI | Faster CI without reducing confidence |
| R11 | Artifact bundling for CI (zip index) | Better failure triage |
| R12 | Performance budgets + flake diagnostics (without hiding failures) | Keeps suite fast and actionable |

---

## R01 — Add Phase 0: Toolchain bootstrap + pinned dependencies

### Problem in v2
v2 introduces a lot of automation (`extract_*`, `validate_*`, `link_check_docs`, schema validation, etc.) but doesn’t define:
- which languages/tools are mandatory (Python version, `ripgrep`, YAML libs, JSON schema validator),
- how to install them consistently,
- or how to fail fast with actionable errors.

That’s a common “plan works on my machine” trap and a CI flake amplifier.

### Proposed change
Add **Phase 0** (“Toolchain & Repo Bootstrap”) with:
- a pinned Python environment (or at least pinned requirements),
- a “doctor” script that checks required tools and versions,
- and a short dev setup section in `<TEST_ROOT>/README.md`.

### Why it improves the project
- **Reliability:** CI failures become “missing dependency X” instead of mysterious downstream breakage.
- **Performance:** fewer wasted cycles in CI reruns.
- **Developer experience:** onboarding is one command instead of tribal knowledge.
- **Future-proofing:** you can upgrade toolchain intentionally with diffs.

### Tradeoffs / risks
- Slight up-front work (but it pays back quickly once multiple agents touch scripts).
- If the repo is intentionally dependency-light, keep it minimal (Python stdlib only + a single jsonschema lib).

### Git diff
```diff
diff --git a/planning/cass_memory_update_plan_v2.md b/planning/cass_memory_update_plan_v2.md
--- a/planning/cass_memory_update_plan_v2.md
+++ b/planning/cass_memory_update_plan_v2.md
@@ -1,6 +1,31 @@
 # Cass Memory Update Plan v2 (Enhanced with Automation, CI-Grade Reporting & Developer Experience)

+## Phase 0: Toolchain & Repo Bootstrap (New, required)
+**Effort:** S (Small)
+**Parallelizable:** No (foundation)
+
+Establish a reproducible toolchain for extractors/validators/reporters and fail fast when missing.
+
+**Deliverables:**
+1. `scripts/requirements.txt` (or `scripts/pyproject.toml`) with pinned versions
+2. `scripts/bootstrap_dev.(sh|ps1)` that creates/updates a local venv and installs deps
+3. `scripts/doctor.(py|lua)` that validates required tooling:
+   - Python version (if Python scripts exist)
+   - `rg` availability (frequency scan)
+   - `cm` availability and version (if Phase 8 depends on it)
+   - optional: schema validator availability (or ship one in Python)
+4. `<TEST_ROOT>/README.md` section: “Tooling setup”
+
+**CI requirement:**
+- Run `scripts/doctor` before any other job steps to fail fast.
+
@@ -706,6 +731,7 @@ gantt
     section Foundation
-    Phase 1: Test Infra    :p1, 0, 1
+    Phase 0: Toolchain     :p0, 0, 1
+    Phase 1: Test Infra    :p1, after p0, 1
```

---

## R02 — Crash/hang detection via run sentinel + progress flushing

### Problem in v2
If the engine crashes/hangs mid-run, you may never get:
- `test_output/status.json`
- a complete `results.json`
- or even a coherent `report.md`

CI then can’t distinguish “tests failed” from “runner died,” and you lose the last executed test context.

### Proposed change
Add a **run-state sentinel** and **progress flushing**:

- Write `test_output/run_state.json` at start:
  - `in_progress: true`
  - `run_id`
  - `started_at`
  - optional `commit`, `platform`, etc.
- After each test, flush:
  - `last_test_started`
  - `last_test_completed`
  - partial counts
- On graceful completion, mark:
  - `in_progress: false`
  - `completed_at`
  - `passed`

Wrapper scripts treat “missing run_state” or `in_progress:true` after timeout as a **crash**.

### Why it improves the project
- **Reliability:** CI correctly fails on crashes, not “missing file”.
- **Debuggability:** you immediately see the last test that started.
- **Performance:** fewer reruns because failures are obvious.

### Tradeoffs / risks
- Minor I/O overhead (tiny JSON file, flushed per test).
- Requires a stable notion of “run_id” (just use a timestamp + random suffix).

### Git diff
```diff
diff --git a/planning/cass_memory_update_plan_v2.md b/planning/cass_memory_update_plan_v2.md
--- a/planning/cass_memory_update_plan_v2.md
+++ b/planning/cass_memory_update_plan_v2.md
@@ -246,6 +246,8 @@ Create the verification pipeline that all subsequent phases depend on.
 4b. **(New)** Per-test artifacts directory: `test_output/artifacts/<safe_test_id>/`
+4c. **(New v3)** Run sentinel: `test_output/run_state.json` (crash/hang detection)
 5. Log capture mechanism for error detection
@@ -402,6 +404,12 @@
 > **(New v2) Schema validation deliverable (drift prevention):**
 > - Commit JSON Schemas under `planning/schemas/` (or `scripts/schemas/` if preferred):
 >   - `planning/schemas/status.schema.json`
 >   - `planning/schemas/results.schema.json`
 >   - `planning/schemas/capabilities.schema.json`
+>   - **(New v3)** `planning/schemas/run_state.schema.json`
+
+> **Crash detection requirement (New v3):**
+> - Runner writes `test_output/run_state.json` at start and updates it after every test.
+> - CI treats “missing run_state” or `in_progress:true` after timeout as a crash.
```

---

## R03 — Reporter architecture from one canonical result model

### Problem in v2
You now require multiple outputs:
- `report.md`
- `status.json`
- `results.json`
- `junit.xml`

If each is produced by separate code paths, drift is guaranteed (counts differ, ordering differs, missing tests differ).

### Proposed change
Make the harness produce a single **canonical in-memory run model**, then feed that into pluggable reporters:

- `MarkdownReporter`
- `JsonReporter` (writes status.json + results.json)
- `JUnitReporter`
- optional: `NdjsonEventReporter` (streaming)

### Why it improves the project
- **Correctness:** one source of truth for totals, ordering, and test statuses.
- **Maintainability:** adding a new report format is “add reporter” not “copy logic”.
- **Performance:** NDJSON streaming can support very large suites without huge memory.

### Tradeoffs / risks
- Slight refactor complexity in harness implementation.
- Reporter interface needs to be stable (but that’s good).

### Git diff
```diff
diff --git a/planning/cass_memory_update_plan_v2.md b/planning/cass_memory_update_plan_v2.md
--- a/planning/cass_memory_update_plan_v2.md
+++ b/planning/cass_memory_update_plan_v2.md
@@ -302,6 +302,18 @@ Test Harness Design:
 local TestRunner = {
     tests = {},
     results = {},
     screenshots = {}
 }
+
+-- (New v3) Reporter pipeline
+TestRunner.reporters = {
+  -- MarkdownReporter, JsonReporter, JUnitReporter, (optional) NdjsonEventReporter
+}
+
+function TestRunner:add_reporter(reporter)
+  table.insert(self.reporters, reporter)
+end
+
+function TestRunner:write_reports(run_model)
+  for _, r in ipairs(self.reporters) do r:write(run_model) end
+end
@@ -341,6 +353,15 @@ function TestRunner:report()
     -- Generate test report
 end
+
+-- (New v3) Optional streaming events for debugging/CI
+-- Writes test lifecycle events as NDJSON:
+-- test_output/events.ndjson
```

---

## R04 — Reduce “triple truth” drift (docs/registry/tests) via synchronization tooling

### Problem in v2
Today, the same fact is duplicated in three places:
1. Docs say: `Verified: Test: file::id`
2. Registry maps: `doc_id -> test_id`
3. The test module registers: `test_id`

This is the exact recipe for long-term drift.

### Proposed change
Keep the plan’s conceptual model, but reduce drift by making synchronization explicit:

1. **Tests declare which doc_ids they verify**:
   - `register(test_id, category, testFn, opts.doc_ids = {...})`
2. Harness produces a **test manifest**:
   - `test_output/test_manifest.json` containing all registered tests and their doc_ids.
3. Add a sync tool:
   - `scripts/sync_registry_from_manifest.py` (or Lua) generates/updates `<TEST_ROOT>/test_registry.lua` (deterministic ordering).
4. Add a second sync tool:
   - `scripts/sync_docs_evidence.py` ensures docs’ `Evidence:` blocks match the registry (check mode in CI; fix mode for dev).

This preserves your v2 “registry is single source of truth” intent, but ensures it is **derived deterministically** instead of hand-maintained.

### Why it improves the project
- **Reliability:** evidence displayed in docs stays correct.
- **Maintainability:** adding a test automatically updates coverage mapping.
- **Parallel work:** agents can add tests without touching shared registry.
- **Compelling:** reviewers can trust the docs, not treat them as aspirational.

### Tradeoffs / risks
- Requires stable markers in docs for the evidence block (easy).
- Registry becomes partially generated. You still need a place for unverified reasons; keep those as an override file.

### Git diff
```diff
diff --git a/planning/cass_memory_update_plan_v2.md b/planning/cass_memory_update_plan_v2.md
--- a/planning/cass_memory_update_plan_v2.md
+++ b/planning/cass_memory_update_plan_v2.md
@@ -327,6 +327,10 @@
 > **(New v2) Capability requirements per test (reliability across environments):**
 > - `register(test_id, category, testFn, opts)` supports `opts.requires = {"screenshot", "log_capture", ...}`.
 > - Harness checks `test_output/capabilities.json` (or in-memory equivalent) and emits `SKIP` with reason if requirements are missing.
+>
+> **(New v3) Doc coverage linking:**
+> - `register(..., opts)` supports `opts.doc_ids = {"binding:...", "component:...", "pattern:..."}`.
+> - Harness writes `test_output/test_manifest.json` listing registered tests + their `doc_ids`.
@@ -463,6 +467,30 @@
 > **Registry schema requirement (testability):**
 > - `<TEST_ROOT>/test_registry.lua` must be the single source of truth for coverage mapping.
+> - **(New v3)** Treat registry as *generated + overrides*:
+>   - Generated from inventories + `test_manifest.json`
+>   - Overrides file adds `unverified` reasons and any manual mapping exceptions
+> - **(New v3)** Add:
+>   - `scripts/sync_registry_from_manifest.(py|lua)` (deterministic generation)
+>   - `scripts/sync_docs_evidence.(py|lua)` (check/fix docs Evidence blocks)
@@ -911,6 +945,16 @@ Phase 7: Test Suite Finalization
 4. **(New)** `scripts/validate_docs_and_registry.lua` (or `.py`) and a documented invocation
+4b. **(New v3)** `scripts/sync_registry_from_manifest.(py|lua)` (inventory + manifest → registry)
+4c. **(New v3)** `scripts/sync_docs_evidence.(py|lua)` (registry → docs evidence blocks)
+4d. **(New v3)** `test_output/test_manifest.json` generated by harness every run
```

---

## R05 — Schemas for inventories + cm candidates (validate everything in CI)

### Problem in v2
Schemas exist for runner outputs (`status/results/capabilities`), but the automation also depends on:
- `planning/inventory/bindings.*.json`
- `planning/inventory/components.*.json`
- `planning/inventory/patterns.*.json`
- `planning/inventory/frequency.*.json`
- `planning/cm_rules_candidates.yaml`

Without schemas, tooling will break silently as fields evolve.

### Proposed change
Add and enforce schemas for:
- binding inventory
- component inventory
- pattern inventory
- frequency scan output
- cm candidates (validate YAML by converting to JSON first)

### Why it improves the project
- **Robustness:** scripts fail early with clear “schema mismatch” errors.
- **Cross-team reliability:** parallel agents can’t accidentally change structure.
- **CI-grade:** contract-driven automation.

### Tradeoffs / risks
- Slight schema maintenance cost, but low compared to debugging broken toolchains.

### Git diff
```diff
diff --git a/planning/cass_memory_update_plan_v2.md b/planning/cass_memory_update_plan_v2.md
--- a/planning/cass_memory_update_plan_v2.md
+++ b/planning/cass_memory_update_plan_v2.md
@@ -402,6 +402,13 @@
 > - Commit JSON Schemas under `planning/schemas/` (or `scripts/schemas/` if preferred):
 >   - `planning/schemas/status.schema.json`
 >   - `planning/schemas/results.schema.json`
 >   - `planning/schemas/capabilities.schema.json`
+>   - **(New v3)** `planning/schemas/bindings_inventory.schema.json`
+>   - **(New v3)** `planning/schemas/components_inventory.schema.json`
+>   - **(New v3)** `planning/schemas/patterns_inventory.schema.json`
+>   - **(New v3)** `planning/schemas/frequency.schema.json`
+>   - **(New v3)** `planning/schemas/cm_rules_candidates.schema.json` (YAML validated via JSON conversion)
@@ -920,6 +927,9 @@
 7. **(New v2)** Schema validation step in CI that validates `status.json`, `results.json`, and `capabilities.json` against committed schemas
+7b. **(New v3)** Schema validation also covers inventories and `cm_rules_candidates.yaml`
```

---

## R06 — Generate Tier-0 docs skeletons from inventories (preserving manual blocks)

### Problem in v2
You *require* every binding/component/pattern has Tier 0 docs, but you also:
- introduce extractors that already know the tier-0 list,
- and require machine-readable inventories.

If humans copy/paste tier-0 lists into markdown, you’ll get omissions and drift.

### Proposed change
Make Tier 0 docs **generated** from inventories and keep humans focused on Tier 1/2 semantics.

Add:
- `scripts/generate_docs_skeletons.py`
- “autogen sections” in docs that are replaced deterministically, while preserving manual text between stable markers.

Example doc pattern:
```md
<!-- AUTOGEN:BEGIN binding_list -->
<!-- AUTOGEN:END binding_list -->
```

### Why it improves the project
- **Massive labor reduction** (especially for 390+ functions).
- **Consistency:** doc_id, names, and source_ref match inventory.
- **Maintainability:** when bindings move, regeneration updates source_ref everywhere.

### Tradeoffs / risks
- Requires stable markers and a discipline that humans don’t edit inside autogen blocks.
- Some teams dislike generated docs; mitigate by making it *only Tier 0 scaffolding*, leaving rich docs human-authored.

### Git diff
```diff
diff --git a/planning/cass_memory_update_plan_v2.md b/planning/cass_memory_update_plan_v2.md
--- a/planning/cass_memory_update_plan_v2.md
+++ b/planning/cass_memory_update_plan_v2.md
@@ -607,6 +607,15 @@ Deliverables per agent:
 1. Binding list: `planning/bindings/{system}_bindings.md`
 2. Test file: `<TEST_ROOT>/test_{system}_bindings.lua`
 3. cm rules for high-frequency bindings
 4. **(New)** Machine-readable binding inventory: `planning/inventory/bindings.{system}.json`
 5. **(New v2, recommended)** Automated extractor: `scripts/extract_sol2_bindings.py` (single-owner, used by all agents)
+6. **(New v3, recommended)** Doc skeleton generator: `scripts/generate_docs_skeletons.py`
+   - Reads `planning/inventory/bindings.{system}.json`
+   - Rewrites Tier-0 sections in `planning/bindings/{system}_bindings.md` inside AUTOGEN markers
@@ -750,6 +759,12 @@ Deliverables:
 1. Component reference: `planning/components/{category}_components.md`
 2. Lua accessibility matrix (which components can be accessed from Lua)
 3. cm rules for component access patterns
 4. **(New)** Machine-readable component inventory: `planning/inventory/components.{category}.json`
 5. **(New v2, recommended)** Automated extractor: `scripts/extract_components.py` (single-owner) that generates Tier 0 component lists and a matrix skeleton.
+6. **(New v3)** Use `scripts/generate_docs_skeletons.py` to keep Tier-0 component lists synchronized with inventories.
```

---

## R07 — Token-aware frequency scanning + alias config

### Problem in v2
Frequency is defined by regex searching, which is easy but inaccurate:
- Counts matches in comments or strings.
- Misses aliases (`ui.box` vs `UIBox`) unless people remember to search variants.
- Agents may use different patterns, leading to inconsistent “High-frequency” decisions.

### Proposed change
Provide a single scanner that:
- lexes Lua and ignores comments/strings by default,
- supports an alias map per system,
- records scanner version and configuration in output.

Add file:
- `planning/frequency_aliases.yaml` (or JSON) defining:
  - canonical name
  - regex/aliases
  - match mode (identifier-only vs raw text)

### Why it improves the project
- **Truthfulness:** “high-frequency” becomes evidence-based, not grep luck.
- **Repeatability:** any agent can reproduce the same counts with the same tool.
- **Better prioritization:** fewer false positives means you test what matters.

### Tradeoffs / risks
- A real Lua parser might be heavy. Mitigation: implement a simple lexer (tokenizer) sufficient to skip strings/comments.

### Git diff
```diff
diff --git a/planning/cass_memory_update_plan_v2.md b/planning/cass_memory_update_plan_v2.md
--- a/planning/cass_memory_update_plan_v2.md
+++ b/planning/cass_memory_update_plan_v2.md
@@ -173,6 +173,17 @@
 > **Frequency automation (new, recommended):**
 > - Provide `scripts/frequency_scan.(py|lua)` that accepts:
 >   - an input list of Lua-facing names/patterns,
 >   - a set of search roots (default: `assets/scripts/`),
 >   - optional comment-ignore mode,
 > - and outputs `planning/inventory/frequency.{system}.json`.
+> - **(New v3)** Default mode is *token-aware*:
+>   - ignore comments and string literals when scanning Lua
+>   - fall back to plain regex only if token scan fails
+> - **(New v3)** Add `planning/frequency_aliases.yaml` to define canonical names and aliases.
+>   - Scanner output must record which alias matched.
```

---

## R08 — Visual baseline storage policy + size governance (optionally Git LFS)

### Problem in v2
Visual baselines are valuable but dangerous:
- PNG baselines can bloat the repo quickly.
- Baseline provenance (which environment produced it) can be unclear.
- Without guardrails, people may commit thousands of screenshots accidentally.

### Proposed change
Add a baseline storage policy and governance:

- Define a canonical platform key:
  - `os`, `arch`, `renderer`, `gpu_vendor` (best-effort), `resolution`
- Store baselines as:
  - `test_baselines/screenshots/<platform_key>/<renderer>/<resolution>/<safe_test_id>.png`
- Add:
  - `test_baselines/README.md` (rules, update workflow)
  - `.gitattributes` + Git LFS for `*.png` (optional but recommended)
  - `scripts/check_baseline_size.py` enforcing a PR size budget (e.g., warn at 50MB, fail at 200MB)

### Why it improves the project
- **Repo health:** avoids ballooning git history.
- **Stability:** baseline routing becomes deterministic (no mixing environments).
- **Better reviews:** size budget prevents “whoops I committed 2GB”.

### Tradeoffs / risks
- Git LFS requires developer setup. If that’s unacceptable, keep baselines small and only store critical ones.

### Git diff
```diff
diff --git a/planning/cass_memory_update_plan_v2.md b/planning/cass_memory_update_plan_v2.md
--- a/planning/cass_memory_update_plan_v2.md
+++ b/planning/cass_memory_update_plan_v2.md
@@ -118,6 +118,18 @@
 > **Baseline management (new):**
 > - Add a harness flag `--record-baselines` (manual only) to write/update baseline images.
 > - CI must never run in record mode.
+> - **(New v3)** Baseline storage policy:
+>   - Store baselines under `test_baselines/screenshots/<platform_key>/<renderer>/<resolution>/`.
+>   - Define `platform_key` in `test_output/capabilities.json` (or `run_state.json`) for deterministic routing.
+> - **(New v3, recommended)** Add `test_baselines/README.md` and baseline size governance:
+>   - `scripts/check_baseline_size.py` enforces a max PR delta budget for baseline images.
+>   - Optional: use Git LFS for `*.png` baselines via `.gitattributes`.
```

---

## R09 — Deterministic rendering config + richer environment capture

### Problem in v2
You mention determinism, but visual nondeterminism often comes from:
- window size / DPI scaling
- font differences
- vsync / frame pacing
- renderer backend differences

If you don’t standardize these, your “visual verified” path will be fragile.

### Proposed change
Make the test scene explicitly configure rendering:

- `test_utils.configure_test_rendering({width=..., height=..., dpi_scale=1, vsync=false, fixed_font=...})`
- record the resolved config in `capabilities.json` and `results.json`:
  - width/height
  - dpi scale
  - renderer/backend
  - font name/hash if possible

### Why it improves the project
- **Reliability:** fewer cross-machine diffs.
- **Better baselines:** baseline routing can include resolution/backend.
- **Developer experience:** visually debugging is consistent.

### Tradeoffs / risks
- Some engines can’t control DPI or font selection. Mitigation: record what you can and quarantine tests that can’t be stabilized.

### Git diff
```diff
diff --git a/planning/cass_memory_update_plan_v2.md b/planning/cass_memory_update_plan_v2.md
--- a/planning/cass_memory_update_plan_v2.md
+++ b/planning/cass_memory_update_plan_v2.md
@@ -229,6 +229,13 @@
 > **Determinism checklist (specific + testable):** During pre-flight, record and enforce:
 > - RNG seeding: `math.randomseed(<fixed>)` (and any engine RNG seed if applicable)
 > - Fixed timestep / frame count driving for screenshot tests
 > - Disabling or accounting for frame-time-dependent animations (or waiting N frames deterministically)
 > - Explicit camera setup for rendering tests (if applicable)
+> - **(New v3)** Explicit rendering config:
+>   - window size/resolution (recorded)
+>   - DPI scale (if controllable)
+>   - vsync/frame pacing disabled for deterministic capture (if controllable)
+>   - fixed font selection or font asset hash (if applicable)
```

---

## R10 — Impact-based test selection for PR CI

### Problem in v2
You add sharding (good), but on PR CI you’ll still end up running *everything* as the suite grows.

That’s fine early, but it won’t scale.

### Proposed change
Add a test impact selection layer:

- `planning/test_impact_map.yaml`:
  - maps file globs to categories/tags/doc systems
- `scripts/select_tests.(py|lua)`:
  - inspects `git diff` and emits runner args (`--category`, `--tags-any`, shards)
- PR CI:
  - run impacted tests + smoke
- Nightly:
  - run full suite (including visual + slow)

### Why it improves the project
- **Performance:** PR CI becomes fast.
- **Reliability:** full verification still happens on schedule.
- **Compelling:** people won’t avoid running tests due to slowness.

### Tradeoffs / risks
- Impact mapping requires maintenance. Mitigation:
  - start broad (UI changes run all UI tests),
  - refine later.

### Git diff
```diff
diff --git a/planning/cass_memory_update_plan_v2.md b/planning/cass_memory_update_plan_v2.md
--- a/planning/cass_memory_update_plan_v2.md
+++ b/planning/cass_memory_update_plan_v2.md
@@ -1296,6 +1296,20 @@ Maintenance Mode (new, post-Phase 8)
 ### CI enforcement:
 - CI should fail if inventories changed but:
   - docs were not updated, or
   - registry mappings are missing for previously verified doc_ids.
+
+### (New v3) PR CI impact selection:
+- Add `planning/test_impact_map.yaml` mapping file globs → runner filters (categories/tags).
+- Add `scripts/select_tests.(py|lua)`:
+  - reads `git diff --name-only <base>`
+  - outputs runner args (categories/tags/shards)
+- PR CI runs:
+  - impacted tests + a small `smoke` subset
+- Nightly runs:
+  - full suite (all shards + visual + slow)
```

---

## R11 — Artifact bundling & triage index for CI

### Problem in v2
When visual tests fail (or when a crash happens), the data you want is scattered:
- screenshots
- diffs
- logs
- report.md
- results.json

People waste time hunting.

### Proposed change
Add an artifact pack step:
- `scripts/pack_test_artifacts.py` zips `test_output/` (or just failing tests)
- writes `test_output/artifacts_index.md` with hyperlinks to key files/folders

### Why it improves the project
- **Developer experience:** debugging becomes “download one zip”.
- **Reliability:** less guesswork means less repeated CI runs.

### Tradeoffs / risks
- Larger CI artifacts. Mitigation: pack only on failure or only failing tests.

### Git diff
```diff
diff --git a/planning/cass_memory_update_plan_v2.md b/planning/cass_memory_update_plan_v2.md
--- a/planning/cass_memory_update_plan_v2.md
+++ b/planning/cass_memory_update_plan_v2.md
@@ -924,6 +924,11 @@ Deliverables:
 11. **(New v2)** `scripts/link_check_docs.(py|lua)` that validates:
     - no duplicate `doc_id` in docs,
@@
 12. **(New v2)** Generated reference index: `docs/reference/index.md` (or `planning/api_reference.md`)
+13. **(New v3)** CI artifact bundling:
+    - `scripts/pack_test_artifacts.(py|lua)` creates `test_output/test_artifacts.zip` (on failure)
+    - `test_output/artifacts_index.md` provides an at-a-glance triage map
```

---

## R12 — Performance budgets + flake diagnostics (without hiding failures)

### Problem in v2
The suite will slow over time. Also, flaky tests kill trust.

Sharding helps runtime, but you need:
- a way to spot slow regressions,
- and a policy for diagnosing flakes without masking them.

### Proposed change
Add:
- per-test (optional) `opts.perf_budget_ms`
- runner tracks durations and highlights:
  - top 10 slow tests
  - regressions vs last run (optional, if you store a baseline JSON)
- for flaky diagnostics:
  - a **manual** `--repeat N` runner mode that repeats selected tests for investigation
  - CI never retries to convert fail→pass; at most it can re-run to attach extra evidence

### Why it improves the project
- **Performance:** you can prevent “test suite takes 40 minutes” creep.
- **Trust:** flakes are surfaced and tracked, not silently retried away.

### Tradeoffs / risks
- Budgets take calibration. Mitigation: start with “warn-only” in PR CI, “fail budgets” in nightly.

### Git diff
```diff
diff --git a/planning/cass_memory_update_plan_v2.md b/planning/cass_memory_update_plan_v2.md
--- a/planning/cass_memory_update_plan_v2.md
+++ b/planning/cass_memory_update_plan_v2.md
@@ -309,6 +309,8 @@ function TestRunner:register(name, category, testFn, opts)
     -- opts may include: tags, source_ref, timeout_frames, requires, display_name
+    -- (New v3) opts may include: perf_budget_ms, doc_ids
 end
@@ -1412,6 +1414,15 @@ Appendix: Tag conventions for tests
 - `tags={"slow"}` - Tests taking >5 seconds
+- **(New v3)** Prefer budgets over ad-hoc “slow” tags:
+  - `opts.perf_budget_ms` allows thresholds per test
+  - Runner reports slow tests even if they pass
+
+### Flake diagnostics (New v3)
+- Add runner flag `--repeat N` for manual investigation
+- CI must not retry failures to convert them to pass; retries (if any) are for extra artifacts only
```

---

## Small but worthwhile editorial fixes (optional)

These don’t change architecture, but they reduce ambiguity.

### 1) Fix duplicate numbering in Phase 1 deliverables
You currently have “4.” and “4b.” (fine) but it’s easy to misread. Consider 4/5/6 style numbering or make 4 a “Outputs” section.

```diff
diff --git a/planning/cass_memory_update_plan_v2.md b/planning/cass_memory_update_plan_v2.md
--- a/planning/cass_memory_update_plan_v2.md
+++ b/planning/cass_memory_update_plan_v2.md
@@ -238,9 +238,11 @@ Deliverables:
-4. Screenshot output directory: `test_output/screenshots/`
-4b. **(New)** Per-test artifacts directory: `test_output/artifacts/<safe_test_id>/`
+4. Output directories:
+   - screenshots: `test_output/screenshots/`
+   - artifacts: `test_output/artifacts/<safe_test_id>/`
```

### 2) Make “UBS” a required glossary entry
You already require Phase 1 to identify it; making it a named glossary item reduces confusion.

```diff
diff --git a/planning/cass_memory_update_plan_v2.md b/planning/cass_memory_update_plan_v2.md
--- a/planning/cass_memory_update_plan_v2.md
+++ b/planning/cass_memory_update_plan_v2.md
@@ -79,6 +79,10 @@ Definitions (for consistency + testability)
 - **"Binding"**: Any Lua-exposed type/function/constant created via Sol2, including methods on usertypes and free functions.
+ - **"UBS"**: Repo-specific build/validation step. Phase 1 must define:
+   - name expansion (what it stands for)
+   - exact invocation command(s)
+   - pass/fail signal and log location
```

---

## Net effect: what v3 looks like

If you apply these revisions, the “v3” plan has these high-level properties:

- **Reproducible toolchain** (Phase 0) so automation doesn’t rot.
- **Crash-proof CI semantics** (run sentinel).
- **One true run model** (reporters consume the same data).
- **Far less drift** (sync tools tie together tests/registry/docs).
- **More accurate prioritization** (token-aware frequency scanning).
- **Scalable CI** (impact selection + sharding + budgets).
- **Better visual discipline** (baseline policy + size governance).
- **Better debugging** (artifact bundles + triage index).

If you want, you can treat these revisions as a “v2.1 patchset” and keep the existing v2 numbering, or formally rename the plan to v3.

