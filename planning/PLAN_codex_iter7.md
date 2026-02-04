# Game #4 “Bargain” — Engineering Plan (Iter6 rewrite: v6.0)

## 0) Goal + Definition of Done (DoD)

### Goal (single vertical slice)
Ship a complete, replayable, deterministic run loop:
- 7 floors total; floor 7 boss (“Sin Lord”)
- Win + Death + Restart → new seeded run
- 10–15 minute target session length per run

### DoD (ship gate; all must be true)
- End-to-end run can be completed (victory or death) without crashes for 3 fixed seeds.
- Forced deal is presented at *every* floor start **before** gameplay continues and **cannot** be skipped.
- Optional deal is offered on *every* level-up and **can** be skipped.
- Progression is **only** Faustian deals: every accepted deal applies both:
  - immediate benefit, and
  - permanent downside that changes gameplay behavior (not text-only)
- Content completeness: **21/21 deals exist** (7 sins × 3 deals), with stable IDs; and **21/21 downsides are enforced by automated tests**.
- Determinism gate: for fixed seed + scripted inputs, run produces a stable “state digest” (§8) across machines.

---

## 1) Scope / Constraints (frozen)

### Gameplay constraints
- Turn-based, grid-based, FOV-limited exploration/combat.
- Player verbs: `Move` (4-way), `Attack` (directional), `Wait`.
- Enemy AI: chase + attack only; no A* (BFS distance field allowed).

### Explicit non-features (do not build)
- No items/inventory/shops
- No save/load
- No meta-progression

### Engineering constraints
- All gameplay rules live in pure Lua sim: no rendering/input/engine globals.
- UI layer is thin: render `world`, translate input → sim actions.
- All randomness flows through a single injected RNG owned by sim.

---

## 2) Repository Integration (run/test hooks)

### Run (existing)
- `just build-debug-fast`
- `./build-debug/raylib-cpp-cmake-template`

### Auto-start modes (required)
- `AUTO_START_BARGAIN=1` → auto-enter Bargain loop (highest precedence)
- Manual entry: `require("bargain.game").start()`

### Test runner integration (required)
Reuse `assets/scripts/tests/test_runner.lua`.

Add `RUN_BARGAIN_TESTS=1` hook in `assets/scripts/core/main.lua`:
- runs early
- exits immediately via `os.exit(0|1)`
- invokes `require("tests.run_bargain_tests").run()`

Invocation:
- `RUN_BARGAIN_TESTS=1 ./build-debug/raylib-cpp-cmake-template`

---

## 3) Code Layout + Ownership (minimize conflicts)

All new Bargain code under `assets/scripts/bargain/`:
- `sim/` — pure simulation (no IO, no engine globals)
- `ui/` — rendering + input mapping + deal modal
- `data/` — deals/enemies/floors/balance tables
- `tests_support/` — fixtures/helpers used by `assets/scripts/tests/*`

Tests follow existing conventions:
- `assets/scripts/tests/test_bargain_*.lua`
- `assets/scripts/tests/run_bargain_tests.lua` (aggregator)

Single-owner “hot files” (avoid parallel edits):
- `assets/scripts/core/main.lua`
- `assets/scripts/tests/test_runner.lua` (only if needed)

---

## 4) Frozen Contracts (lock early; contract changes require tests-first)

### 4.1 `world` schema (freeze at M0)
Required:
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
  - `history` (ordered list `{deal_id, kind, floor_num, turn}`)
  - `pending_offer` (nil or offer struct)

Recommended (freeze if adopted):
- `world.stairs` (`{x,y}` or nil)
- `world.messages` (append-only strings or structs)
- `world.debug_flags` (test/dev only; must not affect release determinism)

### 4.2 Deal offer struct (freeze at M0)
`world.deals.pending_offer`:
- `kind` ∈ `{ "floor_start", "level_up" }`
- `offers` = array of deal IDs (stable order)
- `must_choose` = boolean
- `can_skip` = boolean

### 4.3 Entity schema (freeze at M0)
Required:
- `id`, `kind` (`"player"|"enemy"|"boss"`)
- `x`, `y`
- `hp`, `hp_max`, `atk`, `def`, `speed`, `fov_radius`
- `xp`, `level`
- `flags` (map; must be deterministic keys/values)
- `hooks` (hook_name → array of callbacks; callback order must be stable)

### 4.4 Action encoding (freeze at M0)
- Move: `{type="move", dx=0|±1, dy=0|±1}`
- Attack: `{type="attack", dx=0|±1, dy=0|±1}`
- Wait: `{type="wait"}`

Invalid action policy (pick now; enforce by tests):
- Recommended: returns `{ok=false, err="..."}` and still consumes the actor turn (deterministic).

