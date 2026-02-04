# Serpent — SNKRX-Style Survivor (Vertical Slice) Implementation Plan v4.0

## TL;DR
Add a new selectable game mode (**SERPENT**) where the player only steers a snake; each segment is an auto-attacking unit. Ship a complete run loop: **20 waves** with a **shop between waves**, **16 units**, **4 class synergies**, **6 unit specials**, **2 bosses**, and **win/lose screens**, with deterministic RNG for all “random” outputs and unit tests for all pure-logic modules.

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
  - Enemies deal contact damage with a fixed cooldown.
- Shop between waves:
  - Buy, sell (**50% refund**, floor), reroll (**2g base, +1g per reroll within same shop phase**, resets each shop entry).
  - **5 shop slots** per shop phase.
- Unit leveling:
  - **3 copies** of same unit **at same level** → combine into next level (cap **level 3**).
  - Stat scaling: `HP = base_hp * 2^(level-1)`, `Attack = base_attack * 2^(level-1)`.
- Synergies at **2/4 thresholds** for Warrior/Mage/Ranger/Support.
- Bosses:
  - **Wave 10**: `swarm_queen`
  - **Wave 20**: `lich_king`
- HUD (HP, gold, wave), synergy display, game over/victory screens.
- Deterministic run seed shown on HUD (for repro).

### Non‑Goals (Must NOT Have)
- No items, interest, meta-progression, save/load, difficulty modes, controller support.
- No manual repositioning within the snake.
- No ranged enemy attacks, no enemy projectiles, no enemy on-death effects (bosses are the only “special” behaviors).
- Placeholder visuals; use existing UI primitives/components.

### Guardrails
- No engine globals inside pure modules.
- All randomness must be injectable for deterministic tests.
- Keep Serpent-owned entities/timers/signals isolated and fully cleaned up on exit.
- Serpent runtime must not depend on `initMainGame()` / planning/action/shop phases.

---

## Engine Integration (Repo-Specific, Concrete)

### Game State Integration (`assets/scripts/core/main.lua`)
- Extend `GAMESTATE` to include `SERPENT = 2`.
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

## Numeric Source of Truth (Explicit)

### Units / Enemies Base Stats
- Serpent-specific unit/enemy base stat tables mirror `planning/PLAN_v0.md` exactly.
- Tests must validate **IDs and per-field numbers** (not just counts).

### Synergy Bonuses
| Class | 2-Unit | 4-Unit |
|---|---:|---:|
| Warrior | +20% attack damage | +40% attack damage, +20% HP |
| Mage | +20% spell damage | +40% spell damage, -20% cooldown |
| Ranger | +20% attack speed | +40% attack speed, +20% range |
| Support | Heal snake 5 HP/sec | Heal snake 10 HP/sec, +10% all stats |

Notes:
- Store multipliers as fractions (e.g., `0.20`).
- Support synergy heal is **total heal per second across the whole snake**, distributed deterministically across living segments (see Regen contract).

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
- Damage/HP rounding: all HP and damage are integers; apply modifiers in float then `math.floor(final + 0.00001)`.

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
- `STARTING_SEED = 12345` (override via env if desired: `SERPENT_SEED`)
- Starting snake (head→tail): `soldier`, `apprentice`, `scout` (all level 1)
- HP persists across waves (no refill); only regen/specials heal during combat.

### Canonical Data Shapes (Pure Logic)
All pure modules accept/return plain Lua tables.

**UnitDef** (`assets/scripts/serpent/data/units.lua`)
- `id` (string), `class` (`"Warrior"|"Mage"|"Ranger"|"Support"`), `tier` (1..4), `cost` (int)
- `base_hp`, `base_attack`, `range`, `atk_spd` (numbers)
- `special_id` (string or nil)

**EnemyDef** (`assets/scripts/serpent/data/enemies.lua`)
- `id` (string), `tier` (1..4 or nil), `base_hp`, `base_damage`, `speed` (numbers)
- `tags` (table; e.g., `{ boss=true }`)

**IdState**
- `next_instance_id` (int, starts at 1)
- `next_acquired_seq` (int, starts at 1)
- `next_enemy_id` (int, starts at 1)

