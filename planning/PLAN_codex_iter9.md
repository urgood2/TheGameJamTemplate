# Serpent — SNKRX-Style Survivor (Vertical Slice) Implementation Plan v5.3

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
  - Combat deaths reduce length (removing segments); game over at length 0.
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
- Define **one source of truth** per value (see “Runtime ↔ Pure Boundary”).
- Use stable iteration:
  - Arrays: iterate with `for i=1,#arr do ... end`.
  - Maps: never rely on `pairs()` order for determinism; sort keys when needed.
- Keep Serpent-owned entities/timers/signals isolated and fully cleaned up on exit.
- Serpent runtime must not depend on `initMainGame()` / planning/action/shop phases.

---

## Engine Integration (Repo-Specific, Concrete)

### Game State Integration (`assets/scripts/core/main.lua`)
- Extend `GAMESTATE` to include `SERPENT = 2` (this repo currently uses `0/1` only).
- Load module once near the top-level (idempotent):
  - `local Serpent = require("serpent.serpent_main")`
- Extend `changeGameState(newState)` to support:
  - Entering `GAMESTATE.SERPENT`: call `Serpent.init()`
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
- `rng:choice(list)` (required helper; must consume exactly **one** `int`)

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
  - Transition order:
    1) `on_wave_start` hooks (specials + combat state reset for wave)
    2) `director_state = wave_director.start_wave(wave, rng, enemy_defs)`
- `COMBAT` → `SHOP` when:
  - `wave_director:is_done_spawning(director_state)` is true **and**
  - `enemy_snaps` is empty (all spawned enemies are dead/despawned) **and**
  - `wave < 20`
  - Transition order:
    1) `gold += Gold_per_Wave(wave)`
    2) `wave += 1`
    3) `shop_state = shop.enter_shop(upcoming_wave=wave, gold, rng)`
- `COMBAT` → `VICTORY` when wave 20 cleared using same cleared criteria
- Any state → `GAME_OVER` when `#snake_state.segments == 0`

Constants:
- `STARTING_GOLD = 10`
- `STARTING_SEED = tonumber(os.getenv("SERPENT_SEED") or "") or 12345`
- Starting snake (head→tail): `soldier`, `apprentice`, `scout` (all level 1)
- HP persists across waves; combine (shop-only) sets combined unit to full HP.

Cleanup requirements:
- Use a dedicated timer group and correct engine API:
  - `SERPENT_TIMER_GROUP = "serpent"`
  - `cleanup()` must call `timer.kill_group(SERPENT_TIMER_GROUP)` and clear Serpent-owned entities/UI state.
- Physics callbacks are registered once globally (no per-entry re-register); Serpent toggles `contact_collector:set_enabled(true/false)` and clears overlap state on disable.

### Runtime Update Order (Deterministic)
**Single Source of Truth**
- Pure state: `snake_state`, `combat_state`, `shop_state`, `director_state`, `id_state` are authoritative.
- Runtime entities exist only to render and provide positions/collisions; they do **not** own combat stats.

Per `Serpent.update(dt)` in `COMBAT`:
1. Controllers (movement only):
   - `snake_controller:update(dt, snake_entities, input, arena_cfg)`
   - `enemy_controller:update(dt, enemy_entities, head_pos)`
2. Build runtime snapshots (position/collision only; no combat stats):
   - `segment_pos_snaps = snake_entity_adapter:build_pos_snapshots()` (head→tail order)
   - `enemy_pos_snaps = enemy_entity_adapter:build_pos_snapshots()` (sorted by `enemy_id`)
   - `contact_snaps = contact_collector:build_snapshot()` (sorted, de-duped)
3. Pure combat:
   - `(snake_state, enemy_snaps, combat_state, events) = combat_logic.tick(dt, snake_state, segment_pos_snaps, enemy_snaps, enemy_pos_snaps, contact_snaps, unit_defs, enemy_defs, combat_state, rng)`
   - Contract: `enemy_snaps` list ordering remains sorted by `enemy_id` after all mutations.
4. Apply events to runtime:
   - `combat_adapter:apply(events, snake_entities, enemy_entities, contact_collector)` (despawn + unregister on death; apply HP to visuals if any)
5. Spawning (pure scheduling, then runtime spawn):
   - `(director_state, id_state, spawn_events) = wave_director.tick(dt, director_state, id_state, rng, events, alive_enemy_ids_set(enemy_snaps))`
   - `(enemy_entities, enemy_snaps) = enemy_spawner_adapter:apply(spawn_events, enemy_entities, enemy_snaps, rng, wave, enemy_defs, wave_config)`
6. Post-step wave-clear check (criteria above).

Per `Serpent.update(dt)` in `SHOP`:
- UI-only interactions drive pure shop operations; no combat tick; no director ticking.

---

## Canonical Data Shapes (Pure Logic)
All pure modules accept/return plain Lua tables.

### Data
**UnitDef** (`assets/scripts/serpent/data/units.lua`)
- `id` (string), `class` (`"Warrior"|"Mage"|"Ranger"|"Support"`), `tier` (1..4), `cost` (int)
- `base_hp`, `base_attack` (ints), `range`, `atk_spd` (numbers)
- `special_id` (string or nil)

