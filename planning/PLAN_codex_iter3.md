# Serpent — SNKRX-Style Survivor (Vertical Slice) Implementation Plan v3

## TL;DR
Add a new selectable game mode (**SERPENT**) where the player only steers a snake; each segment is an auto-attacking unit. Complete run loop: **20 waves** with a **shop between waves**, **16 units**, **4 class synergies**, **2 bosses**, and **win/lose screens**, with deterministic RNG for all “random” outputs and unit tests for all pure-logic modules.

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
  - Stat scaling (from design): `HP = base_hp * 2^(level-1)`, `Attack = base_attack * 2^(level-1)`.
- Synergies (from design) at **2/4 thresholds** for Warrior/Mage/Ranger/Support.
- Bosses:
  - **Wave 10**: Swarm Queen
  - **Wave 20**: Lich King
- HUD (HP, gold, wave), synergy display, game over/victory screens.

### Non‑Goals (Must NOT Have)
- No items, interest, meta-progression, save/load, difficulty modes, controller support.
- No manual repositioning within the snake.
- No advanced enemy specials beyond bosses (enemy “special” strings from data are cosmetic unless explicitly implemented below).
- Placeholder visuals; use existing UI primitives/components.

### Guardrails
- No engine globals inside pure modules.
- All randomness must be injectable for deterministic tests.
- Keep Serpent-owned entities/timers/signals isolated and fully cleaned up on exit.

---

## Numeric Source of Truth (Explicit)

### Units / Enemies Base Stats
- All unit and enemy base stat tables mirror `planning/PLAN_v0.md` exactly:
  - Units: **16 total**, 4 per class (Warrior/Mage/Ranger/Support)
  - Enemies: **11 total**, including bosses

### Synergy Bonuses (from design)
| Class | 2-Unit | 4-Unit |
|---|---:|---:|
| Warrior | +20% attack damage | +40% attack damage, +20% HP |
| Mage | +20% spell damage | +40% spell damage, -20% cooldown |
| Ranger | +20% attack speed | +40% attack speed, +20% range |
| Support | Heal snake 5 HP/sec | Heal snake 10 HP/sec, +10% all stats |

Notes:
- Synergy bonuses stored as fractions (e.g., `0.20`).
- Support heal applies to ALL living segments equally each tick.

### Wave Scaling (from design)
```lua
Enemies_per_Wave = 5 + Wave * 2
Enemy_HP_Multiplier = 1 + Wave * 0.1
Enemy_Damage_Multiplier = 1 + Wave * 0.05
Gold_per_Wave = 10 + Wave * 2
```

### Shop Tier Odds (from design)
| Wave | Tier 1 | Tier 2 | Tier 3 | Tier 4 |
|---|---:|---:|---:|---:|
| 1-5 | 70% | 25% | 5% | 0% |
| 6-10 | 55% | 30% | 13% | 2% |
| 11-15 | 35% | 35% | 22% | 8% |
| 16-20 | 20% | 30% | 33% | 17% |

### Movement Tuning Constants (source of truth for v-slice)
```lua
local MOVEMENT_CONFIG = {
  MAX_SPEED = 180,        -- px/sec (head)
  MAX_FORCE = 400,
  MAX_ANGULAR = 6.0,      -- rad/sec
  FRICTION = 0.92,

  SEGMENT_SPACING = 40,   -- px between segment centers
  SEEK_DISTANCE = 100,    -- px ahead of head for seek target

  ARENA_WIDTH = 800,
  ARENA_HEIGHT = 600,
  ARENA_PADDING = 50,
}
```

### Combat Constants (v-slice)
- Contact damage cooldown: `CONTACT_DAMAGE_COOLDOWN_SEC = 0.5`
- Damage/HP rounding: all HP and damage are integers; apply modifiers in float then `math.floor(final + 0.00001)`.

---

## Implementation Contracts (Make Ambiguity Impossible)

