# Serpent — SNKRX-Style Survivor (Vertical Slice) Implementation Plan v5.0

## TL;DR
Add a new selectable game mode (**SERPENT**) where the player only steers a snake; each segment is an auto-attacking unit. Ship a complete run loop: **20 waves** with a **shop between waves**, **16 units**, **4 class synergies**, **6 implemented unit specials (others no-op)**, **2 bosses**, and **win/lose screens**, with deterministic RNG for all “random” outputs and unit tests for all pure-logic modules.

---

## Goals, Non‑Goals, Guardrails

### Goals (Must Have)
- New **SERPENT** mode selectable from main menu.
- Run loop: **Shop (wave 1) → Combat (wave 1) → Shop (wave 2) → … → Combat (wave 20) → Victory**.
- Snake length rules:
  - **Min 3**, **max 8** segments.
  - Purchase order defines segment order (**append to tail**).
  - Selling is blocked if it would reduce length below 3.
  - Combat deaths can reduce below 3; game over at 0.
- Real-time arena combat:
  - Units auto-attack with `atk_spd` (attacks/sec) and `range` (pixels).
  - Enemies deal contact damage with a fixed cooldown **per (enemy_id, instance_id) pair**.
- Shop between waves:
  - Buy, sell (**50% refund**, floor), reroll (**2g base, +1g per reroll within same shop phase**, resets each shop entry).
  - **5 shop slots** per shop phase.
- Unit leveling:
  - **3 copies** of same unit **at same level** → combine into next level (cap **level 3**).
  - Stat scaling (base-only): `HP = base_hp * 2^(level-1)`, `Attack = base_attack * 2^(level-1)`.
- Synergies at **2/4 thresholds** for Warrior/Mage/Ranger/Support.
- Bosses:
  - **Wave 10**: `swarm_queen`
  - **Wave 20**: `lich_king`
- HUD (HP, gold, wave, seed), synergy display, game over/victory screens.
- Deterministic run seed shown on HUD (for repro).

### Non‑Goals (Must NOT Have)
- No items, interest, meta-progression, save/load, difficulty modes, controller support.
- No manual repositioning within the snake.
- No enemy projectiles / ranged attacks in v-slice (enemy “Special” flags are ignored for all non-boss enemies).
- No enemy on-death effects (bosses are the only “special” behaviors).
- Placeholder visuals; use existing UI primitives/components.

### Guardrails
- No engine globals inside pure modules.
- All randomness must be injectable for deterministic tests.
- Keep Serpent-owned entities/timers/signals isolated and fully cleaned up on exit.
- Serpent runtime must not depend on `initMainGame()` / planning/action/shop phases.

---

## Engine Integration (Repo-Specific, Concrete)

### Game State Integration (`assets/scripts/core/main.lua`)
- Extend `GAMESTATE` to include `SERPENT = 2` (next unused numeric id).
- Extend `changeGameState(newState)` to support:
  - `GAMESTATE.SERPENT`: call `Serpent.init()`
  - Leaving `GAMESTATE.SERPENT`: call `Serpent.cleanup()` before switching
- In `main.update(dt)` (after the paused early-return), call:
  - `if currentGameState == GAMESTATE.SERPENT then Serpent.update(dt) end`

### Main Menu Button (Repo Uses `ui.main_menu_buttons`)
In `initMainMenu()` in `assets/scripts/core/main.lua`, add a new `MainMenuButtons.setButtons` entry:
- Label: `localization.get("ui.start_serpent_button")` (new localization key)
- `onClick`: `changeGameState(GAMESTATE.SERPENT)`

### Localization
Add keys to:
- `assets/localization/en_us.json`
- `assets/localization/ko_kr.json` (stub text acceptable for v-slice)
Minimum keys:
- `ui.start_serpent_button`
- `ui.serpent_ready`
- `ui.serpent_reroll`
- `ui.serpent_victory_title`
- `ui.serpent_game_over_title`
- `ui.serpent_retry`
- `ui.serpent_main_menu`

---

## Numeric Source of Truth (Embedded, Explicit)

### Units (16 total)
Costs are `tier_cost = { [1]=3, [2]=6, [3]=12, [4]=20 }` (gold, ints).

