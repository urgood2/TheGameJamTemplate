```md
# Game #4 “Bargain” — Engineering Plan (v6: contract-first, test-gated, parallelizable)

> Product goal: ship a deterministic, replayable 7-floor run where “Bargains” (deals) are the central progression mechanic, with hard gates for determinism, termination, and “no softlocks”.

---

## 0) Outcomes, Non‑Goals, and Success Metrics

### 0.1 Shippable vertical slice (MVP)
A complete **7-floor run** under `seed + scripted inputs`:

- Floors **1–6**: explore/combat → find **stairs** → descend.
- Floor **7**: boss (“Sin Lord”) → **victory** on defeat.
- Player death → **death** state → restart → new seeded run.
- Bargains:
  - **Floor start**: forced offer (must choose; cannot proceed otherwise).
  - **Level up**: optional offer (may skip).

### 0.2 Success metrics (measurable gates)
- Determinism: fixtures `S1,S2,S3` produce **bit-for-bit identical digests** vs goldens.
- Termination: `S1–S3` end in `victory|death` with **no caps hit** and no stuck phases.
- Deal completeness: exactly **21 deals** (`7 sins × 3`), stable IDs, stable sin mapping.
- Downside enforcement: **21/21** deals have automated tests that fail if downside is removed.
- Performance: `S1–S3` suite completes under a defined cap (set initial target; tighten later).

### 0.3 Explicit non‑goals (defer)
- Inventory, shops, meta progression, save/load.
- Fancy VFX, audio polish, advanced UI/UX.
- Complex pathfinding beyond deterministic BFS / distance-field.

---

## 1) Hard Contracts (must be enforced by tests)

### 1.1 Determinism contract
**Sim purity**
- All gameplay rules live in Lua sim modules; no IO, rendering, time, dt, engine globals.
- Bridge/UI:
  - renders from `world`
  - maps UI → sim `input`
  - never mutates sim state directly.

**RNG**
- Single RNG source: `world.rng`.
- Ban `math.random` (and any engine RNG) in sim.
- RNG API must be explicit: `next_int(min,max)`, `choice(array)` (choice must be stable by array order).

**Iteration order**
- In any rule-sensitive sim code: **no `pairs()` / `next()`**.
- Use arrays + explicit sort; all tie-breakers explicit (e.g., `id asc`).
- Canonical neighbor order is global and frozen: **N, E, S, W**.

### 1.2 Termination + safety contract
**Step boundedness**
- One `step()` may internally advance phases but must be bounded:
  - `MAX_INTERNAL_TRANSITIONS` (e.g., 64)
  - per-subsystem caps where needed (procgen attempts, AI loop bounds).
- Whole-run cap in tests: `MAX_STEPS_PER_RUN` (e.g., 5000).

**Invalid inputs**
- Must never crash.
- Policy:
  - return `{ok=false, err="..."}`
  - consumes the actor’s turn
  - invariants remain valid (no half-applied state).

### 1.3 Merge-safety contract (minimize collisions)
- “Hot files” are minimized; new work lives in a dedicated subtree.
- Keep edits minimal to:
  - `assets/scripts/core/main.lua` (test hook + minimal wiring)
  - `assets/scripts/tests/test_runner.lua` (only if unavoidable)
- All new Bargain work under:
  - `assets/scripts/bargain/**`
  - `assets/scripts/tests/bargain/**`
  - `assets/scripts/tests/run_bargain_tests.lua`

---

## 2) Definition of Done (blocking gates)

### Gate A — Termination / no softlocks
For fixtures `S1,S2,S3`:
- End state is `victory|death`.
- 0 crashes, 0 “phase stuck”, 0 cap hits.
- On failure, print a repro bundle:
  - `{seed,floor_num,turn,phase,run_state,last_input,pending_offer,last_events(20),digest}`

### Gate B — Offer gating rules
- Floor start: forced offer
  - `must_choose=true`, `can_skip=false`
  - sim cannot advance past `DEAL_CHOICE` until chosen.
- Level up: optional offer
  - `must_choose=false`, `can_skip=true`
  - skip returns to play immediately.

### Gate C — Deals completeness
- Exactly **21 deals** exist; stable unique IDs; each declares `sin`.

### Gate D — Downside enforcement
- 21/21 deals have automated downside tests that prove a measurable negative effect.

### Gate E — Full determinism digest
- `seed + scripted inputs → digest` matches goldens for `S1,S2,S3`.
- Two consecutive runs on the same machine match bit-for-bit.
- (Stretch) cross-machine stability: avoid floats or normalize them.

---

## 3) Build/Test Interface (single-command harness first)

### 3.1 Test hook (minimal)
Add an early hook in `assets/scripts/core/main.lua`:
- `RUN_BARGAIN_TESTS=1` → run Bargain test suite and exit non-zero on failure.
- Must run before heavy UI bootstrapping.

### 3.2 Test entrypoint + suite registration
- `assets/scripts/tests/run_bargain_tests.lua` registers the suite.
- Reuse existing runner `assets/scripts/tests/test_runner.lua`.

### 3.3 Invocation contract
- `RUN_BARGAIN_TESTS=1 <game_binary>`

---

## 4) Interface Freeze (M0): schemas and APIs that unblock parallel work

### 4.1 World schema (contract-tested)
Required fields:
- `world.grid`
- `world.entities` (map `id -> entity`)
- `world.player_id`
- `world.turn` (monotonic int)
- `world.phase` (enum string)
- `world.floor_num` (1..7)
- `world.run_state` (`"playing"|"victory"|"death"`)
- `world.rng`
- `world.deals.applied` (map `deal_id -> true`)
- `world.deals.history` (array `{deal_id, kind, floor_num, turn}`)
- `world.deals.pending_offer` (nil or offer struct)

Recommended for debugging + deterministic output:
- `world.stairs` (`{x,y}` or nil)
- `world.events` (append-only deterministic structs)
- `world.messages` (append-only deterministic structs)

### 4.2 Entity schema (contract-tested)
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

### 4.4 Input API + invalid action policy (contract-tested)
`step(world, input)` supports:
- Move: `{type="move", dx=0|±1, dy=0|±1}`
- Attack: `{type="attack", dx=0|±1, dy=0|±1}`
- Wait: `{type="wait"}`
- Deal choose: `{type="deal_choose", deal_id="..."}`
- Deal skip: `{type="deal_skip"}`

Invalid input:
- returns `{ok=false, err="..."}`
- consumes turn
- invariants remain valid.

### 4.5 Phase machine (frozen, tested)
Phases:
- `DEAL_CHOICE`
- `PLAYER_INPUT`
- `PLAYER_ACTION`
- `ENEMY_ACTIONS`
- `END_TURN`

Canonical transitions:
`DEAL_CHOICE → PLAYER_INPUT → PLAYER_ACTION → ENEMY_ACTIONS → END_TURN → PLAYER_INPUT`

Rules:
- Forced offers pin `DEAL_CHOICE` until chosen.
- Enemy order: `speed desc`, tie-break `id asc`.

---

## 5) Module Layout (stable integration points)

### 5.1 Sim API exports (frozen)
- `assets/scripts/bargain/sim/world.lua`
  - `new_run(seed, opts) -> world`
  - `new_floor(world, floor_num) -> world` (or pure `build_floor(seed,floor_num)` + apply)
- `assets/scripts/bargain/sim/step.lua`
  - `step(world, input) -> { world, events, ok, err? }`

### 5.2 Core modules (each ships with unit tests)
- `assets/scripts/bargain/sim/grid.lua` (bounds/occupancy/neighbor order/sorted helpers)
- `assets/scripts/bargain/sim/turn_system.lua` (phase progression/turn consumption/deal gating/caps)
- `assets/scripts/bargain/sim/combat.lua` (damage + RNG discipline)
- `assets/scripts/bargain/sim/fov.lua` (occlusion + deterministic visible set)
- `assets/scripts/bargain/sim/floors.lua` + `assets/scripts/bargain/data/floors.lua` (procgen + invariants + caps)
- `assets/scripts/bargain/sim/enemy_ai.lua` + `assets/scripts/bargain/data/enemies.lua` (deterministic chase/attack)
- `assets/scripts/bargain/sim/deals.lua` + `assets/scripts/bargain/data/sins/*.lua` (offers + apply hooks)

### 5.3 Bridge (integrator-owned; minimal)
- `assets/scripts/bargain/game.lua` orchestrates sim + UI; no randomness/time.

---

## 6) Test Strategy (fast, failure-localizing, deterministic)

### 6.1 Test suite layout (explicit files)
- `assets/scripts/tests/run_bargain_tests.lua`
- `assets/scripts/tests/bargain/test_contracts.lua`
- `assets/scripts/tests/bargain/test_static_guards.lua` (no `pairs` in sim; no `math.random` in sim)
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

### 6.4 Floor invariants (property-style tests)
For a bounded set of seeds (e.g., 50 initially; tune later):
- `stairs` exists for floors 1–6 and is reachable from player spawn (BFS).
- Spawn safety: no enemy adjacent at spawn (or explicit rule).
- No infinite procgen loops: attempt cap triggers a deterministic fallback (and fails loudly in tests if fallback used unexpectedly).

### 6.5 Failure output contract (debuggability)
On any failing integration/determinism test, print:
- seed, floor, turn, phase, run_state
- pending_offer + chosen input
- last N events/messages (e.g., 20)
- digest (if computed)

---

## 7) Determinism Harness + Digest Spec

### 7.1 RNG API contract
- `world.rng` is the only randomness source.
- All randomness flows through the RNG object (no implicit random calls in helpers).

### 7.2 Digest payload (canonical order; no map iteration)
Serialize in fixed order:
- `floor_num`, `turn`, `phase`, `run_state`
- player tuple: `(x,y,hp,hp_max,xp,level,atk,def,speed,fov_radius)`
- entities: sorted by `id`, serialize `(id,kind,x,y,hp,selected_flags)`
- applied deals: sorted lexicographically
- optional: compact `deals.history` summary if needed for stability

### 7.3 Script runner (test-owned)
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
- contract + static guard tests (schemas, inputs, phases, RNG injection, offer gating, caps, no `pairs`, no `math.random`)
Accept:
- `test_contracts` + `test_static_guards` pass
- a tiny fixture produces identical digest twice.

### M1 — Core sim loop on a tiny fixed map
Deliver:
- grid movement/collision
- turn system + caps
- combat + ordering + RNG discipline
Accept:
- smoke test: player kills one enemy on fixed 5×5 with fixed script.

### M2 — Floors + FOV invariants (bounded procgen)
Deliver:
- floor generator for floors 1–7 meeting invariants with deterministic caps
- deterministic FOV visible set
Accept:
- invariants over bounded seeds pass within time cap; failures print seed repro.

### M3 — Deals system + 21 deals + downside enforcement
Deliver:
- forced floor-start offer + optional level-up offer
- 21 deals implemented (benefit + enforced downside via hooks)
Accept:
- Gate B, Gate C, Gate D pass.

### M4 — Enemies + boss + win/lose transitions
Deliver:
- enemy templates + deterministic AI
- boss on floor 7
- `run_state` transitions
Accept:
- boss defeat → victory; player HP ≤ 0 → death; AI determinism unit tests pass.

### M5 — Minimal UX flows (no sim logic)
Deliver:
- deal modal (forced vs optional)
- HUD + victory/death + restart
Accept:
- manual checklist on a known seed; confirm no sim logic moved into UI.

### M6 — Full-run determinism gate (S1–S3)
Deliver:
- digest + scripts + goldens for full 7-floor runs
Accept:
- Gate A + Gate E pass reliably for `S1,S2,S3`.

### M7 — Balance surface (separate, last)
Deliver:
- `assets/scripts/bargain/data/balance.lua` as the only tuning surface
- 3 recorded seeded runs (seed + script + outcome + duration)
Accept:
- baseline completion time target met (tune later), at least one seed winnable without debug hooks.

---

## 9) Parallel Work Breakdown (bead-sized, low-collision PRs)

### 9.1 Dependency graph (what unblocks what)
- M0 must land first (contracts + harness + skeleton exports).
- After M0:
  - Core sim (M1), floors/FOV (M2), deals (M3), AI/boss (M4), digest/scripts (M6 pieces) can proceed in parallel.
- UI work can start once `pending_offer` + phases are stable (post M0; richer UI after M3).

### 9.2 Bead units (each includes tests + explicit DoD)

**Integrator**
- I0: env hook + `run_bargain_tests.lua` + minimal `test_smoke.lua`
  - DoD: `RUN_BARGAIN_TESTS=1 <binary>` runs suite and exits correctly.
- I1: optional `AUTO_START_BARGAIN=1` wiring (default off) + wiring test

**Sim core**
- C1: `grid.lua` + tests: neighbor order, occupancy, sorted helpers
- C2: `turn_system.lua` + tests: phase progression, invalid action consumes turn, caps
- C3: `combat.lua` + tests: damage math, RNG usage, ordering
- C4: `step.lua` glue + smoke: fixed map, no offers/AI

**Floors / FOV**
- F1: invariants tests first (reachable stairs, spawn constraints, cap behavior)
- F2: procgen implementation satisfying invariants under bounded seeds
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

## 10) Change Control + Review Checklist (keeps merges sane)

### 10.1 Append-only rules
- Deal IDs and `sin` mapping become **append-only** after Gate C.
- Enemy IDs and boss ID become append-only once M4 lands.
- Digest schema changes require deliberate versioning or explicit rationale.

### 10.2 Golden digest update protocol
Any change to `expected_digests.lua` must include:
- updated digest values
- a 1-line rationale per digest change
- confirmation that two consecutive runs match bit-for-bit.

### 10.3 PR checklist (minimum)
- Adds/updates tests for the change.
- Runs Bargain test suite locally (`RUN_BARGAIN_TESTS=1 ...`).
- No `pairs()`/`math.random` introduced in sim subtree.
- Determinism-impacting changes include tie-breaker reasoning.

---

## 11) Risks + Mitigations (test-enforced where possible)

- Lua table iteration nondeterminism
  - Mitigation: sorted iteration helpers + `test_static_guards` scanning sim for `pairs(`.
- Hidden randomness/time in bridge/UI
  - Mitigation: M6 headless determinism tests (no UI dependency).
- Hook order drift
  - Mitigation: hooks are arrays; explicit order; unit test validates order.
- Procgen infinite loops / unreachable stairs
  - Mitigation: explicit attempt caps + invariant tests with seed repro output.
- “Downside exists but isn’t meaningfully negative”
  - Mitigation: downside tests must flip a concrete outcome under a fixed script.

---

## 12) Collaboration workflow (repo-specific)
- Track work in Beads:
  1) Triage with BV
  2) Claim bead (`in_progress`)
  3) Implement + tests (must pass harness)
  4) Close bead + notify via Agent Mail
- Before editing files: reserve paths exclusively via Agent Mail to avoid collisions.
- Keep PRs small and bead-scoped; prefer parallel sin PRs over one giant “deals” PR.
```