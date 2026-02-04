# Game #4 “Bargain” — Engineering Plan (Iter4 Rewrite: v4.0)

## 0) Goal + Definition of Done (DoD)

### Goal (vertical slice)
Ship a complete, replayable run loop:
- **7 floors total**; **floor 7 boss** (“Sin Lord”).
- **Win** and **Death** screens.
- **Restart → new seeded run**.
- **10–15 minute** target session length.

### DoD (hard, testable)
A build is “done” when all are true:
- A seeded run can be completed end-to-end (victory or death) **without crashes**.
- **Forced deal** is presented at **every floor start**, **before gameplay continues**, and **cannot be skipped**.
- **Optional deal** is offered on **level-up** and **can be skipped**.
- **Progression is only Faustian deals**: each deal applies **(a) immediate benefit** and **(b) permanent downside** that **enforces gameplay behavior** (not text-only).
- **21/21 deals exist and all 21 downsides are enforced by automated tests**.
- Determinism: for a fixed seed + scripted inputs, the run produces a stable “state digest” (see §7.5).

---

## 1) Non-Negotiables / Non-Goals

### Non-negotiables (constraints)
Gameplay:
- Turn-based, grid-based, **FOV-limited** exploration/combat.
- Player verbs: `Move` (4-way), `Attack` (directional), `Wait`.
- Enemy AI: chase + attack only; **no A\*** (BFS distance field is allowed).

Content:
- **7 sins × 3 deals = 21 deals**.
- **All 21 downsides implemented** (no TODO markers; no placeholder behavior).
- **Forced deal at floor start** (cannot skip).
- **Optional deal at level-up** (can skip).

### Explicitly out of scope (do not creep)
- Inventory/items/potions/shops.
- Save/load, meta-progression, difficulty modes.
- Large content systems beyond “deals + enemies + 7 floors”.

---

## 2) Repo Integration (Concrete Run/Test Hooks)

### Build/run (existing)
- Build debug fast:
  - `just build-debug-fast`
  - `./build-debug/raylib-cpp-cmake-template`

### Bargain “start mode” (dev convenience)
Support both:
- `AUTO_START_BARGAIN=1` (auto-enter Bargain loop)
- Manual entry: `require("bargain.game").start()` (via any dev console/eval facility if present)

Precedence:
- `AUTO_START_BARGAIN=1` takes precedence over other auto-start envs (e.g. `AUTO_START_MAIN_GAME`).

### Bargain Lua tests (in-engine, reusing existing test framework)
Use the existing `assets/scripts/tests/test_runner.lua` framework.

Add a `RUN_BARGAIN_TESTS=1` startup hook in `assets/scripts/core/main.lua`, following the existing `RUN_GOAP_TESTS` / `RUN_UI_VALIDATOR_TESTS` patterns:
- Must run **early** (before long-running demos).
- Must `os.exit(0|1)` immediately after running.
- Loads `require("tests.run_bargain_tests")` and calls `run()`.

Invocation:
- `RUN_BARGAIN_TESTS=1 ./build-debug/raylib-cpp-cmake-template`

---

## 3) Code Layout (Parallel-Friendly + Low-Conflict)

### Proposed module tree (new)
All new Bargain code lives under `assets/scripts/bargain/`:
- `assets/scripts/bargain/sim/` — pure simulation (no rendering/input/engine globals)
- `assets/scripts/bargain/ui/` — rendering + input mapping + deal modal (engine-facing)
- `assets/scripts/bargain/data/` — deals/enemies/floors/balance tables
- `assets/scripts/bargain/tests/` — helper utilities + fixtures (optional; keep actual tests in `assets/scripts/tests/` for consistency)

### Tests location (consistent with repo)
- `assets/scripts/tests/test_bargain_*.lua` — unit + integration tests
- `assets/scripts/tests/run_bargain_tests.lua` — aggregator that resets `TestRunner`, requires all Bargain test modules, then calls `TestRunner.run_all()`.

---

## 4) Architecture: Pure Sim Core + Thin Engine Glue

### 4.1 Core rule: pure Lua sim
Simulation modules:
- No rendering/input calls.
- No engine globals.
- State is a plain `world` table passed into systems.

Engine/UI glue:
- Reads `world` and queues actions into sim.
- Renders based on `world` snapshot.

### 4.2 Determinism contract (explicit)
- All randomness inside sim flows through `world.rng` (single injected RNG).
- Procgen must be deterministic for a given `(seed, floor_num)`; tests validate invariants and at least one end-to-end digest (see §7.5).
- Stable iteration order: avoid `pairs()` where order matters; sort by `(speed, id)` or `(y, x, id)` as appropriate.

