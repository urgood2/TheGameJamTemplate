# Serpent - SNKRX-Style Survivor Implementation Plan

## TL;DR

> **Quick Summary**: Implement "Serpent", an SNKRX-style survivor roguelite where player controls a snake of auto-attacking units. Survive 20 waves, buy units between waves, stack class synergies for stat bonuses.
> 
> **Deliverables**: 
> - Complete playable vertical slice (10-15 minute session)
> - Snake movement system (head follows input, body chains)
> - Auto-attack combat with 16 unit types
> - Shop system for purchasing units
> - 4 class synergy system with stat bonuses
> - 20 waves with 2 boss fights
> - Win/lose screens
> 
> **Estimated Effort**: Large (~1 month)
> **Parallel Execution**: YES - 4 waves (see Execution Strategy)
> **Critical Path**: Task 1 → Task 3 → Task 7 → Task 10 → Task 14

---

## Context

### Authoritative Design Specification
**Primary Spec Source**: Originally from `roguelike-prototypes-design.md` in the sister worktree.

**Embedded Numeric Appendix (Source of Truth for Implementation)**:

All numeric values are embedded inline below to ensure reproducibility:

**Classes (4 total)**:
| Class | Color | Role | 2-Unit Synergy | 4-Unit Synergy |
|-------|-------|------|----------------|----------------|
| Warrior | Red | Front-line | +20% attack damage | +40% attack damage, +20% HP |
| Mage | Blue | AoE magic | +20% spell damage | +40% spell damage, -20% cooldown |
| Ranger | Green | Ranged sustained | +20% attack speed | +40% attack speed, +20% range |
| Support | Yellow | Buffs/healing | Heal snake 5 HP/sec | Heal 10 HP/sec, +10% all stats |

**Units (16 total, costs = tier × 3g)**:

*Tier 1 (Cost: 3g, waves 1+)*:
| Unit | Class | HP | Attack | Range | AtkSpd | Special |
|------|-------|-----|--------|-------|--------|---------|
| Soldier | Warrior | 100 | 15 | 50 (melee) | 1.0 | None |
| Apprentice | Mage | 60 | 10 | 200 | 0.8 | None |
| Scout | Ranger | 70 | 8 | 300 | 1.5 | None |
| Healer | Support | 80 | 5 | 100 | 0.5 | Heal adjacent 10 HP/sec |

*Tier 2 (Cost: 6g, waves 5+)*:
| Unit | Class | HP | Attack | Range | AtkSpd | Special |
|------|-------|-----|--------|-------|--------|---------|
| Knight | Warrior | 150 | 20 | 50 | 0.9 | Block: 20% DR |
| Pyromancer | Mage | 70 | 18 | 180 | 0.7 | Burns 5 dmg/sec |
| Sniper | Ranger | 60 | 25 | 400 | 0.6 | Crit 20% 2x |
| Bard | Support | 90 | 8 | 80 | 0.8 | +10% AtkSpd adj |

*Tier 3 (Cost: 12g, waves 10+)*:
| Unit | Class | HP | Attack | Range | AtkSpd | Special |
|------|-------|-----|--------|-------|--------|---------|
| Berserker | Warrior | 120 | 35 | 60 | 1.2 | Frenzy: +5%/kill |
| Archmage | Mage | 80 | 30 | 250 | 0.5 | Hits 3 (stub: 1) |
| Assassin | Ranger | 80 | 40 | 70 | 1.0 | +100% behind |
| Paladin | Support | 150 | 15 | 60 | 0.7 | Divine Shield |

*Tier 4 (Cost: 20g, waves 15+)*:
| Unit | Class | HP | Attack | Range | AtkSpd | Special |
|------|-------|-----|--------|-------|--------|---------|
| Champion | Warrior | 200 | 50 | 80 | 0.8 | Cleave (stub: single) |
| Lich | Mage | 100 | 45 | 300 | 0.4 | Pierce (deferred) |
| Windrunner | Ranger | 100 | 35 | 350 | 1.1 | 3 arrows (stub: 1) |
| Angel | Support | 120 | 20 | 100 | 0.6 | Resurrect (deferred) |

**Units Legend:**
- **Range**: in pixels (50 = melee touch, 200+ = ranged)
- **AtkSpd**: attacks per second (1.0 = 1 attack/sec, 0.5 = 1 attack per 2 sec)

**Enemies (11 total)**:
| Enemy | HP | Damage | Speed (px/s) | Special | Waves |
|-------|-----|--------|--------------|---------|-------|
| Slime | 20 | 5 | 80 (Slow) | None | 1-5 |
| Bat | 15 | 8 | 200 (Fast) | Flies | 1-10 |
| Goblin | 30 | 10 | 120 (Normal) | None | 3-10 |
| Orc | 50 | 15 | 120 (Normal) | None | 5-15 |
| Skeleton | 40 | 12 | 120 (Normal) | Immune poison | 5-15 |
| Wizard | 35 | 20 | 100 (Normal) | Ranged | 8-20 |
| Troll | 100 | 25 | 80 (Slow) | Regenerates | 10-20 |
| Demon | 80 | 30 | 140 (Normal+) | Fire trail | 12-20 |
| Dragon | 200 | 40 | 60 (Slow) | Breath (cone) | 15-20 |
| **Swarm Queen** | 500 | 50 | 50 (Slow) | Spawns 5 slimes/10sec | Wave 10 |
| **Lich King** | 800 | 75 | 100 (Normal) | Raises dead as skeletons | Wave 20 |

**Speed Legend:** Slow=60-80, Normal=100-140, Fast=180-220 (pixels/sec)

**Wave Scaling Formulas**:
```lua
Enemies_per_Wave = 5 + Wave × 2
Enemy_HP_Multiplier = 1 + Wave × 0.1
Enemy_Damage_Multiplier = 1 + Wave × 0.05
Gold_per_Wave = 10 + Wave × 2
```

**Stat Scaling (SNKRX formula)**:
```lua
HP = Base_HP × 2^(Level - 1)
Attack = Base_Attack × 2^(Level - 1)
-- Level 1: 1x, Level 2: 2x, Level 3: 4x (max)
```

**Shop Tier Odds**:
| Wave | Tier 1 | Tier 2 | Tier 3 | Tier 4 |
|------|--------|--------|--------|--------|
| 1-5 | 70% | 25% | 5% | 0% |
| 6-10 | 55% | 30% | 13% | 2% |
| 11-15 | 35% | 35% | 22% | 8% |
| 16-20 | 20% | 30% | 33% | 17% |

### Original Request
Create a detailed master implementation plan for Game #2 "Serpent" based on the roguelike-prototypes-design.md specification.

### Interview Summary
**Key Discussions**:
- Game follows SNKRX mechanics: snake of 3-8 units, real-time auto-combat
- Player controls movement only; units attack automatically
- Session target: 10-15 minutes across 20 waves
- 4 classes (Warrior, Mage, Ranger, Support) with synergy bonuses at 2/4 thresholds
- Unit leveling via duplicate combination (3 copies → level up, stats double)

**Research Findings**:
- Engine already has: steering behaviors, combat system with EventBus/Effects, UI DSL, wave director
- SNKRX stat formula: `stat = base × 2^(level-1)`
- Defense formula: `final_damage = base_damage × (100 / (100 + defense))`
- Existing test framework with `describe()/it()` pattern

### Metis Review
**Identified Gaps** (addressed):
- Snake body data structure: Using array of entity IDs with explicit ordering
- Unit death behavior: Gap closes immediately
- Auto-attack timing: Independent timers per unit based on attack speed
- Targeting priority: Nearest enemy within range
- Wave timeout: Endless until cleared (no timeout)
- Shop pool: Fixed pool, weighted by tier

---

## Work Objectives

### Core Objective
Build a complete playable vertical slice of "Serpent" - an SNKRX-style survivor roguelite with snake movement, auto-combat, shop system, and class synergies.

### Concrete Deliverables
- `assets/scripts/serpent/` - All game-specific Lua code
- `assets/scripts/serpent/snake_controller.lua` - Snake movement system
- `assets/scripts/serpent/auto_attack.lua` - Unit auto-attack system
- `assets/scripts/serpent/synergy_system.lua` - Class synergy bonuses
- `assets/scripts/serpent/serpent_shop.lua` - Unit shop adaptation
- `assets/scripts/serpent/wave_config.lua` - 20 wave definitions
- `assets/scripts/serpent/data/units.lua` - 16 unit definitions
- `assets/scripts/serpent/data/enemies.lua` - 11 enemy definitions
- `assets/scripts/serpent/ui/` - HUD, shop UI, synergy display

### Definition of Done
- [ ] `lua assets/scripts/tests/test_runner.lua assets/scripts/serpent/tests/` → all tests pass
- [ ] Full 20-wave run completable in 10-15 minutes
- [ ] Snake movement feels responsive (head follows input within 0.1s)
- [ ] All 16 units purchasable and functional
- [ ] All 4 synergies activate at 2/4 thresholds with correct stat bonuses
- [ ] Boss fights at waves 10 and 20 function correctly
- [ ] Win/lose screens display with run stats

### Must Have
- Snake of 3-8 units following player input
- Auto-attack system with attack speed and range
- 16 units across 4 classes, 4 tiers
- Shop between waves (buy, sell at 50%, reroll)
- Class synergy bonuses at 2/4 thresholds
- 20 waves with difficulty scaling
- 2 bosses (Swarm Queen wave 10, Lich King wave 20)
- Unit leveling (3 copies → level up, 2x stats)
- Death/victory screens with run stats

### Must NOT Have (Guardrails)

**Explicit Exclusions from Master Design Doc:**
- No items in shop (units only)
- No interest mechanic
- No unit repositioning in snake (purchase order = position)
- No meta-progression
- No save/load mid-run
- No difficulty modes
- No sound design (placeholder beeps only)
- No controller support

**Additional Guardrails from Metis Review:**
- No unit abilities beyond basic auto-attack (damage/heal only)
- No passive items or buffs
- No NG+ scaling
- No position-based effects (e.g., "Position 4 does +30% damage")
- No enemy elites beyond the 2 specified bosses
- Must use placeholder art (shapes + colors for class)
- Must use existing UI components (no new primitives)
- Must follow existing Lua patterns in `assets/scripts/`

---

## Integration Contract

> **CRITICAL**: This section explains how Serpent modules connect to the engine runtime.
> Without this context, the executor cannot understand where code is loaded or how systems interact.

### Entry Point & Loading

**Serpent is a NEW game mode that runs INSTEAD of the existing game, not alongside it.**

**Task 1 MUST implement these EXACT changes to `assets/scripts/core/main.lua`:**

**Change 1: GAMESTATE table (line ~45-48)**
```lua
-- BEFORE:
GAMESTATE = {
    MAIN_MENU = 0,
    IN_GAME = 1
}
-- AFTER:
GAMESTATE = {
    MAIN_MENU = 0,
    IN_GAME = 1,
    SERPENT = 2  -- NEW: Serpent game mode
}
```

**Change 2: Add require at top of file (after line ~38)**
```lua
local Serpent = require("serpent.serpent_main")
```

**Change 3: Update `changeGameState()` function (line ~1091-1106)**
```lua
-- BEFORE (line 1091-1106):
function changeGameState(newState)
    if currentGameState == GAMESTATE.MAIN_MENU and newState ~= GAMESTATE.MAIN_MENU then
        clearMainMenu()
    end
    if newState == GAMESTATE.MAIN_MENU then
        initMainMenu()
    elseif newState == GAMESTATE.IN_GAME then
        initMainGame()
    else
        error("Invalid game state: " .. tostring(newState))
    end
    currentGameState = newState
    globals.currentGameState = newState
end

-- AFTER:
function changeGameState(newState)
    if currentGameState == GAMESTATE.MAIN_MENU and newState ~= GAMESTATE.MAIN_MENU then
        clearMainMenu()
    end
    if newState == GAMESTATE.MAIN_MENU then
        initMainMenu()
    elseif newState == GAMESTATE.IN_GAME then
        initMainGame()
    elseif newState == GAMESTATE.SERPENT then
        Serpent.init()  -- NEW: Initialize Serpent
    else
        error("Invalid game state: " .. tostring(newState))
    end
    currentGameState = newState
    globals.currentGameState = newState
end
```

**Change 4: Update `main.update()` function (insert at line ~1394, after MAIN_MENU block ends)**

**ACTUAL main.update() structure (verified):**
```lua
-- Line 1362-1409: main.update() structure
local isPaused = (globals.gamePaused or currentGameState == GAMESTATE.MAIN_MENU)

if not isPaused then
    Node.update_all(dt)  -- Line 1366
end

Text.update(dt)  -- Line 1371

if (currentGameState == GAMESTATE.MAIN_MENU) then  -- Line 1373
    -- ... main menu specific updates (lines 1374-1393) ...
end  -- Line 1394 - MAIN_MENU block ends here

if isPaused then  -- Line 1396
    component_cache.end_frame()
    return
end

-- ... remainder of update (ProjectileSystemTest, cache end) ...
```

**INSERT ONLY the Serpent update block between lines 1399 and 1401:**

The pause check already exists at lines 1396-1399. Do NOT duplicate it.

```lua
    -- EXISTING lines 1396-1399 (DO NOT COPY - these already exist):
    -- if isPaused then
    --     component_cache.end_frame()
    --     return
    -- end

    -- ===== INSERT THIS BLOCK ONLY (between pause check and ProjectileSystemTest) =====
    if (currentGameState == GAMESTATE.SERPENT) then
        -- Serpent's Node entities already updated by Node.update_all(dt) above
        -- This handles Serpent-specific game logic (wave management, shop, etc.)
        Serpent.update(dt)
    end
    -- ===== END INSERT =====

    -- EXISTING line 1401 (DO NOT COPY - this already exists):
    -- if ProjectileSystemTest ~= nil then
```

**CRITICAL: Do NOT duplicate the pause guard or component_cache.end_frame()!**
The insertion is ONLY the 4 lines starting with `if (currentGameState == GAMESTATE.SERPENT)`.

**Why this location (CRITICAL - pause semantics):**
- **Serpent.update() MUST NOT run when paused** - consistent with existing game semantics
- Placing AFTER `if isPaused then return end` ensures Serpent respects pause state
- Node.update_all(dt) already skips Serpent nodes when paused (line 1364-1367)
- This matches how ProjectileSystemTest is placed (after pause check)

**Pause behavior summary:**
| isPaused | Node.update_all | Serpent.update | Expected |
|----------|-----------------|----------------|----------|
| false    | ✅ runs         | ✅ runs        | Normal play |
| true     | ❌ skipped      | ❌ skipped     | Game frozen |

**Change 5: Add "Serpent" button to main menu**

**ACTUAL main menu button pattern (verified at main.lua:269-306)**:
Buttons are defined in `initMainMenu()` via `MainMenuButtons.setButtons({...})`.

```lua
-- In initMainMenu(), around line 269, find the existing MainMenuButtons.setButtons call
-- Add a Serpent button BEFORE the Language button (second-to-last position):

MainMenuButtons.setButtons({
    -- ... existing Start, Discord, Bluesky buttons ...
    {
        label = "Serpent",  -- Or localization.get("ui.serpent_mode") if adding localization
        onClick = function()
            record_telemetry("serpent_clicked", { scene = "main_menu" })
            changeGameState(GAMESTATE.SERPENT)
        end
    },
    {
        label = localization.get("ui.switch_language"),  -- Keep Language button last
        onClick = function() ... end
    },
})
```

**Why this location**: After the Bluesky button, before Language, keeps main game-start options grouped together.

**What runs during SERPENT state:**
- ✅ `timer.update(dt)` - Serpent uses timer system
- ✅ `Node.update_all(dt)` - Serpent entities use Node system
- ✅ `Text.update(dt)` - Serpent UI uses TextBuilder
- ❌ `initMainGame()` - NOT called (planning/shop/action phases not loaded)
- ❌ `gameplay.lua` combat loop - NOT running (Serpent has its own)

### Game State Integration

