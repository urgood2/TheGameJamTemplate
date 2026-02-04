# Serpent — SNKRX-Style Survivor (Vertical Slice) Implementation Plan v2

## TL;DR
Add a new selectable game mode (**SERPENT**) where the player only steers a snake; each segment is an auto-attacking unit. Complete run loop: **20 waves** with a **shop between waves**, **16 units**, **4 class synergies**, **2 bosses**, and **win/lose screens**, with unit tests for all pure-logic modules and deterministic RNG in tests.

---

## Goals, Non‑Goals, Guardrails

### Goals (Must Have)
- New **SERPENT** mode selectable from main menu.
- Snake length rules:
  - **Min 3**, **max 8** segments.
  - Purchase order defines segment order (**append to tail**).
- Real-time arena combat; units auto-attack (attack speed + range).
- Shop between waves:
  - Buy, sell (**50% refund**), reroll (**2g base, +1g per reroll within the same shop phase**; resets each shop entry).
- Unit leveling:
  - **3 copies of the same unit at the same level → combine** into next level (cap **level 3**).
  - Stat scaling: **double base per level** (HP/Attack), plus synergy modifiers.
- 20-wave run with scaling; bosses at:
  - **Wave 10**: Swarm Queen
  - **Wave 20**: Lich King
- HUD (HP, gold, wave), synergy display, game over/victory screens.

### Non‑Goals (Must NOT Have)
- No items, interest, meta-progression, save/load, difficulty modes, controller support.
- No manual repositioning within the snake.
- Placeholder visuals; use existing UI primitives/components.

### Numeric Source of Truth
- **All unit/enemy base stats, specials, and shop tier odds come from** `planning/PLAN_v0.md`.
- This plan only adds missing *behavioral* specifics (ordering, combine rules, rounding rules, interfaces).

---

## Implementation Contracts (Make Ambiguity Impossible)

### Core Mode State Machine
`serpent_main.lua` runs a simple state machine:
- `MODE_STATE.COMBAT` → `MODE_STATE.SHOP` when wave director reports “wave cleared”
- `MODE_STATE.SHOP` → `MODE_STATE.COMBAT` when player presses “Ready”
- Any state → `MODE_STATE.GAME_OVER` when snake length reaches 0
- `MODE_STATE.COMBAT` → `MODE_STATE.VICTORY` when wave 20 cleared

### Canonical Data Shapes (Pure Logic)
All pure modules accept/return plain Lua tables, no engine globals.

**UnitDef** (from `serpent/data/units.lua`)
- `id` (string), `class` (string: `"Warrior"|"Mage"|"Ranger"|"Support"`), `tier` (1..4), `cost` (int)
- `base_hp`, `base_attack`, `range`, `atk_spd` (numbers)
- `special_id` (string or nil)

**UnitInstance**
- `instance_id` (string or int), `def_id`, `level` (1..3)
- `hp`, `hp_max`, `attack`, `range`, `atk_spd`
- `cooldown` (seconds until next attack, >= 0)
- `acquired_seq` (monotonic int for “purchase order” tie-breaking)

**SnakeState**
- `segments` = array of `UnitInstance` in head→tail order
- `min_len=3`, `max_len=8`

### Combine + Ordering Rules (Critical)
- Buying a unit **always appends** a new level-1 instance to the tail **before** combine checks.
- Combine detection:
  - For each `def_id`, find groups of **3 instances with the same `level`**.
  - Combine **the 3 lowest `acquired_seq`** among eligible instances for that `def_id` + level.
  - Result:
    - Replace the earliest (lowest `acquired_seq`) of the 3 with an upgraded instance (`level+1`).
    - Remove the other 2 instances from the snake.
    - Upgraded instance keeps the position of the kept instance.
- Purchase at max length:
  - Allowed **only if** the append + all resulting combines leave final length `<= max_len`.
  - Otherwise purchase is rejected (no gold spent).

### Gold + Rounding Rules
- Costs are integers.
- Sell refund:
  - Refund is `math.floor(total_paid_for_instance * 0.5)`.
  - `total_paid_for_instance = unit_def.cost * (3^(level-1))` (level 1: ×1, level 2: ×3, level 3: ×9).
- Reroll cost within a single shop phase:
  - `reroll_cost = 2 + reroll_count` (first reroll costs 2, then 3, 4, …)
  - `reroll_count` resets to 0 each time entering the shop.

### Synergy Application Rules
Synergy is derived from the **current snake segments** (post-combine).
- Warrior: affects **attack damage** (and HP at 4)
- Mage: affects **spell damage** (if spell system is stubbed, treat as attack multiplier for now) and cooldown at 4
- Ranger: affects **attack speed** and range at 4
- Support: adds **snake regen** (HP/sec) and at 4 adds **+10% all stats**
- All synergy modifiers are applied when:
  - Entering combat
  - After buy/sell/combine
  - At wave start

