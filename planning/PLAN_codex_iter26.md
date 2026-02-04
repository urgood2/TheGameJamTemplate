# Game #4 “Bargain” — Engineering Plan (v14: contracts + CI proof + stream-parallel)

> **MVP ship goal:** a **deterministic, replayable 7-floor run** where **Bargains** are the primary progression mechanic and every run ends in **victory** or **death** (no softlocks), proven by **one CI-gated command**.

---

## 0) Definition of Done (DoD)

### 0.1 One proof command (local + CI)
**Command sequence**
1. Build: `just build-debug-fast`
2. Headless test run: `RUN_BARGAIN_TESTS=1 ./build-debug/raylib-cpp-cmake-template`

**Pass criteria**
- Process exits `0`
- Headless mode: **no window created** and **no render loop entered**
- All Bargain suites pass
- On failure: exits non-zero and prints **exactly one** machine-parseable JSON repro payload (see §8)

### 0.2 CI gates (hard requirements)
| Gate | Requirement | Exact check |
|---|---|---|
| A Determinism | same seed+script → identical digest | run each seed/script twice; compare digest strings |
| B Termination | run ends in `victory` or `death` | assert `run_state ∈ {"victory","death"}` |
| C Deals catalog | exactly 21 deals, stable IDs | load deals; count=21; IDs unique; sins×3 complete |
| D Downside enforcement | each deal has measurable downside | baseline vs applied metric assertions (table-driven) |
| E No nondeterminism | forbid banned APIs & unstable iteration | static scan + runtime guardrails |
| F Repro fidelity | one failing test → one repro bundle | stdout contains single-line JSON object; exit non-zero |

### 0.3 Explicit non-goals (MVP)
- inventory/shops/save-load/meta progression
- balance polish beyond “not broken”
- sophisticated pathfinding beyond deterministic chase/attack

---

## 1) Repo & Collaboration Contracts (optimize for parallel work)

### 1.1 “Hot” shared files (integrator-owned)
Only these are expected to have frequent concurrent touches; everything else must live in low-collision zones.

- `assets/scripts/core/main.lua`
  - add **early** `RUN_BARGAIN_TESTS` hook (before any engine/window init)
- `assets/scripts/tests/run_bargain_tests.lua`
  - registers suites, runs, prints repro payload on failure, sets exit code

### 1.2 Low-collision zones (everyone else)
- Sim core: `assets/scripts/bargain/sim/**`
- Data: `assets/scripts/bargain/data/**`
- Systems: `assets/scripts/bargain/**` (non-sim helpers allowed, but determinism rules apply if they affect gameplay)
- Tests: `assets/scripts/tests/bargain/**`
- Goldens: `assets/scripts/tests/bargain/goldens/**`

### 1.3 Integration rule: stub-first, then fill
To keep streams unblocked:
- Land **interfaces + contract tests** first (even if implementations are minimal).
- Streams implement behind the interface without editing other streams’ files.
- Only integrator resolves cross-stream wiring in the two “hot” files.

---

## 2) Frozen Interfaces (contract-tested; all streams code against these)

### 2.1 World schema (minimum required)
Required fields (stable):
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

### 2.2 Entity schema (minimum required)
- `id`, `kind` (`"player"|"enemy"|"boss"`)
- `x`, `y`
- `hp`, `hp_max`
- `atk`, `def`, `speed`, `fov_radius`
- `xp`, `level`
- `flags` (deterministically serialized set)
- `hooks` (`hook_name -> array`, stable order)

### 2.3 Offer schema (stable order; no `pairs()` ordering)
`world.deals.pending_offer`:
- `kind ∈ {"floor_start","level_up"}`
- `offers: [deal_id...]` (deterministic order)
- `must_choose: bool`
- `can_skip: bool`

### 2.4 Input API (frozen)
`step(world, input)` supports exactly:
- `{type="move", dx=0|±1, dy=0|±1}`
- `{type="attack", dx=0|±1, dy=0|±1}`
- `{type="wait"}`
- `{type="deal_choose", deal_id="..."}`
- `{type="deal_skip"}`

**Error semantics (frozen, testable)**
- Invalid input returns `{ok=false, err="..."}` and consumes the actor’s turn.
- Must not break invariants; must not crash; must remain deterministic.

### 2.5 Phase machine (frozen; table-driven)
Phases:
`DEAL_CHOICE → PLAYER_INPUT → PLAYER_ACTION → ENEMY_ACTIONS → END_TURN → PLAYER_INPUT`

Rules:
- Forced offers pin `DEAL_CHOICE` until a choice is made.
- Enemy action order: `speed desc`, tie-break `id asc`.
- Canonical direction order: `N, E, S, W` (diagonals disallowed for MVP unless explicitly added later).

---

## 3) Determinism Rules (non-negotiable; enforced by tests)

### 3.1 RNG rules
- Only `world.rng` can generate randomness.
- Forbidden in gameplay logic: `math.random`, time-based seeds, frame `dt`, engine globals, unordered iteration that affects outcomes.

