# Game #4 “Bargain” — Engineering Plan (v9: gated contracts, test-first milestones, low-collision parallel tracks)

> **Ship goal:** a **deterministic, replayable 7-floor run** where **Bargains** are the primary progression mechanic, ending in **victory or death** with **no softlocks**.

---

## 1) Definition of Done (Ship Criteria)

### 1.1 Player-visible MVP (7-floor run)
- Floors **1–6**: explore/combat → find **stairs** → descend.
- Floor **7**: boss (“Sin Lord”) → **victory** on defeat.
- Player HP ≤ 0 → **death** state → restart → new seeded run.
- Bargains:
  - **Floor start**: **forced** offer (must choose; cannot proceed otherwise).
  - **Level up**: **optional** offer (may skip).

### 1.2 Hard gates (must be green to ship)
| Gate | Requirement | How it’s measured |
|---|---|---|
| A — Determinism | S1/S2/S3 produce identical digests | `RUN_BARGAIN_TESTS=1 <game_binary>`; determinism suite runs **twice** per seed and compares to goldens |
| B — Termination | S1–S3 end in `victory|death` with no caps hit | Run scripts to completion; assert `caps_hit=false` and final `run_state ∈ {victory, death}` |
| C — Deal completeness | **21 deals** (7 sins × 3), stable IDs + mapping | Data loader test enumerates deals and validates IDs + sin mapping |
| D — Downside enforcement | **21/21** deals have a downside that measurably matters | Table-driven tests fail if downside removed or becomes no-op |
| E — One-command suite | Single command, clean exit codes, repro bundle on failure | Exit **0** on pass, **non-zero** on fail; prints structured repro payload |

### 1.3 Explicit non-goals (deferred)
- Inventory/shops/meta progression/save-load
- VFX/audio polish
- Advanced pathfinding
- Balance iteration beyond “not broken”

---

## 2) Contracts (Executable + Frozen Early)

### 2.1 Determinism contract (enforced by tests)
**Sim purity**
- All gameplay rules live in pure Lua sim modules: **no IO**, **no rendering**, **no time/dt**, **no engine globals**.

**RNG**
- Single RNG: `world.rng` is the only randomness source.
- Forbidden in sim subtree: `math.random`, engine RNG, or hidden randomness helpers.

**Iteration + ordering**
- No `pairs()` / `next()` where order affects gameplay. Use arrays or sorted key lists.
- Tie-breakers are explicit everywhere ordering matters (example standard: `speed desc`, tie `id asc`).
- Canonical directions and neighbor order: **N, E, S, W** (frozen constant).

### 2.2 Termination / safety contract (enforced by tests)
- `step()` bounds internal transitions: `MAX_INTERNAL_TRANSITIONS` (start **64**, tune with evidence).
- Whole-run bounds in tests: `MAX_STEPS_PER_RUN` (start **5000**, tune with evidence).
- Invalid input must never crash:
  - returns `{ok=false, err="..."}`
  - consumes the actor’s turn (prevents retry loops)
  - world invariants remain valid (no half-applied state)

### 2.3 Merge-safety contract (directory boundaries)
- Keep edits to hot engine/bridge files minimal (single test hook + wiring).
- All Bargain sim/data work stays in:
  - `assets/scripts/bargain/**`
  - `assets/scripts/tests/bargain/**`
  - `assets/scripts/tests/run_bargain_tests.lua`

---

## 3) Frozen Interfaces (Enables Parallel Work)

### 3.1 World schema (contract-tested)
Required:
- `world.grid`
- `world.entities` (`id -> entity`)
- `world.player_id`
- `world.turn`, `world.phase`, `world.floor_num (1..7)`
- `world.run_state ("playing"|"victory"|"death")`
- `world.rng`
- `world.deals.applied (deal_id->true)`
- `world.deals.history (array)`
- `world.deals.pending_offer (nil|offer)`

Recommended (debug + stable output):
- `world.stairs`
- `world.events` (append-only array)
- `world.messages` (append-only array)

### 3.2 Entity schema (contract-tested)
- `id`, `kind ("player"|"enemy"|"boss")`, `x`, `y`
- `hp`, `hp_max`, `atk`, `def`, `speed`, `fov_radius`
- `xp`, `level`
- `flags` (order-independent set; serialized deterministically)
- `hooks` (`hook_name -> array`, stable order)

