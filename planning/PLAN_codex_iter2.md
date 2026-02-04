# Game #4: “Bargain” — Engineering Plan (v2)

## 0) Outcome, Scope, Guardrails

### 0.1 Target outcome (vertical slice)
A complete, playable, deterministic-enough-to-test, turn-based roguelike run:
- 7 floors total → floor 7 boss (“Sin Lord”) → win/lose screen → replay.
- Session target: 10–15 minutes.
- **Only progression is Faustian deals**: every deal grants a benefit **and** a permanent downside with explicit gameplay enforcement.

### 0.2 Hard constraints
- Turn-based, grid-based, FOV-limited exploration/combat.
- **7 sins × 3 deals = 21 total deals**.
- **All 21 downsides are implemented behavior**, not placeholders.
- **Forced deal at floor start** (cannot skip).
- **Optional deal at level-up** (can skip).
- Enemy AI is simple: chase + attack only (no A* pathfinding).
- No items/inventory/potions/shops/meta-progression/save-load/difficulty modes.

### 0.3 Player verbs (and only these)
- Move (4-way).
- Attack (directional).
- Wait.

### 0.4 Definition of done
- Automated tests run deterministically (seeded RNG) and cover core rules + deal enforcement.
- A headless smoke run can simulate multiple turns across multiple floors without nil errors.
- Manual playthrough can reach floor 7 and finish (win or die) with correct UI flows for forced/optional deals.

---

## 1) Architecture choices (optimize for testability + parallel work)

### 1.1 “Pure Lua core” boundary
Implement the game’s **simulation** as pure Lua modules with plain tables:
- No direct dependency on rendering, input, or engine globals.
- UI/engine glue is a thin layer that calls into the simulation.

This allows unit tests to instantiate a “world” and run turns without graphics.

### 1.2 Determinism + reproducibility
All randomness must be injectable:
- `rng:int(lo, hi)` interface (seeded in tests).
- Floor generation takes a seed and produces deterministic invariants (size, wall ratio bounds, enemy counts, stairs placement).

### 1.3 Eventing (optional dependency)
Use `hump.signal` behind an interface (`signal:emit(name, payload)`), but make the simulation work with `signal=nil`.
- Tests can assert state directly; optionally assert emitted events when a signal stub is provided.

---

## 2) Data model (stable early; enables parallel implementation)

### 2.1 Core “World” state
A single table passed through systems:
- `world.grid` (tiles + occupancy)
- `world.entities` (id → entity)
- `world.player_id`
- `world.turn`, `world.phase`
- `world.rng`
- `world.floor_num`, `world.run_state` (playing/victory/death)
- `world.deal_state` (applied deals, offer history, forced/optional flags)

### 2.2 Entity schema (minimum)
Each entity is a table:
- Identity: `id`, `kind` (`player|enemy|boss`)
- Position: `x`, `y`
- Stats: `hp`, `hp_max`, `atk`, `def`, `speed`, `fov_radius`
- Progress: `xp`, `level`
- Flags/hooks (for deals): `flags{}`, `hooks{ on_turn_start[], on_attack[], on_take_damage[], on_kill[], ... }`

### 2.3 Tile schema
- `FLOOR`, `WALL`, `STAIRS_DOWN` (and optionally `STAIRS_UP` if needed for UI only).
- Grid exposes `can_move_to`, `is_opaque`.

---

## 3) Module contracts (freeze APIs early; implement behind them)

### 3.1 `bargain/turn_system.lua`
Responsibilities:
- Phase machine: `PLAYER_INPUT → PLAYER_ACTION → ENEMY_ACTIONS → END_TURN → PLAYER_INPUT`
- Ordering rule: **player acts first every turn; speed only orders enemies**.
Public API:
- `TurnSystem.new({signal?, world})`
- `step()` advances exactly one phase transition (or one full turn if you prefer; choose one and test it).
- `queue_player_action(action)` stored until `PLAYER_ACTION`.
- `get_phase()`, `get_turn()`, `get_enemy_order()`

Tests must lock:
- Phase sequencing.
- Enemy ordering determinism given speeds.
- Player action always precedes enemy actions.

### 3.2 `bargain/grid_system.lua`
Responsibilities:
- Tile storage + bounds checks.
- Occupancy + movement + collision (walls, entities).
Public API:
- `Grid.new(w, h)`
- `set_tile/get_tile`
- `place_entity/move_entity`
- `can_move_to/is_opaque`
- `neighbors4(x,y)` helper

Tests must lock:
- Collision rules (walls block movement; entities block movement).
- Move semantics (dx/dy; bounds).
- Occupancy updates (no duplicate occupancy).