| id | class | tier | cost | base_hp | base_attack | range | atk_spd | special_id |
|---|---|---:|---:|---:|---:|---:|---:|---|
| soldier | Warrior | 1 | 3 | 100 | 15 | 50 | 1.0 | nil |
| apprentice | Mage | 1 | 3 | 60 | 10 | 200 | 0.8 | nil |
| scout | Ranger | 1 | 3 | 70 | 8 | 300 | 1.5 | nil |
| healer | Support | 1 | 3 | 80 | 5 | 100 | 0.5 | healer_adjacent_regen |
| knight | Warrior | 2 | 6 | 150 | 20 | 50 | 0.9 | knight_block |
| pyromancer | Mage | 2 | 6 | 70 | 18 | 180 | 0.7 | pyromancer_burn (no-op v-slice) |
| sniper | Ranger | 2 | 6 | 60 | 25 | 400 | 0.6 | sniper_crit |
| bard | Support | 2 | 6 | 90 | 8 | 80 | 0.8 | bard_adjacent_atkspd |
| berserker | Warrior | 3 | 12 | 120 | 35 | 60 | 1.2 | berserker_frenzy |
| archmage | Mage | 3 | 12 | 80 | 30 | 250 | 0.5 | archmage_multihit (no-op v-slice) |
| assassin | Ranger | 3 | 12 | 80 | 40 | 70 | 1.0 | assassin_backstab (no-op v-slice) |
| paladin | Support | 3 | 12 | 150 | 15 | 60 | 0.7 | paladin_divine_shield |
| champion | Warrior | 4 | 20 | 200 | 50 | 80 | 0.8 | champion_cleave (no-op v-slice) |
| lich | Mage | 4 | 20 | 100 | 45 | 300 | 0.4 | lich_pierce (no-op v-slice) |
| windrunner | Ranger | 4 | 20 | 100 | 35 | 350 | 1.1 | windrunner_multishot (no-op v-slice) |
| angel | Support | 4 | 20 | 120 | 20 | 100 | 0.6 | angel_resurrect (no-op v-slice) |

### Enemies (11 total)
Non-boss enemy “Special” column is ignored in v-slice; all enemies are contact-damage-only.

| id | base_hp | base_damage | speed | boss | min_wave | max_wave |
|---|---:|---:|---:|---:|---:|---:|
| slime | 20 | 5 | 80 | false | 1 | 5 |
| bat | 15 | 8 | 200 | false | 1 | 10 |
| goblin | 30 | 10 | 120 | false | 3 | 10 |
| orc | 50 | 15 | 120 | false | 5 | 15 |
| skeleton | 40 | 12 | 120 | false | 5 | 15 |
| wizard | 35 | 20 | 100 | false | 8 | 20 |
| troll | 100 | 25 | 80 | false | 10 | 20 |
| demon | 80 | 30 | 140 | false | 12 | 20 |
| dragon | 200 | 40 | 60 | false | 15 | 20 |
| swarm_queen | 500 | 50 | 50 | true | 10 | 10 |
| lich_king | 800 | 75 | 100 | true | 20 | 20 |

### Synergy Bonuses
| Class | 2-Unit | 4-Unit |
|---|---:|---:|
| Warrior | +20% attack damage | +40% attack damage, +20% HP |
| Mage | +20% spell damage | +40% spell damage, -20% cooldown |
| Ranger | +20% attack speed | +40% attack speed, +20% range |
| Support | Heal snake 5 HP/sec | Heal snake 10 HP/sec, +10% all stats |

Notes:
- Store multipliers as fractions (e.g., `0.20`).
- Support synergy heal is **global** (not targeted); deterministic distribution specified below.

### Wave Scaling
```lua
Enemies_per_Wave = 5 + Wave * 2
Enemy_HP_Multiplier = 1 + Wave * 0.1
Enemy_Damage_Multiplier = 1 + Wave * 0.05
Gold_per_Wave = 10 + Wave * 2
```

### Shop Tier Odds
| Wave | Tier 1 | Tier 2 | Tier 3 | Tier 4 |
|---|---:|---:|---:|---:|
| 1-5 | 70% | 25% | 5% | 0% |
| 6-10 | 55% | 30% | 13% | 2% |
| 11-15 | 35% | 35% | 22% | 8% |
| 16-20 | 20% | 30% | 33% | 17% |

### Arena + Movement Tuning (v-slice constants)
```lua
local MOVEMENT_CONFIG = {
  MAX_SPEED = 180,        -- px/sec (head)
  SEGMENT_SPACING = 40,   -- px between segment centers
  ARENA_WIDTH = 800,
  ARENA_HEIGHT = 600,
  ARENA_PADDING = 50,
}
```

### Combat Constants (v-slice)
- Contact damage cooldown: `CONTACT_DAMAGE_COOLDOWN_SEC = 0.5`
- HP/damage rounding: all HP and damage are integers; apply modifiers in float then `math.floor(final + 0.00001)`.

---

## Deterministic RNG (Hard Requirement)

### RNG Interface
All randomness goes through injected `rng`:
- `rng:int(min, max)` inclusive
- `rng:float()` in `[0,1)`
- `rng:choice(list)` (optional helper; deterministic via `int`)

### Implementation
Provide `assets/scripts/serpent/rng.lua`:
- A local PRNG (xorshift/LCG) that does **not** touch global `math.randomseed`.
- `rng = RNG.new(seed)`; seed stored/shown on HUD.
- Tests use `RNG.new(12345)` or a stub sequence RNG.

---

## Implementation Contracts (Make Ambiguity Impossible)