**EnemyDef** (`assets/scripts/serpent/data/enemies.lua`)
- `id` (string), `base_hp`, `base_damage` (ints), `speed` (number)
- `min_wave`, `max_wave` (ints)
- `tags` (table; e.g., `{ boss=true }`)

### ID + Instances
**IdState**
- `next_instance_id` (int, starts at 1)
- `next_acquired_seq` (int, starts at 1)
- `next_enemy_id` (int, starts at 1)

**UnitInstance** (base-scaled stats only; effective stats are recomputed each tick)
- `instance_id` (int)
- `def_id` (string), `level` (1..3)
- `hp`, `hp_max_base`, `attack_base` (ints)
- `range_base`, `atk_spd_base` (numbers)
- `cooldown` (seconds until next attack, `>= 0` at end of tick)
- `acquired_seq` (int)
- `special_state` (table; persistent per-run state)

**SnakeState**
- `segments` = array of `UnitInstance` in head→tail order
- `min_len=3`, `max_len=8`

### Enemies
**EnemySnapshot** (pure-facing “model”; runtime mirrors it)
- `enemy_id` (int), `def_id` (string)
- `hp`, `hp_max`, `damage` (ints), `speed` (number)
- `x`, `y` (numbers) — authoritative enemy position for combat targeting
- `tags` (table)

---

## Runtime ↔ Pure Boundary (Snapshots + Events)

### Runtime Snapshots (inputs to pure)
**SegmentPosSnapshot**
- `instance_id` (int)
- `x`, `y` (numbers)

**EnemyPosSnapshot**
- `enemy_id` (int)
- `x`, `y` (numbers)

Contract:
- `segment_pos_snaps` must be in head→tail order matching `snake_state.segments` by `instance_id`.
- `enemy_pos_snaps` must be sorted by `enemy_id` ascending.

**ContactSnapshot**
- Array of `{ enemy_id, instance_id }` for pairs currently overlapping this frame.
- Must be **de-duped** and sorted by `(enemy_id, instance_id)`.

### Runtime ID mapping (required)
Runtime maintains:
- `enemy_id -> enemy_entity_id`
- `instance_id -> segment_entity_id`
…and contact collector maintains the inverse maps:
- `enemy_entity_id -> enemy_id`
- `segment_entity_id -> instance_id`

### Events (pure outputs)
- `AttackEvent`: `{ kind="attack", attacker_instance_id, target_enemy_id, base_damage_int }`
- `DamageEventEnemy`: `{ kind="damage_enemy", target_enemy_id, amount_int, source_instance_id }`
- `DamageEventUnit`: `{ kind="damage_unit", target_instance_id, amount_int, source_enemy_id }`
- `HealEventUnit`: `{ kind="heal_unit", target_instance_id, amount_int }`
- `DeathEventEnemy`: `{ kind="enemy_dead", enemy_id, killer_instance_id }`
- `DeathEventUnit`: `{ kind="unit_dead", instance_id }`
- `SpawnEnemyEvent`: `{ kind="spawn_enemy", enemy_id, def_id, spawn_rule }`
- `WaveStartEvent`: `{ kind="wave_start", wave_num }`

---

## Spawn Rule (Deterministic)
`spawn_rule = { mode="edge_random", arena={ w, h, padding } }`

Algorithm (exact, consumes RNG in this order per spawn):
- Choose edge index `e = rng:int(1,4)` mapping to `left,right,top,bottom`
- Choose coordinate along edge `t = rng:float()`
- Compute `(x,y)` inside arena bounds with padding:
  - left: `x = padding`, `y = padding + t*(h-2*padding)`
  - right: `x = w - padding`, `y = padding + t*(h-2*padding)`
  - top: `x = padding + t*(w-2*padding)`, `y = padding`
  - bottom: `x = padding + t*(w-2*padding)`, `y = h - padding`
- Spawn positions must be identical for same seed/run.

---

## Enemy Scaling (Exact, Pure)
On spawn for wave `wave_num`:
- `hp_max = floor(enemy_def.base_hp * hp_mult(wave_num) + 0.00001)`
- `damage = floor(enemy_def.base_damage * dmg_mult(wave_num) + 0.00001)`
- `hp = hp_max`

---

## Contact Damage (Exact)
Stored in `combat_state.contact_cooldowns`:
- Key: `enemy_id .. ":" .. instance_id`
- Value: seconds remaining until next contact hit for that pair.

Per tick:
- First: decrement all existing cooldown values by `dt` (allow negatives).
- Then: iterate `ContactSnapshot` in sorted `(enemy_id, instance_id)` order:
  - If pair cooldown `<= 0` and both ids still alive: emit `DamageEventUnit` for `enemy.damage`, then set cooldown to `CONTACT_DAMAGE_COOLDOWN_SEC`.
  - Else: do nothing.
- End of tick: prune any cooldown entries whose `enemy_id` or `instance_id` is missing.

---