**Serpent's internal FSM** (from `core/fsm.lua` pattern):
```lua
-- In serpent_main.lua:
local FSM = require("core.fsm")

local SerpentStates = FSM.define{
  initial = "playing",  -- Start directly in gameplay
  states = {
    playing = { enter = start_wave, update = update_combat, transitions = { "shop", "game_over", "victory" } },
    shop = { enter = open_shop, update = update_shop, transitions = { "playing" } },
    game_over = { enter = show_game_over, transitions = { "exit" } },
    victory = { enter = show_victory, transitions = { "exit" } },
    exit = { enter = function() Serpent.cleanup(); changeGameState(GAMESTATE.MAIN_MENU) end },
  }
}
```

**Serpent Teardown/Reset Contract:**

When exiting SERPENT state (via "exit" FSM state or externally), `Serpent.cleanup()` MUST:

1. **Destroy all Serpent entities** - Use `registry:destroy()` (verified pattern from codebase):
   ```lua
   -- Pattern from gameplay.lua:734, wave_director.lua:351, etc.
   for _, entity in ipairs(serpent_entities) do
       registry:destroy(entity)
   end
   serpent_entities = {}
   ```

2. **Clear signal handlers** - Use **SHARED signal_group** (all Serpent modules use same group):
   ```lua
   -- In Serpent.init(), create ONE signal group for ALL Serpent modules:
   local signal_group = require("core.signal_group")
   serpent_handlers = signal_group.new("serpent_main")
   
   -- Pass to submodules during init (they don't create their own):
   SerpentWaveDirector.init(serpent_handlers, serpent_combat_context)
   SerpentShop.init(serpent_handlers, SnakeController)  -- Shop needs snake_controller for selling
   
   -- In submodules, register handlers through the PASSED group:
   function SerpentWaveDirector.init(handlers, ctx)
       handlers:on("serpent_death", function(ev) ... end)
       handlers:on("serpent_wave_complete", function() ... end)
   end
   
   -- In Serpent.cleanup(), single call removes ALL handlers from ALL modules:
   if serpent_handlers then
       serpent_handlers:cleanup()  -- Removes all registered handlers
       serpent_handlers = nil
   end
   ```
   
   **Signal Group Ownership Rule:** Only `serpent_main.lua` creates and owns the signal_group.
   All other Serpent modules receive it as a parameter and use `:on()` to register.
   **NEVER use `signal.register()` directly in Serpent modules** - always go through the group.

3. **Clear combat context** - Create fresh context each run (no unsubscribe needed):
   ```lua
   -- Strategy: Don't reuse combatBus - let old one be GC'd
   -- On cleanup:
   serpent_combat_context.snake_units = {}
   serpent_combat_context.enemies = {}
   serpent_combat_context = nil  -- Allow GC, combatBus listeners go with it
   
   -- On next init(), create fresh context (already in Integration Contract)
   ```

4. **Reset game state** - Clear wave counter, gold, FSM, etc.
   ```lua
   current_wave = 0
   player_gold = 0
   serpent_fsm = nil
   ```

**Re-entry safety**: `Serpent.init()` MUST be idempotent - call `cleanup()` at start if already initialized to prevent duplicate entities on re-entry.

### Entity Representation (Module Responsibility Split)

**Architecture Decision: PURE LOGIC + THIN ADAPTERS**

To enable testability, Serpent modules are split into:

1. **Pure Logic Modules** (testable without engine, no globals):
   - `serpent/data/units.lua` - Lua tables with unit definitions
   - `serpent/data/enemies.lua` - Lua tables with enemy definitions  
   - `serpent/synergy_system.lua` - Pure function: `calculate(class_list) -> bonuses_table`
   - `serpent/wave_config.lua` - Configuration data and scaling formulas
   - `serpent/serpent_shop.lua` - Shop state machine (gold, offerings, reroll cost)
   - `serpent/snake_controller.lua` - **PUBLIC API** (Task 3 creates this) - wraps snake_logic + coordinates with adapter
   - `serpent/auto_attack.lua` - **PUBLIC API** (Task 7 creates this) - wraps auto_attack_logic + adapter

   **Internal pure helpers** (created by Tasks 3/7 as needed):
   - `serpent/snake_logic.lua` - Pure snake state (unit array, add/remove, no ECS)
   - `serpent/auto_attack_logic.lua` - Pure targeting math, cooldown tracking

   **Test pattern**: Direct `require()`, call functions, assert on returned tables.

2. **Thin Engine Adapters** (bridge to ECS/combat, NOT unit tested):
   - `serpent/snake_entity_adapter.lua` - Calls `registry`, steering APIs
   - `serpent/combat_adapter.lua` - Bridges to `serpent_combat_context` and Effects
   - `serpent/enemy_spawner_adapter.lua` - Uses existing enemy_factory patterns

   **Test pattern**: Runtime verification via manual play (canvas-based game).

**This split means:**
- Unit tests run fast with no engine globals
- Core game logic is portable and deterministic
- Adapters are thin wrappers (~20-50 lines each)

### Context Plumbing Contract (How Modules Access Shared State)

**CRITICAL: All Serpent modules receive dependencies via constructor/init, NOT globals.**

| Module | Receives | From |
|--------|----------|------|
| `serpent_main.lua` | OWNS: `serpent_combat_context`, `serpent_handlers` | Creates them |
| `serpent_wave_director.lua` | `handlers`, `ctx` | `serpent_main.init()` |
| `serpent_shop.lua` | `handlers`, `snake_controller` | `serpent_main.init()` |
| `snake_controller.lua` | `ctx` (for snake_units) | `serpent_main.init()` |
| `auto_attack.lua` | `ctx` (for targeting) | `serpent_main.init()` |
| `combat_adapter.lua` | `ctx.stat_defs` | Passed per-call |

**Initialization pattern in serpent_main.lua:**
```lua
function Serpent.init()
    -- 1. Create owned resources
    serpent_handlers = signal_group.new("serpent_main")
    serpent_combat_context = { ... }  -- as shown below
    
    -- 2. Initialize submodules with dependencies
    SnakeController.init(serpent_combat_context)
    AutoAttack.init(serpent_combat_context)
    SerpentWaveDirector.init(serpent_handlers, serpent_combat_context)
    SerpentShop.init(serpent_handlers, SnakeController)
end
```

**Access pattern in submodules:**
```lua
-- serpent_wave_director.lua
local handlers, ctx  -- Module-level locals

function SerpentWaveDirector.init(h, c)
    handlers = h  -- Store reference
    ctx = c       -- Store reference
end

function SerpentWaveDirector.on_enemy_death(ev)
    -- Access ctx.enemies directly - it's the SAME table as serpent_main's
    for i, enemy in ipairs(ctx.enemies) do
        if enemy == ev.entity then
            table.remove(ctx.enemies, i)
            break
        end
    end
end
```

**Why NOT globals:**
- Testability: Can inject mock ctx/handlers in tests
- Explicit dependencies: Clear what each module needs
- No risk of accessing stale/nil globals between runs

### Combat System Integration (ACTUAL Pattern from gameplay.lua:6376-6395)

**CRITICAL: How Serpent units become combat actors**

The existing combat system expects "actors" with specific structure. Serpent creates simplified actors:

**Step 1: Create combat context in Serpent.init()** (mirrors gameplay.lua:6376-6395):
```lua
-- In serpent_main.lua:
local CombatSystem = require("combat.combat_system")
local EventBridge = require("core.event_bridge")
local signal = require("external.hump.signal")

local serpent_combat_context = nil

function Serpent.init()
    local combatStatDefs, DAMAGE_TYPES = CombatSystem.Core.StatDef.make()
    local combatBus = CombatSystem.Core.EventBus.new()
    local combatTime = CombatSystem.Core.Time.new()
    
    serpent_combat_context = {
        stat_defs    = combatStatDefs,
        DAMAGE_TYPES = DAMAGE_TYPES,
        bus          = combatBus,
        time         = combatTime,
        snake_units  = {},  -- Array of SerpentUnitActor
        enemies      = {},  -- Array of SerpentEnemyActor
        get_enemies_of = function(a) return serpent_combat_context.enemies end,
        get_allies_of  = function(a) return serpent_combat_context.snake_units end,
    }
    
    -- Bridge events (NOTE: OnDeath requires manual bridging per event_bridge.lua)
    EventBridge.attach(serpent_combat_context)
    
    -- Manually bridge OnDeath to wave clearing logic
    -- Note: ev.entity is the dead actor, ev.killer is who killed them
    combatBus:on("OnDeath", function(ev)
        signal.emit("serpent_death", ev)  -- Forward full payload for wave manager
    end)
end
```

**Step 2: Define Serpent actor structure** (using verified combat system patterns):

**Verified API** (from `combat_system.lua:1194` and `action_api.lua:402`):
- `CombatSystem.Core.Stats.new(defs)` - Create stats object
- `stats.values[name].base = value` - Set base stat value directly
- `stats:recompute()` - Apply derived stats

```lua
-- In serpent/combat_adapter.lua:
local CombatSystem = require("combat.combat_system")

local CombatAdapter = {}

-- Create a combat actor from Serpent unit data
-- NOTE: Uses Core.Stats.new(), NOT StatBlock.new()
-- NOTE: Actor identity is by TABLE REFERENCE, not by id string
function CombatAdapter.make_unit_actor(unit_data, ecs_entity_id, stat_defs)
    local stats = CombatSystem.Core.Stats.new(stat_defs)
    
    -- Set base stats directly (per combat_system.lua pattern)
    -- NOTE: stat_defs defines "health" but NOT "health_max"
    -- Use actor.max_health field for max HP (combat system uses this)
    stats.values.health = { base = unit_data.hp, add_pct = 0, mul_pct = 0 }
    stats.values.weapon_min = { base = unit_data.attack, add_pct = 0, mul_pct = 0 }
    stats.values.weapon_max = { base = unit_data.attack, add_pct = 0, mul_pct = 0 }
    stats:recompute()
    
    return {
        -- IDENTITY: Remove by TABLE REFERENCE (enemy == dead_actor), not id string
        -- id is only for debugging/display, NOT for lookup
        id = unit_data.id,  -- For debugging only (e.g., "soldier_1")
        ecs_entity = ecs_entity_id,  -- Custom field for ECS entity ID (NOT .entity to avoid OnDeath confusion)
        stats = stats,
        hp = unit_data.hp,      -- Current HP (damage reduces this)
        max_health = unit_data.hp,  -- Max HP (combat system uses actor.max_health)
        side = 1,  -- Snake units are side 1
        class = unit_data.class,
        level = unit_data.level or 1,
        dead = false,  -- Required by combat system
        -- Required by Effects.deal_damage:
        name = unit_data.name,
        tags = { unit_data.class },  -- For targeting by class
    }
end

-- Create a combat actor from enemy data
-- NOTE: Actor identity is by TABLE REFERENCE, not by id string
function CombatAdapter.make_enemy_actor(enemy_data, ecs_entity_id, stat_defs)
    local stats = CombatSystem.Core.Stats.new(stat_defs)
    
    -- NOTE: stat_defs defines "health" but NOT "health_max"
    -- Use actor.max_health field for max HP (combat system uses this)
    stats.values.health = { base = enemy_data.hp, add_pct = 0, mul_pct = 0 }
    stats.values.weapon_min = { base = enemy_data.damage, add_pct = 0, mul_pct = 0 }
    stats.values.weapon_max = { base = enemy_data.damage, add_pct = 0, mul_pct = 0 }
    stats:recompute()
    
    return {
        -- IDENTITY: Remove by TABLE REFERENCE (enemy == dead_actor), not id string
        -- id is only for debugging/display, NOT for lookup
        id = enemy_data.id,  -- For debugging only (e.g., "slime_17")
        ecs_entity = ecs_entity_id,
        stats = stats,
        hp = enemy_data.hp,      -- Current HP (damage reduces this)
        max_health = enemy_data.hp,  -- Max HP (combat system uses actor.max_health)
        side = 2,  -- Enemies are side 2
        dead = false,
        name = enemy_data.name,
        tags = enemy_data.tags or {},
    }
end

-- Deal damage using Effects pipeline
function CombatAdapter.deal_damage(ctx, attacker, target, amount)
    CombatSystem.Game.Effects.deal_damage{ 
        components = {{type = 'physical', amount = amount}} 
    }(ctx, attacker, target)
end

-- Heal using Effects pipeline
function CombatAdapter.heal(ctx, target, amount)
    CombatSystem.Game.Effects.heal{ flat = amount }(ctx, nil, target)
end

-- Check if actor is dead (combat system sets .dead flag)
function CombatAdapter.is_dead(actor)
    return actor.dead or actor.stats:get("health") <= 0
end

return CombatAdapter
```

**Step 3: Death detection and wave clearing**

The `OnDeath` event from `ctx.bus` is NOT automatically bridged to `hump.signal` (per `event_bridge.lua` docs). Serpent must manually detect deaths:

**OnDeath Payload Contract** (verified from `combat_system.lua:2423`):
```lua
-- The ACTUAL OnDeath event payload from combat system:
ctx.bus:emit('OnDeath', { entity = tgt, killer = src })

-- So the payload is:
{
    entity = <the_dead_combat_actor>,  -- The combat actor that died (NOT ECS entity ID!)
    killer = <the_attacker_actor>       -- The actor that dealt the killing blow
}

-- Example: When enemy with id="goblin_1" dies:
{
    entity = {  -- This IS the combat actor, confusingly named "entity"
        id = "goblin_1",
        hp = 0,
        stats = <StatBlock>,
        side = 2,  -- Enemy side
        name = "Goblin",
        -- ... other actor fields
    },
    killer = { ... }  -- The unit that killed it
}
```

**NOTE**: The combat system uses `entity` to mean "the combat actor being acted upon", NOT an ECS entity ID. This follows the existing gameplay.lua convention.

**Wave Director Death Handling (Pure Logic + Runtime Coordination)**

The WaveDirector is **pure logic** - it tracks enemy data and detects deaths via `hp <= 0`.
The **coordinator** (`serpent_main.lua`) owns the bridge between CombatSystem events and WaveDirector.

```lua
-- serpent_wave_director.lua (PURE LOGIC - no signals, no ECS, no CombatSystem)
local SerpentWaveDirector = {}
SerpentWaveDirector.__index = SerpentWaveDirector

function SerpentWaveDirector.create()
    return setmetatable({
        current_wave = 1,
        gold = 0,
        tracked_enemies = {},  -- Simple data tables: { id, hp, max_hp, ... }
        wave_complete = false,
    }, SerpentWaveDirector)
end

-- Called by coordinator after spawning enemies
function SerpentWaveDirector:track_enemy(enemy_data)
    table.insert(self.tracked_enemies, enemy_data)
    self.wave_complete = false
end

-- Called each frame - checks if all tracked enemies are dead
function SerpentWaveDirector:update(dt)
    if self.wave_complete then return end
    
    -- Check all tracked enemies
    local all_dead = true
    for _, enemy in ipairs(self.tracked_enemies) do
        if enemy.hp > 0 then
            all_dead = false
            break
        end
    end
    
    if all_dead and #self.tracked_enemies > 0 then
        self.wave_complete = true
    end
end

function SerpentWaveDirector:is_wave_complete()
    return self.wave_complete
end

return SerpentWaveDirector
```

```lua
-- serpent_main.lua (COORDINATOR - owns signal bridge)
local signal = require("external.hump.signal")
local WaveDirector = require("serpent.serpent_wave_director")

local wave_director = WaveDirector.create()

-- When CombatSystem emits OnDeath, we need to update tracked enemy hp
-- The tracked_enemy table IS the enemy_actor, so mutation propagates automatically
function Serpent.init()
    -- ... combat context setup ...
    
    -- Bridge OnDeath to wave director tracking
    serpent_combat_context.bus:on("OnDeath", function(ev)
        -- ev.entity is the dead combat actor
        -- Since we track the SAME table references, hp is already 0
        -- Wave director's update() will detect this
        
        -- Also remove from combat context
        for i, enemy in ipairs(serpent_combat_context.enemies) do
            if enemy == ev.entity then
                table.remove(serpent_combat_context.enemies, i)
                break
            end
        end
    end)
end

function Serpent.update(dt)
    -- ... other updates ...
    
    wave_director:update(dt)
    
    if wave_director:is_wave_complete() then
        wave_director:complete_wave()  -- Grants gold
        -- Transition to shop
    end
end
```