### Core Mode State Machine (`assets/scripts/serpent/serpent_main.lua`)
Own a state machine:
- Initial: `MODE_STATE.SHOP` with `wave = 1`, `gold = STARTING_GOLD`, `seed = STARTING_SEED`
- `SHOP` → `COMBAT` when player presses “Ready”
- `COMBAT` → `SHOP` when wave director reports “wave cleared” and `wave < 20`
  - Transition order:
    1) `gold += Gold_per_Wave(wave)`
    2) `wave += 1`
    3) `enter_shop(upcoming_wave=wave, gold, rng)`
- `COMBAT` → `VICTORY` when wave 20 cleared
- Any state → `GAME_OVER` when snake length reaches 0

Constants:
- `STARTING_GOLD = 10`
- `STARTING_SEED = tonumber(os.getenv("SERPENT_SEED") or "") or 12345`
- Starting snake (head→tail): `soldier`, `apprentice`, `scout` (all level 1)
- HP persists across waves; combine (shop-only) sets combined unit to full HP.

### Canonical Data Shapes (Pure Logic)
All pure modules accept/return plain Lua tables.

**UnitDef** (`assets/scripts/serpent/data/units.lua`)
- `id` (string), `class` (`"Warrior"|"Mage"|"Ranger"|"Support"`), `tier` (1..4), `cost` (int)
- `base_hp`, `base_attack` (ints), `range`, `atk_spd` (numbers)
- `special_id` (string or nil)

**EnemyDef** (`assets/scripts/serpent/data/enemies.lua`)
- `id` (string), `base_hp`, `base_damage` (ints), `speed` (number)
- `min_wave`, `max_wave` (ints)
- `tags` (table; e.g., `{ boss=true }`)

**IdState**
- `next_instance_id` (int, starts at 1)
- `next_acquired_seq` (int, starts at 1)
- `next_enemy_id` (int, starts at 1)

**UnitInstance** (stores base-scaled stats only; buffs are applied as multipliers at tick-time)
- `instance_id` (int)
- `def_id` (string), `level` (1..3)
- `hp`, `hp_max_base`, `attack_base` (ints)
- `range_base`, `atk_spd_base` (numbers)
- `cooldown` (seconds until next attack, `>= 0`)
- `acquired_seq` (int)
- `special_state` (table; persistent per-run state)

**SnakeState**
- `segments` = array of `UnitInstance` in head→tail order
- `min_len=3`, `max_len=8`

**EnemySnapshot** (pure-facing “model”; runtime mirrors it)
- `enemy_id` (int), `def_id` (string)
- `hp`, `hp_max`, `damage` (ints), `speed` (number)
- `x`, `y` (numbers)
- `tags` (table)

### Runtime ↔ Pure Boundary (Snapshots + Events)

**SegmentSnapshot**
- `instance_id`, `def_id`, `class`
- `hp`, `hp_max`, `attack`, `range`, `atk_spd`, `cooldown`
- `x`, `y`

**ContactSnapshot**
- Array of `{ enemy_id, instance_id }` for pairs currently overlapping this frame.

**Runtime ID mapping (required)**
Runtime maintains:
- `enemy_id -> enemy_entity_id`
- `instance_id -> segment_entity_id`

**Event shapes (pure outputs)**
- `AttackEvent`: `{ kind="attack", attacker_instance_id, target_enemy_id, base_damage_int }`
- `DamageEventEnemy`: `{ kind="damage_enemy", target_enemy_id, amount_int, source_instance_id }`
- `DamageEventUnit`: `{ kind="damage_unit", target_instance_id, amount_int, source_enemy_id }`
- `HealEventUnit`: `{ kind="heal_unit", target_instance_id, amount_int }`
- `DeathEventEnemy`: `{ kind="enemy_dead", enemy_id, killer_instance_id }`
- `DeathEventUnit`: `{ kind="unit_dead", instance_id }`
- `SpawnRequestEvent`: `{ kind="spawn_request", def_id, count, spawn_rule }`

**Spawn rule (deterministic)**
`spawn_rule = { mode="edge_random", arena={ w, h, padding } }`
Algorithm (exact):
- Choose edge index `e = rng:int(1,4)` mapping to `left,right,top,bottom`
- Choose coordinate along edge `t = rng:float()`
- Compute `(x,y)` inside arena bounds with padding:
  - left: `x = padding`, `y = padding + t*(h-2*padding)` (etc.)
- Spawn positions must be identical for same seed/run.

### Collision Collection (Runtime, deterministic)
- Use `local world = PhysicsManager.get_world("world")`
- Register physics pair callbacks on the active world:
  - `physics.on_pair_begin(world, C.CollisionTags.SERPENT_SEGMENT, C.CollisionTags.ENEMY, cb)`
  - `physics.on_pair_end(world, C.CollisionTags.SERPENT_SEGMENT, C.CollisionTags.ENEMY, cb)`
- Maintain an overlap set keyed by `(enemy_id, instance_id)`; each update builds `ContactSnapshot` by iterating the set in sorted order:
  - Sort by `(enemy_id, instance_id)`.