---

## 5) Frozen “World” + Actions (Lock Early to Unblock Parallel Work)

### 5.1 `world` minimum schema (frozen at M0)
- `world.grid` (tiles + occupancy)
- `world.entities` (id → entity)
- `world.player_id`
- `world.turn` (int)
- `world.phase` (enum string)
- `world.floor_num`
- `world.run_state` (`"playing"|"victory"|"death"`)
- `world.rng`
- `world.deals`:
  - `applied` (set `deal_id → true`)
  - `history` (ordered list of `{deal_id, kind, floor_num, turn}`)
  - `pending_offer` (nil or `{kind, offers, must_choose, can_skip}`)

Recommended additions (still frozen at M0 if adopted):
- `world.stairs` (nil or `{x,y}`) on floors 1–6
- `world.messages` (append-only log for UI/debug)
- `world.debug_flags` (test/dev hooks)

### 5.2 Entity schema (frozen at M0)
Required fields:
- `id`, `kind` (`"player"|"enemy"|"boss"`)
- `x`, `y`
- `hp`, `hp_max`, `atk`, `def`, `speed`, `fov_radius`
- `xp`, `level`
- `flags` (map)
- `hooks` (tables of callbacks keyed by hook name)

### 5.3 Action encoding (single format for player + AI)
- Move: `{type="move", dx=0|±1, dy=0|±1}`
- Attack: `{type="attack", dx=0|±1, dy=0|±1}`
- Wait: `{type="wait"}`

Invalid actions policy (choose at M0, lock with tests):
- **Policy A (recommended):** deterministic no-op returning `{ok=false, err="..."}` and still consuming the actor’s turn.
- Contract test must lock this behavior.

### 5.4 Phase model (frozen at M0)
Define explicit phases, including the deal gate:
- `DEAL_CHOICE` → `PLAYER_INPUT` → `PLAYER_ACTION` → `ENEMY_ACTIONS` → `END_TURN` → `PLAYER_INPUT`
Rules:
- If `world.deals.pending_offer` exists and `must_choose=true`, the sim must remain in `DEAL_CHOICE` until a deal is chosen.

---

## 6) Module Contracts (Parallelizable by Design)

Protocol (required):
1) Update **contract tests** first.
2) Update module implementation.
3) Update integrator/UI glue.
4) Notify dependents (Agent Mail) with the contract delta.

### 6.1 `assets/scripts/bargain/sim/grid.lua`
Exports:
- `Grid.new(w,h)`
- `get_tile/set_tile`
- `place_entity(entity)`, `move_entity(id, nx, ny)`
- `can_move_to(x,y)`, `is_opaque(x,y)`
- `get_occupant(x,y)`
- `neighbors4(x,y)`

Contract tests:
- Bounds block; walls block; entities block.
- Occupancy invariants: no dupes, no ghosts; bijection between entity positions and occupancy map.

### 6.2 `assets/scripts/bargain/sim/turn_system.lua`
Exports:
- `TurnSystem.new({world, signal?})`
- `queue_player_action(action)`
- `step()` advances exactly one phase transition
- `get_phase()`, `get_turn()`

Contract tests:
- Phase loop order is frozen and asserted (including `DEAL_CHOICE` gate behavior).
- Player acts before enemies.
- Enemy ordering deterministic: sort by `speed` then stable tie-break (entity id).

### 6.3 `assets/scripts/bargain/sim/combat.lua`
Exports:
- `resolve_attack(attacker_id, dx, dy, world) -> result`

Contract tests:
- Attack consumes turn even if target cell empty (or explicitly chosen alternative; lock it).
- Damage formula frozen (deterministic or RNG-based; lock choice).
- Death behavior frozen (remove entity vs flag + leave corpse; lock choice).

### 6.4 `assets/scripts/bargain/sim/fov.lua`
Exports:
- `FOV.new(grid)`
- `update(cx, cy, radius)`
- `is_visible(x,y)`, `get_state(x,y)` in `UNSEEN|SEEN|VISIBLE`

Contract tests:
- Occlusion behind walls using small golden maps.
- Memory transition `VISIBLE → SEEN` when moving away.

### 6.5 `assets/scripts/bargain/sim/deals.lua` + `assets/scripts/bargain/data/sins.lua`
Data contract (`data/sins.lua`):
- Exactly 21 deals, stable IDs.
- Each deal includes:
  - `id`, `sin`, `name`, `benefit_text`, `downside_text`
  - `apply(world, player_id)` that registers enforcement (stats/flags/hooks/rules)

System contract (`sim/deals.lua`):
- `get_offers(kind, world)` where `kind ∈ {"floor_start","level_up"}`
- `apply_deal(deal_id, world)` (records + applies)