## Combat Tick Simulation Order (Pure)
Per `combat_logic.tick(dt, snake_state, segment_pos_snaps, enemy_snaps, enemy_pos_snaps, contact_snaps, unit_defs, enemy_defs, combat_state, rng)`:

1) **Advance time**
- `combat_state.combat_time_sec += dt`

2) **Merge positions**
- Update `enemy_snaps[i].x/y` from `enemy_pos_snaps` by `enemy_id`.
- Build `segment_positions_by_instance_id` from `segment_pos_snaps`.

3) **Decrement unit cooldowns**
- For each segment in head→tail: `segment.cooldown -= dt` (allow negative internally).

4) **Compute synergy + passive special multipliers**
- Compute `synergy_state` from current segments.
- Compute passive mods from specials (`knight_block`, `bard_adjacent_atkspd`, `berserker_frenzy` as an attack multiplier, etc.).
- Stacking rules (exact):
  - All applicable multipliers multiply (e.g., `atk_mult = warrior_synergy * support_all_stats * berserker_stacks * ...`).
  - Multiple bards affecting a segment: `atk_spd_mult *= 1.10` per adjacent bard (multiplicative stacking).
  - Multiple sources of the same category multiply; no additive mixing except where specified.
- Effective stat recompute (no drift):
  - `effective_hp_max = floor(hp_max_base * hp_mult + 0.00001)`
  - `effective_attack = floor(attack_base * atk_mult + 0.00001)`
  - `effective_range = range_base * range_mult`
  - `effective_atk_spd = atk_spd_base * atk_spd_mult`
  - `effective_period = (1 / effective_atk_spd) * cooldown_period_mult` (Mage 4-set uses `0.8`)
  - Clamp: if `effective_hp_max` decreases, set `hp = min(hp, effective_hp_max)`.

5) **Produce healing events**
- Global regen sources (Support synergy) via global regen accumulator contract.
- Targeted heal sources (Healer adjacent regen) via targeted accumulator contract.
- Deterministic ordering:
  - Emit all global regen `HealEventUnit` events first (in the cursor-driven order).
  - Then emit healer targeted heals:
    - Iterate healers in head→tail order.
    - For each healer: process left neighbor fully (drain accumulator), then right neighbor fully.

6) **Produce attacks (auto-attack)**
- For each segment in head→tail order:
  - Determine target: nearest enemy with `distance <= effective_range`.
  - Tie-break: lowest `enemy_id`.
  - Cadence:
    - While `cooldown <= 0` and target exists:
      - Emit `AttackEvent{base_damage_int = effective_attack}`.
      - `cooldown += effective_period`
    - If no target exists: `cooldown = math.max(cooldown, 0)` and stop.

7) **Apply on-attack modifiers + emit enemy damage**
- Apply specials that modify attacks:
  - `sniper_crit`: roll `rng:float()` per emitted `AttackEvent`; if `< 0.20`, `damage *= 2`.
- After modifiers: emit `DamageEventEnemy` with integer amount (floor rule already satisfied since base is int; only crit multiply yields int).

8) **Apply enemy damage & deaths (deterministic)**
- Apply `DamageEventEnemy` in emitted order.
- When an enemy reaches `hp <= 0`, emit `DeathEventEnemy` immediately with:
  - `killer_instance_id = source_instance_id` from the damage event that reduced hp to `<= 0`.
- Remove dead enemies from `enemy_snaps` at the end of this phase, preserving ascending `enemy_id` ordering for survivors.

9) **Apply contact damage (see Contact Damage contract)**
- Emit `DamageEventUnit` in `ContactSnapshot` sorted order, gated by cooldown.

10) **Apply on-damage-taken modifiers + unit damage + deaths**
- For each `DamageEventUnit` (in the order they were emitted):
  - Apply per-target damage modifiers via specials:
    - `paladin_divine_shield`: if available for that paladin and incoming damage is **nonzero**, set damage to `0` and consume shield.
    - `knight_block`: multiply damage by `0.8`, then floor.
    - If multiple modifiers ever apply: apply shield first, then multiplicative reductions.
  - Apply final damage; if `hp <= 0`, emit `DeathEventUnit`.

11) **Cleanup**
- Remove dead units from `snake_state.segments` (length decreases).
- Prune stale `contact_cooldowns` entries for missing ids.

12) **Specials event hooks**
- Feed events into specials logic in deterministic order:
  - Iterate events in the order they were produced.
  - `enemy_dead` → berserker stacks.
  - `wave_start` → paladin shield reset.

Deterministic ordering constraints:
- Segment iteration is head→tail order.
- Enemy iteration for targeting uses `enemy_snaps` in ascending `enemy_id`.
- Contact damage uses sorted `(enemy_id, instance_id)` order.

---

## Combine + Ordering Rules (Deterministic, Chain-Safe)
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

---

## Gold + Rounding Rules
- Costs are integers.
- Sell refund is `math.floor(total_paid_for_instance * 0.5)`.
- `total_paid_for_instance = unit_def.cost * (3^(level-1))`.

---