### Combat Tick Simulation Order (Pure)
Per `combat_logic.tick(dt, ...)`:
1. Decrement unit `cooldown` by `dt` (allow negative; do not clamp yet).
2. Compute synergy state + passive specials mods for this tick (multipliers only; no mutation of base stats).
3. Produce healing events:
   - Global regen sources (Support synergy) via global regen accumulator contract.
   - Targeted heal sources (Healer adjacent regen) via targeted accumulator contract.
4. Produce attack events from `auto_attack_logic` using `SegmentSnapshot` / `EnemySnapshot`.
   - Cooldown cadence: for each segment, `period = 1/atk_spd`.
   - While `cooldown <= 0` and target exists: emit attack, `cooldown += period`.
   - If no target exists: set `cooldown = math.max(cooldown, 0)` and stop.
5. Apply damage modifiers (synergy + specials like crit), emit `damage_enemy`.
6. Apply enemy damage, emit `enemy_dead` for `hp <= 0` with `killer_instance_id`.
7. Consume `ContactSnapshot` and apply contact cooldown gating per (enemy_id, instance_id), emit `damage_unit`.
8. Apply unit damage, emit `unit_dead` for `hp <= 0`.
9. Feed events into specials/boss logic:
   - `enemy_dead` → berserker stacks / lich king raise scheduling
   - `wave_start` → paladin shield reset

### Combine + Ordering Rules (Deterministic, Chain-Safe)
- Buying appends a new level-1 instance to the tail **before** combine checks.
- Combine detection and application repeats until no more combines are possible:
  - For each pass:
    1) Build eligible groups by `(def_id, level)`.
    2) Process `def_id` in ascending string order, and within each def process `level=1` then `level=2`.
    3) If a `(def_id, level)` has 3+ instances, combine exactly one triple using the 3 lowest `acquired_seq`.
    4) Restart the pass (so level-up can create new triples deterministically).
- Combine result:
  - Replace the earliest (lowest `acquired_seq`) of the triple with an upgraded instance (`level+1`).
  - Remove the other 2 instances from the snake.
  - Upgraded instance keeps `acquired_seq` and `instance_id` of the kept instance.
  - Upgraded instance sets `hp = hp_max_base` (full heal) on combine (shop-only operation).

**Purchase at max length**
- Allowed only if `(append + all resulting combine passes)` ends with length `<= max_len`; otherwise reject (no gold spent).

### Gold + Rounding Rules
- Costs are integers.
- Sell refund is `math.floor(total_paid_for_instance * 0.5)`.
- `total_paid_for_instance = unit_def.cost * (3^(level-1))`.

### Synergy Rules (Exact)
Synergy derived from current snake segments (post-combine):
- Warrior: attack multiplier to **Warrior** only; at 4 also HP multiplier to **Warrior** only.
- Mage: treat “spell damage” as attack multiplier to **Mage** only; at 4 apply cooldown reduction by multiplying attack period by `0.8` (equivalently `atk_spd *= 1/0.8`).
- Ranger: atk_spd and range multipliers to **Ranger** only.
- Support:
  - global regen applies to whole snake per Global Regen contract.
  - at 4: `all_stats_mult=1.10` applies to all units’ `hp_max`, `attack`, `range`, `atk_spd`.

**Effective stat recompute (no drift)**
- Always recompute `hp_max`, `attack`, `range`, `atk_spd` from base-scaled values (`*_base`) times multipliers for the current tick.
- When effective `hp_max` decreases, clamp `hp = min(hp, hp_max)`.
- When effective `atk_spd` increases, keep `cooldown` in seconds and clamp to `<= period` only if `cooldown > period` (do not clamp negative; negative is used to allow multi-attacks).

### Specials (v-slice implemented; others no-op)
Implemented (pure):
- `healer_adjacent_regen`: heals adjacent segments `10 HP/sec` each (targeted)
- `knight_block`: this segment takes `20%` less incoming damage (multiplicative)
- `sniper_crit`: `20%` chance to deal `2x` damage (roll per attack via injected RNG)
- `bard_adjacent_atkspd`: adjacent segments gain `+10% atk_spd` (multiplicative)
- `berserker_frenzy`: per credited kill, gain `+5% attack` (stacking; persists within run)
- `paladin_divine_shield`: once per wave, first **nonzero** incoming hit becomes `0` (resets on wave start)

Adjacency is by snake order; head/tail only have one neighbor.

### Healing Contracts (Deterministic, integer HP)

**Global Regen (Support synergy only)**
- Stored in `combat_state.global_regen_accum` (float) and `combat_state.global_regen_cursor` (int index into snake order).
- Per tick:
  - `global_regen_accum += global_regen_per_sec * dt`
  - While `global_regen_accum >= 1`:
    - Find next living segment starting at `global_regen_cursor`, wrap head→tail (skip dead), update cursor after heal.
    - Emit `HealEventUnit{amount_int=1}` for that segment.
    - `global_regen_accum -= 1`

