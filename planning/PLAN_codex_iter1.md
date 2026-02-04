# Game #4: “Bargain” — Engineering Plan (v1)

## 0) Goal, Constraints, Non‑Goals

**Goal (vertical slice):** A playable, end-to-end turn-based roguelike run (7 floors → Sin Lord) where the *only* progression is permanent Faustian deals (benefit + permanent downside), with a 10–15 minute session target.

**Hard constraints (from PLAN_v0):**
- Turn-based, grid-based, FOV-limited exploration/combat.
- 7 Sins × 3 deals = **21 deals**, each with **explicitly implemented** downside behavior (not “TODO: penalty”).
- **Floor-start deal is forced** (no skip); level-up deal is optional (can skip).
- Simple AI: chase + attack only (no A*).
- No items/inventory/potions/shops/meta-progression/save-load/difficulty modes.

**Actions (v1):**
- **Move**, **Attack (directional)**, **Wait**. (“Use Item” is out of scope and should not appear in task acceptance criteria.)

---

## 1) Architecture Decisions (optimize for testability + parallel work)

### 1.1 Standalone Lua systems (no `combat_system.lua` Stats/Effects)
Implement Bargain as a self-contained Lua module set under `assets/scripts/bargain/`, with plain tables for entities and direct stat mutation for deals. This keeps unit tests simple and avoids coupling to engine globals.

### 1.2 Determinism hooks (required for reliable tests)
Any randomness must be injectable/seeded:
- `Combat.calculate_damage(attacker, defender, rng)` where `rng:int(1,100)` (default backed by `math.random`).
- `DealSystem.get_random_deals(count, rng, constraints)` seeded in tests.
- `FloorManager.generate(floor_num, seed)` so tests can assert sizes/counts without flaky layouts.

### 1.3 Eventing
Use `require("external.hump.signal")` for cross-module events (state changes, phase transitions, deal applied, hp changed). Keep events optional so unit tests can run without engine UI.

---

## 2) Module Boundary + Public API Contracts (freeze early to enable parallelism)

Create stubs + contract tests first, then implement behind them.

### 2.1 `bargain/turn_system.lua`
- `TurnSystem.new({signal?})`
- `add_entity(entity)` / `remove_entity(id)`
- `set_player_action(action)` (queued during `PLAYER_INPUT`)
- `step()` advances phases: `PLAYER_INPUT → PLAYER_ACTION → ENEMY_ACTIONS → END_TURN → PLAYER_INPUT`
- `get_phase()`, `get_turn()`, `get_enemy_order()` (speed-desc)

**Contract rules:**
- Player always acts first each turn; speed only orders enemies.

### 2.2 `bargain/grid_system.lua`
- `Grid.new(w,h)`
- `set_tile(x,y,tile)` / `get_tile(x,y)`
- `can_move_to(x,y)` / `is_opaque(x,y)`
- `place_entity(entity,x,y)` / `move_entity(entity,dx,dy)`
- `manhattan(a,b)` helpers

Tile encoding compatible with DungeonBuilder (0 floor, 1 wall); add `STAIRS_DOWN`.

### 2.3 `bargain/fov_system.lua`
- `FOV.new(grid)`
- `update(cx,cy,radius)`
- `is_visible(x,y)` and `get_state(x,y)` in `{UNSEEN, SEEN, VISIBLE}`

### 2.4 `bargain/deal_system.lua` + `bargain/sins_data.lua`
- `DealSystem.apply_deal(player, deal_id)`
- `DealSystem.get_offers(kind, rng, state)` where `kind in {floor_start, level_up}`
- `sins_data.lua` is data-only: 7 sins, each 3 deals, each deal has `{id, name, benefit, downside, text}`

Downsides that affect behavior register callbacks/flags on player (e.g., `autopilot=true`, `on_attack_callbacks`).

### 2.5 `bargain/player.lua`
- `Player.new(grid, x, y)`
- `Player.queue_action(input_state)` (produces `{type="move"/"attack"/"wait", ...}`)
- `Player.apply_damage(amount)` / `Player.gain_xp(amount)` / `Player.check_level_up()`