Offer-rule tests:
- Floor start: exactly 1 offer; `must_choose=true`, `can_skip=false`
- Level up: exactly 2 offers; `must_choose=false`, `can_skip=true`
- No duplicates of already-applied deals (unless explicitly allowed; decide + lock)

Ship gate:
- 21/21 deals exist.
- 21/21 downsides have **behavioral assertions** (see §7.4).

### 6.6 `assets/scripts/bargain/sim/enemy_ai.lua` + `assets/scripts/bargain/data/enemies.lua`
Exports:
- `decide(enemy_id, world) -> action`

Contract tests:
- Adjacent to player → attack.
- Otherwise move to reduce distance to player:
  - Start with Manhattan chase (MVP), then upgrade to wall-aware BFS distance field (still “no A*”).
- Deterministic tie-breakers (axis preference, then id).

### 6.7 `assets/scripts/bargain/sim/floors.lua` + `assets/scripts/bargain/data/floors.lua`
Exports:
- `generate(floor_num, seed, rng) -> {grid, entities, stairs?, metadata}`

Invariant tests:
- Floor sizes match explicit table per `floor_num`.
- Enemy counts in allowed ranges.
- Valid stairs placement on floors 1–6; **no stairs down on floor 7**.
- Floor 7 contains boss.

### 6.8 `assets/scripts/bargain/game.lua` (integrator-owned)
Exports:
- `start()` (engine entry)
- `update(dt, opts)` (engine tick)
- `queue_action(action)`, `step_sim()` (if separated)
- Deal interaction:
  - `is_waiting_for_deal_choice()`
  - `choose_deal(deal_id)`
  - `skip_deal()` (only when allowed)

Debug hooks (test-safe, stable):
- `debug.goto_floor(n)`, `debug.set_hp(x)`, `debug.grant_xp(x)`, `debug.kill_boss()`

---

## 7) Test Plan (Deterministic + Enforcement-First)

### 7.1 Use existing `tests.test_runner`
All Bargain tests use:
- `local TestRunner = require("tests.test_runner")`
- `TestRunner.describe(...)`, `TestRunner.it(...)`, `TestRunner.expect(...)`

### 7.2 Required test modules (minimum)
- `assets/scripts/tests/test_bargain_grid.lua`
- `assets/scripts/tests/test_bargain_turn_system.lua`
- `assets/scripts/tests/test_bargain_combat.lua`
- `assets/scripts/tests/test_bargain_fov.lua`
- `assets/scripts/tests/test_bargain_enemy_ai.lua`
- `assets/scripts/tests/test_bargain_deals.lua`
- `assets/scripts/tests/test_bargain_data_loading.lua`
- `assets/scripts/tests/test_bargain_floors.lua`
- `assets/scripts/tests/test_bargain_game_smoke.lua`
- `assets/scripts/tests/test_bargain_determinism.lua` (digest test)

### 7.3 Fixtures (golden maps)
Add tiny string/array fixtures inside tests (or a `tests` fixture helper) for:
- FOV occlusion maps
- AI chase maps
- Deal enforcement micro-scenarios (1–3 turns)

Keep fixtures small and explicit; do not rely on procgen in unit tests.

### 7.4 Deal downside enforcement policy (ship gate)
Each downside must be proven by a behavioral assertion, not just “a marker exists”.

Define enforcement categories and require at least one assertion per deal:
- Stat clamp (e.g., `hp_max` reduced)
- Per-turn tax (drain/decay)
- Action restriction (cannot `wait`, cannot `attack` unless condition)
- Risk-on-action (self-damage on move/attack)
- Progress penalty (XP reduction / level threshold increase)
- Spatial constraint (must move toward/away; restricted tiles)
- Enemy modifier (spawn rule, buff enemies) **only if it enforces gameplay** and is testable

Coverage rule:
- 21/21 deals: at least one targeted assertion that fails if the downside is removed.
- Additionally: 1–2 category regression tests to prevent “same bug reappears” across deals.

### 7.5 Determinism “state digest” test
Add an end-to-end test that:
- Starts a run with seed `S`.
- Uses a deterministic scripted input sequence (including deterministic forced deal choice rule).
- Steps N turns / floors.
- Computes a stable digest (e.g., serialize key fields: `floor_num`, `turn`, `player hp/xp/level`, entity positions/hp for a sorted list, applied deal ids).
- Asserts digest equals an expected string for that seed.

This catches accidental nondeterminism from iteration order, RNG leaks, or contract drift.

---

## 8) Milestones (Test-Gated, Shippable Increments)