## Synergy Rules (Exact)
Synergy derived from current snake segments (post-combine):
- Warrior: attack multiplier to **Warrior** only; at 4 also HP multiplier to **Warrior** only.
- Mage: treat “spell damage” as attack multiplier to **Mage** only; at 4 apply cooldown reduction via `cooldown_period_mult = 0.8` (i.e., period multiplied by 0.8 for Mages).
- Ranger: atk_spd and range multipliers to **Ranger** only.
- Support:
  - global regen applies to whole snake per Global Regen contract.
  - at 4: `all_stats_mult=1.10` applies to all units’ `hp_max`, `attack`, `range`, `atk_spd`.

---

## Specials (v-slice implemented; others no-op)
Implemented (pure):
- `healer_adjacent_regen`: heals adjacent segments `10 HP/sec` each (targeted)
- `knight_block`: this segment takes `20%` less incoming damage (multiplicative, floor after multiply)
- `sniper_crit`: `20%` chance to deal `2x` damage (roll per attack via injected RNG)
- `bard_adjacent_atkspd`: adjacent segments gain `+10% atk_spd` (multiplicative; stacks per adjacent bard)
- `berserker_frenzy`: per credited kill, gain `+5% attack` (stacking; persists within run)
- `paladin_divine_shield`: once per wave, first **nonzero** incoming hit becomes `0` (resets on wave start)

Adjacency is by snake order; head/tail only have one neighbor.

---

## Healing Contracts (Deterministic, integer HP)

### Global Regen (Support synergy only)
- Stored in `combat_state.global_regen_accum` (float) and `combat_state.global_regen_cursor` (int index into snake order).
- Per tick:
  - `global_regen_accum += global_regen_per_sec * dt`
  - While `global_regen_accum >= 1`:
    - Find next living segment starting at `global_regen_cursor`, wrap head→tail (skip dead), update cursor after heal.
    - Emit `HealEventUnit{amount_int=1}` for that segment.
    - `global_regen_accum -= 1`

### Targeted Regen (Healer special)
- Stored per-healer in `unit.special_state`:
  - `heal_left_accum`, `heal_right_accum` (floats, default 0)
- Per tick, for each healer instance (head→tail order):
  - If left neighbor exists and alive: `heal_left_accum += 10 * dt`; while `>= 1` emit 1 HP heal to left, subtract 1.
  - Then if right neighbor exists and alive: `heal_right_accum += 10 * dt`; while `>= 1` emit 1 HP heal to right, subtract 1.
- Targeted heals do **not** use global cursor/distribution.

---

## Spawn Scheduling (Unified, Deterministic, Wave-Clear Safe)

### Responsibilities
- `serpent_wave_director.lua` is the **only** pure module that emits `SpawnEnemyEvent`s and the **single source of truth** for “pending spawns”.
- Boss spawn behaviors are implemented in `bosses/*.lua`, but owned/invoked by the wave director so they are counted as pending and cannot allow early wave-clear.

### Spawn Emission Rules
- Fixed pacing for “base wave” enemies:
  - `SPAWN_RATE_PER_SEC = 10`
  - `MAX_SPAWNS_PER_FRAME = 3` (global cap across base + boss spawns)
- Director maintains:
  - `base_spawn_list` (array of `def_id`) in exact RNG-draw order
  - `base_index` (next index to spawn)
  - `spawn_budget` float (accumulates `SPAWN_RATE_PER_SEC * dt`)
  - `forced_queue` array of `def_id` for boss-triggered spawns ready to emit now
  - `delayed_queue` array of `{ t_left_sec, def_id }` for future boss spawns (preserve insertion order)
  - `boss_states` keyed by boss enemy_id (contains per-boss state)
  - `pending_count = (#base_spawn_list - base_index + 1) + #forced_queue + #delayed_queue`
- Per `tick(dt, ...)`:
  1) Decrement delayed timers (in insertion order); move any `t_left_sec <= 0` into `forced_queue` (append; preserve original delayed order).
  2) Process combat events relevant to bosses (from `events[]` in their existing order):
     - For each `enemy_dead` event, call `lich_king.on_enemy_dead` for each tracked lich_king boss state that is alive.
  3) Boss periodic spawns:
     - For each tracked boss state that is alive (iterate boss ids in ascending boss enemy_id):
       - `swarm_queen`: every `10.0s`, append `5` `slime` to `forced_queue` (in-order).
       - `lich_king`: any queued “raise” becomes a delayed entry of `{ t_left_sec=2.0, def_id="skeleton" }` appended to `delayed_queue`.
  4) Emit spawn events this frame in this order, respecting the single cap:
     - Emit from `forced_queue` first (FIFO), then from `base_spawn_list` (in-order) using `spawn_budget`:
       - `spawn_budget += SPAWN_RATE_PER_SEC * dt`
       - `base_emit = min(remaining_cap, floor(spawn_budget))`
       - `spawn_budget -= base_emit`
     - If a rule attempts to enqueue 5 slimes but the cap only allows 3 total spawns this frame, the remaining 2 stay queued for later frames (FIFO).
  5) Every emitted spawn allocates `enemy_id` sequentially from `id_state.next_enemy_id`.
  6) When emitting a boss spawn (`swarm_queen` or `lich_king`), initialize and register the boss state keyed by the allocated `enemy_id`.

