# Game #4 “Bargain” — Engineering Plan (Iter3 Rewrite: v3.1)

## 1) Product Outcome (Vertical Slice)
Deliver a complete, replayable run loop:
- 7 floors total; floor 7 boss (“Sin Lord”).
- Win screen / death screen.
- Restart → new seeded run.
- Target session length: 10–15 minutes.

### Success Metrics (measurable)
- A full seeded run can be completed end-to-end (win or die) without crashes.
- Forced deal is presented at every floor start and cannot be skipped.
- Optional deal is offered on level-up and can be skipped.
- **Progression is only Faustian deals**: each deal applies (a) an immediate benefit and (b) a permanent downside that **enforces gameplay behavior** (not “text-only”).

---

## 2) Non-Negotiables (Hard Constraints)
Gameplay:
- Turn-based, grid-based, FOV-limited exploration/combat.
- Player verbs: `Move` (4-way), `Attack` (directional), `Wait`.
- Enemy AI: chase + attack only; **no A\***.

Content:
- **7 sins × 3 deals = 21 deals**.
- **All 21 downsides implemented** (no TODO markers; no placeholder behavior).
- **Forced deal at each floor start** (cannot skip).
- Optional deal at level-up (can skip).

Out of scope (must not creep):
- Inventory/items/potions/shops.
- Save/load, meta-progression, difficulty modes.

---

## 3) Repo Workflow (Multi-Agent + Beads)
### Coordination rules (required)
- Before editing, reserve files exclusively via Agent Mail (MCP).
- Split work along file ownership boundaries (see §9).
- Any contract/API change must be coordinated (see §6.3).

### Beads workflow (bd)
For each unit of work:
1) Triage with BV (pick a “ready” bead).
2) Claim bead → set `in_progress`.
3) Implement + tests.
4) Close bead + notify dependents via Agent Mail.

---

## 4) Architecture Overview (Test-First Boundary)
### 4.1 Core rule: “Pure Lua sim core”
Simulation modules are pure Lua:
- No rendering/input calls, no engine globals.
- State is a plain `world` table passed into systems.
- UI/engine glue reads `world` + queues actions into the sim.

### 4.2 Determinism contract (explicit + testable)
- All randomness flows through `world.rng:int(lo, hi)` seeded per run/test.
- Procgen is `generate(floor_num, seed, rng)` and is validated via invariants (not exact layout snapshots).
- Any stochastic combat must use injected RNG; otherwise deterministic.

### 4.3 Optional eventing (non-blocking)
- Sim may call `signal:emit(name, payload)` if `signal` is provided.
- Sim must work correctly with `signal == nil`.
- Tests prioritize state assertions; event assertions are optional (via stub signal).

---

## 5) Frozen State + Actions (Lock Early)
### 5.1 `world` minimum schema
- `world.grid` (tiles + occupancy API)
- `world.entities` (id → entity)
- `world.player_id`
- `world.turn` (int), `world.phase` (enum)
- `world.floor_num`, `world.run_state` (`playing|victory|death`)
- `world.rng`
- `world.deals`:
  - `applied` (map/set `deal_id → true`)
  - `history` (ordered list of `{deal_id, kind, floor_num, turn}`)
  - `pending_offer` (nil or `{kind, offers[], must_choose, can_skip}`)

### 5.2 Entity schema (component-ish tables)
Required fields:
- `id`, `kind` (`player|enemy|boss`)
- `x`, `y`
- `hp`, `hp_max`, `atk`, `def`, `speed`, `fov_radius`
- `xp`, `level`
- `flags` (map)
- `hooks` (tables of callbacks keyed by hook name)

### 5.3 Action encoding (single format for player + AI)
- Move: `{type="move", dx=0|±1, dy=0|±1}`
- Attack: `{type="attack", dx=0|±1, dy=0|±1}`
- Wait: `{type="wait"}`

**Invalid actions policy (choose + lock):**
- Either (A) deterministic no-op returning `{ok=false, err=...}` or (B) deterministic error.
- Add a contract test and do not change without coordination.

---

## 6) Module Contracts (Parallelizable by Design)
> Protocol: **Change contract tests before changing contracts.**  
> Each module must have: public API + contract test + focused unit tests.

### 6.1 `bargain/grid_system.lua`
API:
- `Grid.new(w, h)`
- `get_tile/set_tile`
- `place_entity(entity)`, `move_entity(id, nx, ny)`
- `can_move_to(x,y)`, `is_opaque(x,y)`
- `get_occupant(x,y)`
- `neighbors4(x,y)`

Contract tests:
- Bounds block; walls block; entities block.
- Occupancy bijection invariants: no dupes, no ghosts.

