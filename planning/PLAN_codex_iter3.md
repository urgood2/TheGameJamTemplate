# Game #4 “Bargain” — Engineering Plan (Rewrite v2→v3)

## 0) Product outcome + non-negotiables

### 0.1 Vertical-slice outcome
A complete, playable, testable run loop:
- 7 floors total; floor 7 boss (“Sin Lord”); victory/death screen; restart to a new seeded run.
- Target session length: 10–15 minutes.
- **Progression is only Faustian deals**: every deal grants a benefit **and** a permanent downside with **enforced gameplay behavior**.

### 0.2 Hard constraints (must hold)
- Turn-based, grid-based, FOV-limited exploration/combat.
- Player verbs: Move (4-way), Attack (directional), Wait.
- **7 sins × 3 deals = 21 deals total**.
- **All 21 downsides implemented** (no “text only”, no TODO markers).
- **Forced deal at each floor start** (cannot skip).
- Optional deal at level-up (can skip).
- Enemy AI: chase + attack only; **no A\***.
- No inventory/items/potions/shops/save-load/meta-progression/difficulty modes.

### 0.3 Definition of done (ship gate)
Automated:
- Seeded, deterministic-enough tests cover: turn loop, movement/collisions, combat, FOV, deal offer rules, and **downside enforcement (21/21)**.
- Headless smoke sim advances multiple floors without runtime errors; asserts invariants (bounds, phase loop, no invalid occupancy).
Manual:
- Can play from floor 1 → floor 7 → win/lose with correct forced/optional deal UI flows.

---

## 1) Architecture: “Pure Lua sim core” + thin engine/UI

### 1.1 Core boundary (test-first)
Simulation modules are **pure Lua**:
- No rendering/input calls, no engine globals.
- State is a plain `world` table passed into systems.
- UI/engine glue reads state + queues actions into the sim.

### 1.2 Determinism contract
All randomness is injected and recordable:
- `world.rng:int(lo, hi)` (seeded in tests).
- Floor generation is `generate(floor_num, seed, rng)` and must satisfy invariant tests.
- Any stochastic combat uses injected RNG; otherwise fully deterministic.

### 1.3 Eventing (optional)
Support `signal:emit(name, payload)` behind an interface, but simulation must run with `signal=nil`.
- Tests assert state changes first; optionally assert emitted events via a stub signal.

---

## 2) State model + action model (freeze early)

### 2.1 `world` shape (minimum)
- `world.grid` (tiles + occupancy API)
- `world.entities` (id → entity)
- `world.player_id`
- `world.turn` (int), `world.phase` (enum)
- `world.floor_num`, `world.run_state` (`playing|victory|death`)
- `world.rng`
- `world.deals`:
  - `applied` (set/map of deal_id → true)
  - `history` (ordered list of applied deal_ids + when applied)
  - `pending_offer` (nil or `{kind, offers[], must_choose, can_skip}`)

### 2.2 Entity schema (component-ish, still tables)
Required fields:
- `id`, `kind` (`player|enemy|boss`)
- `x`, `y`
- `hp`, `hp_max`, `atk`, `def`, `speed`, `fov_radius`
- `xp`, `level`
- `flags` (map), `hooks` (tables of callbacks keyed by hook name)

### 2.3 Action encoding (single place; used by AI + player)
Use a small tagged table:
- Move: `{type="move", dx=0|±1, dy=0|±1}`
- Attack: `{type="attack", dx=0|±1, dy=0|±1}`
- Wait: `{type="wait"}`
Rules to test:
- Invalid action payloads are rejected deterministically (error or no-op; pick one and lock it).

---

## 3) Module contracts + contract tests (enable parallel work)

> Rule: **Change the contract test before changing the contract.**  
> Each module gets (1) a public API, (2) a contract test file, (3) unit tests for tricky logic.

### 3.1 `bargain/grid_system.lua`
API:
- `Grid.new(w, h)`
- `get_tile/set_tile`
- `place_entity(entity)`, `move_entity(id, nx, ny)`
- `can_move_to(x,y)`, `is_opaque(x,y)`
- `get_occupant(x,y)` (or equivalent)
- `neighbors4(x,y)`
Contract tests:
- Walls block; bounds block; entities block.
- Occupancy updates are bijective (no dupes, no ghost occupants).

### 3.2 `bargain/turn_system.lua`
API (choose one stepping model and lock it):
- `TurnSystem.new({world, signal?})`
- `queue_player_action(action)`
- `step()` advances exactly one phase transition
- `get_phase()`, `get_turn()`
Rules to freeze + test:
- Phase loop order: `PLAYER_INPUT → PLAYER_ACTION → ENEMY_ACTIONS → END_TURN → PLAYER_INPUT`.
- Player always acts before enemies.
- Enemy ordering deterministic: sort by `speed` then stable tie-break (entity id).

