# Vertical Slice Status Report

**Last Updated:** 2025-12-09
**Reference:** [vertical_slice_plan.md](vertical_slice_plan.md)

---

## Executive Summary

| Category | Complete | Partial | Missing |
|----------|----------|---------|---------|
| Core Systems | 7 | 2 | 0 |
| Content | 1 | 1 | 2 |
| UX/Polish | 1 | 3 | 2 |
| **Overall Progress** | **~70%** | | |

The majority of systems infrastructure is complete. Remaining work focuses on content creation (enemies, map), integration testing, and polish.

---

## Phase 1: Core System Unblocks

### Projectiles Visible/Moving
- **Status:** :white_check_mark: COMPLETE
- **Evidence:** [projectile_system.lua](../../assets/scripts/combat/projectile_system.lua) (1943 lines)
- **Features:**
  - Movement types: straight, homing, orbital, arc, custom
  - Collision behaviors: destroy, pierce, bounce, explode, pass-through, chain
  - Lifetime management (time, distance, hit-count)
  - Physics integration with Chipmunk2D
  - Event hooks (OnSpawn, OnHit, OnDestroy)

### Physics/Transform Stability
- **Status:** :warning: PARTIAL - Known bugs remain
- **Known Issues:**
  - [ ] Physics-transform sync jitter (`transform.cpp`)
  - [ ] Drag & drop unreliability with physics bodies
  - [ ] Collision shape position drift during drag
- **Files:** `src/ecs/components/transform.cpp`, `src/systems/physics/physics_world.cpp`

### LDtk Map with Colliders
- **Status:** :warning: FRAMEWORK ONLY - Not integrated
- **What Exists:**
  - [ldtk_quickstart.lua](../../assets/scripts/examples/ldtk_quickstart.lua) - Integration example
  - LDtk configuration loading
  - Entity spawner hook system
  - IntGrid layer support
- **What's Missing:**
  - [ ] Actual game map created in LDtk
  - [ ] Map integrated into main game loop
  - [ ] Spawn points defined
  - [ ] Collision shapes from tilemap

### Reset Run Debug Action
- **Status:** :x: NOT IMPLEMENTED
- **Requirement:** Fully clear state and reload scripts for fast iteration

### Batching vs Non-Batching Render Path
- **Status:** :question: NEEDS DECISION
- **Requirement:** Pick one approach for the slice

---

## Phase 2: Wand Execution + Card Bridge

### WandExecutor System
- **Status:** :white_check_mark: COMPLETE
- **Evidence:** 6605 lines across multiple files
- **Core Files:**
  - [wand_executor.lua](../../assets/scripts/wand/wand_executor.lua) (1342 lines)
  - [wand_actions.lua](../../assets/scripts/wand/wand_actions.lua) (757 lines)
  - [wand_triggers.lua](../../assets/scripts/wand/wand_triggers.lua) (467 lines)
  - [wand_modifiers.lua](../../assets/scripts/wand/wand_modifiers.lua) (576 lines)

### Triggers
- **Status:** :white_check_mark: COMPLETE
- **Implemented:**
  - Timer-based: `every_N_seconds`, `on_cooldown`
  - Event-based: `on_player_attack`, `on_bump_enemy`, `on_dash`, `on_distance_traveled`
  - Condition-based: `on_low_health`, `on_pickup`

### Actions
- **Status:** :white_check_mark: COMPLETE (core), :warning: PARTIAL (alternative mechanics)
- **Working:** fire_basic_bolt, piercing_line, projectile spawning
- **TODOs in code:**
  - [ ] Heal function
  - [ ] Freeze status application
  - [ ] Chain projectile spawning
  - [ ] Hazard entity creation
  - [ ] Summon mechanics
  - [ ] Teleport mechanics
  - [ ] Shield mechanics

### Modifiers
- **Status:** :white_check_mark: COMPLETE
- **Implemented:** double_effect, projectile_pierces, speed_up, damage modifiers

### Card Validation
- **Status:** :white_check_mark: COMPLETE
- **Features:** Slot caps, trigger/action limits, stacking z-order

