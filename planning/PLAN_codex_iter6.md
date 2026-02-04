# Game #4 “Bargain” — Engineering Plan (Iter5 rewrite: v5.0)

## 0) Goal + Definition of Done (DoD)

### Goal (vertical slice)
Ship a complete, replayable run loop:
- 7 floors total; floor 7 boss (“Sin Lord”)
- Win + Death screens
- Restart → new seeded run
- 10–15 minute target session length (one run)

### DoD (hard, testable)
A build is “done” only when all are true:
- A seeded run can be completed end-to-end (victory or death) without crashes.
- Forced deal is presented at every floor start, before gameplay continues, and cannot be skipped.
- Optional deal is offered on level-up and can be skipped.
- Progression is only Faustian deals: each deal applies (a) immediate benefit and (b) permanent downside that changes gameplay behavior (not text-only).
- 21/21 deals exist (7 sins × 3 deals), with stable IDs, and 21/21 downsides are enforced by automated tests.
- Determinism: for a fixed seed + scripted inputs, the run produces a stable “state digest” (see §7.4).

---

## 1) Scope / Constraints

### Non-negotiables
Gameplay:
- Turn-based, grid-based, FOV-limited exploration/combat.
- Player verbs: `Move` (4-way), `Attack` (directional), `Wait`.
- Enemy AI: chase + attack only; no A* (BFS distance field allowed).

Content:
- Forced deal at floor start (cannot skip).
- Optional deal at level-up (can skip).
- No items/inventory/shops, no save/load, no meta-progression.

### Engineering constraints
- All gameplay rules in pure Lua sim (no rendering/input/engine globals).
- UI layer is thin: renders `world` + maps input to sim actions.
- All randomness flows through a single injected RNG (sim-owned).

---

## 2) Repo Integration (Run/Test Hooks)

### Build/run (existing)
- `just build-debug-fast`
- `./build-debug/raylib-cpp-cmake-template`

### Auto-start mode
Support both:
- `AUTO_START_BARGAIN=1` (auto-enter Bargain loop)
- Manual entry: `require("bargain.game").start()`

Precedence rule:
- `AUTO_START_BARGAIN=1` overrides any other auto-start env.

### Test runner integration
Reuse existing `assets/scripts/tests/test_runner.lua`.

Add `RUN_BARGAIN_TESTS=1` hook in `assets/scripts/core/main.lua` (mirroring existing patterns):
- Runs early, exits immediately with `os.exit(0|1)`
- Loads `require("tests.run_bargain_tests").run()`

Invocation:
- `RUN_BARGAIN_TESTS=1 ./build-debug/raylib-cpp-cmake-template`

---

## 3) Code Layout (conflict-minimizing)

All new Bargain code under `assets/scripts/bargain/`:
- `sim/` — pure simulation
- `ui/` — rendering + input mapping + deal modal
- `data/` — deals/enemies/floors/balance tables
- `tests_support/` (optional) — helpers/fixtures used by `assets/scripts/tests/*`

Tests live with existing conventions:
- `assets/scripts/tests/test_bargain_*.lua`
- `assets/scripts/tests/run_bargain_tests.lua` (aggregator)

---

## 4) Frozen Contracts (lock early; change via protocol)

### 4.1 `world` schema (M0 freeze)
Minimum:
- `world.grid`
- `world.entities` (id → entity)
- `world.player_id`
- `world.turn` (int)
- `world.phase` (string enum)
- `world.floor_num`
- `world.run_state` (`"playing"|"victory"|"death"`)
- `world.rng`
- `world.deals`:
  - `applied` (deal_id → true)
  - `history` (ordered list of `{deal_id, kind, floor_num, turn}`)
  - `pending_offer` (nil or offer struct)

Recommended (still M0-frozen if adopted):
- `world.stairs` (nil or `{x,y}`) on floors 1–6
- `world.messages` (append-only)
- `world.debug_flags` (test/dev hooks)