### 2.6 `bargain/enemy_ai.lua` + `bargain/enemies_data.lua` + `bargain/enemies.lua`
- `EnemyAI.decide(enemy, player, grid)` → `{type="move"/"attack", ...}`
- `Enemies.create(type_id)` returns entity with stats/flags.

### 2.7 `bargain/floor_manager.lua` + `bargain/floors_data.lua`
- `FloorManager.generate(floor_num, seed)` → `{grid, entities, stairs_pos?, enemy_budget, ...}`
- Uses `DungeonBuilder` + `stage_providers.sequence()` to enforce 7-floor run.

### 2.8 UI modules (manual-verification oriented)
- `bargain/ui/deal_modal.lua` (forced vs skippable)
- `bargain/ui/game_hud.lua`
- `bargain/ui/end_screens.lua`

### 2.9 `bargain/game.lua` (single integrator-owned file)
- `BargainGame.start()`, `BargainGame.update(dt)`, `BargainGame.draw()`
- State machine: `TITLE → PLAYING → DEAL_SELECTION → VICTORY/DEATH`
- Expose `BargainGame.debug.*` commands (goto_floor, clear_floor, kill_boss, set_hp, grant_xp)

---

## 3) Test Strategy (automated first, manual where unavoidable)

### 3.1 Test harness (mandatory foundation)
- `assets/scripts/bargain/tests/run_all_tests.lua` runs each `test_*.lua` via `pcall(dofile, ...)` and prints pass/fail summary.
- Tests are pure Lua scripts using `assert()`. They must not require the UI.

### 3.2 Unit tests (fast, deterministic)
- Turn ordering, phase transitions, event emission counts.
- Grid collision and movement.
- FOV occlusion and memory (VISIBLE→SEEN).
- Deal application correctness (stats + flags/callback registration).
- Enemy AI decisions on simple maps.
- Boss phase transitions at exact HP thresholds.

### 3.3 Integration smoke tests (minimal)
- `test_game_smoke.lua`: instantiate `BargainGame` in “headless” mode (no rendering calls) and step a few turns with stubbed input/actions to ensure no nil access across modules.

### 3.4 Manual acceptance checklists (UI/gameplay)
- Deal modal forced vs optional behavior.
- HUD updates on HP change and deal acquisition.
- Full run completion via normal play + debug shortcuts.

---

## 4) Work Breakdown (beads) + Parallelization Plan

### Workflow (per AGENTS.md)
For each work item:
1) `BV` triage → pick a ready bead
2) claim bead (`in_progress`)
3) implement + tests
4) close bead + notify via Agent Mail (and release file reservations)

### Parallel workstreams (minimize file overlap)
- **Stream A: Core simulation** (`turn_system`, `grid_system`, `combat`, `player`)
- **Stream B: Progression/content** (`sins_data`, `deal_system`, `enemies_data/enemies`, `floor_manager`)
- **Stream C: Perception/rendering glue** (`fov_system`, draw helpers, tile mapping)
- **Stream D: UI + UX** (deal modal, HUD, end screens)
- **Stream E (Integrator):** `game.lua` + state machine + debug commands + smoke test

---

## 5) Milestones (each is shippable + testable)

### M0 — Scaffolding + Contracts (unblocks everyone)
**Deliverables**
- Directory structure under `assets/scripts/bargain/` and `assets/scripts/bargain/tests/`
- Stub modules with documented public APIs (return tables, no engine dependencies)
- `run_all_tests.lua` + contract tests (initially failing is acceptable only until stubs exist)

**Exit criteria**
- `dofile("assets/scripts/bargain/tests/run_all_tests.lua")` runs and reports test file loading (even if some tests fail due to stubbed `error("TODO")`).

---

### M1 — Core Turn + Grid (first playable “rules loop” without graphics)
**Deliverables**
- Turn phases + deterministic enemy ordering
- Grid collision + entity placement/movement
- Player action production for Move/Attack/Wait (no UI; tests drive actions)