### 4.5 Phase model (freeze at M0)
Phases:
- `DEAL_CHOICE` → `PLAYER_INPUT` → `PLAYER_ACTION` → `ENEMY_ACTIONS` → `END_TURN` → `PLAYER_INPUT`

Rules:
- If `pending_offer.must_choose=true`, sim stays in `DEAL_CHOICE` until a deal is chosen.

---

## 5) Module Interfaces (parallel-friendly; tests define behavior)

### 5.1 `bargain/sim/grid.lua`
Exports:
- `Grid.new(w,h)`
- `get_tile/set_tile`, `is_opaque`
- `place_entity`, `move_entity`
- `get_occupant`, `can_move_to`
- `neighbors4` (stable order)

Tests:
- bounds/walls/entities block movement
- occupancy invariants (positions↔occupants consistent)
- neighbor ordering stable

### 5.2 `bargain/sim/turn_system.lua`
Exports:
- `TurnSystem.new({world})`
- `queue_player_action(action)`
- `step()` advances exactly one phase transition
- `get_phase()`, `get_turn()`

Tests:
- exact phase sequence (including deal gate)
- player acts before enemies
- enemy action order deterministic: sort by `speed`, tie-break by `id`

### 5.3 `bargain/sim/combat.lua`
Exports:
- `resolve_attack(attacker_id, dx, dy, world) -> result`

Tests (freeze semantics):
- empty-target behavior (choose + freeze)
- damage formula deterministic (or RNG-based via `world.rng`; choose + freeze)
- death behavior (remove vs corpse flag; choose + freeze)

### 5.4 `bargain/sim/fov.lua`
Exports:
- `update(world, cx, cy, radius)` writes visibility state
- `get_state(x,y)` in `UNSEEN|SEEN|VISIBLE`

Tests:
- small golden occlusion maps
- memory transition: `VISIBLE → SEEN` when leaving LOS

### 5.5 `bargain/sim/deals.lua` + `bargain/data/sins/*.lua`
Data contract:
- exactly 21 deals; stable `deal_id` strings
- each deal provides:
  - `id`, `sin`, `name`
  - `benefit_text`, `downside_text`
  - `apply(world, player_id)` enforces benefit + downside (stats/flags/hooks/rules)

System contract:
- `get_offers(kind, world) -> offer_struct` (stable ordering)
- `apply_deal(deal_id, world)`

Tests:
- floor start offer: exactly 1 offer; `must_choose=true`, `can_skip=false`
- level-up offer: exactly 2 offers; `must_choose=false`, `can_skip=true`
- no duplicates of already-applied deals (unless explicitly allowed; decide + freeze)
- **21/21 downside enforcement**: table-driven assertions, 1+ per deal (ship gate)

### 5.6 `bargain/sim/enemy_ai.lua` + `bargain/data/enemies.lua`
Exports:
- `decide(enemy_id, world) -> action`

Tests:
- adjacent → attack
- otherwise move to reduce distance (Manhattan first; BFS field when walls exist)
- deterministic tie-break (axis preference then id)

### 5.7 `bargain/sim/floors.lua` + `bargain/data/floors.lua`
Exports:
- `generate(floor_num, seed, rng) -> {grid, entities, stairs?, metadata}`

Tests (invariants only; no brittle layout goldens):
- floor sizes match explicit table per floor
- enemy counts within allowed ranges
- stairs valid on floors 1–6; none on floor 7
- floor 7 contains boss

### 5.8 `bargain/game.lua` (integrator-owned)
Exports:
- `start()`, `update(dt)`
- `queue_action(action)`
- deal UI bridge:
  - `is_waiting_for_deal_choice()`
  - `choose_deal(deal_id)`
  - `skip_deal()` (only if allowed)

Debug hooks (test-safe, stable surface):
- `debug.goto_floor(n)`, `debug.set_hp(x)`, `debug.grant_xp(x)`

---

## 6) Test Plan (fast, deterministic, downside-enforcing)

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
- `test_bargain_determinism.lua` (digest gate)

### 6.2 Fixtures policy
- unit tests use tiny hand-authored maps (no procgen)
- procgen tests are invariants-only

### 6.3 Downside enforcement policy (ship gate)
For every deal: include at least one assertion that fails if the downside is removed.

Allowed enforcement mechanisms (must be testable in 1–3 turns):
- stat penalty/clamp (`hp_max`, `atk`, `def`, `speed`, `fov_radius`)
- per-turn tax (drain/decay)
- action restriction (e.g., cannot `wait`)
- risk-on-action (self-damage on move/attack)
- progression penalty (XP gain reduction, higher thresholds)
- spatial constraint (forced movement tendency, forbidden tiles)
- enemy modifier only if it changes gameplay in a verifiable way