### 6.2 `bargain/turn_system.lua`
API (pick one stepping model and freeze it):
- `TurnSystem.new({world, signal?})`
- `queue_player_action(action)`
- `step()` advances exactly one phase transition
- `get_phase()`, `get_turn()`

Contract tests:
- Phase loop order is frozen and asserted:
  - `PLAYER_INPUT → PLAYER_ACTION → ENEMY_ACTIONS → END_TURN → PLAYER_INPUT`
- Player acts before enemies.
- Enemy ordering deterministic: sort by `speed` then stable tie-break (entity id).

### 6.3 `bargain/combat.lua`
API:
- `Combat.resolve_attack(attacker_id, dx, dy, world)` → result

Contract tests:
- Attack consumes turn even if target cell is empty.
- Damage formula frozen (deterministic or RNG-based).
- Death behavior frozen (remove entity vs flag); tests lock the choice.

### 6.4 `bargain/fov_system.lua`
API:
- `FOV.new(grid)`
- `update(cx, cy, radius)`
- `is_visible(x,y)`, `get_state(x,y)` (`UNSEEN|SEEN|VISIBLE`)

Contract tests:
- Occlusion behind walls on small golden maps.
- Memory transition `VISIBLE → SEEN` after moving away.

### 6.5 `bargain/deal_system.lua` + `bargain/sins_data.lua`
Data contract (`sins_data.lua`):
- Exactly 21 deals.
- Per deal:
  - `id` (stable string)
  - `sin` (one of 7 stable keys)
  - `name`, `benefit_text`, `downside_text`
  - `apply(world, player_id)` registers enforcement (stats/flags/hooks/rules)

System contract:
- `DealSystem.get_offers(kind, world)` where `kind ∈ {"floor_start","level_up"}`
- `DealSystem.apply_deal(deal_id, world)` (records + applies)

Offer-rule tests:
- Floor start: exactly 1 offer; `must_choose=true`, `can_skip=false`
- Level up: exactly 2 offers; `must_choose=false`, `can_skip=true`
- No duplicates of already-applied deals unless explicitly allowed (decide + test)

Enforcement tests (ship gate):
- Completeness: 21/21 deals exist and `apply` registers enforcement marker(s).
- Behavior: every downside is validated by an automated test (policy in §7.4).

### 6.6 `bargain/enemy_ai.lua` + `bargain/enemies_data.lua`
API:
- `EnemyAI.decide(enemy_id, world)` → action

Contract tests:
- Adjacent to player → attack.
- Otherwise move to reduce Manhattan distance if possible; deterministic fallback axis; else wait.
- Deterministic results on fixed maps.

### 6.7 `bargain/floor_manager.lua` + `bargain/floors_data.lua`
API:
- `FloorManager.generate(floor_num, seed, rng)` → `{grid, entities, stairs_pos?, metadata}`

Invariant tests:
- Floor sizes match explicit table per `floor_num`.
- Enemy counts in allowed ranges.
- Valid stairs placement on floors 1–6; **no stairs down on floor 7**.
- Floor 7 contains boss; no alternate escape/progression.

### 6.8 `bargain/game.lua` (integrator-owned)
API:
- `Game.new({seed, signal?, headless?})`
- `queue_action(action)`, `step()`
- `is_waiting_for_deal_choice()`, `choose_deal(deal_id)`, `skip_deal()` (only when allowed)

Debug hooks (stable, test-safe):
- `debug.goto_floor(n)`, `debug.set_hp(x)`, `debug.grant_xp(x)`, `debug.kill_boss()`

---

## 7) Test Plan (Deterministic + Enforcement-First)
### 7.1 Test harness (Milestone 0 gate)
`assets/scripts/bargain/tests/run_all_tests.lua` must:
- Discover tests (`test_*.lua` or a manifest).
- Run each file with `pcall`.
- Print per-file PASS/FAIL + summary.
- Exit failure via `error()` if any test fails.

### 7.2 Required unit suites (minimum)
- `test_grid_system.lua`
- `test_turn_system.lua`
- `test_combat.lua`
- `test_fov_system.lua`
- `test_enemy_ai.lua`
- `test_deal_system.lua`
- `test_data_loading.lua`
- `test_floors.lua`

### 7.3 Headless integration smoke (runtime safety net)
`test_game_smoke.lua`:
- Starts a seeded run in headless mode.
- Auto-chooses forced floor-start deals deterministically (e.g., first offer).
- Steps N turns across multiple floors.

Asserts:
- No runtime errors.
- Player remains in bounds.
- Phase returns to `PLAYER_INPUT`.
- Occupancy invariants hold (no two entities share a tile, etc.).
- Forced-deal gate blocks progression until chosen.

### 7.4 Deal downside enforcement policy (ship gate)
Each downside must be validated by an automated behavior assertion, not just “marker exists”.

