# Game #4 “Bargain” — Engineering Plan (v13: contract-first, CI-provable, parallel-by-design)

> **Ship goal (MVP):** a **deterministic, replayable 7-floor run** where **Bargains** are the primary progression mechanic and every run ends in **victory or death** (no softlocks), proven by **one CI-gated command**.

---

## 0) Definition of Done (DoD)

### 0.1 One proof command (local + CI)
1. Build: `just build-debug-fast`
2. Headless test run: `RUN_BARGAIN_TESTS=1 ./build-debug/raylib-cpp-cmake-template`

**Pass criteria**
- Process exits `0`
- **No window created** / **no render loop** entered
- All Bargain suites pass
- On failure: exits non-zero and prints **exactly one** machine-parseable repro payload (see §7)

### 0.2 CI gates (hard requirements)
| Gate | Requirement | Exact check |
|---|---|---|
| A Determinism | same seed+script → identical digest | run each seed/script twice; compare digest strings |
| B Termination | run ends in `victory` or `death` | assert `run_state ∈ {"victory","death"}` |
| C Deals catalog | exactly 21 deals, stable IDs | load deals; count=21; IDs unique; sins×3 complete |
| D Downside enforcement | each deal has measurable downside | table-driven baseline vs applied metric assertions |
| E No nondeterminism | forbid banned APIs & unstable iteration | static scan + runtime guardrails |
| F Repro fidelity | one failing test → one repro bundle | stdout contains single JSON object and exits non-zero |

### 0.3 Explicit non-goals (MVP)
- inventory/shops/save-load/meta progression
- balance polish beyond “not broken”
- sophisticated pathfinding beyond deterministic chase/attack

---

## 1) Repository Contracts (land first; unblock parallel work)

### 1.1 Minimal shared file touch list (integrator-owned)
Only these are “hot” shared files; everything else should live in low-collision directories.

- `assets/scripts/core/main.lua`  
  - adds `RUN_BARGAIN_TESTS` early-exit hook (before any window/UI boot)
- `assets/scripts/tests/run_bargain_tests.lua`  
  - registers suites, runs, prints repro payload on failure, sets exit code

### 1.2 Low-collision work zones (everyone else)
- Sim core: `assets/scripts/bargain/sim/**`
- Data: `assets/scripts/bargain/data/**`
- Systems: `assets/scripts/bargain/**` (non-sim helpers may live outside `sim/`, but determinism rules still apply if they affect gameplay)
- Tests: `assets/scripts/tests/bargain/**`

---

## 2) Frozen Interfaces (every stream codes against these)

### 2.1 World schema (contract-tested)
Required fields (no extras needed for MVP, but these must exist and be stable):
- `world.grid`
- `world.entities` (map `id -> entity`)
- `world.player_id`
- `world.turn` (integer, increments deterministically)
- `world.phase` (string enum)
- `world.floor_num` (1..7)
- `world.run_state` (`"playing"|"victory"|"death"`)
- `world.rng` (the only RNG)
- `world.deals.applied` (map `deal_id -> true`)
- `world.deals.history` (append-only array)
- `world.deals.pending_offer` (`nil | offer`)
- `world.caps_hit` (bool; true only if internal cap triggered)

Allowed deterministic debug channels (append-only):
- `world.events`
- `world.messages`

### 2.2 Entity schema (contract-tested)
- `id`, `kind` (`"player"|"enemy"|"boss"`)
- `x`, `y`
- `hp`, `hp_max`
- `atk`, `def`, `speed`, `fov_radius`
- `xp`, `level`
- `flags` (deterministically serialized set)
- `hooks` (`hook_name -> array`, stable order)

### 2.3 Offer schema (stable order)
`world.deals.pending_offer`:
- `kind ∈ {"floor_start","level_up"}`
- `offers: [deal_id...]` (deterministic order; never `pairs()` order)
- `must_choose: bool`
- `can_skip: bool`

### 2.4 Input API (frozen)
`step(world, input)` supports exactly:
- `{type="move", dx=0|±1, dy=0|±1}`
- `{type="attack", dx=0|±1, dy=0|±1}`
- `{type="wait"}`
- `{type="deal_choose", deal_id="..."}`
- `{type="deal_skip"}`

**Error semantics (frozen)**
- Invalid input returns `{ok=false, err="..."}` and **consumes the actor turn** without breaking invariants.

### 2.5 Phase machine (frozen; table-driven)
Phases:
`DEAL_CHOICE → PLAYER_INPUT → PLAYER_ACTION → ENEMY_ACTIONS → END_TURN → PLAYER_INPUT`

Rules:
- Forced offers pin `DEAL_CHOICE` until chosen.
- Enemy action order: `speed desc`, tie-break `id asc`.
- Canonical direction order: `N, E, S, W` (and diag is disallowed for MVP unless explicitly added later).

---

## 3) Determinism, Ordering, and Caps (non-negotiable)

