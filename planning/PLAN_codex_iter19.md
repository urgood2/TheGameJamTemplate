```md
# Game #4 “Bargain” — Engineering Plan (v7: executable contracts, test-first gates, low-collision parallel work)

> Product goal: ship a deterministic, replayable **7-floor** run where **Bargains** are the primary progression mechanic, with **hard gates** for determinism, termination, and no softlocks.

---

## 0) Ship Criteria (what “done” means)

### 0.1 MVP (player-visible)
A complete **7-floor run** under `seed + scripted inputs`:
- Floors **1–6**: explore/combat → find **stairs** → descend.
- Floor **7**: boss (“Sin Lord”) → **victory** on defeat.
- Player HP ≤ 0 → **death** state → restart → new seeded run.
- Bargains:
  - **Floor start**: forced offer (must choose; cannot proceed otherwise).
  - **Level up**: optional offer (may skip).

### 0.2 Hard success metrics (gates)
- **Determinism:** fixtures `S1,S2,S3` produce **bit-for-bit identical digests** vs goldens (two consecutive runs match).
- **Termination:** `S1–S3` end in `victory|death` with **no caps hit** and no stuck phases.
- **Deal completeness:** exactly **21 deals** (`7 sins × 3`) with stable IDs and stable sin mapping.
- **Downside enforcement:** **21/21** deals have tests that fail if the downside is removed or becomes non-impactful.
- **Runtime:** the `S1–S3` suite finishes under an explicit cap (set once harness exists; tighten later).

### 0.3 Non-goals (explicitly deferred)
Inventory/shops/meta progression/save-load; polish VFX/audio; advanced pathfinding.

---

## 1) Contracts (must be enforced by tests)

### 1.1 Determinism contract
- **Sim purity:** all gameplay rules live in Lua sim modules; no IO, rendering, time/dt, engine globals.
- **Single RNG:** `world.rng` is the only randomness source; ban `math.random` (and engine RNG) in sim.
- **Stable iteration:** no `pairs()` / `next()` in rule-sensitive sim; use arrays + explicit sort; all tie-breakers explicit (e.g., `id asc`).
- **Canonical neighbor order:** globally frozen as **N, E, S, W**.

### 1.2 Termination / safety contract
- `step()` is bounded by `MAX_INTERNAL_TRANSITIONS` (e.g., 64) and subsystem attempt caps (procgen/AI).
- Whole-run cap in tests: `MAX_STEPS_PER_RUN` (e.g., 5000).
- Invalid input must never crash:
  - returns `{ok=false, err="..."}`
  - consumes the actor’s turn
  - invariants remain valid (no half-applied state).

### 1.3 Merge-safety contract (parallel work without collisions)
- Keep edits to hot files minimal (only test hook + wiring if needed).
- All new Bargain work stays in:
  - `assets/scripts/bargain/**`
  - `assets/scripts/tests/bargain/**`
  - `assets/scripts/tests/run_bargain_tests.lua`

---

## 2) Test Harness (single-command, failure-localizing)

### 2.1 One command to run everything
- Env: `RUN_BARGAIN_TESTS=1`
- Invocation: `RUN_BARGAIN_TESTS=1 <game_binary>` (must exit non-zero on failure)

### 2.2 Minimal hook
- Add an early hook in `assets/scripts/core/main.lua` that:
  - detects `RUN_BARGAIN_TESTS=1`
  - runs Bargain suite
  - exits before heavy UI boot

### 2.3 Suite layout (explicit files)
- Entrypoint: `assets/scripts/tests/run_bargain_tests.lua`
- Tests:
  - `assets/scripts/tests/bargain/test_contracts.lua` (schemas, phases, inputs, caps, offer gating)
  - `assets/scripts/tests/bargain/test_static_guards.lua` (scan sim subtree: no `pairs(`, no `math.random`, no time/IO)
  - `assets/scripts/tests/bargain/test_grid.lua`
  - `assets/scripts/tests/bargain/test_turn_system.lua`
  - `assets/scripts/tests/bargain/test_combat.lua`
  - `assets/scripts/tests/bargain/test_fov.lua`
  - `assets/scripts/tests/bargain/test_enemy_ai.lua`
  - `assets/scripts/tests/bargain/test_floors_invariants.lua`
  - `assets/scripts/tests/bargain/test_data_loading.lua`
  - `assets/scripts/tests/bargain/test_deals_downsides.lua` (table-driven 21 rows)
  - `assets/scripts/tests/bargain/test_smoke.lua`
  - `assets/scripts/tests/bargain/test_determinism.lua` (S1–S3 full-run digests)

### 2.4 Fixtures (versioned + reviewable)
- `assets/scripts/tests/bargain/fixtures/seeds.lua` (`S1,S2,S3`)
- `assets/scripts/tests/bargain/fixtures/scripts.lua` (scripted inputs + offer decisions)
- `assets/scripts/tests/bargain/fixtures/expected_digests.lua` (goldens + 1-line rationale per change)

### 2.5 Failure output contract (repro bundle)
Any failing integration/determinism test prints:
`{seed,floor_num,turn,phase,run_state,last_input,pending_offer,last_events(20),digest,caps_hit?}`

---

## 3) Interface Freeze (M0 contract; enables parallel work)

### 3.1 World schema (contract-tested)
Required:
- `world.grid`, `world.entities (id->entity)`, `world.player_id`
- `world.turn`, `world.phase`, `world.floor_num (1..7)`, `world.run_state ("playing"|"victory"|"death")`
- `world.rng`
- `world.deals.applied (deal_id->true)`, `world.deals.history (array)`, `world.deals.pending_offer (nil|offer)`

Recommended (debug + deterministic output):
- `world.stairs`, `world.events` (append-only), `world.messages` (append-only)

### 3.2 Entity schema (contract-tested)
- `id`, `kind ("player"|"enemy"|"boss")`, `x`,`y`
- `hp`,`hp_max`,`atk`,`def`,`speed`,`fov_radius`
- `xp`,`level`
- `flags` (order-independent)
- `hooks` (hook_name → array; explicit stable order)

### 3.3 Offer struct (array-only, stable order)
`world.deals.pending_offer`:
- `kind ∈ {"floor_start","level_up"}`
- `offers: [deal_id...]`
- `must_choose: bool`
- `can_skip: bool`

### 3.4 Input API (contract-tested)
`step(world, input)` supports:
- `{type="move", dx=0|±1, dy=0|±1}`
- `{type="attack", dx=0|±1, dy=0|±1}`
- `{type="wait"}`
- `{type="deal_choose", deal_id="..."}`
- `{type="deal_skip"}`

### 3.5 Phase machine (frozen + tested)
Phases: `DEAL_CHOICE → PLAYER_INPUT → PLAYER_ACTION → ENEMY_ACTIONS → END_TURN → PLAYER_INPUT`
Rules:
- Forced offers pin `DEAL_CHOICE` until chosen.
- Enemy order: `speed desc`, tie-break `id asc`.

---

## 4) Digest Spec (determinism oracle)

### 4.1 Canonical digest payload (no map iteration)
Serialize in fixed order:
- `floor_num, turn, phase, run_state`
- player tuple: `(x,y,hp,hp_max,xp,level,atk,def,speed,fov_radius)`
- entities: sorted by `id`, each `(id,kind,x,y,hp,selected_flags)`
- applied deals: sorted lexicographically
- optional: compact `deals.history` summary (only if needed for stability)

### 4.2 Script runner rules (test-owned)
Loop:
- if `pending_offer`: consume next scripted `deal_choose|deal_skip`
- else: consume next scripted `move|attack|wait`
Stop on `victory|death`, fail on caps, return digest.

---

## 5) Module Boundaries (parallel-safe)

### 5.1 Sim API exports (frozen)
- `assets/scripts/bargain/sim/world.lua`
  - `new_run(seed, opts) -> world`
  - `new_floor(world, floor_num) -> world` (or pure build + apply)
- `assets/scripts/bargain/sim/step.lua`
  - `step(world, input) -> {world, events, ok, err?}`

### 5.2 Core modules (each must ship with unit tests)
- `assets/scripts/bargain/sim/grid.lua`
- `assets/scripts/bargain/sim/turn_system.lua`
- `assets/scripts/bargain/sim/combat.lua`
- `assets/scripts/bargain/sim/fov.lua`
- `assets/scripts/bargain/sim/floors.lua` + `assets/scripts/bargain/data/floors.lua`
- `assets/scripts/bargain/sim/enemy_ai.lua` + `assets/scripts/bargain/data/enemies.lua`
- `assets/scripts/bargain/sim/deals.lua` + `assets/scripts/bargain/data/sins/*.lua`

### 5.3 Bridge (minimal integrator touch)
- `assets/scripts/bargain/game.lua` orchestrates sim + UI; no randomness/time.

---

## 6) Milestones (deliverables + exit tests)

### M0 — Harness + contracts (must land first)
Deliver:
- `RUN_BARGAIN_TESTS=1` hook + suite entrypoint
- stub modules with correct exports
- contract + static guard tests
Exit:
- `test_contracts` + `test_static_guards` pass
- a tiny fixture produces identical digest twice

### M1 — Core sim loop on fixed tiny map
Deliver:
- deterministic move/collision, turn system + caps, combat + ordering
Exit:
- `test_smoke`: player kills 1 enemy on fixed 5×5 under fixed script

### M2 — Floors + FOV invariants (bounded procgen)
Deliver:
- floor generator for floors 1–7 with deterministic attempt caps + deterministic fallback behavior
- deterministic FOV visible set
Exit:
- `test_floors_invariants` passes over bounded seeds (start at 50); failures print seed repro

### M3 — Deals system + 21 deals + downside enforcement
Deliver:
- forced floor-start offers + optional level-up offers
- 21 deals implemented (benefit + enforced downside via hooks)
Exit:
- Gate B/C/D all pass (`test_deals_downsides` table has 21 rows and all flip a measurable outcome)

### M4 — Enemies + boss + win/lose transitions
Deliver:
- enemy templates + deterministic AI
- floor 7 boss + victory condition
Exit:
- `test_enemy_ai` determinism, plus integration that reaches victory and death paths

### M5 — Minimal UX flows (no sim logic)
Deliver:
- deal modal (forced vs optional), HUD, victory/death + restart
Exit:
- manual checklist on known seed; confirm bridge/UI does not mutate sim directly

### M6 — Full-run determinism (S1–S3)
Deliver:
- scripts + goldens for full 7-floor runs
Exit:
- Gate A + Gate E pass reliably for `S1,S2,S3` (two consecutive runs match bit-for-bit)

### M7 — Balance surface (last; separate from correctness)
Deliver:
- `assets/scripts/bargain/data/balance.lua` as the only tuning surface
Exit:
- 3 recorded seeded runs (seed + script + outcome + duration) documented in data/fixtures

---

## 7) Parallel Work Breakdown (bead-sized, low-collision)

### 7.1 Dependency graph
- **M0 blocks everything.**
- After M0 lands, these proceed in parallel: M1 core sim, M2 floors/FOV, M3 deals, M4 AI/boss, M6 digest/scripts pieces, M5 UI wiring.

### 7.2 Bead units (each includes tests + explicit DoD)
- Integrator:
  - I0: hook + `run_bargain_tests.lua` + minimal smoke wiring (DoD: suite runs and returns correct exit code)
- Sim core:
  - C1: `grid.lua` + unit tests (neighbor order, occupancy, sorted helpers)
  - C2: `turn_system.lua` + unit tests (phase progression, invalid input consumes turn, caps)
  - C3: `combat.lua` + unit tests (damage math, RNG usage discipline)
  - C4: `step.lua` glue + smoke
- Floors/FOV:
  - F1: invariants tests first (reachability, spawn constraints, cap behavior)
  - F2: procgen implementation satisfying invariants under bounded seeds
  - V1: `fov.lua` + unit tests (occlusion determinism, stable visible set)
- AI/Boss:
  - A1: enemies schema + load test
  - A2: AI chase/attack + determinism tie-break tests
  - A3: boss behavior + floor 7 win condition tests
- Deals:
  - D0: `deals.lua` core (offer generation + apply plumbing) + offer gating tests
  - D(1–7): one sin per bead: `data/sins/<sin>.lua` with 3 deals + 3 downside test rows
- Determinism:
  - R1: digest implementation + unit/integration tests
  - R2: full scripts + goldens for `S1–S3` (+ rationale per change)

---

## 8) Change Control (prevents churn)

### 8.1 Append-only freezes (after first landing)
- Deal IDs + `sin` mapping are append-only once “21 deals exist” gate is met.
- Enemy IDs + boss ID are append-only once M4 lands.
- Digest schema changes require explicit rationale and/or versioning.

### 8.2 Golden update protocol
Any change to `assets/scripts/tests/bargain/fixtures/expected_digests.lua` must include:
- updated digest values
- a 1-line rationale per digest change
- confirmation that two consecutive runs match bit-for-bit

### 8.3 PR checklist (minimum)
- Adds/updates tests for the change.
- Runs `RUN_BARGAIN_TESTS=1 <game_binary>` locally.
- No forbidden patterns introduced in sim subtree (`pairs`, `math.random`, time/IO).
- Determinism-impacting changes include explicit tie-breaker reasoning.

---

## 9) Risks + test-enforced mitigations
- Lua table iteration nondeterminism → sorted iteration helpers + static scan tests.
- Hidden randomness/time in bridge/UI → headless determinism tests (no UI dependency).
- Procgen infinite loops/unreachable stairs → attempt caps + invariant tests with seed repro.
- “Downside exists but is toothless” → downside tests must flip a concrete outcome under a fixed script.

---

## 10) Repo workflow (Beads + coordination)
- Beads:
  1) Triage with BV
  2) Claim bead (`in_progress`)
  3) Implement + tests (suite must pass)
  4) Close bead + notify via Agent Mail
- Before editing: reserve paths exclusively via Agent Mail (keep beads small + low-collision).
```