### Card-to-Spell Conversion
- **Status:** :white_check_mark: COMPLETE
- **Files:**
  - [card_upgrade_system.lua](../../assets/scripts/wand/card_upgrade_system.lua) (555 lines)
  - [card_synergy_system.lua](../../assets/scripts/wand/card_synergy_system.lua) (534 lines)

### Smoke Test (trigger → bolt → damage)
- **Status:** :warning: NEEDS VERIFICATION
- **Action:** Run actual playtest to confirm end-to-end flow

---

## Phase 3: Combat Loop + Progression

### Wave Manager + Spawner
- **Status:** :white_check_mark: COMPLETE
- **Files:**
  - [wave_manager.lua](../../assets/scripts/combat/wave_manager.lua) (517 lines)
  - [enemy_spawner.lua](../../assets/scripts/combat/enemy_spawner.lua) (567 lines)
- **Features:**
  - Wave configuration loading
  - Difficulty scaling per wave
  - Spawn patterns: instant, timed, budget-based, survival
  - Spawn point types: random, fixed, off-screen, around player, circle
  - Reward calculation (gold, XP)

### State Machine
- **Status:** :white_check_mark: COMPLETE
- **File:** [combat_state_machine.lua](../../assets/scripts/combat/combat_state_machine.lua) (566 lines)
- **States:**
  - INIT → WAVE_START → SPAWNING → COMBAT → VICTORY → INTERMISSION → (loop or GAME_WON)
  - DEFEAT → GAME_OVER

### XP/Gold Drops
- **Status:** :white_check_mark: COMPLETE
- **Evidence:** Reward system integrated in wave_manager

### Shop System
- **Status:** :white_check_mark: COMPLETE
- **File:** [shop_system.lua](../../assets/scripts/core/shop_system.lua) (633 lines)
- **Features:**
  - 5-slot card offerings
  - Rarity weighting (Common 60%, Uncommon 30%, Rare 9%, Legendary 1%)
  - Interest system (1g per 10g, capped at 5g)
  - Lock system for offerings
  - Escalating reroll costs
  - Card removal service

### Level-Up System
- **Status:** :warning: PARTIAL
- **What Exists:** [level_up_screen.lua](../../assets/scripts/ui/level_up_screen.lua)
- **What's Missing:**
  - [ ] Verify stat choices (+physique/+cunning/+spirit) are connected
  - [ ] Test stat application to player entity

### HUD Components
- **Status:** :white_check_mark: COMPLETE
- **Files:**
  - [currency_display.lua](../../assets/scripts/ui/currency_display.lua) - Gold/XP
  - [wand_cooldown_ui.lua](../../assets/scripts/ui/wand_cooldown_ui.lua) - Cooldowns
  - [tag_synergy_panel.lua](../../assets/scripts/ui/tag_synergy_panel.lua) - Tag thresholds
  - [cast_feed_ui.lua](../../assets/scripts/ui/cast_feed_ui.lua) - Cast history
  - [message_queue_ui.lua](../../assets/scripts/ui/message_queue_ui.lua) - Notifications

### Death/Victory Screens
- **Status:** :warning: PARTIAL
- **What Exists:** States in state machine (DEFEAT, GAME_WON)
- **What's Missing:**
  - [ ] Verify UI screens exist and display properly
  - [ ] Wire screens to state transitions

### Stability (5 crash-free runs)
- **Status:** :x: NOT TESTED
- **Action:** Perform QA sweep once integration complete

---

## Phase 4: Content + UX + Release

### Enemy Types
- **Status:** :x: MISSING
- **Required for Slice:**
  - [ ] Charger enemy (melee rush)
  - [ ] Ranged enemy (shoots projectiles)
  - [ ] Hazard dropper (leaves ground hazards)
  - [ ] 1 Elite/Boss pattern
- **Note:** Spawner framework exists, needs enemy definitions

### Controller Polish
- **Status:** :warning: PARTIAL
- **What Exists:** Controller navigation framework (30k+ LOC)
- **What's Missing:**
  - [ ] Cursor snaps to selection
  - [ ] Disable mouse when controller active
  - [ ] Trigger area single-card restriction
  - [ ] Main menu fully navigable