### 3.3 `bargain/combat.lua`
Responsibilities:
- Deterministic damage + hit resolution (if any).
Public API:
- `Combat.resolve_attack(attacker, defender, rng, world)` → result table
Rules to freeze (example; finalize in this milestone):
- Attack consumes turn even if no defender in target cell.
- Damage formula is deterministic with injected RNG (or fully deterministic if you choose no RNG).

Tests must lock:
- Known attacker/defender stats yield expected damage with fixed RNG.
- Death handling (hp <= 0).

### 3.4 `bargain/fov_system.lua`
Responsibilities:
- Visibility and memory: `UNSEEN`, `SEEN`, `VISIBLE`.
Public API:
- `FOV.new(grid)`
- `update(cx, cy, radius)`
- `get_state(x,y)`, `is_visible(x,y)`

Tests must lock:
- Occlusion behind walls on fixed maps.
- Memory transition `VISIBLE → SEEN` after moving away.

### 3.5 `bargain/deal_system.lua` + `bargain/sins_data.lua`
**Non-negotiable:** every deal must have explicit downside enforcement.

Data contract (`sins_data.lua`):
- 7 sins; each has 3 deals; each deal has:
  - `id` (unique stable string)
  - `sin` (stable enum/string)
  - `name`
  - `benefit_text`, `downside_text`
  - `apply(world, player)` function OR a declarative effect + implementation mapping

System API (`deal_system.lua`):
- `DealSystem.get_offers(kind, rng, state)` where `kind ∈ {floor_start, level_up}`
- `DealSystem.apply_deal(world, player, deal_id)` (records it, applies benefit+downside)

Tests must lock:
- Exactly 21 deals present with required fields.
- `apply_deal` always changes state in a detectable way and registers enforcement for downsides (flags/hooks/stat deltas).
- Offer rules:
  - Floor start: exactly 1 offer, cannot skip.
  - Level up: 2 offers + explicit skip option.

### 3.6 `bargain/enemy_ai.lua` + `bargain/enemies_data.lua`
AI contract (no A*):
- If adjacent to player: attack.
- Else: choose a move that reduces Manhattan distance if possible; if blocked, try alternate axis; else wait.

API:
- `EnemyAI.decide(enemy, world)` → action
- `Enemies.create(type_id, rng)` → entity template

Tests must lock:
- AI chooses attack when adjacent.
- AI moves toward player on simple maps.
- AI behavior is deterministic on fixed maps.

### 3.7 `bargain/floor_manager.lua` + `bargain/floors_data.lua`
Responsibilities:
- Generate floor layouts and spawn enemies.
- Enforce 7-floor progression and boss-only floor 7 rule.

API:
- `FloorManager.generate(floor_num, seed, rng)` → `{grid, entities, stairs_pos, metadata}`
- `FloorManager.spawn_player(world, pos)` (or handled by game orchestrator)

Tests must lock (prefer invariants, not exact layouts):
- Floor sizes per floor number.
- Enemy counts within bounds.
- Stairs placement rules.
- Floor 7 has boss and no stairs down.

### 3.8 UI + glue (thin layer; manual acceptance heavy)
- `bargain/ui/deal_modal.lua` (forced accept vs optional skip)
- `bargain/ui/game_hud.lua` (HP/stats/deals/floor/turn)
- `bargain/ui/end_screens.lua`
- `bargain/game.lua` orchestrator (single integrator-owned)

Debug commands contract:
- `BargainGame.debug.goto_floor(n)`, `clear_floor()`, `kill_boss()`, `set_hp(x)`, `grant_xp(x)`.

---

## 4) Test strategy (make it cheap to validate workstreams)

### 4.1 Test harness (mandatory)
`assets/scripts/bargain/tests/run_all_tests.lua`:
- Discovers `test_*.lua` (or a fixed manifest).
- Runs each under `pcall`.
- Prints per-test-file PASS/FAIL + summary.
- Returns non-zero-like status via `error()` if failures (so CI/dev console can detect it).

### 4.2 Unit tests (fast, deterministic)
Minimum set (must exist before integration work):
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
- Constructs `world` + `BargainGame` in headless mode.
- Applies forced floor-start deals deterministically.
- Steps N turns and asserts no nil errors; asserts invariants (player stays in bounds; phase loops; enemies act).

### 4.4 Deal enforcement coverage policy (practical but strict)
- **Completeness test**: iterate all 21 deals and assert each deal has:
  - benefit+downside text
  - an implementation entry
  - an “enforcement marker” (stat delta, flag, or hook) that can be asserted
