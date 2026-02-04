# Game #4 “Bargain” — Engineering Plan (v10: contract-first, CI-gated, parallel workstreams)

> **Ship goal:** a **deterministic, replayable 7-floor run** where **Bargains** are the primary progression mechanic, ending in **victory or death** with **no softlocks**.

---

## 0) Quick Command Sheet (how we prove “done”)

### Build + run Bargain suite (one command, local + CI)
- Build (fast debug): `just build-debug-fast`
- Run suite: `RUN_BARGAIN_TESTS=1 ./build-debug/raylib-cpp-cmake-template`

### Repo guardrails (pre-commit)
- C++ unit tests: `just test` (or `scripts/run_tests.sh`)
- UI baselines (only if UI touched): `just ui-verify` (optionally `just ui-baseline-capture` before refactors)

---

## 1) Ship Definition of Done (player-visible + engineering gates)

### 1.1 Player-visible MVP (7-floor run)
- Floors **1–6**: explore/combat → find **stairs** → descend.
- Floor **7**: boss (“Sin Lord”) → **victory** on defeat.
- Player HP ≤ 0 → **death** state → restart → new seeded run.
- Bargains:
  - **Floor start**: **forced** offer (must choose; cannot proceed otherwise).
  - **Level up**: **optional** offer (may skip).

### 1.2 Hard gates (must be green to ship)
| Gate | Requirement | How it’s measured (test-owned) |
|---|---|---|
| A — Determinism | S1/S2/S3 produce identical digests | `RUN_BARGAIN_TESTS=1 ...` runs determinism suite **twice** per seed; compares to goldens |
| B — Termination | S1–S3 end in `victory|death` with no caps hit | scripted runs assert `caps_hit=false` and final `run_state ∈ {victory, death}` |
| C — Deal completeness | **21 deals** (7 sins × 3), stable IDs + mapping | data loader test enumerates deals; validates **counts, uniqueness, mapping** |
| D — Downside enforcement | **21/21** deals have a downside that measurably matters | table-driven tests fail if downside becomes no-op |
| E — One-command suite | single command, clean exit codes, repro bundle on failure | exit **0** on pass, **non-zero** on fail; prints structured repro payload |

### 1.3 Explicit non-goals (deferred)
- Inventory/shops/meta progression/save-load
- VFX/audio polish
- Advanced pathfinding
- Balance iteration beyond “not broken”

---

## 2) Architecture Boundary (to enable parallel work safely)

### 2.1 “Hot files” policy (minimize collisions)
- **Only one** required hot file edit for the Bargain test hook:
  - `assets/scripts/core/main.lua` (add `RUN_BARGAIN_TESTS` gate, early exit)

Everything else stays under new, low-collision directories:
- Sim + data: `assets/scripts/bargain/**`
- Tests: `assets/scripts/tests/bargain/**`
- Entrypoint: `assets/scripts/tests/run_bargain_tests.lua`

### 2.2 Determinism contract (test-enforced)
- **Sim purity:** all gameplay rules live in pure Lua sim modules: **no IO**, **no rendering**, **no dt**, **no engine globals**.
- **RNG:** a single RNG handle `world.rng`; no other randomness sources.
- **Ordering:** no order-dependent `pairs()/next()`; stable tie-breakers everywhere ordering matters.
- **Canonical direction order:** **N, E, S, W** (frozen constant used everywhere).

### 2.3 Termination / safety contract (test-enforced)
- Internal transition bound: `MAX_INTERNAL_TRANSITIONS` (start **64**, tune with evidence).
- Whole-run bound: `MAX_STEPS_PER_RUN` (start **5000**, tune with evidence).
- Invalid input must not crash:
  - returns `{ok=false, err="..."}`
  - consumes the actor’s turn
  - world invariants remain valid (no half-applied state)

---

## 3) Frozen Interfaces (PR-1 deliverable; unblock parallel tracks)

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

## 4) Test Harness Design (fail-fast, failure-localizing)

### 4.1 Runner choice (reuse repo’s runner)
- Use `assets/scripts/tests/test_runner.lua` (`describe/it/expect`) for all Bargain tests.
- `assets/scripts/tests/run_bargain_tests.lua` registers Bargain suites and calls the runner; exits with proper code.

### 4.2 One-command contract
- Env: `RUN_BARGAIN_TESTS=1`
- Invocation: `RUN_BARGAIN_TESTS=1 ./build-debug/raylib-cpp-cmake-template`
- Behavior:
  - runs suite
  - prints a single structured repro bundle on failure
  - exits non-zero on any failure
  - must not boot UI / enter main loop

### 4.3 Failure output contract (structured repro bundle)
On failure, print **one** parseable payload (JSON or Lua-table-as-JSON) containing at least:
- `seed, floor_num, turn, phase, run_state`
- `last_input, pending_offer`
- `last_events(20)`
- `digest`
- `caps_hit?`
- (optional) `world_snapshot_path` if dump exists

---

## 5) Determinism Oracle (digest spec; golden-managed)

### 5.1 Canonical digest payload (fixed order; no map iteration)
Serialize deterministically:
- `digest_version`
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

### 5.3 Golden update protocol (prevents churn)
Any change to goldens must include:
- updated digest values
- a 1-line rationale per changed digest
- confirmation: two consecutive runs match bit-for-bit (same seed + script)

If digest schema must change:
- bump `digest_version` and migrate goldens in one PR with rationale.

---

## 6) Milestones (deliverables + exit tests + parallelization points)