### 3.3 Offer struct (array-only, stable)
`world.deals.pending_offer`:
- `kind ∈ {"floor_start","level_up"}`
- `offers: [deal_id...]` (deterministic order)
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
- Enemy order: `speed desc`, tie `id asc`.

---

## 4) Test Harness (One Command, Failure-Localizing)

### 4.1 One-command contract
- Env: `RUN_BARGAIN_TESTS=1`
- Invocation: `RUN_BARGAIN_TESTS=1 <game_binary>`
- Behavior:
  - runs suite
  - prints minimal repro bundle on failure
  - exits non-zero on any failure

### 4.2 Minimal hook (single touchpoint)
- Early detect `RUN_BARGAIN_TESTS=1`
- Run `assets/scripts/tests/run_bargain_tests.lua`
- Exit before UI boot

### 4.3 Suite layout (explicit)
Entrypoint:
- `assets/scripts/tests/run_bargain_tests.lua`

Test modules (minimum set; expand only as needed):
- `assets/scripts/tests/bargain/test_contracts.lua` (schemas, phases, offer gating, caps)
- `assets/scripts/tests/bargain/test_static_guards.lua` (forbidden patterns in sim subtree)
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

Fixtures:
- `assets/scripts/tests/bargain/fixtures/seeds.lua` (`S1,S2,S3`)
- `assets/scripts/tests/bargain/fixtures/scripts.lua` (scripted inputs + offer decisions)
- `assets/scripts/tests/bargain/fixtures/expected_digests.lua` (goldens + 1-line rationale per change)

### 4.4 Failure output contract (structured repro bundle)
On failure, print a single structured payload containing at least:
- `seed, floor_num, turn, phase, run_state`
- `last_input, pending_offer`
- `last_events(20)`
- `digest`
- `caps_hit?`
- (optional) `world_snapshot_path` if dumping is supported

---

## 5) Determinism Oracle (Digest Spec)

### 5.1 Canonical digest payload (fixed order; no map iteration)
Serialize deterministically:
- `floor_num, turn, phase, run_state`
- player tuple: `(x,y,hp,hp_max,xp,level,atk,def,speed,fov_radius)`
- entities: sorted by `id`, each `(id,kind,x,y,hp,selected_flags)`
- applied deals: sorted lexicographically
- optional: compact `deals.history` summary (only if needed for stability)

### 5.2 Script runner rules (test-owned)
Loop:
- if `pending_offer`: consume next scripted `deal_choose|deal_skip`
- else: consume next scripted `move|attack|wait`
Stop on `victory|death`, fail on caps, return final digest.

---

## 6) Milestones (Deliverables + Exit Tests)

### M0 — Harness + contracts (critical path)
Deliver:
- One-command test hook + suite entrypoint
- Contract tests + static guard tests
- Minimal sim stubs exporting frozen interfaces

Exit tests:
- `test_contracts` + `test_static_guards` pass
- A tiny fixture produces identical digest twice

### M1 — Core sim loop on fixed tiny map
Deliver:
- deterministic movement + collision
- turn system + caps + invalid-input semantics
- deterministic combat ordering
- `step` glue

Exit tests:
- `test_smoke`: player kills 1 enemy on fixed 5×5 under fixed script

### M2 — Floors + FOV invariants (bounded procgen)
Deliver:
- deterministic floor generator for floors 1–7 with attempt caps + deterministic fallback
- deterministic FOV visible set

Exit tests:
- `test_floors_invariants` over bounded seeds (start 50); failures print seed repro
- `test_fov` golden visible sets on at least 3 maps (empty, corridor, occluders)

### M3 — Deals system + 21 deals + downside enforcement
Deliver:
- forced floor-start offers + optional level-up offers
- 21 deals implemented (benefit + enforced downside via hooks)

Exit tests:
- `test_deals_downsides` has 21 rows; each row flips a measurable outcome under a fixed script
- `test_contracts` verifies forced offer blocks progression and optional offer can skip

### M4 — Enemies + boss + win/lose transitions
Deliver:
- enemy templates + deterministic AI
- floor 7 boss + victory condition; player death path

Exit tests:
- `test_enemy_ai` determinism (tie-breaks + stable targeting)
- integration scripts reach both `victory` and `death` on known seeds

