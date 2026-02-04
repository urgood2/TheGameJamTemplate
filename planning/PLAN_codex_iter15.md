```md
# Game #4 “Bargain” — Engineering Plan (v3, execution-ready)

## 0) Outcome, Slice, Non‑Goals

### Outcome (ship slice)
A deterministic, replayable **single run of 7 floors**:

- Floors **1–6**: explore/combat → find **stairs** → descend.
- Floor **7**: boss (“Sin Lord”) → **victory** on defeat.
- Player death → **game over** → restart → new seeded run.
- **No softlocks**: sim always produces a next valid state; no stuck modal/phase; no infinite loops.

### Non‑goals (explicitly out of scope for the slice)
- Inventory/items/shops, save/load, meta progression.
- Any pathfinding beyond **BFS / distance-field** (no A*).
- Networking, replays UI, fancy VFX.

---

## 1) “Must Hold” Architecture Constraints

### 1.1 Sim determinism (non-negotiable)
- **All gameplay rules live in pure Lua sim** (no rendering, IO, time/dt, engine globals).
- UI is a **thin adapter**: render from `world` + translate input → sim input.
- Single injected RNG: `world.rng`.
  - **Ban** `math.random` in sim code.
- Deterministic ordering:
  - **No `pairs()`** in rule-sensitive code (AI, offers, hooks, entity processing, digest).
  - All tie-breaks explicit (e.g., `id asc`).
  - Global fixed neighbor order: **N,E,S,W** (or another single choice; standardize everywhere).

### 1.2 “Hot files” policy (merge safety)
Single-owner policy (minimize conflicts):
- `assets/scripts/core/main.lua` (only for env hook + minimal wiring).
- `assets/scripts/tests/test_runner.lua` (touch only if unavoidable).

All Bargain work lives under:
- `assets/scripts/bargain/**` (new)
- `assets/scripts/tests/bargain/**` (new)
- `assets/scripts/tests/run_bargain_tests.lua` (new)

---

## 2) Definition of Done (Hard Gates)

### Gate A — Termination + no softlocks (blocking)
For fixtures `S1,S2,S3` + scripted inputs:
- Run ends in **victory or death**.
- **0 crashes**, **0 softlocks**, **0 infinite loops**.
- `step()` completes within bounded internal transitions (guarded by a step cap).

### Gate B — Offer gating rules (blocking)
- **Every floor start**: forced deal offer
  - `must_choose=true`, `can_skip=false`
  - sim cannot advance past `DEAL_CHOICE` until chosen.
- **Every level-up**: optional deal offer
  - `must_choose=false`, `can_skip=true`
  - skip returns to play immediately.

### Gate C — Deals completeness (blocking)
- Exactly **21 deals** exist (7 sins × 3).
- IDs stable + unique; every deal declares `sin`.

### Gate D — Downside enforcement is real gameplay (blocking)
- **21/21 deals** have an automated test proving a measurable downside.
- Each test must fail if the downside is removed (no “field exists” assertions).

### Gate E — Determinism digest (blocking)
- `seed + scripted inputs → digest` matches golden for `S1,S2,S3`.
- Two consecutive runs on same machine match **bit-for-bit**.
- Stretch: matches across machines (if platform/float variance is not present).

---

## 3) Single-Command Test Contract (must exist early)

### 3.1 Entry contract
Add an early env-var hook in `assets/scripts/core/main.lua`:

- `RUN_BARGAIN_TESTS=1` runs Bargain tests and exits non-zero on failure.
- Must run before heavy UI bootstrapping.

Use existing runner:
- `assets/scripts/tests/test_runner.lua`

Add:
- `assets/scripts/tests/run_bargain_tests.lua` (aggregates Bargain suite)

### 3.2 Command examples (contract is env var, binary name can vary)
- `RUN_BARGAIN_TESTS=1 <game_binary>`

---

## 4) Contract Freeze (M0): Interfaces enabling parallel work

### 4.1 World schema (tests enforce)
Required:
- `world.grid`
- `world.entities` (map `id -> entity`)
- `world.player_id`
- `world.turn` (int, monotonically increasing)
- `world.phase` (string enum)
- `world.floor_num` (1..7)
- `world.run_state` (`"playing"|"victory"|"death"`)
- `world.rng`
- `world.deals.applied` (map `deal_id -> true`)
- `world.deals.history` (array of `{deal_id, kind, floor_num, turn}`)
- `world.deals.pending_offer` (nil or offer struct)

Recommended early (stabilizes UI + digest):
- `world.stairs` (`{x,y}` or nil)
- `world.events` (append-only deterministic structs from `step`)
- `world.messages` (append-only deterministic structs for UI)

### 4.2 Entity schema (tests enforce)
- `id`, `kind` (`"player"|"enemy"|"boss"`)
- `x`, `y`
- `hp`, `hp_max`, `atk`, `def`, `speed`, `fov_radius`
- `xp`, `level`
- `flags` (must not depend on map iteration order)
- `hooks` (hook_name → array; callback order explicit + stable)

### 4.3 Deal offer struct (no table iteration)
`world.deals.pending_offer`:
- `kind` ∈ `{ "floor_start", "level_up" }`
- `offers`: array of deal IDs (stable order)
- `must_choose`: bool
- `can_skip`: bool

### 4.4 Sim input + invalid action policy (tests enforce)
`step(world, input)` accepts:
- Move: `{type="move", dx=0|±1, dy=0|±1}`
- Attack: `{type="attack", dx=0|±1, dy=0|±1}`
- Wait: `{type="wait"}`
- Deal choose: `{type="deal_choose", deal_id="..."}`
- Deal skip: `{type="deal_skip"}`

Invalid input behavior:
- Return `{ok=false, err="..."}`
- **Consumes the actor’s turn** (prevents “spam invalid until favorable”).

### 4.5 Phase machine (frozen)
Phases:
- `DEAL_CHOICE`
- `PLAYER_INPUT`
- `PLAYER_ACTION`
- `ENEMY_ACTIONS`
- `END_TURN`

Transition loop:
`DEAL_CHOICE → PLAYER_INPUT → PLAYER_ACTION → ENEMY_ACTIONS → END_TURN → PLAYER_INPUT`

Deterministic rules:
- Forced offers pin phase at `DEAL_CHOICE` until chosen.
- Enemy processing order: `speed desc`, tie-break `id asc`.

---

## 5) Module Layout (parallel-safe) + Stable Exports

### 5.1 Sim API (frozen exports)
- `assets/scripts/bargain/sim/world.lua`
  - `new_run(seed, opts) -> world`
  - `new_floor(world, floor_num) -> world` (recommended)
- `assets/scripts/bargain/sim/step.lua`
  - `step(world, input) -> { world, events, ok, err? }`

### 5.2 Lanes (each lane ships with unit tests)
- `assets/scripts/bargain/sim/grid.lua` (bounds/occupancy/neighbor order/sorted iteration helpers)
- `assets/scripts/bargain/sim/turn_system.lua` (phase progression/turn consumption/deal gating)
- `assets/scripts/bargain/sim/combat.lua` (damage + RNG discipline)
- `assets/scripts/bargain/sim/fov.lua` (occlusion + deterministic visible set)
- `assets/scripts/bargain/sim/floors.lua` + `assets/scripts/bargain/data/floors.lua` (procgen + invariants)
- `assets/scripts/bargain/sim/enemy_ai.lua` + `assets/scripts/bargain/data/enemies.lua` (deterministic chase/attack)
- `assets/scripts/bargain/sim/deals.lua` + `assets/scripts/bargain/data/sins/*.lua` (offers + apply hooks)

### 5.3 Bridge (integrator-owned, minimal)
- `assets/scripts/bargain/game.lua`
  - orchestrates sim + UI, no randomness/time.

---

## 6) Test Strategy (fast, deterministic, failure-localizing)

### 6.1 Test tree (minimum set; extend as needed)
- `assets/scripts/tests/run_bargain_tests.lua`
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

### 6.2 Fixtures (reviewable + stable)
- `fixtures/bargain_seeds.lua`: `S1=0x00C0FFEE`, `S2=0x00BADA55`, `S3=0x00DEADBEEF`
- `fixtures/bargain_scripts.lua`: scripted inputs (including deal choices/skips)
- `fixtures/bargain_expected_digests.lua`: golden digests + one-line rationale per change

### 6.3 Downside enforcement pattern (table-driven; 21 rows)
For each deal:
- Arrange: minimal deterministic world + fixed short script (1–20 steps).
- Act: apply deal + advance until downside should manifest.
- Assert: observable negative effect that flips an outcome under fixed script (examples):
  - Worse combat result (HP remaining / death threshold).
  - Per-turn drain triggers at `END_TURN`.
  - Action restriction returns `ok=false` and consumes turn.
  - Self-damage on move/attack.
  - XP penalty delays level-up at a known turn.

---

## 7) Determinism Harness + Digest Spec

### 7.1 RNG contract
- `world.rng` is sole randomness source.
- Explicit API only (e.g., `next_int(min,max)`, `choice(array)`).
- Procgen/offers/AI use RNG only via this API.

### 7.2 Digest payload (canonical order; no map iteration)
Serialize in fixed order:
- `floor_num`, `turn`, `phase`, `run_state`
- Player tuple: `(x,y,hp,hp_max,xp,level,atk,def,speed,fov_radius)`
- Entities: sort by `id`, serialize `(id,kind,x,y,hp,selected_flags)`
- Applied deals: sorted lexicographically
- (Optional) compact `deals.history` summary if needed for stability

### 7.3 Script runner helper (test-owned)
- Starts run with seed.
- Loop:
  - if `pending_offer` then emit next scripted `deal_choose/skip`
  - else emit next scripted move/attack/wait
- Stops on victory/death or fails on step cap (e.g., 5000).
- Returns digest.

---

## 8) Milestones (deliverables + acceptance tests)

### M0 — Wiring + contract freeze (unblocks parallel work)
Deliver:
- `RUN_BARGAIN_TESTS` hook + `run_bargain_tests.lua`
- stub modules with correct exports
- contract tests: schemas, inputs, phase machine, RNG injection, deal gating
Accept (tests):
- contract suite passes; two consecutive runs identical on same seed/script

### M1 — Core sim loop on fixed tiny map
Deliver:
- grid collision/movement
- turn system + phase stepping
- combat resolution
Accept (tests):
- `grid`, `turn_system`, `combat` tests pass
- smoke: player kills one enemy on fixed 5×5 under fixed script

### M2 — Floors + FOV invariants (bounded procgen)
Deliver:
- floor generator meets invariants for floors 1–7
- FOV occlusion + memory model
Accept (tests):
- invariants over bounded seeds (e.g., 50) pass within a time cap
- explicit iteration caps enforced (tests fail loudly on cap hit)

### M3 — Deals core + 21 deals + downside enforcement
Deliver:
- forced floor-start offer + optional level-up offer
- all 21 deals implemented (benefit + enforced downside)
Accept (tests):
- data loading: 21 stable IDs, no dupes, all sins present
- offer rule tests pass (Gate B)
- 21/21 downside tests pass (Gate D)

### M4 — Enemies + boss + win/lose transitions
Deliver:
- enemy templates + deterministic AI
- boss on floor 7
- `run_state` transitions to victory/death
Accept (tests):
- AI unit tests pass (tie-break determinism)
- boss defeat sets `run_state="victory"`
- player HP ≤ 0 sets `run_state="death"`

### M5 — Minimal UX flows (no sim logic)
Deliver:
- deal modal (forced vs optional)
- HUD (HP/stats/deals/floor/turn)
- victory/death screens + restart
Accept (manual checklist):
- for a known seed: see forced offer at floor start; optional offer on level-up; run-state screens correct

### M6 — Full-run determinism gate (S1–S3)
Deliver:
- digest + fixtures + scripted runner
- full 7-floor scripts for S1–S3
Accept (tests):
- determinism suite passes reliably for S1–S3 (Gate E)

### M7 — Balance pass (separate surface, last)
Deliver:
- `assets/scripts/bargain/data/balance.lua` as sole tuning surface
- 3 recorded seeded runs (seed + script + outcome + duration)
Accept:
- average completion time ~10–15 minutes
- at least one seed winnable without debug hooks

---

## 9) Parallel Work Breakdown (bead-sized, test-first)

### Dependency graph (minimal)
- M0 contracts → everything else in parallel
- (M1 + M2 + M3 + M4) → M6 golden full-runs
- UI (M5) starts once offer flow + phase machine are stable

### Bead list (each bead = PR-sized, includes tests)
**Integrator (single-owner)**
- I0: `RUN_BARGAIN_TESTS` hook + `run_bargain_tests.lua`
- I1: optional `AUTO_START_BARGAIN=1` entry (default off)

**Sim core**
- C1: `grid.lua` + tests (neighbor order + deterministic helpers)
- C2: `turn_system.lua` + tests (phase progression + invalid action consumes turn)
- C3: `combat.lua` + tests (damage math + RNG discipline)
- C4: `step.lua` glue + smoke test

**Floors / FOV**
- F1: floors invariants tests first (spec + caps)
- F2: implement generator to satisfy invariants (bounded seeds)
- V1: `fov.lua` + tests (occlusion determinism + memory rules)

**AI / Boss**
- A1: `data/enemies.lua` schema + loading test
- A2: `enemy_ai.lua` + tests (targeting + tie-break determinism)
- A3: boss behavior + test (floor 7 win condition)

**Deals (sin-parallelizable)**
- D0: `deals.lua` core (offer generation + apply plumbing) + Gate B tests
- D(1–7): one file per sin `data/sins/<sin>.lua` with 3 deals + 3 downside test rows

**Determinism**
- R1: digest implementation + harness tests
- R2: scripts + expected digests for S1–S3

**UI**
- U1: deal modal wiring (`pending_offer` → choose/skip input)
- U2: HUD + run-state screens + restart flow (no sim logic)

---

## 10) Operational Risks + Mitigations

- Lua table iteration nondeterminism
  - Mitigation: central sorted-iteration helpers; enforce “no `pairs()` in sim” via review + targeted tests/guards.
- Hidden randomness/time in UI/bridge
  - Mitigation: headless determinism tests (M6) must pass without UI involvement.
- Hook order drift
  - Mitigation: hooks are arrays; explicit execution order; unit tests for ordering.
- Procgen infinite loops
  - Mitigation: explicit iteration caps + invariants tests that fail loudly.
- “Downside” not actually negative
  - Mitigation: downside tests must flip a measurable outcome under fixed script.

---

## 11) Change Policy (keeps merges sane)
- Deal IDs and `sin` mapping are **append-only** after Gate C is met.
- Golden digest updates require:
  - updating `fixtures/bargain_expected_digests.lua`
  - a one-line rationale per changed digest (what rule change caused it)
  - confirmation that determinism remains stable across two consecutive runs.
```