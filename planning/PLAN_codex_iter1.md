# Serpent — SNKRX-Style Survivor (Vertical Slice) Implementation Plan v1

## TL;DR
Build a new game mode (“Serpent”) where the player controls snake movement only; snake segments are auto-attacking units. Survive 20 waves with a shop between waves. Core deliverable is a **10–15 minute** complete run loop with **16 units**, **4 class synergies**, **2 bosses**, win/lose screens, and test coverage for all pure-logic modules.

---

## Goals, Non‑Goals, Guardrails

### Goals (Must Have)
- New **SERPENT** game mode selectable from main menu.
- Snake length **3–8** segments (purchase order defines position).
- Real-time arena combat; units auto-attack using attack speed + range.
- Shop between waves: buy, sell (50%), reroll (base 2g, +1g each reroll).
- Unit leveling: **3 copies → level up**, stats follow SNKRX doubling (cap level 3).
- 20 waves with scaling; bosses at **wave 10** (Swarm Queen) and **wave 20** (Lich King).
- HUD (HP total, gold, wave), synergy display, game over/victory screens.

### Non‑Goals (Must NOT Have)
- No items, interest, meta-progression, save/load, difficulty modes, controller support.
- No unit repositioning within the snake.
- Placeholder visuals only; use existing UI primitives/components.
- No complex abilities beyond basic damage/heal; specials may be stubbed/deferred (see Appendix).

---

## Source of Truth (Numeric Appendix)

### Classes (4)
| Class | 2-Unit Synergy | 4-Unit Synergy |
|---|---|---|
| Warrior | +20% attack damage | +40% attack damage, +20% HP |
| Mage | +20% spell damage | +40% spell damage, -20% cooldown |
| Ranger | +20% attack speed | +40% attack speed, +20% range |
| Support | Heal snake 5 HP/sec | Heal 10 HP/sec, +10% all stats |

### Units (16; cost = tier × 3g)
Tier 1 (3g, waves 1+): Soldier (W), Apprentice (M), Scout (R), Healer (S)  
Tier 2 (6g, waves 5+): Knight (W), Pyromancer (M), Sniper (R), Bard (S)  
Tier 3 (12g, waves 10+): Berserker (W), Archmage (M), Assassin (R), Paladin (S)  
Tier 4 (20g, waves 15+): Champion (W), Lich (M), Windrunner (R), Angel (S)

(Use the exact base stats/specials already embedded in `planning/PLAN_v0.md` unless re-specified elsewhere.)

### Enemies (11)
(Use the exact base stats/specials already embedded in `planning/PLAN_v0.md`.)

### Wave Scaling
```lua
Enemies_per_Wave = 5 + Wave * 2
Enemy_HP_Multiplier = 1 + Wave * 0.1
Enemy_Damage_Multiplier = 1 + Wave * 0.05
Gold_per_Wave = 10 + Wave * 2
```

### Unit Level Scaling (cap level 3)
```lua
HP = Base_HP * 2^(Level - 1)
Attack = Base_Attack * 2^(Level - 1)
```

### Shop Tier Odds
(Use the exact table already embedded in `planning/PLAN_v0.md`.)

---

## Architecture (Testability First)

### Directory Layout
- `assets/scripts/serpent/` (all Serpent code)
  - `serpent_main.lua` (mode entrypoint: init/update/cleanup)
  - `data/` (`units.lua`, `enemies.lua`)
  - `ui/` (HUD, shop UI, synergy UI, end screens)
  - `bosses/` (boss logic)
  - `tests/` (pure logic tests)

### Pure Logic vs Runtime Adapters
**Pure logic (unit tested; no engine globals):**
- `serpent/data/*.lua` (tables)
- `serpent/synergy_system.lua`
- `serpent/wave_config.lua`
- `serpent/serpent_shop.lua`
- `serpent/snake_logic.lua`
- `serpent/auto_attack_logic.lua`
- `serpent/unit_factory.lua`
- Boss logic modules should expose pure functions where feasible.

**Runtime-only (manual verification; thin):**
- `serpent/snake_controller.lua` + `serpent/snake_entity_adapter.lua`
- `serpent/auto_attack.lua`
- `serpent/combat_adapter.lua`
- `serpent/enemy_spawner_adapter.lua`
- `serpent/combat_manager.lua` (or coordinator module that wires engine + pure logic)
- `serpent/ui/*` render paths (state logic can be unit tested if isolated)

### Required Public Entrypoints
- `serpent/serpent_main.lua` exports:
  - `init()`, `update(dt)`, `cleanup()`
  - `init()` must be **idempotent** (call `cleanup()` first if needed).
- Serpent must own a single handler group (signal_group) for cleanup safety.

---

## Engine Integration Contract (Implementation-Ready)

### Add New Game State + Menu Entry
Make the minimal changes necessary to `assets/scripts/core/main.lua` to:
- Add `GAMESTATE.SERPENT`.
- `require("serpent.serpent_main")` at top-level.
- In `changeGameState(newState)`, call `Serpent.init()` when entering SERPENT.
- Ensure `Serpent.update(dt)` is called in the main update loop **only when not paused** and only in SERPENT state (do not duplicate existing pause guards).
- Add a “Serpent” button in the main menu that calls `changeGameState(GAMESTATE.SERPENT)`.