**Exit criteria**
- Unit tests pass: `test_turn_system.lua`, `test_grid_system.lua`, `test_player.lua` (movement + wait), `test_combat.lua` (damage formula deterministic with injected rng).

---

### M2 — FOV + Dungeon Adapter (first explorable floor)
**Deliverables**
- Shadowcasting FOV with UNSEEN/SEEN/VISIBLE
- DungeonBuilder → Bargain grid adapter (tile encoding consistent)

**Exit criteria**
- `test_fov_system.lua` passes with a fixed map and known occluders.
- `test_floor_adapter.lua` (or fold into `test_floors.lua`) verifies wall/floor copying and stairs placement.

---

### M3 — Deals (power system) + Offer logic
**Deliverables**
- `sins_data.lua` complete (7×3) with IDs and display text
- `deal_system.lua` applies **all 21** benefits + downsides (flags/callbacks where needed)
- Offer selection rules: forced floor-start (1 deal), optional level-up (2 deals + skip)

**Exit criteria**
- `test_data_loading.lua` validates 21 deals, each has benefit+downside.
- `test_deal_system.lua` covers at least: Pride/Ego, Wrath/Fury, Sloth/Autopilot, plus “all deals implemented” completeness check.
- Replacement interpretations for out-of-scope mechanics (gold/shops/items/spells) are encoded in data and verified by tests.

---

### M4 — Enemies + AI + Floors (full 7-floor simulation without UI)
**Deliverables**
- 10 enemy types + simple unique traits
- AI chase/attack decisions (melee + ranged)
- Floor generation/config for floors 1–7 (sizes, enemy counts, boss-only floor 7)

**Exit criteria**
- `test_enemy_ai.lua` and `test_enemies.lua` pass.
- `test_floors.lua` asserts floor sizes, enemy count ranges, stairs rules, and boss-only floor 7.

---

### M5 — UI (Deal Modal + HUD + End Screens)
**Deliverables**
- Deal modal: forced accept at floor start, optional skip at level-up
- HUD: HP, stats, active deals, floor, turn
- End screens: victory/death + replay flow

**Exit criteria (manual)**
- Verify forced/optional deal flows, HUD updates, end screens via play + debug shortcuts.
- Capture 2 screenshots: forced modal and victory/death screen.

---

### M6 — Game Loop Integration (vertical slice complete)
**Deliverables**
- `bargain/game.lua` orchestrates: title → floor loop → boss → win/lose
- Debug commands exposed as specified in PLAN_v0

**Exit criteria**
- `test_game_smoke.lua` passes (no nil errors stepping turns).
- Manual: start run, accept deals, clear floors (normal play or debug), reach floor 7, defeat boss, see victory.

---

### M7 — Balancing + Session Timing
**Deliverables**
- `bargain/balance_config.lua` (single source of truth for tunables)
- Session timing log for 3 runs + adjustments

**Exit criteria**
- Average run time 10–15 minutes; at least 1/3 runs winnable; not all runs trivial.

---

## 6) Integration Commands (verification)
- Build: `just build`
- Run: `./build/raylib-cpp-cmake-template`
- In-game console: `dofile("assets/scripts/bargain/tests/run_all_tests.lua")`
- Start manually (if not wired into main): `dofile("assets/scripts/bargain/game.lua"); BargainGame.start()`

---

## 7) Risk Register (top items + mitigations)
- **FOV correctness**: lock deterministic test maps early; keep implementation small and well-tested.
- **Deal downside “handwaving”**: require each deal to have an explicit enforcement mechanism (stat, flag, callback) and a unit test for at least one representative downside per category.
- **Integration churn in `game.lua`**: assign a single integrator; other streams publish stable APIs + contract tests.
- **Flaky tests due to RNG/procgen**: seed everywhere; inject RNG; assert invariants (counts/sizes) not exact layouts unless seeded.

---