- **Representative behavior tests**: at least 1 test per downside category you define (e.g., action restriction, stat drain per turn, max HP reduction, FOV reduction, self-damage on action, XP penalty).

---

## 5) Parallelization plan (minimize file overlap)

### Stream A — Core simulation
Owns: `grid_system`, `turn_system`, `combat`, base entity schema, basic player actions.

### Stream B — Progression/content
Owns: `sins_data`, `deal_system`, enemy data/templates, XP/level rules.

### Stream C — Perception/procgen
Owns: `fov_system`, `floor_manager`, dungeon adapter.

### Stream D — UI/UX
Owns: deal modal, HUD, end screens (reads simulation state; no simulation logic).

### Stream E — Integrator
Owns: `bargain/game.lua`, debug commands, headless smoke test wiring, state machine.

Cross-stream contract rule:
- Streams must not call into each other via internals; only via frozen APIs above.
- Any contract change requires updating the corresponding contract test first.

---

## 6) Milestones (shippable, testable checkpoints)

### M0 — Contracts + harness (unblocks everything)
Deliverables:
- Module stubs with public APIs + `error("unimplemented")` bodies.
- Test harness runs and reports failures cleanly.
Exit criteria:
- Running the harness loads all test files and produces a summary output.

### M1 — Core loop without UI
Deliverables:
- Grid collision + movement.
- Turn system phases + enemy ordering.
- Player Move/Attack/Wait action model.
Exit criteria (automated):
- `test_grid_system.lua`, `test_turn_system.lua`, `test_combat.lua` pass.

### M2 — FOV + floor adapter
Deliverables:
- FOV implementation with memory.
- Floor generation adapter producing correct tile encoding + stairs.
Exit criteria (automated):
- `test_fov_system.lua`, `test_floors.lua` (invariants) pass.

### M3 — Deals (all 21) + offer rules
Deliverables:
- Complete `sins_data.lua` with 21 deal definitions.
- Deal application applies benefit + registers downside enforcement.
- Offer flows: forced floor-start, optional level-up.
Exit criteria (automated):
- `test_data_loading.lua` validates 21/21.
- `test_deal_system.lua` validates enforcement markers for 21/21 and behavior for representative categories.

### M4 — Enemies + AI + floor progression
Deliverables:
- Enemy templates + AI chase/attack.
- Floors 1–7 config including boss-only floor 7.
Exit criteria (automated):
- `test_enemy_ai.lua`, `test_floors.lua` pass.

### M5 — UI + manual flows
Deliverables:
- Deal modal (forced vs optional skip).
- HUD + end screens.
Exit criteria (manual):
- Floor start always forces deal selection.
- Level-up offers allow skip.
- Victory/death screens appear and allow replay.

### M6 — Integration (vertical slice complete)
Deliverables:
- `bargain/game.lua` state machine and debug commands.
- Headless smoke test.
Exit criteria:
- `test_game_smoke.lua` passes.
- Manual: can reach floor 7 and finish a run (normal play or debug).

### M7 — Balance + timing
Deliverables:
- Central `balance_config.lua` for tunables.
- Timing logs for 3 runs + adjustments.
Exit criteria:
- Average run time ~10–15 minutes; at least one winnable run; not all runs trivial.

---

## 7) Beads breakdown (dependency-aware, parallelizable)
Create beads that map to milestone deliverables (examples):
- M0: harness + stubs + contract tests (one bead per module contract if needed).
- M1: grid; turn system; combat; player actions (separate beads).
- M2: FOV; floor adapter/procgen invariants (separate beads).
- M3: deal schema + completeness tests; deal implementations split by sin (7 beads) with shared enforcement helper.
- M4: enemy data; AI; floors_data; boss implementation.
- M5: deal modal; HUD; end screens.
- M6: game orchestrator; debug commands; headless smoke test.
- M7: balance config; run timing + adjustments.

Each bead’s acceptance criteria:
- Adds/updates automated tests for the behavior it introduces.
- Runs the local test harness with no new failures.
- Avoids cross-stream file edits unless coordinated via contract changes.

---

## 8) Risk register + mitigations

- **Deal downsides drift into “text only”**: enforce the 21/21 enforcement-marker test + representative behavior tests.
- **FOV correctness**: lock a small set of golden maps for unit tests early.
- **Procgen flakiness**: assert invariants; seed RNG everywhere; avoid exact-layout assertions unless explicitly seeded.
- **Integration churn**: keep `bargain/game.lua` integrator-owned; other streams communicate via stable contracts + tests.