### Core Mode State Machine
`assets/scripts/serpent/serpent_main.lua` owns a state machine:
- Initial: `MODE_STATE.SHOP` for `wave = 1`, `gold = STARTING_GOLD`
- `SHOP` → `COMBAT` when player presses “Ready”
- `COMBAT` → `SHOP` when wave director reports “wave cleared” and `wave < 20`
  - On transition: `gold += Gold_per_Wave(wave)`, then `wave += 1`, then `enter_shop(wave, gold, rng)`
- `COMBAT` → `VICTORY` when wave 20 cleared
- Any state → `GAME_OVER` when snake length reaches 0

Constants:
- `STARTING_GOLD = 10`
- Starting snake (head→tail): `soldier`, `apprentice`, `scout` (all level 1)

### Canonical Data Shapes (Pure Logic)
All pure modules accept/return plain Lua tables.

**UnitDef** (`assets/scripts/serpent/data/units.lua`)
- `id` (string), `class` (`"Warrior"|"Mage"|"Ranger"|"Support"`), `tier` (1..4), `cost` (int)
- `base_hp`, `base_attack`, `range`, `atk_spd` (numbers)
- `special_id` (string or nil)

**UnitInstance**
- `instance_id` (int, monotonic)
- `def_id` (string), `level` (1..3)
- `hp`, `hp_max`, `attack`, `range`, `atk_spd`
- `cooldown` (seconds until next attack, `>= 0`)
- `acquired_seq` (int, monotonic by buys)
- `special_state` (table; per-special runtime state, pure-managed)

**SnakeState**
- `segments` = array of `UnitInstance` in head→tail order
- `min_len=3`, `max_len=8`

**EnemyInstance** (pure-facing shape)
- `enemy_id` (int), `def_id` (string), `hp`, `hp_max`, `damage`, `speed`, `x`, `y`
- `tags` (table; e.g., `{ boss=true }`)

### Combine + Ordering Rules (Critical)
- Buying always appends a new level-1 instance to the tail **before** combine checks.
- Combine detection:
  - For each `def_id`, find groups of **3 instances with the same `level`**.
  - Combine **the 3 lowest `acquired_seq`** among eligible instances for that `def_id` + level.
- Result:
  - Replace the earliest (lowest `acquired_seq`) of the 3 with an upgraded instance (`level+1`).
  - Remove the other 2 instances from the snake.
  - Upgraded instance keeps the position of the kept instance.
  - Upgraded instance keeps `acquired_seq` of the kept instance; `instance_id` remains the kept instance’s `instance_id`.
- Purchase at max length:
  - Allowed only if `(append + all resulting combines)` ends with length `<= max_len`.
  - Otherwise reject purchase (no gold spent, no state changes).

### Gold + Rounding Rules
- Costs are integers.
- Sell refund is `math.floor(total_paid_for_instance * 0.5)`.
- `total_paid_for_instance = unit_def.cost * (3^(level-1))` (because level-up consumes 3 copies each step).

### Synergy Application Rules
Synergy is derived from current snake segments (post-combine) and produces explicit modifiers:
- Warrior: `attack_mult`, and at 4 also `hp_mult`
- Mage: `spell_mult` (applied as `attack_mult` for Mage units in v-slice), and at 4 also `cooldown_mult` (0.8)
- Ranger: `atk_spd_mult`, and at 4 also `range_mult`
- Support: `regen_hp_per_sec_total`, and at 4 also `all_stats_mult` (1.10)

Application points:
- On entering combat
- After buy/sell/combine (shop only)
- At wave start

### Specials (Unit Specials Contract)
Implement the following specials in v-slice; all others are defined but are **no-ops** (explicitly documented in code/tests):
- `healer_adjacent_regen`: heals adjacent segments `10 HP/sec` each (clamped)
- `knight_block`: segment takes `20%` less incoming damage
- `sniper_crit`: `20%` chance to deal `2x` damage (uses injected RNG)
- `bard_adjacent_atkspd`: adjacent segments gain `+10% atk_spd` (multiplicative)
- `berserker_frenzy`: per kill by this instance, gain `+5% attack` (stacking; persists within run)
- `paladin_divine_shield`: once per wave, first incoming damage to this segment is reduced to `0`