### 4.2 Deal offer struct (M0 freeze)
`world.deals.pending_offer` shape:
- `kind` ∈ `{ "floor_start", "level_up" }`
- `offers` = array of deal IDs
- `must_choose` = boolean
- `can_skip` = boolean

### 4.3 Entity schema (M0 freeze)
Required:
- `id`, `kind` (`"player"|"enemy"|"boss"`)
- `x`, `y`
- `hp`, `hp_max`, `atk`, `def`, `speed`, `fov_radius`
- `xp`, `level`
- `flags` (map)
- `hooks` (hook_name → array of callbacks)

### 4.4 Action encoding (M0 freeze)
- Move: `{type="move", dx=0|±1, dy=0|±1}`
- Attack: `{type="attack", dx=0|±1, dy=0|±1}`
- Wait: `{type="wait"}`

Invalid action policy (choose and lock with tests at M0):
- Recommended: deterministic no-op result `{ok=false, err="..."}` and still consumes the actor turn.

### 4.5 Phase model (M0 freeze)
Explicit phases (string enum):
- `DEAL_CHOICE` → `PLAYER_INPUT` → `PLAYER_ACTION` → `ENEMY_ACTIONS` → `END_TURN` → `PLAYER_INPUT`
Rules:
- If `pending_offer.must_choose=true`, sim stays in `DEAL_CHOICE` until a deal is chosen.

---

## 5) Module Contracts (parallel-friendly)

Rule of engagement:
1) Update/introduce contract tests first.
2) Implement module to satisfy them.
3) Update integrator/UI glue.
4) Announce contract deltas to dependents (Agent Mail).

### 5.1 `bargain/sim/grid.lua`
Exports:
- `Grid.new(w,h)`
- `get_tile/set_tile`, `is_opaque`
- `place_entity`, `move_entity`
- `get_occupant`, `can_move_to`
- `neighbors4`

Tests:
- Bounds/walls/entities block movement.
- Occupancy invariants (bijective positions↔occupants).
- Deterministic neighbor ordering.

### 5.2 `bargain/sim/turn_system.lua`
Exports:
- `TurnSystem.new({world})`
- `queue_player_action(action)`
- `step()` (advances exactly one phase transition)
- `get_phase()`, `get_turn()`

Tests:
- Phase order exact (including `DEAL_CHOICE` gate).
- Player acts before enemies.
- Enemy order deterministic: sort by `speed`, tie-break by `id`.

### 5.3 `bargain/sim/combat.lua`
Exports:
- `resolve_attack(attacker_id, dx, dy, world) -> result`

Tests (lock semantics):
- Empty-target behavior (either consumes turn or not; choose and freeze).
- Damage formula deterministic (or RNG-based via `world.rng`; choose and freeze).
- Death behavior (remove entity vs corpse flag; choose and freeze).

### 5.4 `bargain/sim/fov.lua`
Exports:
- `update(world, cx, cy, radius)` (writes visibility state into grid or a dedicated map)
- `get_state(x,y)` in `UNSEEN|SEEN|VISIBLE`

Tests:
- Golden occlusion maps (small, explicit).
- Memory: `VISIBLE → SEEN` when leaving LOS.

### 5.5 `bargain/sim/deals.lua` + `bargain/data/sins/*.lua`
Data contract:
- Exactly 21 deals; stable `deal_id` strings.
- Each deal provides:
  - `id`, `sin`, `name`
  - `benefit_text`, `downside_text`
  - `apply(world, player_id)` that *enforces* benefit+downside (stats/flags/hooks/rules)

System contract:
- `get_offers(kind, world) -> offer_struct`
- `apply_deal(deal_id, world)`

Tests:
- Floor start offer: exactly 1 offer; `must_choose=true`, `can_skip=false`.
- Level-up offer: exactly 2 offers; `must_choose=false`, `can_skip=true`.
- No duplicates of already-applied deals (unless explicitly allowed; decide and lock).
- 21/21 downside enforcement: table-driven assertions, one per deal (ship gate).