### Physics/Collision Tags (Serpent must do its own init)
Because SERPENT bypasses main gameplay initialization, Serpent init must ensure required collision tags exist before enabling masks/callbacks:
- Create a dedicated snake segment collision tag (e.g., `serpent_segment`).
- Ensure enemy tag exists (reuse existing constant tag if present).
- Enable collision between `serpent_segment` and `enemy`.
- Register contact callbacks for contact damage.

### Cleanup Contract
`Serpent.cleanup()` must:
- Destroy all Serpent-created entities.
- Remove all Serpent signal handlers via the owned signal_group cleanup.
- Clear references to combat context / runtime state so re-entry does not duplicate entities or handlers.

---

## Testing Standard

### Test File Header (required)
Every Serpent test file must begin with:
```lua
package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"
local t = require("tests.test_runner")
```

### Running Tests
Preferred (independent of runner flags):
```bash
set -e
for f in assets/scripts/serpent/tests/test_*.lua; do lua "$f"; done
```

---

## Execution Strategy (Parallelizable)

### Parallel Waves (high-level)
- Wave A: Tasks 1, 2, 5
- Wave B: Tasks 3, 4, 6
- Wave C: Tasks 7, 8, 9
- Wave D: Tasks 10, 11, 12
- Wave E: Tasks 13, 14, 15
- Wave F: Tasks 16, 17, 18

---

## Tasks (Implementation Checklist + Acceptance Criteria)

### Task 1 — Mode Skeleton + Core Integration
**Deliverables**
- `assets/scripts/serpent/serpent_main.lua` with `init/update/cleanup`
- Folder structure: `serpent/data`, `serpent/ui`, `serpent/bosses`, `serpent/tests`
- Core wiring in `assets/scripts/core/main.lua` (GAMESTATE + menu + update hook)

**Acceptance**
- From repo root, `lua -e "package.path=package.path..';./assets/scripts/?.lua;./assets/scripts/?/init.lua'; require('serpent.serpent_main')"` succeeds.
- Running the game: main menu shows “Serpent”; entering Serpent creates no errors; exiting to menu does not leak (re-entering does not duplicate).

---

### Task 2 — Unit Data (16)
**Deliverables**
- `assets/scripts/serpent/data/units.lua` (exact 16 units, 4/class, correct costs)

**Tests**
- `assets/scripts/serpent/tests/test_units.lua`: counts, class distribution, cost=tier*3.

---

### Task 3 — Snake Movement (Logic + Runtime Adapter)
**Deliverables**
- `serpent/snake_logic.lua` (pure: add/remove rules, min/max constraints, death vs sell removal)
- `serpent/snake_entity_adapter.lua` (runtime: create segment entities, steering setup)
- `serpent/snake_controller.lua` (runtime coordinator: input → head steer → pursuit chain)

**Tests**
- `assets/scripts/serpent/tests/test_snake_logic.lua`:
  - create N units
  - add up to max 8
  - sell removal blocked below 3
  - death removal allowed below 3; game over at 0

**Manual**
- Snake spawns (default 4 segments), moves with WASD/arrows, spacing stable, no jitter.

---

### Task 4 — Synergy System (Pure)
**Deliverables**
- `serpent/synergy_system.lua` with `calculate(class_list) -> structured bonuses`
- Bonuses represented as fractions (0.20) and levels (0/1/2)

**Tests**
- `assets/scripts/serpent/tests/test_synergy_system.lua`: thresholds at 2/4, correct values.

---

### Task 5 — Enemy Data (11)
**Deliverables**
- `assets/scripts/serpent/data/enemies.lua` with 11 enemies incl. 2 bosses.

**Tests**
- `assets/scripts/serpent/tests/test_enemies.lua`: counts and required ids exist.

---

### Task 6 — Wave Config (20)
**Deliverables**
- `assets/scripts/serpent/wave_config.lua`
  - Either explicit 20-wave table or deterministic generator that yields 20 waves
  - Helper functions for multipliers + enemy counts + gold

**Tests**
- `assets/scripts/serpent/tests/test_wave_config.lua`: 20 waves, bosses at 10/20, scaling math.

---

### Task 7 — Auto-Attack (Logic + Runtime Coordinator)
**Deliverables**
- `serpent/auto_attack_logic.lua` (pure: cooldown math, nearest-in-range)
- `serpent/auto_attack.lua` (runtime: reads positions, applies damage via adapter)

**Tests**
- `assets/scripts/serpent/tests/test_auto_attack_logic.lua`

**Manual**
- Units attack at correct cadence; only targets in range.

---

### Task 8 — Shop System (Pure)
**Deliverables**
- `assets/scripts/serpent/serpent_shop.lua`
  - offerings generation with tier odds by wave
  - buy/sell/reroll rules and gold accounting

