# Game #4 “Bargain” — Engineering Plan (v12: contract-first, CI-provable, parallel-by-design)

> **Ship goal:** a **deterministic, replayable 7-floor run** where **Bargains** are the primary progression mechanic and every run ends in **victory or death** (no softlocks), proven by **one CI-gated command**.

---

## 0) Definition of Done (DoD)

### 0.1 Single proof command (local + CI)
- Build: `just build-debug-fast`
- Run headless Bargain suite: `RUN_BARGAIN_TESTS=1 ./build-debug/raylib-cpp-cmake-template`

**Pass criteria**
- Exit code `0`
- No window created / no main loop entered
- All Bargain tests pass
- On failure: prints exactly **one** machine-parseable repro bundle (see §6)

### 0.2 CI quality gates (must be enforced)
| Gate | Requirement | Exact measurement |
|---|---|---|
| A Determinism | Same seed + same script → identical digests | run each seed/script twice; compare digest strings |
| B Termination | Runs end in `victory` or `death` | assert final `run_state∈{victory,death}` and `caps_hit=false` |
| C Deals catalog | Exactly 21 deals (7 sins × 3), stable IDs | loader spec: count=21, IDs unique, mapping complete |
| D Downside enforcement | 21/21 deals materially change outcome | table-driven “baseline vs applied” metric assertions |
| E Repro | One failure → one repro payload | stdout contains single JSON (or JSONL) object and exits non-zero |

### 0.3 Explicit non-goals (MVP)
- inventory, shops, save/load, meta progression
- broad polish (VFX/audio/balance beyond “not broken”)
- sophisticated pathfinding beyond deterministic chase/attack

---

## 1) Contract Package (unblocks parallel work; must land first)

### 1.1 Contract package scope (frozen interfaces + tests)
**Deliverables**
- `RUN_BARGAIN_TESTS` early-exit hook (no UI boot)
- Bargain test runner that:
  - registers suites
  - runs them
  - exits with correct code
- Contract tests for:
  - schemas
  - step/input semantics
  - phase machine rules
  - caps/termination behavior
  - determinism constraints (static scan + runtime digest checks)

**Exit tests**
- The single proof command (§0.1) passes on a clean checkout.
- A minimal “hello sim” test creates a world, steps it, produces a digest, and terminates.

### 1.2 File boundary rules (to minimize collisions)
**Only shared-hot files (integrator-owned)**
- `assets/scripts/core/main.lua` (test hook + early exit)
- `assets/scripts/tests/run_bargain_tests.lua` (suite registration + exit code)

**Low-collision zones (everyone else works here)**
- Sim/core: `assets/scripts/bargain/sim/**`
- Data: `assets/scripts/bargain/data/**`
- Systems (FOV/floors/AI/etc.): `assets/scripts/bargain/**`
- Tests/fixtures: `assets/scripts/tests/bargain/**`

---

## 2) Frozen Interfaces (what every stream codes against)

### 2.1 `world` schema (contract-tested)
**Required**
- `world.grid`
- `world.entities` (map `id -> entity`)
- `world.player_id`
- `world.turn`
- `world.phase`
- `world.floor_num` (1..7)
- `world.run_state` (`"playing"|"victory"|"death"`)
- `world.rng` (the only RNG)
- `world.deals.applied` (map `deal_id -> true`)
- `world.deals.history` (array, append-only)
- `world.deals.pending_offer` (`nil | offer`)

**Allowed deterministic debug**
- `world.events` (append-only)
- `world.messages` (append-only)

### 2.2 `entity` schema (contract-tested)
- `id`, `kind` (`"player"|"enemy"|"boss"`)
- `x`, `y`
- `hp`, `hp_max`
- `atk`, `def`, `speed`, `fov_radius`
- `xp`, `level`
- `flags` (deterministically serialized set)
- `hooks` (`hook_name -> array`, stable order)

### 2.3 `offer` schema (stable order)
`world.deals.pending_offer`:
- `kind ∈ {"floor_start","level_up"}`
- `offers: [deal_id...]` (deterministic order)
- `must_choose: bool`
- `can_skip: bool`

### 2.4 Input API
`step(world, input)` supports exactly:
- `{type="move", dx=0|±1, dy=0|±1}`
- `{type="attack", dx=0|±1, dy=0|±1}`
- `{type="wait"}`
- `{type="deal_choose", deal_id="..."}`
- `{type="deal_skip"}`

