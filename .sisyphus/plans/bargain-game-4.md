# Game #4: "Bargain" - Faustian Deal Roguelike Implementation Plan

## TL;DR

> **Quick Summary**: Implement a turn-based roguelike where the player's ONLY source of power is making Faustian deals with the Seven Deadly Sins. Each deal grants a permanent benefit at the cost of a permanent downside. Fight through 7 floors to defeat the Sin Lord.
> 
> **Deliverables**: 
> - Turn-based grid combat system with FOV
> - 7 Sins entity system with 21 deals (3 per sin)
> - Deal selection UI (forced floor-start, optional level-up)
> - 7 procedurally-generated floors with scaling difficulty
> - 10 regular enemy types + Sin Lord boss
> - Complete game loop: start → floors → boss → win/lose
> 
> **Estimated Effort**: Large (~4 weeks for vertical slice)
> **Parallel Execution**: YES - 3 waves of parallel work
> **Critical Path**: Turn System → Deal System → Enemy AI → Floor Progression → Boss

---

## Context

### Original Request
Create a detailed implementation plan for "Bargain" - a Faustian deal roguelike where the player's only source of power is making deals with the Seven Deadly Sins, each granting permanent benefits AND permanent downsides.

**Note**: Original design numbers were provided during interview and are captured in Appendices A-D of this plan.

### Interview Summary
**Key Discussions**:
- Combat: Grid-based with FOV, 4 basic actions (Move, Attack, Use Item, Wait)
- Visuals: Dungeon Mode sprite set (256 tiles) - heroes, enemies, terrain, UI elements
- AI: Simple chase + attack behavior - no complex pathfinding needed
- Deals: Floor-start forced (1 deal), level-up optional (choose 1 from 2 or skip)
- Test Strategy: TDD workflow - write tests first

**Research Findings**:
- `combat_system.lua`: Event-driven framework with Effects, perfect for deal stat modifications
- `DungeonBuilder`: Complete procgen system for floor generation (FULL REUSE)
- `stage_providers.lua`: Sequence mode for 7-floor progression (FULL REUSE)
- `forma`: Grid generation library (NOT for FOV - use pure Lua shadowcasting instead)
- Legacy curse system: Good pattern reference for deals with downsides
- Dungeon Mode sprites: Use existing sprite atlas at `assets/graphics/sprites_atlas-*.png` with `sprites-*.json` for tile/character rendering

### Metis Review
**Identified Gaps** (addressed):
1. Turn order system: NEW - needs full implementation (highest risk)
2. Grid-based movement: NEW - integrate with turn system
3. FOV rendering: NEW - implement pure Lua shadowcasting (forma is NOT for FOV)
4. Downside enforcement: Clarified - use gameplay constraints, not just stat penalties
5. Level-up trigger: Clarified - use XP threshold from master plan
6. Death condition: Confirmed - single HP pool, no multiple lives
7. Sin Lord phases: Confirmed - 5 phases at HP thresholds

**Guardrails Applied** (from Metis):
- Turn system MUST be isolated and tested before combat integration
- Each downside MUST have explicit implementation (not just "reduced stats")
- Deal UI MUST prevent accidentally refusing floor-start deals
- Sin Lord MUST have distinct visual/behavior per phase

---

## Work Objectives

### Core Objective
Implement "Bargain" as a playable vertical slice: a turn-based roguelike where the player makes Faustian deals with Seven Deadly Sins, gaining power through benefits while managing permanent downsides, across 7 floors culminating in a Sin Lord boss fight.

### Concrete Deliverables

All files created under `assets/scripts/bargain/` directory. Use `require("bargain.module_name")` to load.

1. `assets/scripts/bargain/turn_system.lua` - Turn-based combat controller
2. `assets/scripts/bargain/grid_system.lua` - Grid movement and positioning
3. `assets/scripts/bargain/fov_system.lua` - Field of view rendering
4. `assets/scripts/bargain/deal_system.lua` - Faustian deal mechanics (21 deals)
5. `assets/scripts/bargain/sins_data.lua` - 7 Sins and their deals definitions
6. `assets/scripts/bargain/enemy_ai.lua` - Simple chase + attack behaviors
7. `assets/scripts/bargain/enemies_data.lua` - 10 regular enemy type definitions
8. `assets/scripts/bargain/floors_data.lua` - 7 floor configurations
9. `assets/scripts/bargain/sin_lord.lua` - Final boss with 5 phases
10. `assets/scripts/bargain/ui/deal_modal.lua` - Deal selection interface
11. `assets/scripts/bargain/ui/game_hud.lua` - HP, stats, active deals display
12. `assets/scripts/bargain/game.lua` - Main game loop orchestration
13. `assets/scripts/bargain/tests/` - Test scripts directory

### Definition of Done
- [ ] Player can navigate 7 floors using WASD/arrows (grid movement)
- [ ] FOV limits visibility to explored areas
- [ ] 21 deals function with both benefits AND downsides
- [ ] Floor-start deals are forced (cannot skip)
- [ ] Level-up deals are optional (can skip)
- [ ] All 10 regular enemy types + Sin Lord function with simple AI
- [ ] Sin Lord has 5 distinct phases
- [ ] Game ends with victory screen (beat Sin Lord) or death screen (HP = 0)
- [ ] Session completes in 10-15 minutes
- [ ] TDD test coverage for core systems

### Must Have
- Turn-based grid combat with FOV
- 7 Sins × 3 deals = 21 total deals
- Each deal has BOTH benefit AND downside
- 7 floors with increasing difficulty
- Sin Lord boss with phase transitions
- Deal selection UI (modal dialogs)
- HP/stats display with active deals list

### Must NOT Have (Guardrails)
- **No complex AI**: Simple chase only, no A* pathfinding
- **No deal synergies**: Downsides don't multiply, benefits don't combo
- **No item drops**: Deals are the ONLY power source
- **No refusing floor-start deals**: Must accept one
- **No meta-progression**: Each run is fresh
- **No save/load**: Runs are short enough
- **No multiplayer**: Solo experience only
- **No achievements**: Out of scope for vertical slice
- **No difficulty modes**: Single balanced difficulty

---

## Core Data Model (CRITICAL - Read First)

### Decision: Standalone Lua Systems

Bargain is implemented as a **self-contained Lua module** with its own stat/entity system. It does NOT use the existing `combat_system.lua` Stats/Effects framework, which is designed for a different game architecture with complex buff stacking, time-based durations, and context buses.

**Why standalone:**
1. Simpler to implement and test
2. No dependency on engine globals or combat context
3. Deals apply permanent modifications (not time-limited buffs)
4. Cleaner separation for the game jam prototype

### Entity Model

```lua
-- Player entity structure
local player = {
  -- Identity
  id = "player",
  type = "player",
  
  -- Position (1-based grid coordinates)
  x = 5,
  y = 5,
  
  -- Stats (plain numbers, modified directly by deals)
  stats = {
    max_hp = 100,      -- Modified by deals
    hp = 100,          -- Current HP
    attack = 10,       -- Base damage
    defense = 5,       -- Damage reduction
    speed = 100,       -- Turn order (higher = acts first), percentage
    crit_chance = 5,   -- Percentage
    crit_damage = 150, -- Percentage multiplier
  },
  
  -- Deal tracking
  active_deals = {},   -- Array of deal_id strings
  
  -- Callback hooks (for deals like Wrath/Fury that trigger on attack)
  on_attack_callbacks = {},
  on_damage_callbacks = {},
  on_turn_callbacks = {},
  
  -- XP/Level
  xp = 0,
  level = 1,
  xp_to_next_level = 100,
}

-- Enemy entity structure (same core, minus deal tracking)
local enemy = {
  id = "enemy_1",
  type = "imp",  -- Enemy type from enemies_data.lua
  x = 8,
  y = 3,
  stats = {
    max_hp = 15,
    hp = 15,
    attack = 5,
    defense = 0,
    speed = 120,
  },
  -- Type-specific flags
  ignores_armor = false,
  is_ranged = false,
  enrage_threshold = nil,  -- e.g., 0.5 for Berserker
}
```

### Stat Modification (NOT using Effects.modify_stat)

Deals apply **direct permanent modifications** to stats:

```lua
-- Example: Pride/Ego deal (+25% damage, -15% max HP)
function Deals.apply_ego(player)
  player.stats.attack = player.stats.attack * 1.25
  player.stats.max_hp = math.floor(player.stats.max_hp * 0.85)
  player.stats.hp = math.min(player.stats.hp, player.stats.max_hp)
  table.insert(player.active_deals, "pride_ego")
end

-- Example: Wrath/Fury deal (callback-based)
function Deals.apply_fury(player)
  player.stats.speed = player.stats.speed * 1.30
  table.insert(player.on_attack_callbacks, function(damage_dealt)
    player.stats.hp = player.stats.hp - 5  -- Self-damage
  end)
  table.insert(player.active_deals, "wrath_fury")
end
```

### Combat Formulas

```lua
-- Attack damage calculation
function Combat.calculate_damage(attacker, defender)
  local base = attacker.stats.attack
  local is_crit = math.random(100) <= attacker.stats.crit_chance
  local damage = base
  if is_crit then
    damage = damage * (attacker.stats.crit_damage / 100)
  end
  -- Apply defense (simple reduction, minimum 1 damage)
  local reduction = defender.ignores_armor and 0 or defender.stats.defense
  damage = math.max(1, damage - reduction)
  return math.floor(damage), is_crit
end
```

### Turn Order Model (CLARIFIED)

Bargain uses a **phase-based turn system with speed ordering WITHIN phases**:

1. **PLAYER_INPUT**: Wait for player to choose action (Move/Attack/Wait)
2. **PLAYER_ACTION**: Execute player's action
3. **ENEMY_ACTIONS**: All enemies act in speed order (highest speed first)
4. **END_TURN**: Trigger turn-end effects, increment turn counter

**Key rule**: Player ALWAYS acts first in a turn. Speed only determines enemy ordering.
This is simpler than DCSS energy accumulation and matches classic roguelikes like Brogue.

### Bargain Entry Point & Rendering (CONCRETE INTEGRATION POINTS)