**Targeted Regen (Healer special)**
- Stored per-healer in `unit.special_state`:
  - `heal_left_accum`, `heal_right_accum` (floats, default 0)
- Per tick, for each healer instance:
  - If left neighbor exists and alive: `heal_left_accum += 10 * dt`; while `>= 1` emit 1 HP heal to left, subtract 1.
  - Same for right neighbor.
- Targeted heals do **not** use global cursor/distribution.

---

## Directory Layout
All Serpent code under `assets/scripts/serpent/`:
- `serpent_main.lua`
- `rng.lua`
- Data: `data/units.lua`, `data/enemies.lua`, `data/shop_odds.lua`
- Pure logic:
  - `snake_logic.lua`
  - `unit_factory.lua`
  - `combine_logic.lua`
  - `synergy_system.lua`
  - `specials_system.lua`
  - `serpent_shop.lua`
  - `wave_config.lua`
  - `auto_attack_logic.lua`
  - `serpent_wave_director.lua`
  - `combat_logic.lua`
- Runtime:
  - `snake_entity_adapter.lua`, `snake_controller.lua`
  - `enemy_entity_adapter.lua`, `enemy_controller.lua`
  - `contact_collector.lua`
  - `enemy_spawner_adapter.lua`
  - `combat_adapter.lua`
- UI:
  - `ui/hud.lua`, `ui/shop_ui.lua`, `ui/synergy_ui.lua`
  - `ui/game_over_screen.lua`, `ui/victory_screen.lua`
- Bosses (pure helpers owned by wave director/combat tick):
  - `bosses/swarm_queen.lua`, `bosses/lich_king.lua`
- Tests:
  - `tests/test_*.lua` (pure logic + view-model helpers only)

---

## Testing Standard

### Test Header (Required)
```lua
package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"
local t = require("tests.test_runner")
```

### How to Run
```bash
lua assets/scripts/tests/test_runner.lua assets/scripts/serpent/tests/
```

### Testability Rule
- Pure modules: unit tests required.
- UI: tests cover view-model/pure helpers only.
- Runtime adapters/controllers: validated via manual checklist + minimal “smoke require” tests.

---

## Execution Strategy (Parallelizable With Dependencies)

### Parallel Work Packs
- Pack A: RNG + data tables + tests
- Pack B: Pure core (snake/unit factory/combines) + tests
- Pack C: Pure combat (synergy/specials/auto-attack/combat logic) + tests
- Pack D: Pure waves/shop (odds/wave config/wave director/shop) + tests
- Pack E: Runtime core (mode skeleton, collisions/contact collector, spawner, enemy + snake controllers)
- Pack F: UI (shop/synergy/hud/screens) after view-model inputs exist
- Pack G: Bosses (pure boss timers + wave director integration)

Dependency notes:
- C depends on A+B.
- D depends on A (enemy defs + odds) and C (combat events feeding boss/special rules).
- E depends on B/C/D for meaningful integration.
- F depends on B/C/D outputs.
- G depends on D (director) and C (events/time), and E (spawner path).

---

## Tasks (Checklist + Acceptance Criteria)

### Task 1 — Mode Skeleton + Core Integration (Repo-Specific)
**Deliverables**
- `assets/scripts/serpent/serpent_main.lua` with `init()`, `update(dt)`, `cleanup()`
- Minimal integration edits in `assets/scripts/core/main.lua`:
  - add `GAMESTATE.SERPENT = 2`
  - `changeGameState` supports SERPENT and calls cleanup on exit
  - `main.update(dt)` calls `Serpent.update(dt)` when SERPENT
  - main menu adds Serpent button via `MainMenuButtons.setButtons`
- Serpent-owned timer group name: `SERPENT_TIMER_GROUP = "serpent"`; cleanup calls `timer.clear_group("serpent")` (or equivalent) and unregisters physics callbacks.

**Acceptance**
- `lua -e "package.path=package.path..';./assets/scripts/?.lua;./assets/scripts/?/init.lua'; require('serpent.serpent_main')"` succeeds.
- Enter SERPENT from main menu without errors.
- Exit to main menu and re-enter SERPENT without duplicate timers/callbacks/entities (manual).

---

### Task 2 — RNG Utility (Deterministic, No Global Random)
**Deliverables**
- `assets/scripts/serpent/rng.lua` implementing `new(seed)`, `int`, `float`, optional `choice`

**Tests**
- `assets/scripts/serpent/tests/test_rng.lua`:
  - same seed yields identical sequences
  - different seeds diverge
  - `int(min,max)` is inclusive and stable

---

### Task 3 — Unit Data (16) + Shop Odds Data (Verified Values)
**Deliverables**
- `assets/scripts/serpent/data/units.lua` exactly matches the Units table in this plan (including `special_id` strings/nil).
- `assets/scripts/serpent/data/shop_odds.lua` implements odds table (1-5, 6-10, 11-15, 16-20).