### 5.6 `bargain/sim/enemy_ai.lua` + `bargain/data/enemies.lua`
Exports:
- `decide(enemy_id, world) -> action`

Tests:
- Adjacent → attack.
- Otherwise move to reduce distance (start Manhattan; upgrade to BFS distance field when walls exist).
- Deterministic tie-break (axis preference then id).

### 5.7 `bargain/sim/floors.lua` + `bargain/data/floors.lua`
Exports:
- `generate(floor_num, seed, rng) -> {grid, entities, stairs?, metadata}`

Tests:
- Floor sizes match explicit table per floor.
- Enemy counts within allowed ranges.
- Stairs valid on floors 1–6; no stairs on floor 7.
- Floor 7 contains boss.

### 5.8 `bargain/game.lua` (integrator-owned)
Exports:
- `start()`, `update(dt)`
- `queue_action(action)`
- Deal UI bridge:
  - `is_waiting_for_deal_choice()`
  - `choose_deal(deal_id)`
  - `skip_deal()` (only if allowed)

Debug hooks (test-safe, stable):
- `debug.goto_floor(n)`, `debug.set_hp(x)`, `debug.grant_xp(x)`

---

## 6) Test Strategy (fast, deterministic, enforce downsides)

### 6.1 Required test modules
- `test_bargain_grid.lua`
- `test_bargain_turn_system.lua`
- `test_bargain_combat.lua`
- `test_bargain_fov.lua`
- `test_bargain_enemy_ai.lua`
- `test_bargain_deals.lua` (offer rules + per-deal enforcement table)
- `test_bargain_data_loading.lua` (21 deals, stable IDs, no dupes)
- `test_bargain_floors.lua` (invariants only)
- `test_bargain_game_smoke.lua` (multi-floor minimal run)
- `test_bargain_determinism.lua` (digest)

### 6.2 Fixtures policy
- Unit tests use tiny hand-authored maps/fixtures (no procgen).
- Procgen tests are invariants-only (no brittle golden layouts).

### 6.3 Deal downside enforcement policy (ship gate)
For every deal, include at least one assertion that would fail if the downside were removed.
Acceptable enforcement mechanisms (must be testable):
- Stat clamp/penalty (`hp_max`, `atk`, `def`, `speed`, `fov_radius`)
- Per-turn tax (drain/decay)
- Action restriction (e.g., cannot `wait`, conditional attacks)
- Risk-on-action (self-damage on move/attack)
- Progress penalty (XP gain reduction, level threshold increase)
- Spatial constraint (forced movement tendency, forbidden tiles)
- Enemy modifier only if it changes gameplay in a verifiable way

Implementation guideline:
- Table-driven test where each deal registers a minimal scenario + expected invariant over 1–3 turns.

### 6.4 Determinism digest (ship gate)
Add a digest function (test-owned or sim-owned) that serializes:
- `floor_num`, `turn`, `phase`, `run_state`
- Player: `hp/hp_max`, `xp`, `level`, core stats, position
- Sorted entities list: `(id, kind, x, y, hp, flags subset)`
- Applied deal IDs sorted
Then:
- Start run with seed `S`
- Apply deterministic forced-deal choice (e.g., always first offer)
- Execute a fixed action script for N steps
- Assert digest equals expected string

---

## 7) Milestones (test-gated, shippable increments)

### M0 — Test wiring + contract freeze
Deliver:
- `RUN_BARGAIN_TESTS=1` hook + `run_bargain_tests.lua`
- Stub modules with correct exports
- Contract tests for `world` schema, phases, action encoding

Gate:
- Bargain tests run, fail cleanly, exit reliably (no boot-time crash).

### M1 — Core sim loop on fixed tiny map
Deliver:
- Grid + movement/collision
- Turn system + phase loop (including deal gate)
- Combat resolution

