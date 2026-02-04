# Game #4 “Bargain” — Engineering Plan (Iter7: v7.0)

## 0) Objective + Definition of Done (ship gate)

### Objective (one complete vertical slice)
Ship a replayable, deterministic 7-floor run loop:
- Floors 1–6: explore/combat → reach stairs
- Floor 7: boss (“Sin Lord”) → victory on defeat
- Death → game-over screen → restart → new seeded run
- Target run length: 10–15 minutes

### DoD (all must be true)
**Stability**
- For 3 fixed seeds, a full run can be completed to **victory or death** with **no crashes** and no softlocks.

**Deal rules**
- A **forced** deal is presented at **every floor start** *before gameplay continues* and **cannot** be skipped.
- An **optional** deal is offered at **every level-up** and **can** be skipped.

**Progression**
- The only progression mechanism is **Faustian deals**.
- Every accepted deal applies both:
  - an immediate benefit, and
  - a permanent downside that changes gameplay behavior (not text-only).

**Content completeness**
- Exactly **21 deals** exist (7 sins × 3 deals) with **stable IDs**.
- **21/21 downsides are enforced by automated tests** (at least 1 assertion per deal that fails if the downside is removed).

**Determinism**
- For a fixed seed + scripted inputs, the sim produces a stable **state digest** across machines (see §8).

---

## 1) Non-goals / constraints (frozen)

### Gameplay constraints
- Turn-based, grid-based, FOV-limited exploration/combat.
- Player verbs: `Move` (4-way), `Attack` (directional), `Wait`.
- Enemy AI: chase + attack only; no A* (BFS / distance-field allowed).

### Explicit non-features
- No inventory/items/shops
- No save/load
- No meta-progression

### Engineering constraints
- All gameplay rules live in **pure Lua sim** (no engine globals, no rendering/input calls).
- UI layer is thin: render from `world`, translate input → sim actions.
- All randomness flows through a **single injected RNG** owned by the sim.

---

## 2) Repo integration (run/test hooks, minimal hot-file edits)

### Existing run
- `just build-debug-fast`
- `./build-debug/raylib-cpp-cmake-template`

### Required entry modes
- `AUTO_START_BARGAIN=1` → auto-enter Bargain loop (highest precedence)
- Manual entry: `require("bargain.game").start()`

### Required test runner integration
Reuse `assets/scripts/tests/test_runner.lua`.

Add `RUN_BARGAIN_TESTS=1` hook in `assets/scripts/core/main.lua`:
- runs early
- exits immediately via `os.exit(0|1)`
- invokes `require("tests.run_bargain_tests").run()`

Invocation:
- `RUN_BARGAIN_TESTS=1 ./build-debug/raylib-cpp-cmake-template`

**Hot-file policy**
- Only one bead edits `assets/scripts/core/main.lua` (M0 integrator bead).
- Prefer adding new modules over touching shared infrastructure.

---

## 3) Directory layout + ownership lanes (conflict-minimizing)

All new Bargain code under `assets/scripts/bargain/`:
- `sim/` — pure simulation (deterministic, no IO)
- `ui/` — rendering + input mapping + deal modal
- `data/` — deals/enemies/floors/balance tables
- `tests_support/` — fixtures/helpers used by tests

Tests under `assets/scripts/tests/`:
- `test_bargain_*.lua`
- `run_bargain_tests.lua` (aggregator)

Ownership lanes (parallel after M0 contract freeze):
- **Sim core:** `bargain/sim/grid.lua`, `turn_system.lua`, `combat.lua`
- **Perception/procgen:** `bargain/sim/fov.lua`, `bargain/sim/floors.lua`, `bargain/data/floors.lua`
- **AI/enemies:** `bargain/sim/enemy_ai.lua`, `bargain/data/enemies.lua`
- **Deals/content:** `bargain/sim/deals.lua`, `bargain/data/sins/*`
- **Integrator/UI:** `bargain/game.lua`, `bargain/ui/*`, `assets/scripts/core/main.lua` (single-owner)
- **Determinism/test harness:** `bargain/sim/digest.lua`, `test_bargain_determinism.lua`, scripted-input helpers

---

## 4) Frozen contracts (tests-first changes only)

### 4.1 `world` schema (freeze at M0)
Required fields:
- `world.grid`
- `world.entities` (id → entity)
- `world.player_id`
- `world.turn` (int)
- `world.phase` (enum string)
- `world.floor_num`
- `world.run_state` (`"playing"|"victory"|"death"`)
- `world.rng` (only RNG used by sim)
- `world.deals`:
  - `applied` (deal_id → true)
  - `history` (ordered list `{deal_id, kind, floor_num, turn}`)
  - `pending_offer` (nil or offer struct)

Recommended (adopt once, then freeze):
- `world.stairs` (`{x,y}` or nil)
- `world.messages` (append-only deterministic structs)
- `world.debug_flags` (test-only; must not affect release determinism)

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
- `flags` (deterministic map)
- `hooks` (hook_name → array of callbacks; callback order must be stable)

