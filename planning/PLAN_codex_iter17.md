```md
# Game #4 “Bargain” — Engineering Plan (v5: specific, testable, parallel-first)

> Goal: ship a deterministic, replayable 7-floor run with “Bargains” (deals) as the core mechanic, with hard gates for determinism + no-softlocks.

---

## 0) Ship Slice, Success Metrics, Non‑Goals

### 0.1 Shippable slice (one vertical slice)
A single run of **7 floors**, fully deterministic under `seed + scripted inputs`:

- Floors **1–6**: explore/combat → find **stairs** → descend.
- Floor **7**: boss (“Sin Lord”) → **victory** on defeat.
- Player death → **game over** → restart → new seeded run.
- **No softlocks**: sim always reaches a valid next state (phase, inputs, offers).

### 0.2 Success metrics (objective, measurable)
- Determinism: `S1,S2,S3` scripted runs match golden digests **bit-for-bit**.
- Termination: all scripted runs end in `victory|death` without hitting caps.
- Deal correctness: **21 deals** exist, stable IDs, each has an automated downside test that fails if downside removed.
- Runtime: full `S1–S3` suite completes under a defined cap (e.g., < 5s local; tune later).

### 0.3 Explicit non‑goals (out of scope)
- Inventory/items/shops, save/load, meta progression.
- Advanced pathfinding beyond BFS/distance-field.
- Networking, replay UI, advanced VFX.

---

## 1) Hard Contracts (must hold; enforced by tests)

### 1.1 Determinism contract (non‑negotiable)
- **All gameplay rules are pure Lua sim** (no rendering, IO, time/dt, engine globals).
- Bridge/UI only:
  - renders from `world`
  - maps UI input → sim `input`
- Single RNG source: `world.rng`. **Ban `math.random`** in sim.
- No nondeterministic iteration in rule-sensitive sim code:
  - **No `pairs()` / `next()`** in anything affecting rules (AI, offers, hooks, processing, digest).
  - Use stable arrays + explicit sort; ties break explicitly (e.g., `id asc`).
- Canonical neighbor order is global and frozen: **N, E, S, W**.

### 1.2 Safety / termination contract
- One `step()` must be bounded:
  - internal phase transition cap (e.g., `MAX_INTERNAL_TRANSITIONS = 64`)
  - internal work caps for procgen, AI loops, etc.
- Whole-run cap for tests/harness (e.g., `MAX_STEPS_PER_RUN = 5000`)
- Invalid inputs never crash:
  - return `{ok=false, err="..."}`
  - **consume the actor’s turn**
  - invariants remain valid (no half-applied state)

### 1.3 Merge-safety (hot files policy)
- Keep edits minimal to:
  - `assets/scripts/core/main.lua` (only env hook + minimal wiring)
  - `assets/scripts/tests/test_runner.lua` (touch only if unavoidable)
- All new work lives under:
  - `assets/scripts/bargain/**`
  - `assets/scripts/tests/bargain/**`
  - `assets/scripts/tests/run_bargain_tests.lua`

---

## 2) Definition of Done (gates; fail fast)

### Gate A — Termination + no softlocks (blocking)
For fixtures `S1,S2,S3`:
- Runs end in `victory|death`
- 0 crashes, 0 softlocks, 0 cap hits
- On failure: dump `{seed,floor,turn,phase,run_state,input,pending_offer,last_events,digest}`

### Gate B — Offer gating rules (blocking)
- Every floor start: forced offer
  - `must_choose=true`, `can_skip=false`
  - sim cannot advance past `DEAL_CHOICE` until chosen
- Every level-up: optional offer
  - `must_choose=false`, `can_skip=true`
  - skip returns to play immediately

### Gate C — Deals completeness (blocking)
- Exactly **21 deals** exist: **7 sins × 3**
- Deal IDs stable + unique; each declares `sin`

### Gate D — Downside enforcement (blocking)
- **21/21** have automated tests proving measurable downside
- Each downside test fails if downside logic is removed

### Gate E — Determinism digest (blocking)
- `seed + scripted inputs → digest` matches golden for `S1,S2,S3`
- Two consecutive runs on same machine match bit-for-bit
- (Stretch) cross-machine stability if floats avoided/normalized

---

## 3) Single-Command Test Harness (exists first)

### 3.1 Entry hook (minimal)
In `assets/scripts/core/main.lua` add:
- `RUN_BARGAIN_TESTS=1` → run bargain tests and exit non-zero on failure
- Must run before heavy UI bootstrapping

### 3.2 Test entrypoint
- Reuse `assets/scripts/tests/test_runner.lua`
- Add `assets/scripts/tests/run_bargain_tests.lua` to register/aggregate Bargain suite

### 3.3 Invocation contract
- `RUN_BARGAIN_TESTS=1 <game_binary>`

---

## 4) Interface Freeze (M0): schemas that unblock parallel work

### 4.1 World schema (enforced by contract tests)
Required:
- `world.grid`
- `world.entities` (map `id -> entity`)
- `world.player_id`
- `world.turn` (monotonic int)
- `world.phase` (string enum)
- `world.floor_num` (1..7)
- `world.run_state` (`"playing"|"victory"|"death"`)
- `world.rng`
- `world.deals.applied` (map `deal_id -> true`)
- `world.deals.history` (array `{deal_id, kind, floor_num, turn}`)
- `world.deals.pending_offer` (nil or offer struct)

Recommended (for debugging + digest stability):
- `world.stairs` (`{x,y}` or nil)
- `world.events` (append-only deterministic structs)
- `world.messages` (append-only deterministic structs for UI)

### 4.2 Entity schema (enforced)
- `id`, `kind` (`"player"|"enemy"|"boss"`)
- `x`, `y`
- `hp`, `hp_max`, `atk`, `def`, `speed`, `fov_radius`
- `xp`, `level`
- `flags` (must not depend on map iteration order)
- `hooks` (hook_name → array; callback order explicit + stable)

### 4.3 Deal offer struct (no map iteration)
`world.deals.pending_offer`:
- `kind` ∈ `{ "floor_start", "level_up" }`
- `offers`: array of deal IDs (stable order)
- `must_choose`: bool
- `can_skip`: bool

### 4.4 Input API + invalid action policy (enforced)
`step(world, input)` supports:
- Move: `{type="move", dx=0|±1, dy=0|±1}`
- Attack: `{type="attack", dx=0|±1, dy=0|±1}`
- Wait: `{type="wait"}`
- Deal choose: `{type="deal_choose", deal_id="..."}`
- Deal skip: `{type="deal_skip"}`

Invalid input:
- returns `{ok=false, err="..."}`
- consumes turn
- invariants remain valid

### 4.5 Phase machine (frozen)
Phases:
- `DEAL_CHOICE`
- `PLAYER_INPUT`
- `PLAYER_ACTION`
- `ENEMY_ACTIONS`
- `END_TURN`

Canonical transitions:
`DEAL_CHOICE → PLAYER_INPUT → PLAYER_ACTION → ENEMY_ACTIONS → END_TURN → PLAYER_INPUT`

Rules:
- Forced offers pin `DEAL_CHOICE` until chosen
- Enemy order: `speed desc`, tie-break `id asc`

---

## 5) Module Layout (public exports = stable integration points)

### 5.1 Sim API (frozen exports)
- `assets/scripts/bargain/sim/world.lua`
  - `new_run(seed, opts) -> world`
  - `new_floor(world, floor_num) -> world` (recommended)
- `assets/scripts/bargain/sim/step.lua`
  - `step(world, input) -> { world, events, ok, err? }`

### 5.2 Workstream modules (each ships with unit tests)
- `assets/scripts/bargain/sim/grid.lua` (bounds/occupancy/neighbor order/sorted iteration helpers)
- `assets/scripts/bargain/sim/turn_system.lua` (phase progression/turn consumption/deal gating/caps)
- `assets/scripts/bargain/sim/combat.lua` (damage + RNG discipline)
- `assets/scripts/bargain/sim/fov.lua` (occlusion + deterministic visible set)
- `assets/scripts/bargain/sim/floors.lua` + `assets/scripts/bargain/data/floors.lua` (procgen + invariants + caps)
- `assets/scripts/bargain/sim/enemy_ai.lua` + `assets/scripts/bargain/data/enemies.lua` (deterministic chase/attack)
- `assets/scripts/bargain/sim/deals.lua` + `assets/scripts/bargain/data/sins/*.lua` (offers + apply hooks)

### 5.3 Bridge (integrator-owned; minimal)
- `assets/scripts/bargain/game.lua` orchestrates sim + UI; **no randomness/time**

---

## 6) Test Strategy (fast, deterministic, failure-localizing)

### 6.1 Test suite structure (explicit files)
- `assets/scripts/tests/run_bargain_tests.lua`
- `assets/scripts/tests/bargain/test_contracts.lua`
- `assets/scripts/tests/bargain/test_grid.lua`
- `assets/scripts/tests/bargain/test_turn_system.lua`
- `assets/scripts/tests/bargain/test_combat.lua`
- `assets/scripts/tests/bargain/test_fov.lua`
- `assets/scripts/tests/bargain/test_enemy_ai.lua`
- `assets/scripts/tests/bargain/test_floors_invariants.lua`
- `assets/scripts/tests/bargain/test_data_loading.lua`
- `assets/scripts/tests/bargain/test_deals_downsides.lua`
- `assets/scripts/tests/bargain/test_smoke.lua`
- `assets/scripts/tests/bargain/test_determinism.lua`

### 6.2 Fixtures (stable + reviewable)
- `assets/scripts/tests/bargain/fixtures/seeds.lua` (`S1,S2,S3`)
- `assets/scripts/tests/bargain/fixtures/scripts.lua` (scripted inputs + offer decisions)
- `assets/scripts/tests/bargain/fixtures/expected_digests.lua` (goldens + 1-line rationale per change)

### 6.3 Downside enforcement pattern (table-driven; 21 rows)
Each deal row defines:
- Arrange: minimal deterministic world + short script (1–20 steps)
- Act: apply deal + advance to manifestation point
- Assert: measurable negative effect that flips an outcome under fixed script:
  - worse combat result (HP remaining / death threshold)
  - per-turn drain at `END_TURN`
  - action restriction returns `ok=false` and consumes turn
  - self-damage on move/attack
  - XP penalty delays a known level-up point

### 6.4 Debuggability contract (mandatory failure output)
On failure print:
- seed, floor, turn, phase, run_state
- pending_offer + chosen input
- last N events/messages (e.g., 20)
- digest (if computed)

---

## 7) Determinism Harness + Digest Spec

### 7.1 RNG API contract
- `world.rng` only randomness source
- explicit API only (e.g., `next_int(min,max)`, `choice(array)`)
- procgen/offers/AI use RNG only via this API

### 7.2 Digest payload (canonical order; no map iteration)
Serialize in fixed order:
- `floor_num`, `turn`, `phase`, `run_state`
- player tuple: `(x,y,hp,hp_max,xp,level,atk,def,speed,fov_radius)`
- entities: sorted by `id`, serialize `(id,kind,x,y,hp,selected_flags)`
- applied deals: sorted lexicographically
- optional: compact `deals.history` summary if needed for stability

### 7.3 Script runner helper (test-owned)
Loop:
- if `pending_offer` → consume next scripted `deal_choose|deal_skip`
- else → consume next scripted `move|attack|wait`
Stop on `victory|death` or fail on caps; return digest.

---

## 8) Milestones (deliverables + acceptance tests)

### M0 — Harness + contract freeze (unblocks parallel work)
Deliver:
- env hook + `run_bargain_tests.lua`
- stub modules with correct exports
- contract tests (schemas, inputs, phases, RNG injection, deal gating, caps)
Accept:
- contract suite passes; two consecutive identical runs for a tiny fixture

### M1 — Core sim loop on tiny fixed map
Deliver:
- grid movement/collision
- turn system + caps
- combat (ordering + RNG discipline)
Accept:
- unit tests pass; smoke: player kills one enemy on fixed 5×5 with fixed script

### M2 — Floors + FOV invariants (bounded procgen)
Deliver:
- floor generator for floors 1–7 meeting invariants (stairs reachable, spawn safety, bounded loops)
- deterministic FOV visible set
Accept:
- invariants over bounded seeds (e.g., 50) pass within time cap; cap-hit fails loudly w/ seed repro

### M3 — Deals system + 21 deals + downside enforcement
Deliver:
- forced floor-start offer + optional level-up offer
- 21 deals implemented (benefit + enforced downside)
Accept:
- Gate B, Gate C, Gate D tests all pass

### M4 — Enemies + boss + win/lose transitions
Deliver:
- enemy templates + deterministic AI
- boss on floor 7
- `run_state` transitions
Accept:
- AI determinism tests pass; boss defeat → victory; player HP ≤ 0 → death

### M5 — Minimal UX flows (no sim logic)
Deliver:
- deal modal (forced vs optional)
- HUD + victory/death + restart
Accept:
- manual checklist on known seed; no sim logic added

### M6 — Full-run determinism gate (S1–S3)
Deliver:
- digest + scripts + goldens for 7-floor runs
Accept:
- Gate A + Gate E pass reliably for `S1,S2,S3`

### M7 — Balance surface (last, separate)
Deliver:
- `assets/scripts/bargain/data/balance.lua` as the only tuning surface
- 3 recorded seeded runs (seed + script + outcome + duration)
Accept:
- average completion ~10–15 minutes; at least one seed winnable without debug hooks

---

## 9) Parallel Work Breakdown (bead-sized PRs)

### 9.1 Dependency summary
- M0 contracts → enables parallel workstreams.
- M1/M2/M3/M4 can proceed in parallel after M0, but M6 requires all.
- UI can start once `pending_offer` + phases are stable (post M0/M3).

### 9.2 Beads (each includes tests + explicit DoD)
**Integrator**
- I0: env hook + `run_bargain_tests.lua` + minimal `test_smoke.lua`
  - DoD: `RUN_BARGAIN_TESTS=1 <binary>` runs and exits correctly.
- I1: optional `AUTO_START_BARGAIN=1` wiring (default off) + wiring test

**Sim core**
- C1: `grid.lua` + tests: neighbor order, occupancy, sorted iteration helpers
- C2: `turn_system.lua` + tests: phase progression, invalid action consumes turn, caps
- C3: `combat.lua` + tests: damage math, RNG usage, ordering
- C4: `step.lua` glue + smoke: fixed map, no offers/AI

**Floors / FOV**
- F1: invariants tests first (stairs reachable, spawn constraints, cap behavior)
- F2: procgen implementation to satisfy invariants under bounded seeds
- V1: `fov.lua` + tests: occlusion determinism, visible set stability

**AI / Boss**
- A1: `data/enemies.lua` schema + loading test
- A2: `enemy_ai.lua` + tests: chase/attack rules, tie-break determinism
- A3: boss rules + tests: floor 7 win condition + deterministic behavior

**Deals (sin-parallelizable)**
- D0: `deals.lua` core (offer generation + apply plumbing) + Gate B tests
- D(1–7): one sin per PR: `data/sins/<sin>.lua` with 3 deals + 3 downside test rows

**Determinism**
- R1: digest implementation + unit/integration tests (canonical serialization)
- R2: full scripts + expected digests for `S1–S3` + rationale per change

**UI**
- U1: deal modal wiring (`pending_offer` → choose/skip input) (no sim logic)
- U2: HUD + run-state screens + restart (no sim logic)

---

## 10) Risks + Mitigations (prefer test-enforced)

- Lua table iteration nondeterminism
  - Mitigation: central sorted-iteration helpers + explicit test that scans Bargain sim for `pairs(` usage (or equivalent guard).
- Hidden randomness/time in bridge/UI
  - Mitigation: full determinism tests (M6) run headless and must pass without UI.
- Hook order drift
  - Mitigation: hooks are arrays; explicit order; unit test validates ordering.
- Procgen infinite loops / unreachable stairs
  - Mitigation: explicit iteration caps + invariants tests that fail loudly with seed repro.
- “Downside exists but isn’t negative”
  - Mitigation: downside tests must flip a concrete outcome under a fixed script.

---

## 11) Change Control (keeps merges sane)
- Deal IDs and `sin` mapping become **append-only** after Gate C.
- Golden digest changes require:
  - updating `expected_digests.lua`
  - 1-line rationale per change
  - confirming stability across two consecutive runs
```