### RNG (Deterministic Tests)
All randomness (shop offerings, wave enemy picks) must be via injected `rng` function:
- `rng.int(min, max)` and/or `rng.float()` passed into pure modules
- Tests provide a deterministic RNG stub (fixed sequence)

---

## Repo Integration (Concrete Touchpoints)

### Game State Integration (`assets/scripts/core/main.lua`)
- Add `GAMESTATE.SERPENT` constant.
- `changeGameState(newState)`:
  - On enter SERPENT: call `Serpent.init()`
  - On leave SERPENT: call `Serpent.cleanup()` before transitioning away
- `main.update(dt)`:
  - When `currentGameState == GAMESTATE.SERPENT` and not paused: call `Serpent.update(dt)`
  - Do not break existing pause behavior (`globals.gamePaused` / main-menu pause)

### Menu Entry
Add a “Serpent” button alongside existing main menu buttons, wired to `changeGameState(GAMESTATE.SERPENT)`.

### Serpent Ownership + Cleanup
- Serpent creates and owns:
  - all entities it spawns
  - its timers/signals grouped under a single group/tag owned by the mode
- `Serpent.cleanup()` must be safe to call multiple times (idempotent).

---

## Directory Layout
All Serpent code under `assets/scripts/serpent/`:
- `serpent_main.lua`
- `data/units.lua`, `data/enemies.lua`, `data/shop_odds.lua` (may read from v0 tables if mirrored)
- Pure logic:
  - `snake_logic.lua`
  - `serpent_shop.lua`
  - `synergy_system.lua`
  - `unit_factory.lua`
  - `wave_config.lua`
  - `auto_attack_logic.lua`
  - `serpent_wave_director.lua`
- Runtime adapters:
  - `snake_entity_adapter.lua`, `snake_controller.lua`
  - `combat_adapter.lua`, `combat_manager.lua`
  - `enemy_spawner_adapter.lua`
  - `auto_attack.lua`
- UI:
  - `ui/hud.lua`, `ui/shop_ui.lua`, `ui/synergy_ui.lua`
  - `ui/game_over_screen.lua`, `ui/victory_screen.lua`
- Tests:
  - `tests/test_*.lua` (pure logic + view-model tests only)

---

## Testing Standard

### Test Header (Required)
```lua
package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"
local t = require("tests.test_runner")
```

### How to Run (Repo-Local)
```bash
set -e
for f in assets/scripts/serpent/tests/test_*.lua; do lua "$f"; done
```

### Testability Rule
- UI tests only cover view-model/pure helpers (no engine draw calls).
- Runtime adapters are validated via manual checklist (and optional lightweight smoke test if feasible).

---

## Execution Strategy (Parallelizable With Dependencies)

### Dependency Notes
- Pure logic modules can be developed in parallel after Task 1 scaffolding.
- Runtime wiring (combat/spawner/controller) depends on their pure counterparts.

### Parallel Work Packs
- Pack A (Pure Core): Tasks 2, 4, 6, 8, 9
- Pack B (Combat Pure): Task 7 (+ parts of 10 if pure logic extracted)
- Pack C (Runtime Movement): Task 3 (after Task 1)
- Pack D (Runtime Combat/Waves): Tasks 10–11 (after Tasks 3, 6–7)
- Pack E (UI): Tasks 12–16 (after Task 1; integrates after Tasks 8, 11)
- Pack F (Bosses): Task 15 (after Tasks 5, 11)

---

## Tasks (Checklist + Acceptance Criteria)

### Task 1 — Mode Skeleton + Core Integration
**Deliverables**
- `assets/scripts/serpent/serpent_main.lua` with `init()`, `update(dt)`, `cleanup()`
- Folder structure under `assets/scripts/serpent/`
- Minimal integration edits in `assets/scripts/core/main.lua`:
  - `GAMESTATE.SERPENT`
  - menu button
  - update hook
  - state transition hooks call init/cleanup

**Acceptance**
- `lua -e "package.path=package.path..';./assets/scripts/?.lua;./assets/scripts/?/init.lua'; require('serpent.serpent_main')"` succeeds.
- Entering SERPENT from main menu does not error.
- Leaving to main menu and re-entering SERPENT does not duplicate entities/handlers (observed via no double-spawns and no repeated callbacks).

---

### Task 2 — Unit Data (16)
**Deliverables**
- `assets/scripts/serpent/data/units.lua` mirrors the 16 units in `planning/PLAN_v0.md` (ids, classes, tiers, costs, base stats, specials).