**Why this works:**
- When creating enemies, coordinator passes the SAME table reference to both:
  - `CombatAdapter.make_enemy_actor(enemy_data, ...)` → combat actor with `.hp`
  - `wave_director:track_enemy(enemy_data)` → same table reference
- When combat system deals damage, it modifies `actor.hp`
- WaveDirector's update() reads the same `.hp` field
- No signal bridge needed for death detection (just hp <= 0 check)

**Actor-to-ECS-Entity Mapping Strategy:**
- Serpent actors store a custom `.ecs_entity` field (NOT `.entity` to avoid confusion with OnDeath payload)
- When ECS entity ID is needed (e.g., for position), access via `actor.ecs_entity`
- This differs from gameplay.lua which uses a separate `combatActorToEntity` map

### Contact Damage Collision Integration (Verified Pattern from gameplay.lua:9124-9210)

**CRITICAL: How enemies deal contact damage to snake segments.**

**Reference file**: `assets/scripts/core/gameplay.lua:9124-9210` shows the EXACT pattern for player-enemy collision callbacks.

**Collision Tags** (from `core/constants.lua`):
```lua
local C = require("core.constants")
-- Existing tags we can use:
-- C.CollisionTags.PLAYER = "player"
-- C.CollisionTags.ENEMY = "enemy"

-- Serpent will use:
-- "serpent_segment" - custom tag for snake body segments (NOT "player" to avoid conflicts)
-- C.CollisionTags.ENEMY - reuse existing enemy tag
```

**Physics World**: Serpent uses the same "world" physics world as the main game:
```lua
local world = PhysicsManager.get_world("world")
```

**Step 1: Define collision tags in Serpent.init()** (after entity creation):

**Collision Tag Registration Strategy (VERIFIED from C++ source):**

Tags are registered via two mechanisms in this codebase:
1. **C++ startup**: `game.cpp:1271-1272` calls `physicsWorld->AddCollisionTag()` for "default" and "player"
2. **Auto-registration**: `physics_world.cpp:1081-1082` shows `AddShapeToEntity()` auto-adds unknown tags:
   ```cpp
   if (!collisionTags.contains(tag))
     AddCollisionTag(tag);
   ```

**Serpent's approach:**

**CRITICAL: SERPENT mode does NOT run gameplay.lua's tag initialization (initActionPhase).**
Gameplay.lua:9986-9995 explicitly registers tags including "enemy". Since Serpent bypasses this,
**Serpent.init() MUST register required tags manually**.

**DO NOT call `physics.set_collision_tags()`** - it CLEARS and overwrites ALL tags (`physics_world.cpp:560-561`)

**Required initialization order in Serpent.init():**
```lua
local world = PhysicsManager.get_world("world")

-- STEP 1: Register collision tags BEFORE any entity creation or collision setup
-- (mirrors gameplay.lua:9986-9995 pattern)
world:AddCollisionTag(C.CollisionTags.ENEMY)       -- Required for enemies
world:AddCollisionTag("serpent_segment")           -- For snake segments

-- STEP 2: Create snake segment entities (their physics bodies use "serpent_segment" tag)
-- ... create entities ...

-- STEP 3: Create enemy entities (their physics bodies use C.CollisionTags.ENEMY tag)
-- ... create enemies ...

-- STEP 4: Enable collision masks AFTER tags exist
physics.enable_collision_between_many(world, "serpent_segment", { C.CollisionTags.ENEMY })
physics.enable_collision_between_many(world, C.CollisionTags.ENEMY, { "serpent_segment" })
physics.update_collision_masks_for(world, "serpent_segment", { C.CollisionTags.ENEMY })
physics.update_collision_masks_for(world, C.CollisionTags.ENEMY, { "serpent_segment" })

-- STEP 5: Register collision callbacks
physics.on_pair_presolve(world, "serpent_segment", C.CollisionTags.ENEMY, contact_damage_callback)

-- Verify tags (debugging, can be removed after verification):
world:PrintCollisionTags()  -- Should show both "serpent_segment" and "enemy"
```