### M0 — Contracts + test wiring (unblocks parallel work)
Deliver:
- `assets/scripts/tests/run_bargain_tests.lua` aggregator.
- Stub modules with correct exports (may `error("unimplemented")`).
- Contract tests compiling and running via `RUN_BARGAIN_TESTS=1`.

Gate:
- Bargain test runner executes and reports failures cleanly; no boot-time crashes.

### M1 — Core loop on tiny fixed map (headless-ish)
Deliver:
- Grid movement/collision.
- Turn system phase loop (including `DEAL_CHOICE` gate).
- Combat resolution.

Gate:
- `test_bargain_grid`, `test_bargain_turn_system`, `test_bargain_combat` pass.

### M2 — FOV + floor invariants
Deliver:
- FOV occlusion + memory.
- Floor generator meeting invariants for floors 1–7 (layout may be simple initially).

Gate:
- `test_bargain_fov`, `test_bargain_floors` pass.

### M3 — Deals (21/21) + offer rules + enforcement tests
Deliver:
- Offer rules (forced floor-start; optional level-up).
- `data/sins.lua` complete with 21 real effects + real enforced downsides.

Gate:
- `test_bargain_data_loading` proves 21/21 stable IDs.
- `test_bargain_deals` proves offer rules + 21/21 downside enforcement.

### M4 — Enemies + AI + progression to floor 7 win/lose
Deliver:
- Enemy templates + deterministic chase/attack AI.
- Boss on floor 7 + victory wiring.

Gate:
- `test_bargain_enemy_ai` passes.
- Victory test: boss defeat → `run_state="victory"`.

### M5 — UI flows (manual gate; minimal polish)
Deliver:
- Deal modal (forced vs optional skip).
- HUD (HP/stats/deals/floor/turn).
- Victory/death screens + restart.

Manual checklist:
- Forced deal cannot be skipped.
- Level-up deal can be skipped.
- Victory/death reachable; restart produces new seeded run.

### M6 — Integration hardening + smoke + determinism
Deliver:
- `bargain/game.lua` orchestrator stable.
- Multi-floor smoke test.
- Digest determinism test.

Gate:
- `test_bargain_game_smoke` passes on 3 fixed seeds.
- `test_bargain_determinism` passes.

### M7 — Balance pass (time-to-complete target)
Deliver:
- Central `data/balance.lua` tuning surface.
- 3 seeded run timing notes + adjustments.

Gate:
- Average run time ~10–15 minutes; at least one seed winnable without debug hooks.

---

## 9) Parallelization Plan (Workstreams + Bead Slicing)

### 9.1 File ownership lanes (minimize merge conflicts)
- Sim core: `assets/scripts/bargain/sim/grid.lua`, `.../turn_system.lua`, `.../combat.lua`
- Perception/procgen: `assets/scripts/bargain/sim/fov.lua`, `.../floors.lua`, `assets/scripts/bargain/data/floors.lua`
- Content/progression: `assets/scripts/bargain/sim/deals.lua`, `assets/scripts/bargain/data/sins.lua`
- AI/enemies: `assets/scripts/bargain/sim/enemy_ai.lua`, `assets/scripts/bargain/data/enemies.lua`
- Integrator/UI: `assets/scripts/bargain/game.lua`, `assets/scripts/bargain/ui/*`, `assets/scripts/core/main.lua` (single owner)
- Tests: `assets/scripts/tests/test_bargain_*.lua` split per module

### 9.2 Highest-leverage parallel unit: “one sin”
Split sins into separate files to enable parallel delivery:
- `assets/scripts/bargain/data/sins/envy.lua`, `.../wrath.lua`, etc.
- `data/sins.lua` aggregates and enforces “21 exactly”.

Bead definition (recommended):
- One sin bead = **3 deals + tests proving each downside** + passing data-loading invariants.

### 9.3 Contract-change protocol (anti-churn)
Any API change requires:
1) Update contract tests.
2) Update module.
3) Update integrator + aggregator + any dependent tests.
4) Notify dependents via Agent Mail with summary and new contract expectations.

---

## 10) Risks + Mitigations (Testable)

- “Downside drift” into text-only  
  Mitigation: 21/21 behavioral assertions (ship gate).
- FOV regressions  
  Mitigation: golden-map unit tests; no procgen reliance.
- Procgen flakiness / nondeterminism  
  Mitigation: invariant-only tests for procgen + end-to-end digest test.
- Ordering nondeterminism  
  Mitigation: stable sorting everywhere; determinism digest test.
- Integration churn / engine update loop hazards  
  Mitigation: single integrator owner; keep Bargain update as a gate that preserves engine end-of-frame/flush path.

---