### Base Wave Enemy Selection (Exact RNG Consumption)
In `start_wave(wave_num, rng, enemy_defs)`:
- `n = Enemies_per_Wave(wave_num)`
- `pool = wave_config.get_pool(wave_num, enemy_defs)` (non-boss only)
- Build `base_spawn_list` length `n` with:
  - for `i=1..n`: `base_spawn_list[i] = rng:choice(pool)` (uniform; consumes exactly one `int` per choice)
- Boss injection:
  - if `wave_num == 10`: prepend one `swarm_queen` spawn into `forced_queue` at wave start
  - if `wave_num == 20`: prepend one `lich_king` spawn into `forced_queue` at wave start

Wave clear uses:
- `director.pending_count == 0` and `enemy_snaps` empty.

---

## Shop Determinism (Exact RNG Consumption)
Per `enter_shop(upcoming_wave, gold, rng)`:
- For each of 5 slots (slot order 1..5):
  1) Consume `r = rng:float()` and pick tier by cumulative odds for `upcoming_wave`.
  2) Build tier unit pool (stable sorted by unit `id` ascending).
  3) Pick unit index `k = rng:int(1, #pool)`; offer is `pool[k]`.

Per `reroll`:
- Same 5-slot generation, same RNG consumption order; reroll counter increments cost deterministically.

---

## Directory Layout
All Serpent code under `assets/scripts/serpent/`:
- `serpent_main.lua`
- `rng.lua`
- Data: `data/units.lua`, `data/enemies.lua`, `data/shop_odds.lua`
- Pure logic:
  - `snake_logic.lua`
  - `unit_factory.lua`
  - `enemy_factory.lua`
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
- Bosses (pure helpers invoked by wave director):
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
- Pack B: Pure core (snake/unit/enemy factory/combines) + tests
- Pack C: Pure combat (synergy/specials/auto-attack/combat logic) + tests
- Pack D: Pure waves/shop (odds/wave config/wave director/shop) + tests
- Pack E: Runtime core (mode skeleton, collisions/contact collector, spawner, enemy + snake controllers)
- Pack F: UI (shop/synergy/hud/screens) after view-model inputs exist

Dependency notes:
- C depends on A+B.
- D depends on A (defs + odds) and C (combat events for boss scheduling).
- E depends on B/C/D for meaningful integration.
- F depends on B/C/D outputs.

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
  - `require("serpent.serpent_main")` wired once (no repeated requires)
- Serpent-owned timer group name: `SERPENT_TIMER_GROUP = "serpent"`; cleanup calls `timer.kill_group("serpent")`.

**Acceptance**
- `lua -e "package.path=package.path..';./assets/scripts/?.lua;./assets/scripts/?/init.lua'; require('serpent.serpent_main')"` succeeds.
- Enter SERPENT from main menu without errors.
- Exit to main menu and re-enter SERPENT without duplicate state (manual).

---

### Task 2 — Localization Keys
**Deliverables**
- Add required keys to:
  - `assets/localization/en_us.json`
  - `assets/localization/ko_kr.json`

**Acceptance**
- Main menu Serpent button label resolves via `localization.get("ui.start_serpent_button")`.
- Serpent UI (ready/reroll/victory/game over/retry/main menu) uses the planned keys and renders non-empty strings (manual).

---

### Task 3 — RNG Utility (Deterministic, No Global Random)
**Deliverables**
- `assets/scripts/serpent/rng.lua` implementing `new(seed)`, `int`, `float`, `choice`

**Tests**
- `assets/scripts/serpent/tests/test_rng.lua`:
  - same seed yields identical sequences
  - different seeds diverge
  - `int(min,max)` is inclusive and stable
  - `choice(list)` consumes exactly one `int` and matches `int(1,#list)` semantics

---

### Task 4 — Unit Data (16) + Shop Odds Data (Verified Values)
**Deliverables**
- `assets/scripts/serpent/data/units.lua` exactly matches the Units table in this plan.
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

### Task 5 — Enemy Data (11) + Enemy Factory (Pure)
**Deliverables**
- `assets/scripts/serpent/data/enemies.lua` exactly matches the Enemies table in this plan.
- `assets/scripts/serpent/enemy_factory.lua`:
  - `create_snapshot(enemy_def, enemy_id, wave_num, wave_config, x, y) -> EnemySnapshot` (scaled hp/damage + tags + position)

**Tests**
- `assets/scripts/serpent/tests/test_enemies.lua`:
  - exactly 11 entries
  - expected IDs present (including `swarm_queen`, `lich_king`)
  - per-enemy numeric fields match expected values (table-driven)
  - wave ranges validated (min<=max; bosses exact wave)
- `assets/scripts/serpent/tests/test_enemy_factory.lua`:
  - hp/damage scaling formulas + rounding match spec
  - bosses and non-boss tags preserved
  - positions set as provided

---

### Task 6 — Snake Core Logic (Pure)
**Deliverables**
- `assets/scripts/serpent/snake_logic.lua`:
  - `create_initial(unit_defs, min_len, max_len, id_state) -> (SnakeState, id_state)`
  - `can_sell(snake_state, instance_id) -> bool`
  - `remove_instance(snake_state, instance_id) -> SnakeState`
  - `is_dead(snake_state) -> bool`