**How Bargain is launched**:
- **Option 1 (Debug console)**: Run `dofile("assets/scripts/bargain/game.lua")` then call `BargainGame.start()`
- **Option 2 (Dev init)**: Add to `assets/scripts/core/main.lua` in the initialization section (around line 300+):
```lua
local bargain = require("bargain.game")
bargain.start()
```

**Rendering API** (see `assets/scripts/core/gameplay.lua` lines 6687-6751 for examples):
```lua
-- Draw a sprite at grid position using command_buffer
command_buffer.queueDrawSpriteTopLeft(layers.sprites, function(c)
  c.spriteName = "dungeon_floor.png"  -- From sprites-*.json
  c.x = grid_x * TILE_SIZE
  c.y = grid_y * TILE_SIZE
  c.tint = {1, 1, 1, alpha}  -- Alpha for FOV: 1.0=visible, 0.5=seen, 0=hidden
end)
```

**Input API** (see `assets/scripts/ui/patch_notes_modal.lua` line 465, `assets/scripts/core/main.lua` lines 1385-1390):
```lua
-- Check for key press using global IsKeyPressed
if IsKeyPressed(KEY_W) or IsKeyPressed(KEY_UP) then
  -- Move up
end
if IsKeyPressed(KEY_SPACE) or IsKeyPressed(KEY_ENTER) then
  -- Attack/confirm
end
```
Key constants: `KEY_W`, `KEY_A`, `KEY_S`, `KEY_D`, `KEY_UP`, `KEY_DOWN`, `KEY_LEFT`, `KEY_RIGHT`, `KEY_SPACE`, `KEY_ENTER`, `KEY_ESCAPE`, `KEY_X`

**Per-frame update hook**: Bargain's `game.lua` should expose an `update(dt)` function called from the main loop. Add to `assets/scripts/core/main.lua` update section:
```lua
-- In main.lua update function
if BargainGame and BargainGame.active then
  BargainGame.update(dt)
end
```

### Targeting Model (REQUIRED for deal downsides)

**Base targeting behavior**: Player attacks are **directional**:
- Press Arrow key while adjacent to enemy → Attack in that direction
- If multiple enemies adjacent, player chooses direction (no auto-target by default)
- This allows "can't choose target" to be a meaningful downside

**Autopilot downside enforcement**: When Sloth/Autopilot is active:
- Player automatically attacks the nearest adjacent enemy each turn
- Direction choice is removed - system picks target by distance
- Implemented as flag: `player.autopilot = true` checked in input handler

### "Use Item" Action - REMOVED for v1

The 4 actions originally mentioned are reduced to **3 for v1**:
- **Move**: Arrow keys / WASD
- **Attack**: Arrow key toward adjacent enemy  
- **Wait**: X key (skip turn)

"Use Item" is OUT OF SCOPE: no consumables, no inventory, deals are the ONLY power source.

**Task 13 (Main Game Loop) will implement these integrations.**

### Debug Commands (for testing/verification)

Task 13 should expose these debug functions via the game module for manual verification:

```lua
-- Debug commands available via debug console
BargainGame.debug = {
  -- Teleport to specific floor
  goto_floor = function(floor_num)
    BargainGame.current_floor = floor_num
    BargainGame.generate_floor(floor_num)
  end,
  
  -- Kill all enemies on current floor
  clear_floor = function()
    BargainGame.enemies = {}
  end,
  
  -- Kill the Sin Lord (for victory screen testing)
  kill_boss = function()
    if BargainGame.sin_lord then
      BargainGame.sin_lord.stats.hp = 0
      BargainGame.check_victory()
    end
  end,
  
  -- Set player HP
  set_hp = function(hp)
    BargainGame.player.stats.hp = hp
  end,
  
  -- Grant XP for level-up testing
  grant_xp = function(amount)
    BargainGame.player.xp = BargainGame.player.xp + amount
    BargainGame.check_level_up()
  end,
}
```

**Usage in debug console:** `BargainGame.debug.goto_floor(7)`, `BargainGame.debug.kill_boss()`, etc.

### Grid Adapter (DungeonBuilder → Bargain Grid)

`DungeonBuilder` outputs a vendor `Grid` with numeric tiles. Bargain needs symbolic tiles.

**CRITICAL**: DungeonBuilder uses `0=floor, 1=wall` (see `dungeon.lua` line 22 and DEFAULT_OPTS).

```lua
-- Tile type constants (Bargain uses its own symbolic values)
local TileType = {
  FLOOR = 0,       -- Walkable
  WALL = 1,        -- Blocks movement and vision
  DOOR = 2,        -- Walkable, may block vision when closed
  STAIRS_DOWN = 3, -- Walkable, triggers floor transition
}

-- Adapter: Convert DungeonBuilder output to Bargain grid
-- NOTE: DungeonBuilder uses 0=floor, 1=wall (same encoding, so direct copy works)
function FloorManager.convert_dungeon_to_bargain_grid(dungeon_result)
  local bg = BargainGrid.new(dungeon_result.grid.width, dungeon_result.grid.height)
  
  for y = 1, dungeon_result.grid.height do
    for x = 1, dungeon_result.grid.width do
      local vendor_tile = dungeon_result.grid:get(x, y)
      -- DungeonBuilder uses 0=floor, 1=wall - same as Bargain TileType
      bg:set_tile(x, y, vendor_tile)
    end
  end
  
  -- Place stairs (in a valid room position, not on floor 7)
  if dungeon_result.rooms and #dungeon_result.rooms > 0 then
    local stairs_room = dungeon_result.rooms[#dungeon_result.rooms]  -- Last room
    local cx = math.floor(stairs_room.x + stairs_room.w / 2)
    local cy = math.floor(stairs_room.y + stairs_room.h / 2)
    bg:set_tile(cx, cy, TileType.STAIRS_DOWN)
  end
  
  return bg
end
```

---

## Deal Interpretation Notes (CRITICAL)

Several deals in Appendix A reference mechanics (gold, shops, items, spells, weapons, potions, racial abilities) that are OUT OF SCOPE for this vertical slice per the "Must NOT Have" guardrails. 

**Interpretation rules:**

| Deal Reference | Vertical Slice Interpretation |
|---------------|------------------------------|
| **Gold** (Greed deals) | XP multiplier instead. "+50% gold" → "+50% XP from kills" |
| **Shop prices** (Monopoly) | SKIPPED for vertical slice - replace with stat boost |
| **Items drop** (Tax) | XP/heal chance instead. "Items drop often" → "10% chance to heal 5 HP on kill" |
| **Spells** (Envy/Mimic) | Special attack instead. "Copy spell" → "Copy enemy's attack damage for 3 turns" |
| **Weapons** (Envy/Theft) | Attack stat. "Steal weapon" → "+5 attack on hit, lose 3 attack permanently" |
| **Racial ability** (Copycat) | Passive removed. "Gain enemy ability" → gain their speed bonus |
| **Potions** (Gluttony/Devour) | Heal items in general. "Can't use potions" → "Can't gain HP from floor clears" |
| **Minions** (Sloth/Delegate, Entourage) | NPC ally that acts after player. Simplified AI: moves toward nearest enemy, attacks if adjacent. Takes damage on player's behalf per deal description. |