Specials system rules:
- Specials must be deterministic with injected RNG/time.
- Specials must not mutate engine state; they emit events/modifiers consumed by combat/shop coordinators.

### RNG (Deterministic Tests)
All randomness goes through injected `rng`:
- `rng.int(min, max)` inclusive
- `rng.float()` in `[0,1)`
- Tests supply deterministic stubs (fixed sequence).

---

## Repo Integration (Concrete Touchpoints)

### Game State Integration (`assets/scripts/core/main.lua`)
- Add `GAMESTATE.SERPENT`.
- On enter SERPENT: call `Serpent.init()`.
- On leave SERPENT: call `Serpent.cleanup()` before transition.
- In `main.update(dt)`: if `GAMESTATE.SERPENT` and not paused, call `Serpent.update(dt)`.
- Do not duplicate or break existing pause guards.

### Menu Entry
Add a “Serpent” button alongside existing main menu buttons, wired to `changeGameState(GAMESTATE.SERPENT)`.

### Serpent Ownership + Cleanup
- Serpent owns:
  - entities it spawns
  - collision tags/masks it enables
  - event handlers/timers registered through a single “serpent” group/tag
- `Serpent.cleanup()` is idempotent.

---

## Directory Layout
All Serpent code under `assets/scripts/serpent/`:
- `serpent_main.lua`
- Data: `data/units.lua`, `data/enemies.lua`, `data/shop_odds.lua`
- Pure logic:
  - `snake_logic.lua`
  - `unit_factory.lua`
  - `combine_logic.lua` (optional split if it keeps files smaller)
  - `synergy_system.lua`
  - `specials_system.lua`
  - `serpent_shop.lua`
  - `wave_config.lua`
  - `auto_attack_logic.lua`
  - `serpent_wave_director.lua`
  - `combat_logic.lua` (pure coordinator for attack + contact + specials + synergy)
- Runtime adapters:
  - `snake_entity_adapter.lua`, `snake_controller.lua`
  - `enemy_spawner_adapter.lua`
  - `combat_adapter.lua`
  - `auto_attack.lua`
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

### How to Run (Repo-Standard)
```bash
lua assets/scripts/tests/test_runner.lua assets/scripts/serpent/tests/
```

### Testability Rule
- Pure modules: unit tests required.
- UI: tests cover view-model/pure helpers only.
- Runtime adapters: validated via manual checklist.

---

## Execution Strategy (Parallelizable With Dependencies)

### Parallel Work Packs
- Pack A (Data): units/enemies/shop odds + tests
- Pack B (Pure Core): snake/unit factory/combines + tests
- Pack C (Pure Combat): synergy/specials/auto-attack/combat logic + tests
- Pack D (Pure Waves/Shop): wave config + wave director + shop logic + tests
- Pack E (Runtime Wiring): mode skeleton, movement, spawner, combat adapter, collisions
- Pack F (UI): shop/synergy/hud/screens (after their view-model inputs exist)
- Pack G (Bosses): boss pure + spawner integration (after wave director + spawner exist)

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
- Enter SERPENT from main menu without errors.
- Exit to main menu and re-enter SERPENT without duplicate spawns/handlers (manual observation).

---

### Task 2 — Unit Data (16) + Shop Odds Data
**Deliverables**
- `assets/scripts/serpent/data/units.lua` mirrors the 16 units in `planning/PLAN_v0.md`.
- `assets/scripts/serpent/data/shop_odds.lua` implements wave→tier odds table (1-5, 6-10, 11-15, 16-20).

