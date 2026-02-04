# Game #4 “Bargain” — Engineering Plan (v11: contract-packaged, test-first, parallel-by-default)

> **Ship goal:** a **deterministic, replayable 7-floor run** where **Bargains** are the primary progression mechanic, ending in **victory or death** with **no softlocks**, proven by a **single CI-gated command**.

---

## 0) Proof Commands (definition of “done”)

### 0.1 One command (local + CI)
- Build: `just build-debug-fast`
- Run Bargain suite: `RUN_BARGAIN_TESTS=1 ./build-debug/raylib-cpp-cmake-template`

**Pass criteria**
- Exit code `0`
- No UI boot / no main loop
- All Bargain tests green

### 0.2 Repo guardrails (pre-commit)
- `just test` (or `scripts/run_tests.sh`)
- If UI touched: `just ui-verify` (capture baseline first if refactoring: `just ui-baseline-capture`)

---

## 1) Ship DoD (player-visible) + Quality Gates (engineering)

### 1.1 Player-visible MVP (7 floors)
- Floors **1–6**: explore/combat → find **stairs** → descend
- Floor **7**: boss (“Sin Lord”) → **victory** on defeat
- Player HP ≤ 0 → **death** → restart → new seeded run
- Bargains:
  - **Floor start:** forced offer (**must choose**)
  - **Level up:** optional offer (**may skip**)

### 1.2 Hard gates (CI must enforce)
| Gate | Requirement | How we measure it |
|---|---|---|
| A Determinism | Seeds `S1,S2,S3` produce identical digests | suite runs each seed/script twice; compares digests |
| B Termination | `S1–S3` end in `victory` or `death` | asserts `caps_hit=false` and final `run_state∈{victory,death}` |
| C Deal completeness | Exactly **21 deals** (7 sins × 3) with stable IDs | loader test: counts + uniqueness + mapping |
| D Downside enforcement | **21/21** deals have a downside that materially changes outcomes | table-driven “with vs without deal” assertions |
| E One-command repro | failures emit a single parseable repro payload | suite prints one structured bundle and exits non-zero |

### 1.3 Explicit non-goals (deferred)
- inventory/shops/save-load/meta progression
- polish (VFX/audio/balance beyond “not broken”)
- advanced pathfinding

---

## 2) Parallelization Strategy (freeze the contract package)

### 2.1 Contract Package (must land first; unblocks all streams)
**Deliverable:** a small set of “frozen interfaces” + contract tests that *everyone* codes against.

**Contract package contents**
- World schema + entity schema + offer schema
- Phase machine rules
- Input API (`step(world, input)`)
- Determinism constraints (ordering, RNG, forbidden APIs)
- Failure/repro bundle format

**Exit test**
- `RUN_BARGAIN_TESTS=1 ...` runs contract suite and exits `0`

### 2.2 Collision-minimizing file boundaries
**Hot file policy**
- Only one unavoidable shared edit (test hook): `assets/scripts/core/main.lua`

**Everything else lives in low-collision directories**
- Sim + data: `assets/scripts/bargain/**`
- Tests: `assets/scripts/tests/bargain/**`
- Entrypoint: `assets/scripts/tests/run_bargain_tests.lua`

**Reservation guidance (Agent Mail)**
- Integrator: `assets/scripts/core/main.lua`, `assets/scripts/tests/run_bargain_tests.lua`
- Core sim: `assets/scripts/bargain/sim/**`
- Floors/FOV: `assets/scripts/bargain/floors/**`, `assets/scripts/bargain/fov/**`
- Deals: `assets/scripts/bargain/deals/**`, `assets/scripts/bargain/data/deals/**`
- Enemies/Boss: `assets/scripts/bargain/enemies/**`
- Goldens: `assets/scripts/tests/bargain/fixtures/**`
- UI: whatever UI directory exists; avoid sim dirs

---

## 3) Frozen Interfaces (exactly what other streams rely on)

### 3.1 World schema (contract-tested)
Required fields:
- `world.grid`
- `world.entities` (map `id -> entity`)
- `world.player_id`
- `world.turn`, `world.phase`, `world.floor_num` (1..7)
- `world.run_state` (`"playing"|"victory"|"death"`)
- `world.rng`
- `world.deals.applied` (map `deal_id -> true`)
- `world.deals.history` (array)
- `world.deals.pending_offer` (`nil|offer`)

Recommended (for repro/debug; must be deterministic):
- `world.stairs`
- `world.events` (append-only array)
- `world.messages` (append-only array)