### 3.3 `bargain/combat.lua`
API:
- `Combat.resolve_attack(attacker_id, dx, dy, world)` → result
Rules to freeze + test:
- Attack consumes turn even if empty target cell.
- Damage formula (deterministic or RNG-based with fixed RNG).
- Death: `hp <= 0` removes entity / sets flag; pick one and test it.

### 3.4 `bargain/fov_system.lua`
API:
- `FOV.new(grid)`
- `update(cx, cy, radius)`
- `is_visible(x,y)`, `get_state(x,y)` (`UNSEEN|SEEN|VISIBLE`)
Tests:
- Occlusion behind walls on small golden maps.
- Memory transition `VISIBLE → SEEN` after moving away.

### 3.5 `bargain/deal_system.lua` + `bargain/sins_data.lua`
Data contract (`sins_data.lua`):
- 21 deals; each deal has:
  - `id` (stable unique string)
  - `sin` (one of 7 stable sin keys)
  - `name`, `benefit_text`, `downside_text`
  - `apply(world, player_id)` that **registers enforcement** (stat delta, flag, hook, rule override)
System contract:
- `DealSystem.get_offers(kind, world)` where `kind ∈ { "floor_start", "level_up" }`
- `DealSystem.apply_deal(deal_id, world)` (records + applies)
Offer rules to test:
- Floor start: exactly 1 offer; **must_choose=true; can_skip=false**.
- Level up: 2 offers; **must_choose=false; can_skip=true**.
Enforcement tests:
- Completeness: 21/21 deals exist and `apply` mutates state + sets an enforcement marker.
- Behavioral: at least one test per downside category (see §4.4).

### 3.6 `bargain/enemy_ai.lua` + `bargain/enemies_data.lua`
AI API:
- `EnemyAI.decide(enemy_id, world)` → action
Rules to test:
- Adjacent to player → attack.
- Else move to reduce Manhattan distance if possible; fallback axis; else wait.
- Deterministic on fixed maps.

### 3.7 `bargain/floor_manager.lua` + `bargain/floors_data.lua`
API:
- `FloorManager.generate(floor_num, seed, rng)` → `{grid, entities, stairs_pos?, metadata}`
Rules to test (invariants, not exact layouts):
- Floor sizes per floor number (explicit table).
- Enemy counts within bounds.
- Stairs placement valid on floors 1–6; **no stairs down on floor 7**.
- Floor 7 contains boss entity and no other progression escape hatch.

### 3.8 `bargain/game.lua` (integrator-owned)
API:
- `Game.new({seed, signal?, headless?})`
- `queue_action(action)`, `step()`
- `is_waiting_for_deal_choice()`, `choose_deal(deal_id)` / `skip_deal()` (skip only when allowed)
Debug hooks (explicit, stable):
- `debug.goto_floor(n)`, `debug.set_hp(x)`, `debug.grant_xp(x)`, `debug.kill_boss()`

---

## 4) Test plan (fast + deterministic + enforcement-focused)

### 4.1 Test harness (mandatory first milestone)
`assets/scripts/bargain/tests/run_all_tests.lua`:
- Discovers `test_*.lua` (or manifest).
- Runs each file under `pcall`.
- Prints PASS/FAIL per file + summary.
- Fails process via `error()` if any failures.

### 4.2 Unit test suite (baseline)
Required test files (names stable):
- `test_grid_system.lua`
- `test_turn_system.lua`
- `test_combat.lua`
- `test_fov_system.lua`
- `test_enemy_ai.lua`
- `test_deal_system.lua`
- `test_data_loading.lua`
- `test_floors.lua`

### 4.3 Headless integration smoke
`test_game_smoke.lua`:
- Starts a seeded run in headless mode.
- Auto-chooses forced floor-start deals deterministically (e.g., first offer).
- Steps N turns across multiple floors.
Asserts:
- No runtime errors.
- Player remains in bounds.
- Phase loops back to `PLAYER_INPUT`.
- Occupancy invariants hold (no two entities on one tile, etc.).

### 4.4 Deal downside enforcement coverage policy
Define downside categories (example; finalize early and document in `test_deal_system.lua`):
- **Stat clamp** (max HP reduction, atk/def penalties)
- **Per-turn tax** (hp drain, armor decay, etc.)
- **Action restriction** (cannot wait, cannot attack unless condition, etc.)
- **Risk-on-action** (self-damage on move/attack, etc.)
- **Progress penalty** (xp reduction, level-up cost increase)
For each category:
- 1–2 focused behavior tests (small map, deterministic steps).
Additionally:
- Completeness test: 21/21 deals have enforcement marker.

---

## 5) Parallelization strategy (minimize merge conflicts)