**Tests**
- `assets/scripts/serpent/tests/test_units.lua`:
  - exactly 16 entries
  - 4 per class
  - `cost == tier * 3`
- `assets/scripts/serpent/tests/test_shop_odds.lua`:
  - correct odds per wave bracket; probabilities sum to 1.0.

---

### Task 3 — Enemy Data (11)
**Deliverables**
- `assets/scripts/serpent/data/enemies.lua` mirrors the 11 enemies in `planning/PLAN_v0.md` (including boss defs).

**Tests**
- `assets/scripts/serpent/tests/test_enemies.lua`:
  - exactly 11 entries
  - boss ids present

---

### Task 4 — Snake Core Logic (Pure)
**Deliverables**
- `assets/scripts/serpent/snake_logic.lua`:
  - `create_initial(units, min_len, max_len) -> SnakeState`
  - `can_sell(snake_state, instance_id) -> bool`
  - `remove_instance(snake_state, instance_id) -> SnakeState`
  - `is_dead(snake_state) -> bool`

**Tests**
- `assets/scripts/serpent/tests/test_snake_logic.lua`:
  - selling blocked if it would drop below 3
  - removal via death can drop below 3
  - length 0 marks dead

---

### Task 5 — Unit Factory + Combine Rules (Pure)
**Deliverables**
- `assets/scripts/serpent/unit_factory.lua`:
  - `create_instance(unit_def, instance_id, acquired_seq) -> UnitInstance(level=1)`
  - `recompute_stats(instance, unit_def, synergy_mods, special_mods) -> UnitInstance` (pure)
- `assets/scripts/serpent/serpent_combine.lua` (or in unit_factory):
  - `detect_and_apply_combines(snake_state, unit_defs) -> (snake_state, combine_events)`

**Tests**
- `assets/scripts/serpent/tests/test_unit_factory.lua`:
  - stat scaling matches `base * 2^(level-1)` and caps at 3
- `assets/scripts/serpent/tests/test_combines.lua`:
  - combine chooses lowest `acquired_seq` triple
  - kept slot preserved; other 2 removed
  - max-length purchase gating helper scenarios (used by shop tests)

---

### Task 6 — Synergy System (Pure)
**Deliverables**
- `assets/scripts/serpent/synergy_system.lua`:
  - `calculate(segments) -> synergy_state`
  - returns per-class `count`, `level` (0/1/2), and numeric modifiers

**Tests**
- `assets/scripts/serpent/tests/test_synergy_system.lua`:
  - thresholds at 2/4
  - modifier values match table in this plan

---

### Task 7 — Specials System (Pure)
**Deliverables**
- `assets/scripts/serpent/specials_system.lua`:
  - `get_passive_mods(segments, wave_ctx, rng) -> mods_by_instance_id`
  - `on_attack(event, ctx, rng) -> (event_or_nil, extra_events[])`
  - `on_damage_taken(event, ctx, rng) -> (event_or_nil, extra_events[])`
  - `tick(dt, ctx, rng) -> events[]` (for regen/shields per wave)

**Tests**
- `assets/scripts/serpent/tests/test_specials.lua`:
  - healer heals adjacent correctly
  - knight reduces damage by 20%
  - sniper crit triggers deterministically with stub RNG
  - bard buffs adjacent atk_spd
  - berserker stacks +5% attack per kill
  - paladin negates first hit per wave

---

### Task 8 — Wave Config (20) (Pure)
**Deliverables**
- `assets/scripts/serpent/wave_config.lua`:
  - `get_wave(wave_num) -> wave_spec` (enemy counts + allowed enemy pool + boss flag)
  - helpers implement scaling formulas exactly:
    - `enemy_count(wave)`, `hp_mult(wave)`, `dmg_mult(wave)`, `gold_reward(wave)`

**Tests**
- `assets/scripts/serpent/tests/test_wave_config.lua`:
  - waves 1..20 exist
  - bosses at 10 and 20
  - formulas match “Numeric Source of Truth”