**Tests**
- `assets/scripts/serpent/tests/test_units.lua`:
  - exactly 16 entries; 4 per class
  - IDs match expected set
  - all numeric fields match expected values (table-driven)
  - `special_id` matches expected (including no-op ids)
- `assets/scripts/serpent/tests/test_shop_odds.lua`:
  - correct odds per wave bracket; probabilities sum to 1.0

---

### Task 4 — Enemy Data (11) (Verified Values)
**Deliverables**
- `assets/scripts/serpent/data/enemies.lua` exactly matches the Enemies table in this plan (including wave ranges + boss tags).

**Tests**
- `assets/scripts/serpent/tests/test_enemies.lua`:
  - exactly 11 entries
  - expected IDs present (including `swarm_queen`, `lich_king`)
  - per-enemy numeric fields match expected values (table-driven)
  - wave ranges validated (min<=max; bosses exact wave)

---

### Task 5 — Snake Core Logic (Pure)
**Deliverables**
- `assets/scripts/serpent/snake_logic.lua`:
  - `create_initial(unit_defs, min_len, max_len, id_state) -> (SnakeState, id_state)`
  - `can_sell(snake_state, instance_id) -> bool`
  - `remove_instance(snake_state, instance_id) -> SnakeState`
  - `is_dead(snake_state) -> bool`

**Tests**
- `assets/scripts/serpent/tests/test_snake_logic.lua`:
  - selling blocked if it would drop below 3
  - removal via death can drop below 3
  - length 0 marks dead
  - `create_initial` emits 3 starting instances with monotonic ids/seq

---

### Task 6 — Unit Factory + Combine Rules (Pure)
**Deliverables**
- `assets/scripts/serpent/unit_factory.lua`:
  - `create_instance(unit_def, instance_id, acquired_seq) -> UnitInstance(level=1, base stats set)`
  - `apply_level_scaling(unit_def, level) -> { hp_max_base_int, attack_base_int }`
- `assets/scripts/serpent/combine_logic.lua`:
  - `apply_combines_until_stable(snake_state, unit_defs) -> (snake_state, combine_events)`
  - combine event includes `{ kept_instance_id, removed_instance_ids[], new_level }`

**Tests**
- `assets/scripts/serpent/tests/test_unit_factory.lua`:
  - stat scaling matches `base * 2^(level-1)` and caps at 3
- `assets/scripts/serpent/tests/test_combines.lua`:
  - combine chooses lowest `acquired_seq` triple
  - chaining combine works deterministically
  - kept slot preserved; other 2 removed
  - upgraded instance full-heals (`hp == hp_max_base`)
  - max-length purchase gating helper scenarios

---

### Task 7 — Synergy System (Pure)
**Deliverables**
- `assets/scripts/serpent/synergy_system.lua`:
  - `calculate(segments, unit_defs) -> synergy_state`
  - `get_effective_multipliers(synergy_state, segments) -> by_instance_id`
  - multipliers include: `hp_mult`, `atk_mult`, `range_mult`, `atk_spd_mult`, `cooldown_period_mult`

**Tests**
- `assets/scripts/serpent/tests/test_synergy_system.lua`:
  - thresholds at 2/4
  - modifier values match table
  - mage cooldown rule equals `cooldown_period_mult = 0.8` at 4-units

---

### Task 8 — Specials System (Pure)
**Deliverables**
- `assets/scripts/serpent/specials_system.lua` implementing:
  - `get_passive_mods(ctx) -> mods_by_instance_id`
  - `tick(dt, ctx, rng) -> events[]`
  - `on_attack(ctx, attack_event, rng) -> (possibly_modified_attack_event, extra_events[])`
  - `on_damage_taken(ctx, damage_unit_event) -> (modified_damage_unit_event, extra_events[])`
  - `on_enemy_death(ctx, death_enemy_event) -> extra_events[]`
  - `on_wave_start(ctx)`

Ctx includes: `snake_state`, `unit_defs`, `wave_num`, `now_sec` (monotonic combat time).

**Tests**
- `assets/scripts/serpent/tests/test_specials.lua`:
  - healer targeted heals adjacent correctly (does not use global distribution)
  - knight reduces damage by 20% with correct floor rounding
  - sniper crit deterministic with seeded RNG
  - bard buffs adjacent atk_spd multiplicatively
  - berserker stacks +5% attack per credited kill
  - paladin negates first nonzero hit per wave and resets on wave start

---

### Task 9 — Wave Config (20) (Pure)
**Deliverables**
- `assets/scripts/serpent/wave_config.lua`:
  - `enemy_count(wave)`, `hp_mult(wave)`, `dmg_mult(wave)`, `gold_reward(wave)`
  - `get_pool(wave_num, enemy_defs) -> enemy_def_ids[]`:
    - includes all non-boss enemies whose `min_wave <= wave_num <= max_wave`
    - excludes boss ids (bosses injected by wave director only)