### 5.1 File ownership boundaries (primary conflict-avoidance)
- Core sim: `bargain/grid_system.lua`, `bargain/turn_system.lua`, `bargain/combat.lua`
- Perception/procgen: `bargain/fov_system.lua`, `bargain/floor_manager.lua`, `bargain/floors_data.lua`
- Content/progression: `bargain/deal_system.lua`, `bargain/sins_data.lua`, `bargain/enemies_data.lua`
- AI: `bargain/enemy_ai.lua`
- Integrator: `bargain/game.lua`
- Tests: `assets/scripts/bargain/tests/*` (split by module; avoid one mega test file)

### 5.2 Deal implementation parallelism (highest leverage)
Split `sins_data.lua` content into per-sin files (if allowed by project conventions) to reduce conflicts, e.g.:
- `bargain/sins/envy.lua`, `.../wrath.lua`, etc.
Then `sins_data.lua` only aggregates.
Parallel unit of work: **one sin = 3 deals + tests**.

### 5.3 Contract-change protocol
- Any API change requires:
  1) Update contract test(s)
  2) Update module(s)
  3) Update integrator glue if needed
- No cross-stream edits without explicit coordination.

---

## 6) Milestones (each shippable, test-gated)

### M0 — Harness + contracts (unblocks parallel work)
Deliver:
- Test runner.
- Module stubs with correct exports and `error("unimplemented")`.
- Contract tests wired (expected to fail until implementations land).
Verify:
- Harness runs and reports failures cleanly; no load-time crashes.

### M1 — Core loop on a fixed tiny map (no UI)
Deliver:
- Grid movement/collision.
- Turn system phase loop + action queue.
- Combat resolution.
Verify:
- `test_grid_system.lua`, `test_turn_system.lua`, `test_combat.lua` all pass.

### M2 — FOV + floor generation invariants
Deliver:
- FOV with memory + occlusion.
- Floor generation meeting invariants for floors 1–7.
Verify:
- `test_fov_system.lua`, `test_floors.lua` pass.

### M3 — Deals (21/21) + offer rules
Deliver:
- Complete deal data + enforcement wiring.
- Offer flow state machine (forced floor-start; optional level-up).
Verify:
- `test_data_loading.lua` proves 21/21.
- `test_deal_system.lua` proves enforcement marker 21/21 + category behavior tests.

### M4 — Enemies + AI + progression to floor 7
Deliver:
- Enemy templates + AI chase/attack.
- Floor 7 boss config + win condition wiring.
Verify:
- `test_enemy_ai.lua`, `test_floors.lua` pass.
- New tests for boss defeat → `run_state="victory"`.

### M5 — UI flows (manual gate)
Deliver:
- Deal modal (forced vs optional skip).
- HUD (HP/stats/deals/floor/turn).
- End screens (victory/death) + replay.
Verify (manual):
- Forced deal cannot be skipped.
- Level-up deal can be skipped.
- Victory/death screens reachable and restart works.

### M6 — Integration hardening
Deliver:
- `bargain/game.lua` orchestrator + debug hooks.
- `test_game_smoke.lua` across multiple floors with deterministic choices.
Verify:
- Smoke test passes reliably (multiple seeds if feasible).

### M7 — Balance pass (time-to-complete target)
Deliver:
- Single `balance_config.lua` (central tuning).
- Record 3 seeded run timings + adjust numbers.
Verify:
- Average run ~10–15 minutes; at least one seed winnable without debug.

---

## 7) Beads breakdown (ready-to-claim units with acceptance criteria)

### 7.1 Bead acceptance criteria (standard)
Each bead must:
- Add/update automated tests for introduced behavior.
- Run test harness with no new failures.
- Respect file ownership boundaries unless doing a contract change.

### 7.2 Suggested beads (dependency-ordered)
- M0:
  - Harness bead: test runner + test discovery.
  - Contract beads: one per module contract test.
- M1:
  - Grid bead, TurnSystem bead, Combat bead (can be parallel after contracts).
- M2:
  - FOV bead, FloorManager bead.
- M3:
  - DealSystem core bead (offer rules + apply recording).
  - 7× sin beads (each: 3 deals + enforcement marker + 1 behavior test).
- M4:
  - Enemy data bead, AI bead, Boss/win-condition bead.
- M5:
  - Deal modal bead, HUD bead, End screens bead.
- M6:
  - Game orchestrator bead, Debug commands bead, Smoke test bead.
- M7:
  - Balance config bead, Timing + tuning bead.

---

## 8) Risks + mitigations (testable mitigations)

- **“Downside drift” into UI text only** → enforce 21/21 enforcement-marker test + category behavior tests.
- **FOV correctness regressions** → keep 2–3 golden maps in tests; no procgen in FOV unit tests.
- **Procgen flakiness** → seed everywhere; test invariants not exact layouts; clamp random ranges.
- **Integration churn** → keep `bargain/game.lua` integrator-owned; require contract-test updates for API changes.
- **Non-deterministic ordering bugs** → stable sort keys (speed then id), deterministic iteration (no `pairs()` where order matters).

---