**Tests**
- `assets/scripts/serpent/tests/test_snake_logic.lua`:
  - selling blocked if it would drop below 3
  - removal via death reduces length (can drop below 3)
  - length 0 marks dead
  - `create_initial` emits 3 starting instances with monotonic ids/seq

---

### Task 7 — Unit Factory + Combine Rules (Pure)
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

### Task 8 — Synergy System (Pure)
**Deliverables**
- `assets/scripts/serpent/synergy_system.lua`:
  - `calculate(segments, unit_defs) -> synergy_state`
  - `get_effective_multipliers(synergy_state, segments, unit_defs) -> by_instance_id`
  - multipliers include: `hp_mult`, `atk_mult`, `range_mult`, `atk_spd_mult`, `cooldown_period_mult`, `global_regen_per_sec`

**Tests**
- `assets/scripts/serpent/tests/test_synergy_system.lua`:
  - thresholds at 2/4
  - modifier values match table
  - mage cooldown rule equals `cooldown_period_mult = 0.8` at 4-units

---

### Task 9 — Specials System (Pure)
**Deliverables**
- `assets/scripts/serpent/specials_system.lua` implementing:
  - `get_passive_mods(ctx) -> mods_by_instance_id`
  - `tick(dt, ctx, rng) -> events[]` (heals only; deterministic ordering defined above)
  - `on_attack(ctx, attack_event, rng) -> (possibly_modified_attack_event, extra_events[])`
  - `on_damage_taken(ctx, damage_unit_event) -> (modified_damage_unit_event, extra_events[])`
  - `on_enemy_death(ctx, death_enemy_event) -> extra_events[]`
  - `on_wave_start(ctx)`

Ctx includes: `snake_state`, `unit_defs`, `wave_num`, `now_sec` (monotonic combat time).

**Tests**
- `assets/scripts/serpent/tests/test_specials.lua`:
  - healer targeted heals adjacent correctly (ordering and accumulation)
  - knight reduces damage by 20% with correct floor rounding
  - sniper crit deterministic with seeded RNG (roll per attack)
  - bard buffs adjacent atk_spd multiplicatively (stacks)
  - berserker stacks +5% attack per credited kill
  - paladin negates first nonzero hit per wave and resets on wave start

---

### Task 10 — Wave Config (20) (Pure)
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

### Task 11 — Shop System (Pure)
**Deliverables**
- `assets/scripts/serpent/serpent_shop.lua`:
  - `enter_shop(upcoming_wave, gold, rng, unit_defs, shop_odds) -> shop_state` (5 offers; deterministic RNG contract)
  - `reroll(shop_state, rng, unit_defs, shop_odds) -> (shop_state, gold_delta_int)`
  - `can_buy(...) -> bool`
  - `buy(...) -> (shop_state, snake_state, gold, id_state, events[])`
  - `sell(...) -> (snake_state, gold)`
- Offer rules:
  - `SHOP_SLOTS = 5`
  - Choose tier by odds table for `upcoming_wave`, then choose uniformly among units of that tier.
  - Tier pool order must be stable (sort by unit `id` ascending).
  - Duplicates allowed.

**Tests**
- `assets/scripts/serpent/tests/test_serpent_shop.lua`:
  - 5 offers
  - reroll cost increments (2,3,4,…) and resets each `enter_shop`
  - gold accounting and floor rounding
  - purchase rejection at max length without combines; acceptance when combines reduce length
  - sell refund equals `floor(cost * 3^(level-1) * 0.5)`
  - deterministic shop offer stream under fixed seed (exact ids expected)

---

### Task 12 — Auto-Attack Logic (Pure)
**Deliverables**
- `assets/scripts/serpent/auto_attack_logic.lua`:
  - `tick(dt, segment_combat_snaps, enemy_snaps) -> (updated_cooldowns_by_instance_id, attack_events[])`
  - `segment_combat_snaps` contract:
    - head→tail order
    - fields: `instance_id, x, y, effective_attack_int, effective_range_num, effective_period_num, cooldown_num`
  - target selection:
    - nearest target with `distance <= effective_range`
    - tie-break: lowest `enemy_id`
  - cadence:
    - allow multiple attacks per tick using `while cooldown <= 0`

**Tests**
- `assets/scripts/serpent/tests/test_auto_attack_logic.lua`:
  - multi-attack behavior when `dt > period`
  - nearest selection + tie-break
  - out-of-range yields no attacks
  - stable event ordering for multiple segments

---

### Task 13 — Combat Logic (Pure)
**Deliverables**
- `assets/scripts/serpent/combat_logic.lua`:
  - `init_state(snake_state, wave_num) -> combat_state`:
    - `global_regen_accum`, `global_regen_cursor`
    - `contact_cooldowns` map
    - `combat_time_sec`
  - `tick(dt, snake_state, segment_pos_snaps, enemy_snaps, enemy_pos_snaps, contact_snaps, unit_defs, enemy_defs, combat_state, rng) -> (snake_state, enemy_snaps, combat_state, events[])`
  - must:
    - merge positions deterministically
    - apply synergy + specials exactly once per tick
    - enforce contact cooldown `0.5s` per (enemy_id, instance_id)
    - implement global regen distribution and targeted healer regen with defined ordering
    - emit death events and remove dead units/enemies from returned state
    - prune stale cooldown entries when ids no longer exist
    - preserve sorted `enemy_snaps` ordering by `enemy_id`