**Tests**
- `assets/scripts/serpent/tests/test_wave_config.lua`:
  - waves 1..20 valid
  - formulas match “Numeric Source of Truth”
  - pool matches expected membership derived from wave ranges (table-driven per wave bracket)

---

### Task 10 — Shop System (Pure)
**Deliverables**
- `assets/scripts/serpent/serpent_shop.lua`:
  - `enter_shop(upcoming_wave, gold, rng) -> shop_state`
  - `reroll(shop_state, rng) -> (shop_state, gold_delta_int)`
  - `can_buy(...) -> bool`
  - `buy(...) -> (shop_state, snake_state, gold, id_state, events[])`
  - `sell(...) -> (snake_state, gold)`
- Offer rules:
  - `SHOP_SLOTS = 5`
  - Choose tier by odds table for `upcoming_wave`, then choose uniformly among units of that tier.
  - Duplicates allowed.

**Tests**
- `assets/scripts/serpent/tests/test_serpent_shop.lua`:
  - 5 offers
  - reroll cost increments (2,3,4,…) and resets each `enter_shop`
  - gold accounting and floor rounding
  - purchase rejection at max length without combines; acceptance when combines reduce length
  - sell refund equals `floor(cost * 3^(level-1) * 0.5)`

---

### Task 11 — Auto-Attack Logic (Pure)
**Deliverables**
- `assets/scripts/serpent/auto_attack_logic.lua`:
  - `tick(dt, segment_snaps, enemy_snaps) -> (updated_cooldowns_by_instance_id, attack_events[])`
  - target selection:
    - nearest target with `distance <= range`
    - tie-break: lowest `enemy_id`
  - cadence:
    - allow multiple attacks per tick using `while cooldown <= 0`

**Tests**
- `assets/scripts/serpent/tests/test_auto_attack_logic.lua`:
  - multi-attack behavior when `dt > period`
  - nearest selection + tie-break
  - out-of-range yields no attacks

---

### Task 12 — Combat Logic (Pure)
**Deliverables**
- `assets/scripts/serpent/combat_logic.lua`:
  - `init_state(snake_state, wave_num) -> combat_state`:
    - `global_regen_accum`, `global_regen_cursor`
    - `contact_cooldowns` map
    - `combat_time_sec`
  - `tick(dt, snake_state, segment_snaps, enemy_snaps, contact_snaps, unit_defs, enemy_defs, combat_state, rng) -> (snake_state, enemy_snaps, combat_state, events[])`
  - applies:
    - synergy + specials exactly once per tick
    - contact cooldown `0.5s` per (enemy_id, instance_id)
    - global regen distribution and targeted healer regen
    - death events with killer credit

**Tests**
- `assets/scripts/serpent/tests/test_combat_logic.lua`:
  - class multipliers apply to correct classes
  - global regen distribution deterministic and clamps to hp_max
  - targeted healer regen deterministic and adjacency-correct
  - contact damage cooldown gating over multiple ticks
  - death events emitted at hp <= 0
  - berserker kill credit increments stacks deterministically

---

### Task 13 — Wave Director (Pure)
**Deliverables**
- `assets/scripts/serpent/serpent_wave_director.lua`:
  - tracks current wave, active enemy set, and “wave cleared”
  - on wave start emits `SpawnRequestEvent` list for regular enemies + boss injection
  - boss injection:
    - wave 10 includes `swarm_queen`
    - wave 20 includes `lich_king`
  - exposes:
    - `start_wave(wave_num, rng) -> spawn_requests[]`
    - `on_enemy_dead(enemy_id) -> nil`
    - `is_wave_cleared() -> bool`

**Tests**
- `assets/scripts/serpent/tests/test_serpent_wave_director.lua`:
  - wave start/completion detection
  - boss waves inject correct boss ids
  - regular pool excludes bosses

---

### Task 14 — Runtime Physics + Collision Tag Wiring (Required for Contact Damage)
**Deliverables**
- `assets/scripts/core/constants.lua`: add `CollisionTags.SERPENT_SEGMENT = "serpent_segment"`
- `assets/scripts/serpent/contact_collector.lua`:
  - installs/removes physics pair begin/end callbacks (world = `PhysicsManager.get_world("world")`)
  - maintains overlap set → sorted `ContactSnapshot`
- `serpent_main.lua`:
  - ensures `world:AddCollisionTag(C.CollisionTags.SERPENT_SEGMENT)` (idempotent best-effort)
  - enables collisions between `SERPENT_SEGMENT` and `ENEMY` via `physics.enable_collision_between_many` + `physics.update_collision_masks_for`
  - cleanup unregisters callbacks and clears overlap set

**Manual Acceptance**
- Overlap tracking works across begin/end; snapshot ordering stable.
- No callbacks remain after exiting Serpent (no double damage on re-enter).

---