### 3.2 Entity schema (contract-tested)
- `id`, `kind` (`"player"|"enemy"|"boss"`), `x`, `y`
- `hp`, `hp_max`, `atk`, `def`, `speed`, `fov_radius`
- `xp`, `level`
- `flags` (order-independent set; must serialize deterministically)
- `hooks` (`hook_name -> array`, stable order)

### 3.3 Offer struct (stable order, array-only)
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
- Forced offers pin `DEAL_CHOICE` until chosen
- Enemy order: `speed desc`, tie `id asc`
- Invalid input: returns `{ok=false, err="..."}` and **consumes the actor’s turn** without breaking invariants

---

## 4) Determinism + Safety Contracts (test-owned, non-negotiable)

### 4.1 Determinism rules
- Single RNG: only `world.rng` is allowed to generate randomness
- No order-dependent iteration: avoid `pairs()/next()` for gameplay-critical iteration
- All ordering uses explicit stable sorts and fixed tie-breakers
- Canonical direction order is frozen: `N, E, S, W`

**Static scan tests** (fail fast)
- forbid `pairs(` / `next(` in sim directories (allowlist only where harmless)
- forbid `os.time`, `math.random`, frame `dt`, engine globals in sim

### 4.2 Termination / caps
- `MAX_INTERNAL_TRANSITIONS` (start 64)
- `MAX_STEPS_PER_RUN` (start 5000)
- Procgen attempt caps + deterministic fallback when caps hit

**Tests**
- scripted runs must end in `victory|death` without hitting caps
- procgen seeds must not exceed attempt caps; failures print seed repro

---

## 5) Test Harness Design (failure-localizing and CI-friendly)

### 5.1 Runner
- Reuse `assets/scripts/tests/test_runner.lua` (`describe/it/expect`)
- Add `assets/scripts/tests/run_bargain_tests.lua` that registers Bargain suites and exits with correct code

### 5.2 Test suites (explicit list)
- `contracts_spec.lua`: schemas, phases, invalid-input semantics, caps behavior
- `determinism_static_spec.lua`: forbidden API and iteration hazards scan
- `digest_spec.lua`: digest stability and versioning
- `sim_smoke_spec.lua`: tiny-map integration smoke
- `floors_spec.lua`: bounded procgen invariants + seed repro
- `fov_spec.lua`: deterministic visible-set goldens
- `deals_loader_spec.lua`: 21 deals mapping + uniqueness
- `deals_downside_spec.lua`: 21 table-driven downside checks
- `ai_spec.lua`: deterministic targeting + tie-breakers
- `run_scripts_spec.lua`: S1–S3 full-run scripts + golden digests

### 5.3 Failure output contract (single repro bundle)
On failure, print exactly one parseable payload containing:
- `seed, floor_num, turn, phase, run_state`
- `last_input, pending_offer`
- `last_events(20)`
- `digest`
- `caps_hit`
- optional: `world_snapshot_path` if dumped

---

## 6) Digest + Golden Protocol (prevents churn)

### 6.1 Digest schema (versioned)
Serialize in fixed order (no map iteration):
- `digest_version`
- `floor_num, turn, phase, run_state`
- player tuple `(x,y,hp,hp_max,xp,level,atk,def,speed,fov_radius)`
- entities sorted by `id`: `(id,kind,x,y,hp,selected_flags)`
- applied deals sorted lexicographically
- optional compact history summary only if needed for stability

### 6.2 Golden update rules
Any change to goldens must include:
- updated digest(s)
- one-line rationale per changed digest
- proof: two consecutive runs match bit-for-bit (same seed + same script)

If digest schema changes:
- bump `digest_version`
- migrate all goldens in the same bead/PR

---

## 7) Deal Catalog Contract (IDs and mapping are frozen)

- **ID format:** `<sin>.<index>` (e.g. `wrath.1`)
- Exactly **7 sins**, exactly **3 deals each** (21 total)
- Once Gate C is met: **append-only** (no renames/remaps)

**Downside test standard (per deal)**
- Run the same fixed script:
  - baseline (no deal)
  - with deal applied
- Assert at least one metric changes in the expected direction:
  - HP lost / damage taken
  - turns-to-kill
  - visibility count
  - action availability / forced behavior

---

## 8) Milestones (bead-sized deliverables + exit tests + dependencies)

### M0 — Contract Package + Harness (critical path)
Deliver:
- `RUN_BARGAIN_TESTS` hook + early exit in `assets/scripts/core/main.lua`
- `assets/scripts/tests/run_bargain_tests.lua` wired to `tests/test_runner.lua`
- Contract + static determinism scan suites
- Minimal sim stubs exporting frozen interfaces