### 3.2 Stable iteration rules
- No gameplay-critical `pairs()`/`next()` in sim-critical modules.
- “Order matters” collections must be:
  - arrays in fixed order, or
  - explicitly sorted with deterministic comparator + tie-breakers.

### 3.3 Caps & termination guarantees
Constants (contract-tested; tune later):
- `MAX_INTERNAL_TRANSITIONS` (start `64`)
- `MAX_STEPS_PER_RUN` (start `5000`)
- procgen attempt caps per floor with deterministic fallback

**Behavior on cap trip (must be deterministic)**
- set `world.caps_hit=true`
- set `world.run_state` terminal (default `"death"` unless agreed otherwise)
- emit repro bundle (§8)

---

## 4) Test Strategy (CI-friendly, failure-localizing, low churn)

### 4.1 Test runner contract
Entry: `assets/scripts/tests/run_bargain_tests.lua`
- uses existing runner (`describe/it/expect`)
- stable stdout: suite output + (on failure) **exactly one** repro JSON line
- exits `0` on success; non-zero on any failure

### 4.2 Required suite inventory (each is a bead-sized deliverable)
**Contracts & harness**
- `assets/scripts/tests/bargain/contracts_spec.lua`
  - schema validation, phase rules, invalid-input semantics, cap behavior
- `assets/scripts/tests/bargain/determinism_static_spec.lua`
  - static scan: ban nondeterministic APIs + ban `pairs()` in sim-critical modules
- `assets/scripts/tests/bargain/digest_spec.lua`
  - digest stable across reruns; version bump rules; stable serialization checks

**Core behavior**
- `assets/scripts/tests/bargain/sim_smoke_spec.lua`
  - tiny fixed map: move/attack/turn loop; terminates; digest stable
- `assets/scripts/tests/bargain/ai_spec.lua`
  - deterministic targeting, tie-breakers, action order

**World-gen & visibility**
- `assets/scripts/tests/bargain/floors_spec.lua`
  - bounded seed set: invariants (stairs reachable, connectivity, spawn constraints), deterministic fallback on cap hit
- `assets/scripts/tests/bargain/fov_spec.lua`
  - golden visible-set tests on canonical maps

**Deals**
- `assets/scripts/tests/bargain/deals_loader_spec.lua`
  - 21 deals exist, IDs valid/unique, sins×3 coverage
- `assets/scripts/tests/bargain/deals_downside_spec.lua`
  - 21 table rows; each row asserts at least one downside metric flips

**End-to-end determinism**
- `assets/scripts/tests/bargain/run_scripts_spec.lua`
  - full-run scripts `S1,S2,S3` + golden digests; determinism gate A; termination gate B

### 4.3 Golden protocol (minimize churn)
- Goldens live under `assets/scripts/tests/bargain/goldens/**`
- Any golden update requires:
  - updated golden file(s)
  - a one-line rationale per change (kept adjacent to the golden)
  - proof: two consecutive runs match for the same seed/script

---

## 5) Deals Catalog Contract (stable IDs + downside proof)

### 5.1 IDs and cardinality (freeze once Gate C is green)
- ID format: `<sin>.<index>` (e.g., `wrath.1`)
- Exactly `7 sins × 3 deals = 21`
- After freeze: append-only (no renames/remaps; only additive metadata allowed)

### 5.2 Downside standard (CI-testable, per deal)
For each deal:
- run identical deterministic script twice:
  - baseline (deal not applied)
  - applied (deal applied at earliest legal moment)
- assert at least one metric flips, using a standardized metric set (all metrics must have precise definitions in code/tests):
  - `hp_lost_total`
  - `turns_elapsed`
  - `damage_dealt_total` and/or `damage_taken_total`
  - `kills_required` (if relevant)
  - `visible_tiles_count` (if FOV-related)
  - `forced_actions_count` / `denied_actions_count` (if input constraints exist)

---

## 6) Milestones (dependency-ordered; each ends with specific green tests)

### M0 — Headless harness + contracts (critical path)
**Deliverables**
- `RUN_BARGAIN_TESTS` early-exit hook (no window)
- Bargain test runner and repro bundle plumbing
- `contracts_spec` + `sim_smoke_spec` minimal green

**Exit tests**
- Proof command (§0.1) passes
- `contracts_spec` and `sim_smoke_spec` pass on clean checkout

### M1 — Core sim loop (tiny fixed map end-to-end)
**Deliverables**
- deterministic step loop + combat + caps wiring + event/message append-only channels
- digest function + stable serialization rules

**Exit tests**
- `sim_smoke_spec` covers: move, attack, enemy acts, termination without caps
- `digest_spec` verifies stable digest across repeated runs

### M2 — Floors + FOV (invariants-first)
**Deliverables**
- procgen that guarantees stairs reachability (or deterministic cap+fallback)
- FOV implementation with canonical golden maps

**Exit tests**
- `floors_spec` passes for bounded seeds (e.g., 20 seeds, fixed list)
- `fov_spec` goldens green

### M3 — Deals system + 21 deals + downside enforcement
**Deliverables**
- offer generation points (`floor_start`, `level_up`)
- apply plumbing for deal hooks
- complete 21-deal catalog + loader