**Tests**
- `assets/scripts/serpent/tests/test_serpent_shop.lua`: offerings size, odds boundaries, gold spend/refund, reroll cost increments.

---

### Task 9 — Unit Factory + Leveling (Pure + Runtime glue as needed)
**Deliverables**
- `assets/scripts/serpent/unit_factory.lua`
  - create unit instance from unit id
  - level up math (cap 3)
  - combine 3 copies into next level

**Tests**
- `assets/scripts/serpent/tests/test_unit_factory.lua`: base stats, doubling, cap, combine result.

---

### Task 10 — Combat Integration (Runtime Coordinator)
**Deliverables**
- `assets/scripts/serpent/combat_adapter.lua` (bridge to Effects / stats objects)
- `assets/scripts/serpent/combat_manager.lua` (runtime coordinator)
  - applies auto-attack damage
  - contact damage callbacks (with per-pair cooldown)
  - removes dead units from snake immediately (gap closes)
  - applies synergy effects at appropriate refresh points (e.g., on purchase/sell/level-up and at wave start)

**Tests**
- If any pure logic is extracted (recommended), add `test_combat_*` to validate calculations/events without engine.

**Manual**
- Enemies collide with segments → segment takes damage; unit death removes segment; game over at 0.

---

### Task 11 — Wave Director (Pure + Runtime Spawner)
**Deliverables**
- `assets/scripts/serpent/serpent_wave_director.lua` (pure: wave progression, spawn specs, gold rewards)
- `assets/scripts/serpent/enemy_spawner_adapter.lua` (runtime: spawn from specs into engine + combat context)

**Tests**
- `assets/scripts/serpent/tests/test_serpent_wave_director.lua`: wave start, completion detection via hp==0, gold award, boss spec presence.

**Manual**
- Wave completes only when all enemies dead; transitions to shop.

---

### Task 12 — Shop UI (View Model + Render)
**Deliverables**
- `assets/scripts/serpent/ui/shop_ui.lua`
  - view-model state methods testable without engine
  - `render()` uses existing UI DSL

**Tests**
- `assets/scripts/serpent/tests/test_shop_ui.lua`: offering slots, affordability logic, reroll label.

**Manual**
- 5 offerings visible; buy/sell/reroll/ready works; gold updates correctly.

---

### Task 13 — Synergy UI
**Deliverables**
- `assets/scripts/serpent/ui/synergy_ui.lua`

**Tests**
- `assets/scripts/serpent/tests/test_synergy_ui.lua`: 4 classes shown; levels render from provided synergy data.

**Manual**
- Synergy display updates after purchases/sells/combines.

---

### Task 14 — HUD (HP/Gold/Wave)
**Deliverables**
- `assets/scripts/serpent/ui/hud.lua`
  - HP displayed as sum(current)/sum(max) over living units

**Tests**
- `assets/scripts/serpent/tests/test_hud.lua`: formatting and basic state updates.

**Manual**
- HUD updates live during combat and shop.

---

### Task 15 — Bosses
**Deliverables**
- `assets/scripts/serpent/bosses/swarm_queen.lua` (spawn 5 slimes/10s)
- `assets/scripts/serpent/bosses/lich_king.lua` (raise dead → skeletons)

**Tests**
- `assets/scripts/serpent/tests/test_bosses.lua`: base HP and mechanic outputs.

**Manual**
- Boss waves trigger at 10 and 20; mechanics observable; run remains finishable.

---

### Task 16 — End Screens
**Deliverables**
- `assets/scripts/serpent/ui/game_over_screen.lua`
- `assets/scripts/serpent/ui/victory_screen.lua`
- Run stats model (waves, gold earned, units purchased) tracked in serpent_main

**Tests**
- `assets/scripts/serpent/tests/test_screens.lua`: required text + buttons exist.

**Manual**
- Victory after wave 20; game over when snake length 0; retry and main menu work; cleanup correct.

---

### Task 17 — Balance Pass (Manual)
**Targets**
- Wave 1 clears in <30s (typical play)
- Around ~80 gold by wave 5 (order-of-magnitude sanity)
- Full run 10–15 minutes (typical play)
- No single unit tier dominates unreasonably early

**Artifacts**
- Record tuning changes in a short “balance notes” section (in code comments or a small doc file, your choice).

---

### Task 18 — Final Integration Verification (Manual + Perf)
**Checklist**
- Full run from start → victory works without errors.
- Re-enter Serpent from menu multiple times without duplication/leaks.
- Stress: late wave enemy counts do not tank frame time (target <16ms typical).

---

## Commit Strategy (Atomic, Verifiable)
- Commit after each task group when its tests/manual checks pass.
- Before each commit: run Serpent tests and the repo’s standard verification script(s) (e.g., UBS if required by repo conventions).

---

## Appendix — Ability Scope (Vertical Slice)
- Implemented: Healer adjacent heal (10 HP/sec).
- Stubbed (acceptable): simple crit stat, flat DR, basic DoT, flat aura bonus; AoE/pierce/extra arrows/cleave as single-target.
- Deferred: frenzy per kill, positional/backstab, divine shield, pierce, resurrect.