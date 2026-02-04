```md
# Game #4 “Bargain” — Engineering Plan (v2, execution-ready)

## 0) Goal, Slice, Non‑Goals

### Ship slice (vertical)
A deterministic, replayable **7-floor run**:

- Floors **1–6**: explore/combat → find **stairs** → descend
- Floor **7**: boss (“Sin Lord”) → **victory** on defeat
- Player death → **game over** → restart → new seeded run
- **No softlocks** (no stuck modal/phase, no “no valid actions”, no infinite loops)

### Non‑goals for slice
- No inventory/items/shops
- No save/load
- No meta progression
- No pathfinding beyond **BFS/distance-field** (no A*)

---

## 1) Hard Architecture Constraints (must hold)

### Sim purity + determinism
- **All gameplay rules live in pure Lua sim** (no rendering/IO/time/dt/engine globals)
- **UI is a thin adapter**: render from `world` + translate input → sim input
- Single injected RNG: `world.rng`
  - **Ban** `math.random` and any hidden randomness
- Deterministic ordering everywhere
  - No `pairs()` iteration in any rule-sensitive place (AI, offers, hooks, entity processing)
  - All tie-breaks explicit (e.g., `id asc`)

### Concurrency / merge strategy
- “Hot files” (single-owner policy to minimize conflicts):
  - `assets/scripts/core/main.lua` (test hook + entry wiring)
  - `assets/scripts/tests/test_runner.lua` (only if unavoidable)
- All Bargain work goes under:
  - `assets/scripts/bargain/**` (new)
  - `assets/scripts/tests/bargain/**` (new)
  - `assets/scripts/tests/run_bargain_tests.lua` (new aggregator)

---

## 2) Definition of Done (Gates)

### Gate A — No crash / no softlock (blocking)
For seeds `S1,S2,S3` with scripted inputs:
- Run always ends in **victory or death**
- **0 crashes**, **0 softlocks**, **0 infinite loops**
- Phase machine never stalls: `step()` always returns a next phase/state within bounded turns

### Gate B — Deal offer rules (blocking)
- **Every floor start**: forced deal offer
  - `must_choose=true`, `can_skip=false`
  - sim cannot advance until chosen
- **Every level-up**: optional deal offer
  - `must_choose=false`, `can_skip=true`
  - skip returns to play immediately

### Gate C — Content completeness (blocking)
- Exactly **21 deals** exist (7 sins × 3)
- Deal IDs are stable + unique; each deal declares `sin`

### Gate D — Downside enforcement (blocking, automated)
- **21/21 deals** have a test that proves a *gameplay* downside
- Test must fail if downside is removed (no “field exists” assertions)

### Gate E — Determinism digest (blocking)
- `seed + scripted inputs → digest` matches expected for `S1,S2,S3`
- Two consecutive runs on the same machine match bit-for-bit
- Stretch: digest matches across machines (if no platform variance)

---

## 3) Single-Command Test Contract

### Test entry (must work early)
Implement a new env-var hook in `assets/scripts/core/main.lua`:

- `RUN_BARGAIN_TESTS=1` runs Bargain tests and exits non-zero on failure
- Keep it early: it should run before any heavy UI bootstrapping

Use the existing runner:
- `assets/scripts/tests/test_runner.lua`

Add:
- `assets/scripts/tests/run_bargain_tests.lua` (aggregates Bargain suite)

Recommended command(s):
- `RUN_BARGAIN_TESTS=1 ./build-debug/raylib-cpp-cmake-template`
- Or via `Justfile` if preferred by the team (keep the env var contract stable)

---

## 4) Contract Freeze (M0): Interfaces that unblock parallel work

### 4.1 World schema (enforced by tests)
Required fields:
- `world.grid`
- `world.entities` (map `id -> entity`)
- `world.player_id`
- `world.turn` (int, monotonically increasing)
- `world.phase` (string enum)
- `world.floor_num` (1..7)
- `world.run_state` (`"playing"|"victory"|"death"`)
- `world.rng` (only randomness source)
- `world.deals.applied` (map `deal_id -> true`)
- `world.deals.history` (array of `{deal_id, kind, floor_num, turn}`)
- `world.deals.pending_offer` (nil or offer struct)

Recommended (freeze once adopted; prefer adding in M0):
- `world.stairs` (`{x,y}` or nil)
- `world.events` (append-only array of deterministic structs; produced by `step`)
- `world.messages` (append-only array of deterministic structs for UI)

### 4.2 Entity schema (enforced by tests)
- `id`, `kind` (`"player"|"enemy"|"boss"`)
- `x`, `y`
- `hp`, `hp_max`, `atk`, `def`, `speed`, `fov_radius`
- `xp`, `level`
- `flags` (reads/writes must not depend on map iteration order)
- `hooks` (hook_name → array; callback order stable and explicit)

### 4.3 Deal offer struct (no table iteration)
`world.deals.pending_offer`:
- `kind` ∈ `{ "floor_start", "level_up" }`
- `offers`: array of deal IDs (stable order)
- `must_choose`: bool
- `can_skip`: bool

### 4.4 Sim input encoding + invalid-action policy (tests enforce)
`step(world, input)` accepts:
- Move: `{type="move", dx=0|±1, dy=0|±1}`
- Attack: `{type="attack", dx=0|±1, dy=0|±1}`
- Wait: `{type="wait"}`
- Deal choose: `{type="deal_choose", deal_id="..."}`
- Deal skip: `{type="deal_skip"}`

Invalid input behavior:
- Return `{ok=false, err="..."}`
- **Consumes the actor’s turn** (prevents “spam invalid until RNG favorable”)

### 4.5 Phase machine (frozen)
Phases:
- `DEAL_CHOICE`
- `PLAYER_INPUT`
- `PLAYER_ACTION`
- `ENEMY_ACTIONS`
- `END_TURN`

Transition loop:
`DEAL_CHOICE → PLAYER_INPUT → PLAYER_ACTION → ENEMY_ACTIONS → END_TURN → PLAYER_INPUT`

Determinism rules:
- Forced offers pin phase at `DEAL_CHOICE` until chosen
- Enemy processing order: `speed desc`, tie-break `id asc`
- Neighbor order fixed globally: choose one and standardize everywhere (`N,E,S,W` recommended)
- All tie-breaks explicit (movement, targeting, offer ordering)

---

## 5) Module Layout (parallel-safe) + Ownership

### Sim API (frozen exports)
- `assets/scripts/bargain/sim/world.lua`
  - `new_run(seed, opts) -> world`
  - `new_floor(world, floor_num) -> world` (optional, but recommended to separate “descend”)
- `assets/scripts/bargain/sim/step.lua`
  - `step(world, input) -> { world=world, events=events, ok=bool, err?=string }`

### Lane modules (each ships with unit tests)
- `assets/scripts/bargain/sim/grid.lua`
  - bounds, occupancy, neighbor order, deterministic iteration helpers
- `assets/scripts/bargain/sim/turn_system.lua`
  - phase progression, turn consumption, deal gating
- `assets/scripts/bargain/sim/combat.lua`
  - hit/damage semantics, RNG usage
- `assets/scripts/bargain/sim/fov.lua`
  - occlusion + memory model (return deterministic visible set)
- `assets/scripts/bargain/sim/floors.lua` + `assets/scripts/bargain/data/floors.lua`
  - procgen + invariants
- `assets/scripts/bargain/sim/enemy_ai.lua` + `assets/scripts/bargain/data/enemies.lua`
  - deterministic chase/attack logic
- `assets/scripts/bargain/sim/deals.lua` + `assets/scripts/bargain/data/sins/*.lua`
  - offer generation + apply/remove hooks

### Bridge (integrator-owned, minimal)
- `assets/scripts/bargain/game.lua`
  - orchestrates sim + UI (no time/randomness)
  - emits UI events/messages from sim outputs

---

## 6) Test Strategy (fast, deterministic, failure-localizing)

### 6.1 Test tree
- `assets/scripts/tests/run_bargain_tests.lua` (aggregator)
- `assets/scripts/tests/bargain/test_bargain_contracts.lua`
- `assets/scripts/tests/bargain/test_bargain_grid.lua`
- `assets/scripts/tests/bargain/test_bargain_turn_system.lua`
- `assets/scripts/tests/bargain/test_bargain_combat.lua`
- `assets/scripts/tests/bargain/test_bargain_fov.lua`
- `assets/scripts/tests/bargain/test_bargain_enemy_ai.lua`
- `assets/scripts/tests/bargain/test_bargain_floors_invariants.lua`
- `assets/scripts/tests/bargain/test_bargain_data_loading.lua`
- `assets/scripts/tests/bargain/test_bargain_deals_downsides.lua`
- `assets/scripts/tests/bargain/test_bargain_smoke.lua`
- `assets/scripts/tests/bargain/test_bargain_determinism.lua`

### 6.2 Fixtures (stable, reviewable)
- `assets/scripts/tests/bargain/fixtures/bargain_seeds.lua`
  - `S1=0x00C0FFEE`, `S2=0x00BADA55`, `S3=0x00DEADBEEF`
- `assets/scripts/tests/bargain/fixtures/bargain_scripts.lua`
  - scripted inputs (include deal choices when prompted)
- `assets/scripts/tests/bargain/fixtures/bargain_expected_digests.lua`
  - golden digests + one-line rationale per digest change

### 6.3 Downside enforcement pattern (table-driven; 21 rows)
For each deal:
- Arrange: minimal deterministic world + fixed script (1–20 steps)
- Act: apply deal + advance until downside should manifest
- Assert: observable negative effect that flips an outcome:
  - combat result changes under fixed script
  - per-turn drain triggers at `END_TURN`
  - action restriction returns `ok=false` and consumes turn
  - self-damage on move/attack
  - XP penalty delays level-up under fixed script

---

## 7) Determinism Harness + Digest Spec

### 7.1 RNG contract
- `world.rng` is sole randomness
- API must be explicit (e.g., `next_int(min,max)`, `choice(array)`)
- Procgen/offers/AI use RNG only through this API

### 7.2 Digest payload (canonical order; no map iteration)
Serialize in fixed order:
- `floor_num`, `turn`, `phase`, `run_state`
- Player: `(x,y,hp,hp_max,xp,level,atk,def,speed,fov_radius)`
- Entities: sort by `id`, serialize `(id,kind,x,y,hp,selected_flags)`
- Applied deals: sorted lexicographically
- Optional: compact `deals.history` summary (only if needed for stability)

### 7.3 Script runner (test-owned)
- Implement a helper used only by tests:
  - starts run with seed
  - loops: if `pending_offer` then emits next scripted `deal_choose/skip`
  - otherwise emits next scripted move/attack/wait
  - stops on victory/death or fails on step cap (e.g., 5000)
  - returns digest

---

## 8) Milestones (deliverables + acceptance criteria)

### M0 — Wiring + Contract Freeze (unblocks parallel)
Deliver:
- `RUN_BARGAIN_TESTS=1` hook + `run_bargain_tests.lua`
- stub modules with correct exports
- contract tests: schemas, inputs, phase machine, RNG injection, deal gating
Accept:
- two consecutive runs produce identical outputs
- contract tests pass on CI/local

### M1 — Core sim loop on fixed tiny map
Deliver:
- grid collision/movement
- turn system + phase stepping
- combat resolution
Accept:
- unit tests pass (`grid`, `turn_system`, `combat`)
- smoke test: player kills one enemy on fixed 5×5 without desync

### M2 — Floors invariants + FOV invariants (bounded procgen)
Deliver:
- floor generator meets invariants for 1–7
- FOV occlusion + memory model
Accept:
- invariants over bounded seeds (e.g., 50 seeds) pass within time caps
- explicit iteration caps enforced (failing tests if exceeded)

### M3 — Deals (21) + downside enforcement
Deliver:
- forced floor-start offer + optional level-up offer
- all 21 deals implemented (benefit + enforced downside)
Accept:
- data loading proves 21 stable IDs, no dupes, all sins present
- offer rule tests pass
- 21/21 downside tests pass

### M4 — Enemies + Boss + win/lose transitions
Deliver:
- enemy templates + deterministic AI
- boss on floor 7
- `run_state` transitions to victory/death
Accept:
- AI unit tests pass
- boss defeat sets `run_state="victory"`
- player HP ≤ 0 sets `run_state="death"`

### M5 — Minimal UX flows (no sim logic)
Deliver:
- deal modal (forced vs optional)
- HUD (HP/stats/deals/floor/turn)
- victory/death screens + restart
Accept:
- manual checklist entries recorded (seed, action script, expected screens)

### M6 — Full-run determinism gate (S1–S3)
Deliver:
- digest + fixtures + scripted runner
- full 7-floor scripts for S1–S3
Accept:
- determinism tests pass reliably for S1–S3

### M7 — Balance pass (last, separate surface)
Deliver:
- `assets/scripts/bargain/data/balance.lua` as sole tuning surface
- 3 recorded seeded runs (seed + script + outcome + duration)
Accept:
- average completion time ~10–15 minutes
- at least one seed winnable without debug hooks

---

## 9) Parallel Work Breakdown (bead-sized, test-first)

### Dependencies (simple)
- M0 contracts → everything else in parallel
- (M1 + M2 + M3 + M4) → M6 golden full-runs
- UI (M5) starts once offer flow + phase machine are stable

### Suggested bead granularity (each bead = PR-sized)
**Integrator beads (single-owner)**
- I0: `RUN_BARGAIN_TESTS` hook + `run_bargain_tests.lua` wired
- I1: add `AUTO_START_BARGAIN=1` entry (optional; keep off by default)

**Sim Core beads**
- C1: `grid.lua` + `test_bargain_grid.lua` (neighbor order + occupancy)
- C2: `turn_system.lua` + tests (phase progression + invalid action consumes turn)
- C3: `combat.lua` + tests (damage math + RNG discipline)
- C4: `step.lua` loop glue + `test_bargain_smoke.lua`

**Floors/FOV beads**
- F1: `floors.lua` invariants tests first (no generator yet; just spec + caps)
- F2: implement generator to satisfy invariants (bounded seeds)
- V1: `fov.lua` + tests (occlusion determinism + memory rules)

**AI/Enemies beads**
- A1: `data/enemies.lua` schema + loading test
- A2: `enemy_ai.lua` + tests (tie-breaks + targeting determinism)
- A3: boss behavior + test (floor 7 win condition)

**Deals beads (sin-parallelizable)**
- D0: `deals.lua` core (offer generation + apply plumbing) + tests for Gate B
- D(1–7): one file per sin `data/sins/<sin>.lua` with 3 deals + 3 downside assertions
  - Each bead includes its rows in `test_bargain_deals_downsides.lua`

**Determinism beads**
- R1: digest implementation + `test_bargain_determinism.lua` harness
- R2: scripts + expected digests for S1–S3 (Gate E)

**UI beads**
- U1: deal modal wiring (reads `pending_offer`, emits choose/skip input)
- U2: HUD + run-state screens + restart flow (no sim logic)

---

## 10) Risk Register + Mitigations (operational)

- Lua table iteration nondeterminism
  - Mitigation: central helper in `grid.lua` or `sim/util.lua` for sorted IDs/keys; ban `pairs()` in sim hot paths
- Hidden randomness/time in bridge/UI
  - Mitigation: determinism golden tests (M6) must pass with UI disabled/headless mode
- Hook order drift
  - Mitigation: hooks stored as arrays; execution order explicitly defined
- Procgen infinite loops
  - Mitigation: explicit iteration caps + invariant tests that fail loudly when caps hit
- “Downside” not actually negative
  - Mitigation: downside tests must flip a measurable outcome under fixed script (not just “apply succeeded”)

---
```