**Error semantics (frozen)**
- Invalid input returns `{ok=false, err="..."}` and **consumes the actor turn** without breaking invariants.

### 2.5 Phase machine (frozen, table-driven tests)
Phases:
`DEAL_CHOICE → PLAYER_INPUT → PLAYER_ACTION → ENEMY_ACTIONS → END_TURN → PLAYER_INPUT`

Rules:
- Forced offers pin `DEAL_CHOICE` until chosen.
- Enemy action order: `speed desc`, tie-break `id asc`.
- Canonical direction order is fixed: `N, E, S, W`.

---

## 3) Determinism & Safety (non-negotiable)

### 3.1 RNG rules
- Only `world.rng` may generate randomness.
- No `math.random`, time-based seeds, frame `dt`, or engine globals in sim logic.

### 3.2 Stable iteration rules
- No gameplay-critical `pairs()`/`next()` iteration in sim directories.
- All “order matters” collections must:
  - be arrays with fixed order, or
  - be sorted with explicit comparator + tie-breakers.

### 3.3 Caps (termination guarantees)
Define explicit constants (contract-tested):
- `MAX_INTERNAL_TRANSITIONS` (start 64)
- `MAX_STEPS_PER_RUN` (start 5000)
- Procgen attempt caps per floor; deterministic fallback when exceeded

**Tests**
- Scripted runs must finish without hitting caps.
- Seeded procgen invariant test prints seed repro on failure.

---

## 4) Test Strategy (failure-localizing, CI-friendly)

### 4.1 Test runner behavior
- One entry: `assets/scripts/tests/run_bargain_tests.lua`
- Uses existing `assets/scripts/tests/test_runner.lua` (`describe/it/expect`)
- Produces stable, minimal stdout; on failure emits a single repro bundle (§6)

### 4.2 Suite list (explicit deliverables)
- `assets/scripts/tests/bargain/contracts_spec.lua`
  - schema validation, phase rules, invalid-input semantics, caps behavior
- `assets/scripts/tests/bargain/determinism_static_spec.lua`
  - static scan forbidding nondeterministic APIs/usages in sim dirs
- `assets/scripts/tests/bargain/digest_spec.lua`
  - digest stability + `digest_version` bump rules
- `assets/scripts/tests/bargain/sim_smoke_spec.lua`
  - fixed tiny-map end-to-end smoke (move/attack/turn loop)
- `assets/scripts/tests/bargain/floors_spec.lua`
  - invariants across bounded seeds; deterministic fallback on cap hit
- `assets/scripts/tests/bargain/fov_spec.lua`
  - goldens for visible-set on canonical maps
- `assets/scripts/tests/bargain/deals_loader_spec.lua`
  - 21 deals exist, IDs valid, uniqueness, sin/index coverage
- `assets/scripts/tests/bargain/deals_downside_spec.lua`
  - 21 table-driven downside assertions (“baseline vs applied”)
- `assets/scripts/tests/bargain/ai_spec.lua`
  - deterministic targeting and tie-breakers
- `assets/scripts/tests/bargain/run_scripts_spec.lua`
  - full-run scripts for `S1,S2,S3` with golden digests

---

## 5) Digest & Golden Protocol (minimize churn)

### 5.1 Digest requirements
- Fixed-order serialization only (no map iteration)
- Sorted entity list by `id`
- Sorted applied deals lexicographically
- Versioned: `digest_version` must be included and bumped on schema change

### 5.2 Golden update rules
Any golden change must include:
- updated digest(s)
- one-line rationale per digest
- proof: two consecutive runs match bit-for-bit (same seed + same script)

---

## 6) Failure Repro Bundle (single payload contract)

On any test failure, print exactly one JSON object (or a single JSONL line) containing:
- `seed`, `floor_num`, `turn`, `phase`, `run_state`
- `last_input`, `pending_offer`
- `last_events` (<= 20)
- `digest`, `digest_version`
- `caps_hit` (bool)
- optional: `world_snapshot_path` (if dumped deterministically)

---

## 7) Deal Catalog Contract (frozen IDs + downside proof)

- ID format: `<sin>.<index>` (e.g., `wrath.1`)
- Exactly 7 sins × 3 deals each = 21 total
- After Gate C passes: append-only (no renames/remaps)