---

### Task 9 — Shop System (Pure)
**Deliverables**
- `assets/scripts/serpent/serpent_shop.lua`:
  - `enter_shop(upcoming_wave, gold, rng) -> shop_state` (reroll_count reset; offers generated)
  - `reroll(shop_state, rng) -> shop_state` (updates offers; increments reroll_count; charges via delta output)
  - `can_buy(shop_state, slot, snake_state, gold) -> bool`
  - `buy(shop_state, slot, snake_state, gold, id_state) -> (shop_state, snake_state, gold, id_state, events[])`
  - `can_sell(snake_state, instance_id) -> bool`
  - `sell(snake_state, instance_id, gold, unit_defs) -> (snake_state, gold)`
- Shop offer rules:
  - `SHOP_SLOTS = 5`
  - Choose tier by odds table for `upcoming_wave`, then choose uniformly among units of that tier.

**Tests**
- `assets/scripts/serpent/tests/test_serpent_shop.lua`:
  - 5 offers
  - reroll cost increments (2,3,4,…) and resets each `enter_shop`
  - gold accounting and floor rounding
  - purchase rejection at max length without combines; acceptance when combine reduces length
  - sell refund equals `floor(cost * 3^(level-1) * 0.5)`

---

### Task 10 — Auto-Attack Logic (Pure) + Runtime Bridge
**Deliverables**
- `assets/scripts/serpent/auto_attack_logic.lua` (pure):
  - ticks cooldowns
  - selects nearest target in range (tie-break by lowest `enemy_id`)
  - emits attack events `{ attacker_instance_id, target_enemy_id, base_damage }`
- `assets/scripts/serpent/auto_attack.lua` (runtime):
  - maps runtime entities → pure inputs and applies events via adapter

**Tests**
- `assets/scripts/serpent/tests/test_auto_attack_logic.lua`:
  - cooldown cadence uses `atk_spd` as attacks/sec (`period = 1/atk_spd`)
  - nearest target selection and tie-breaker
  - out-of-range yields no attacks

---

### Task 11 — Combat Logic (Pure) + Runtime Combat Adapter
**Deliverables**
- `assets/scripts/serpent/combat_logic.lua` (pure):
  - applies synergy + specials modifiers to produced attack damage
  - emits damage events (unit→enemy) and contact damage events (enemy→unit)
  - contact damage uses `CONTACT_DAMAGE_COOLDOWN_SEC = 0.5` per (enemy, segment) pair
  - emits death events when hp reaches 0
- `assets/scripts/serpent/combat_adapter.lua` (runtime):
  - applies damage/heal to runtime actors/entities and returns updated hp snapshots

**Tests**
- `assets/scripts/serpent/tests/test_combat_logic.lua`:
  - synergy damage multipliers affect correct classes
  - support regen distributes evenly and clamps to hp_max
  - contact damage respects cooldown
  - death events emitted when hp <= 0

---

### Task 12 — Wave Director (Pure) + Runtime Spawner Adapter
**Deliverables**
- `assets/scripts/serpent/serpent_wave_director.lua` (pure):
  - tracks current wave, active enemies, and “wave cleared”
  - consumes enemy death notifications
  - outputs spawn specs `{ def_id, count, hp_mult, dmg_mult }`
- `assets/scripts/serpent/enemy_spawner_adapter.lua` (runtime):
  - spawns enemies with burst limiting (configurable spawn-per-second)

**Tests**
- `assets/scripts/serpent/tests/test_serpent_wave_director.lua`:
  - wave start/completion detection
  - boss waves spawn correct boss
  - gold reward is computed via `wave_config.gold_reward(wave)` (integration expectation)

---

### Task 13 — Runtime Movement (Snake Controller + Entity Adapter)
**Deliverables**
- `assets/scripts/serpent/snake_entity_adapter.lua` (runtime):
  - create/destroy segment entities from `SnakeState`
  - maintains head→tail order mapping to entities