### Task 15 — Runtime Entities + Controllers (Snake + Enemies)
**Deliverables**
- `assets/scripts/serpent/snake_entity_adapter.lua`:
  - spawns segment entities tagged `SERPENT_SEGMENT` with physics bodies
  - maintains `instance_id -> entity_id` mapping
  - emits `SegmentSnapshot` with `physics.GetPosition`
- `assets/scripts/serpent/snake_controller.lua`:
  - head steering via WASD/arrows
  - updates head position/velocity (use `physics.SetVelocity` and clamp to arena via `physics.SetPosition`)
  - tail follows by enforcing `SEGMENT_SPACING` using position constraints in snake order (deterministic)
- `assets/scripts/serpent/enemy_entity_adapter.lua` + `enemy_controller.lua`:
  - spawns enemy entities tagged `ENEMY` and ensures they collide with `SERPENT_SEGMENT`
  - maintains `enemy_id -> entity_id` mapping
  - enemy movement: move toward head position at `enemy_snapshot.speed` using `physics.SetVelocity`

**Manual Acceptance**
- Snake spawns with starting units in correct order.
- Movement stable (no runaway drift); head stays within arena bounds.
- Enemies reliably approach snake (not dependent on PLAYER systems).

---

### Task 16 — Runtime Spawner + Combat Adapter
**Deliverables**
- `assets/scripts/serpent/enemy_spawner_adapter.lua`:
  - consumes `SpawnRequestEvent`
  - computes deterministic spawn positions via RNG + spawn rule
  - spawns enemies and returns `EnemySnapshot` list with assigned `enemy_id`
  - burst limiting constants:
    - `MAX_SPAWNS_PER_SEC = 10`
    - `MAX_SPAWNS_PER_FRAME = 3`
- `assets/scripts/serpent/combat_adapter.lua`:
  - applies `damage_enemy`/`enemy_dead` to runtime entities and snapshots
  - applies `damage_unit`/`unit_dead` to runtime segments and snake state
  - despawns runtime entities on death

**Manual Acceptance**
- Enemy touching a segment deals damage once per 0.5s while overlapping.
- Segment death removes entity immediately; chain closes.
- Enemy death despawns cleanly and decrements active enemy count for wave clear.
- Late waves: burst limiting prevents spawn spikes from freezing the frame.

---

### Task 17 — UI (Shop + Synergy + HUD)
**Deliverables**
- `assets/scripts/serpent/ui/shop_ui.lua`:
  - view-model helpers: slot labels, affordability, reroll label, sell enable/disable, ready enable
  - interactions: buy/reroll/sell/ready
- `assets/scripts/serpent/ui/synergy_ui.lua`
- `assets/scripts/serpent/ui/hud.lua`:
  - HP as `sum(hp)/sum(hp_max)` across segments
  - gold, wave, seed

**Tests**
- `assets/scripts/serpent/tests/test_shop_ui.lua` (view-model only)
- `assets/scripts/serpent/tests/test_synergy_ui.lua` (view-model only)
- `assets/scripts/serpent/tests/test_hud.lua` (formatting + aggregation helpers)

---

### Task 18 — Bosses (Wave 10/20) + Integration (Pure)
**Deliverables**
- `assets/scripts/serpent/bosses/swarm_queen.lua`
  - `init(enemy_id) -> boss_state`
  - `tick(dt, boss_state, is_alive, rng) -> (boss_state, spawn_events[])`
  - cadence: spawns `5` `slime` every `10.0s` while alive
- `assets/scripts/serpent/bosses/lich_king.lua`
  - `init(enemy_id) -> boss_state`
  - `on_enemy_dead(boss_state, dead_enemy_def_id, dead_enemy_tags) -> boss_state`
  - `tick(dt, boss_state, is_alive) -> (boss_state, spawn_events[])`
  - whenever any non-boss enemy dies, queue 1 `skeleton` spawn after `2.0s`
- Wire boss events into combat tick / wave director → spawner path.

**Tests**
- `assets/scripts/serpent/tests/test_bosses.lua`:
  - deterministic spawn cadence under simulated time steps
  - deterministic delayed raise behavior

---

### Task 19 — End Screens + Final Verification
**Deliverables**
- `assets/scripts/serpent/ui/game_over_screen.lua`
- `assets/scripts/serpent/ui/victory_screen.lua`
- Run stats tracked in `serpent_main.lua` (waves cleared, gold earned, units purchased)

**Tests**
- `assets/scripts/serpent/tests/test_screens.lua`:
  - required labels present in view-model
  - buttons: retry, main menu

**Manual Checklist**
- Full run start → victory without errors.
- Game over triggers at length 0 from combat deaths.
- Retry/menu performs full cleanup; re-entering SERPENT does not duplicate entities/handlers.
- Burst limiting active on late waves.

---

## Commit Strategy
- Commit after each task group when its tests (and required manual checks) pass.
- Before committing: run `lua assets/scripts/tests/test_runner.lua assets/scripts/serpent/tests/` and repo-standard verification (UBS).