**Exit tests**
- `deals_loader_spec` green (21 IDs, sins×3 coverage)
- `deals_downside_spec` green (21/21 flips ≥1 metric)

### M4 — Enemies + boss + win/lose
**Deliverables**
- deterministic enemy templates + AI chase/attack
- boss + explicit victory condition on floor 7

**Exit tests**
- scripted scenarios reach both `victory` and `death`
- `ai_spec` deterministic ordering + tie-breakers

### M5 — Minimal UI bridge (UI only; sim remains headless-testable)
**Deliverables**
- deal modal UI maps to `deal_choose` / `deal_skip`
- HUD + victory/death screen + restart

**Exit tests**
- manual checklist on a known seed
- static scan ensures no gameplay logic in UI layer (scope-defined)

### M6 — Full-run scripts + determinism goldens (release confidence)
**Deliverables**
- scripts `S1,S2,S3` (fixed input sequences + expected terminal outcomes)
- golden digests for each script + seed

**Exit tests**
- `run_scripts_spec` green for all scripts
- CI Gate A + B green (two consecutive runs match; termination guaranteed)

### M7 — Balance surface (post-correctness)
**Deliverables**
- single tuning surface for numeric knobs
- 3 recorded seeded runs added to fixtures/docs (non-blocking for correctness)

**Exit tests**
- tuning changes do not require golden churn except when intended (documented)

---

## 7) Parallel Workstreams (minimal collisions + explicit handoffs)

### Stream I — Integrator (M0)
**Owns**
- `assets/scripts/core/main.lua`
- `assets/scripts/tests/run_bargain_tests.lua`
**Delivers**
- headless hook, runner wiring, repro bundle contract

### Stream C — Core sim (M1)
**Owns**
- `assets/scripts/bargain/sim/**`
- `assets/scripts/tests/bargain/sim_smoke_spec.lua`
- `assets/scripts/tests/bargain/contracts_spec.lua` (shared with integrator only via agreed contract changes)

### Stream F/V — Floors + FOV (M2)
**Owns**
- `assets/scripts/bargain/floors/**`, `assets/scripts/bargain/fov/**`
- `assets/scripts/tests/bargain/floors_spec.lua`
- `assets/scripts/tests/bargain/fov_spec.lua`

### Stream D — Deals (M3)
**Owns**
- `assets/scripts/bargain/data/deals/**`
- `assets/scripts/bargain/deals/**`
- `assets/scripts/tests/bargain/deals_loader_spec.lua`
- `assets/scripts/tests/bargain/deals_downside_spec.lua`

### Stream A — Enemies + boss (M4)
**Owns**
- `assets/scripts/bargain/enemies/**`, `assets/scripts/bargain/ai/**`
- `assets/scripts/tests/bargain/ai_spec.lua`

### Stream R — Digest + scripts + goldens (M1→M6)
**Owns**
- `assets/scripts/bargain/sim/digest/**`
- `assets/scripts/tests/bargain/digest_spec.lua`
- `assets/scripts/tests/bargain/run_scripts_spec.lua`
- `assets/scripts/tests/bargain/goldens/**`

### Stream UI — Minimal UI bridge (M5)
**Owns**
- UI layer only (must not contain sim logic)
**Constraint**
- UI emits inputs to `step()` only; never mutates world directly

---

## 8) Failure Repro Bundle (single payload contract)

### 8.1 Output contract
On any test failure:
- print **exactly one** JSON object to stdout (single line; JSONL style)
- exit non-zero

### 8.2 Payload fields (minimum)
- `seed`, `floor_num`, `turn`, `phase`, `run_state`
- `last_input`, `pending_offer`
- `last_events` (<= 20; deterministic order)
- `digest`, `digest_version`
- `caps_hit` (bool)
- optional: `world_snapshot_path` (only if dump path is deterministic)

### 8.3 Snapshot rules (if used)
- snapshot filename deterministic from `(seed, script_id, turn)`
- serializer must enforce stable key ordering (no raw table iteration order)

---

## 9) Risks → Required Mitigations (must be test-backed)

- Lua iteration nondeterminism → ordered-iteration helpers + `determinism_static_spec`
- Hidden randomness/time in bridge/UI → headless suite must never boot UI; static scan bans time/RNG in sim scopes
- Procgen infinite loops/unreachable stairs → attempt caps + `floors_spec` invariants + deterministic fallback + repro payload
- “Downside exists but is toothless” → `deals_downside_spec` requires metric flip per deal
- Golden churn → digest versioning + rationale-per-change + double-run proof in CI

---

## 10) Beads + Coordination Workflow (operational)

- Triage with BV; only claim beads with explicit exit tests from §4/§6.
- Claim bead → set `in_progress`.
- Reserve paths (exclusive) before edits; prefer low-collision zones in §1.2.
- Implement + ship tests in the same bead.
- Close bead → notify dependents via Agent Mail:
  - what changed (files + contracts touched)
  - which suites/gates to rerun
  - whether goldens changed (and why)
- Run UBS before committing; keep commits small and stream-scoped.