Gate:
- Grid/turn/combat tests pass.

### M2 — FOV + floor invariants
Deliver:
- FOV occlusion + memory
- Floor generator that satisfies invariants for floors 1–7 (layout can be simple)

Gate:
- FOV + floors tests pass.

### M3 — Deals: 21/21 + enforced downsides
Deliver:
- Offer rules implemented (forced floor-start; optional level-up)
- 21 deals (7 sins × 3) with real benefits + enforced downsides
- Per-deal enforcement tests (table-driven)

Gate:
- Data loading proves 21 stable IDs.
- Deals tests prove offer rules + 21/21 enforcement.

### M4 — Enemies + AI + boss win/lose
Deliver:
- Enemy templates + deterministic chase/attack AI
- Boss on floor 7
- Victory/death state transitions

Gate:
- Enemy AI tests pass.
- Victory test: boss defeat → `run_state="victory"`.
- Death test: player hp ≤ 0 → `run_state="death"`.

### M5 — UI flows (manual verification + basic smoke)
Deliver:
- Deal modal (forced vs optional skip)
- HUD (HP/stats/deals/floor/turn)
- Victory/death screens + restart

Manual checklist:
- Forced deal cannot be skipped.
- Level-up deal can be skipped.
- Restart produces a new seeded run.

### M6 — Integration hardening + determinism
Deliver:
- `bargain/game.lua` orchestrator stabilized
- Multi-floor smoke tests on 3 fixed seeds
- Determinism digest test

Gate:
- Smoke passes for seeds `{S1,S2,S3}`.
- Determinism digest passes.

### M7 — Balance pass (time-to-complete target)
Deliver:
- `data/balance.lua` tuning surface
- 3 timed seeded runs recorded (notes in repo)

Gate:
- Average completion time ~10–15 minutes; at least one seed winnable without debug hooks.

---

## 8) Parallelization (workstreams + bead slicing)

### 8.1 Ownership lanes (minimize merge conflicts)
- Sim core: `bargain/sim/grid.lua`, `turn_system.lua`, `combat.lua`
- Perception/procgen: `bargain/sim/fov.lua`, `bargain/sim/floors.lua`, `bargain/data/floors.lua`
- Content/progression: `bargain/sim/deals.lua`, `bargain/data/sins/*`
- AI/enemies: `bargain/sim/enemy_ai.lua`, `bargain/data/enemies.lua`
- Integrator/UI: `bargain/game.lua`, `bargain/ui/*`, `assets/scripts/core/main.lua` (single owner)
- Tests: split by module; keep each test file owned with its module lane

### 8.2 Highest-leverage parallel unit: “one sin”
Structure:
- `assets/scripts/bargain/data/sins/<sin>.lua` defines 3 deals
- `assets/scripts/bargain/data/sins.lua` aggregates and enforces “exactly 21”

Bead definition:
- One bead = one sin (3 deals) + tests proving each downside

Dependencies:
- Requires M0 freeze + `sim/deals.lua` offer/apply scaffolding
- Does not require UI

---

## 9) Coordination Protocol (repo-specific)

- Before editing, reserve files (exclusive) via Agent Mail.
- Use Beads workflow:
  1) Triage (BV)
  2) Claim bead (`in_progress`)
  3) Implement + tests
  4) Close bead + notify dependents (Agent Mail)
- Contract changes require: tests-first update → module update → integrator update → broadcast delta.

---

## 10) Risks + Mitigations (test-backed)

- “Downside drift” into text-only → Mitigation: 21/21 enforcement gate + table-driven per-deal tests.
- FOV regressions → Mitigation: golden-map tests (no procgen dependence).
- Nondeterminism (iteration/RNG leaks) → Mitigation: stable sorts everywhere + digest test.
- Integration churn in engine loop → Mitigation: single integrator owner + early test hook exit.
- Procgen flakiness → Mitigation: procgen tests are invariants-only + fixed-seed smoke.