### 4.4 Action encoding + invalid action policy (freeze at M0)
- Move: `{type="move", dx=0|±1, dy=0|±1}`
- Attack: `{type="attack", dx=0|±1, dy=0|±1}`
- Wait: `{type="wait"}`

Invalid action policy (pick and lock):
- Return `{ok=false, err="..."}` and **consume the actor’s turn** (deterministic).

### 4.5 Phase model (freeze at M0)
Phases:
- `DEAL_CHOICE` → `PLAYER_INPUT` → `PLAYER_ACTION` → `ENEMY_ACTIONS` → `END_TURN` → `PLAYER_INPUT`

Rules:
- If `pending_offer.must_choose=true`, sim stays in `DEAL_CHOICE` until a deal is chosen.
- Enemy action order is deterministic: sort by `speed`, tie-break by `id`.

---

## 5) Module interfaces (designed for parallel work; tests define semantics)

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
- enemy order deterministic (speed then id)

### 5.3 `bargain/sim/combat.lua`
Exports:
- `resolve_attack(attacker_id, dx, dy, world) -> result`

Tests (freeze semantics):
- empty-target behavior
- damage formula deterministic (or RNG-based via `world.rng`, but single-source)
- death behavior (remove vs corpse flag; decide once)

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
- floor-start offer: exactly 1 offer; `must_choose=true`, `can_skip=false`
- level-up offer: exactly 2 offers; `must_choose=false`, `can_skip=true`
- no duplicates of already-applied deals (unless explicitly allowed; decide and lock)
- 21/21 downside enforcement (table-driven; ship gate)

### 5.6 `bargain/sim/enemy_ai.lua` + `bargain/data/enemies.lua`
Exports:
- `decide(enemy_id, world) -> action`

Tests:
- adjacent → attack
- otherwise move to reduce distance (Manhattan-first; BFS field when walls exist)
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

Debug hooks (test-safe surface):
- `debug.goto_floor(n)`, `debug.set_hp(x)`, `debug.grant_xp(x)`

---

## 6) Test plan (fast, deterministic, enforcement-driven)

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

### 6.2 Fixture policy
- Unit tests use tiny hand-authored maps (no procgen).
- Procgen tests are invariants-only.
- Tests must not depend on frame time (`dt`) or rendering.

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

## 7) Milestones + gates (each is shippable, each unlocks parallel work)

### M0 — Wiring + contract freeze
Deliver:
- `RUN_BARGAIN_TESTS=1` hook + `run_bargain_tests.lua`
- stub modules with correct exports
- contract tests for `world`, phases, action encoding

Gate:
- Bargain tests run from the game binary, fail cleanly, and exit reliably.

### M1 — Core sim loop (tiny fixed map)
Deliver:
- grid + movement/collision
- turn system + phase loop (deal gate included)
- combat resolution

Gate:
- `grid/turn/combat` tests pass.

### M2 — FOV + floors invariants
Deliver:
- FOV occlusion + memory
- floor generator satisfies invariants for floors 1–7 (layout can be simple)

Gate:
- `fov/floors` tests pass.

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

## 8) Determinism digest (exact spec; test-owned)

### Digest contents
Serialize (in stable order):
- `floor_num`, `turn`, `phase`, `run_state`
- player: `(x,y,hp,hp_max,xp,level,atk,def,speed,fov_radius)`
- entities: list of `(id,kind,x,y,hp,flags_subset)` sorted by `id`
- applied deal IDs sorted lexicographically

### Determinism rules (enforced by tests + review)
- Never rely on Lua table iteration order for serialization.
- Offers selection must be stable (explicit ordering).
- AI/pathing tie-breakers must be explicit and stable.
- Only `world.rng` is used for randomness (no `math.random`, no OS/time sources).

### Scripted input for determinism test
- Define a scripted action list (e.g., 50–200 actions) that:
  - chooses deals when prompted
  - moves/attacks/waits deterministically
- The determinism test runs: `seed + scripted actions → digest`
- Gate: same digest across machines for each fixed seed.

---

## 9) Parallelizable bead slicing (small, test-first units)

### 9.1 Bead units (recommended granularity)
- **One module bead:** implement one sim module + its test file(s).
- **One sin bead:** implement `bargain/data/sins/<sin>.lua` (3 deals) + add 3 downside assertions to `test_bargain_deals.lua`.
- **One floor/proc bead:** add/adjust floor invariants and generator behavior + invariants tests.
- **One UI bead:** deal modal + input mapping + smoke checklist.

### 9.2 Dependency graph (who can start when)
- After **M0**: all lanes can proceed in parallel (grid/combat/fov/floors/ai/deals/tests).
- Deals lane requires: `bargain/sim/deals.lua` scaffolding + contract tests (M0).
- UI lane requires: `bargain/game.lua` integration surface (can be stubbed early, finished in M5).

---

## 10) Coordination protocol (enforced workflow)
- Reserve files (exclusive) via Agent Mail before edits; keep reservations narrow.
- Beads workflow:
  1) Triage ready work (BV)
  2) Claim bead (`in_progress`)
  3) Implement + tests
  4) Close bead + notify dependents (Agent Mail)
- Contract changes require: tests-first update → module update → integrator update → broadcast delta.