**Tests**
- `assets/scripts/serpent/tests/test_units.lua`:
  - exactly 16 entries
  - 4 per class
  - `cost == tier*3`

---

### Task 3 — Snake Movement (Pure + Runtime)
**Deliverables**
- `assets/scripts/serpent/snake_logic.lua` (pure):
  - `can_buy(snake_state, pending_combines) -> bool`
  - `append_unit(snake_state, unit_instance) -> snake_state`
  - `apply_death(snake_state, instance_id) -> snake_state`
  - `can_sell(snake_state, instance_id) -> bool`
  - `sell_remove(snake_state, instance_id) -> snake_state`
- `assets/scripts/serpent/snake_entity_adapter.lua` (runtime): create/destroy segment entities from snake_state
- `assets/scripts/serpent/snake_controller.lua` (runtime): input steers head; body follows with stable spacing

**Tests**
- `assets/scripts/serpent/tests/test_snake_logic.lua`:
  - append up to max length with no combines
  - selling blocked if it would drop below 3
  - death removal can drop below 3
  - length 0 triggers “dead” condition returned by logic (or explicit helper)

**Manual**
- Snake spawns with a defined default (e.g., 3 or 4 segments; choose one and document in code).
- Moves with WASD/arrows; spacing stable; no jitter.

---

### Task 4 — Synergy System (Pure)
**Deliverables**
- `assets/scripts/serpent/synergy_system.lua`:
  - `calculate(segments) -> synergy_state`
  - output includes per-class `count`, `level` (0/1/2), and explicit numeric modifiers (fractions)

**Tests**
- `assets/scripts/serpent/tests/test_synergy_system.lua`:
  - thresholds at 2/4
  - correct modifier values from `planning/PLAN_v0.md`

---

### Task 5 — Enemy Data (11)
**Deliverables**
- `assets/scripts/serpent/data/enemies.lua` mirrors the 11 enemies in `planning/PLAN_v0.md` (including boss ids).

**Tests**
- `assets/scripts/serpent/tests/test_enemies.lua`:
  - exactly 11 entries
  - boss ids present

---

### Task 6 — Wave Config (20)
**Deliverables**
- `assets/scripts/serpent/wave_config.lua`:
  - deterministic generator or explicit table for 20 waves
  - exposes helpers:
    - `enemy_count(wave)`, `hp_mult(wave)`, `dmg_mult(wave)`, `gold_reward(wave)`
  - bosses appear at 10 and 20

**Tests**
- `assets/scripts/serpent/tests/test_wave_config.lua`:
  - exactly 20 waves produced
  - boss waves at 10 and 20
  - scaling math matches spec

---

### Task 7 — Auto-Attack (Pure + Runtime)
**Deliverables**
- `assets/scripts/serpent/auto_attack_logic.lua` (pure):
  - cooldown tick/update
  - target selection: nearest in range
  - returns attack events `{attacker_id, target_id, damage}`
- `assets/scripts/serpent/auto_attack.lua` (runtime): maps entities → pure inputs and applies events via adapter

**Tests**
- `assets/scripts/serpent/tests/test_auto_attack_logic.lua`:
  - cooldown cadence
  - nearest target selection
  - out-of-range behavior

---

### Task 8 — Shop System (Pure)
**Deliverables**
- `assets/scripts/serpent/serpent_shop.lua`:
  - `enter_shop(wave, gold, rng) -> shop_state` (reroll_count reset)
  - `reroll(shop_state, rng) -> shop_state`
  - `can_buy(shop_state, offering_index, snake_state) -> bool`
  - `buy(...) -> (shop_state, snake_state, gold_delta, combine_events)`
  - `can_sell(snake_state, instance_id) -> bool`
  - `sell(...) -> (snake_state, gold_delta)`
  - uses shop odds from `planning/PLAN_v0.md` (mirrored in a data module if needed)

**Tests**
- `assets/scripts/serpent/tests/test_serpent_shop.lua`:
  - offerings count fixed (choose and document: e.g., 5)
  - reroll cost increments and resets per shop entry
  - gold accounting + rounding rules
  - purchase rejection at max length without combines; acceptance when a combine reduces length

---

### Task 9 — Unit Factory + Leveling (Pure)
**Deliverables**
- `assets/scripts/serpent/unit_factory.lua`:
  - `create_instance(def_id, acquired_seq) -> UnitInstance(level=1)`
  - `apply_level_stats(instance, unit_def) -> instance` (HP/Attack doubling by level)
  - `detect_and_apply_combines(snake_state) -> (snake_state, combine_events)`