**Tests**
- `assets/scripts/serpent/tests/test_combat_logic.lua`:
  - class multipliers apply to correct classes
  - global regen distribution deterministic and clamps to hp_max
  - targeted healer regen deterministic and adjacency-correct (including ordering)
  - contact damage cooldown gating over multiple ticks
  - unit deaths remove segments (length decreases)
  - enemy deaths remove enemies and keep ordering stable
  - berserker kill credit increments stacks deterministically

---

### Task 14 — Wave Director (Pure, Spawn Scheduling + Boss Ownership)
**Deliverables**
- `assets/scripts/serpent/serpent_wave_director.lua`:
  - deterministic spawn scheduling so “wave cleared” cannot happen before all planned spawns have occurred (including boss spawns and delayed raises)
  - constants:
    - `SPAWN_RATE_PER_SEC = 10`
    - `MAX_SPAWNS_PER_FRAME = 3`
  - API:
    - `start_wave(wave_num, rng, enemy_defs, wave_config) -> director_state`
    - `tick(dt, director_state, id_state, rng, combat_events, alive_enemy_ids_set) -> (director_state, id_state, spawn_events[])`
    - `is_done_spawning(director_state) -> bool` (true when `pending_count == 0`)
  - must implement:
    - base wave enemy selection algorithm (exact RNG consumption)
    - boss injection and boss state creation keyed by boss enemy_id when boss spawn emitted
    - swarm queen cadence and lich raise scheduling exactly as specified (including cap carryover + ordering)

**Tests**
- `assets/scripts/serpent/tests/test_serpent_wave_director.lua`:
  - wave 1/10/20 base spawn counts match `Enemies_per_Wave` (+ boss injection on 10/20)
  - determinism: same seed+dt sequence yields identical spawn event stream (enemy_ids and def_ids)
  - boss behaviors:
    - queen: emits 5 `slime` every 10.0s while alive (respecting per-frame cap carryover deterministically)
    - lich: queues 1 `skeleton` spawn 2.0s after each non-boss enemy death while alive (preserve event order)
  - pending_count reaches 0 only after all base + boss + delayed spawns have been emitted

---

### Task 15 — Runtime Physics + Collision Tag Wiring (Required for Contact Damage)
**Deliverables**
- `assets/scripts/core/constants.lua`: add `CollisionTags.SERPENT_SEGMENT = "serpent_segment"`
- `assets/scripts/serpent/contact_collector.lua`:
  - registers `physics.on_pair_begin` and `physics.on_pair_separate` once
  - `set_enabled(bool)` toggles whether callbacks mutate internal overlap state
  - maintains inverse maps:
    - `register_enemy_entity(enemy_id, entity_id)`
    - `unregister_enemy_entity(enemy_id, entity_id)` (must remove all overlap pairs for this enemy_id)
    - `register_segment_entity(instance_id, entity_id)`
    - `unregister_segment_entity(instance_id, entity_id)` (must remove all overlap pairs for this instance_id)
  - stores overlaps as a set keyed by `enemy_id..":"..instance_id` to avoid duplicates
  - `build_snapshot() -> ContactSnapshot` sorted by `(enemy_id, instance_id)`
  - `clear()` to wipe overlaps (called on disable/cleanup)
- `serpent_main.lua`:
  - ensures `world:AddCollisionTag(C.CollisionTags.SERPENT_SEGMENT)` (idempotent best-effort)
  - enables collisions between `SERPENT_SEGMENT` and `ENEMY` via `physics.enable_collision_between_many` + `physics.update_collision_masks_for`
  - cleanup disables collector and clears overlap set

**Manual Acceptance**
- Overlap tracking works across begin/separate; snapshot ordering stable and de-duped.
- Re-entering Serpent does not register duplicate callbacks or cause double contact damage.

---

### Task 16 — Runtime Entities + Controllers (Snake + Enemies)
**Deliverables**
- `assets/scripts/serpent/snake_entity_adapter.lua`:
  - spawns segment entities tagged `SERPENT_SEGMENT` with physics bodies
  - maintains `instance_id -> entity_id` mapping
  - calls `contact_collector.register_segment_entity(instance_id, entity_id)`
  - unregisters on despawn
  - `build_pos_snapshots() -> SegmentPosSnapshot[]` in head→tail order matching `snake_state`
- `assets/scripts/serpent/snake_controller.lua`:
  - head steering via WASD/arrows
  - updates head position/velocity (use `physics.SetVelocity` and clamp to arena via `physics.SetPosition`)
  - tail follows by enforcing `SEGMENT_SPACING` in snake order (deterministic)
