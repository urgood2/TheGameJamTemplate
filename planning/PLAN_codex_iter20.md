# Game #4 “Bargain” — Engineering Plan (v8: executable contracts, gated milestones, low-collision parallel tracks)

> Product goal: ship a **deterministic, replayable 7-floor run** where **Bargains** are the primary progression mechanic, with **hard gates** for determinism, termination, and no softlocks.

---

## 0) Definition of Done (Ship Criteria)

### 0.1 Player-visible MVP
A complete **7-floor run** reproducible under `seed + scripted inputs`:

- Floors **1–6**: explore/combat → find **stairs** → descend.
- Floor **7**: boss (“Sin Lord”) → **victory** on defeat.
- Player HP ≤ 0 → **death** state → restart → new seeded run.
- Bargains:
  - **Floor start**: forced offer (must choose; cannot proceed otherwise).
  - **Level up**: optional offer (may skip).

### 0.2 Hard gates (must be green before “done”)
- **Gate A — Determinism:** fixtures `S1,S2,S3` produce **bit-for-bit identical digests** vs goldens; each seed matches across **two consecutive runs**.
- **Gate B — Termination:** `S1–S3` end in `victory|death` with **no caps hit** and no stuck phases.
- **Gate C — Deal completeness:** exactly **21 deals** (`7 sins × 3`) with **stable IDs** and **stable sin mapping**.
- **Gate D — Downside enforcement:** **21/21** deals have tests that fail if the downside is removed or becomes non-impactful.
- **Gate E — One-command run:** `RUN_BARGAIN_TESTS=1 <game_binary>` exits **0 on pass**, **non-zero on fail**, prints repro bundle on failure.

### 0.3 Explicit non-goals (deferred)
Inventory/shops/meta progression/save-load; polish VFX/audio; advanced pathfinding; deep balance iteration.

---

## 1) Constraints as Executable Contracts

### 1.1 Determinism contract (test + static guard)
- **Sim purity:** all gameplay rules live in Lua sim modules; no IO, rendering, time/dt, or engine globals.
- **Single RNG:** `world.rng` is the only randomness source; ban `math.random` (and engine RNG) in sim.
- **Stable iteration:** no `pairs()` / `next()` in rule-sensitive sim; use arrays + explicit sort.
- **Explicit tie-breakers:** when ordering matters, define it (e.g., `speed desc`, tie `id asc`).
- **Canonical neighbor order:** frozen globally as **N, E, S, W**.

### 1.2 Safety/termination contract (unit + integration)
- `step()` is bounded by `MAX_INTERNAL_TRANSITIONS` (start at **64**; adjust with evidence).
- Whole-run cap in tests: `MAX_STEPS_PER_RUN` (start at **5000**).
- Invalid input must never crash:
  - returns `{ok=false, err="..."}`
  - consumes the actor’s turn (prevents “retry loops”)
  - invariants remain valid (no half-applied state)

### 1.3 Merge-safety contract (low collision)
- Keep edits to hot files minimal (only test hook + wiring if required).
- All new Bargain work stays in:
  - `assets/scripts/bargain/**`
  - `assets/scripts/tests/bargain/**`
  - `assets/scripts/tests/run_bargain_tests.lua`

---

## 2) Architecture Freeze (M0 contract; enables parallel work)

### 2.1 Core boundaries
- **Sim (pure):** deterministic rules and state transitions.
- **Bridge (thin):** translates UI/input to sim inputs; must not mutate sim state except via `step()`.
- **UI:** presentation only; no randomness/time affecting sim.

### 2.2 World schema (contract-tested)
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

### 2.3 Entity schema (contract-tested)
- `id`, `kind ("player"|"enemy"|"boss")`, `x`, `y`
- `hp`, `hp_max`, `atk`, `def`, `speed`, `fov_radius`
- `xp`, `level`
- `flags` (order-independent set; serialized deterministically)
- `hooks` (`hook_name -> array`, stable order)

### 2.4 Offer struct (array-only, stable order)
`world.deals.pending_offer`:
- `kind ∈ {"floor_start","level_up"}`
- `offers: [deal_id...]` (ordered deterministically)
- `must_choose: bool`
- `can_skip: bool`

### 2.5 Input API (contract-tested)
`step(world, input)` supports:
- `{type="move", dx=0|±1, dy=0|±1}`
- `{type="attack", dx=0|±1, dy=0|±1}`
- `{type="wait"}`
- `{type="deal_choose", deal_id="..."}`
- `{type="deal_skip"}`

### 2.6 Phase machine (frozen + tested)
Phases: `DEAL_CHOICE → PLAYER_INPUT → PLAYER_ACTION → ENEMY_ACTIONS → END_TURN → PLAYER_INPUT`

Rules:
- Forced offers pin `DEAL_CHOICE` until chosen.
- Enemy order: `speed desc`, tie-break `id asc`.

---

## 3) Test Harness (one command, failure-localizing, CI-ready)

### 3.1 One-command contract
- Env: `RUN_BARGAIN_TESTS=1`
- Invocation: `RUN_BARGAIN_TESTS=1 <game_binary>`
- Behavior:
  - runs suite
  - prints minimal failing repro bundle
  - exits non-zero on any failure

### 3.2 Minimal engine hook (single touchpoint)
In `assets/scripts/core/main.lua`:
- early detect `RUN_BARGAIN_TESTS=1`
- run `assets/scripts/tests/run_bargain_tests.lua`
- exit before heavy UI boot

### 3.3 Suite layout (explicit files)
Entrypoint:
- `assets/scripts/tests/run_bargain_tests.lua`

Test modules:
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