### M0 — “Contracts First” (critical path, unblock parallel work)
Deliver:
- `RUN_BARGAIN_TESTS` hook + early exit in `assets/scripts/core/main.lua`
- `assets/scripts/tests/run_bargain_tests.lua` using `tests.test_runner`
- Contract tests: schemas, phases, offer gating, caps, invalid-input semantics
- Static guard tests for determinism rules (forbidden APIs + ordering hazards)
- Minimal sim stubs exporting frozen interfaces

Exit tests:
- `RUN_BARGAIN_TESTS=1 ...` exits **0** when green, **non-zero** when failing
- determinism mini-test: run same seed/script twice → identical digest

Parallelization unlocked after M0:
- Core sim (M1), Floors/FOV (M2), Deals (M3), Enemies/Boss (M4), Goldens (M6 prep), UI (M5)

### M1 — Core sim loop on fixed tiny map
Deliver:
- deterministic movement + collision
- turn system + caps + invalid-input semantics
- deterministic combat ordering
- `step()` glue

Exit tests:
- smoke script on a fixed 5×5: player kills 1 enemy, no caps hit, deterministic digest

### M2 — Floors + FOV invariants (bounded procgen)
Deliver:
- deterministic floor generator for floors 1–7 with attempt caps + deterministic fallback
- deterministic FOV visible set

Exit tests:
- floor invariants over bounded seeds (start 50); failures print seed repro
- FOV goldens on at least 3 maps (empty, corridor, occluders)

### M3 — Deals system + 21 deals + downside enforcement
Deliver:
- forced floor-start offers + optional level-up offers
- 21 deals implemented (benefit + enforced downside via hooks)

Exit tests:
- `21`-row downside suite: each deal measurably changes an outcome under a fixed script
- offer gating: forced offer blocks progression; optional offer can skip

### M4 — Enemies + boss + win/lose transitions
Deliver:
- enemy templates + deterministic AI
- floor 7 boss + victory condition; player death path

Exit tests:
- AI determinism: stable targeting and tie-breakers
- integration scripts reach both `victory` and `death` on known seeds

### M5 — Minimal UX flows (no sim logic)
Deliver:
- deal modal (forced vs optional), HUD, victory/death + restart

Exit:
- manual checklist on a known seed; confirm UI never mutates sim directly (only via `step()`)

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

## 7) Workstreams (bead-sized, parallelizable, low collision)

### Stream I — Integrator (owns M0 harness + hook)
- I0: `RUN_BARGAIN_TESTS` hook + `run_bargain_tests.lua` entrypoint
  - DoD: correct exit codes + structured repro bundle

### Stream C — Core sim
- C1: `grid` + unit tests (neighbor order, occupancy, stable sort helpers)
- C2: `turn_system` + unit tests (phase progression, caps, invalid input consumes turn)
- C3: `combat` + unit tests (damage math, ordering, no RNG leakage)
- C4: `step` glue + smoke test

### Stream F/V — Floors + FOV
- F1: invariants tests first (connectivity, spawn/stairs constraints, cap behavior)
- F2: procgen implementation satisfying invariants under bounded seeds
- V1: `fov` + unit tests (occlusion determinism, stable visible set)

### Stream A — Enemies + Boss
- A1: enemy templates schema + load test
- A2: AI chase/attack + determinism tie-break tests
- A3: boss behavior + floor 7 win condition tests

### Stream D — Deals
- D0: deals core (offer generation + apply plumbing) + offer gating tests
- D1–D7: one sin per bead: 3 deals + 3 downside rows (table-driven)

### Stream R — Determinism + goldens
- R1: digest implementation + tests
- R2: full scripts + goldens for S1–S3 (+ rationale per change)

### Stream UI — Minimal UI/bridge (after M0; independent of sim internals)
- UI0: deal modal + input mapping to `deal_choose/deal_skip`
- UI1: victory/death screen + restart plumbing

---

## 8) Deal Catalog Contract (IDs + mapping frozen)
- **ID format (frozen):** `<sin>.<index>` (example: `wrath.1`, `wrath.2`, `wrath.3`)
- **Mapping:** exactly 7 sins, each exactly 3 deals; loader test enforces count + uniqueness.
- **Append-only rule:** once Gate C is met, IDs and sin mapping become append-only.

Downside test standard (per deal):
- Run a fixed script **with** the deal applied and **without** it applied.
- Assert at least one metric changes in the expected direction (HP lost, turns-to-kill, visibility count, damage dealt/taken, action availability).

---

## 9) Risk Register (each risk has a test mitigation)

- Lua table iteration nondeterminism → sorted iteration helpers + static scan tests for `pairs()/next()`.
- Hidden randomness/time in bridge/UI → headless determinism tests that run without UI.
- Procgen infinite loops/unreachable stairs → attempt caps + invariant tests with seed repro.
- “Downside exists but is toothless” → downside suite must flip a concrete outcome under a fixed script.
- Golden churn blocking progress → digest versioning + enforced rationale per golden change.

---

## 10) Execution Workflow (Beads + coordination)

- **Beads**
  1) Triage what’s ready with BV
  2) Claim bead (`in_progress`)
  3) Implement + tests (Bargain suite + relevant unit tests)
  4) Close bead and notify via Agent Mail
- **Coordination**
  - Reserve paths exclusively before edits (Agent Mail).
  - Prefer working only inside the stream’s directory boundary.
- **Pre-commit**
  - Run UBS before committing (repo guardrail).
  - Keep commits small and stream-scoped unless a refactor demands otherwise.