**UnitInstance**
- `instance_id` (int)
- `def_id` (string), `level` (1..3)
- `hp`, `hp_max`, `attack` (ints)
- `range`, `atk_spd` (numbers)
- `cooldown` (seconds until next attack, `>= 0`)
- `acquired_seq` (int)
- `special_state` (table; persistent per-run state)

**SnakeState**
- `segments` = array of `UnitInstance` in head→tail order
- `min_len=3`, `max_len=8`

**EnemySnapshot** (pure-facing)
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
In Serpent init:
- Register physics pair callbacks on the active world:
  - `physics.on_pair_begin(world, C.CollisionTags.SERPENT_SEGMENT, C.CollisionTags.ENEMY, cb)`
  - `physics.on_pair_end(world, C.CollisionTags.SERPENT_SEGMENT, C.CollisionTags.ENEMY, cb)`
- Maintain an overlap set keyed by `(enemy_id, instance_id)`; each update builds `ContactSnapshot` by iterating the set in sorted order:
  - Sort by `(enemy_id, instance_id)`.

### Combat Tick Simulation Order (Pure)
Per `combat_logic.tick(dt, ...)`:
1. Decrement unit `cooldown` by `dt` (clamp to `>= 0`).
2. Compute synergy state and special passive mods for the tick.
3. Produce regen events (support synergy + healer special) using deterministic accumulation/distribution.
4. Produce attack events from `auto_attack_logic` using positions.
5. Apply damage modifiers (synergy + specials like crit), emit `damage_enemy`.
6. Apply enemy damage, emit `enemy_dead` for `hp <= 0` with `killer_instance_id`.
7. Consume `ContactSnapshot` and apply contact cooldown gating per (enemy_id, instance_id), emit `damage_unit`.
8. Apply unit damage, emit `unit_dead` for `hp <= 0`.
9. Feed `enemy_dead` into specials (berserker stacks) and bosses (lich king raise requests).

### Combine + Ordering Rules
- Buying appends a new level-1 instance to the tail **before** combine checks.
- Combine detection:
  - For each `def_id`, find groups of **3 instances with the same `level`**.
  - Combine **the 3 lowest `acquired_seq`** among eligible instances for that `def_id` + level.
- Result:
  - Replace the earliest (lowest `acquired_seq`) of the 3 with an upgraded instance (`level+1`).
  - Remove the other 2 instances from the snake.
  - Upgraded instance keeps `acquired_seq` and `instance_id` of the kept instance.
  - Upgraded instance sets `hp = hp_max` (full heal) on combine (shop-only operation).
- Purchase at max length:
  - Allowed only if `(append + all resulting combines)` ends with length `<= max_len`; otherwise reject (no gold spent).

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
  - regen applies to whole snake per Regen contract.
  - at 4: `all_stats_mult=1.10` applies to all units’ `hp_max`, `attack`, `range`, `atk_spd`.

**HP recompute**
- When `hp_max` changes due to buffs, keep `hp` and clamp: `hp = min(hp, hp_max)` (except combine).

**Cooldown recompute**
- When effective `atk_spd` changes, keep `cooldown` in seconds and clamp to `<= period` (`period = 1/atk_spd`).

### Specials (v-slice implemented; all others no-op)
Implemented:
- `healer_adjacent_regen`: heals adjacent segments `10 HP/sec` each
- `knight_block`: this segment takes `20%` less incoming damage (multiplicative)
- `sniper_crit`: `20%` chance to deal `2x` damage (roll per attack via injected RNG)
- `bard_adjacent_atkspd`: adjacent segments gain `+10% atk_spd` (multiplicative)
- `berserker_frenzy`: per credited kill, gain `+5% attack` (stacking; persists within run)
- `paladin_divine_shield`: once per wave, first **nonzero** incoming hit becomes `0` (resets on wave start)

Adjacency is by snake order; head/tail only have one neighbor.