**Tests**
- `assets/scripts/serpent/tests/test_unit_factory.lua`:
  - stat doubling by level, cap at 3
  - combine chooses lowest `acquired_seq` triple
  - resulting order rules (kept slot preserved, 2 removed)

---

### Task 10 — Combat Integration (Runtime Coordinator)
**Deliverables**
- `assets/scripts/serpent/combat_adapter.lua`: minimal bridge for applying damage/heal and querying positions
- `assets/scripts/serpent/combat_manager.lua`:
  - runs auto-attack runtime
  - processes contact damage (with explicit per-pair cooldown constant)
  - removes dead snake segments immediately and triggers game-over when length 0
  - applies synergy refresh at defined points

**Acceptance**
- Manual: enemy contact damages segments; dead segments disappear and snake closes gaps; no double damage spam from contacts due to cooldown.

---

### Task 11 — Wave Director (Pure + Runtime Spawner)
**Deliverables**
- `assets/scripts/serpent/serpent_wave_director.lua` (pure):
  - tracks current wave, kill counts, and transitions
  - produces spawn specs in a deterministic format (counts + enemy ids)
  - reports “wave cleared” when all spawned enemies are dead
- `assets/scripts/serpent/enemy_spawner_adapter.lua` (runtime): spawns enemies from specs; supports burst-limiting (spawn rate cap) for perf

**Tests**
- `assets/scripts/serpent/tests/test_serpent_wave_director.lua`:
  - wave start and completion detection
  - gold reward emitted on wave completion
  - boss spawn spec present on waves 10 and 20

---

### Task 12 — Shop UI (View-Model + Render)
**Deliverables**
- `assets/scripts/serpent/ui/shop_ui.lua`:
  - pure-ish view-model helpers (slot labels, affordability, reroll label)
  - render uses existing UI primitives

**Tests**
- `assets/scripts/serpent/tests/test_shop_ui.lua`:
  - offerings slots count
  - affordability logic
  - reroll label reflects cost and count

**Manual**
- Buy/sell/reroll/ready works; gold updates; blocked actions show clear feedback.

---

### Task 13 — Synergy UI
**Deliverables**
- `assets/scripts/serpent/ui/synergy_ui.lua`

**Tests**
- `assets/scripts/serpent/tests/test_synergy_ui.lua`:
  - renders 4 classes
  - level display matches synergy_state input

---

### Task 14 — HUD (HP/Gold/Wave)
**Deliverables**
- `assets/scripts/serpent/ui/hud.lua`
  - HP shown as `sum(hp)/sum(hp_max)` across current segments

**Tests**
- `assets/scripts/serpent/tests/test_hud.lua`:
  - formatting helpers
  - update from injected state

---

### Task 15 — Bosses (Wave 10/20)
**Deliverables**
- `assets/scripts/serpent/bosses/swarm_queen.lua`
- `assets/scripts/serpent/bosses/lich_king.lua`
- Each boss exposes a pure tick function for tests:
  - `tick(state, dt) -> (state, events)` where events include spawn requests

**Tests**
- `assets/scripts/serpent/tests/test_bosses.lua`:
  - deterministic event emission given fixed dt/time
  - basic sanity: correct spawn cadence triggers at least once over a simulated window

**Manual**
- Boss mechanics visible and do not soft-lock the run.

---

### Task 16 — End Screens
**Deliverables**
- `assets/scripts/serpent/ui/game_over_screen.lua`
- `assets/scripts/serpent/ui/victory_screen.lua`
- Run stats tracked in `serpent_main.lua` (waves cleared, gold earned, units purchased)

**Tests**
- `assets/scripts/serpent/tests/test_screens.lua`:
  - required text labels present
  - buttons: retry, main menu

**Manual**
- Victory after clearing wave 20; game over at length 0; retry/menu performs full cleanup.

---

### Task 17 — Balance Pass (Manual, Timeboxed)
**Targets**
- Wave 1 clears in <30s typical play
- ~80 gold by wave 5 (order-of-magnitude sanity)
- Full run ~10–15 minutes typical play

**Artifact**
- `planning/serpent_balance_notes.md` summarizing any tuning changes (what/why).

---

### Task 18 — Final Verification (Manual + Perf)
**Checklist**
- Full run start → victory without errors.
- Enter/exit/re-enter SERPENT from main menu multiple times without duplication/leaks.
- Late waves: spawn limiting prevents obvious frame collapse (target <16ms typical on dev machine).

---

## Commit Strategy
- Commit after each task group when its tests (and required manual checks) pass.
- Before committing: run Serpent tests and repo-standard verification (UBS) per repo guardrails.

---