### M5 — Minimal UX flows (no sim logic)
Deliver:
- deal modal (forced vs optional), HUD, victory/death + restart

Exit:
- manual checklist on a known seed; confirm bridge/UI never mutates sim directly (only via `step()`)

### M6 — Full-run determinism (S1–S3)
Deliver:
- scripts + goldens for full 7-floor runs

Exit tests:
- Gate A + Gate B pass for `S1,S2,S3` (two consecutive runs match bit-for-bit)

### M7 — Balance surface (separate from correctness)
Deliver:
- `assets/scripts/bargain/data/balance.lua` as the only tuning surface

Exit:
- 3 recorded seeded runs (seed + script + outcome + duration) added to fixtures/docs

---

## 7) Parallel Work Plan (Bead-Sized, Low Collision)

### 7.1 Dependency graph
- **M0 blocks everything.**
- After M0, parallel tracks:
  - **Track C:** core sim (M1)
  - **Track F/V:** floors + FOV (M2)
  - **Track D:** deals (M3)
  - **Track A:** enemies/boss (M4)
  - **Track R:** digest/scripts/goldens (M6 parts can start as soon as digest exists)
  - **Track UI:** minimal UX (M5)

### 7.2 Beads (each must ship with tests + explicit DoD)
**Integrator**
- I0: test hook + `run_bargain_tests.lua` + suite skeleton (DoD: correct exit codes + prints repro payload)

**Core sim**
- C1: `grid` + unit tests (neighbor order, occupancy, deterministic sort helpers)
- C2: `turn_system` + unit tests (phase progression, caps, invalid input consumes turn)
- C3: `combat` + unit tests (damage math, ordering, no RNG leakage)
- C4: `step` glue + smoke test

**Floors/FOV**
- F1: invariants tests first (connectivity, spawn/stairs constraints, cap behavior)
- F2: procgen implementation satisfying invariants under bounded seeds
- V1: `fov` + unit tests (occlusion determinism, stable visible set)

**Enemies/Boss**
- A1: enemy templates schema + load test
- A2: AI chase/attack + determinism tie-break tests
- A3: boss behavior + floor 7 win condition tests

**Deals**
- D0: deals core (offer generation + apply plumbing) + offer gating tests
- D1–D7: one sin per bead: 3 deals + 3 downside tests (table rows)

**Determinism**
- R1: digest implementation + unit/integration tests
- R2: full scripts + goldens for S1–S3 (+ rationale per change)

---

## 8) Deal Catalog Contract (IDs + Mapping Frozen)
- **ID format (frozen):** `<sin>.<index>` (example: `wrath.1`, `wrath.2`, `wrath.3`)
- **Mapping:** exactly 7 sins, each exactly 3 deals; data loader test enforces count + uniqueness.
- **Append-only rule:** once Gate C is met, IDs and sin mapping become append-only.

Downside test standard (per deal):
- Run a fixed script **with** the deal applied and **without** it applied.
- Assert at least one measurable metric changes in the expected direction (examples: HP lost, turns-to-kill, visibility count, damage dealt/taken, action availability).

---

## 9) Golden Update Protocol (Prevents Churn)
Any change to `expected_digests` must include:
- updated digest values
- a 1-line rationale per changed digest
- confirmation: two consecutive runs match bit-for-bit (same seed + script)

If digest schema must change:
- either bump a digest version field, or provide a migration note + updated goldens with rationale.

---

## 10) Risks + Test-Enforced Mitigations
- Lua table iteration nondeterminism → sorted iteration helpers + static scan tests.
- Hidden randomness/time in bridge/UI → headless determinism tests (no UI dependency).
- Procgen infinite loops/unreachable stairs → attempt caps + invariant tests with seed repro.
- “Downside exists but is toothless” → downside tests must flip a concrete outcome under a fixed script.

---

## 11) Repo Workflow (Beads + Coordination)
- **Beads**
  1) Triage with BV
  2) Claim bead (`in_progress`)
  3) Implement + tests (suite must pass)
  4) Close bead + notify via Agent Mail
- **Coordination**
  - Reserve paths exclusively before edits (Agent Mail).
  - Prefer low-collision directories per track.
- **Pre-commit**
  - Run UBS before committing (repo guardrail).