### 3.4 Failure output contract (repro bundle)
Any failing integration/determinism test prints:
`{seed,floor_num,turn,phase,run_state,last_input,pending_offer,last_events(20),digest,caps_hit?}`

---

## 4) Determinism Oracle (Digest Spec)

### 4.1 Canonical digest payload
Serialize in fixed order (no map iteration):
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

## 5) Milestones (deliverables + exit tests)

### M0 — Harness + contracts (critical path; must land first)
Deliver:
- `RUN_BARGAIN_TESTS=1` hook + suite entrypoint
- stub sim modules with correct exports
- contract + static guard tests

Exit tests:
- `test_contracts` + `test_static_guards` pass
- a tiny fixture produces identical digest twice

### M1 — Core sim loop on fixed tiny map
Deliver:
- deterministic move/collision
- turn system + caps + invalid-input semantics
- combat + deterministic ordering
- `step.lua` glue

Exit tests:
- `test_smoke`: player kills 1 enemy on fixed 5×5 under fixed script

### M2 — Floors + FOV invariants (bounded procgen)
Deliver:
- deterministic floor generator for floors 1–7 with attempt caps + deterministic fallback
- deterministic FOV visible set

Exit tests:
- `test_floors_invariants` passes over bounded seeds (start at 50); failures print seed repro
- `test_fov` defines stable visible set on at least 3 maps (empty, corridor, occluders)

### M3 — Deals system + 21 deals + downside enforcement
Deliver:
- forced floor-start offers + optional level-up offers
- 21 deals implemented (benefit + enforced downside via hooks)

Exit tests:
- `test_deals_downsides` has 21 rows and each row flips a measurable outcome under a fixed script
- `test_contracts` verifies “forced offer blocks progression” and “optional offer can skip”

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
- manual checklist on known seed; confirm bridge/UI does not mutate sim directly

### M6 — Full-run determinism (S1–S3)
Deliver:
- scripts + goldens for full 7-floor runs

Exit tests:
- Gate A + Gate B pass for `S1,S2,S3` (two consecutive runs match bit-for-bit)

### M7 — Balance surface (separate from correctness)
Deliver:
- `assets/scripts/bargain/data/balance.lua` as the only tuning surface

Exit:
- 3 recorded seeded runs (seed + script + outcome + duration) documented in fixtures

---

## 6) Parallel Work Plan (bead-sized, low collision)

### 6.1 Dependency graph (critical path)
- **M0 blocks everything.**
- After M0, work proceeds on parallel tracks:
  - Track C: core sim (M1)
  - Track F/V: floors + FOV (M2)
  - Track D: deals (M3)
  - Track A: enemies/boss (M4)
  - Track R: digest/scripts/goldens (M6 pieces can start early)
  - Track UI: minimal UX (M5)

### 6.2 Bead units (each includes tests + explicit DoD)
Integrator:
- I0: hook + `run_bargain_tests.lua` + suite skeleton (DoD: exits 0/≠0 correctly)

Core sim:
- C1: `grid.lua` + unit tests (neighbor order, occupancy, sorted helpers)
- C2: `turn_system.lua` + unit tests (phase progression, caps, invalid input consumes turn)
- C3: `combat.lua` + unit tests (damage math, no forbidden RNG)
- C4: `step.lua` glue + smoke

Floors/FOV:
- F1: invariants tests first (reachability, spawn constraints, cap behavior)
- F2: procgen implementation satisfying invariants under bounded seeds
- V1: `fov.lua` + unit tests (occlusion determinism, stable visible set)

Enemies/Boss:
- A1: enemies schema + load test
- A2: AI chase/attack + determinism tie-break tests
- A3: boss behavior + floor 7 win condition tests

Deals:
- D0: `deals.lua` core (offer generation + apply plumbing) + offer gating tests
- D(1–7): one sin per bead: `data/sins/<sin>.lua` with 3 deals + 3 downside test rows

Determinism:
- R1: digest implementation + unit/integration tests
- R2: full scripts + goldens for `S1–S3` (+ rationale per change)

---

## 7) Change Control (prevents churn)

### 7.1 Append-only freezes (after first landing)
- Deal IDs + sin mapping are append-only once Gate C is met.
- Enemy IDs + boss ID are append-only once M4 lands.
- Digest schema changes require explicit rationale and/or versioning.

### 7.2 Golden update protocol
Any change to `assets/scripts/tests/bargain/fixtures/expected_digests.lua` must include:
- updated digest values
- a 1-line rationale per digest change
- confirmation that two consecutive runs match bit-for-bit

### 7.3 Review checklist (minimum)
- Adds/updates tests for the change.
- `RUN_BARGAIN_TESTS=1 <game_binary>` passes locally.
- No forbidden patterns introduced in sim subtree (`pairs`, `math.random`, time/IO/engine globals).
- Determinism-impacting changes include explicit tie-breaker reasoning.

---

## 8) Risks + test-enforced mitigations
- Lua table iteration nondeterminism → sorted iteration helpers + static scan tests.
- Hidden randomness/time in bridge/UI → headless determinism tests (no UI dependency).
- Procgen infinite loops/unreachable stairs → attempt caps + invariant tests with seed repro.
- “Downside exists but is toothless” → downside tests must flip a concrete outcome under a fixed script.

---

## 9) Repo workflow (Beads + coordination)
- Beads:
  1) Triage with BV
  2) Claim bead (`in_progress`)
  3) Implement + tests (suite must pass)
  4) Close bead + notify via Agent Mail
- Coordination:
  - Reserve paths exclusively via Agent Mail before edits.
  - Keep beads small and scoped to low-collision directories.