Implementation approach:
- table-driven tests: each deal registers a minimal scenario + expected invariant(s)

---

## 7) Work Breakdown (milestones + gates)

### M0 — Wiring + contract freeze
Deliver:
- `RUN_BARGAIN_TESTS=1` hook + `run_bargain_tests.lua`
- stub modules with correct exports
- contract tests for `world`, phases, action encoding

Gate:
- Bargain tests run, fail cleanly, and exit reliably (no boot crash)

### M1 — Core sim loop (tiny fixed map)
Deliver:
- grid + movement/collision
- turn system + phase loop (deal gate included)
- combat resolution

Gate:
- `grid/turn/combat` tests pass

### M2 — FOV + floors invariants
Deliver:
- FOV occlusion + memory
- floor generator satisfies invariants for floors 1–7 (layout can be simple)

Gate:
- `fov/floors` tests pass

### M3 — Deals (21/21) + enforced downsides
Deliver:
- offer rules (forced floor-start; optional level-up)
- 21 deals with real benefits + enforced downsides
- per-deal enforcement tests (table-driven)

Gate:
- data loading proves 21 stable IDs
- deals tests prove offer rules + 21/21 enforcement

### M4 — Enemies + boss + win/lose
Deliver:
- enemy templates + deterministic chase/attack AI
- boss on floor 7
- victory/death transitions

Gate:
- enemy AI tests pass
- victory: boss defeat → `run_state="victory"`
- death: player hp ≤ 0 → `run_state="death"`

### M5 — UI flows (manual checklist + smoke)
Deliver:
- deal modal (forced vs optional skip)
- HUD (HP/stats/deals/floor/turn)
- victory/death screens + restart

Manual checklist:
- forced deal cannot be skipped
- level-up deal can be skipped
- restart produces a new seeded run

### M6 — Determinism hardening
Deliver:
- stable orchestrator in `bargain/game.lua`
- smoke tests for 3 fixed seeds
- determinism digest test

Gate:
- smoke passes for `{S1,S2,S3}`
- determinism digest passes

### M7 — Balance pass (time-to-complete target)
Deliver:
- `data/balance.lua` tuning surface
- 3 timed seeded runs recorded (notes committed)

Gate:
- average completion time ~10–15 minutes
- at least one seed winnable without debug hooks

---

## 8) Determinism Digest (exact spec; test-owned or sim-owned)

Digest serialization includes:
- `floor_num`, `turn`, `phase`, `run_state`
- player: position + `hp/hp_max`, `xp`, `level`, core stats
- sorted entities list: `(id, kind, x, y, hp, flags_subset)` sorted by `id`
- applied deal IDs sorted lexicographically

Rules (must be enforced in code review + tests):
- never rely on Lua table iteration order for serialization
- when selecting offers, use stable sorting/ordering rules
- when resolving ties in AI/pathing, use deterministic tie-breakers

---

## 9) Parallelization & Beads (explicit slicing)

### 9.1 Ownership lanes (can run in parallel after M0)
- Sim core: `bargain/sim/grid.lua`, `turn_system.lua`, `combat.lua`
- Perception/procgen: `bargain/sim/fov.lua`, `bargain/sim/floors.lua`, `bargain/data/floors.lua`
- Content/progression: `bargain/sim/deals.lua`, `bargain/data/sins/*`
- AI/enemies: `bargain/sim/enemy_ai.lua`, `bargain/data/enemies.lua`
- Integrator/UI: `bargain/game.lua`, `bargain/ui/*`, `assets/scripts/core/main.lua` (single owner)
- Tests: each lane owns its `test_bargain_*` files; shared aggregators single-owner

### 9.2 Highest-leverage bead unit: “one sin”
One bead = one sin (3 deals) + tests proving each downside:
- implement `assets/scripts/bargain/data/sins/<sin>.lua` (3 deals)
- extend aggregator `assets/scripts/bargain/data/sins.lua` (enforce exactly 21)
- add/extend `assets/scripts/tests/test_bargain_deals.lua` with 3 downside assertions

Dependencies:
- requires M0 contracts + `sim/deals.lua` scaffolding
- does not require UI

---

## 10) Coordination Protocol (repo-specific; enforce every time)

- Reserve files (exclusive) via Agent Mail before edits; keep reservations narrow.
- Beads workflow:
  1) Triage ready work (BV)
  2) Claim bead (`in_progress`)
  3) Implement + tests
  4) Close bead + notify dependents (Agent Mail)
- Contract changes require: tests-first update → module update → integrator update → broadcast delta.