Define enforcement categories (finalize early inside `test_deal_system.lua`):
- Stat clamp (e.g., max HP reduction)
- Per-turn tax (e.g., drain/decay)
- Action restriction (e.g., cannot wait; cannot attack unless condition)
- Risk-on-action (e.g., self-damage on move/attack)
- Progress penalty (e.g., XP reduction; level-up cost increase)

**Coverage requirement:**
- 21/21 deals: at least one test assertion demonstrating enforced behavior.
- Category tests: 1–2 small golden-map tests per category to prevent regressions.
- Completeness test: 21/21 deals have stable IDs and an enforcement registration marker.

---

## 8) Milestones (Shippable + Test-Gated)
### M0 — Harness + contracts (unblocks parallel work)
Deliver:
- Test runner.
- Module stubs exporting APIs (may `error("unimplemented")`).
- Contract test files wired.

Gate:
- Runner executes without load-time crashes; failures are reported cleanly.

### M1 — Core loop on fixed tiny map (headless)
Deliver:
- Grid movement/collision.
- Turn system phase loop + action queue.
- Combat resolution.

Gate:
- `test_grid_system.lua`, `test_turn_system.lua`, `test_combat.lua` pass.

### M2 — FOV + floor generation invariants
Deliver:
- FOV with occlusion + memory.
- Floor generation meeting invariants for floors 1–7.

Gate:
- `test_fov_system.lua`, `test_floors.lua` pass.

### M3 — Deals (21/21) + offer rules + enforcement
Deliver:
- Deal offer rules (floor-start forced; level-up optional).
- `sins_data.lua` complete with 21 real effects and downsides.

Gate:
- `test_data_loading.lua` proves 21/21 stable IDs.
- `test_deal_system.lua` proves offer rules + enforcement behavior coverage.

### M4 — Enemies + AI + progression to floor 7 win/lose
Deliver:
- Enemy templates + deterministic chase/attack AI.
- Boss config for floor 7 + victory wiring.

Gate:
- `test_enemy_ai.lua` passes.
- Victory test: boss defeat → `run_state="victory"`.

### M5 — UI flows (manual gate, minimal polish)
Deliver:
- Deal modal (forced vs optional skip).
- HUD (HP/stats/deals/floor/turn).
- Victory/death screens + restart.

Manual gate checklist:
- Forced deal cannot be skipped.
- Level-up deal can be skipped.
- Victory/death reachable; restart produces a new seeded run.

### M6 — Integration hardening
Deliver:
- `bargain/game.lua` orchestrator complete + debug hooks.
- Headless multi-floor smoke test stability.

Gate:
- `test_game_smoke.lua` passes reliably (optionally on 3 fixed seeds).

### M7 — Balance pass (time-to-complete target)
Deliver:
- Central `balance_config.lua` (single tuning surface).
- 3 seeded run timing notes + adjustments.

Gate:
- Average run time ~10–15 minutes; at least one seed winnable without debug hooks.

---

## 9) Parallelization (Minimize Merge Conflicts)
### 9.1 File ownership lanes
- Core sim: `bargain/grid_system.lua`, `bargain/turn_system.lua`, `bargain/combat.lua`
- Perception/procgen: `bargain/fov_system.lua`, `bargain/floor_manager.lua`, `bargain/floors_data.lua`
- Content/progression: `bargain/deal_system.lua`, `bargain/sins_data.lua`, `bargain/enemies_data.lua`
- AI: `bargain/enemy_ai.lua`
- Integrator: `bargain/game.lua`
- Tests: `assets/scripts/bargain/tests/*` (split by module)

### 9.2 Highest-leverage parallel unit: “one sin”
If repo conventions allow, split content to reduce conflicts:
- `bargain/sins/envy.lua`, `.../wrath.lua`, etc., aggregated by `bargain/sins_data.lua`

Parallel bead definition:
- One sin bead = 3 deals + tests proving each downside behavior.

### 9.3 Contract-change protocol (anti-churn)
Any API change requires:
1) Update contract test(s).
2) Update module(s).
3) Update integrator glue/tests.
4) Notify dependents (Agent Mail) with the contract delta.

---

## 10) Risks + Testable Mitigations
- “Downside drift” into text-only → enforce 21/21 behavior assertions in `test_deal_system.lua`.
- FOV regressions → keep 2–3 golden maps; never rely on procgen in FOV unit tests.
- Procgen flakiness → seed everywhere; test invariants only; clamp RNG ranges.
- Non-deterministic ordering bugs → stable sorting (speed then id); avoid `pairs()` where order matters in gameplay logic.
- Integration churn → keep `bargain/game.lua` integrator-owned; require contract-test-first changes.

---