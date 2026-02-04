```md
# Game #4 “Bargain” — Engineering Plan (v4, execution + verification focused)

## 0) Ship Target, Slice, Non‑Goals

### Ship target (one shippable slice)
A deterministic, replayable **single run of 7 floors**:

- Floors **1–6**: explore/combat → find **stairs** → descend.
- Floor **7**: boss (“Sin Lord”) → **victory** when defeated.
- Player death → **game over** → restart → new seeded run.
- **No softlocks**: the sim always reaches a next valid state (phase, inputs, AI, offers).

### Explicit non‑goals (out of scope for this slice)
- Inventory/items/shops, save/load, meta progression.
- Pathfinding beyond **BFS / distance-field** (no A*).
- Networking, replay UI, advanced VFX.

---

## 1) Hard Constraints (must hold; tested)

### 1.1 Determinism contract (non‑negotiable)
- **All gameplay rules live in pure Lua sim** (no rendering, IO, time/dt, engine globals).
- UI/bridge is a thin adapter: render from `world`; translate input → sim `input`.
- Single RNG source: `world.rng`. **Ban** `math.random` in sim.
- No nondeterministic iteration in rule-sensitive code:
  - **No `pairs()`** in sim logic affecting rules (AI, offers, hooks, entity processing, digest).
  - Use stable arrays + explicit sorting; tie-breakers are explicit (e.g., `id asc`).
- A single neighbor order is used everywhere: **N,E,S,W** (choose once; never vary).

### 1.2 Safety/termination contract
- Every `step()` call is bounded:
  - **Phase-transition cap** within one `step()` (e.g., max 64 internal transitions).
  - **Run cap** for scripts (e.g., max 5000 `step()` calls).
- Invalid inputs never crash; return `{ok=false, err=...}` and **consume the actor’s turn**.

### 1.3 Merge-safety (hot files policy)
- Minimize edits to:
  - `assets/scripts/core/main.lua` (only env hook + minimal wiring)
  - `assets/scripts/tests/test_runner.lua` (touch only if unavoidable)
- All Bargain work lives under:
  - `assets/scripts/bargain/**` (new)
  - `assets/scripts/tests/bargain/**` (new)
  - `assets/scripts/tests/run_bargain_tests.lua` (new)

---

## 2) Definition of Done (gates; fail fast)

### Gate A — Termination + no softlocks (blocking)
For fixtures `S1,S2,S3` + scripted inputs:
- Run ends in **victory or death**.
- **0 crashes**, **0 softlocks**, **0 infinite loops**.
- Caps enforced: hitting a cap fails tests with a useful dump (seed/floor/turn/phase + last N events).

### Gate B — Offer gating rules (blocking)
- **Every floor start**: forced deal offer
  - `must_choose=true`, `can_skip=false`
  - sim cannot advance past `DEAL_CHOICE` until chosen.
- **Every level-up**: optional deal offer
  - `must_choose=false`, `can_skip=true`
  - skip returns immediately to play.

### Gate C — Deals completeness (blocking)
- Exactly **21 deals** exist (7 sins × 3).
- Deal IDs stable + unique; each deal declares `sin`.

### Gate D — Downside enforcement (blocking)
- **21/21 deals** have an automated test proving a measurable downside.
- Each downside test must fail if the downside logic is removed.

### Gate E — Determinism digest (blocking)
- `seed + scripted inputs → digest` matches golden for `S1,S2,S3`.
- Two consecutive runs on the same machine match **bit-for-bit**.
- (Stretch) Cross-machine stability if no floats/platform variance exist.

---

## 3) “Single Command” Test Contract (exists first)

### 3.1 Entry hook (minimal change)
Add an early env-var hook in `assets/scripts/core/main.lua`:

- `RUN_BARGAIN_TESTS=1` runs Bargain tests and exits non-zero on failure.
- Must run before heavy UI bootstrapping.

### 3.2 Test entrypoint
- Reuse: `assets/scripts/tests/test_runner.lua`
- Add: `assets/scripts/tests/run_bargain_tests.lua` (aggregates Bargain suite)

### 3.3 Invocation contract (binary name varies)
- `RUN_BARGAIN_TESTS=1 <game_binary>`

---

## 4) Contract Freeze (M0): Interfaces that unblock parallel work

### 4.1 World schema (tests enforce)
Required fields:
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

Recommended (stabilizes UI + debugging + digest):
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

### 4.4 Sim input API + invalid action policy (tests enforce)
`step(world, input)` accepts:
- Move: `{type="move", dx=0|±1, dy=0|±1}`
- Attack: `{type="attack", dx=0|±1, dy=0|±1}`
- Wait: `{type="wait"}`
- Deal choose: `{type="deal_choose", deal_id="..."}`
- Deal skip: `{type="deal_skip"}`

Invalid input behavior:
- Return `{ok=false, err="..."}`
- **Consumes the actor’s turn**
- World invariants remain valid (no half-applied transitions).

### 4.5 Phase machine (frozen)
Phases:
- `DEAL_CHOICE`
- `PLAYER_INPUT`
- `PLAYER_ACTION`
- `ENEMY_ACTIONS`
- `END_TURN`

Canonical transition loop:
`DEAL_CHOICE → PLAYER_INPUT → PLAYER_ACTION → ENEMY_ACTIONS → END_TURN → PLAYER_INPUT`

Rules:
- Forced offers pin phase at `DEAL_CHOICE` until chosen.
- Enemy processing order: `speed desc`, tie-break `id asc`.

---

## 5) Module Layout + Public Exports (parallel-safe)

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
- `assets/scripts/bargain/game.lua` orchestrates sim + UI; **no randomness/time**.

---

## 6) Test Strategy (fast, deterministic, failure-localizing)

### 6.1 Test suite layout
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

### 6.2 Fixtures (stable + reviewable)
- `fixtures/bargain_seeds.lua`: `S1=0x00C0FFEE`, `S2=0x00BADA55`, `S3=0x00DEADBEEF`
- `fixtures/bargain_scripts.lua`: scripted inputs (including deal choices/skips)
- `fixtures/bargain_expected_digests.lua`: golden digests + one-line rationale per change

### 6.3 Downside enforcement pattern (table-driven; 21 rows)
Each deal must have:
- Arrange: minimal deterministic world + short script (1–20 steps).
- Act: apply deal + advance until downside should manifest.
- Assert: measurable negative effect that flips an outcome under fixed script:
  - worse combat result (HP remaining / death threshold),
  - per-turn drain triggers at `END_TURN`,
  - action restriction returns `ok=false` and consumes turn,
  - self-damage on move/attack,
  - XP penalty delays a known level-up point.

### 6.4 Debuggability contract (for failing tests)
On failure, tests should print:
- seed, floor, turn, phase, run_state
- pending_offer (if any), chosen input
- last N events/messages (e.g., 20)
- digest (if available)

---

## 7) Determinism Harness + Digest Spec

### 7.1 RNG API contract
- `world.rng` is the only randomness source.
- Explicit API only (e.g., `next_int(min,max)`, `choice(array)`).
- Procgen/offers/AI use RNG only via this API.

### 7.2 Digest payload (canonical order; no map iteration)
Serialize in fixed order:
- `floor_num`, `turn`, `phase`, `run_state`
- Player tuple: `(x,y,hp,hp_max,xp,level,atk,def,speed,fov_radius)`
- Entities: sort by `id`, serialize `(id,kind,x,y,hp,selected_flags)`
- Applied deals: sorted lexicographically
- Optional: compact `deals.history` summary if needed for stability

### 7.3 Script runner helper (test-owned)
- Start run with seed.
- Loop:
  - if `pending_offer` then consume next scripted `deal_choose/skip`
  - else consume next scripted move/attack/wait
- Stop on victory/death or fail on step cap.
- Return digest.

---

## 8) Milestones (deliverables + acceptance tests)

### M0 — Wiring + contract freeze (unblocks parallel work)
Deliver:
- `RUN_BARGAIN_TESTS` hook + `run_bargain_tests.lua`
- stub modules with correct exports
- contract tests: schemas, inputs, phase machine, RNG injection, deal gating, caps
Accept (tests):
- contract suite passes; two consecutive runs identical on same seed/script

### M1 — Core sim loop on fixed tiny map (rules baseline)
Deliver:
- grid collision/movement
- turn system + phase stepping + caps
- combat resolution (deterministic ordering + RNG discipline)
Accept (tests):
- `grid`, `turn_system`, `combat` pass
- smoke: player kills one enemy on fixed 5×5 under fixed script

### M2 — Floors + FOV invariants (bounded procgen)
Deliver:
- floor generator meets invariants for floors 1–7 (stairs reachable, spawn safety, no infinite loops)
- FOV occlusion + deterministic visible set
Accept (tests):
- invariants over bounded seeds (e.g., 50) pass within a time cap
- explicit iteration caps enforced (tests fail loudly on cap hit)

### M3 — Deals system + 21 deals + downside enforcement
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
- AI tests pass (tie-break determinism)
- boss defeat sets `run_state="victory"`
- player HP ≤ 0 sets `run_state="death"`

### M5 — Minimal UX flows (no sim logic)
Deliver:
- deal modal (forced vs optional)
- HUD (HP/stats/deals/floor/turn)
- victory/death screens + restart
Accept (manual checklist):
- known seed: forced offer at floor start; optional offer on level-up; win/lose screens correct

### M6 — Full-run determinism gate (S1–S3)
Deliver:
- digest + fixtures + scripted runner
- full 7-floor scripts for S1–S3
Accept (tests):
- determinism suite passes reliably for S1–S3 (Gate E)

### M7 — Balance surface (separate, last)
Deliver:
- `assets/scripts/bargain/data/balance.lua` as the sole tuning surface
- 3 recorded seeded runs (seed + script + outcome + duration)
Accept:
- average completion time ~10–15 minutes
- at least one seed winnable without debug hooks

---

## 9) Parallel Work Breakdown (bead-sized; test-first)

### Dependency structure (critical path)
- M0 contracts → enables parallel workstreams
- (M1 + M2 + M3 + M4) → enables M6 golden full-runs
- UI (M5) starts once offer flow + phase machine stabilize

### Beads (each bead = PR-sized, includes tests + clear DoD)
**Integrator (single-owner)**
- I0: `RUN_BARGAIN_TESTS` hook + `run_bargain_tests.lua` + smoke test
- I1: optional `AUTO_START_BARGAIN=1` entry (default off) + minimal wiring test

**Sim core**
- C1: `grid.lua` + tests (neighbor order, occupancy, sorted iteration helpers)
- C2: `turn_system.lua` + tests (phase progression, invalid action consumes turn, caps)
- C3: `combat.lua` + tests (damage math, RNG usage, ordering)
- C4: `step.lua` glue + smoke test (no offers, no AI; fixed map)

**Floors / FOV**
- F1: invariants spec tests first (stairs reachable, spawn constraints, cap behavior)
- F2: implement generator to satisfy invariants under bounded seeds
- V1: `fov.lua` + tests (occlusion determinism, visible set stability)

**AI / Boss**
- A1: `data/enemies.lua` schema + loading test
- A2: `enemy_ai.lua` + tests (chase/attack rules, tie-break determinism)
- A3: boss rules + test (floor 7 win condition)

**Deals (sin-parallelizable)**
- D0: `deals.lua` core (offer generation + apply plumbing) + Gate B tests
- D(1–7): one file per sin `data/sins/<sin>.lua` with 3 deals + 3 downside test rows

**Determinism**
- R1: digest implementation + harness tests (unit + integration)
- R2: scripts + expected digests for S1–S3 + rationale comments

**UI**
- U1: deal modal wiring (`pending_offer` → choose/skip input) (no sim logic)
- U2: HUD + run-state screens + restart flow (no sim logic)

---

## 10) Operational Risks + Mitigations (tested where possible)

- Lua table iteration nondeterminism
  - Mitigation: central sorted-iteration helpers; “no `pairs()` in sim” review rule + targeted tests/guards.
- Hidden randomness/time in UI/bridge
  - Mitigation: headless determinism tests (M6) must pass without UI involvement.
- Hook order drift
  - Mitigation: hooks are arrays; explicit execution order; unit test for ordering.
- Procgen infinite loops / unreachable stairs
  - Mitigation: explicit iteration caps + invariants tests that fail loudly with seed repro.
- Downside not actually negative
  - Mitigation: downside tests must flip an outcome under fixed script (not “field exists”).

---

## 11) Change Policy (keeps merges sane)
- Deal IDs and `sin` mapping are **append-only** after Gate C is met.
- Golden digest updates require:
  - updating `fixtures/bargain_expected_digests.lua`
  - a one-line rationale per changed digest (what rule change caused it)
  - confirming determinism stability across two consecutive runs.
```