Exit tests:
- `RUN_BARGAIN_TESTS=1 ...` exits `0` when green, non-zero on failure
- determinism mini-test: same seed/script twice → identical digest

Unblocks: Core sim, Floors/FOV, Deals, Enemies/Boss, Goldens, UI

### M1 — Core Sim (tiny fixed map)
Deliver:
- deterministic movement/collision
- turn system + phase progression + caps
- deterministic combat ordering
- `step()` glue

Exit tests:
- tiny 5×5 smoke: player kills 1 enemy, no caps hit, deterministic digest

### M2 — Floors + FOV
Deliver:
- deterministic floor generator for floors 1–7 (bounded attempts + fallback)
- deterministic FOV visible set

Exit tests:
- floor invariants over bounded seeds (start 50); failures print seed repro
- FOV goldens on at least 3 maps: empty, corridor, occluders

### M3 — Deals System + 21 Deals + Downside Enforcement
Deliver:
- forced floor-start offers + optional level-up offers
- 21 deals implemented with enforced downsides (hooks)

Exit tests:
- 21-row downside suite passes
- offer gating: forced offer blocks progression; optional offer can skip

### M4 — Enemies + Boss + Win/Lose
Deliver:
- enemy templates + deterministic AI
- floor 7 boss + victory condition; player death path

Exit tests:
- AI determinism: stable targeting + tie-breakers
- integration scripts reach both `victory` and `death` on known seeds

### M5 — Minimal UX (no sim logic)
Deliver:
- deal modal (forced vs optional), HUD, victory/death + restart

Exit:
- manual checklist on known seed; confirm UI never mutates sim directly (only via `step()`)

### M6 — Full-run determinism (S1–S3)
Deliver:
- scripts + goldens for full 7-floor runs

Exit tests:
- Gate A + Gate B for `S1,S2,S3` (two consecutive runs match bit-for-bit)

### M7 — Balance Surface (separate from correctness)
Deliver:
- single tuning surface file (e.g., `assets/scripts/bargain/data/balance.lua`) as the only balance knob location

Exit:
- 3 recorded seeded runs (seed + script + outcome + duration) added to fixtures/docs

---

## 9) Workstreams (parallelizable “beads” with crisp DoD)

### Stream I — Integrator (M0 owner)
- I0: `RUN_BARGAIN_TESTS` hook + `run_bargain_tests.lua`
  - DoD: correct exit codes, no UI boot, repro bundle on failure

### Stream C — Core Sim (M1 owner)
- C1: `grid` + unit tests (neighbor order, occupancy, stable sort helper)
- C2: `turn_system` + unit tests (phase progression, caps, invalid input consumes turn)
- C3: `combat` + unit tests (damage math, ordering, no RNG leakage)
- C4: `step` glue + smoke test

### Stream F/V — Floors + FOV (M2 owner)
- F1: invariants tests first (connectivity, spawn/stairs constraints, cap behavior)
- F2: procgen implementation satisfying invariants under bounded seeds
- V1: FOV + unit tests (occlusion determinism, stable visible set)

### Stream D — Deals (M3 owner)
- D0: deals core (offer generation + apply plumbing) + offer gating tests
- D1–D7: one sin per bead: 3 deals + matching downside rows (table-driven)

### Stream A — Enemies + Boss (M4 owner)
- A1: enemy templates schema + load test
- A2: AI chase/attack + determinism tie-break tests
- A3: boss behavior + floor 7 win condition tests

### Stream R — Determinism + Goldens (M6 owner)
- R1: digest implementation + tests + `digest_version` policy
- R2: full scripts + goldens for S1–S3 (+ rationale per change)

### Stream UI — Minimal UI/Bridge (M5 owner; after M0)
- UI0: deal modal + input mapping to `deal_choose/deal_skip`
- UI1: victory/death screen + restart plumbing

---

## 10) Risk Register (each risk has a test mitigation)

- Lua iteration nondeterminism → sorted iteration helpers + static scan for `pairs()/next()`
- Hidden randomness/time in bridge/UI → headless determinism tests that never boot UI
- Procgen infinite loops/unreachable stairs → attempt caps + invariant tests with seed repro
- “Downside exists but is toothless” → downside suite must flip a concrete metric under a fixed script
- Golden churn blocking progress → digest versioning + rationale-per-change rule

---

## 11) Execution Workflow (Beads + coordination)

- Triage readiness with BV
- Claim bead (`in_progress`)
- Reserve paths exclusively (Agent Mail) before edits
- Implement + tests (Bargain suite + relevant unit tests)
- Close bead and notify dependents via Agent Mail
- Run UBS before committing; keep commits small and stream-scoped