### 3.1 RNG rules
- Only `world.rng` can generate randomness.
- Forbidden in gameplay logic: `math.random`, time-based seeds, frame `dt`, engine globals.

### 3.2 Stable iteration rules
- No gameplay-critical `pairs()`/`next()` over tables in sim/gameplay directories.
- Any “order matters” collection must be:
  - array in fixed order, or
  - explicitly sorted with comparator + deterministic tie-breakers.

### 3.3 Caps & termination guarantees
Define constants (contract-tested; tuned later):
- `MAX_INTERNAL_TRANSITIONS` (start `64`)
- `MAX_STEPS_PER_RUN` (start `5000`)
- procgen attempt caps per floor with deterministic fallback behavior when exceeded

**Contract expectations**
- If a cap trips: set `world.caps_hit=true`, set `world.run_state` to `"death"` (or another agreed terminal), and emit a repro bundle.

---

## 4) Test Strategy (CI-friendly, failure-localizing)

### 4.1 Test runner behavior
Entry: `assets/scripts/tests/run_bargain_tests.lua`
- uses existing `assets/scripts/tests/test_runner.lua` (`describe/it/expect`)
- stable stdout: only suite output + (on failure) exactly one repro JSON object
- exits `0` on success; non-zero on any failure

### 4.2 Required suite inventory (each is a bead-sized deliverable)
- `assets/scripts/tests/bargain/contracts_spec.lua`  
  - schema validation, phase rules, invalid-input semantics, cap behavior
- `assets/scripts/tests/bargain/determinism_static_spec.lua`  
  - static scan: ban nondeterministic APIs + ban `pairs()` in sim-critical modules
- `assets/scripts/tests/bargain/digest_spec.lua`  
  - digest stable across reruns; digest version bump rules
- `assets/scripts/tests/bargain/sim_smoke_spec.lua`  
  - tiny fixed map: move/attack/turn loop; terminates; digest stable
- `assets/scripts/tests/bargain/floors_spec.lua`  
  - bounded seeds: invariants (connectivity, stairs reachable, spawn constraints), deterministic fallback on cap hit
- `assets/scripts/tests/bargain/fov_spec.lua`  
  - golden visible-set tests on canonical maps
- `assets/scripts/tests/bargain/deals_loader_spec.lua`  
  - 21 deals exist, IDs valid/unique, sins×3 coverage
- `assets/scripts/tests/bargain/deals_downside_spec.lua`  
  - 21 table rows; each row asserts at least one downside metric flips
- `assets/scripts/tests/bargain/ai_spec.lua`  
  - deterministic targeting, tie-breakers, action order
- `assets/scripts/tests/bargain/run_scripts_spec.lua`  
  - full-run scripts `S1,S2,S3` + golden digests; determinism gate A

### 4.3 Golden protocol (minimize churn)
- Goldens live under `assets/scripts/tests/bargain/goldens/**`
- Every golden update requires:
  - updated golden file(s)
  - a one-line rationale per change
  - proof: two consecutive runs match bit-for-bit for same seed/script

---

## 5) Deal Catalog Contract (stable IDs + downside proof)

### 5.1 IDs and cardinality (frozen after Gate C is green)
- ID format: `<sin>.<index>` (e.g., `wrath.1`)
- Exactly `7 sins × 3 deals = 21`
- After Gate C passes: append-only (no renames/remaps; only additive metadata allowed)

### 5.2 Downside standard (per deal; CI-testable)
For each deal:
- run identical deterministic script twice:
  - baseline (deal not applied)
  - applied (deal applied at the earliest legal moment)
- assert at least one metric flips as expected, using a standardized metric set:
  - `hp_lost_total`
  - `turns_elapsed`
  - `kills_required` / `damage_dealt_total`
  - `visible_tiles_count` (if FOV-related)
  - `forced_actions_count` / `denied_actions_count`

---

## 6) Milestones (dependency-ordered, bead-sized, exit-test defined)

### M0 — Contract package + headless harness (critical path)
**Depends on:** nothing  
**Exit tests**
- Proof command (§0.1) passes
- `contracts_spec` and `sim_smoke_spec` exist and pass on a clean checkout

### M1 — Core sim (tiny fixed map end-to-end)
**Depends on:** M0  
**Exit tests**
- `sim_smoke_spec` covers: move, attack, enemy acts, termination without caps
- `digest_spec` verifies stable digest across repeated runs

### M2 — Floors + FOV
**Depends on:** M0 (M1 recommended for integration)  
**Exit tests**
- `floors_spec` passes for bounded seeds set (e.g., 20 seeds)
- `fov_spec` goldens green

### M3 — Deals system + 21 deals + downside enforcement
**Depends on:** M1 + M0  
**Exit tests**
- `deals_loader_spec` green (21 IDs, coverage)
- `deals_downside_spec` green (21/21 flip at least one metric)

### M4 — Enemies + boss + win/lose
**Depends on:** M1 + M2  
**Exit tests**
- `run_state` reaches both `victory` and `death` on scripted scenarios
- `ai_spec` deterministic ordering + tie-breakers