**Downside standard (per deal)**
- Run identical deterministic script twice:
  - baseline (no deal)
  - with deal applied
- Assert at least one metric flips as expected:
  - damage taken / HP lost
  - turns-to-kill
  - visibility count / FOV constraints
  - forced behavior / action denial / added risk

---

## 8) Milestones (bead-sized, with dependencies + exit tests)

### M0 — Contract Package + Harness (critical path; unblocks all streams)
**Depends on:** nothing  
**Exit:** single proof command passes; determinism mini-test passes

### M1 — Core Sim (tiny fixed map end-to-end)
**Depends on:** M0  
**Exit:** smoke test: player kills enemy, no caps, digest stable

### M2 — Floors + FOV
**Depends on:** M0 (and ideally M1 for integration)  
**Exit:** floor invariants across bounded seeds; FOV goldens green

### M3 — Deals System + 21 Deals + Downside Enforcement
**Depends on:** M1 (hooks + step integration), M0 (contract)  
**Exit:** `deals_loader_spec` + `deals_downside_spec` green

### M4 — Enemies + Boss + Win/Lose
**Depends on:** M1 + M2  
**Exit:** scripted seeds reach both `victory` and `death`

### M5 — Minimal UX (UI only; no sim logic)
**Depends on:** M0 + M3 (deal modal needs offer/apply)  
**Exit:** manual checklist on a known seed; UI only emits inputs to `step()`

### M6 — Full-run determinism (S1–S3 scripts + goldens)
**Depends on:** M1–M4 (and M3)  
**Exit:** Gates A + B pass for `S1,S2,S3` (two consecutive runs match)

### M7 — Balance surface (separate from correctness)
**Depends on:** M3–M4  
**Exit:** single tuning surface file; 3 recorded seeded runs added to fixtures/docs

---

## 9) Parallel Workstreams (ownership + crisp DoD)

### Stream I — Integrator (M0 owner)
- I0: `RUN_BARGAIN_TESTS` hook + runner + exit codes
  - DoD: headless run, stable repro bundle, zero UI boot

### Stream C — Core Sim (M1 owner)
- C1: grid + deterministic helpers (neighbor order, stable sorts)
- C2: turn system + phase machine + caps (table-driven tests)
- C3: combat + ordering (no RNG leakage)
- C4: `step()` glue + smoke test script

### Stream F/V — Floors + FOV (M2 owner)
- F1: invariants tests first (connectivity, spawn/stairs constraints, caps)
- F2: procgen that satisfies invariants under bounded seeds
- V1: FOV implementation + goldens (occluders/corridor/empty)

### Stream D — Deals (M3 owner)
- D0: offer generation + apply plumbing + gating tests
- D1–D7: one sin per bead (3 deals + downside rows)

### Stream A — Enemies + Boss (M4 owner)
- A1: enemy templates schema + load tests
- A2: AI chase/attack + determinism tie-break tests
- A3: boss behavior + victory condition tests

### Stream R — Determinism + Goldens (M6 owner)
- R1: digest + tests + `digest_version` policy
- R2: full scripts + goldens for `S1,S2,S3` (+ rationale per change)

### Stream UI — Minimal UI/Bridge (M5 owner)
- UI0: deal modal + input mapping to `deal_choose/deal_skip`
- UI1: HUD + victory/death + restart plumbing

---

## 10) Risks (each must have a test mitigation)

- Lua iteration nondeterminism → ordered iter helpers + static scan suite
- Hidden randomness/time in bridge/UI → headless suite never boots UI
- Procgen infinite loops/unreachable stairs → attempt caps + invariant tests + seed repro
- “Downside exists but is toothless” → downside suite must flip a concrete metric
- Golden churn → digest versioning + rationale-per-change + double-run proof

---

## 11) Execution Workflow (Beads + multi-agent coordination)

- Triage with BV; only claim beads that have clear DoD and an owner.
- Claim bead → set `in_progress`.
- Reserve paths exclusively (Agent Mail) before edits; prefer low-collision zones.
- Implement + add/extend tests in the suite list (§4.2).
- Close bead → notify dependent streams (Agent Mail) with:
  - what changed
  - which gates/suites to rerun
  - whether goldens changed (and rationale)
- Run UBS before committing; keep commits small and stream-scoped.