- `assets/scripts/serpent/enemy_entity_adapter.lua` + `enemy_controller.lua`:
  - spawns enemy entities tagged `ENEMY` and ensures they collide with `SERPENT_SEGMENT`
  - maintains `enemy_id -> entity_id` mapping
  - calls `contact_collector.register_enemy_entity(enemy_id, entity_id)`
  - unregisters on despawn
  - `build_pos_snapshots() -> EnemyPosSnapshot[]` sorted by `enemy_id`
  - enemy movement: move toward head position at `enemy_snapshot.speed` using `physics.SetVelocity`

**Manual Acceptance**
- Snake spawns with starting units in correct order.
- Movement stable (no runaway drift); head stays within arena bounds.
- Enemies reliably approach snake (not dependent on PLAYER systems).

---

### Task 17 — Runtime Spawner + Combat Adapter
**Deliverables**
- `assets/scripts/serpent/enemy_spawner_adapter.lua`:
  - consumes `SpawnEnemyEvent` (individual spawns with explicit `enemy_id`)
  - computes deterministic spawn positions via RNG + spawn rule (exact algorithm in this plan)
  - uses `enemy_factory.create_snapshot(...)` to create scaled stats + initial position
  - spawns enemies and returns updated `enemy_snaps` list (must remain sorted by `enemy_id`)
- `assets/scripts/serpent/combat_adapter.lua`:
  - applies `DamageEventEnemy` / `DeathEventEnemy` to runtime entities and `enemy_snaps`
  - applies `DamageEventUnit` / `DeathEventUnit` to runtime segments (visual) and relies on `snake_state` for truth
  - despawns runtime entities on death and unregisters them from contact collector

**Manual Acceptance**
- Enemy touching a segment deals damage once per 0.5s while overlapping.
- Segment death removes entity immediately and removes it from snake length/order.
- Enemy death despawns cleanly and removes it from `enemy_snaps`.
- Wave cannot clear before all scheduled spawns are emitted and enemies are dead.

---

### Task 18 — UI (Shop + Synergy + HUD)
**Deliverables**
- `assets/scripts/serpent/ui/shop_ui.lua`:
  - view-model helpers: slot labels, affordability, reroll label, sell enable/disable, ready enable
  - interactions: buy/reroll/sell/ready (drive pure shop + combine + synergy refresh)
  - uses localization keys (`ui.serpent_ready`, `ui.serpent_reroll`)
- `assets/scripts/serpent/ui/synergy_ui.lua` (view-model from `synergy_state`)
- `assets/scripts/serpent/ui/hud.lua`:
  - HP as `sum(hp)/sum(effective_hp_max)` across segments (effective hp_max computed with current synergy/passives, clamp rule)
  - gold, wave, seed

**Tests**
- `assets/scripts/serpent/tests/test_shop_ui.lua` (view-model only)
- `assets/scripts/serpent/tests/test_synergy_ui.lua` (view-model only)
- `assets/scripts/serpent/tests/test_hud.lua` (formatting + aggregation helpers)

---

### Task 19 — Boss Modules (Pure)
**Deliverables**
- `assets/scripts/serpent/bosses/swarm_queen.lua`
  - `init(enemy_id) -> boss_state`
  - `tick(dt, boss_state, is_alive) -> (boss_state, forced_def_ids[])`
  - cadence: returns `{"slime","slime","slime","slime","slime"}` every `10.0s` while alive
- `assets/scripts/serpent/bosses/lich_king.lua`
  - `init(enemy_id) -> boss_state`
  - `on_enemy_dead(boss_state, dead_enemy_def_id, dead_enemy_tags) -> boss_state`
  - `tick(dt, boss_state, is_alive) -> (boss_state, delayed_spawns[])`
  - delayed spawn shape: `{ t_left_sec=2.0, def_id="skeleton" }` per qualifying death (non-boss only)

**Tests**
- `assets/scripts/serpent/tests/test_bosses.lua`:
  - deterministic cadence under simulated time steps
  - deterministic delayed raise scheduling
  - ignores boss deaths for lich raises

---

### Task 20 — End Screens + Final Verification
**Deliverables**
- `assets/scripts/serpent/ui/game_over_screen.lua`
- `assets/scripts/serpent/ui/victory_screen.lua`
- Run stats tracked in `serpent_main.lua` (waves cleared, gold earned, units purchased)

**Tests**
- `assets/scripts/serpent/tests/test_screens.lua`:
  - required labels present in view-model
  - buttons: retry, main menu
  - uses localization keys (`ui.serpent_victory_title`, `ui.serpent_game_over_title`, `ui.serpent_retry`, `ui.serpent_main_menu`)

**Manual Checklist**
- Full run start → victory without errors.
- Game over triggers at length 0 from combat deaths.
- Retry/menu performs full cleanup; re-entering SERPENT does not duplicate entities/handlers/timers.
- Determinism spot-check: same `SERPENT_SEED` yields identical shop offers and initial spawn positions.

---

## Commit Strategy
- Commit after each task group when its tests (and required manual checks) pass.
- Before committing: run `lua assets/scripts/tests/test_runner.lua assets/scripts/serpent/tests/` and repo-standard verification (UBS).