### M5 — Minimal UI bridge (UI only; sim stays headless-testable)
**Depends on:** M0 + M3  
**Exit tests**
- manual checklist on a known seed:
  - deal modal appears on offer
  - choose/skip maps to `deal_choose`/`deal_skip`
  - victory/death screen
- no gameplay logic in UI layer (enforced by static scan scope)

### M6 — Full-run determinism scripts + goldens
**Depends on:** M1–M4 (and M3)  
**Exit tests**
- `run_scripts_spec` green for `S1,S2,S3`
- Gate A and B green in CI (two consecutive runs match; termination guaranteed)

### M7 — Balance surface (post-correctness)
**Depends on:** M3–M4  
**Exit tests**
- single tuning surface file for numeric knobs
- 3 recorded seeded runs added to fixtures/docs (non-blocking for MVP correctness)

---

## 7) Failure Repro Bundle (single payload contract)

### 7.1 Output contract
On any test failure: print **exactly one JSON object** to stdout (single line; JSONL style), then exit non-zero.

### 7.2 Payload fields (minimum)
- `seed`, `floor_num`, `turn`, `phase`, `run_state`
- `last_input`, `pending_offer`
- `last_events` (<= 20; deterministic order)
- `digest`, `digest_version`
- `caps_hit` (bool)
- optional: `world_snapshot_path` (only if the dump path is deterministic)

### 7.3 Snapshot rules (if used)
- snapshot filename is deterministic from `(seed, script_id, turn)` (no timestamps)
- snapshot must not include nondeterministic table key order (serialize in fixed order)

---

## 8) Parallel Workstreams (ownership + minimal collisions)

### Stream I — Integrator (M0)
**Targets**
- headless hook + test runner + repro bundle
**Only shared-hot files**
- `assets/scripts/core/main.lua`
- `assets/scripts/tests/run_bargain_tests.lua`

### Stream C — Core sim (M1)
**Targets**
- deterministic grid helpers, step loop, combat, caps
**Primary files**
- `assets/scripts/bargain/sim/**`
- `assets/scripts/tests/bargain/sim_smoke_spec.lua`
- `assets/scripts/tests/bargain/contracts_spec.lua`

### Stream F/V — Floors + FOV (M2)
**Targets**
- procgen invariants-first; FOV goldens
**Primary files**
- `assets/scripts/bargain/floors/**`, `assets/scripts/bargain/fov/**`
- `assets/scripts/tests/bargain/floors_spec.lua`
- `assets/scripts/tests/bargain/fov_spec.lua`

### Stream D — Deals (M3)
**Targets**
- offers + apply plumbing; 21 deals; downside table
**Primary files**
- `assets/scripts/bargain/data/deals/**`
- `assets/scripts/bargain/deals/**`
- `assets/scripts/tests/bargain/deals_loader_spec.lua`
- `assets/scripts/tests/bargain/deals_downside_spec.lua`

### Stream A — Enemies + boss (M4)
**Targets**
- enemy templates; AI chase/attack; boss + victory condition
**Primary files**
- `assets/scripts/bargain/enemies/**`, `assets/scripts/bargain/ai/**`
- `assets/scripts/tests/bargain/ai_spec.lua`
- `assets/scripts/tests/bargain/run_scripts_spec.lua` (scenario-based)

### Stream R — Determinism + goldens (M6)
**Targets**
- digest protocol; scripts S1–S3; golden storage + rationale discipline
**Primary files**
- `assets/scripts/bargain/sim/digest/**`
- `assets/scripts/tests/bargain/digest_spec.lua`
- `assets/scripts/tests/bargain/run_scripts_spec.lua`
- `assets/scripts/tests/bargain/goldens/**`

### Stream UI — Minimal UI bridge (M5)
**Targets**
- deal modal UI; HUD; restart plumbing
**Primary constraint**
- UI emits inputs to `step()` only; no sim logic in UI layer

---

## 9) Risks → Mandatory Test Mitigations

- Lua iteration nondeterminism → ordered-iteration helpers + `determinism_static_spec`
- Hidden randomness/time in bridge/UI → headless suite must never boot UI; static scan bans time/RNG usage in sim
- Procgen infinite loops/unreachable stairs → attempt caps + `floors_spec` invariant suite + repro seed payload
- “Downside exists but is toothless” → `deals_downside_spec` must flip a concrete metric for each deal
- Golden churn → digest versioning + rationale-per-change + double-run determinism proof in CI

---

## 10) Beads + Coordination Workflow (operational)

- Triage with BV; only claim beads with explicit exit tests from §4/§6.
- Claim bead → set `in_progress`.
- Reserve paths (exclusive) before edits; prefer low-collision zones in §1.2.
- Implement + add/extend tests in §4.2 (tests ship with the feature).
- Close bead → notify dependents via Agent Mail:
  - what changed (files + contracts touched)
  - which suites/gates to rerun
  - whether goldens changed (and why)
- Run UBS before committing; keep commits small and stream-scoped.