**Replacement Deal Definitions (for deals that can't work as-is):**

| Original Deal | Replacement Effect |
|--------------|-------------------|
| **Greed/Hoard** | +50% XP from kills, -1 base attack |
| **Greed/Tax** | 10% chance to heal 5 HP on kill, -1 base defense |
| **Greed/Monopoly** | +15% all stats, take +25% damage |
| **Envy/Mimic** | Copy last enemy's attack value for 3 turns (one use per floor), lose 10% attack permanently |
| **Envy/Theft** | On hit: 20% chance to gain +2 attack (permanent), your base attack reduced by 3 |
| **Envy/Copycat** | Gain killed enemy's speed bonus (if any), lose 10% base speed |
| **Gluttony/Devour** | Heal fully after clearing a room, can't regenerate HP between rooms |

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: YES (`tests/` directory with GoogleTest framework for C++)
- **User wants tests**: TDD (tests first)
- **Framework**: 
  - **Lua tests**: Create simple test harness in `assets/scripts/bargain/tests/` using assert statements
  - **C++ tests**: Existing GoogleTest framework in `tests/unit/` for any C++ components (unlikely needed for Bargain since it's pure Lua)

### TDD Workflow

Each TODO follows RED-GREEN-REFACTOR:

1. **RED**: Write failing test first
   - Test file: `assets/scripts/bargain/tests/test_[system].lua`
   - Test command: In-game debug console (`` ` `` key): `dofile("assets/scripts/bargain/tests/test_[system].lua")`
   - OR: Load in-game via debug console: `dofile("assets/scripts/bargain/tests/test_turn_system.lua")`
   - Expected: FAIL (test exists, implementation doesn't)

2. **GREEN**: Implement minimum code to pass
   - Same test command
   - Expected: PASS

3. **REFACTOR**: Clean up while keeping green
   - Same test command
   - Expected: PASS (still)

**Note on Lua Test Pattern**: Tests are simple scripts using `assert()` that can be run via the game's Lua environment. Example:
```lua
-- assets/scripts/bargain/tests/test_turn_system.lua
local TurnSystem = require("bargain.turn_system")
local ts = TurnSystem.new()
assert(ts ~= nil, "TurnSystem should create")
ts:add_entity({id="player", speed=100})
assert(#ts:get_entities() == 1, "Should have 1 entity")
print("[PASS] test_turn_system.lua - all tests passed")
```

### Manual Verification (Gameplay)

For UI and gameplay integration, use interactive verification:

```bash
# Build and run game
just build && ./build/raylib-cpp-cmake-template

# Verification checklist per task provided in acceptance criteria
```

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Foundation - Start Immediately):
├── Task 1: Project scaffolding + data files
├── Task 2: Turn system (CRITICAL PATH)
└── Task 3: Grid system

Wave 2 (Core Systems - After Wave 1):
├── Task 4: FOV system [depends: 3]
├── Task 5: Deal system [depends: 1]
├── Task 6: Player entity [depends: 2, 3]
└── Task 7: Enemy AI [depends: 2, 3]

Wave 3 (Content - After Wave 2):
├── Task 8: 10 regular enemy types [depends: 7]
├── Task 9: Floor generation + progression [depends: 4]
├── Task 10: Deal modal UI [depends: 5]
└── Task 11: Game HUD [depends: 6]

Wave 4 (Integration - After Wave 3):
├── Task 12: Sin Lord boss [depends: 8]
├── Task 13: Main game loop [depends: 9, 10, 11]
└── Task 14: Death/Victory screens [depends: 13]

Wave 5 (Polish - After Wave 4):
└── Task 15: Balancing + session timing [depends: all]

Critical Path: Task 2 → Task 6 → Task 7 → Task 8 → Task 12 → Task 13
Parallel Speedup: ~35% faster than sequential
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 5 | 2, 3 |
| 2 | None | 6, 7 | 1, 3 |
| 3 | None | 4, 6, 7 | 1, 2 |
| 4 | 3 | 9 | 5, 6, 7 |
| 5 | 1 | 10 | 4, 6, 7 |
| 6 | 2, 3 | 11 | 4, 5, 7 |
| 7 | 2, 3 | 8 | 4, 5, 6 |
| 8 | 7 | 12 | 9, 10, 11 |
| 9 | 4 | 13 | 8, 10, 11 |
| 10 | 5 | 13 | 8, 9, 11 |
| 11 | 6 | 13 | 8, 9, 10 |
| 12 | 8 | 13 | 13 (partial) |
| 13 | 9, 10, 11, 12 | 14 | None |
| 14 | 13 | 15 | None |
| 15 | 14 | None | None |

### Agent Dispatch Summary

| Wave | Tasks | Recommended Agents |
|------|-------|-------------------|
| 1 | 1, 2, 3 | `delegate_task(category="unspecified-high", load_skills=["codebase-teacher"], run_in_background=true)` |
| 2 | 4, 5, 6, 7 | Dispatch parallel after Wave 1 completes |
| 3 | 8, 9, 10, 11 | Dispatch parallel after Wave 2 completes |
| 4 | 12, 13, 14 | Sequential, high integration risk |
| 5 | 15 | Manual balancing + playtesting |

---

## TODOs

### Task 1: Project Scaffolding + Data Files

**What to do**:
- Create `assets/scripts/bargain/` directory structure
- Create `assets/scripts/bargain/tests/` directory for test scripts
- Create `sins_data.lua` with 7 sins and 21 deals definitions
- Create `enemies_data.lua` with 10 regular enemy type definitions  
- Create `floors_data.lua` with 7 floor configurations
- Create `constants.lua` with game balance numbers
- Create `assets/scripts/bargain/tests/run_all_tests.lua` - test aggregator script

**Must NOT do**:
- Don't implement any logic yet - data files only
- Don't create UI files yet
- Don't wire up any systems

**Recommended Agent Profile**:
- **Category**: `quick`
  - Reason: Data file creation is straightforward, no complex logic
- **Skills**: [`codebase-teacher`]
  - `codebase-teacher`: Understand existing data file patterns in the codebase

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 1 (with Tasks 2, 3)
- **Blocks**: Task 5 (Deal system needs sins_data.lua)
- **Blocked By**: None (can start immediately)

**References**:

**Pattern References** (existing data files):
- `assets/scripts/combat/enemy_factory.lua:enemyConfigs` - Enemy definition pattern
- `assets/scripts/combat/wave_examples.lua` - Stage/wave data structure (note: in combat/, not procgen/)
- `assets/raws/colors.json` - Color definitions for sin themes

**API/Type References** (EXACT NUMBERS - copy these directly):
- **All 21 Deals**: See Appendix A at end of this plan (copied from master design doc)
- **Enemy Stats**: See Appendix B at end of this plan (copied from master design doc)

**Documentation References**:
- `docs/systems/combat/README.md` - Stats system overview

**WHY Each Reference Matters**:
- `enemy_factory.lua`: Shows how to structure enemy configs with HP, damage, speed
- `wave_examples.lua`: Shows how to define floor/stage progressions
- Master design doc: Contains EXACT numbers for all deals and enemies - copy these

**Acceptance Criteria**:

**TDD:**
- [ ] Test file created: `assets/scripts/bargain/tests/test_data_loading.lua`
- [ ] Test aggregator created: `assets/scripts/bargain/tests/run_all_tests.lua`
- [ ] Test: `sins_data` loads 7 sins with 3 deals each (21 total)
- [ ] Test: Each deal has `benefit` table AND `downside` table
- [ ] Test: `enemies_data` loads 10 regular enemy types
- [ ] Test: `floors_data` loads 7 floor configurations
- [ ] Test script runs without errors

**run_all_tests.lua structure:**
```lua
-- assets/scripts/bargain/tests/run_all_tests.lua
-- Run all Bargain test scripts
print("=== Running Bargain Tests ===")

local test_files = {
  "assets/scripts/bargain/tests/test_data_loading.lua",
  "assets/scripts/bargain/tests/test_turn_system.lua",
  "assets/scripts/bargain/tests/test_grid_system.lua",
  "assets/scripts/bargain/tests/test_fov_system.lua",
  "assets/scripts/bargain/tests/test_deal_system.lua",
  "assets/scripts/bargain/tests/test_player.lua",
  "assets/scripts/bargain/tests/test_enemy_ai.lua",
  "assets/scripts/bargain/tests/test_enemies.lua",
  "assets/scripts/bargain/tests/test_floors.lua",
  "assets/scripts/bargain/tests/test_sin_lord.lua",
}

local passed = 0
local failed = 0

for _, file in ipairs(test_files) do
  local ok, err = pcall(dofile, file)
  if ok then
    passed = passed + 1
  else
    failed = failed + 1
    print("[FAIL] " .. file .. ": " .. tostring(err))
  end
end

print("=== Results: " .. passed .. " passed, " .. failed .. " failed ===")
```

**Automated Verification** (in-game console or script):
```lua
-- Run via debug console (` key) or dofile()
local sins = require("bargain.sins_data")
assert(#sins == 7, "Expected 7 sins")
for _, sin in ipairs(sins) do
  assert(#sin.deals == 3, "Each sin needs 3 deals")
end
print("[PASS] sins_data.lua validated - 7 sins, 21 deals total")

local enemies = require("bargain.enemies_data")
assert(#enemies == 10, "Expected 10 regular enemy types")
print("[PASS] enemies_data.lua validated - 10 enemy types")

local floors = require("bargain.floors_data")
assert(#floors == 7, "Expected 7 floors")
print("[PASS] floors_data.lua validated - 7 floors")
```

**Evidence to Capture:**
- [ ] Console output showing all PASS messages
- [ ] No Lua errors during require()

**Commit**: YES
- Message: `feat(bargain): add game data files for sins, enemies, and floors`
- Files: `assets/scripts/bargain/*.lua`
- Pre-commit: `just build` succeeds

---

### Task 2: Turn System (CRITICAL PATH)

**What to do**:
- Create `bargain/turn_system.lua` - core turn controller
- Implement turn phases: PLAYER_INPUT → PLAYER_ACTION → ENEMY_ACTIONS → END_TURN
- Implement speed-based turn ordering (higher speed acts first)
- Create event hooks: `on_turn_start`, `on_turn_end`, `on_entity_act`
- Write comprehensive tests FIRST (TDD)

**Must NOT do**:
- Don't integrate with grid/movement yet - pure turn logic
- Don't implement actual combat - just turn ordering
- Don't add UI - console logging for debug

**Recommended Agent Profile**:
- **Category**: `unspecified-high`
  - Reason: Core system requiring careful design, moderate complexity
- **Skills**: [`codebase-teacher`]
  - `codebase-teacher`: Understand existing event/signal patterns

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 1 (with Tasks 1, 3)
- **Blocks**: Tasks 6, 7 (Player and Enemy AI need turn system)
- **Blocked By**: None (can start immediately)

**References**:

**Pattern References**:
- `assets/scripts/combat/combat_system.lua:EventBus` - Event dispatch pattern
- `assets/scripts/external/hump/signal.lua` - Signal/event system (HUMP library)
- `assets/scripts/combat/wave_examples.lua:6` - Shows correct signal require: `require("external.hump.signal")`
- `todo_from_snkrx/done/player.lua:update()` - Turn-based update pattern

**API/Type References**:
- `docs/systems/combat/README.md:Events` - Event system documentation
- `docs/external/hump_README.md` - HUMP signal documentation

**External References**:
- DCSS turn system: Each entity has `speed` stat, turn order determined by accumulated time

**WHY Each Reference Matters**:
- `combat_system.lua:EventBus`: Use this pattern for turn events (don't reinvent)
- `external/hump/signal.lua`: CORRECT location for signal system - use `require("external.hump.signal")`
- Speed formula: Higher speed acts first within a turn

**Acceptance Criteria**:

**TDD:**
- [ ] Test file created: `assets/scripts/bargain/tests/test_turn_system.lua`
- [ ] Test: Turn phases execute in order (PLAYER → ENEMIES → END)
- [ ] Test: Higher speed entities act before lower speed
- [ ] Test: Multiple enemies act in speed order
- [ ] Test: Turn counter increments correctly
- [ ] Test: Event hooks fire at correct times
- [ ] Test script runs without errors (6+ assertions pass)

**Automated Verification** (run via debug console):
```lua
-- Run: dofile("assets/scripts/bargain/tests/test_turn_system.lua")
local TurnSystem = require("bargain.turn_system")
local ts = TurnSystem.new()
assert(ts ~= nil, "TurnSystem should create")

-- Add mock entities
ts:add_entity({id="player", type="player", speed=100})
ts:add_entity({id="enemy1", type="enemy", speed=80})
ts:add_entity({id="enemy2", type="enemy", speed=120})

-- Verify turn phases (player ALWAYS acts first per Core Data Model)
-- Speed only affects enemy ordering within ENEMY_ACTIONS phase
assert(ts:get_current_phase() == "PLAYER_INPUT", "Starts in player input phase")
print("[PASS] Turn system - starts in player input phase")

-- Verify enemy ordering by speed (within enemy phase)
local enemy_order = ts:get_enemy_turn_order()
assert(enemy_order[1].id == "enemy2", "Fastest enemy (120) should be first")
assert(enemy_order[2].id == "enemy1", "Slower enemy (80) should be second")
print("[PASS] Turn system - enemy speed ordering works")

-- Verify turn counter
assert(ts:get_turn_count() == 0, "Starts at turn 0")
ts:advance_turn()
assert(ts:get_turn_count() == 1, "Turn count increments")
print("[PASS] Turn system - turn counter works")
```

**Evidence to Capture:**
- [ ] Console output showing all PASS messages
- [ ] Turn ordering demonstration

**Commit**: YES
- Message: `feat(bargain): implement turn-based combat system with speed ordering`
- Files: `assets/scripts/bargain/turn_system.lua`, `assets/scripts/bargain/tests/test_turn_system.lua`
- Pre-commit: `just build` succeeds

---

### Task 3: Grid System

**What to do**:
- Create `bargain/grid_system.lua` - grid management
- Implement tile grid with configurable size (10x10 to 25x25)
- Implement tile types: FLOOR, WALL, DOOR, STAIRS_DOWN
- Implement entity positioning on grid (x, y coordinates)
- Implement movement validation (can't walk through walls)
- Implement Manhattan distance calculation

**Must NOT do**:
- Don't implement actual movement input handling
- Don't implement FOV (separate task)
- Don't generate dungeons (use DungeonBuilder in later task)

**Recommended Agent Profile**:
- **Category**: `unspecified-high`
  - Reason: Core system, moderate complexity
- **Skills**: [`codebase-teacher`]
  - `codebase-teacher`: Understand existing grid/procgen patterns

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 1 (with Tasks 1, 2)
- **Blocks**: Tasks 4, 6, 7 (FOV, Player, Enemy AI need grid)
- **Blocked By**: None (can start immediately)

**References**:

**Pattern References**:
- `assets/scripts/core/procgen/grid_builder.lua` - Existing grid implementation
- `assets/scripts/core/procgen/coords.lua` - Coordinate conversion utilities
- `assets/scripts/core/procgen/dungeon.lua:Grid` - Grid data structure

**API/Type References**:
- No separate procgen README - see code comments in `dungeon.lua`

**Coordinate Convention**:
- Existing procgen uses **1-based indexing** (Lua standard)
- All Bargain grid code should use 1-based indexing to match

**WHY Each Reference Matters**:
- `grid_builder.lua`: DON'T reinvent - use or extend existing Grid class
- `coords.lua`: Use existing coordinate conversion (grid ↔ world)
- `dungeon.lua:Grid`: May be able to reuse directly

**Acceptance Criteria**:

**TDD:**
- [ ] Test file created: `assets/scripts/bargain/tests/test_grid_system.lua`
- [ ] Test: Grid creates with specified dimensions
- [ ] Test: Tile types can be set and retrieved
- [ ] Test: Entity can be placed at valid position
- [ ] Test: Movement blocked by WALL tiles
- [ ] Test: Movement allowed on FLOOR tiles
- [ ] Test: Manhattan distance calculates correctly
- [ ] Test script runs without errors (6+ assertions pass)

**Automated Verification** (run via debug console):
```lua
-- Run: dofile("assets/scripts/bargain/tests/test_grid_system.lua")
local Grid = require("bargain.grid_system")
local g = Grid.new(10, 10)
assert(g ~= nil, "Grid should create")

-- Set some walls (note: 1-based indexing)
g:set_tile(5, 5, Grid.WALL)
g:set_tile(5, 6, Grid.FLOOR)

-- Test movement validation
assert(g:can_move_to(5, 6) == true, "Can move to floor")
assert(g:can_move_to(5, 5) == false, "Cannot move to wall")
print("[PASS] Grid system - movement validation works")

-- Test Manhattan distance (1-based coords)
assert(g:manhattan_distance(1, 1, 4, 5) == 7, "Manhattan distance correct")
print("[PASS] Grid system - manhattan distance works")
```

**Evidence to Capture:**
- [ ] Console output showing all PASS messages
- [ ] Grid state verification

**Commit**: YES
- Message: `feat(bargain): implement grid system for turn-based movement`
- Files: `assets/scripts/bargain/grid_system.lua`, `assets/scripts/bargain/tests/test_grid_system.lua`
- Pre-commit: `just build` succeeds

---

### Task 4: FOV System

**What to do**:
- Create `assets/scripts/bargain/fov_system.lua` - field of view calculation
- **DECISION: Use pure Lua recursive shadowcasting** (simpler, self-contained, no C++ binding needed)
- Implement visibility states: UNSEEN, SEEN (revealed but not visible), VISIBLE
- Implement FOV radius (player default: 8 tiles)
- Create FOV update function called when player moves

**Algorithm to implement** (recursive shadowcasting):
```lua
-- Core shadowcasting function scans one octant
-- Call for all 8 octants to get full FOV
function FOV:scan_octant(cx, cy, row, start_slope, end_slope, radius, octant)
  -- For each row in the octant...
  -- Mark visible tiles
  -- Track shadow segments created by walls
  -- Recursively scan next row with adjusted slopes
end
```

**Must NOT do**:
- Don't implement rendering (handled in game.lua draw loop)
- Don't implement memory/minimap
- Don't add complex lighting effects
- Don't use forma library (it's for grid generation, not FOV)
- Don't try to bind C++ LOS (too coupled to engine globals)

**Recommended Agent Profile**:
- **Category**: `unspecified-high`
  - Reason: Shadowcasting algorithm requires careful implementation
- **Skills**: [`codebase-teacher`]
  - `codebase-teacher`: Understand grid coordinate conventions

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 2 (with Tasks 5, 6, 7)
- **Blocks**: Task 9 (Floor generation needs FOV for rendering)
- **Blocked By**: Task 3 (needs grid system)

**References**:

**External References (Lua FOV implementations)**:
- Recursive shadowcasting algorithm: https://www.roguebasin.com/index.php/FOV_using_recursive_shadowcasting
- Simple Lua implementation: ~100-150 lines of code
- Reference implementation (C but portable): https://www.roguebasin.com/index.php/C%2B%2B_shadowcasting_implementation

**WHY Each Reference Matters**:
- RogueBasin article: Well-documented algorithm with pseudocode, port to Lua
- Algorithm produces correct visibility for roguelikes (handles corners, pillars, etc.)

**Acceptance Criteria**:

**TDD:**
- [ ] Test file created: `assets/scripts/bargain/tests/test_fov_system.lua`
- [ ] Test: FOV updates when player position changes
- [ ] Test: Tiles within radius are VISIBLE
- [ ] Test: Tiles behind walls are not VISIBLE
- [ ] Test: Previously seen tiles become SEEN (not UNSEEN)
- [ ] Test: FOV radius is configurable
- [ ] Test script runs without errors (5+ assertions pass)

**Automated Verification** (run via debug console):
```lua
-- Run: dofile("assets/scripts/bargain/tests/test_fov_system.lua")
local FOV = require("bargain.fov_system")
local Grid = require("bargain.grid_system")

local g = Grid.new(20, 20)
g:set_tile(10, 11, Grid.WALL)  -- Wall blocking view

local fov = FOV.new(g)
fov:update(10, 10, 8)  -- Player at 10,10, radius 8

assert(fov:is_visible(10, 10) == true, "Player position visible")
assert(fov:is_visible(11, 10) == true, "Adjacent tile visible")
assert(fov:is_visible(10, 15) == false, "Tile behind wall not visible")
print("[PASS] FOV system - visibility calculation works")
```

**Evidence to Capture:**
- [ ] Console output showing PASS message
- [ ] Visual verification of FOV in-game (tiles fade outside view)

**Commit**: YES
- Message: `feat(bargain): implement FOV system with shadowcasting`
- Files: `assets/scripts/bargain/fov_system.lua`, `assets/scripts/bargain/tests/test_fov_system.lua`
- Pre-commit: `just build` succeeds

---

### Task 5: Deal System

**What to do**:
- Create `assets/scripts/bargain/deal_system.lua` - Faustian deal mechanics
- Implement deal application: `apply_deal(player, deal_id)` using **direct stat modification** (see Core Data Model)
- Implement benefit effects by directly modifying player.stats fields
- Implement downside effects via stat penalties + callback registration (e.g., on_attack_callbacks)
- Track active deals on player.active_deals array
- Implement deal offering: `get_random_deals(count, exclude_sins)`

**IMPORTANT**: Use standalone Lua stat system (NOT combat_system.lua Effects). See Core Data Model section for entity structure and stat modification patterns.

**Must NOT do**:
- Don't implement UI (separate task)
- Don't implement deal synergies (explicitly forbidden)
- Don't allow deal removal/undo
- Don't use combat_system.lua Effects.modify_stat (standalone approach)

**Recommended Agent Profile**:
- **Category**: `unspecified-high`
  - Reason: Core game mechanic, needs careful implementation of 21 deals
- **Skills**: [`codebase-teacher`]
  - `codebase-teacher`: Understand callback patterns for conditional effects

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 2 (with Tasks 4, 6, 7)
- **Blocks**: Task 10 (Deal modal needs deal system)
- **Blocked By**: Task 1 (needs sins_data.lua)

**References**:

**Pattern References**:
- See **Core Data Model** section for exact stat modification approach
- See **Deal Interpretation Notes** for how to handle deals that reference out-of-scope mechanics

**WHY Each Reference Matters**:
- Core Data Model: Shows exact player/enemy structure and how to modify stats directly
- Deal Interpretation: Provides replacements for deals that can't work as-is (gold/shop/spell deals)

**Acceptance Criteria**:

**TDD:**
- [ ] Test file created: `assets/scripts/bargain/tests/test_deal_system.lua`
- [ ] Test: Pride/Ego deal applies +25% damage AND -15% max HP
- [ ] Test: Wrath/Fury deal applies +30% attack speed AND 5 self-damage per attack
- [ ] Test: Sloth/Autopilot deal enables auto-attack AND disables target selection
- [ ] Test: Active deals are tracked on player
- [ ] Test: get_random_deals returns correct count without duplicates
- [ ] Test: All 21 deals have both benefit AND downside implemented
- [ ] Test script runs without errors (10+ assertions pass)

**Automated Verification** (run via debug console):
```lua
-- Run: dofile("assets/scripts/bargain/tests/test_deal_system.lua")
local Deals = require("bargain.deal_system")

-- Test Pride/Ego deal (using Core Data Model entity structure)
local player = {
  id = "player",
  stats = {
    max_hp = 100,
    hp = 100,
    attack = 10,
    defense = 5,
    speed = 100,
  },
  active_deals = {},
  on_attack_callbacks = {},
}
Deals.apply_deal(player, "pride_ego")
assert(player.stats.attack == 12.5, "Ego: +25% attack")
assert(player.stats.max_hp == 85, "Ego: -15% max HP")
assert(#player.active_deals == 1, "Deal tracked")
print("[PASS] Pride/Ego deal - benefit AND downside applied")

-- Test Wrath/Fury deal (verify self-damage callback exists)
local player2 = {
  id = "player2",
  stats = { speed = 100, hp = 100 },
  active_deals = {},
  on_attack_callbacks = {},
}
Deals.apply_deal(player2, "wrath_fury")
assert(player2.stats.speed == 130, "Fury: +30% speed")
assert(#player2.on_attack_callbacks > 0, "Fury: self-damage callback registered")
print("[PASS] Wrath/Fury deal - speed boost + callback")

-- Verify all 21 deals load
local sins = require("bargain.sins_data")
local deal_count = 0
for _, sin in ipairs(sins) do
  for _, deal in ipairs(sin.deals) do
    assert(deal.benefit ~= nil, "Deal must have benefit")
    assert(deal.downside ~= nil, "Deal must have downside")
    deal_count = deal_count + 1
  end
end
assert(deal_count == 21, "Expected 21 deals total")
print("[PASS] All 21 deals have both benefit AND downside")
```

**Evidence to Capture:**
- [ ] Console output showing all PASS messages
- [ ] Verification that every deal has BOTH effects

**Commit**: YES
- Message: `feat(bargain): implement Faustian deal system with 21 deals`
- Files: `assets/scripts/bargain/deal_system.lua`, `assets/scripts/bargain/tests/test_deal_system.lua`
- Pre-commit: `just build` succeeds

---

### Task 6: Player Entity

**What to do**:
- Create `bargain/player.lua` - player entity and controls
- Implement base stats from master plan (HP: 100, Attack: 10, Defense: 5, Speed: 100%)
- Implement 4 actions: Move, Attack, Use Item, Wait
- Integrate with turn system (player input phase)
- Integrate with grid system (movement validation)
- Implement XP gain and level-up trigger

**Must NOT do**:
- Don't implement input handling UI (separate concern)
- Don't implement inventory system (no items except consumables)
- Don't implement deal application (deal_system handles that)

**Recommended Agent Profile**:
- **Category**: `unspecified-high`
  - Reason: Central entity requiring integration with multiple systems
- **Skills**: [`codebase-teacher`]
  - `codebase-teacher`: Understand entity patterns in codebase

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 2 (with Tasks 4, 5, 7)
- **Blocks**: Task 11 (Game HUD needs player stats)
- **Blocked By**: Tasks 2, 3 (needs turn and grid systems)

**References**:

**Pattern References**:
- See **Core Data Model** section above for exact entity structure
- `todo_from_snkrx/done/player.lua` - Conceptual reference for player state machine (different architecture but useful patterns)
- Master design doc lines 960-966 - Base character stats

**API/Type References**:
- `docs/systems/combat/README.md:Stats` - Stats system reference

**WHY Each Reference Matters**:
- `player.lua`: Existing player pattern with movement, stats, actions
- Master doc: Base stats (HP: 100, Attack: 10, Defense: 5, Speed: 100%)

**Acceptance Criteria**:

**TDD:**
- [ ] Test file created: `assets/scripts/bargain/tests/test_player.lua`
- [ ] Test: Player created with correct base stats
- [ ] Test: Move action updates position on grid
- [ ] Test: Move action blocked by walls
- [ ] Test: Attack action deals damage (base formula)
- [ ] Test: Wait action passes turn
- [ ] Test: XP gain triggers level-up at threshold
- [ ] Test script runs without errors (6+ assertions pass)

**Automated Verification** (run via debug console):
```lua
-- Run: dofile("assets/scripts/bargain/tests/test_player.lua")
local Player = require("bargain.player")
local Grid = require("bargain.grid_system")

local g = Grid.new(10, 10)
local p = Player.new(g, 5, 5)

assert(p.stats.max_hp == 100, "Base HP is 100")
assert(p.stats.attack == 10, "Base Attack is 10")
assert(p.stats.defense == 5, "Base Defense is 5")
assert(p.x == 5 and p.y == 5, "Initial position correct")
print("[PASS] Player - base stats correct")

p:move(1, 0)  -- Move right
assert(p.x == 6, "Moved right")
print("[PASS] Player - movement works")
```

**Evidence to Capture:**
- [ ] Console output showing all PASS messages
- [ ] Player stat verification

**Commit**: YES
- Message: `feat(bargain): implement player entity with movement and stats`
- Files: `assets/scripts/bargain/player.lua`, `assets/scripts/bargain/tests/test_player.lua`
- Pre-commit: `just build` succeeds

---

### Task 7: Enemy AI

**What to do**:
- Create `bargain/enemy_ai.lua` - simple chase + attack AI
- Implement chase behavior: move toward player using Manhattan distance
- Implement attack behavior: attack when adjacent (melee) or in range (ranged)
- Integrate with turn system (enemy action phase)
- Implement different behavior per enemy type (from enemies_data)

**Must NOT do**:
- No A* pathfinding - simple Manhattan chase only
- No complex tactics or abilities beyond basic attack
- No fleeing or retreating behavior

**Recommended Agent Profile**:
- **Category**: `unspecified-low`
  - Reason: Simple AI, chase + attack only
- **Skills**: [`codebase-teacher`]
  - `codebase-teacher`: Find existing AI patterns

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 2 (with Tasks 4, 5, 6)
- **Blocks**: Task 8 (Enemy types need AI)
- **Blocked By**: Tasks 2, 3 (needs turn and grid systems)

**References**:

**Pattern References**:
- `assets/scripts/ai/` - Existing AI system
- `todo_from_snkrx/done/enemies.lua:Seeker` - Chase behavior pattern
- `docs/systems/ai-behavior/AI_README.md` - AI documentation

**WHY Each Reference Matters**:
- `ai/`: May have reusable chase behavior
- `Seeker`: Simple chase pattern to reference
- Chase formula: Move toward player along axis with larger distance

**Acceptance Criteria**:

**TDD:**
- [ ] Test file created: `assets/scripts/bargain/tests/test_enemy_ai.lua`
- [ ] Test: Enemy moves toward player when not adjacent
- [ ] Test: Enemy attacks player when adjacent
- [ ] Test: Enemy chooses axis with larger distance to close
- [ ] Test: Enemy respects wall collision
- [ ] Test: Ranged enemy attacks from distance (if in range)
- [ ] Test script runs without errors (5+ assertions pass)

**Automated Verification** (run via debug console):
```lua
-- Run: dofile("assets/scripts/bargain/tests/test_enemy_ai.lua")
local EnemyAI = require("bargain.enemy_ai")
local Grid = require("bargain.grid_system")

local g = Grid.new(10, 10)
local enemy = {x=2, y=2, stats={range=1}}
local player = {x=5, y=2}

local action = EnemyAI.decide(enemy, player, g)
assert(action.type == "move", "Should move toward player")
assert(action.dx == 1, "Move right toward player (larger axis)")
print("[PASS] Enemy AI - chase behavior works")

-- Test attack when adjacent
local enemy2 = {x=4, y=2, stats={range=1}}
local action2 = EnemyAI.decide(enemy2, player, g)
assert(action2.type == "attack", "Should attack when adjacent")
print("[PASS] Enemy AI - attack behavior works")
```

**Evidence to Capture:**
- [ ] Console output showing all PASS messages
- [ ] AI decision demonstration

**Commit**: YES
- Message: `feat(bargain): implement simple chase + attack enemy AI`
- Files: `assets/scripts/bargain/enemy_ai.lua`, `assets/scripts/bargain/tests/test_enemy_ai.lua`
- Pre-commit: `just build` succeeds

---

### Task 8: Regular Enemy Types (10 types)

**What to do**:
- Create enemy factory function using enemies_data.lua
- Implement all 10 regular enemy types with stats from Appendix B
- Implement enemy-specific behaviors:
  - Imp: Fast movement (120% speed)
  - Cultist: Basic enemy (no special)
  - Skeleton: Basic melee (no special)
  - Demon: Resistant to fire
  - Wraith: Ignores armor
  - Golem: High defense
  - Succubus: Charm chance
  - Berserker: Enrages at low HP
  - Mage: Ranged attacks
  - Knight: Blocks first hit
- Create enemy spawning function for floors

**Must NOT do**:
- No new enemy types beyond the 10 specified
- No complex abilities beyond single special trait
- Sin Lord is Task 12, NOT part of this task

**Recommended Agent Profile**:
- **Category**: `unspecified-high`
  - Reason: Content-heavy task with 10 enemy variations
- **Skills**: [`codebase-teacher`]
  - `codebase-teacher`: Understand enemy factory patterns

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 3 (with Tasks 9, 10, 11)
- **Blocks**: Task 12 (Sin Lord inherits from enemy base)
- **Blocked By**: Task 7 (needs enemy AI)

**References**:

**Pattern References**:
- `assets/scripts/combat/enemy_factory.lua` - Enemy creation pattern
- See Appendix B for exact enemy stats (10 regular enemies)

**WHY Each Reference Matters**:
- `enemy_factory.lua`: Follow existing factory pattern
- Master doc: EXACT stats for each enemy type

**Acceptance Criteria**:

**TDD:**
- [ ] Test file created: `assets/scripts/bargain/tests/test_enemies.lua`
- [ ] Test: Each of 10 regular enemy types can be created
- [ ] Test: Imp has 120% speed
- [ ] Test: Wraith damage ignores armor
- [ ] Test: Golem has high defense value
- [ ] Test: Berserker stats increase below 50% HP
- [ ] Test: Mage attacks at range
- [ ] Test script runs without errors (10+ assertions, one per enemy)

**Automated Verification** (run via debug console):
```lua
-- Run: dofile("assets/scripts/bargain/tests/test_enemies.lua")
local Enemies = require("bargain.enemies")

-- Test each enemy type
local imp = Enemies.create("imp")
assert(imp.stats.speed == 120, "Imp speed is 120%")
assert(imp.stats.hp == 15, "Imp HP is 15")
print("[PASS] Imp - fast enemy")

local wraith = Enemies.create("wraith")
assert(wraith.ignores_armor == true, "Wraith ignores armor")
assert(wraith.stats.hp == 30, "Wraith HP is 30")
print("[PASS] Wraith - armor piercing")

local golem = Enemies.create("golem")
assert(golem.stats.defense >= 20, "Golem high defense")
assert(golem.stats.speed == 70, "Golem is slow")
print("[PASS] Golem - tanky")

local berserker = Enemies.create("berserker")
assert(berserker.enrage_threshold == 0.5, "Berserker enrages at 50% HP")
print("[PASS] Berserker - enrage mechanic")

-- Verify all 10 regular enemy types exist (Sin Lord is Task 12)
local types = {"imp", "cultist", "skeleton", "demon", "wraith", "golem", "succubus", "berserker", "mage", "knight"}
for _, t in ipairs(types) do
  local e = Enemies.create(t)
  assert(e ~= nil, t .. " should create")
end
print("[PASS] All 10 regular enemy types can be created")
```

**Evidence to Capture:**
- [ ] Console output showing all PASS messages
- [ ] Stat verification for each enemy type

**Commit**: YES
- Message: `feat(bargain): implement all 10 regular enemy types with unique behaviors`
- Files: `assets/scripts/bargain/enemies.lua`, `assets/scripts/bargain/tests/test_enemies.lua`
- Pre-commit: `just build` succeeds

---

### Task 9: Floor Generation + Progression

**What to do**:
- Create `bargain/floor_manager.lua` - floor orchestration
- Use existing `DungeonBuilder` for room generation
- Use existing `stage_providers.sequence()` for 7-floor progression
- Configure floor sizes per master plan (10x10 → 15x15 → back to 10x10)
- Configure enemy counts per floor (3-5 → 12-15 → boss only)
- Place stairs down in each floor (except floor 7)
- Integrate difficulty scaling via `procgen.curve`

**Must NOT do**:
- Don't write custom dungeon generation - use DungeonBuilder
- Don't implement infinite/endless mode
- Don't add dungeon branches or alternate paths

**Recommended Agent Profile**:
- **Category**: `unspecified-low`
  - Reason: Mostly configuration and wiring existing systems
- **Skills**: [`codebase-teacher`]
  - `codebase-teacher`: Understand DungeonBuilder and stage providers

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 3 (with Tasks 8, 10, 11)
- **Blocks**: Task 13 (Game loop needs floor progression)
- **Blocked By**: Task 4 (needs FOV for rendering)

**References**:

**Pattern References**:
- `assets/scripts/core/procgen/dungeon.lua:DungeonBuilder` - FULL REUSE
- `assets/scripts/combat/stage_providers.lua:sequence()` - FULL REUSE
- `assets/scripts/core/procgen.lua:curve()` - Difficulty scaling (line 333)
- Master design doc lines 984-991 - Floor size/enemy table

**WHY Each Reference Matters**:
- `DungeonBuilder`: Use fluent API for floor generation
- `sequence()`: Configure 7 floors with exact specs
- `curve()`: Scale difficulty 1.0 → 1.6 across floors
- Master doc: Floor 1 is 10x10 with 3-5 enemies, Floor 7 is 10x10 with boss only

**Acceptance Criteria**:

**TDD:**
- [ ] Test file created: `assets/scripts/bargain/tests/test_floors.lua`
- [ ] Test: 7 floors can be generated in sequence
- [ ] Test: Floor 1 is 10x10 with 3-5 enemies
- [ ] Test: Floor 4-6 are 15x15 with 8-15 enemies
- [ ] Test: Floor 7 is 10x10 with Sin Lord only
- [ ] Test: Stairs placed in floors 1-6
- [ ] Test: No stairs in floor 7 (boss floor)
- [ ] Test script runs without errors (6+ assertions pass)

**Automated Verification** (run via debug console):
```lua
-- Run: dofile("assets/scripts/bargain/tests/test_floors.lua")
local FloorManager = require("bargain.floor_manager")

local floor1 = FloorManager.generate(1)
assert(floor1.width == 10 and floor1.height == 10, "Floor 1 is 10x10")
assert(floor1.enemy_count >= 3 and floor1.enemy_count <= 5, "Floor 1 has 3-5 enemies")
assert(floor1.has_stairs == true, "Floor 1 has stairs")
print("[PASS] Floor 1 - correct configuration")

local floor4 = FloorManager.generate(4)
assert(floor4.width == 15 and floor4.height == 15, "Floor 4 is 15x15")
print("[PASS] Floor 4 - larger size")

local floor7 = FloorManager.generate(7)
assert(floor7.has_stairs == false, "Floor 7 no stairs (boss floor)")
assert(floor7.has_boss == true, "Floor 7 has Sin Lord")
print("[PASS] Floor 7 - boss floor configuration")
```

**Evidence to Capture:**
- [ ] Console output showing all PASS messages
- [ ] Generated floor visualization (optional)

**Commit**: YES
- Message: `feat(bargain): implement floor generation using DungeonBuilder`
- Files: `assets/scripts/bargain/floor_manager.lua`, `assets/scripts/bargain/tests/test_floors.lua`
- Pre-commit: `just build` succeeds

---

### Task 10: Deal Modal UI

**What to do**:
- Create `bargain/ui/deal_modal.lua` - deal selection interface
- Implement floor-start deal modal (FORCED - no cancel button)
- Implement level-up deal modal (OPTIONAL - has skip button)
- Display deal name, sin name, benefit, downside clearly
- Use sin-themed colors (Gold/Pride, Red/Wrath, etc.)
- Add confirmation before applying deal

**Must NOT do**:
- Don't add animations (keep it simple)
- Don't add hover tooltips (text is inline)
- Don't allow comparing multiple deals side-by-side

**Recommended Agent Profile**:
- **Category**: `visual-engineering`
  - Reason: UI work requiring layout and visual design
- **Skills**: [`frontend-ui-ux`]
  - `frontend-ui-ux`: UI component design

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 3 (with Tasks 8, 9, 11)
- **Blocks**: Task 13 (Game loop needs deal UI)
- **Blocked By**: Task 5 (needs deal system)

**References**:

**Pattern References**:
- `assets/scripts/ui/skill_confirmation_modal.lua` - Modal pattern with confirm/cancel
- `assets/scripts/ui/ui_syntax_sugar.lua` - DSL for vbox, hbox, text, button
- `assets/scripts/ui/patch_notes_modal.lua` - Backdrop and centered modal

**API/Type References**:
- `docs/api/ui_helper_reference.md` - Full UI API reference
- `docs/api/ui-dsl-reference.md` - DSL syntax guide

**WHY Each Reference Matters**:
- `skill_confirmation_modal.lua`: EXACT pattern for deal confirmation
- `ui_syntax_sugar.lua`: Use `dsl.vbox`, `dsl.button` for layout
- Sin colors from master doc: Gold, Yellow, Red, Green, Orange, Purple, Pink

**Acceptance Criteria**:

**Manual Verification** (run game and verify visually):
```bash
# Build and launch game
just build && ./build/raylib-cpp-cmake-template

# Verification steps:
1. Start new game → Floor 1 loads
2. Verify: Floor-start deal modal appears automatically
3. Verify: Modal shows Sin name header (e.g., "GREED offers you a BARGAIN...")
4. Verify: Benefit text is visible (green colored)
5. Verify: Downside text is visible (red colored)
6. Verify: Floor-start modal has NO skip/refuse button
7. Click Accept button
8. Verify: Modal closes, game resumes
9. Gain XP to trigger level-up
10. Verify: Level-up deal modal appears with 2 deals
11. Verify: Level-up modal HAS skip button
12. Take screenshot (F12 or engine screenshot key)
```

**Evidence to Capture:**
- [ ] Screenshot of floor-start modal (no skip)
- [ ] Screenshot of level-up modal (with skip)
- [ ] Description of visual verification results

**Commit**: YES
- Message: `feat(bargain): implement deal selection modal UI`
- Files: `assets/scripts/bargain/ui/deal_modal.lua`
- Pre-commit: `just build` succeeds

---

### Task 11: Game HUD

**What to do**:
- Create `bargain/ui/game_hud.lua` - main game interface
- Display HP bar with current/max values
- Display Attack, Defense, Speed stats
- Display active deals list (with sin icons/colors)
- Display current floor number
- Display turn indicator

**Must NOT do**:
- No minimap
- No inventory display (deals only)
- No XP bar (level-up is event-based)

**Recommended Agent Profile**:
- **Category**: `visual-engineering`
  - Reason: UI layout and stat display
- **Skills**: [`frontend-ui-ux`]
  - `frontend-ui-ux`: HUD design

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 3 (with Tasks 8, 9, 10)
- **Blocks**: Task 13 (Game loop needs HUD)
- **Blocked By**: Task 6 (needs player stats)

**References**:

**Pattern References**:
- `assets/scripts/ui/stats_panel.lua` - Stat display with progress bars
- `assets/scripts/ui/ui_syntax_sugar.lua` - DSL for building UI components
- See Appendix D for UI layout reference

**Dynamic Update Pattern**:
For HUD stats that change (HP, active deals), use one of these approaches:
1. **Re-spawn on change**: `ui.box.Remove(old_id)` then create new element with updated values
2. **State tags**: Use `dsl.text` with a function callback that reads current stats
3. **Signal listener**: Register for stat change events and update UI elements

**WHY Each Reference Matters**:
- `stats_panel.lua`: Progress bar pattern for HP display
- `ui_syntax_sugar.lua`: DSL primitives (`dsl.text`, `dsl.progressBar`, etc.)
- Layout: HP/stats top-right, active deals list bottom

**Acceptance Criteria**:

**Manual Verification** (run game and verify visually):
```bash
# Build and launch game
just build && ./build/raylib-cpp-cmake-template

# Verification steps:
1. Start new game → Floor 1 loads
2. Verify: HP bar visible showing "HP: 100/100" (or current/max format)
3. Verify: Stats visible (ATK: 10, DEF: 5, etc.)
4. Verify: Floor indicator shows "Floor 1"
5. Verify: Active deals section exists (empty initially)
6. Accept a deal from floor-start modal
7. Verify: Deal appears in active deals list
8. Take damage from enemy
9. Verify: HP bar updates to reflect damage
10. Take screenshot
```

**Evidence to Capture:**
- [ ] Screenshot of HUD with stats
- [ ] Screenshot of HUD with active deals
- [ ] HP bar update verification

**Commit**: YES
- Message: `feat(bargain): implement game HUD with HP, stats, and deals display`
- Files: `assets/scripts/bargain/ui/game_hud.lua`
- Pre-commit: Game builds and runs

---

### Task 12: Sin Lord Boss

**What to do**:
- Create `bargain/sin_lord.lua` - final boss implementation
- Implement 5 phases based on HP thresholds (from master plan):
  - 100-80%: Pride (+50% damage)
  - 80-60%: Wrath (attacks twice)
  - 60-40%: Gluttony (heals 10 HP/turn)
  - 40-20%: Sloth (summons 2 minions)
  - 20-0%: All Sins (random effect each turn)
- Base stats: HP 200, Attack 30, Speed 100%
- Implement phase transition effects (visual/audio cue)

**Must NOT do**:
- No additional phases beyond 5
- No complex multi-stage attacks
- No environmental hazards

**Recommended Agent Profile**:
- **Category**: `unspecified-high`
  - Reason: Complex boss with multiple behaviors
- **Skills**: [`codebase-teacher`]
  - `codebase-teacher`: Understand boss patterns

**Parallelization**:
- **Can Run In Parallel**: Partial
- **Parallel Group**: Wave 4 (can start while Task 13 begins)
- **Blocks**: Task 13 (final integration)
- **Blocked By**: Task 8 (inherits enemy base)

**References**:

**Pattern References**:
- `assets/scripts/combat/enemy_factory.lua` - Boss creation pattern
- Master design doc lines 1009-1019 - Sin Lord phase table

**WHY Each Reference Matters**:
- `enemy_factory.lua`: Pattern for creating special enemies
- Master doc: EXACT HP thresholds and effects per phase

**Acceptance Criteria**:

**TDD:**
- [ ] Test file created: `assets/scripts/bargain/tests/test_sin_lord.lua`
- [ ] Test: Sin Lord created with 200 HP
- [ ] Test: At 80% HP, phase changes to Wrath (attacks twice)
- [ ] Test: At 60% HP, phase changes to Gluttony (heals each turn)
- [ ] Test: At 40% HP, phase changes to Sloth (summons minions)
- [ ] Test: At 20% HP, phase changes to All Sins (random effect)
- [ ] Test: Phase transitions fire event for UI/audio cue
- [ ] Test script runs without errors (6+ assertions pass)

**Automated Verification** (run via debug console):
```lua
-- Agent runs:
local SinLord = require("bargain.sin_lord")

local boss = SinLord.new()
assert(boss.stats.max_hp == 200, "Sin Lord HP")
assert(boss.phase == "pride", "Starts in Pride phase")

boss:take_damage(40)  -- 160 HP = 80%
assert(boss.phase == "wrath", "Phase changed to Wrath")

boss:take_damage(40)  -- 120 HP = 60%
assert(boss.phase == "gluttony", "Phase changed to Gluttony")
print("Sin Lord phases verified")
```

**Evidence to Capture:**
- [ ] Test output for all 5 phases
- [ ] Phase transition verification

**Commit**: YES
- Message: `feat(bargain): implement Sin Lord boss with 5 phases`
- Files: `assets/scripts/bargain/sin_lord.lua`, `assets/scripts/bargain/tests/test_sin_lord.lua`
- Pre-commit: `just build` succeeds

---

### Task 13: Main Game Loop

**What to do**:
- Create `bargain/game.lua` - main orchestration
- Implement game states: TITLE → PLAYING → DEAL_SELECTION → VICTORY → DEATH
- Wire up all systems: turn, grid, FOV, player, enemies, floors, deals, UI
- Implement floor transition (stairs → next floor → deal offered)
- Implement level-up trigger (XP threshold → deal offered)
- Implement win condition (Sin Lord defeated)
- Implement lose condition (player HP = 0)

**Must NOT do**:
- No pause menu (short runs)
- No save/load (short runs)
- No settings menu (out of scope)

**Recommended Agent Profile**:
- **Category**: `unspecified-high`
  - Reason: Integration of all systems, high complexity
- **Skills**: [`codebase-teacher`]
  - `codebase-teacher`: Understand game loop patterns

**Parallelization**:
- **Can Run In Parallel**: NO (depends on everything)
- **Parallel Group**: Wave 4 (sequential)
- **Blocks**: Task 14 (end screens)
- **Blocked By**: Tasks 9, 10, 11, 12 (all previous systems)

**References**:

**Pattern References**:
- `assets/scripts/core/gameplay.lua` - Existing game loop pattern (uses `require("external.hump.signal")` for events)
- `assets/scripts/external/hump/signal.lua` - HUMP signal library for event-driven state transitions

**State Machine Implementation**:
- Create simple state machine in `bargain/states.lua` with states: TITLE, PLAYING, DEAL_SELECTION, VICTORY, DEATH
- Use HUMP signal for state transitions: `signal.emit("state_change", new_state)`
- State machine is a simple Lua table with current state and transition functions

**WHY Each Reference Matters**:
- `gameplay.lua`: Follow existing game initialization/loop patterns for startup sequence
- `hump/signal.lua`: Use for decoupled state transitions and game events
- Core loop: START → Floor Loop → Boss → WIN/LOSE (implement directly in bargain/game.lua)

**Acceptance Criteria**:

**Manual Verification** (full game loop test):
```bash
# Build and launch game
just build && ./build/raylib-cpp-cmake-template

# Verification steps:
1. Launch game
2. Verify: Title screen appears with "New Game" option
3. Start new game
4. Verify: Floor 1 generates with visible tiles
5. Verify: Floor-start deal modal appears automatically
6. Accept deal
7. Verify: Player can move with WASD/arrow keys
8. Move player, verify: Enemies move after player turn
9. Fight and defeat all enemies OR use debug command to clear floor
10. Move to stairs tile
11. Use stairs (press Enter or interact key)
12. Verify: Floor 2 loads
13. Verify: Another deal offered at floor start
14. Take screenshots at each stage
```

**Evidence to Capture:**
- [ ] Screenshot of title screen
- [ ] Screenshot of gameplay on floor 1
- [ ] Screenshot of floor transition to floor 2
- [ ] Description of turn-based flow working correctly

**Commit**: YES
- Message: `feat(bargain): implement main game loop orchestration`
- Files: `assets/scripts/bargain/game.lua`
- Pre-commit: Game builds and runs

---

### Task 14: Death/Victory Screens

**What to do**:
- Create `bargain/ui/end_screens.lua` - end game UI
- Implement death screen:
  - Display "YOU DIED" message
  - Show floor reached
  - Show deals made (list all)
  - Show cause of death
  - "Try Again" button → restart
- Implement victory screen:
  - Display "VICTORY" message
  - Show all deals made
  - Show final stats
  - "Play Again" button → restart

**Must NOT do**:
- No leaderboards
- No statistics tracking across runs
- No unlockables

**Recommended Agent Profile**:
- **Category**: `visual-engineering`
  - Reason: UI screens with layout
- **Skills**: [`frontend-ui-ux`]
  - `frontend-ui-ux`: Screen design

**Parallelization**:
- **Can Run In Parallel**: NO
- **Parallel Group**: Wave 4 (after Task 13)
- **Blocks**: Task 15 (balancing needs full game)
- **Blocked By**: Task 13 (game loop triggers end screens)

**References**:

**Pattern References**:
- `assets/scripts/ui/patch_notes_modal.lua` - Full-screen modal pattern
- Master design doc lines 1024-1039 - UI description

**Acceptance Criteria**:

**Manual Verification** (death and victory screens):
```bash
# Build and launch game
just build && ./build/raylib-cpp-cmake-template

# Death screen test:
1. Start new game, accept floor-start deal
2. Use debug console (` key) to reduce HP: `player.hp = 1`
3. Let enemy attack to trigger death
4. Verify: Death screen appears
5. Verify: "YOU DIED" text visible
6. Verify: Floor reached displayed (e.g., "Floor 1")
7. Verify: Deals made listed
8. Click "Try Again" button
9. Verify: New game starts fresh

# Victory test:
1. Start new game
2. Use debug console to teleport to floor 7: `game.goto_floor(7)`
3. Use debug console to kill Sin Lord: `game.kill_boss()`
4. Verify: Victory screen appears
5. Verify: All deals collected during run are listed
6. Take screenshots of both screens
```

**Evidence to Capture:**
- [ ] Screenshot of death screen
- [ ] Screenshot of victory screen
- [ ] Confirmation that "Try Again" / "Play Again" buttons work

**Commit**: YES
- Message: `feat(bargain): implement death and victory screens`
- Files: `assets/scripts/bargain/ui/end_screens.lua`
- Pre-commit: Game builds and runs

---

### Task 15: Balancing + Session Timing

**What to do**:
- Playtest complete runs and measure session length
- Target: 10-15 minutes per run
- Adjust if needed:
  - Enemy HP/damage scaling
  - Floor enemy counts
  - XP requirements for level-up
  - Deal benefit/downside magnitudes
  - Sin Lord HP/phases
- Create balance config file for easy tuning
- Document final balance values

**Must NOT do**:
- No difficulty modes (single balanced difficulty)
- No player choice of difficulty
- Don't change core mechanics, only numbers

**Recommended Agent Profile**:
- **Category**: `unspecified-low`
  - Reason: Tuning values, not code changes
- **Skills**: []
  - Manual playtesting required

**Parallelization**:
- **Can Run In Parallel**: NO
- **Parallel Group**: Wave 5 (final)
- **Blocks**: None (final task)
- **Blocked By**: Task 14 (needs complete game)

**References**:

**Pattern References**:
- Master design doc lines 1146-1152 - Session length targets

**Acceptance Criteria**:

**Manual Verification:**
- [ ] Complete 3 full runs (win attempt)
- [ ] Record session times
- [ ] Average session: 10-15 minutes
- [ ] Game is winnable (at least 1 of 3 runs can win)
- [ ] Game is challenging (not every run wins)
- [ ] All 21 deals feel impactful
- [ ] Sin Lord phases are distinct and challenging

**Evidence to Capture:**
- [ ] Session time log
- [ ] Balance adjustment notes
- [ ] Final balance config values

**Commit**: YES
- Message: `chore(bargain): balance game for 10-15 minute sessions`
- Files: `assets/scripts/bargain/balance_config.lua`
- Pre-commit: N/A (config only)

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `feat(bargain): add game data files` | bargain/*.lua | Tests pass |
| 2 | `feat(bargain): implement turn system` | turn_system.lua | Tests pass |
| 3 | `feat(bargain): implement grid system` | grid_system.lua | Tests pass |
| 4 | `feat(bargain): implement FOV system` | fov_system.lua | Tests pass |
| 5 | `feat(bargain): implement deal system` | deal_system.lua | Tests pass |
| 6 | `feat(bargain): implement player entity` | player.lua | Tests pass |
| 7 | `feat(bargain): implement enemy AI` | enemy_ai.lua | Tests pass |
| 8 | `feat(bargain): implement enemy types` | enemies.lua | Tests pass |
| 9 | `feat(bargain): implement floor generation` | floor_manager.lua | Tests pass |
| 10 | `feat(bargain): implement deal modal` | ui/deal_modal.lua | Game runs |
| 11 | `feat(bargain): implement game HUD` | ui/game_hud.lua | Game runs |
| 12 | `feat(bargain): implement Sin Lord boss` | sin_lord.lua | Tests pass |
| 13 | `feat(bargain): implement game loop` | game.lua | Game runs |
| 14 | `feat(bargain): implement end screens` | ui/end_screens.lua | Game runs |
| 15 | `chore(bargain): balance game` | balance_config.lua | Session times |

---

## Success Criteria

### Verification Commands
```bash
# Build the game
just build

# Run the game
./build/raylib-cpp-cmake-template

# Run Lua tests via debug console (` key in-game):
dofile("assets/scripts/bargain/tests/run_all_tests.lua")

# Expected: Game launches, title screen appears
# Expected: Can complete full run in 10-15 minutes
# Expected: All test scripts output [PASS] messages
```

### Final Checklist
- [ ] All "Must Have" features present
- [ ] All "Must NOT Have" items absent
- [ ] All 21 deals have both benefit AND downside
- [ ] Sin Lord has all 5 phases working
- [ ] Session completes in 10-15 minutes
- [ ] Game is winnable but challenging
- [ ] TDD tests pass for core systems

---

*Plan generated by Prometheus based on master design document and interview. Ready for implementation.*

---

## Appendix A: All 21 Deals (EXACT NUMBERS)

Copy these values directly into `sins_data.lua`.

### PRIDE (Gold)
| Deal | Benefit | Downside |
|------|---------|----------|
| **Ego** | +25% damage | -15% max HP |
| **Hubris** | Critical hits deal 3x damage | -20% armor |
| **Supremacy** | +50% damage to enemies below 50% HP | -50% damage to enemies above 50% HP |

### GREED (Yellow)
| Deal | Benefit | Downside |
|------|---------|----------|
| **Hoard** | +50% gold from enemies | -1 STR |
| **Tax** | Enemies drop items more often | -1 DEX |
| **Monopoly** | Shops have better items | All shop prices +50% |

### WRATH (Red)
| Deal | Benefit | Downside |
|------|---------|----------|
| **Fury** | +30% attack speed | Take 5 damage per attack you make |
| **Bloodlust** | Heal 10% of damage dealt | -25% defense |
| **Rampage** | Kill streak: +10% damage per kill (stacks to 50%, resets on turn without kill) | Take 10 damage if no kill for 3 turns |

### ENVY (Green)
| Deal | Benefit | Downside |
|------|---------|----------|
| **Mimic** | Copy the last spell an enemy cast (one use) | Forget your highest-level spell |
| **Theft** | 20% chance to steal enemy's weapon on hit | Your weapon is destroyed |
| **Copycat** | Gain the special ability of last killed enemy | Lose your racial ability |

### GLUTTONY (Orange)
| Deal | Benefit | Downside |
|------|---------|----------|
| **Feast** | +50% max HP | -20% movement speed |
| **Devour** | Heal fully after each combat | Can't use potions |
| **Bloat** | +100% HP regeneration | Size doubles (easier to hit, +25% damage taken) |

### SLOTH (Purple)
| Deal | Benefit | Downside |
|------|---------|----------|
| **Autopilot** | Auto-attack nearest enemy | Can't choose attack target |
| **Delegate** | Summon a minion that fights for you | You deal 50% damage |
| **Rest** | Heal 10 HP per turn | Can't move (enemies come to you) |

### LUST (Pink)
| Deal | Benefit | Downside |
|------|---------|----------|
| **Charm** | 30% chance enemies skip turn | -15% damage |
| **Entourage** | Start each floor with 2 charmed minions | Minions take 50% of damage you would take |
| **Seduction** | Bosses have 20% less HP | You have 20% less HP |

---

## Appendix B: Enemy Types (EXACT STATS)

### Regular Enemies (10 types - Task 8)

Copy these values directly into `enemies_data.lua`.

| Enemy | HP | Attack | Speed | Special |
|-------|-----|--------|-------|---------|
| **Imp** | 15 | 5 | 120% | Fast |
| **Cultist** | 25 | 8 | 100% | None |
| **Skeleton** | 20 | 10 | 100% | None (basic melee) |
| **Demon** | 40 | 12 | 90% | Resistant to fire (no fire damage type in v1, treat as +10 defense) |
| **Wraith** | 30 | 15 | 110% | Ignores armor |
| **Golem** | 60 | 10 | 70% | High defense (defense = 20) |
| **Succubus** | 35 | 18 | 100% | 20% charm chance (enemy skips turn) |
| **Berserker** | 50 | 25 | 80% | Enrages below 50% HP (+50% attack) |
| **Mage** | 25 | 20 | 100% | Ranged attacks (range = 5 tiles) |
| **Knight** | 70 | 15 | 90% | Blocks first hit (take 0 damage once) |

### Sin Lord Boss (Task 12 - SEPARATE from regular enemies)

| Boss | HP | Attack | Speed | Special |
|------|-----|--------|-------|---------|
| **Sin Lord** | 200 | 30 | 100% | Phase-based abilities (see below) |

### Sin Lord Boss Phases
| HP Range | Phase | Behavior |
|----------|-------|----------|
| 100-80% | Pride | +50% damage |
| 80-60% | Wrath | Attacks twice per turn |
| 60-40% | Gluttony | Heals 10 HP per turn |
| 40-20% | Sloth | Summons 2 minions |
| 20-0% | All Sins | Random sin effect each turn |

---

## Appendix C: Floor Configuration (EXACT VALUES)

Copy these values directly into `floors_data.lua`.

| Floor | Size | Enemies | Deal Opportunities |
|-------|------|---------|-------------------|
| 1 | 10x10 | 3-5 weak | Floor start: 1 deal, Level up: 1 deal |
| 2 | 12x12 | 5-7 weak | Floor start: 1 deal, Level up: 1 deal |
| 3 | 12x12 | 6-8 mixed | Floor start: 1 deal, Level up: 1 deal |
| 4 | 15x15 | 8-10 mixed | Floor start: 1 deal, Level up: 2 deals (pick 1) |
| 5 | 15x15 | 10-12 hard | Floor start: 1 deal, Level up: 2 deals |
| 6 | 15x15 | 12-15 hard | Floor start: 1 deal, Level up: 2 deals |
| 7 | 10x10 | SIN LORD only | No level up (boss floor) |

### Player Base Stats
| Stat | Base Value |
|------|------------|
| Max HP | 100 |
| Attack | 10 |
| Defense | 5 |
| Speed | 100% |
| Crit Chance | 5% |
| Crit Damage | 150% |

### Combat Formulas
```lua
-- Attack damage
Damage = Attack × (1 + Deal_Bonuses) × Crit_Multiplier

-- Damage taken
Damage_Taken = Incoming × (1 - Defense/100) × (1 + Deal_Penalties)
```

---

## Appendix D: UI Layout Reference

```
+-----------------------------------+
| Floor 4    HP: ▓▓▓▓░░ 68/100     |
| Deals: 5   ATK: 18  DEF: 3       |
+-----------------------------------+
|                                   |
|   [Dungeon Grid - Tiles/Sprites]  |
|                                   |
|      @.....                       |
|      ##..D..                      |
|      ...#...                      |
+-----------------------------------+
| Active Deals:                     |
| [Fury] [Feast] [Charm] [Hoard]   |
+-----------------------------------+
```

### Deal Modal Layout
```
+-----------------------------------+
| GREED offers you a BARGAIN...     |
+-----------------------------------+
| [HOARD]                           |
| +50% gold from enemies            |  <- GREEN text
| COST: -1 STR (permanently)        |  <- RED text
|                                   |
| [Accept]        [Refuse]          |  <- Refuse only on level-up
+-----------------------------------+
```