### Regen Distribution (Deterministic, integer HP)
All regen sources generate a float budget per tick, accumulated in `combat_state.regen_accum`:
- `regen_accum += regen_total_per_sec * dt`
- While `regen_accum >= 1`:
  - Spend 1 HP at a time distributed head→tail across living segments (skip dead), looping.
  - Emit `HealEventUnit{amount_int=1}`
  - `regen_accum -= 1`

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
- Bosses:
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
- D depends on A (enemy defs + odds) and optionally C (boss triggers).
- E depends on B/C/D for meaningful integration.
- F depends on B/C/D outputs.
- G depends on D (events) and E (spawner path).

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

**Acceptance**
- `lua -e "package.path=package.path..';./assets/scripts/?.lua;./assets/scripts/?/init.lua'; require('serpent.serpent_main')"` succeeds.
- Enter SERPENT from main menu without errors.
- Exit to main menu and re-enter SERPENT without duplicate spawns/handlers (manual).

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
- `assets/scripts/serpent/data/units.lua` mirrors the 16 units in `planning/PLAN_v0.md`.
- `assets/scripts/serpent/data/shop_odds.lua` implements odds table (1-5, 6-10, 11-15, 16-20).

**Tests**
- `assets/scripts/serpent/tests/test_units.lua`:
  - exactly 16 entries; 4 per class
  - IDs match expected set from `PLAN_v0.md`
  - per-unit numeric fields match expected values (table-driven)
- `assets/scripts/serpent/tests/test_shop_odds.lua`:
  - correct odds per wave bracket; probabilities sum to 1.0

---

### Task 4 — Enemy Data (11) (Verified Values)
**Deliverables**
- `assets/scripts/serpent/data/enemies.lua` mirrors the 11 enemies in `planning/PLAN_v0.md` (including bosses).

**Tests**
- `assets/scripts/serpent/tests/test_enemies.lua`:
  - exactly 11 entries
  - expected IDs present (including `swarm_queen`, `lich_king`)
  - per-enemy numeric fields match expected values (table-driven)

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
  - `create_instance(unit_def, instance_id, acquired_seq) -> UnitInstance(level=1)`
  - `apply_level_scaling(instance, unit_def) -> UnitInstance` (base-only scaling)
- `assets/scripts/serpent/combine_logic.lua`:
  - `detect_and_apply_combines(snake_state, unit_defs) -> (snake_state, combine_events)`
  - combine event includes `{ kept_instance_id, removed_instance_ids[], new_level }`

**Tests**
- `assets/scripts/serpent/tests/test_unit_factory.lua`:
  - stat scaling matches `base * 2^(level-1)` and caps at 3
- `assets/scripts/serpent/tests/test_combines.lua`:
  - combine chooses lowest `acquired_seq` triple
  - kept slot preserved; other 2 removed
  - upgraded instance full-heals (`hp == hp_max`)
  - max-length purchase gating helper scenarios

---

### Task 7 — Synergy System (Pure)
**Deliverables**
- `assets/scripts/serpent/synergy_system.lua`:
  - `calculate(segments, unit_defs) -> synergy_state`
  - exposes per-class `{ count, level(0/1/2), mods }` and per-instance effective multipliers

**Tests**
- `assets/scripts/serpent/tests/test_synergy_system.lua`:
  - thresholds at 2/4
  - modifier values match table
  - mage cooldown rule converts to `atk_spd *= 1/0.8` at level 2

---

### Task 8 — Specials System (Pure)
**Deliverables**
- `assets/scripts/serpent/specials_system.lua` implementing contracts:
  - `get_passive_mods(...)`
  - `tick(dt, ctx, rng) -> events[]`
  - `on_attack(...)`
  - `on_damage_taken(...)`
  - `on_enemy_death(...)`
  - `on_wave_start(...)`

Ctx includes: `snake_state`, `unit_defs`, `wave_num`.

**Tests**
- `assets/scripts/serpent/tests/test_specials.lua`:
  - healer heals adjacent correctly
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
  - `get_pool(wave_num) -> enemy_def_ids[]` (explicit mapping derived from `PLAN_v0.md`, codified as a Lua table)

**Tests**
- `assets/scripts/serpent/tests/test_wave_config.lua`:
  - waves 1..20 valid
  - bosses at 10 and 20 (via wave director, see Task 12)
  - formulas match “Numeric Source of Truth”
  - pool mapping matches expected table-driven spec

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
  - purchase rejection at max length without combines; acceptance when combine reduces length
  - sell refund equals `floor(cost * 3^(level-1) * 0.5)`