### Tooltip Readability
- **Status:** :warning: BUGS EXIST
- **Known Issues:**
  - [ ] Text overflow in tooltips
  - [ ] Background translucency regression

### Broken Shaders
- **Status:** :warning: KNOWN ISSUES
- **Avoid in Slice:**
  - `starry_tunnel` - broken
  - `item_glow` - blending issues
  - `3d_skew` on cards - causes player invisibility

### Audio Pass
- **Status:** :x: NOT STARTED
- **Required:**
  - [ ] Dash sound variations
  - [ ] Loot pickup sounds
  - [ ] Volume normalization
  - [ ] Toggle for tick sounds

### Performance/Memory
- **Status:** :x: KNOWN BUG
- **Issues:**
  - [ ] WASM memory leak
  - [ ] Card drag performance
  - [ ] Entity/timer cleanup on wave end

### Build Scripts
- **Status:** :white_check_mark: COMPLETE
- **Available:** `just build-debug`, `just build-release`, `just build-web`

### Store Assets
- **Status:** :x: NOT STARTED
- **Required:**
  - [ ] 5-7 screenshots
  - [ ] 30-45s gameplay clip
  - [ ] "How to play" blurb

---

## Priority Action Items

### Immediate (This Week)

1. **Create LDtk Map**
   - Design simple arena with colliders
   - Define spawn points for enemies
   - Integrate into game loop

2. **Define Enemy Types**
   - Create 3 basic enemies in data files
   - Implement AI behaviors
   - Test with spawner

3. **End-to-End Integration Test**
   - Start game → spawn enemies → cast spells → deal damage → clear wave
   - Document any breaks in the loop

### Short-Term (Next 2 Weeks)

4. **Fix Critical Bugs**
   - Physics/transform jitter
   - Card z-order on first overlap
   - WASM memory leak

5. **Complete Level-Up Flow**
   - Verify stat selection works
   - Test stat application

6. **Add Reset Run Debug Action**
   - Quick iteration for testing

### Pre-Release

7. **Controller Polish**
8. **Audio Pass**
9. **5 Crash-Free Runs QA**
10. **Store Assets**

---

## Test Checklist

### Core Loop
- [ ] Game starts without crash
- [ ] Player can move (WASD/controller)
- [ ] Player can dash
- [ ] Wand fires automatically on trigger
- [ ] Projectiles spawn and move
- [ ] Projectiles collide with enemies
- [ ] Enemies take damage and die
- [ ] XP/gold drops on enemy death
- [ ] Wave completes when all enemies dead
- [ ] Shop appears between waves
- [ ] Can buy/sell cards in shop
- [ ] Level-up appears at XP threshold
- [ ] Can select stat on level-up
- [ ] Boss/elite spawns on final wave
- [ ] Victory screen on boss defeat
- [ ] Death screen when player HP = 0
- [ ] Can restart from death/victory

### Stability
- [ ] Run 1: No crash
- [ ] Run 2: No crash
- [ ] Run 3: No crash
- [ ] Run 4: No crash
- [ ] Run 5: No crash

---

## File References

| System | Primary File(s) | Lines |
|--------|-----------------|-------|
| Projectiles | `assets/scripts/combat/projectile_system.lua` | 1943 |
| Wand Executor | `assets/scripts/wand/wand_executor.lua` | 1342 |
| Combat | `assets/scripts/combat/combat_system.lua` | 5866 |
| Wave Manager | `assets/scripts/combat/wave_manager.lua` | 517 |
| Enemy Spawner | `assets/scripts/combat/enemy_spawner.lua` | 567 |
| State Machine | `assets/scripts/combat/combat_state_machine.lua` | 566 |
| Shop | `assets/scripts/core/shop_system.lua` | 633 |
| Cards Data | `assets/scripts/data/cards.lua` | 963 |
| Projectiles Data | `assets/scripts/data/projectiles.lua` | 177 |
| Main Gameplay | `assets/scripts/core/gameplay.lua` | 8860 |

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