**Why this order matters:**
- `AddCollisionTag` must happen BEFORE `enable_collision_between_many` (otherwise masks lookup fails)
- `on_pair_presolve` requires both tags to exist (otherwise callback won't register)

**Verification checklist for Task 10:**
- [ ] `world:PrintCollisionTags()` shows both "serpent_segment" and "enemy"
- [ ] Collision callback fires repeatedly while enemy overlaps segment

**Step 2: Create snake segment physics bodies** (in snake_entity_adapter.lua):

**VERIFIED API** (from `entity_builder.lua` and `physics_builder.lua`):
- `EntityBuilder.new(sprite):at(x, y):size(w, h):build()` - creates entity with transform
- `PhysicsBuilder.for_entity(entity):circle():tag(tag):apply()` - adds physics body

```lua
-- When creating each snake segment entity:
local EntityBuilder = require("core.entity_builder")
local PhysicsBuilder = require("core.physics_builder")

-- Step 1: Create entity with transform (NO :transform() or :physics() methods exist!)
local segment_entity = EntityBuilder.new("snake_segment_sprite")
    :at(x, y)
    :size(SEGMENT_SIZE, SEGMENT_SIZE)
    :build()

-- Step 2: Add physics body separately
PhysicsBuilder.for_entity(segment_entity)
    :circle()
    :tag("serpent_segment")
    :sensor(false)  -- false = solid body for collision
    :density(1.0)
    :apply()

-- Alternative using direct physics API (same result):
-- physics.create_physics_for_transform(
--     registry,
--     physics_manager_instance,
--     segment_entity,
--     "world",  -- worldName
--     {
--         shape = "circle",
--         tag = "serpent_segment",
--         sensor = false,
--         density = 1.0,
--     }
-- )
```

**Step 3: Register collision callback** (pattern from gameplay.lua:9126-9151):
```lua
-- In serpent_main.lua, after setting up collision masks:
local contact_cooldowns = {}  -- { [enemy_actor] = { [segment_actor] = last_damage_time } }
local CONTACT_DAMAGE_COOLDOWN = 0.5  -- seconds between damage ticks

-- WHY on_pair_presolve (NOT on_pair_begin):
-- - on_pair_begin fires ONCE when contact starts, then never again while overlapping
-- - on_pair_presolve fires EVERY PHYSICS STEP while bodies overlap
-- - We need repeated checks to implement "damage every 0.5s while in contact"
-- - Verified from physics_world.cpp: presolve handlers run each simulation step

physics.on_pair_presolve(world, "serpent_segment", C.CollisionTags.ENEMY, function(arb)
    local a, b = arb:entities()
    
    -- DISAMBIGUATION: Try lookup in both lists - whichever succeeds tells us the type
    -- (Same approach as gameplay.lua:9134-9137 which compares against known survivorEntity)
    local segment_actor = find_actor_by_ecs_entity(serpent_combat_context.snake_units, a)
                       or find_actor_by_ecs_entity(serpent_combat_context.snake_units, b)
    local enemy_actor = find_actor_by_ecs_entity(serpent_combat_context.enemies, a)
                     or find_actor_by_ecs_entity(serpent_combat_context.enemies, b)
    
    if segment_actor and enemy_actor and not segment_actor.dead and not enemy_actor.dead then
        -- Check cooldown using os.clock() (verified pattern from projectile_system.lua:1865, etc.)
        -- NOTE: ctx.time is combat time (ticked manually), not wall clock
        local now = os.clock()
        contact_cooldowns[enemy_actor] = contact_cooldowns[enemy_actor] or {}
        local last_hit = contact_cooldowns[enemy_actor][segment_actor] or 0
        
        if now - last_hit >= CONTACT_DAMAGE_COOLDOWN then
            -- Deal damage to segment
            CombatAdapter.deal_damage(serpent_combat_context, enemy_actor, segment_actor, enemy_actor.stats:get("weapon_min"))
            contact_cooldowns[enemy_actor][segment_actor] = now
            
            -- Visual feedback
            hitFX(segment_actor.ecs_entity, 10, 0.2)
            playSoundEffect("effects", "player_hurt", 0.9 + math.random() * 0.2)
        end
    end
    return true  -- Allow collision to proceed (return false to stop collision response)
end)
```

**Time API Clarification:**
- `ctx.time` is `CombatSystem.Core.Time` instance: `{ now = 0 }` with `:tick(dt)` method (combat_system.lua:975-984)
- `ctx.time.now` gives combat-ticked time (requires manual `ctx.time:tick(dt)` in Serpent.update)
- For contact damage cooldown, use `os.clock()` instead (verified pattern across codebase: projectile_system.lua:1865, wave_manager.lua:163, etc.)

**Helper function to find actor by ECS entity:**
```lua
local function find_actor_by_ecs_entity(actor_list, ecs_entity)
    for _, actor in ipairs(actor_list) do
        if actor.ecs_entity == ecs_entity then
            return actor
        end
    end
    return nil
end
```

**Verification Checklist (Task 10):**
- [ ] Snake segments have physics bodies with "serpent_segment" tag
- [ ] Enemies have physics bodies with C.CollisionTags.ENEMY tag
- [ ] Collision callback fires when enemy touches segment
- [ ] Damage is dealt ONCE per cooldown window (not every frame)
- [ ] Damage goes to SPECIFIC segment that was hit (not all segments)
- [ ] Dead actors don't trigger more damage
- [ ] Cooldown map is cleaned up when actors die

### Test Helpers Architecture (Pure Lua, No Engine Dependencies)

**Test helpers (`serpent/tests/test_helpers.lua`):**

```lua
local TestHelpers = {}

-- MockSnake: Simulates snake state without ECS
-- Supports callbacks for testing coordinator behavior
function TestHelpers.MockSnake(config)
    local self = {
        units = config.units or {},
        synergies = config.synergies or {},
        -- Callback hooks for testing
        on_unit_removed = config.on_unit_removed,  -- Called when unit removed
    }
    
    function self:get_unit_count() 
        return #self.units 
    end
    
    function self:get_all_positions()
        local positions = {}
        for i, u in ipairs(self.units) do
            positions[i] = {x = u.x or 0, y = u.y or 0}
        end
        return positions
    end
    
    function self:remove_unit(id)
        for i, u in ipairs(self.units) do
            if u.id == id then 
                local removed = table.remove(self.units, i)
                -- Fire callback if registered (for testing gap-close behavior)
                if self.on_unit_removed then
                    self.on_unit_removed(removed, i)
                end
                return true
            end
        end
        return false
    end
    
    return self
end

-- MockEnemy: Simple enemy stub for targeting tests
function TestHelpers.MockEnemy(config)
    return {
        x = config.x or 0,
        y = config.y or 0,
        hp = config.hp or 100,
        id = config.id or "mock_enemy",
    }
end

-- RunSimulation: For integration tests ONLY (requires game running)
-- NOTE: This cannot be used in unit tests - use for Task 17/18 only
function TestHelpers.RunSimulation(config)
    error("RunSimulation requires full game context - use for Task 17/18 only")
end

return TestHelpers
```

### UI System Integration

**Serpent UI uses `ui.ui_syntax_sugar`** (verified from `docs/api/ui-dsl-reference.md` and in-repo usage):

**UI Module Choice:**
- `ui.ui_syntax_sugar` - The modern DSL documented in `docs/api/ui-dsl-reference.md` (use this)
- `ui.ui_defs` - Older helper functions (exists but has less consistent API)

**Reference usage**: See `assets/scripts/ui/skills_panel.lua`, `assets/scripts/ui/level_up_screen.lua` for real examples.

```lua
-- In serpent/ui/shop_ui.lua:
local dsl = require("ui.ui_syntax_sugar")  -- Use modern DSL

function ShopUI:create_offering_panel(offering)
    return dsl.vbox({
        dsl.text(offering.name),
        dsl.text(offering.class, { color = CLASS_COLORS[offering.class] }),
        dsl.text(offering.cost .. "g"),
        dsl.button("Buy", { onClick = function() self:purchase(offering) end }),
    })
end
```

### Ability Scope Clarification

**Which unit specials are implemented in the vertical slice:**

| Unit | Special | Status |
|------|---------|--------|
| Soldier | None | N/A |
| Apprentice | None | N/A |
| Scout | None | N/A |
| Healer | Heal adjacent 10 HP/sec | **IMPLEMENTED** |
| Knight | 20% damage reduction | **STUBBED** (flat DR stat) |
| Pyromancer | Burns 5 dmg/sec | **STUBBED** (basic DoT) |
| Sniper | 20% crit, 2x damage | **STUBBED** (crit stat) |
| Bard | +10% attack speed aura | **STUBBED** (flat bonus) |
| Berserker | +5%/kill frenzy | **DEFERRED** |
| Archmage | Hits 3 enemies | **STUBBED** (single target) |
| Assassin | +100% from behind | **DEFERRED** |
| Paladin | Divine Shield | **DEFERRED** |
| Champion | Cleave all in range | **STUBBED** (single target) |
| Lich | Pierce through enemies | **DEFERRED** |
| Windrunner | Fires 3 arrows | **STUBBED** (single arrow) |
| Angel | Resurrect 1st dead/wave | **DEFERRED** |

**Legend:**
- **IMPLEMENTED** = Full mechanic works
- **STUBBED** = Simplified (single target, flat stat)
- **DEFERRED** = Not in vertical slice

**Reconciliation with Task 7 "no AoE" guardrail:**
- Task 7's "single target only" applies to auto-attack system
- AoE specials (Archmage, Champion, Windrunner) are STUBBED as single target

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: YES (`assets/scripts/tests/` with `describe()/it()` pattern)
- **User wants tests**: YES (TDD)
- **Framework**: Lua test framework at `assets/scripts/tests/test_runner.lua`

### TDD Workflow

Each TODO follows RED-GREEN-REFACTOR.

**CRITICAL: Test File Header** (from `test_spawn.lua` pattern):
```lua
-- EVERY Serpent test file MUST start with this header:
-- Add assets/scripts to package path (required for require() to find modules)
package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")
```

**Why this is required:** The test runner does NOT set `package.path`. Without this line, `require("serpent.data.units")` will fail with "module not found".

**Full Test File Template:**
```lua
-- Test file: assets/scripts/serpent/tests/test_example.lua
-- Add assets/scripts to package path
package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")
local MyModule = require("serpent.my_module")

t.describe("MyModule", function()
  t.it("should do something", function()
    t.expect(actual).to_be(expected)        -- Strict equality
    t.expect(actual).to_equal(expected)     -- Deep equality for tables
    t.expect(actual).to_contain(substring)  -- String contains
    t.expect(actual).to_be_truthy()         -- Not nil/false
    t.expect(actual).to_be_falsy()          -- nil or false
    t.expect(actual).to_be_nil()            -- Exactly nil
    t.expect(fn).to_throw("pattern")        -- Error matching pattern
    t.expect(x).never().to_be(y)            -- Negation
  end)
end)

t.run()  -- REQUIRED: Executes the tests
```

**Running tests:**
```bash
# From repository root:
lua assets/scripts/serpent/tests/test_units.lua  # Run single test file
# Or run all Serpent tests:
for f in assets/scripts/serpent/tests/test_*.lua; do lua "$f"; done
```

**WRONG** (do NOT use globals or skip package.path):
```lua
-- WRONG - missing package.path:
local t = require("tests.test_runner")  -- Works
local units = require("serpent.data.units")  -- FAILS: module not found

-- WRONG - global syntax:
describe("...", function() ... end)  -- No global describe
assert.equals(a, b)                  -- No global assert.equals
```

**Task Structure:**
1. **RED**: Write failing test first
   - Test file: `assets/scripts/serpent/tests/test_{feature}.lua`
   - Test command: `lua assets/scripts/tests/test_runner.lua assets/scripts/serpent/tests/`
   - Expected: FAIL (test exists, implementation doesn't)
2. **GREEN**: Implement minimum code to pass
   - Command: `lua assets/scripts/tests/test_runner.lua -f {feature} assets/scripts/serpent/tests/`
   - Expected: PASS
3. **REFACTOR**: Clean up while keeping green
   - Command: `lua assets/scripts/tests/test_runner.lua assets/scripts/serpent/tests/`
   - Expected: PASS (all tests still pass)

**Test Utilities**: Serpent tests will create a shared test helper at `assets/scripts/serpent/tests/test_helpers.lua` providing:
- `MockSnake`: Stub snake controller for unit tests
- `MockEnemy`: Stub enemy for combat tests  
- `RunSimulation`: Integration test harness that wraps game loop

### Verification by Deliverable Type

| Type | Verification Tool | Procedure |
|------|------------------|-----------|
| **Lua modules** | Lua test framework | Run test file, assert expected behavior |
| **Gameplay (canvas)** | Manual runtime verification | Run game, perform actions, observe behavior, capture screenshot evidence |
| **Performance** | Console timing logs | Assert frame time < 16ms with 30 enemies |

**Note on Canvas-Based Games:**
This is a Raylib/C++ game rendered to canvas. Playwright/browser automation CANNOT:
- Read canvas pixel state
- Simulate game input (only DOM events, not Raylib input)
- Assert on in-game state

**For gameplay verification, Tasks use "Runtime Verification Checklist":**
1. Build and run game (`just build-debug && ./build/raylib-cpp-cmake-template`)
2. Navigate to Serpent mode via main menu
3. Perform specified actions
4. Observe expected behavior
5. Capture screenshot to `.sisyphus/evidence/`

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately):
├── Task 1: Project setup + folder structure
├── Task 2: Unit data definitions (16 units)
└── Task 5: Enemy data definitions (11 enemies)

Wave 2 (After Wave 1):
├── Task 3: Snake movement controller [depends: 1]
├── Task 4: Synergy system (pure logic) [depends: 2]
└── Task 6: Wave configuration (20 waves) [depends: 5]

Wave 3 (After Wave 2):
├── Task 7: Auto-attack system [depends: 3]
├── Task 8: Shop system adaptation [depends: 2, 4]
└── Task 9: Unit spawning + leveling [depends: 2, 3]

Wave 4 (After Wave 3):
├── Task 10: Combat integration [depends: 7, 9]
├── Task 11: Wave director integration [depends: 6, 10]
└── Task 12: Shop UI [depends: 8]

Wave 5 (After Wave 4):
├── Task 13: Synergy UI [depends: 4, 12]
├── Task 14: HUD (HP, gold, wave) [depends: 11]
└── Task 15: Boss implementations [depends: 10, 11]

Wave 6 (After Wave 5):
├── Task 16: Death/victory screens [depends: 11, 14]
├── Task 17: Balance tuning pass [depends: all]
└── Task 18: Final integration test [depends: all]

Critical Path: Task 1 → Task 3 → Task 7 → Task 10 → Task 14
Parallel Speedup: ~50% faster than sequential
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 3, 4, 6, 8 | 2, 5 |
| 2 | None | 4, 8, 9 | 1, 5 |
| 3 | 1 | 7, 9 | 4, 6 |
| 4 | 2 | 8, 13 | 3, 6 |
| 5 | None | 6 | 1, 2 |
| 6 | 5 | 11 | 3, 4 |
| 7 | 3 | 10 | 8, 9 |
| 8 | 2, 4 | 12 | 7, 9 |
| 9 | 2, 3 | 10 | 7, 8 |
| 10 | 7, 9 | 11, 15 | 12 |
| 11 | 6, 10 | 14, 15, 16 | 12 |
| 12 | 8 | 13 | 10, 11 |
| 13 | 4, 12 | 17 | 14, 15 |
| 14 | 11 | 16, 17 | 13, 15 |
| 15 | 10, 11 | 17 | 13, 14 |
| 16 | 11, 14 | 18 | 17 |
| 17 | 13, 14, 15 | 18 | 16 |
| 18 | 16, 17 | None | None (final) |

### Agent Dispatch Summary

| Wave | Tasks | Recommended Agent Profile |
|------|-------|---------------------------|
| 1 | 1, 2, 5 | `category="quick"`, `load_skills=[]` - Data setup |
| 2 | 3, 4, 6 | `category="unspecified-high"`, `load_skills=[]` - Core systems |
| 3 | 7, 8, 9 | `category="unspecified-high"`, `load_skills=[]` - Integration |
| 4 | 10, 11, 12 | `category="visual-engineering"`, `load_skills=["frontend-ui-ux"]` - UI work |
| 5 | 13, 14, 15 | `category="unspecified-high"`, `load_skills=[]` - Polish |
| 6 | 16, 17, 18 | `category="unspecified-high"`, `load_skills=[]` - Final QA (manual play testing) |

---

## TODOs

### Task 1: Project Setup + Folder Structure

**What to do**:
- Create `assets/scripts/serpent/` directory structure
- Create main entry point `serpent_main.lua`
- Create test directory `assets/scripts/serpent/tests/`
- Set up basic game state machine (menu → playing → shop → game_over)

**Must NOT do**:
- Don't create any gameplay logic yet
- Don't add assets beyond placeholder shapes

**Recommended Agent Profile**:
- **Category**: `quick`
  - Reason: Simple file creation and structure setup
- **Skills**: `[]`
  - No special skills needed for file creation
- **Skills Evaluated but Omitted**:
  - `frontend-ui-ux`: Not needed for folder setup

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 1 (with Tasks 2, 5)
- **Blocks**: Tasks 3, 4, 6, 8
- **Blocked By**: None (can start immediately)

**References**:

**Pattern References** (existing code to follow):
- `assets/scripts/core/fsm.lua` - Declarative finite state machine with `FSM.define{}` pattern
- `assets/scripts/core/main.lua:40-48` - GAMESTATE table pattern for game states
- `assets/scripts/core/gameplay.lua` - Game loop and update patterns

**Documentation References**:
- `docs/README.md` - Project structure conventions

**WHY Each Reference Matters**:
- `fsm.lua` provides the exact state machine pattern to use (define states, transitions, enter/exit callbacks)
- `main.lua` shows how GAMESTATE enum is defined and used
- `gameplay.lua` shows how game systems are initialized and updated

**Acceptance Criteria**:

```bash
# Agent runs:
ls -la assets/scripts/serpent/
# Assert: Directory exists with subdirectories: data/, ui/, tests/, bosses/

ls assets/scripts/serpent/*.lua
# Assert: serpent_main.lua exists

ls assets/scripts/serpent/tests/
# Assert: tests/ directory exists with test_helpers.lua

# Verify FSM import works (must set package.path from repo root)
lua -e "package.path = package.path .. ';./assets/scripts/?.lua;./assets/scripts/?/init.lua'; local FSM = require('core.fsm'); print('FSM loaded')"
# Assert: Prints "FSM loaded" without error
```

**Commit**: YES
- Message: `feat(serpent): initialize project structure and folder layout`
- Files: `assets/scripts/serpent/**`
- Pre-commit: Directory structure validation

---

### Task 2: Unit Data Definitions (16 units)

**What to do**:
- Create `assets/scripts/serpent/data/units.lua`
- Define all 16 units with: id, name, class, tier, cost, base_hp, base_attack, attack_speed, range, special
- Use SNKRX stat formulas from research

**Must NOT do**:
- Don't implement unit spawning logic (just data)
- Don't add complex abilities (damage/heal numbers only)

**Recommended Agent Profile**:
- **Category**: `quick`
  - Reason: Data definition file, no complex logic
- **Skills**: `[]`
  - No special skills needed
- **Skills Evaluated but Omitted**:
  - None relevant

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 1 (with Tasks 1, 5)
- **Blocks**: Tasks 4, 8, 9
- **Blocked By**: None (can start immediately)

**References**:

**Pattern References** (existing code to follow):
- `assets/scripts/creatures.json` - If creature data exists, follow pattern
- `docs/snkrx_research/Units.md` - Unit stat ranges and abilities

**Documentation References**:
- Master design doc section "Units (16 total, 4 per class)"
- SNKRX research: `docs/snkrx_research/Summary.md` - Stat formulas

**WHY Each Reference Matters**:
- Unit stats must match design doc quotas
- Stat scaling must follow SNKRX formula: `stat × 2^(level-1)`

**Acceptance Criteria**:

```lua
-- Test file: assets/scripts/serpent/tests/test_units.lua
-- Add assets/scripts to package path
package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")
local units = require("serpent.data.units")

t.describe("Unit Data", function()
  t.it("should have exactly 16 units", function()
    local count = 0
    for _ in pairs(units.all) do count = count + 1 end
    t.expect(count).to_be(16)
  end)
  
  t.it("should have 4 units per class", function()
    local class_counts = { warrior = 0, mage = 0, ranger = 0, support = 0 }
    for _, unit in pairs(units.all) do
      class_counts[unit.class] = class_counts[unit.class] + 1
    end
    for class, count in pairs(class_counts) do
      t.expect(count).to_be(4)
    end
  end)
  
  t.it("should have correct tier costs", function()
    for _, unit in pairs(units.all) do
      local expected_cost = unit.tier * 3 -- Tier 1=3g, Tier 2=6g, etc.
      t.expect(unit.cost).to_be(expected_cost)
    end
  end)
end)

t.run()
```

```bash
# Agent runs:
lua assets/scripts/tests/test_runner.lua -f "Unit Data" assets/scripts/serpent/tests/
# Assert: All tests pass (exit code 0)
```

**Commit**: YES
- Message: `feat(serpent): define 16 unit types across 4 classes`
- Files: `assets/scripts/serpent/data/units.lua`, `assets/scripts/serpent/tests/test_units.lua`
- Pre-commit: `lua assets/scripts/tests/test_runner.lua -f "Unit Data" assets/scripts/serpent/tests/`

---

### Task 3: Snake Movement Controller

**What to do**:
- Create `assets/scripts/serpent/snake_controller.lua` (public API module)
- Create `assets/scripts/serpent/snake_logic.lua` (pure logic, no engine deps)
- Create `assets/scripts/serpent/snake_entity_adapter.lua` (thin ECS wrapper)

**Module Responsibilities:**
- `snake_logic.lua` - Pure state: unit array, add/remove unit, reorder. **Tested via unit tests.**
- `snake_entity_adapter.lua` - ECS: creates entities, calls steering APIs. **NOT unit tested.**
- `snake_controller.lua` - Coordinator: combines logic + adapter, exposes public API.

**Movement Approach:**
- **Input**: WASD/arrow keys set target direction (NOT mouse - keeps it simple)
- Head: Moves in input direction via `steering.seek_point()` on a target point ahead
- Body: Each segment follows predecessor via `steering.pursuit()`
- Support 3-8 unit snake length
- Handle segment spacing and smooth following

**Input API - Two Options:**

**Option A: Raylib direct IsKeyDown()** (simpler, verified in `main.lua:1385-1391`):
```lua
-- Direct Raylib bindings (available as globals)
local function get_input_direction()
    local dx, dy = 0, 0
    if IsKeyDown(KEY_W) or IsKeyDown(KEY_UP) then dy = -1 end
    if IsKeyDown(KEY_S) or IsKeyDown(KEY_DOWN) then dy = 1 end
    if IsKeyDown(KEY_A) or IsKeyDown(KEY_LEFT) then dx = -1 end
    if IsKeyDown(KEY_D) or IsKeyDown(KEY_RIGHT) then dx = 1 end
    return dx, dy
end
```

**Reference**: `main.lua:1385-1391` uses `IsKeyPressed(KEY_W)` etc. for main menu navigation.

**Option B: input.bind() system** (more complex, verified in `gameplay.lua:9226-9237`):
```lua
-- Bind keys once in init:
input.bind("serpent_left", { device = "keyboard", key = KeyboardKey.KEY_A, trigger = "Held", context = "serpent" })
input.bind("serpent_right", { device = "keyboard", key = KeyboardKey.KEY_D, trigger = "Held", context = "serpent" })
input.bind("serpent_up", { device = "keyboard", key = KeyboardKey.KEY_W, trigger = "Held", context = "serpent" })
input.bind("serpent_down", { device = "keyboard", key = KeyboardKey.KEY_S, trigger = "Held", context = "serpent" })

-- Poll in update:
local function get_input_direction()
    local dx, dy = 0, 0
    if input.is_active("serpent_left") then dx = -1 end
    if input.is_active("serpent_right") then dx = 1 end
    if input.is_active("serpent_up") then dy = -1 end
    if input.is_active("serpent_down") then dy = 1 end
    return dx, dy
end
```

**Recommended: Option A** (IsKeyDown) for simplicity. Option B is overkill for a single-player mode.

**Key constants** (Raylib globals):
- `KEY_W`, `KEY_A`, `KEY_S`, `KEY_D`
- `KEY_UP`, `KEY_DOWN`, `KEY_LEFT`, `KEY_RIGHT`

**Movement Tuning Constants (Source of Truth):**
```lua
local MOVEMENT_CONFIG = {
    -- Steering parameters (see physics_docs.md:740-780)
    MAX_SPEED = 180,           -- pixels/sec (head)
    MAX_FORCE = 400,           -- steering force
    MAX_ANGULAR = 6.0,         -- radians/sec
    FRICTION = 0.92,           -- damping
    
    -- Snake chain parameters
    SEGMENT_SPACING = 40,      -- pixels between segment centers
    SEEK_DISTANCE = 100,       -- target point ahead of head for smooth steering
    
    -- Arena
    ARENA_WIDTH = 800,         -- playable area
    ARENA_HEIGHT = 600,
    ARENA_PADDING = 50,        -- boundary buffer before turning
}
```

**Must NOT do**:
- Don't implement combat/attacks yet
- Don't implement unit death removal yet (just movement)

**Recommended Agent Profile**:
- **Category**: `unspecified-high`
  - Reason: Core gameplay mechanic requiring physics/steering integration
- **Skills**: `[]`
  - Engine systems documented in physics_docs.md
- **Skills Evaluated but Omitted**:
  - `frontend-ui-ux`: Not UI work

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 2 (with Tasks 4, 6)
- **Blocks**: Tasks 7, 9
- **Blocked By**: Task 1

**References**:

**Pattern References** (existing code to follow):
- `docs/api/physics_docs.md:740-780` - Steering API (seek_point, pursuit)
- `docs/snkrx_research/Summary.md` - Reference for SNKRX-style movement (note: implementation uses steering API from `docs/api/physics_docs.md`)

**API References**:
- `steering.seek_point(registry, agent, point, weight, arrival_distance)` - For head
- `steering.pursuit(registry, hunter, target, weight)` - For body following
- `steering.make_steerable(registry, agent, max_speed, max_force, max_angular, friction)`

**WHY Each Reference Matters**:
- `steering.seek_point` makes head follow player input
- `steering.pursuit` chains body segments to follow leader
- Must configure steerable parameters for responsive feel

**Acceptance Criteria**:

**Unit Tests (snake_logic.lua - pure logic, no engine):**
```lua
-- Test file: assets/scripts/serpent/tests/test_snake_logic.lua
-- Add assets/scripts to package path
package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")
local SnakeLogic = require("serpent.snake_logic")

t.describe("Snake Logic (Pure)", function()
  t.it("should create snake with initial unit count", function()
    local snake = SnakeLogic.create({ unit_count = 4 })
    t.expect(snake:get_unit_count()).to_be(4)
  end)
  
  t.it("should add units up to max 8", function()
    local snake = SnakeLogic.create({ unit_count = 6 })
    t.expect(snake:add_unit({ id = "test_1" })).to_be_truthy()
    t.expect(snake:add_unit({ id = "test_2" })).to_be_truthy()
    t.expect(snake:get_unit_count()).to_be(8)
    -- Should not add beyond 8
    t.expect(snake:add_unit({ id = "test_3" })).to_be_falsy()
  end)
  
  t.it("should remove unit by id", function()
    local snake = SnakeLogic.create({ unit_count = 4 })
    snake.units[2].id = "target_unit"
    t.expect(snake:remove_unit("target_unit")).to_be_truthy()
    t.expect(snake:get_unit_count()).to_be(3)
  end)
  
  t.it("should allow sell removal down to min 3 units", function()
    local snake = SnakeLogic.create({ unit_count = 4 })
    snake.units[1].id = "u1"
    -- Sell removal (voluntary) is blocked at 3
    t.expect(snake:sell_unit("u1")).to_be_truthy()  -- 4->3 OK
    t.expect(snake:get_unit_count()).to_be(3)
    snake.units[1].id = "u2"
    t.expect(snake:sell_unit("u2")).to_be_falsy()   -- 3->2 blocked (sell)
  end)
  
  t.it("should allow death removal below 3 (combat death)", function()
    local snake = SnakeLogic.create({ unit_count = 3 })
    snake.units[1].id = "u1"
    -- Death removal (involuntary) CAN go below 3
    t.expect(snake:death_remove_unit("u1")).to_be_truthy()
    t.expect(snake:get_unit_count()).to_be(2)
  end)
  
  t.it("should report game_over when all units die", function()
    local snake = SnakeLogic.create({ unit_count = 1 })
    snake.units[1].id = "last"
    t.expect(snake:death_remove_unit("last")).to_be_truthy()
    t.expect(snake:get_unit_count()).to_be(0)
    t.expect(snake:is_game_over()).to_be_truthy()
  end)
  
  t.it("should return all unit data", function()
    local snake = SnakeLogic.create({ unit_count = 3 })
    local units = snake:get_all_units()
    t.expect(#units).to_be(3)
  end)
end)

t.run()
```

```bash
# Agent runs (pure logic tests - no engine needed):
lua assets/scripts/serpent/tests/test_snake_logic.lua
# Assert: All tests pass (exit code 0)
```

**Runtime Verification (snake_controller.lua + adapter - requires game running):**
```
1. Build and run: just build-debug && ./build/raylib-cpp-cmake-template
2. Click "Serpent" button on main menu
3. Observe: Snake of 4 units appears at center
4. Move snake with WASD/arrow keys: Head follows input direction
5. Observe: Body segments follow head with spacing
6. Capture screenshot: .sisyphus/evidence/task-3-snake-movement.png
```

**Commit**: YES
- Message: `feat(serpent): implement snake movement with pursuit chain`
- Files: `assets/scripts/serpent/snake_controller.lua`, `assets/scripts/serpent/tests/test_snake_controller.lua`
- Pre-commit: `lua assets/scripts/tests/test_runner.lua -f "Snake Controller" assets/scripts/serpent/tests/`

---

### Task 4: Synergy System (Pure Logic)

**What to do**:
- Create `assets/scripts/serpent/synergy_system.lua`
- Implement class counting from snake units
- Implement synergy activation at 2/4 thresholds
- Return stat bonuses as pure data (no entity modification)

**Synergy Bonuses (from design doc)**:
| Class | 2 Units | 4 Units |
|-------|---------|---------|
| Warrior | +20% attack damage | +40% attack damage, +20% HP |
| Mage | +20% spell damage | +40% spell damage, -20% spell cooldown |
| Ranger | +20% attack speed | +40% attack speed, +20% range |
| Support | Heal snake 5 HP/sec | Heal 10 HP/sec, +10% all stats |

**Stat Bonus Representation Contract:**
- **Synergy system stores bonuses as FRACTIONS**: `0.20` means +20%
- **Combat Stats expects PERCENTAGE INTEGERS**: `add_pct=20` means +20%
- **Conversion point**: When applying synergy bonuses to actor stats, multiply by 100
  ```lua
  -- In synergy application (Task 10):
  local synergies = SynergySystem.calculate(snake_classes)
  if synergies.warrior.attack_damage_bonus then
      -- Synergy returns 0.20, Stats expects 20
      actor.stats.values.weapon_min.add_pct = synergies.warrior.attack_damage_bonus * 100
      actor.stats:recompute()
  end
  ```

**HP/Healing Semantics Contract:**

1. **HP Model: PER-SEGMENT (not shared pool)**
   - Each unit in the snake has its own HP tracked in its combat actor
   - "Snake total HP" for HUD = sum of all living units' current HP
   - "Snake max HP" for HUD = sum of all living units' max HP
   - When a unit's HP reaches 0, that unit dies and is removed from snake

2. **Unit Death Behavior:**
   - Dead unit is removed via `snake:death_remove_unit(id)` (gap closes immediately)
   - Snake length decreases by 1
   - **Death removal CAN reduce below 3** (unlike sell removal which is blocked at 3)
   - Game over when snake length == 0 (all units dead)
   
   **Sell vs Death removal distinction:**
   - `sell_unit(id)` - Voluntary (shop), blocked if would go below 3 units
   - `death_remove_unit(id)` - Involuntary (combat), always allowed, triggers game over check

3. **Healing Distribution:**
   - **Healer unit "heal adjacent"**: Heals the unit immediately BEFORE it in snake array (index - 1)
     - If Healer is at position 0 (head), heals position 1 instead
     - Heals 10 HP/sec to that one adjacent unit
   - **Support synergy "heal snake"**: Heals ALL living units equally
     - At 2 units: each unit heals 5 HP/sec
     - At 4 units: each unit heals 10 HP/sec
   - Healing cannot exceed unit's max HP

4. **Contact Damage:**
   - Enemies deal damage when colliding with ANY snake segment
   - Damage is dealt to the SPECIFIC segment that was hit
   - Contact damage cooldown: 0.5 sec per enemy-segment pair (prevents rapid damage ticks)
   - Enemy AI: chase the snake HEAD (position of unit at index 0)

**Must NOT do**:
- Don't apply bonuses to entities (just calculate)
- Don't create triggered effects (stat multipliers only)

**Recommended Agent Profile**:
- **Category**: `unspecified-high`
  - Reason: System logic with stat calculations
- **Skills**: `[]`
  - No special skills needed
- **Skills Evaluated but Omitted**:
  - None relevant

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 2 (with Tasks 3, 6)
- **Blocks**: Tasks 8, 13
- **Blocked By**: Task 2

**References**:

**Pattern References** (existing code to follow):
- `docs/systems/combat/README.md:100-108` - Status/buff patterns
- `docs/snkrx_research/Summary.md` - SNKRX synergy reference (numeric values embedded in plan's "Classes" table)

**Documentation References**:
- Master design doc section "Classes (4 total)" - Synergy thresholds

**WHY Each Reference Matters**:
- Follow existing stat modification patterns
- Match SNKRX synergy thresholds (2/4 not 3/6)

**Acceptance Criteria**:

```lua
-- Test file: assets/scripts/serpent/tests/test_synergy_system.lua
-- Add assets/scripts to package path
package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")
local SynergySystem = require("serpent.synergy_system")

t.describe("Synergy System", function()
  t.it("should return no synergies with 1 unit per class", function()
    local snake_classes = { "warrior", "mage", "ranger", "support" }
    local synergies = SynergySystem.calculate(snake_classes)
    t.expect(synergies.warrior.level).to_be(0)
    t.expect(synergies.mage.level).to_be(0)
  end)
  
  t.it("should activate level 1 synergy at 2 units", function()
    local snake_classes = { "warrior", "warrior", "mage" }
    local synergies = SynergySystem.calculate(snake_classes)
    t.expect(synergies.warrior.level).to_be(1)
    t.expect(synergies.warrior.attack_damage_bonus).to_be(0.20)
  end)
  
  t.it("should activate level 2 synergy at 4 units", function()
    local snake_classes = { "warrior", "warrior", "warrior", "warrior" }
    local synergies = SynergySystem.calculate(snake_classes)
    t.expect(synergies.warrior.level).to_be(2)
    t.expect(synergies.warrior.attack_damage_bonus).to_be(0.40)
    t.expect(synergies.warrior.hp_bonus).to_be(0.20)
  end)
  
  t.it("should calculate support heal rate", function()
    local snake_classes = { "support", "support" }
    local synergies = SynergySystem.calculate(snake_classes)
    t.expect(synergies.support.heal_per_second).to_be(5)
  end)
end)

t.run()
```

```bash
# Agent runs:
lua assets/scripts/tests/test_runner.lua -f "Synergy System" assets/scripts/serpent/tests/
# Assert: All tests pass (exit code 0)
```

**Commit**: YES
- Message: `feat(serpent): implement class synergy system with stat bonuses`
- Files: `assets/scripts/serpent/synergy_system.lua`, `assets/scripts/serpent/tests/test_synergy_system.lua`
- Pre-commit: `lua assets/scripts/tests/test_runner.lua -f "Synergy System" assets/scripts/serpent/tests/`

---

### Task 5: Enemy Data Definitions (11 enemies)

**What to do**:
- Create `assets/scripts/serpent/data/enemies.lua`
- Define all 11 enemy types with: id, name, hp, damage, speed, special, wave_range
- Include 2 bosses (Swarm Queen, Lich King)

**Must NOT do**:
- Don't implement enemy AI yet (just data)
- Don't add complex boss phases yet

**Recommended Agent Profile**:
- **Category**: `quick`
  - Reason: Data definition file
- **Skills**: `[]`
  - No special skills needed
- **Skills Evaluated but Omitted**:
  - None relevant

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 1 (with Tasks 1, 2)
- **Blocks**: Task 6
- **Blocked By**: None (can start immediately)

**References**:

**Pattern References**:
- Task 2's units.lua pattern for data structure

**Documentation References**:
- Master design doc section "Enemies" - All 11 enemy types with stats

**WHY Each Reference Matters**:
- Enemy stats must match design doc exactly
- Same data structure pattern as units

**Acceptance Criteria**:

```lua
-- Test file: assets/scripts/serpent/tests/test_enemies.lua
-- Add assets/scripts to package path
package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")
local enemies = require("serpent.data.enemies")

t.describe("Enemy Data", function()
  t.it("should have exactly 11 enemy types", function()
    local count = 0
    for _ in pairs(enemies.all) do count = count + 1 end
    t.expect(count).to_be(11)
  end)
  
  t.it("should have 2 bosses", function()
    local boss_count = 0
    for _, enemy in pairs(enemies.all) do
      if enemy.is_boss then boss_count = boss_count + 1 end
    end
    t.expect(boss_count).to_be(2)
  end)
  
  t.it("should have Swarm Queen with correct HP", function()
    t.expect(enemies.all.swarm_queen.hp).to_be(500)
    t.expect(enemies.all.swarm_queen.is_boss).to_be_truthy()
  end)
  
  t.it("should have Lich King with correct HP", function()
    t.expect(enemies.all.lich_king.hp).to_be(800)
    t.expect(enemies.all.lich_king.is_boss).to_be_truthy()
  end)
end)

t.run()
```

```bash
# Agent runs:
lua assets/scripts/tests/test_runner.lua -f "Enemy Data" assets/scripts/serpent/tests/
# Assert: All tests pass (exit code 0)
```

**Commit**: YES
- Message: `feat(serpent): define 11 enemy types including 2 bosses`
- Files: `assets/scripts/serpent/data/enemies.lua`, `assets/scripts/serpent/tests/test_enemies.lua`
- Pre-commit: `lua assets/scripts/tests/test_runner.lua -f "Enemy Data" assets/scripts/serpent/tests/`

---

### Task 6: Wave Configuration (20 waves)

**What to do**:
- Create `assets/scripts/serpent/wave_config.lua`
- Define 20 waves with: enemy_types, enemy_count, scaling_multipliers
- Configure boss waves at 10 and 20
- Implement wave scaling formula

**Wave Scaling (from design doc)**:
```lua
Enemies_in_Wave = 5 + Wave × 2
Enemy_HP_Multiplier = 1 + Wave × 0.1
Enemy_Damage_Multiplier = 1 + Wave × 0.05
```

**Must NOT do**:
- Don't implement wave spawning logic (just configuration)
- Don't add enemy AI

**Recommended Agent Profile**:
- **Category**: `quick`
  - Reason: Configuration data with formulas
- **Skills**: `[]`
  - No special skills needed
- **Skills Evaluated but Omitted**:
  - None relevant

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 2 (with Tasks 3, 4)
- **Blocks**: Task 11
- **Blocked By**: Task 5

**References**:

**Pattern References**:
- `assets/scripts/combat/wave_director.lua` - Existing wave structure if available

**Documentation References**:
- Master design doc "Wave Structure" section
- Design doc: Wave scaling formulas

**WHY Each Reference Matters**:
- Must match existing wave director API if present
- Scaling formulas from design doc

**Acceptance Criteria**:

```lua
-- Test file: assets/scripts/serpent/tests/test_wave_config.lua
-- Add assets/scripts to package path
package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")
local WaveConfig = require("serpent.wave_config")

t.describe("Wave Configuration", function()
  t.it("should have exactly 20 waves", function()
    t.expect(#WaveConfig.waves).to_be(20)
  end)
  
  t.it("should have boss at wave 10", function()
    t.expect(WaveConfig.waves[10].is_boss_wave).to_be_truthy()
    t.expect(WaveConfig.waves[10].boss_id).to_be("swarm_queen")
  end)
  
  t.it("should have boss at wave 20", function()
    t.expect(WaveConfig.waves[20].is_boss_wave).to_be_truthy()
    t.expect(WaveConfig.waves[20].boss_id).to_be("lich_king")
  end)
  
  t.it("should scale enemy count correctly", function()
    -- Wave 1: 5 + 1*2 = 7 enemies
    t.expect(WaveConfig.get_enemy_count(1)).to_be(7)
    -- Wave 10: 5 + 10*2 = 25 enemies
    t.expect(WaveConfig.get_enemy_count(10)).to_be(25)
  end)
  
  t.it("should scale HP multiplier correctly", function()
    -- Wave 5: 1 + 5*0.1 = 1.5x
    t.expect(WaveConfig.get_hp_multiplier(5)).to_be(1.5)
  end)
end)

t.run()
```

```bash
# Agent runs:
lua assets/scripts/tests/test_runner.lua -f "Wave Configuration" assets/scripts/serpent/tests/
# Assert: All tests pass (exit code 0)
```

**Commit**: YES
- Message: `feat(serpent): configure 20 waves with difficulty scaling`
- Files: `assets/scripts/serpent/wave_config.lua`, `assets/scripts/serpent/tests/test_wave_config.lua`
- Pre-commit: `lua assets/scripts/tests/test_runner.lua -f "Wave Configuration" assets/scripts/serpent/tests/`

---

### Task 7: Auto-Attack System

**What to do**:
- Create `assets/scripts/serpent/auto_attack.lua` (public API module)
- Create `assets/scripts/serpent/auto_attack_logic.lua` (pure logic, no engine deps)

**Module Responsibilities:**
- `auto_attack_logic.lua` - Pure: cooldown tracking, target selection math. **Tested via unit tests.**
- `auto_attack.lua` - Coordinator: uses logic + calls `combat_adapter.deal_damage()`. **Runtime verified.**

**Features:**
- Attack cooldown per unit based on attack_speed
- Target acquisition (nearest enemy in range)
- Integrate with combat system via combat_adapter

**Must NOT do**:
- Don't add complex targeting logic
- Don't implement AoE attacks (single target only for vertical slice)

**Recommended Agent Profile**:
- **Category**: `unspecified-high`
  - Reason: Combat system integration
- **Skills**: `[]`
  - Combat system documented in docs
- **Skills Evaluated but Omitted**:
  - None relevant

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 3 (with Tasks 8, 9)
- **Blocks**: Task 10
- **Blocked By**: Task 3

**References**:

**Pattern References**:
- `docs/systems/combat/README.md:70-88` - Effects.deal_damage pattern
- `docs/systems/combat/README.md:43-58` - Targeters API

**API References**:
- `Effects.deal_damage{ components={{type='physical', amount=X}} }`
- `Targeters.all_enemies(ctx)` - Get all enemies
- Timer system for cooldowns

**WHY Each Reference Matters**:
- Must use existing damage pipeline
- Follow targeter patterns for enemy detection

**Acceptance Criteria**:

**Unit Tests (auto_attack_logic.lua - pure logic, no engine):**
```lua
-- Test file: assets/scripts/serpent/tests/test_auto_attack_logic.lua
-- Add assets/scripts to package path
package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")
local AutoAttackLogic = require("serpent.auto_attack_logic")

t.describe("Auto Attack Logic (Pure)", function()
  t.it("should calculate cooldown from attack_speed", function()
    -- attack_speed 1.0 = 1 attack/sec = 1.0 cooldown
    -- attack_speed 2.0 = 2 attacks/sec = 0.5 cooldown
    t.expect(AutoAttackLogic.calculate_cooldown(1.0)).to_be(1.0)
    t.expect(AutoAttackLogic.calculate_cooldown(2.0)).to_be(0.5)
  end)
  
  t.it("should find nearest target in range", function()
    local attacker = { x = 0, y = 0, range = 100 }
    local targets = {
      { x = 50, y = 0, id = "close" },   -- 50 units away
      { x = 200, y = 0, id = "far" },    -- 200 units away (out of range)
      { x = 80, y = 0, id = "medium" },  -- 80 units away
    }
    local target = AutoAttackLogic.find_nearest_in_range(attacker, targets)
    t.expect(target.id).to_be("close")
  end)
  
  t.it("should return nil if no targets in range", function()
    local attacker = { x = 0, y = 0, range = 100 }
    local targets = {
      { x = 200, y = 0, id = "far" },
    }
    local target = AutoAttackLogic.find_nearest_in_range(attacker, targets)
    t.expect(target).to_be_nil()
  end)
  
  t.it("should track cooldown state", function()
    local state = AutoAttackLogic.create_state(1.0) -- 1 sec cooldown
    t.expect(AutoAttackLogic.can_attack(state)).to_be_truthy()
    AutoAttackLogic.trigger_cooldown(state)
    t.expect(AutoAttackLogic.can_attack(state)).to_be_falsy()
    AutoAttackLogic.update(state, 0.5)
    t.expect(AutoAttackLogic.can_attack(state)).to_be_falsy()
    AutoAttackLogic.update(state, 0.5)
    t.expect(AutoAttackLogic.can_attack(state)).to_be_truthy()
  end)
end)

t.run()
```

```bash
# Agent runs (pure logic tests - no engine needed):
lua assets/scripts/serpent/tests/test_auto_attack_logic.lua
# Assert: All tests pass (exit code 0)
```

**Runtime Verification (auto_attack.lua - requires game running):**
```
1. Build and run: just build-debug && ./build/raylib-cpp-cmake-template
2. Start Serpent mode, begin wave 1
3. Observe: Units auto-attack enemies within range
4. Observe: Attack frequency matches attack_speed stat
5. Capture screenshot: .sisyphus/evidence/task-7-auto-attack.png
```

**Commit**: YES
- Message: `feat(serpent): implement auto-attack system with target acquisition`
- Files: `assets/scripts/serpent/auto_attack.lua`, `assets/scripts/serpent/auto_attack_logic.lua`, `assets/scripts/serpent/tests/test_auto_attack_logic.lua`
- Pre-commit: `lua assets/scripts/serpent/tests/test_auto_attack_logic.lua`

---

### Task 8: Shop System Adaptation

**What to do**:
- Create `assets/scripts/serpent/serpent_shop.lua`
- Adapt existing shop patterns for unit purchases
- Implement: buy unit, sell unit (50% value), reroll (2g base, +1g each)
- Implement tier-weighted offerings based on wave

**Shop Tier Odds (from SNKRX)**:
| Wave | Tier 1 | Tier 2 | Tier 3 | Tier 4 |
|------|--------|--------|--------|--------|
| 1-5 | 70% | 25% | 5% | 0% |
| 6-10 | 55% | 30% | 13% | 2% |
| 11-15 | 35% | 35% | 22% | 8% |
| 16-20 | 20% | 30% | 33% | 17% |

**Must NOT do**:
- Don't add interest mechanic
- Don't add items
- Don't add unit reposition

**Recommended Agent Profile**:
- **Category**: `unspecified-high`
  - Reason: Shop system with probability logic
- **Skills**: `[]`
  - No special skills needed
- **Skills Evaluated but Omitted**:
  - None relevant

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 3 (with Tasks 7, 9)
- **Blocks**: Task 12
- **Blocked By**: Tasks 2, 4

**References**:

**Pattern References**:
- `assets/scripts/core/shop_system.lua` - Existing shop if available
- `docs/snkrx_research/Summary.md` - SNKRX shop reference (tier odds embedded in plan's "Shop Tier Odds" table)

**WHY Each Reference Matters**:
- Follow existing shop patterns
- Tier odds must match SNKRX research

**Acceptance Criteria**:

```lua
-- Test file: assets/scripts/serpent/tests/test_serpent_shop.lua
-- Add assets/scripts to package path
package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")
local SerpentShop = require("serpent.serpent_shop")

t.describe("Serpent Shop", function()
  t.it("should generate 5 offerings", function()
    local shop = SerpentShop.create({ wave = 1 })
    local offerings = shop:get_offerings()
    t.expect(#offerings).to_be(5)
  end)
  
  t.it("should weight tiers by wave", function()
    -- Wave 1-5: 70% tier 1, no tier 4
    local shop = SerpentShop.create({ wave = 1 })
    -- Generate many offerings to test distribution
    local tier_counts = { 0, 0, 0, 0 }
    for i = 1, 100 do
      shop:reroll_free() -- Free reroll for testing
      for _, offer in ipairs(shop:get_offerings()) do
        tier_counts[offer.tier] = tier_counts[offer.tier] + 1
      end
    end
    -- Tier 4 should be 0 in waves 1-5
    t.expect(tier_counts[4]).to_be(0)
  end)
  
  t.it("should allow purchase when enough gold", function()
    local shop = SerpentShop.create({ wave = 1, gold = 10 })
    local offerings = shop:get_offerings()
    local first_offer = offerings[1]
    local result = shop:purchase(1)
    t.expect(result.success).to_be_truthy()
    t.expect(shop:get_gold()).to_be(10 - first_offer.cost)
  end)
  
  t.it("should reject purchase when not enough gold", function()
    local shop = SerpentShop.create({ wave = 1, gold = 0 })
    local result = shop:purchase(1)
    t.expect(result.success).to_be_falsy()
  end)
  
  t.it("should sell units at 50% value", function()
    local shop = SerpentShop.create({ wave = 1, gold = 0 })
    local unit = { cost = 6 } -- Tier 2 unit
    local gold_gained = shop:sell(unit)
    t.expect(gold_gained).to_be(3) -- 50% of 6
  end)
  
  t.it("should increase reroll cost each time", function()
    local shop = SerpentShop.create({ wave = 1, gold = 100 })
    t.expect(shop:get_reroll_cost()).to_be(2)
    shop:reroll()
    t.expect(shop:get_reroll_cost()).to_be(3)
    shop:reroll()
    t.expect(shop:get_reroll_cost()).to_be(4)
  end)
end)

t.run()
```

```bash
# Agent runs:
lua assets/scripts/tests/test_runner.lua -f "Serpent Shop" assets/scripts/serpent/tests/
# Assert: All tests pass (exit code 0)
```

**Commit**: YES
- Message: `feat(serpent): implement unit shop with tier weighting and reroll`
- Files: `assets/scripts/serpent/serpent_shop.lua`, `assets/scripts/serpent/tests/test_serpent_shop.lua`
- Pre-commit: `lua assets/scripts/tests/test_runner.lua -f "Serpent Shop" assets/scripts/serpent/tests/`

---

### Task 9: Unit Spawning + Leveling

**What to do**:
- Create `assets/scripts/serpent/unit_factory.lua`
- Implement unit entity spawning from data definitions
- Implement unit leveling: 3 copies → level up, stats double
- Integrate with snake controller for adding units

**Level Up Formula (from SNKRX)**:
```lua
HP = Base_HP × 2^(Level - 1)
Attack = Base_Attack × 2^(Level - 1)
-- Level 1: 1x, Level 2: 2x, Level 3: 4x (max)
```

**Must NOT do**:
- Don't add level 3 special abilities (just stat scaling)
- Don't add visual variations per level

**Recommended Agent Profile**:
- **Category**: `unspecified-high`
  - Reason: Entity creation with stat calculations
- **Skills**: `[]`
  - No special skills needed
- **Skills Evaluated but Omitted**:
  - None relevant

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 3 (with Tasks 7, 8)
- **Blocks**: Task 10
- **Blocked By**: Tasks 2, 3

**References**:

**Pattern References**:
- `assets/scripts/core/spawn.lua` - Entity spawning patterns
- `docs/snkrx_research/Summary.md` - Level up reference (formula embedded in plan: `stat × 2^(level-1)`)

**WHY Each Reference Matters**:
- Follow existing spawn patterns
- Level up formula must match SNKRX

**Acceptance Criteria**:

```lua
-- Test file: assets/scripts/serpent/tests/test_unit_factory.lua
-- Add assets/scripts to package path
package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")
local UnitFactory = require("serpent.unit_factory")

t.describe("Unit Factory", function()
  t.it("should create unit with base stats", function()
    local unit = UnitFactory.create("soldier") -- Tier 1 warrior
    t.expect(unit.hp).to_be(100)
    t.expect(unit.attack).to_be(15)
    t.expect(unit.level).to_be(1)
  end)
  
  t.it("should double stats at level 2", function()
    local unit = UnitFactory.create("soldier")
    unit = UnitFactory.level_up(unit)
    t.expect(unit.level).to_be(2)
    t.expect(unit.hp).to_be(200)  -- 100 * 2
    t.expect(unit.attack).to_be(30) -- 15 * 2
  end)
  
  t.it("should quadruple stats at level 3", function()
    local unit = UnitFactory.create("soldier")
    unit = UnitFactory.level_up(unit)
    unit = UnitFactory.level_up(unit)
    t.expect(unit.level).to_be(3)
    t.expect(unit.hp).to_be(400)  -- 100 * 4
    t.expect(unit.attack).to_be(60) -- 15 * 4
  end)
  
  t.it("should not level beyond 3", function()
    local unit = UnitFactory.create("soldier")
    for i = 1, 5 do
      unit = UnitFactory.level_up(unit)
    end
    t.expect(unit.level).to_be(3) -- Capped at 3
  end)
  
  t.it("should combine 3 copies into level 2", function()
    local units = {
      UnitFactory.create("soldier"),
      UnitFactory.create("soldier"),
      UnitFactory.create("soldier"),
    }
    local result = UnitFactory.try_combine(units)
    t.expect(#result.remaining).to_be(1)
    t.expect(result.remaining[1].level).to_be(2)
  end)
end)

t.run()
```

```bash
# Agent runs:
lua assets/scripts/tests/test_runner.lua -f "Unit Factory" assets/scripts/serpent/tests/
# Assert: All tests pass (exit code 0)
```

**Commit**: YES
- Message: `feat(serpent): implement unit spawning with level-up combination`
- Files: `assets/scripts/serpent/unit_factory.lua`, `assets/scripts/serpent/tests/test_unit_factory.lua`
- Pre-commit: `lua assets/scripts/tests/test_runner.lua -f "Unit Factory" assets/scripts/serpent/tests/`

---

### Task 10: Combat Integration

**What to do**:
- Create `assets/scripts/serpent/combat_manager.lua`
- Integrate auto-attack with snake units
- Implement enemy damage to snake (contact damage)
- Implement unit death and snake gap closing
- Apply synergy bonuses to combat calculations

**Must NOT do**:
- Don't implement complex damage types (physical only)
- Don't add combat animations

**Recommended Agent Profile**:
- **Category**: `unspecified-high`
  - Reason: Core combat loop integration
- **Skills**: `[]`
  - Combat system in docs
- **Skills Evaluated but Omitted**:
  - None relevant

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 4 (with Tasks 11, 12)
- **Blocks**: Tasks 11, 15
- **Blocked By**: Tasks 7, 9

**References**:

**Pattern References**:
- `docs/systems/combat/README.md` - Full combat system
- `assets/scripts/serpent/auto_attack.lua` - From Task 7

**WHY Each Reference Matters**:
- Must integrate with existing combat EventBus
- Auto-attack is the source of unit attacks

**Acceptance Criteria**:

**Architecture Note: Pure Logic vs Engine Integration**

`combat_manager.lua` is a **PURE LOGIC** module that works on simple data tables:
- Unit tables: `{ id, hp, max_hp, attack, class, x, y, attack_cooldown, last_attack_time }`
- Enemy tables: `{ id, hp, max_hp, damage, x, y }`
- NO `stats` object, NO `CombatSystem` dependency in this module

`combat_adapter.lua` (from Combat System Integration section above) is the **ENGINE ADAPTER**:
- Wraps simple data into CombatSystem.Core.Stats-backed actors
- Calls Effects.deal_damage for actual damage application
- Used at **runtime only**, NOT in unit tests

**This separation allows unit tests to verify combat LOGIC without engine dependencies.**

```lua
-- Test file: assets/scripts/serpent/tests/test_combat_manager.lua
-- Add assets/scripts to package path
package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")
local CombatManager = require("serpent.combat_manager")
local TestHelpers = require("serpent.tests.test_helpers")
local MockSnake = TestHelpers.MockSnake

-- NOTE: CombatManager is PURE LOGIC - works on simple {hp, attack} tables
-- It does NOT call CombatSystem.Game.Effects or require stats objects
-- Runtime damage goes through combat_adapter.lua, which wraps for CombatSystem

t.describe("Combat Manager (Pure Logic)", function()
  t.it("should calculate unit attack damage", function()
    -- Pure logic: given unit with attack=10, calculate damage output
    local snake = MockSnake({ 
      units = { { id = "u1", attack = 10, attack_speed = 1.0, last_attack_time = 0 } } 
    })
    local enemies = { { id = "e1", hp = 100, max_hp = 100, x = 0, y = 0 } }
    local cm = CombatManager.create(snake, enemies)
    
    -- process_attacks returns damage events, does NOT mutate hp directly
    -- (Runtime adapter applies actual damage via CombatSystem)
    local damage_events = cm:calculate_attacks(1.0) -- 1 second of combat time
    
    t.expect(#damage_events).to_be(1)
    t.expect(damage_events[1].attacker_id).to_be("u1")
    t.expect(damage_events[1].target_id).to_be("e1")
    t.expect(damage_events[1].amount).to_be(10)
  end)
  
  t.it("should apply synergy damage bonus to calculations", function()
    local snake = MockSnake({
      units = { 
        { id = "u1", attack = 10, class = "warrior", attack_speed = 1.0, last_attack_time = 0 },
        { id = "u2", attack = 10, class = "warrior", attack_speed = 1.0, last_attack_time = 0 }
      },
      synergies = { warrior = { attack_damage_bonus = 0.20 } }
    })
    local enemies = { { id = "e1", hp = 100, max_hp = 100, x = 0, y = 0 } }
    local cm = CombatManager.create(snake, enemies)
    
    local damage_events = cm:calculate_attacks(1.0)
    -- Both units attack, each with 10 * 1.20 = 12 damage
    t.expect(#damage_events).to_be(2)
    t.expect(damage_events[1].amount).to_be(12)
    t.expect(damage_events[2].amount).to_be(12)
  end)
  
  t.it("should calculate contact damage from enemy", function()
    local snake = MockSnake({
      units = { { id = "u1", hp = 100, max_hp = 100, x = 0, y = 0 } }
    })
    local enemies = { { id = "e1", damage = 5, x = 5, y = 5 } }  -- Close enough to touch
    local cm = CombatManager.create(snake, enemies)
    
    -- calculate_contact_damage returns events, does not mutate
    local contact_events = cm:calculate_contact_damage()
    
    t.expect(#contact_events).to_be(1)
    t.expect(contact_events[1].target_id).to_be("u1")
    t.expect(contact_events[1].amount).to_be(5)
  end)
  
  t.it("should mark unit as dead when hp reaches 0", function()
    local snake = MockSnake({
      units = {
        { id = "unit1", hp = 10, max_hp = 10 },
        { id = "unit2", hp = 100, max_hp = 100 },
        { id = "unit3", hp = 100, max_hp = 100 }
      }
    })
    local cm = CombatManager.create(snake, {})
    
    -- Apply damage event (simulating what adapter would do)
    cm:apply_damage_to_unit("unit1", 15)
    
    local dead_units = cm:get_dead_units()
    t.expect(#dead_units).to_be(1)
    t.expect(dead_units[1].id).to_be("unit1")
  end)
  
  t.it("should signal snake to close gap after unit death", function()
    -- This tests the death callback integration
    local gap_close_called = false
    local snake = MockSnake({
      units = {
        { id = "unit1", x = 0, y = 0 },
        { id = "unit2", x = 50, y = 0 },
        { id = "unit3", x = 100, y = 0 }
      },
      on_unit_removed = function() gap_close_called = true end
    })
    local cm = CombatManager.create(snake, {})
    
    snake:remove_unit("unit2")
    
    t.expect(gap_close_called).to_be_truthy()
    t.expect(snake:get_unit_count()).to_be(2)
  end)
end)

t.run()
```

**Runtime Integration Note:**
At runtime, the coordinator (`serpent_main.lua`) does:
```lua
local damage_events = combat_manager:calculate_attacks(dt)
for _, event in ipairs(damage_events) do
    -- Convert to CombatSystem actors and apply via adapter
    local attacker_actor = find_actor_by_id(event.attacker_id)
    local target_actor = find_actor_by_id(event.target_id)
    CombatAdapter.deal_damage(ctx, attacker_actor, target_actor, event.amount)
end
```

```bash
# Agent runs:
lua assets/scripts/tests/test_runner.lua -f "Combat Manager" assets/scripts/serpent/tests/
# Assert: All tests pass (exit code 0)
```

**Commit**: YES
- Message: `feat(serpent): integrate combat with snake units and synergy bonuses`
- Files: `assets/scripts/serpent/combat_manager.lua`, `assets/scripts/serpent/tests/test_combat_manager.lua`
- Pre-commit: `lua assets/scripts/tests/test_runner.lua -f "Combat Manager" assets/scripts/serpent/tests/`

---

### Task 11: Wave Director Integration

**What to do**:
- Create `assets/scripts/serpent/serpent_wave_director.lua`
- Integrate wave config with enemy spawning
- Implement wave start/end detection
- Implement gold rewards on wave completion
- Transition to shop after wave

**Gold per Wave (from design doc)**:
```lua
Base_Gold = 10 + Wave × 2
```

**Must NOT do**:
- Don't implement wave timer/timeout
- Don't add enemy AI beyond chasing snake

**Architecture Note: Pure Logic vs Engine Integration**

`serpent_wave_director.lua` is a **PURE LOGIC** module that:
- Tracks wave state (current wave, gold, completion status)
- Returns **spawn specifications** (enemy data tables), NOT ECS entities
- Manages active enemy DATA (simple tables with hp, position, etc.)
- Testable without engine dependencies

`enemy_spawner_adapter.lua` (runtime only) is the **ENGINE ADAPTER**:
- Takes spawn specs from WaveDirector → creates ECS entities via EntityBuilder
- Creates CombatSystem actors via CombatAdapter
- Registers physics bodies, starts AI behaviors
- NOT unit tested (requires full engine)

**WaveDirector data flow:**
```
WaveDirector.start_wave()
  → returns spawn_specs: [{ type="slime", count=3, hp=40, ... }, ...]
  
Runtime coordinator (serpent_main.lua):
  for _, spec in ipairs(spawn_specs) do
    local ecs_entity = EnemySpawnerAdapter.spawn_enemy(spec)
    local actor = CombatAdapter.make_enemy_actor(spec, ecs_entity, stat_defs)
    table.insert(serpent_combat_context.enemies, actor)
    wave_director:track_enemy(actor)  -- WaveDirector tracks simple data
  end

WaveDirector.update(dt):
  - Checks tracked enemies for hp <= 0 (dead)
  - Removes dead enemies from tracking
  - Returns is_complete = true when all enemies dead
```

**Recommended Agent Profile**:
- **Category**: `unspecified-high`
  - Reason: Wave management integration
- **Skills**: `[]`
  - No special skills needed
- **Skills Evaluated but Omitted**:
  - None relevant

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 4 (with Tasks 10, 12)
- **Blocks**: Tasks 14, 15, 16
- **Blocked By**: Tasks 6, 10

**References**:

**Pattern References**:
- `assets/scripts/combat/wave_director.lua` - Existing wave director
- `assets/scripts/serpent/wave_config.lua` - From Task 6

**WHY Each Reference Matters**:
- Follow existing wave patterns
- Use wave config for enemy spawns

**Acceptance Criteria**:

```lua
-- Test file: assets/scripts/serpent/tests/test_serpent_wave_director.lua
-- Add assets/scripts to package path
package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

-- NOTE: WaveDirector is PURE LOGIC - returns spawn specs, tracks simple data
-- It does NOT create ECS entities or CombatSystem actors
-- Runtime spawning goes through enemy_spawner_adapter.lua

local t = require("tests.test_runner")
local WaveDirector = require("serpent.serpent_wave_director")

-- NOTE: WaveDirector is PURE LOGIC
-- - start_wave() returns SPAWN SPECS, not ECS entities
-- - track_enemy() accepts simple data tables, not CombatSystem actors
-- - update() checks tracked enemy.hp to detect deaths

t.describe("Serpent Wave Director (Pure Logic)", function()
  t.it("should start at wave 1", function()
    local wd = WaveDirector.create()
    t.expect(wd:get_current_wave()).to_be(1)
  end)
  
  t.it("should return spawn specs on wave start", function()
    local wd = WaveDirector.create()
    local spawn_specs = wd:start_wave()
    
    -- Returns array of spawn specifications, NOT actual enemies
    t.expect(#spawn_specs > 0).to_be_truthy()
    -- NOTE: test_runner uses .never().to_be(), NOT .to_not_be()
    t.expect(spawn_specs[1].type).never().to_be(nil)  -- e.g., "slime"
    t.expect(spawn_specs[1].count).never().to_be(nil) -- e.g., 3
    t.expect(spawn_specs[1].hp).never().to_be(nil)    -- base hp for this type
  end)
  
  t.it("should track enemies and detect wave completion when all dead", function()
    local wd = WaveDirector.create()
    local spawn_specs = wd:start_wave()
    
    -- Simulate runtime: coordinator creates enemies from specs, then tracks them
    local tracked_enemies = {}
    for _, spec in ipairs(spawn_specs) do
      for i = 1, spec.count do
        local enemy = { id = spec.type .. "_" .. i, hp = spec.hp, max_hp = spec.hp }
        table.insert(tracked_enemies, enemy)
        wd:track_enemy(enemy)  -- WaveDirector watches this data
      end
    end
    
    -- Not complete yet
    t.expect(wd:is_wave_complete()).to_be(false)
    
    -- Kill all tracked enemies (modify their hp)
    for _, enemy in ipairs(tracked_enemies) do
      enemy.hp = 0
    end
    
    -- Update detects deaths
    wd:update(0.1)
    t.expect(wd:is_wave_complete()).to_be_truthy()
  end)
  
  t.it("should grant gold on wave completion", function()
    local wd = WaveDirector.create()
    local initial_gold = wd:get_gold()
    
    wd:start_wave()
    wd:complete_wave()  -- Called after wave is verified complete
    
    -- Wave 1: 10 + 1*2 = 12 gold
    t.expect(wd:get_gold()).to_be(initial_gold + 12)
  end)
  
  t.it("should return boss spawn spec on wave 10", function()
    local wd = WaveDirector.create()
    
    -- Simulate completing waves 1-9
    for i = 1, 9 do
      wd:start_wave()
      wd:complete_wave()
      wd:next_wave()
    end
    
    -- Wave 10
    local spawn_specs = wd:start_wave()
    
    -- Should include boss spec
    local boss_spec = nil
    for _, spec in ipairs(spawn_specs) do
      if spec.is_boss then
        boss_spec = spec
        break
      end
    end
    
    t.expect(boss_spec).never().to_be(nil)
    t.expect(boss_spec.type).to_be("swarm_queen")
    t.expect(boss_spec.hp).to_be(500)  -- Boss HP from design doc
  end)
end)

t.run()
```

```bash
# Agent runs:
lua assets/scripts/tests/test_runner.lua -f "Serpent Wave Director" assets/scripts/serpent/tests/
# Assert: All tests pass (exit code 0)
```

**Commit**: YES
- Message: `feat(serpent): implement wave director with spawning and rewards`
- Files: `assets/scripts/serpent/serpent_wave_director.lua`, `assets/scripts/serpent/tests/test_serpent_wave_director.lua`
- Pre-commit: `lua assets/scripts/tests/test_runner.lua -f "Serpent Wave Director" assets/scripts/serpent/tests/`

---

### Task 12: Shop UI

**What to do**:
- Create `assets/scripts/serpent/ui/shop_ui.lua`
- Display 5 unit offerings with name, class, stats, cost
- Display player gold
- Buy, sell, reroll buttons
- Ready button to start next wave

**Must NOT do**:
- Don't add fancy animations
- Don't add tooltips beyond basic stats

**Recommended Agent Profile**:
- **Category**: `visual-engineering`
  - Reason: UI layout and interaction
- **Skills**: `["frontend-ui-ux"]`
  - UI patterns and visual design
- **Skills Evaluated but Omitted**:
  - `playwright`: Not needed for UI creation (only verification)

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 4 (with Tasks 10, 11)
- **Blocks**: Task 13
- **Blocked By**: Task 8

**References**:

**Pattern References**:
- `docs/api/ui_helper_reference.md` - UI DSL patterns
- `docs/api/ui-dsl-reference.md` - Full UI DSL guide

**WHY Each Reference Matters**:
- Must use existing UI DSL
- Follow established UI patterns

**Acceptance Criteria**:

**UI Module Design Pattern (CRITICAL for testability)**:
Serpent UI modules are designed as **view models** - they manage state and return data, but do NOT call engine globals directly during construction/query. Actual rendering happens via a separate `render()` method that uses the UI DSL.

```lua
-- Test file: assets/scripts/serpent/tests/test_shop_ui.lua
-- Add assets/scripts to package path
package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

-- NOTE: These tests verify UI STATE LOGIC, not rendering.
-- UI modules are designed as view models: create() and query methods are pure,
-- only render() methods call engine globals.
local t = require("tests.test_runner")
local ShopUI = require("serpent.ui.shop_ui")

t.describe("Shop UI (State Logic)", function()
  t.it("should track 5 offering slots", function()
    local ui = ShopUI.create()
    local offerings = ui:get_offering_count()
    t.expect(offerings).to_be(5)
  end)
  
  t.it("should format gold amount", function()
    local ui = ShopUI.create({ gold = 25 })
    t.expect(ui:get_gold_display()).to_be("25")
  end)
  
  t.it("should calculate buy affordability", function()
    local ui = ShopUI.create({ gold = 10 })
    ui:set_offerings({ { cost = 3 }, { cost = 6 }, { cost = 12 }, { cost = 20 }, { cost = 3 } })
    t.expect(ui:is_buy_enabled(1)).to_be_truthy() -- Cost 3, affordable
    t.expect(ui:is_buy_enabled(2)).to_be_truthy() -- Cost 6, affordable
    t.expect(ui:is_buy_enabled(4)).to_be_falsy() -- Cost 20, not affordable
  end)
  
  t.it("should show reroll cost", function()
    local ui = ShopUI.create({ reroll_cost = 2 })
    t.expect(ui:get_reroll_button_text()).to_be("Reroll (2g)")
  end)
end)

t.run()
```

**Visual Verification (via game runtime)**:
```
# Agent runs game via `just serve-web` (port 8000):
1. Navigate to: http://localhost:8000
2. Start game, complete wave 1 to reach shop
3. Verify visually: 5 unit offerings displayed
4. Verify visually: Gold amount visible
5. Screenshot: .sisyphus/evidence/task-12-shop-ui.png

Note: Game uses canvas rendering, not DOM. Visual verification via screenshot.
```

**Commit**: YES
- Message: `feat(serpent): implement shop UI with offerings and gold display`
- Files: `assets/scripts/serpent/ui/shop_ui.lua`, `assets/scripts/serpent/tests/test_shop_ui.lua`
- Pre-commit: `lua assets/scripts/tests/test_runner.lua -f "Shop UI" assets/scripts/serpent/tests/`

---

### Task 13: Synergy UI

**What to do**:
- Create `assets/scripts/serpent/ui/synergy_ui.lua`
- Display active synergies with class icons
- Show synergy level (0/1/2) and current count
- Update in real-time as units are purchased/sold

**Must NOT do**:
- Don't add synergy tooltips
- Don't add animations

**Recommended Agent Profile**:
- **Category**: `visual-engineering`
  - Reason: UI display
- **Skills**: `["frontend-ui-ux"]`
  - UI patterns
- **Skills Evaluated but Omitted**:
  - None relevant

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 5 (with Tasks 14, 15)
- **Blocks**: Task 17
- **Blocked By**: Tasks 4, 12

**References**:

**Pattern References**:
- `assets/scripts/serpent/synergy_system.lua` - From Task 4
- `docs/api/ui_helper_reference.md` - UI patterns

**WHY Each Reference Matters**:
- Display synergy system data
- Use existing UI DSL

**Acceptance Criteria**:

```lua
-- Test file: assets/scripts/serpent/tests/test_synergy_ui.lua
-- Add assets/scripts to package path
package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")
local SynergyUI = require("serpent.ui.synergy_ui")

t.describe("Synergy UI", function()
  t.it("should display 4 class synergies", function()
    local ui = SynergyUI.create()
    local elements = ui:get_class_elements()
    t.expect(#elements).to_be(4)
  end)
  
  t.it("should show inactive synergy at level 0", function()
    local ui = SynergyUI.create()
    ui:set_synergies({ warrior = { level = 0, count = 1 } })
    t.expect(ui:get_class_progress("warrior")).to_be("1/2")
    t.expect(ui:is_class_active("warrior")).to_be_falsy()
  end)
  
  t.it("should show active synergy at level 1", function()
    local ui = SynergyUI.create()
    ui:set_synergies({ warrior = { level = 1, count = 2 } })
    t.expect(ui:get_class_progress("warrior")).to_be("2/4")
    t.expect(ui:is_class_active("warrior")).to_be_truthy()
  end)
  
  t.it("should show max synergy at level 2", function()
    local ui = SynergyUI.create()
    ui:set_synergies({ warrior = { level = 2, count = 4 } })
    t.expect(ui:get_class_progress("warrior")).to_be("4/4")
    t.expect(ui:is_class_max("warrior")).to_be_truthy()
  end)
end)

t.run()
```

**Commit**: YES
- Message: `feat(serpent): implement synergy UI with class progress display`
- Files: `assets/scripts/serpent/ui/synergy_ui.lua`, `assets/scripts/serpent/tests/test_synergy_ui.lua`
- Pre-commit: `lua assets/scripts/tests/test_runner.lua -f "Synergy UI" assets/scripts/serpent/tests/`

---

### Task 14: HUD (HP, Gold, Wave)

**What to do**:
- Create `assets/scripts/serpent/ui/hud.lua`
- Display snake total HP / max HP
- Display current gold
- Display current wave / max wave (X/20)
- Display active synergies summary

**Must NOT do**:
- Don't add unit portraits
- Don't add detailed stats

**Recommended Agent Profile**:
- **Category**: `visual-engineering`
  - Reason: HUD layout
- **Skills**: `["frontend-ui-ux"]`
  - UI design
- **Skills Evaluated but Omitted**:
  - None relevant

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 5 (with Tasks 13, 15)
- **Blocks**: Tasks 16, 17
- **Blocked By**: Task 11

**References**:

**Pattern References**:
- `docs/api/ui_helper_reference.md` - UI DSL
- `assets/scripts/ui/currency_display.lua` - If exists, gold display pattern

**WHY Each Reference Matters**:
- Follow existing UI patterns
- Match currency display style

**Acceptance Criteria**:

```lua
-- Test file: assets/scripts/serpent/tests/test_hud.lua
-- Add assets/scripts to package path
package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")
local HUD = require("serpent.ui.hud")

t.describe("HUD", function()
  t.it("should display wave progress", function()
    local hud = HUD.create({ wave = 5, max_wave = 20 })
    t.expect(hud:get_wave_text()).to_be("Wave 5/20")
  end)
  
  t.it("should display snake HP", function()
    local hud = HUD.create({ hp = 350, max_hp = 500 })
    t.expect(hud:get_hp_text()).to_be("350/500")
  end)
  
  t.it("should display gold", function()
    local hud = HUD.create({ gold = 45 })
    t.expect(hud:get_gold_text()).to_be("45")
  end)
  
  t.it("should update in real-time", function()
    local hud = HUD.create({ hp = 100, max_hp = 100 })
    hud:set_hp(80)
    t.expect(hud:get_hp_text()).to_be("80/100")
  end)
end)

t.run()
```

**Commit**: YES
- Message: `feat(serpent): implement game HUD with HP, gold, and wave display`
- Files: `assets/scripts/serpent/ui/hud.lua`, `assets/scripts/serpent/tests/test_hud.lua`
- Pre-commit: `lua assets/scripts/tests/test_runner.lua -f "HUD" assets/scripts/serpent/tests/`

---

### Task 15: Boss Implementations

**What to do**:
- Create `assets/scripts/serpent/bosses/swarm_queen.lua`
- Create `assets/scripts/serpent/bosses/lich_king.lua`
- Implement Swarm Queen: Spawns 5 slimes every 10 seconds
- Implement Lich King: Raises dead enemies as skeletons

**Must NOT do**:
- Don't add complex phase transitions
- Don't add special visual effects

**Recommended Agent Profile**:
- **Category**: `unspecified-high`
  - Reason: Boss AI and mechanics
- **Skills**: `[]`
  - No special skills needed
- **Skills Evaluated but Omitted**:
  - None relevant

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 5 (with Tasks 13, 14)
- **Blocks**: Task 17
- **Blocked By**: Tasks 10, 11

**References**:

**Pattern References**:
- `docs/snkrx_research/Summary.md` - SNKRX boss reference (boss specs embedded in plan's "Enemies" table)
- Master design doc "Boss System" section

**WHY Each Reference Matters**:
- Boss mechanics from design doc
- SNKRX boss patterns for reference

**Acceptance Criteria**:

```lua
-- Test file: assets/scripts/serpent/tests/test_bosses.lua
-- Add assets/scripts to package path
package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")
local SwarmQueen = require("serpent.bosses.swarm_queen")
local LichKing = require("serpent.bosses.lich_king")

t.describe("Swarm Queen", function()
  t.it("should have 500 HP", function()
    local boss = SwarmQueen.create()
    t.expect(boss.hp).to_be(500)
  end)
  
  t.it("should spawn 5 slimes every 10 seconds", function()
    local boss = SwarmQueen.create()
    local spawned = boss:update(10.0) -- 10 seconds
    t.expect(#spawned).to_be(5)
    for _, enemy in ipairs(spawned) do
      t.expect(enemy.id).to_be("slime")
    end
  end)
  
  t.it("should not spawn if dead", function()
    local boss = SwarmQueen.create()
    boss.hp = 0
    local spawned = boss:update(10.0)
    t.expect(#spawned).to_be(0)
  end)
end)

t.describe("Lich King", function()
  t.it("should have 800 HP", function()
    local boss = LichKing.create()
    t.expect(boss.hp).to_be(800)
  end)
  
  t.it("should raise dead enemies as skeletons", function()
    local boss = LichKing.create()
    local dead_enemies = { { id = "slime" }, { id = "goblin" } }
    local raised = boss:raise_dead(dead_enemies)
    t.expect(#raised).to_be(2)
    for _, enemy in ipairs(raised) do
      t.expect(enemy.id).to_be("skeleton")
    end
  end)
end)

t.run()
```

**Commit**: YES
- Message: `feat(serpent): implement Swarm Queen and Lich King bosses`
- Files: `assets/scripts/serpent/bosses/*.lua`, `assets/scripts/serpent/tests/test_bosses.lua`
- Pre-commit: `lua assets/scripts/tests/test_runner.lua -f "boss" assets/scripts/serpent/tests/`

---

### Task 16: Death/Victory Screens

**What to do**:
- Create `assets/scripts/serpent/ui/game_over_screen.lua`
- Create `assets/scripts/serpent/ui/victory_screen.lua`
- Display run stats: waves completed, units purchased, gold earned
- Retry and main menu buttons

**Must NOT do**:
- Don't add animations
- Don't add leaderboards

**Recommended Agent Profile**:
- **Category**: `visual-engineering`
  - Reason: Screen layout
- **Skills**: `["frontend-ui-ux"]`
  - UI design
- **Skills Evaluated but Omitted**:
  - None relevant

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 6 (with Tasks 17, 18)
- **Blocks**: Task 18
- **Blocked By**: Tasks 11, 14

**References**:

**Pattern References**:
- `docs/api/ui_helper_reference.md` - UI DSL

**WHY Each Reference Matters**:
- Use existing UI DSL for screens

**Acceptance Criteria**:

```lua
-- Test file: assets/scripts/serpent/tests/test_screens.lua
-- Add assets/scripts to package path
package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")
local GameOverScreen = require("serpent.ui.game_over_screen")
local VictoryScreen = require("serpent.ui.victory_screen")

t.describe("Game Over Screen", function()
  t.it("should display waves completed", function()
    local screen = GameOverScreen.create({ waves_completed = 12 })
    t.expect(screen:get_stat("waves")).to_be("Waves: 12/20")
  end)
  
  t.it("should have retry button", function()
    local screen = GameOverScreen.create({})
    t.expect(screen:get_button("retry")).to_be_truthy()
  end)
end)

t.describe("Victory Screen", function()
  t.it("should display completion message", function()
    local screen = VictoryScreen.create({})
    t.expect(screen:get_title()).to_be("Victory!")
  end)
  
  t.it("should display all stats", function()
    local screen = VictoryScreen.create({
      waves_completed = 20,
      units_purchased = 15,
      gold_earned = 350
    })
    t.expect(screen:get_stat("waves")).to_be("Waves: 20/20")
    t.expect(screen:get_stat("units")).to_be("Units: 15")
    t.expect(screen:get_stat("gold")).to_be("Gold: 350")
  end)
end)

t.run()
```

**Commit**: YES
- Message: `feat(serpent): implement game over and victory screens with stats`
- Files: `assets/scripts/serpent/ui/game_over_screen.lua`, `assets/scripts/serpent/ui/victory_screen.lua`, `assets/scripts/serpent/tests/test_screens.lua`
- Pre-commit: `lua assets/scripts/tests/test_runner.lua -f "Screen" assets/scripts/serpent/tests/`

---

### Task 17: Balance Tuning Pass

**What to do**:
- Review and adjust unit stats for difficulty curve
- Review and adjust wave enemy counts/scaling
- Review gold rewards vs unit costs
- Ensure 10-15 minute session target

**Must NOT do**:
- Don't add new content
- Don't change core mechanics

**Recommended Agent Profile**:
- **Category**: `unspecified-high`
  - Reason: Game balance analysis
- **Skills**: `[]`
  - No special skills needed
- **Skills Evaluated but Omitted**:
  - None relevant

**Parallelization**:
- **Can Run In Parallel**: YES
- **Parallel Group**: Wave 6 (with Tasks 16, 18)
- **Blocks**: Task 18
- **Blocked By**: Tasks 13, 14, 15

**References**:

**Documentation References**:
- Master design doc - All numeric values
- `docs/snkrx_research/Summary.md` - SNKRX balance numbers

**WHY Each Reference Matters**:
- Verify implementation matches design doc numbers
- SNKRX numbers are battle-tested

**Acceptance Criteria**:

**Balance Verification Note:**

Balance tuning is a **runtime-only** verification because:
1. `TestHelpers.RunSimulation()` throws an error by design (requires full game context)
2. Balance feel requires actual gameplay, not simulated numbers
3. Session timing depends on player skill and real-time enemy AI

**DO NOT create `test_balance.lua`** - the test runner would fail on `RunSimulation()` calls.

**Manual Balance Verification Checklist:**
```
1. Build and run: just build-debug && ./build/raylib-cpp-cmake-template
2. Start Serpent mode, play through 5 waves
3. Time wave 1: Should complete in under 30 seconds with starter snake
4. Check gold after wave 5: Should have ~80 gold (enough for tier 2 unit)
5. Play full run to wave 20
6. Total session time: Should be 10-15 minutes

Evidence Screenshots:
- .sisyphus/evidence/task-17-wave1-time.png (stopwatch showing <30s)
- .sisyphus/evidence/task-17-wave5-gold.png (showing gold amount)
- .sisyphus/evidence/task-17-full-session.png (showing total time)

If balance is off, adjust in: assets/scripts/serpent/data/*.lua
- Wave gold rewards (wave_config.lua)
- Unit costs (units.lua)
- Enemy stats scaling (enemies.lua)
```

**Commit**: YES
- Message: `chore(serpent): balance pass for 10-15 minute session target`
- Files: `assets/scripts/serpent/data/*.lua` (tweaked values)
- Pre-commit: None (manual verification)

---

### Task 18: Final Integration Test

**What to do**:
- Create full end-to-end test
- Verify complete game loop: start → waves → shop → boss → victory
- Verify all systems integrate correctly
- Manual playtest for feel

**Must NOT do**:
- Don't add new features
- Don't fix non-critical bugs (document them instead)

**Recommended Agent Profile**:
- **Category**: `unspecified-high`
  - Reason: Integration testing
- **Skills**: `[]`
  - No special skills needed (canvas game - no DOM automation possible)
- **Skills Evaluated but Omitted**:
  - `playwright`: NOT useful - Raylib renders to canvas, no DOM to automate

**Parallelization**:
- **Can Run In Parallel**: NO - Final integration
- **Parallel Group**: Sequential (final task)
- **Blocks**: None (final)
- **Blocked By**: Tasks 16, 17

**References**:

**All prior tasks** - Integration of everything

**Acceptance Criteria**:

**Integration Test Design Note:**

The `serpent_main.lua` module uses the **SINGLETON PATTERN** (matching Integration Contract):
- `Serpent.init()` - Called by main.lua when entering SERPENT state
- `Serpent.update(dt)` - Called each frame by main.lua during SERPENT state
- Internal FSM handles states: playing → shop → game_over/victory → exit

Integration tests for Task 18 are **runtime verification checklists**, NOT automated Lua tests, because:
1. Serpent is a singleton initialized by main.lua, not a constructible class
2. Full game loop requires ECS entities, physics, rendering
3. Canvas-based output cannot be asserted programmatically

**Runtime Integration Verification Checklist:**
```
1. Build and run: just build-debug && ./build/raylib-cpp-cmake-template
2. Click "Serpent" on main menu
3. Verify: Snake of 3 starter units appears
4. Press WASD: Snake head moves in direction
5. Observe: Body segments follow with chain spacing
6. Wait for enemies to spawn
7. Observe: Units auto-attack enemies in range
8. Kill all enemies in wave 1
9. Verify: Shop screen appears with 5 offerings
10. Purchase a unit (if gold allows)
11. Click "Ready"
12. Verify: Wave 2 starts with more enemies
13. Reach wave 10
14. Verify: Swarm Queen boss appears with 500 HP
15. Complete or fail the run
16. Verify: Game over or victory screen shows stats
17. Click "Retry" or "Main Menu"
18. Verify: State resets correctly

Screenshot Evidence:
- .sisyphus/evidence/task-18-wave-gameplay.png
- .sisyphus/evidence/task-18-shop-screen.png
- .sisyphus/evidence/task-18-boss-fight.png
- .sisyphus/evidence/task-18-end-screen.png
```

**Playwright E2E Test**:
```
# Visual E2E verification via game runtime (`just serve-web` on port 8000):
1. Navigate to: http://localhost:8000
2. Start new game
3. Verify: Snake appears with starting units
4. Move snake with WASD/arrow keys
5. Observe: Units auto-attack spawned enemies
6. Complete wave 1
7. Verify: Shop screen appears
8. Purchase first unit offering
9. Click Ready
10. Verify: Wave 2 starts
11. Screenshot: .sisyphus/evidence/task-18-integration.png

Note: Canvas-based game, manual visual verification for final E2E.
```

**DO NOT create `test_integration.lua`** - `RunSimulation()` throws an error by design.
Task 18 verification is the Runtime Integration Checklist above.

**Commit**: YES
- Message: `test(serpent): verify full game integration (manual checklist)`
- Files: `.sisyphus/evidence/task-18-*.png` (screenshot evidence)
- Pre-commit: None (manual verification)

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `feat(serpent): initialize project structure` | `assets/scripts/serpent/**` | Directory exists |
| 2 | `feat(serpent): define 16 unit types` | `data/units.lua`, `tests/` | `lua test_runner.lua` |
| 3 | `feat(serpent): implement snake movement` | `snake_controller.lua`, `tests/` | `lua test_runner.lua` |
| 4 | `feat(serpent): implement synergy system` | `synergy_system.lua`, `tests/` | `lua test_runner.lua` |
| 5 | `feat(serpent): define 11 enemy types` | `data/enemies.lua`, `tests/` | `lua test_runner.lua` |
| 6 | `feat(serpent): configure 20 waves` | `wave_config.lua`, `tests/` | `lua test_runner.lua` |
| 7 | `feat(serpent): implement auto-attack` | `auto_attack.lua`, `tests/` | `lua test_runner.lua` |
| 8 | `feat(serpent): implement shop system` | `serpent_shop.lua`, `tests/` | `lua test_runner.lua` |
| 9 | `feat(serpent): implement unit factory` | `unit_factory.lua`, `tests/` | `lua test_runner.lua` |
| 10 | `feat(serpent): integrate combat` | `combat_manager.lua`, `tests/` | `lua test_runner.lua` |
| 11 | `feat(serpent): implement wave director` | `serpent_wave_director.lua`, `tests/` | `lua test_runner.lua` |
| 12 | `feat(serpent): implement shop UI` | `ui/shop_ui.lua`, `tests/` | `lua test_runner.lua` |
| 13 | `feat(serpent): implement synergy UI` | `ui/synergy_ui.lua`, `tests/` | `lua test_runner.lua` |
| 14 | `feat(serpent): implement HUD` | `ui/hud.lua`, `tests/` | `lua test_runner.lua` |
| 15 | `feat(serpent): implement bosses` | `bosses/*.lua`, `tests/` | `lua test_runner.lua` |
| 16 | `feat(serpent): implement end screens` | `ui/*_screen.lua`, `tests/` | `lua test_runner.lua` |
| 17 | `chore(serpent): balance tuning` | `data/*.lua` | Manual checklist |
| 18 | `test(serpent): integration verification` | `evidence/*.png` | Manual checklist |

---

## Success Criteria

### Verification Commands
```bash
# Run all Serpent tests (Tasks 1-16 have automated tests)
lua assets/scripts/tests/test_runner.lua assets/scripts/serpent/tests/

# Expected: All automated tests pass (~16 test files, ~80+ assertions), exit code 0
# NOTE: Tasks 17 and 18 are MANUAL verification only (no test_balance.lua or test_integration.lua)
#       because TestHelpers.RunSimulation() requires full game context and throws an error when run standalone

# Manual verification for Tasks 17 & 18 (via native or web build)
just build-debug && ./build/raylib-cpp-cmake-template
# Or: just serve-web  # Starts server on port 8000

# Task 17 balance checklist:
# 1. Wave 1 completes in under 30 seconds
# 2. ~80 gold after wave 5
# 3. Full run takes 10-15 minutes

# Task 18 integration checklist:
# 1. Complete game loop from start to victory/defeat
# 2. All systems integrate correctly
# 3. Screenshot evidence in .sisyphus/evidence/
```

### Final Checklist
- [ ] All 16 automated tasks completed with passing tests
- [ ] Task 17 manual balance verification completed (with evidence)
- [ ] Task 18 manual integration verification completed (with evidence)
- [ ] Full game loop playable from start to victory
- [ ] 16 units purchasable and functional in snake
- [ ] 4 class synergies activate at correct thresholds
- [ ] 2 boss fights function correctly
- [ ] Session completes in 10-15 minutes
- [ ] No critical bugs blocking gameplay
- [ ] All guardrails respected (no items, no interest, etc.)

---

*Plan generated by Prometheus based on roguelike-prototypes-design.md and SNKRX research. Ready for execution.*