---

### Task 11 — Auto-Attack Logic (Pure)
**Deliverables**
- `assets/scripts/serpent/auto_attack_logic.lua`:
  - `tick(dt, segment_snaps, enemy_snaps) -> (updated_cooldowns_by_instance_id, attack_events[])`
  - target selection:
    - nearest target in range by euclidean distance
    - tie-break: lowest `enemy_id`
  - cadence uses `period = 1/atk_spd`

**Tests**
- `assets/scripts/serpent/tests/test_auto_attack_logic.lua`:
  - cooldown cadence with fixed `dt`
  - nearest selection + tie-break
  - out-of-range yields no attacks

---

### Task 12 — Combat Logic (Pure)
**Deliverables**
- `assets/scripts/serpent/combat_logic.lua`:
  - `init_state(snake_state, wave_num) -> combat_state` (regen accumulator, contact cooldown table)
  - `tick(dt, snake_state, segment_snaps, enemy_snaps, contact_snaps, synergy_state, unit_defs, enemy_defs, combat_state, rng) -> (snake_state, enemy_snaps, combat_state, events[])`
  - applies:
    - synergy + specials exactly once
    - contact cooldown `0.5s` per (enemy_id, instance_id)
    - deterministic regen distribution
    - death events with killer credit

**Tests**
- `assets/scripts/serpent/tests/test_combat_logic.lua`:
  - class multipliers apply to correct classes
  - support regen distribution deterministic and clamps to hp_max
  - contact damage cooldown gating over multiple ticks
  - death events emitted at hp <= 0
  - berserker kill credit increments stacks deterministically

---

### Task 13 — Wave Director (Pure)
**Deliverables**
- `assets/scripts/serpent/serpent_wave_director.lua`:
  - tracks current wave, active enemy set, and “wave cleared”
  - on wave start emits a `SpawnRequestEvent` list for regular enemies + boss injection
  - boss injection:
    - wave 10 includes `swarm_queen`
    - wave 20 includes `lich_king`

**Tests**
- `assets/scripts/serpent/tests/test_serpent_wave_director.lua`:
  - wave start/completion detection
  - boss waves inject correct boss ids
  - gold reward expectation uses `wave_config.gold_reward(wave)`

---

### Task 14 — Runtime Physics + Collision Tag Wiring (Required for Contact Damage)
**Deliverables**
- `assets/scripts/core/constants.lua`: add `CollisionTags.SERPENT_SEGMENT = "serpent_segment"`
- `assets/scripts/serpent/contact_collector.lua`:
  - installs/removes physics pair begin/end callbacks
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
  - tail follows by enforcing `SEGMENT_SPACING` using `physics.SetPosition` (deterministic, stable)
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
  - supports burst limiting (spawn-per-second cap)
- `assets/scripts/serpent/combat_adapter.lua`:
  - applies `damage_enemy`/`enemy_dead` to runtime entities and snapshots
  - applies `damage_unit`/`unit_dead` to runtime segments and snake state
  - despawns runtime entities on death

**Manual Acceptance**
- Enemy touching a segment deals damage once per 0.5s while overlapping.
- Segment death removes entity immediately; chain closes.
- Enemy death despawns cleanly and decrements active enemy count for wave clear.

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

### Task 18 — Bosses (Wave 10/20) + Integration
**Deliverables**
- `assets/scripts/serpent/bosses/swarm_queen.lua`
  - cadence: spawns `5` `slime` every `10.0s` while alive
  - emits `SpawnRequestEvent`
- `assets/scripts/serpent/bosses/lich_king.lua`
  - whenever any non-boss enemy dies, queue 1 `skeleton` spawn after `2.0s`
- Wire boss events into wave director → spawner path.

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
- Late waves: burst limiting prevents obvious frame collapse.

---

## Commit Strategy
- Commit after each task group when its tests (and required manual checks) pass.
- Before committing: run `lua assets/scripts/tests/test_runner.lua assets/scripts/serpent/tests/` and repo-standard verification (UBS).