- `assets/scripts/serpent/snake_controller.lua` (runtime):
  - input steering for head via `IsKeyDown` (WASD + arrows)
  - body follows via pursuit, spacing from `MOVEMENT_CONFIG`

**Manual Acceptance**
- Snake spawns with starting units (`soldier`, `apprentice`, `scout`) in correct order.
- Moves smoothly with stable spacing; no jitter or oscillation in typical play.

---

### Task 14 — Combat Runtime Integration + Collisions
**Deliverables**
- In `serpent_main.lua`:
  - configure collision tags/masks for `serpent_segment` vs `ENEMY` using existing engine patterns
  - register contact callbacks; implement per-pair cooldown table keyed by actors
  - on segment death: remove from snake state and despawn entity immediately; gaps close naturally by pursuit
  - game over on length 0

**Manual Acceptance**
- Enemy touching a segment deals damage once per 0.5s while overlapping (not every frame).
- Segment death removes that segment immediately and the chain closes.

---

### Task 15 — Shop UI (View-Model + Render)
**Deliverables**
- `assets/scripts/serpent/ui/shop_ui.lua`:
  - view-model helpers: slot labels, affordability, reroll label, sell enable/disable, ready enable
  - render with existing UI primitives
- UI interaction (explicit):
  - 5 offer buttons; click to buy
  - each segment row has a “Sell” button
  - “Reroll” and “Ready” buttons

**Tests**
- `assets/scripts/serpent/tests/test_shop_ui.lua`:
  - 5 slots
  - affordability logic
  - reroll label reflects cost/count
  - sell disabled when snake length == 3

---

### Task 16 — Synergy UI + HUD
**Deliverables**
- `assets/scripts/serpent/ui/synergy_ui.lua`
- `assets/scripts/serpent/ui/hud.lua`
  - HP shown as `sum(hp)/sum(hp_max)` across current segments

**Tests**
- `assets/scripts/serpent/tests/test_synergy_ui.lua`:
  - renders 4 classes, level display matches input
- `assets/scripts/serpent/tests/test_hud.lua`:
  - formatting helpers and hp aggregation

---

### Task 17 — Bosses (Wave 10/20)
**Deliverables**
- `assets/scripts/serpent/bosses/swarm_queen.lua`
  - `tick(state, dt) -> (state, events)` where events can request spawning `slime`
  - cadence: spawns `5 slimes` every `10.0s` while alive
- `assets/scripts/serpent/bosses/lich_king.lua`
  - `tick(state, dt) -> (state, events)` where events can request spawning `skeleton`
  - behavior: whenever any non-boss enemy dies, queue 1 skeleton spawn after `2.0s` (raised dead)
- Integrate boss events into wave director/spawner path.

**Tests**
- `assets/scripts/serpent/tests/test_bosses.lua`:
  - swarm queen spawn cadence deterministic under simulated time
  - lich king raises dead deterministically with fixed dt/time steps

---

### Task 18 — End Screens + Final Verification
**Deliverables**
- `assets/scripts/serpent/ui/game_over_screen.lua`
- `assets/scripts/serpent/ui/victory_screen.lua`
- Run stats tracked in `serpent_main.lua` (waves cleared, gold earned, units purchased)

**Tests**
- `assets/scripts/serpent/tests/test_screens.lua`:
  - required text labels present
  - buttons: retry, main menu

**Manual Checklist**
- Full run start → victory without errors.
- Game over triggers at length 0 from combat deaths.
- Retry/menu performs full cleanup; re-entering SERPENT does not duplicate entities/handlers.
- Late waves: burst limiting prevents obvious frame collapse (target <16ms typical on dev machine).

---

## Commit Strategy
- Commit after each task group when its tests (and required manual checks) pass.
- Before committing: run `lua assets/scripts/tests/test_runner.lua assets/scripts/serpent/tests/` and repo-standard verification (UBS).