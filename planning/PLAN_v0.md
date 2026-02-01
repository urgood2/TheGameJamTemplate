# Descent - DCSS-Lite Traditional Roguelike Implementation Plan

## TL;DR

> **Quick Summary**: Implement "Descent", a DCSS-faithful traditional roguelike with turn-based combat, shadowcasting FOV, 5 dungeon floors, and a boss fight. Target 15-20 minute sessions. MVP-first approach with minimal content, then expand.
> 
> **Deliverables**: 
> - Playable turn-based roguelike with ASCII/tile aesthetic
> - 5 floors with procedural room templates + enemy/item placement
> - Character creation (species + background)
> - God system, spell system, item identification
> - Boss fight on floor 5
> - Victory/death screens
> 
> **Estimated Effort**: Large (~3-4 weeks for MVP, ~2 weeks for full content)
> **Parallel Execution**: YES - 3 waves (Foundation → Core Systems → Content)
> **Critical Path**: Tileset → Turn System → Map Rendering → Combat → Dungeon Gen → Victory/Death

---

## Context

### Original Request
Create a detailed implementation plan for Game #1 ("Descent") from the roguelike prototypes design document. The game is a DCSS-lite traditional roguelike with turn-based combat.

### Interview Summary

**Key Decisions Made**:
- **Test Strategy**: TDD with engine-appropriate framework
- **Tileset**: Copy dungeon_mode tileset (256 sprites) from external project
- **Dungeon Generation**: Template + Variation Hybrid (agent generates starter templates)
- **Item Identification**: Simple (scrolls only need identification)
- **Combat Feedback**: Instant + Flash/Shake (using existing HitFX)
- **Session Persistence**: Truly ephemeral (no save/load)
- **Turn System**: State machine (PLAYER_TURN, ENEMY_TURN, ANIMATING)
- **FOV**: Pure Lua recursive shadowcasting (simpler MVP approach; C++ integration deferred)
- **Input**: WASD + Numpad (no VI-keys)
- **Shop System**: Dynamic stock with reroll
- **Spell Selection**: Modal card selection
- **Content Scope**: MVP first (1 species, 1 background, 1 god, 3 spells, 5 enemies)

**Research Findings**:
- Engine has existing FOV system (`/src/systems/line_of_sight/`) - available but complex to integrate; using pure Lua for MVP
- Existing dungeon generator (`/assets/scripts/core/procgen/dungeon.lua`) - use as foundation
- Existing inventory system (`/assets/scripts/core/inventory_grid.lua`) - available
- Existing HitFX system - available
- No turn system exists - must build from scratch

### Master Design Document Reference

**CRITICAL**: All content specifications (species, backgrounds, gods, spells, enemies, items, formulas) come from:
- **Location**: `/Users/joshuashin/.superset/worktrees/TheGameJamTemplate/urgood2/roguelike-master-plan/.sisyphus/plans/roguelike-prototypes-design.md`
- **Section**: "GAME 1: DESCENT" (lines 126-401)

**Key formulas from design doc**:
```lua
-- Melee Attack (from design doc lines 246-249)
damage = weapon_base + str_modifier + species_bonus
hit_chance = 70 + (dex * 2) - (enemy_evasion * 2)

-- Ranged/Magic Attack (from design doc lines 251-254)
damage = spell_base * (1 + int * 0.05) * species_multiplier
hit_chance = 80 + (skill * 3)

-- Defense (from design doc lines 256-258)
damage_taken = incoming - armor_value
evasion_chance = 10 + (dex * 2) + dodge_skill

-- HP/MP Scaling (from design doc lines 260-266)
max_hp = (10 + species_hp_mod) * (1 + level * 0.15)
max_mp = (5 + species_mp_mod) * (1 + level * 0.1)

-- XP (from design doc lines 272-274)
xp_for_level_n = 10 * n * species_xp_mod
```

**Content quotas from design doc**:
- Floor 1: 15x15, 5-8 enemies, guaranteed shop
- Floor 2: 20x20, 8-12 enemies, first altar
- Floor 3: 20x20, 10-15 enemies, second altar
- Floor 4: 25x25, 12-18 enemies, third altar + miniboss
- Floor 5: 15x15, 5 guards + BOSS

### Metis Review

**Identified Gaps** (addressed):
- Tileset in external project → Copy to this worktree
- FOV needed → Implement pure Lua recursive shadowcasting (simpler than C++ integration for MVP)
- No turn system → Build state machine from scratch
- Room templates needed → Agent generates starter templates

---

## Work Objectives

### Core Objective
Build a playable turn-based traditional roguelike that faithfully captures the DCSS experience in 15-20 minute sessions.

### Concrete Deliverables
1. Turn-based game loop with state machine
2. Pure Lua recursive shadowcasting FOV (MVP approach; C++ integration deferred)
3. ASCII/tile map rendering using dungeon_mode tileset
4. Combat system with DCSS-like formulas
5. Dungeon generation with 5 floors
6. Character creation (species + background selection)
7. God system with abilities
8. Item system with scroll identification
9. Spell system with level-up acquisition
10. Shop system with dynamic stock
11. Boss fight on floor 5
12. Victory and death screens

### Definition of Done
- [ ] Player can create character (select species + background)
- [ ] Player can navigate 5 floors using WASD + numpad
- [ ] Turn-based combat works (player then enemies)
- [ ] FOV reveals/hides tiles correctly
- [ ] Items can be picked up, equipped, used
- [ ] Scrolls require identification
- [ ] God altars appear, god abilities work
- [ ] Level-up grants spell choices
- [ ] Shops work with reroll
- [ ] Boss fight on floor 5
- [ ] Victory screen on boss defeat
- [ ] Death screen on HP=0
- [ ] Run completes in 15-20 minutes

### Must Have
- Turn-based movement and combat
- Shadowcasting FOV
- 5 floors with stairs
- Basic combat (attack, damage, death)
- MVP content (1 species, 1 background, 1 god, 3 spells, 5 enemies)

### Must NOT Have (Guardrails)
- **No meta-progression** - Each run is independent
- **No autoexplore** - Manual navigation only
- **No hunger system** - Removed complexity
- **No dungeon branches** - Linear 5-floor descent
- **No inventory tetris** - Simple list inventory
- **No animations** - Instant state changes + HitFX flash only
- **No mouse support** - Keyboard only
- **No save/load** - Ephemeral sessions
- **No AI slop** - Don't over-abstract, no premature optimization
- **No scope creep** - MVP content only until core loop proven

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: YES - `/assets/scripts/tests/test_runner.lua`
- **User wants tests**: TDD
- **Framework**: Use existing `tests.test_runner` module (BDD-style describe/it/expect)

### TDD Approach

Each TODO follows RED-GREEN-REFACTOR where applicable:

1. **RED**: Write failing test first using existing test runner
2. **GREEN**: Implement minimum code to pass
3. **REFACTOR**: Clean up while keeping tests green

**Test Location**: `/assets/scripts/tests/test_descent_*.lua` (follows existing test naming convention)

**Existing Test Runner** (verified at `/assets/scripts/tests/test_runner.lua`):
```lua
local t = require("tests.test_runner")

t.describe("Descent Turn System", function()
    t.it("should start in PLAYER_TURN state", function()
        local TurnManager = require("descent.turn_manager")
        local tm = TurnManager.new()
        t.expect(tm:get_state()).to_be("PLAYER_TURN")
    end)
    
    t.it("should transition to ENEMY_TURN after player action", function()
        local TurnManager = require("descent.turn_manager")
        local tm = TurnManager.new()
        tm:player_action_complete()
        t.expect(tm:get_state()).to_be("ENEMY_TURN")
    end)
end)

t.run()  -- Returns true if all pass
```

### Automated Verification

| Deliverable Type | Verification Method |
|------------------|---------------------|
| Turn System | `t.expect(state).to_be("PLAYER_TURN")` |
| FOV | `t.expect(fov.is_visible(x,y)).to_be(true)` |
| Combat | `t.expect(result.damage).to_be(12)` |
| Dungeon Gen | `t.expect(#floor.rooms >= 5).to_be_truthy()` |
| UI Screens | Manual observation + state inspection |

### Test Execution Environments (CRITICAL)

**Two distinct execution contexts exist:**

| Context | What Can Be Tested | Execution Method |
|---------|-------------------|-----------------|
| **Headless Lua** | Pure logic (combat math, turn transitions, FOV calculations, data validation) | `lua tests/test_runner.lua --filter "descent"` |
| **In-Engine** | Rendering, input handling, UI screens, engine globals | Run game → Lua console → `require("tests.test_runner").run()` |

**Headless Tests** (no engine globals available):
- Turn state machine transitions
- Combat damage calculations  
- FOV visibility algorithms
- Dungeon template placement logic
- Item/spell data validation

```bash
# Run headless tests FROM PROJECT ROOT (not from assets/scripts!)
# The test runner's default directory is ./assets/scripts/tests (relative to cwd)
# Verified from test_runner.lua:991-992: opts.dir = "./assets/scripts/tests"

# Correct invocation:
lua assets/scripts/tests/test_runner.lua --filter "descent"

# WRONG (will fail to find tests):
# cd assets/scripts && lua tests/test_runner.lua --filter "descent"  # BAD!
```

**In-Engine Tests** (require `command_buffer`, `layers`, `registry`, etc.):
- Map rendering (`descent.map:render()`)
- UI screens (character creation, shop, victory/death)
- Input context binding verification
- Entity spawning and management

```lua
-- Run in-engine tests from game's Lua console:
local t = require("tests.test_runner")
t.set_filter("descent_rendering")  -- Only in-engine tests
t.run()
```

**Test File Naming Convention**:
- `test_descent_*.lua` → Headless (pure logic)
- `test_descent_rendering_*.lua` → In-engine (requires graphics/input)

**IMPORTANT**: Tests in `test_descent_*.lua` files must NOT call engine globals like `command_buffer`, `layers`, `registry`. If a module needs engine globals, either:
1. Mock them in the test
2. Move the test to an in-engine test file
3. Design the module with dependency injection

**Visual Verification Method**:
For UI verification, use Lua state inspection and manual observation:
```lua
-- Verify UI state via Lua (in-engine)
local ui_state = descent.ui.get_current_screen()
print("UI state:", ui_state)
-- Manually observe screen matches expected state

-- Note: No Lua screenshot API exists in this engine.
-- For visual evidence, use system screenshot tools:
-- - macOS: Cmd+Shift+4
-- - Windows: Print Screen or Snipping Tool
-- Save to: .sisyphus/evidence/task_name.png
```

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately - Foundation):
├── Task 1: Copy tileset to project
├── Task 2: Create descent/ module structure
└── Task 3: Setup test infrastructure

Wave 2 (After Wave 1 - Core Systems):
├── Task 4: Turn system state machine
├── Task 5: FOV Lua bindings
├── Task 6: Map rendering system
├── Task 7: Input context for roguelike
└── Task 8: Basic dungeon generation

Wave 3 (After Wave 2 - Core Gameplay):
├── Task 9: Combat system
├── Task 10: Item/inventory system
├── Task 11: Character creation UI
└── Task 12: Enemy AI

Wave 4 (After Wave 3 - Content & Polish):
├── Task 13: God system
├── Task 14: Spell system
├── Task 15: Shop system
├── Task 16: Level-up system
├── Task 17: Boss fight
├── Task 18: Victory/Death screens
└── Task 19: Full MVP content integration

Wave 5 (After MVP Validated - Content Expansion):
├── Task 20: Add remaining species (3 more)
├── Task 21: Add remaining backgrounds (3 more)
├── Task 22: Add remaining gods (4 more)
├── Task 23: Add remaining spells (9 more)
└── Task 24: Add remaining enemies (10 more)

Critical Path: 1 → 4 → 6 → 9 → 17 → 18
Parallel Speedup: ~50% faster than sequential
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 6 | 2, 3 |
| 2 | None | 4, 5, 6, 7, 8, 9, 10, 11, 12 | 1, 3 |
| 3 | None | 4, 5, 9 | 1, 2 |
| 4 | 2, 3 | 6, 9, 12 | 5, 7, 8 |
| 5 | 2, 3 | 6 | 4, 7, 8 |
| 6 | 1, 4, 5 | 8, 9, 11 | 7 |
| 7 | 2 | 4 | 4, 5, 6, 8 |
| 8 | 2, 6 | 17 | 7 |
| 9 | 3, 4, 6 | 12, 17 | 10, 11 |
| 10 | 6 | 13, 15 | 9, 11, 12 |
| 11 | 6 | None | 9, 10, 12 |
| 12 | 4, 9 | 17 | 10, 11 |
| 13 | 10 | 17 | 14, 15, 16 |
| 14 | 9 | 16 | 13, 15 |
| 15 | 10 | None | 13, 14, 16 |
| 16 | 14 | None | 13, 15 |
| 17 | 8, 9, 12 | 18 | None |
| 18 | 17 | 19 | None |
| 19 | 18 | 20-24 | None |

### Agent Dispatch Summary

| Wave | Tasks | Recommended Dispatch |
|------|-------|---------------------|
| 1 | 1, 2, 3 | `delegate_task(category="quick", load_skills=[], run_in_background=true)` × 3 |
| 2 | 4, 5, 6, 7, 8 | `delegate_task(category="unspecified-high", load_skills=[], ...)` |
| 3 | 9, 10, 11, 12 | `delegate_task(category="unspecified-high", ...)` |
| 4 | 13-18 | `delegate_task(category="visual-engineering", load_skills=["frontend-ui-ux"], ...)` for UI tasks |
| 5 | 20-24 | `delegate_task(category="quick", ...)` - content is data entry |

---

## TODOs

### Wave 1: Foundation

- [ ] 1. Copy Tileset to Project

  **What to do**:
  - Create `assets/graphics/pre-packing-files_globbed/dungeon_mode/` directory (does not exist yet)
  - Obtain dungeon tileset sprites (256 files: dm_000 through dm_255)
  - Copy sprites to the new directory
  - Regenerate sprite atlas using TexturePacker
  - Verify sprites are accessible via sprite system

  **Asset Acquisition - PRIMARY APPROACH**:
  
  **Use existing CP437 sprites already in repo** as the base:
  - Existing sprites: `assets/graphics/pre-packing-files_globbed/cp437/` (if present)
  - OR use `assets/graphics/cp437_20x20_sprites.png` as a sprite sheet reference
  
  If the tileset does NOT exist in repo, create minimal placeholder sprites:
  ```bash
  # Create the directory first:
  mkdir -p assets/graphics/pre-packing-files_globbed/dungeon_mode/
  
  # Generate 256 placeholder sprites (20x20 white squares with glyph):
  # This can be done with ImageMagick or a quick Python script:
  for i in $(seq 0 255); do
      printf -v num "%03d" $i
      convert -size 20x20 xc:black -fill white -gravity center \
          -pointsize 14 -annotate 0 "$(printf "\\x$(printf '%02x' $i)")" \
          "assets/graphics/pre-packing-files_globbed/dungeon_mode/dm_${num}.png"
  done
  ```
  
  **CRITICAL**: This task blocks Task 6 (Map Rendering). If tileset acquisition is unclear, use the placeholder approach above to unblock progress. Art can be improved later.

  **Alternative - Download from kenney.nl**:
  - Download "1-Bit Pack" from https://kenney.nl/assets/1-bit-pack
  - Extract and rename files to dm_XXX.png format
  - Map key glyphs: 64 → @ (player), 35 → # (wall), 46 → . (floor)

  **Must NOT do**:
  - Do not modify original sprites
  - Do not rename files (keep dm_XXX_name.png format)
  - Do not manually edit atlas JSON files (TexturePacker generates these)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple file copy operation + TexturePacker run
  - **Skills**: `[]`
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2, 3)
  - **Blocks**: Task 6 (Map Rendering)
  - **Blocked By**: None

  **References**:
  - Destination: `assets/graphics/pre-packing-files_globbed/dungeon_mode/`
  - TexturePacker project: `assets/graphics/sprites_texturepacker.tps` (main atlas config)
  - Generated atlas files: `assets/graphics/sprites-{n}.json` and `assets/graphics/sprites_atlas-{n}.png`
  - Alternative tileset: kenney.nl 1-Bit Pack (https://kenney.nl/assets/1-bit-pack)
  - CP437 reference: `assets/graphics/cp437_mappings.json` - Maps sprite_number → cp437 character → unicode codepoint (NOT sprite filenames). Used to understand which glyph each numbered sprite represents. Sprite naming convention is `dm_XXX_description.png` where XXX is the sprite_number (e.g., dm_064_at_symbol.png for '@' symbol).

  **Tileset/Atlas Pipeline**:
  
  The project uses **TexturePacker** to pack loose sprites into atlases:
  
  1. **Source Location**: Place sprite PNG files in `assets/graphics/pre-packing-files_globbed/`
     - Organized by subdirectory (e.g., `dungeon_mode/`, `characters/`)
     - Filename becomes sprite identifier (e.g., `dm_064_at_symbol.png` → sprite name "dm_064_at_symbol")
  
  2. **TexturePacker Config**: `assets/graphics/sprites_texturepacker.tps`
     - JSON-array output format
     - Max texture size: 4096×4096
     - Outputs to: `sprites_atlas-{n}.png` + `sprites-{n}.json`
  
  3. **Regenerate Atlas**: After adding new sprites, run TexturePacker:
     ```bash
     # If TexturePacker CLI is installed:
     TexturePacker assets/graphics/sprites_texturepacker.tps
     
     # Or open sprites_texturepacker.tps in TexturePacker GUI and click "Publish"
     ```
  
  4. **Sprite Access in Lua** (verified from `tutorial/dialogue/input_prompt.lua:187-208`):
     ```lua
     -- Sprite names in atlas include .png extension (verified from sprites-0.json)
     -- e.g., "dm_064_at_symbol.png" NOT "dm_064_at_symbol"
     
     -- Draw using command_buffer (verified API):
     command_buffer.queueDrawSpriteTopLeft(layers.sprites, function(c)
         c.spriteName = "dm_064_at_symbol.png"  -- NOTE: Include .png extension
         c.x = tileX * TILE_SIZE
         c.y = tileY * TILE_SIZE
         c.dstW = TILE_SIZE
         c.dstH = TILE_SIZE
         c.tint = Col(255, 255, 255, 255)  -- Use Col() for colors, not Color.WHITE
     end, zOrder, layer.DrawCommandSpace.World)
     
     -- Or via EntityBuilder (for persistent entities):
     EntityBuilder.new()
         :sprite("dm_064_at_symbol.png")
         :position(x, y)
         :build()
     ```
  
  **Note**: The `.tps` file (line 37) shows output goes to `sprites_atlas-{n}.png`, and the data format is `json-array` (line 35).

  **Acceptance Criteria**:
  ```bash
  # Agent runs - verify directory created and files copied:
  ls -la assets/graphics/pre-packing-files_globbed/dungeon_mode/ | head -5
  # Assert: Directory exists with sprite files
  
  ls assets/graphics/pre-packing-files_globbed/dungeon_mode/ | wc -l
  # Assert: Output is 256 (or at minimum, key sprites exist)
  
  # Verify specific key files exist (using simple numbered names):
  ls assets/graphics/pre-packing-files_globbed/dungeon_mode/dm_064*.png
  # Assert: File exists (sprite 64 = '@' player symbol)
  
  ls assets/graphics/pre-packing-files_globbed/dungeon_mode/dm_035*.png
  # Assert: File exists (sprite 35 = '#' wall)
  
  # Verify TexturePacker regenerated atlas (after running TexturePacker):
  ls assets/graphics/sprites-*.json | head -1
  # Assert: At least one sprites JSON file exists
  
  # Verify sprite appears in atlas JSON (grep for filename):
  grep -l "dm_064" assets/graphics/sprites-*.json
  # Assert: At least one JSON file contains the sprite entry
  ```
  
  **In-Engine Verification** (run in Lua console after starting game):
  ```lua
  -- Test that the sprite can be drawn without error:
  command_buffer.queueDrawSpriteTopLeft(layers.sprites, function(c)
      c.spriteName = "dm_064.png"  -- Use actual filename
      c.x = 100
      c.y = 100
      c.dstW = 20
      c.dstH = 20
      c.tint = Col(255, 255, 255, 255)
  end, 100, layer.DrawCommandSpace.Screen)
  -- Assert: No error thrown, sprite appears on screen
  ```

  **Commit**: YES
  - Message: `feat(descent): copy dungeon_mode tileset (256 sprites)`
  - Files: `assets/graphics/pre-packing-files_globbed/dungeon_mode/*`, `assets/graphics/sprites-*.json`, `assets/graphics/sprites_atlas-*.png`

---

- [ ] 2. Create Descent Module Structure

  **What to do**:
  - Create directory structure at `/assets/scripts/descent/`
  - Create module files with basic boilerplate:
    - `descent/init.lua` - Main entry point
    - `descent/turn_manager.lua` - Turn system state machine
    - `descent/combat.lua` - Combat calculations
    - `descent/fov.lua` - Pure Lua FOV implementation
    - `descent/map.lua` - Map rendering and tile management
    - `descent/dungeon.lua` - Dungeon generation using templates
    - `descent/player.lua` - Player state and actions
    - `descent/enemy.lua` - Enemy definitions and AI
    - `descent/items.lua` - Item definitions
    - `descent/spells.lua` - Spell definitions
    - `descent/gods.lua` - God system
    - `descent/status_effects.lua` - Status effect system (berserk, slow, regen, etc.)
    - `descent/pathfinding.lua` - A* pathfinding for enemy AI
    - `descent/ui/` - UI components directory
    - `descent/data/` - Content data directory
    - `descent/debug.lua` - Debug commands for testing
  
  **Status Effects System** (`descent/status_effects.lua`):
  
  Cross-cutting system used by gods, spells, items, and enemies. Required structure:
  
  ```lua
  local StatusEffects = {}
  
  -- Status effect definitions
  StatusEffects.EFFECTS = {
      berserk = {
          duration = 10,  -- turns
          stacks = false,  -- can't stack, refresh duration instead
          on_apply = function(entity) entity.damage_multiplier = 1.5 end,
          on_remove = function(entity) entity.damage_multiplier = 1.0 end,
      },
      slow = {
          duration = 5,
          stacks = false,
          on_apply = function(entity) entity.speed = "slow" end,
          on_remove = function(entity) entity.speed = entity.base_speed end,
      },
      regen = {
          duration = 20,
          stacks = false,  -- refreshes duration
          on_tick = function(entity) entity.hp = math.min(entity.hp + 2, entity.max_hp) end,
      },
      poison = {
          duration = 10,
          stacks = true,  -- multiple poison stacks compound
          on_tick = function(entity, stacks) entity.hp = entity.hp - stacks end,
      },
  }
  
  -- Apply status to entity (handles stacking/refresh)
  function StatusEffects.apply(entity, effect_name, duration_override)
      -- Implementation handles effect.stacks, calls on_apply
  end
  
  -- Tick all effects on entity (call at END of entity's turn)
  function StatusEffects.tick(entity)
      -- Decrement durations, call on_tick, remove expired effects
  end
  
  -- Remove specific effect
  function StatusEffects.remove(entity, effect_name)
      -- Calls on_remove callback
  end
  
  return StatusEffects
  ```
  
  **Integration Points**:
  - Turn system calls `StatusEffects.tick(entity)` at END of each entity's turn
  - Gods apply effects via `StatusEffects.apply(player, "berserk")`
  - Combat checks effects for damage modifiers
  - UI shows active effects on player/enemy
  
  **Debug Module Specification** (`descent/debug.lua`):
  
  This module provides testing/verification helpers. Required functions:
  
  ```lua
  local Debug = {}
  
  -- Grant XP to player (for testing level-up flow)
  -- Usage: descent.debug.grant_xp(30)
  function Debug.grant_xp(amount)
      local player = descent.get_player()
      player.xp = (player.xp or 0) + amount
      -- Trigger level-up check
      local Leveling = require("descent.leveling")
      Leveling.check_levelup(player)
  end
  
  -- Set player HP directly (for testing death screen)
  -- Usage: descent.debug.set_player_hp(1)
  function Debug.set_player_hp(hp)
      local player = descent.get_player()
      player.hp = hp
  end
  
  -- Skip to a specific floor (for testing boss/victory)
  -- Usage: descent.debug.skip_to_floor(5)
  function Debug.skip_to_floor(floor_num)
      local state = descent.get_state()
      state.current_floor = floor_num
      descent.generate_floor(floor_num)
  end
  
  -- Kill boss instantly (for testing victory screen)
  -- Usage: descent.debug.kill_boss()
  function Debug.kill_boss()
      local state = descent.get_state()
      if state.boss then
          state.boss.hp = 0
          state.boss:on_death()
      end
  end
  
  return Debug
  ```
  
  **Note**: Tests go in `/assets/scripts/tests/test_descent_*.lua` (using existing test infrastructure)

  **Must NOT do**:
  - Do not modify existing `/assets/scripts/core/` files **in this task** (Task 2 is module structure only)
  - Do not duplicate existing functionality (reference it instead)
  
  **Core Edit Policy Exception** (for Task 19 integration):
  
  Task 19 WILL require minimal edits to these core files:
  - `assets/scripts/core/main.lua` - Add GAMESTATE.DESCENT, initDescent(), changeGameState() case
  - `assets/scripts/ui/main_menu_buttons.lua` - Add "Descent" button
  
  These edits are allowed ONLY in Task 19 and must be:
  - Additive (don't modify existing IN_GAME behavior)
  - Minimal (only what's needed for entry/exit)
  - Isolated (Descent logic stays in descent/ module)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Directory and file creation
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 3)
  - **Blocks**: Tasks 4-12 (all core systems)
  - **Blocked By**: None

  **References**:
  - Module pattern: `assets/scripts/core/entity_builder.lua` - Shows module export pattern (no core/init.lua exists)
  - EntityBuilder pattern: `assets/scripts/core/entity_builder.lua` - Lines 1-50 show standard module structure:
    ```lua
    local M = {}  -- Module table
    function M.new(...) ... end
    return M
    ```
  - Inventory grid: `assets/scripts/core/inventory_grid.lua` - Another module pattern example

  **Acceptance Criteria**:
  ```bash
  # Agent runs:
  ls -la assets/scripts/descent/
  # Assert: Shows init.lua, turn_manager.lua, combat.lua, fov.lua, debug.lua, etc.
  
  ls assets/scripts/descent/ui/
  # Assert: Directory exists
  
  ls assets/scripts/descent/debug.lua
  # Assert: File exists (debug module for testing)
  
  # Verify debug module has required functions:
  grep -c "function Debug" assets/scripts/descent/debug.lua
  # Assert: Returns 4 (grant_xp, set_player_hp, skip_to_floor, kill_boss)
  ```

  **Commit**: YES
  - Message: `feat(descent): create module structure`
  - Files: `assets/scripts/descent/*`

---

- [ ] 3. Create Initial Descent Test Files (Using Existing Test Runner)

  **What to do**:
  - Create initial test file `/assets/scripts/tests/test_descent_turn_system.lua` using existing test runner
  - Write first failing test for turn system (TDD: RED phase)
  - Verify tests run correctly with existing infrastructure
  
  **IMPORTANT**: Use the existing test runner at `/assets/scripts/tests/test_runner.lua` - do NOT create a new one.

  **Must NOT do**:
  - Do NOT create a new test runner (one already exists)
  - Do NOT create `/assets/scripts/descent/tests/` directory (use existing `/assets/scripts/tests/`)
  - Do not modify engine C++ test infrastructure

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple test file creation
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2)
  - **Blocks**: Tasks 4, 5, 9 (systems that need tests)
  - **Blocked By**: None

  **References**:
  - Existing test runner: `/assets/scripts/tests/test_runner.lua` (BDD-style describe/it/expect)
  - Existing test examples: `/assets/scripts/tests/test_*.lua` (many examples available)
  - Test runner docs: `/assets/scripts/tests/test_runner.lua:1-55` (usage documentation in file header)

  **Test File Template** (create at `/assets/scripts/tests/test_descent_turn_system.lua`):
  ```lua
  -- test_descent_turn_system.lua
  local t = require("tests.test_runner")
  
  t.describe("Descent Turn System", function()
      t.it("should start in PLAYER_TURN state", function()
          -- This test will fail initially (TDD RED phase)
          local TurnManager = require("descent.turn_manager")
          local tm = TurnManager.new()
          t.expect(tm:get_state()).to_be("PLAYER_TURN")
      end)
  end)
  
  return t.run()
  ```

  **Acceptance Criteria**:
  ```bash
  # Run from PROJECT ROOT (NOT from assets/scripts!):
  # Verified: test_runner.lua:991-992 uses "./assets/scripts/tests" relative to cwd
  lua assets/scripts/tests/test_runner.lua --filter "descent"
  
  # Expected output (TDD RED phase - test should FAIL):
  # Descent Turn System
  #   ✗ should start in PLAYER_TURN state
  # 
  # 1 failed, 0 passed
  ```

  **Commit**: YES
  - Message: `feat(descent): setup test infrastructure with failing turn system test`
  - Files: `assets/scripts/tests/test_descent_turn_system.lua`

---

### Wave 2: Core Systems

- [ ] 4. Implement Turn System State Machine

  **What to do**:
  - Implement state machine in `descent/turn_manager.lua`
  - States: `INITIALIZING`, `PLAYER_TURN`, `PROCESSING_PLAYER`, `ENEMY_TURN`, `PROCESSING_ENEMIES`, `ANIMATING`, `GAME_OVER`, `VICTORY`
  - Player turn waits for input, then transitions to PROCESSING_PLAYER
  - After player action, transition to ENEMY_TURN
  - Process all enemies sequentially, then back to PLAYER_TURN
  - ANIMATING state for HitFX (brief, non-blocking)
  - Write tests for state transitions
  
  **Speed/Action Economy System**:
  
  Enemies have a `speed` property that affects how often they act:
  - `"fast"` - Acts twice per player turn (2 actions per round)
  - `"normal"` - Acts once per player turn (default)
  - `"slow"` - Acts every other player turn (0.5 actions per round)
  
  **Implementation approach** (energy system):
  ```lua
  -- Each entity has energy that accumulates
  -- Normal speed gains 100 energy per player turn
  -- Fast gains 200, Slow gains 50
  -- Action costs 100 energy
  
  TurnManager.SPEED_ENERGY = {
      fast = 200,
      normal = 100,
      slow = 50,
  }
  
  function TurnManager:process_enemy_turn()
      for _, enemy in ipairs(self.enemies) do
          -- Add energy based on speed
          enemy.energy = (enemy.energy or 0) + self.SPEED_ENERGY[enemy.speed or "normal"]
          
          -- Act while enough energy
          while enemy.energy >= 100 do
              enemy:take_action()
              enemy.energy = enemy.energy - 100
          end
      end
  end
  ```
  
  **Status effect integration**: `StatusEffects.tick(enemy)` called AFTER each individual action

  **Must NOT do**:
  - Do not integrate with real game loop yet (test in isolation first)
  - Do not add actual combat logic (just state transitions)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Core system, requires careful design
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 5, 7, 8)
  - **Blocks**: Tasks 6, 9, 12
  - **Blocked By**: Tasks 2, 3

  **References**:
  - State machine pattern: Check existing AI state machines in `assets/scripts/ai/`
  - Signal pattern: `docs/api/signal_system.md` - For state change events

  **Acceptance Criteria**:
  ```lua
  -- Test in tests/test_descent_turn_system.lua:
  local TurnManager = require("descent.turn_manager")
  local tm = TurnManager.new()
  
  -- Test initial state
  assert(tm:get_state() == "PLAYER_TURN", "Should start in PLAYER_TURN")
  
  -- Test player action transitions to enemy turn
  tm:player_action_complete()
  assert(tm:get_state() == "ENEMY_TURN", "Should transition to ENEMY_TURN")
  
  -- Test enemy turn completion
  tm:enemies_action_complete()
  assert(tm:get_state() == "PLAYER_TURN", "Should return to PLAYER_TURN")
  
  -- Test game over
  tm:trigger_game_over()
  assert(tm:get_state() == "GAME_OVER", "Should be GAME_OVER")
  
  print("Basic turn system tests passed!")
  ```
  
  **Speed/Energy System Tests**:
  ```lua
  -- Test in tests/test_descent_turn_system.lua:
  local TurnManager = require("descent.turn_manager")
  
  -- Track action counts
  local action_counts = { fast = 0, normal = 0, slow = 0 }
  
  -- Create mock enemies
  local fast_enemy = {
      speed = "fast",
      energy = 0,
      take_action = function(self) action_counts.fast = action_counts.fast + 1 end
  }
  local normal_enemy = {
      speed = "normal",
      energy = 0,
      take_action = function(self) action_counts.normal = action_counts.normal + 1 end
  }
  local slow_enemy = {
      speed = "slow",
      energy = 0,
      take_action = function(self) action_counts.slow = action_counts.slow + 1 end
  }
  
  local tm = TurnManager.new()
  tm:add_enemy(fast_enemy)
  tm:add_enemy(normal_enemy)
  tm:add_enemy(slow_enemy)
  
  -- Simulate 2 player turns
  for i = 1, 2 do
      tm:player_action_complete()
      tm:process_enemy_turn()
  end
  
  -- Fast enemy: 2 turns × 200 energy = 400 energy = 4 actions
  assert(action_counts.fast == 4, "Fast enemy should act 4 times, got " .. action_counts.fast)
  
  -- Normal enemy: 2 turns × 100 energy = 200 energy = 2 actions  
  assert(action_counts.normal == 2, "Normal enemy should act 2 times, got " .. action_counts.normal)
  
  -- Slow enemy: 2 turns × 50 energy = 100 energy = 1 action
  assert(action_counts.slow == 1, "Slow enemy should act 1 time, got " .. action_counts.slow)
  
  print("Speed/energy system tests passed!")
  ```

  **Commit**: YES (groups with 5)
  - Message: `feat(descent): implement turn system state machine`
  - Files: `assets/scripts/descent/turn_manager.lua`, `assets/scripts/tests/test_descent_turn_system.lua`

---

- [ ] 5. Implement Pure Lua FOV System

  **What to do**:
  - Create `descent/fov.lua` with a pure Lua recursive shadowcasting implementation
  - Track current visibility (cleared each turn) and explored tiles (persists)
  - Integrate with Descent's map system via a simple `is_walkable(x, y)` interface
  - Write tests for FOV calculation
  
  **IMPORTANT: Why Pure Lua instead of C++ FOV bindings**:
  The existing C++ FOV system (`/src/systems/line_of_sight/`) depends on:
  - `globals::map[x][y]` being populated with tile entities
  - Each tile entity having `TileComponent.blocksLight`
  - `initLineOfSight(registry)` being called after map setup
  
  This creates a complex integration requirement between Lua dungeon generation and C++ tile entities. For Descent's MVP, a pure Lua FOV is simpler and sufficient.
  
  **Future upgrade path**: If performance becomes an issue (unlikely for 25x25 maps), Task 5 can be revisited to add C++ bindings later.

  **Must NOT do**:
  - Do not create C++ bindings (keep it simple for MVP)
  - Do not attempt to populate `globals::map` from Lua

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: C++/Lua binding work
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 4, 7, 8)
  - **Blocks**: Task 6
  - **Blocked By**: Tasks 2, 3

  **References**:
  - FOV algorithm: Recursive shadowcasting (roguebasin.com)
  - Existing procgen utilities: `/assets/scripts/core/procgen/dungeon.lua` - for coordinate/grid patterns

  **Pure Lua Shadowcasting Implementation** (descent/fov.lua):
  ```lua
  -- Simple recursive shadowcasting algorithm
  -- Based on: http://www.roguebasin.com/index.php/FOV_using_recursive_shadowcasting
  local M = {}
  local explored = {}
  local visible = {}
  local map = nil  -- Will be set by M.set_map
  
  -- Multipliers for the 8 octants
  local mult = {
      {1,0,0,-1,-1,0,0,1}, {0,1,-1,0,0,-1,1,0},
      {0,1,1,0,0,-1,-1,0}, {1,0,0,1,-1,0,0,-1}
  }
  
  local function blocks(x, y)
      return not map:is_walkable(x, y)
  end
  
  local function set_visible(x, y)
      visible[x] = visible[x] or {}
      visible[x][y] = true
      explored[x] = explored[x] or {}
      explored[x][y] = true
  end
  
  local function cast_light(ox, oy, row, start, finish, radius, xx, xy, yx, yy)
      if start < finish then return end
      local new_start = 0
      for j = row, radius do
          local dx, dy = -j - 1, -j
          local blocked = false
          while dx <= 0 do
              dx = dx + 1
              local X = ox + dx * xx + dy * xy
              local Y = oy + dx * yx + dy * yy
              local l_slope = (dx - 0.5) / (dy + 0.5)
              local r_slope = (dx + 0.5) / (dy - 0.5)
              if start < r_slope then
                  -- continue
              elseif finish > l_slope then
                  break
              else
                  if dx * dx + dy * dy < radius * radius then
                      set_visible(X, Y)
                  end
                  if blocked then
                      if blocks(X, Y) then
                          new_start = r_slope
                      else
                          blocked = false
                          start = new_start
                      end
                  else
                      if blocks(X, Y) and j < radius then
                          blocked = true
                          cast_light(ox, oy, j + 1, start, l_slope, radius, xx, xy, yx, yy)
                          new_start = r_slope
                      end
                  end
              end
          end
          if blocked then break end
      end
  end
  
  function M.set_map(m) map = m end
  
  function M.compute(x, y, radius)
      visible = {}
      set_visible(x, y)
      for oct = 1, 8 do
          cast_light(x, y, 1, 1.0, 0.0, radius,
              mult[1][oct], mult[2][oct], mult[3][oct], mult[4][oct])
      end
  end
  
  function M.is_visible(x, y) return visible[x] and visible[x][y] or false end
  function M.is_explored(x, y) return explored[x] and explored[x][y] or false end
  function M.reset() explored = {}; visible = {} end
  
  return M
  ```

  **Acceptance Criteria**:
  ```lua
  -- Test in tests/test_descent_fov.lua:
  local FOV = require("descent.fov")
  
  -- Create mock map for testing
  local mock_map = {
      width = 10, height = 10,
      walls = { [5] = { [5] = true } },  -- Wall at (5,5)
      is_walkable = function(self, x, y)
          if x < 0 or y < 0 or x >= self.width or y >= self.height then return false end
          return not (self.walls[x] and self.walls[x][y])
      end
  }
  FOV.set_map(mock_map)
  
  -- Compute FOV from position (3, 3) with range 5
  FOV.compute(3, 3, 5)
  
  -- Player position should be visible
  assert(FOV.is_visible(3, 3) == true, "Player position should be visible")
  
  -- Adjacent positions should be visible
  assert(FOV.is_visible(4, 3) == true, "Adjacent should be visible")
  
  -- Also verify explored tracking
  assert(FOV.is_explored(4, 3) == true, "Adjacent should be explored")
  
  print("FOV tests passed!")
  ```

  **Commit**: YES (groups with 4)
  - Message: `feat(descent): implement pure Lua FOV with recursive shadowcasting`
  - Files: `assets/scripts/descent/fov.lua`, `assets/scripts/tests/test_descent_fov.lua`

---

- [ ] 6. Implement Map Rendering System

  **What to do**:
  - Create `descent/map.lua` for tile-based map management
  - Load dungeon_mode tileset sprites
  - Create tile type enum: FLOOR, WALL, DOOR, STAIRS_UP, STAIRS_DOWN, etc.
  - Render map using tile sprites from dungeon_mode tileset
  - Integrate FOV - only render visible tiles, show "fog of war" for explored but not visible
  - Create coordinate system (tile coords vs screen coords)
  - Camera follows player

  **Must NOT do**:
  - Do not add smooth camera movement (instant snap)
  - Do not add tile animations

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: Rendering and visual system
  - **Skills**: `["frontend-ui-ux"]`
    - frontend-ui-ux: Tile rendering and visual layout

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (after Tasks 4, 5)
  - **Blocks**: Tasks 8, 9, 11
  - **Blocked By**: Tasks 1, 4, 5

  **References**:
  - Tileset: `assets/graphics/pre-packing-files_globbed/dungeon_mode/` (after Task 1)
  - Sprite mapping: Use filename convention dm_XXX_name.png (e.g., "dm_064_at_symbol.png")
  - Layer system: `docs/api/z-order-rendering.md`
  - Draw command API: `assets/scripts/core/gameplay.lua:6687-6730` - Shows correct queueDrawSpriteTopLeft usage

  **Rendering API** (verified from gameplay.lua):
  
  The engine uses `command_buffer.queueDrawSpriteTopLeft` for tile rendering:
  ```lua
  -- Correct rendering pattern (from gameplay.lua:6687):
  command_buffer.queueDrawSpriteTopLeft(layers.sprites, function(c)
      c.spriteName = "dm_035_hash.png"  -- Floor tile sprite name
      c.x = screen_x
      c.y = screen_y
      c.dstW = TILE_SIZE  -- e.g., 16 or 32
      c.dstH = TILE_SIZE
      c.tint = tile_tint  -- Color table for FOV dimming
  end, z_order, layer.DrawCommandSpace.World)
  
  -- Sprite command fields (from chugget_code_definitions.lua:2504-2518):
  -- c.spriteName: string - Name of sprite in atlas
  -- c.x, c.y: number - Top-left position
  -- c.dstW, c.dstH: number|nil - Destination size (nil = original size)
  -- c.tint: Color - Tint color for visibility/fog effects
  ```
  
  **Tile Sprite Mapping**:
  ```lua
  local TILE_SPRITES = {
      [TILE.FLOOR] = "dm_046_period.png",      -- . (floor)
      [TILE.WALL] = "dm_035_hash.png",         -- # (wall)
      [TILE.DOOR_CLOSED] = "dm_043_plus.png",  -- + (closed door)
      [TILE.DOOR_OPEN] = "dm_039_quote.png",   -- ' (open door)
      [TILE.STAIRS_DOWN] = "dm_062_greater.png", -- > (stairs down)
      [TILE.STAIRS_UP] = "dm_060_less.png",    -- < (stairs up)
  }
  ```
  
  **FOV Tinting**:
  ```lua
  local function get_tile_tint(x, y)
      if FOV.is_visible(x, y) then
          return Color.WHITE  -- Full brightness
      elseif FOV.is_explored(x, y) then
          return { r = 80, g = 80, b = 100, a = 255 }  -- Dim blue-gray for fog
      else
          return nil  -- Don't render at all
      end
  end
  ```

  **Acceptance Criteria**:
  ```lua
  -- Test in tests/test_descent_map.lua (IN-ENGINE - requires command_buffer):
  local Map = require("descent.map")
  
  -- Create small test map
  local map = Map.new(10, 10)
  map:set_tile(5, 5, Map.TILE.FLOOR)
  map:set_tile(0, 0, Map.TILE.WALL)
  
  -- Verify tile types
  assert(map:get_tile(5, 5) == Map.TILE.FLOOR, "Should be floor")
  assert(map:get_tile(0, 0) == Map.TILE.WALL, "Should be wall")
  
  -- Verify render doesn't crash
  map:render()
  print("Map rendering test passed!")
  ```
  
  **Visual Verification** (manual - no screenshot API available):
  ```
  Manual verification steps:
  1. Start descent mode
  2. Observe: Tile grid renders on screen (floor and wall tiles visible)
  3. Move player to reveal FOV changes
  4. Observe: Previously visible tiles appear dimmed (fog of war)
  5. Observe: Unexplored tiles are not rendered (black)
  
  Note: Engine does not expose a Lua screenshot function.
  Use system screenshot (Cmd+Shift+4 on macOS, Print Screen on Windows) if needed.
  ```

  **Commit**: YES
  - Message: `feat(descent): implement tile-based map rendering with FOV`
  - Files: `assets/scripts/descent/map.lua`, `assets/scripts/tests/test_descent_rendering_map.lua`

---

- [ ] 7. Create Roguelike Input Context

  **What to do**:
  - Create new input context "roguelike" in input system
  - Map controls:
    - WASD: 4-directional movement
    - Numpad 1-9: 8-directional movement (including diagonals)
    - SPACE or ENTER: Confirm/interact
    - I: Open inventory
    - G: Pick up item
    - D: Drop item
    - C: Character sheet
    - M: Message log
    - ESC: Menu/cancel
    - 1-9 (top row): Spell hotkeys
    - TAB: Next target
  - Do NOT process input during ENEMY_TURN state

  **Must NOT do**:
  - Do not add mouse controls
  - Do not modify existing "gameplay" input context

  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
    - Reason: Configuration work
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 4, 5, 6, 8)
  - **Blocks**: Task 4 (input handling)
  - **Blocked By**: Task 2

  **References**:
  - **AUTHORITATIVE SOURCE**: `src/systems/input/input_lua_bindings.cpp` (lines 786-798) - This is the ground truth for field names
  - Input system docs: `src/systems/input/input_action_binding_usage.md` - **WARNING: This doc uses incorrect mouse field (`key` instead of `mouse`); follow C++ source, not this doc**
  - Existing gameplay bindings: `assets/scripts/core/gameplay.lua:5154-5210` - Shows actual `input.bind` usage pattern
  - Existing gameplay bindings: `assets/scripts/core/gameplay.lua:9226-9301` - Shows survivor mode input bindings

  **Input API (verified from assets/scripts/core/gameplay.lua)**:
  
  The `input.bind` function uses **different field names depending on device type**:
  
  **Keyboard bindings** (verified from gameplay.lua:9226):
  ```lua
  input.bind("action_name", {
      device = "keyboard",           -- Device type
      key = KeyboardKey.KEY_W,       -- Use KeyboardKey enum
      trigger = "Pressed",           -- "Pressed" | "Released" | "Down"
      context = "roguelike"          -- Input context name
  })
  
  -- Example:
  input.bind("move_up", { device = "keyboard", key = KeyboardKey.KEY_W, trigger = "Pressed", context = "roguelike" })
  
  -- Numpad keys (for 8-directional movement):
  input.bind("move_upleft", { device = "keyboard", key = KeyboardKey.KEY_KP_7, trigger = "Pressed", context = "roguelike" })
  input.bind("move_downright", { device = "keyboard", key = KeyboardKey.KEY_KP_3, trigger = "Pressed", context = "roguelike" })
  ```
  
  **Gamepad BUTTON bindings** (verified from gameplay.lua:5154-5209):
  ```lua
  input.bind("action_name", {
      device = "gamepad_button",              -- NOTE: "gamepad_button", NOT "gamepad"
      button = GamepadButton.GAMEPAD_BUTTON_RIGHT_FACE_DOWN,  -- NOTE: field is "button", NOT "key"
      trigger = "Pressed",
      context = "roguelike"
  })
  
  -- Example D-pad bindings (from gameplay.lua:5160-5184):
  input.bind("dpad_up", { device = "gamepad_button", button = GamepadButton.GAMEPAD_BUTTON_LEFT_FACE_UP, trigger = "Pressed", context = "roguelike" })
  input.bind("dpad_down", { device = "gamepad_button", button = GamepadButton.GAMEPAD_BUTTON_LEFT_FACE_DOWN, trigger = "Pressed", context = "roguelike" })
  ```
  
  **Gamepad AXIS bindings** (verified from gameplay.lua:9278-9301):
  ```lua
  input.bind("action_name", {
      device = "gamepad_axis",               -- NOTE: "gamepad_axis" for analog sticks
      axis = GamepadAxis.GAMEPAD_AXIS_LEFT_X,  -- NOTE: field is "axis", NOT "key"
      trigger = "Axis",
      context = "roguelike"
  })
  
  -- Example:
  input.bind("gamepad_move_x", { device = "gamepad_axis", axis = GamepadAxis.GAMEPAD_AXIS_LEFT_X, trigger = "Axis", context = "roguelike" })
  ```
  
  **Mouse bindings** (verified from input_lua_bindings.cpp:792-793):
  ```lua
  input.bind("action_name", {
      device = "mouse",
      mouse = MouseButton.MOUSE_BUTTON_LEFT,  -- NOTE: field is "mouse", NOT "key"
      trigger = "Pressed",
      context = "roguelike"
  })
  ```
  
  **CRITICAL**: The field names are device-specific (verified from C++ source):
  - `keyboard` → `key = KeyboardKey.KEY_*`
  - `mouse` → `mouse = MouseButton.MOUSE_BUTTON_*` (NOT `key`!)
  - `gamepad_button` → `button = GamepadButton.GAMEPAD_BUTTON_*`
  - `gamepad_axis` → `axis = GamepadAxis.GAMEPAD_AXIS_*`
  
  **Available Enums** (from input_lua_bindings.cpp):
  - `KeyboardKey.KEY_W`, `KEY_A`, `KEY_S`, `KEY_D`, `KEY_SPACE`, `KEY_ENTER`, `KEY_ESCAPE`
  - `KeyboardKey.KEY_KP_1` through `KEY_KP_9` (numpad), `KEY_KP_0`
  - `KeyboardKey.KEY_ONE` through `KEY_NINE` (top row numbers)
  - `MouseButton.MOUSE_BUTTON_LEFT`, `MOUSE_BUTTON_RIGHT`, `MOUSE_BUTTON_MIDDLE`
  - `GamepadButton.GAMEPAD_BUTTON_LEFT_FACE_UP/DOWN/LEFT/RIGHT` (D-pad)
  - `GamepadButton.GAMEPAD_BUTTON_RIGHT_FACE_DOWN` (A button on Xbox)
  - `GamepadAxis.GAMEPAD_AXIS_LEFT_X`, `GAMEPAD_AXIS_LEFT_Y`, `GAMEPAD_AXIS_RIGHT_X`, `GAMEPAD_AXIS_RIGHT_Y`
  
  **Context Management**:
  ```lua
  input.set_context("roguelike")        -- Set active context
  input.action_pressed("move_up")       -- Check if action just pressed
  input.action_down("move_up")          -- Check if action held
  input.action_value("gamepad_move_x")  -- Get analog value (-1 to 1)
  ```

  **Acceptance Criteria**:
  ```lua
  -- Test in tests/test_descent_rendering_input.lua (IN-ENGINE - requires input system):
  local descent_input = require("descent.input")
  
  -- Setup roguelike context
  descent_input.setup_context()
  
  -- Verify context is set
  assert(descent_input.current_context == "roguelike", "Context should be roguelike")
  
  -- Verify bindings were registered by checking action detection works
  -- (Note: Can't directly query bindings, but can verify setup didn't error)
  print("Input context setup passed!")
  
  -- Test actual input in game loop (manual verification):
  -- 1. Press W key
  -- 2. Verify input.action_pressed("move_up") returns true
  ```
  
  **Manual Input Verification**:
  ```
  1. Start descent mode
  2. Press W - player should move up
  3. Press numpad 7 - player should move up-left (diagonal)
  4. Press I - inventory should open
  5. Press G near item - item should be picked up
  ```

  **Commit**: YES (groups with 8)
  - Message: `feat(descent): create roguelike input context with WASD + numpad`
  - Files: `assets/scripts/descent/input.lua`, input config files

---

- [ ] 8. Basic Dungeon Generation with Room Templates

  **What to do**:
  - Create `descent/dungeon.lua` using existing dungeon generator as foundation
  - Create 10 room templates as Lua data:
    - 3 rectangular rooms (small, medium, large)
    - 2 L-shaped rooms
    - 2 corridor sections
    - 1 treasure room (with chest)
    - 1 altar room (for gods)
    - 1 boss room (floor 5 only)
  - Generate floor layout: place rooms, connect with corridors
  - Place stairs (down on floors 1-4, up on floors 2-5)
  - Procedural enemy/item placement based on floor difficulty
  - Write test for generation validity

  **Must NOT do**:
  - Do not create complex branching dungeons
  - Do not add special dungeon features (traps, secret doors) yet

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Algorithm design
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (after Task 6)
  - **Blocks**: Task 17 (boss fight needs boss room)
  - **Blocked By**: Tasks 2, 6

  **References**:
  - Existing dungeon gen: `assets/scripts/core/procgen/dungeon.lua`
  - Master design doc: `/Users/joshuashin/.superset/worktrees/TheGameJamTemplate/urgood2/roguelike-master-plan/.sisyphus/plans/roguelike-prototypes-design.md` (lines 223-239 - Dungeon Structure)
  - Floor sizes from design doc:
    - Floor 1: 15x15, 5-8 enemies
    - Floor 2: 20x20, 8-12 enemies
    - Floor 3: 20x20, 10-15 enemies
    - Floor 4: 25x25, 12-18 enemies
    - Floor 5: 15x15, boss arena

  **Pathfinding Approach**:
  Since no Lua pathfinding binding exists, implement simple BFS in `descent/pathfinding.lua`:
  ```lua
  -- Simple BFS for walkability verification
  function M.can_reach(map, start, goal)
      local visited = {}
      local queue = {start}
      while #queue > 0 do
          local current = table.remove(queue, 1)
          if current.x == goal.x and current.y == goal.y then return true end
          -- Add walkable neighbors to queue
      end
      return false
  end
  ```

  **Acceptance Criteria**:
  ```lua
  -- Test in tests/test_descent_dungeon.lua:
  local Dungeon = require("descent.dungeon")
  local Pathfinding = require("descent.pathfinding")
  
  -- Generate floor 1
  local floor = Dungeon.generate(1)
  
  -- Verify floor has required elements
  assert(floor.rooms and #floor.rooms >= 5, "Floor 1 should have 5+ rooms")
  assert(floor.stairs_down ~= nil, "Floor 1 needs stairs down")
  assert(floor.player_start ~= nil, "Floor needs player start position")
  
  -- Verify floor dimensions (Floor 1 = 15x15 per design doc)
  assert(floor.width == 15, "Floor 1 width should be 15")
  assert(floor.height == 15, "Floor 1 height should be 15")
  
  -- Verify walkability using our BFS pathfinding
  local reachable = Pathfinding.can_reach(floor, floor.player_start, floor.stairs_down)
  assert(reachable == true, "Path from start to stairs must exist")
  
  print("Dungeon generation tests passed!")
  ```

  **Commit**: YES (groups with 7)
  - Message: `feat(descent): implement template-based dungeon generation`
  - Files: `assets/scripts/descent/dungeon.lua`, `assets/scripts/descent/data/room_templates.lua`, `assets/scripts/tests/test_descent_dungeon.lua`

---

### Wave 3: Core Gameplay

- [ ] 9. Implement Combat System

  **What to do**:
  - Create `descent/combat.lua` with DCSS-like formulas from design doc:
    ```lua
    -- Melee damage
    damage = weapon_base + str_modifier + species_bonus
    hit_chance = 70 + (dex * 2) - (enemy_evasion * 2)
    
    -- Ranged/Magic damage
    damage = spell_base * (1 + int * 0.05) * species_multiplier
    hit_chance = 80 + (skill * 3)
    
    -- Defense
    damage_taken = incoming - armor_value
    evasion_chance = 10 + (dex * 2) + dodge_skill
    ```
  - Attack action: Check hit, calculate damage, apply damage, trigger HitFX
  - Death handling: Remove enemy, grant XP
  - Integrate with turn system (attack ends player turn)
  - Write comprehensive tests for combat math

  **Must NOT do**:
  - Do not add critical hits yet (save for polish)
  - Do not add status effects yet (save for spell system)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Core game system with formulas
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 10, 11)
  - **Blocks**: Tasks 12, 17
  - **Blocked By**: Tasks 3, 4, 6

  **References**:
  - Formulas: `/Users/joshuashin/.superset/worktrees/TheGameJamTemplate/urgood2/roguelike-master-plan/.sisyphus/plans/roguelike-prototypes-design.md` (lines 243-270 - Combat System)
  - HitFX: `docs/api/hitfx_doc.md`
  - HitFX usage: `assets/scripts/core/hitfx.lua`
  - Existing combat patterns: `assets/scripts/combat/` (for HitFX integration pattern)

  **Combat API Contract**:
  
  ```lua
  -- Combat.calculate_melee(attacker, defender) returns:
  -- {
  --   raw_damage = number,    -- weapon_base + str + species_bonus (before armor)
  --   damage = number,        -- max(0, raw_damage - defender.armor)
  --   hit_chance = number,    -- clamped to [5, 95] (always 5% min, 95% max)
  --   hit = boolean           -- result of roll against hit_chance
  -- }
  --
  -- Formulas (from design doc lines 246-258):
  --   raw_damage = weapon_base + attacker.str + attacker.species_bonus
  --   damage = max(0, raw_damage - defender.armor)
  --   hit_chance = clamp(70 + (attacker.dex * 2) - (defender.evasion * 2), 5, 95)
  ```

  **Acceptance Criteria**:
  ```lua
  -- Test in tests/test_descent_combat.lua:
  local Combat = require("descent.combat")
  
  -- Test melee damage calculation
  -- NOTE: attacker needs dex for hit_chance calculation
  local attacker = { str = 10, dex = 12, weapon_base = 5, species_bonus = 0 }
  local defender = { armor = 3, evasion = 5 }
  
  -- Raw damage: weapon_base(5) + str(10) + species_bonus(0) = 15
  -- Final damage: max(0, 15 - armor(3)) = 12
  local result = Combat.calculate_melee(attacker, defender)
  assert(result.raw_damage == 15, "Raw damage should be 15, got " .. result.raw_damage)
  assert(result.damage == 12, "Final damage should be 12, got " .. result.damage)
  
  -- Hit chance: 70 + (attacker.dex(12) * 2) - (defender.evasion(5) * 2)
  --           = 70 + 24 - 10 = 84%
  assert(result.hit_chance == 84, "Hit chance should be 84%, got " .. result.hit_chance)
  
  -- Test armor > damage (floors at 0)
  local weak_attacker = { str = 1, dex = 10, weapon_base = 1, species_bonus = 0 }
  local heavy_defender = { armor = 10, evasion = 0 }
  local weak_result = Combat.calculate_melee(weak_attacker, heavy_defender)
  assert(weak_result.damage == 0, "Damage should floor at 0, got " .. weak_result.damage)
  
  -- Test magic damage
  local caster = { int = 15, species_multiplier = 1.2 }
  -- Expected: spell_base(10) * (1 + int(15)*0.05) * species_multiplier(1.2)
  --         = 10 * 1.75 * 1.2 = 21
  local magic_result = Combat.calculate_magic(caster, 10)  -- 10 = spell_base
  assert(magic_result.damage == 21, "Magic damage should be 21, got " .. magic_result.damage)
  
  print("Combat calculation tests passed!")
  ```

  **Commit**: YES
  - Message: `feat(descent): implement DCSS-style combat system`
  - Files: `assets/scripts/descent/combat.lua`, `assets/scripts/tests/test_descent_combat.lua`

---

- [ ] 10. Implement Item and Inventory System

  **What to do**:
  - Create `descent/items.lua` with item definitions from design doc:
    - Weapons: 8 types (dagger, short sword, long sword, axe, mace, quarterstaff, shortbow, crossbow)
    - Armor: 4 slots (body, head, hands, feet) × 3 tiers (light, medium, heavy)
    - Consumables: Potions (healing, magic, haste), Scrolls (teleport, identify)
  - Use existing inventory_grid.lua for inventory management
  - Implement equip/unequip actions
  - Implement scroll identification system:
    - Scrolls have randomized names per run (e.g., "ZLORP", "BLEEM")
    - Using scroll or Scroll of Identify reveals true name
    - Track identified scrolls in run state
  - Implement use item action (potions, scrolls)

  **Must NOT do**:
  - Do not implement inventory tetris (simple list)
  - Do not add item enchantments yet

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Data-heavy system
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 9, 11, 12)
  - **Blocks**: Tasks 13, 15
  - **Blocked By**: Task 6

  **References**:
  - Existing inventory: `assets/scripts/core/inventory_grid.lua`
  - Item data format: `assets/scripts/data/equipment.lua`
  - Master design doc: Item specifications

  **Acceptance Criteria**:
  ```lua
  -- Test in tests/test_descent_items.lua:
  local Items = require("descent.items")
  local Inventory = require("descent.inventory")
  
  -- Create player inventory
  local inv = Inventory.new()
  
  -- Create and add sword
  local sword = Items.create("short_sword")
  assert(sword.damage == 5, "Short sword damage should be 5")
  inv:add(sword)
  assert(inv:count() == 1, "Should have 1 item")
  
  -- Test scroll identification
  local scroll = Items.create("scroll_teleport")
  assert(scroll.identified == false, "New scroll should be unidentified")
  assert(scroll.display_name ~= "Scroll of Teleport", "Should show random name")
  
  scroll:identify()
  assert(scroll.identified == true, "Should be identified")
  assert(scroll.display_name == "Scroll of Teleport", "Should show real name")
  
  print("Item system tests passed!")
  ```

  **Commit**: YES (groups with 11)
  - Message: `feat(descent): implement item system with scroll identification`
  - Files: `assets/scripts/descent/items.lua`, `assets/scripts/descent/inventory.lua`, `assets/scripts/descent/data/item_definitions.lua`, `assets/scripts/tests/test_descent_items.lua`

---

- [ ] 11. Create Character Creation UI

  **What to do**:
  - Create `descent/ui/character_creation.lua`
  - Screen flow: Species selection → Background selection → Start game
  - For MVP: Only Human species and Gladiator background (show as "selected")
  - Display species stats and traits
  - Display background starting equipment and skills
  - Use existing UI DSL for layout
  - Keyboard navigation (up/down to select, enter to confirm)

  **Must NOT do**:
  - Do not implement full character customization
  - Do not add character naming

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: UI screen
  - **Skills**: `["frontend-ui-ux"]`
    - frontend-ui-ux: UI layout and interaction

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 9, 10, 12)
  - **Blocks**: None (can be skipped for testing)
  - **Blocked By**: Task 6

  **References**:
  - UI DSL: `docs/api/ui-dsl-reference.md`
  - Species/Background data: Master design doc
  - Modal pattern: Check existing game menus

  **Acceptance Criteria**:
  ```lua
  -- Test in tests/test_descent_rendering_character_creation.lua (IN-ENGINE - requires UI):
  local CharCreation = require("descent.ui.character_creation")
  
  -- Verify species data loaded
  local species = CharCreation.get_species_list()
  assert(#species >= 1, "Should have at least 1 species (Human)")
  assert(species[1].name == "Human", "First species should be Human")
  
  -- Verify background data loaded
  local backgrounds = CharCreation.get_background_list()
  assert(#backgrounds >= 1, "Should have at least 1 background (Gladiator)")
  assert(backgrounds[1].name == "Gladiator", "First background should be Gladiator")
  
  -- Verify character can be created
  local player = CharCreation.create_character("Human", "Gladiator")
  assert(player.species == "Human", "Player species should be Human")
  assert(player.background == "Gladiator", "Player background should be Gladiator")
  
  print("Character creation tests passed!")
  ```
  
  **Manual Visual Verification**:
  ```
  1. Start game, select "Descent" mode
  2. Verify: Character creation screen appears
  3. Verify: "Human" species shown with stats (HP+0, MP+0, XP 1.0x)
  4. Verify: "Gladiator" background shown with equipment (Short sword, Leather armor, 3 Throwing nets)
  5. Press Enter to confirm
  6. Verify: Game starts with player @ visible on map
  7. Take system screenshot (Cmd+Shift+4 on macOS) and save to .sisyphus/evidence/task-11-char-creation.png
  ```

  **Commit**: YES (groups with 10)
  - Message: `feat(descent): implement character creation UI`
  - Files: `assets/scripts/descent/ui/character_creation.lua`

---

- [ ] 12. Implement Enemy AI

  **What to do**:
  - Create `descent/enemy.lua` with enemy definitions from design doc (MVP: 5 enemies)
    - Rat: HP 5, DMG 2, Fast speed
    - Goblin: HP 10, DMG 4, Normal speed
    - Skeleton: HP 15, DMG 5, Undead trait
    - Orc: HP 20, DMG 7, Normal
    - Placeholder Boss: HP 50, DMG 15
  - Simple AI behavior per turn:
    1. If player adjacent: attack
    2. If player visible: move toward player (use pathfinding)
    3. Otherwise: idle
  - Integrate with turn system (enemy turn processes all enemies)
  - Speed handling: Fast enemies get 2 actions, Slow get 0.5

  **Must NOT do**:
  - Do not implement complex AI behaviors (spellcasting, fleeing)
  - Do not add enemy special abilities yet

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: AI logic
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 9, 10, 11)
  - **Blocks**: Task 17
  - **Blocked By**: Tasks 4, 9

  **References**:
  - Pathfinding: Use `descent/pathfinding.lua` (BFS implementation from Task 8)
  - AI patterns: `assets/scripts/ai/`
  - Enemy stats: `/Users/joshuashin/.superset/worktrees/TheGameJamTemplate/urgood2/roguelike-master-plan/.sisyphus/plans/roguelike-prototypes-design.md` (lines 347-362 - Enemies table)

  **Acceptance Criteria**:
  ```lua
  -- Test in tests/test_descent_enemy.lua:
  local Enemy = require("descent.enemy")
  local Map = require("descent.map")
  
  -- Create test scenario
  local map = Map.new(10, 10)
  local enemy = Enemy.create("goblin", 5, 5)
  local player_pos = {x = 7, y = 5}
  
  -- Test AI decision: player visible, should move toward
  local action = enemy:decide_action(map, player_pos)
  assert(action.type == "move", "Should decide to move toward player")
  assert(action.target.x == 6, "Should move toward player (x)")
  
  -- Test AI decision: player adjacent, should attack
  player_pos = {x = 6, y = 5}
  action = enemy:decide_action(map, player_pos)
  assert(action.type == "attack", "Should attack adjacent player")
  
  print("Enemy AI tests passed!")
  ```

  **Commit**: YES
  - Message: `feat(descent): implement enemy AI with pathfinding`
  - Files: `assets/scripts/descent/enemy.lua`, `assets/scripts/descent/data/enemy_definitions.lua`, `assets/scripts/tests/test_descent_enemy.lua`

---

### Wave 4: Content & Polish

- [ ] 13. Implement God System

  **What to do**:
  - Create `descent/gods.lua` with god definitions (MVP: Trog only)
    - Trog: Rage god, anti-magic
    - Piety: Binary (worshipping or not)
    - Ability 1: Berserk (2x damage, 1.5x speed, 10 turns)
    - Ability 2: Trog's Hand (regen + magic resist, 20 turns)
    - Conduct: No spellcasting
  - Create altar interaction: Prompt to worship god
  - Create god abilities UI (keybind to activate)
  - Track piety state and conduct violations
  - Conduct violation = lose god favor

  **Must NOT do**:
  - Do not implement piety levels (keep binary)
  - Do not add god wrath mechanics

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Game system
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 14, 15, 16)
  - **Blocks**: Task 17 (boss may interact with god)
  - **Blocked By**: Task 10 (needs status effect system)

  **References**:
  - God definitions: `/Users/joshuashin/.superset/worktrees/TheGameJamTemplate/urgood2/roguelike-master-plan/.sisyphus/plans/roguelike-prototypes-design.md` (lines 209-221 - Gods table)
  - Trog specifics: Ability 1 = Berserk (2x damage, 1.5x speed, 10 turns), Ability 2 = Trog's Hand (regen + magic resist, 20 turns), Conduct = No spellcasting
  - Status effects: Implement in `descent/status_effects.lua` module

  **Acceptance Criteria**:
  ```lua
  -- Test in tests/test_descent_gods.lua:
  local Gods = require("descent.gods")
  local Player = require("descent.player")
  
  -- Create player with no god
  local player = Player.new()
  assert(player.god == nil, "Should start with no god")
  
  -- Worship Trog
  Gods.worship(player, "trog")
  assert(player.god == "trog", "Should worship Trog")
  
  -- Use Berserk ability
  local berserk_result = Gods.use_ability(player, "trog", 1)
  assert(player.status.berserk == true, "Should have berserk status")
  assert(player.damage_multiplier == 2, "Should have 2x damage")
  
  -- Violate conduct (cast spell)
  local cast_result = Gods.check_conduct(player, "cast_spell")
  assert(cast_result.violation == true, "Casting spell violates Trog conduct")
  
  print("God system tests passed!")
  ```

  **Commit**: YES (groups with 14)
  - Message: `feat(descent): implement god system with Trog`
  - Files: `assets/scripts/descent/gods.lua`, `assets/scripts/descent/data/god_definitions.lua`, `assets/scripts/tests/test_descent_gods.lua`

---

- [ ] 14. Implement Spell System

  **What to do**:
  - Create `descent/spells.lua` with spell definitions (MVP: 3 spells)
    - Freeze (Ice): 5 damage + slow for 3 turns, 3 MP
    - Flame Dart (Fire): 4 damage ranged 6, 2 MP
    - Blink (Translocation): Random teleport within 5 tiles, 4 MP
  - Create spell casting action (checks MP, applies effect)
  - Create spell targeting UI (for Freeze and Flame Dart)
  - Integrate with turn system (casting ends turn)
  - Track known spells per player

  **Must NOT do**:
  - Do not add spell failure chance yet
  - Do not add spell schools/skillup

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Game system
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 13, 15, 16)
  - **Blocks**: Task 16 (level-up grants spells)
  - **Blocked By**: Task 9 (needs combat system)

  **References**:
  - Spell definitions: `/Users/joshuashin/.superset/worktrees/TheGameJamTemplate/urgood2/roguelike-master-plan/.sisyphus/plans/roguelike-prototypes-design.md` (lines 289-303 - Spells table)
  - MVP Spells: Freeze (Ice, 3 MP, 5 dmg + slow), Flame Dart (Fire, 2 MP, 4 dmg ranged), Blink (Translocation, 4 MP, random teleport)
  - Targeting patterns: `assets/scripts/combat/` for existing targeting examples

  **Acceptance Criteria**:
  ```lua
  -- Test in tests/test_descent_spells.lua:
  local Spells = require("descent.spells")
  local Player = require("descent.player")
  
  -- Create player with MP
  local player = Player.new()
  player.mp = 10
  player.known_spells = {"freeze", "flame_dart", "blink"}
  
  -- Cast freeze
  local target = {x = 5, y = 5}
  local result = Spells.cast(player, "freeze", target)
  assert(result.success == true, "Should cast successfully")
  assert(result.damage == 5, "Should deal 5 damage")
  assert(result.status == "slow", "Should apply slow")
  assert(player.mp == 7, "Should cost 3 MP")
  
  -- Try to cast with insufficient MP
  player.mp = 1
  result = Spells.cast(player, "freeze", target)
  assert(result.success == false, "Should fail with low MP")
  assert(result.reason == "insufficient_mp", "Should explain failure")
  
  print("Spell system tests passed!")
  ```

  **Commit**: YES (groups with 13)
  - Message: `feat(descent): implement spell system with 3 spells`
  - Files: `assets/scripts/descent/spells.lua`, `assets/scripts/descent/data/spell_definitions.lua`, `assets/scripts/tests/test_descent_spells.lua`

---

- [ ] 15. Implement Shop System

  **What to do**:
  - Create `descent/shop.lua`
  - Generate random shop stock (5 items per shop)
  - Item pool based on floor level
  - Reroll mechanic: 2g base, +1g per reroll this visit
  - Purchase: Subtract gold, add item to inventory
  - No sell-back (simplify)
  - Create shop UI with item list and prices

  **Must NOT do**:
  - Do not add sell-back
  - Do not add shop theft mechanics

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: UI-heavy
  - **Skills**: `["frontend-ui-ux"]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 13, 14, 16)
  - **Blocks**: None
  - **Blocked By**: Task 10 (needs item system)

  **References**:
  - Shop mechanics: Master design doc
  - UI patterns: Existing shop UIs in game

  **Acceptance Criteria**:
  ```lua
  -- Test in tests/test_descent_shop.lua:
  local Shop = require("descent.shop")
  local Player = require("descent.player")
  
  -- Create shop for floor 1
  local shop = Shop.new(1)
  assert(#shop.items == 5, "Shop should have 5 items")
  
  -- Purchase item
  local player = Player.new()
  player.gold = 100
  local item = shop.items[1]
  local result = shop:purchase(player, 1)
  assert(result.success == true, "Should purchase")
  assert(player.gold == 100 - item.price, "Should deduct gold")
  assert(#shop.items == 4, "Shop should have 4 items left")
  
  -- Reroll
  local old_items = shop.items
  result = shop:reroll(player)
  assert(result.success == true, "Should reroll")
  assert(player.gold == 100 - item.price - 2, "Should cost 2g")
  
  print("Shop system tests passed!")
  ```

  **Commit**: YES (groups with 16)
  - Message: `feat(descent): implement shop system with reroll`
  - Files: `assets/scripts/descent/shop.lua`, `assets/scripts/descent/ui/shop_ui.lua`, `assets/scripts/tests/test_descent_shop.lua`

---

- [ ] 16. Implement Level-Up System

  **What to do**:
  - Create `descent/leveling.lua`
  - XP formula from design doc: `XP_for_Level_N = 10 * N * Species_XP_Mod`
  - Level cap: 10
  - Per level gain:
    - +1 to chosen stat (STR, DEX, or INT)
    - +15% base HP
    - +10% base MP
  - At levels 3, 6, 9: Spell choice (pick 1 of 3 random)
  - Create level-up UI: Modal card selection for spell choice
  - Create stat selection UI

  **Must NOT do**:
  - Do not add skill points
  - Do not add ability unlocks beyond spells

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: UI-focused
  - **Skills**: `["frontend-ui-ux"]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 13, 14, 15)
  - **Blocks**: None
  - **Blocked By**: Task 14 (needs spell system for spell selection)

  **References**:
  - XP formula: Master design doc
  - Spell selection UI: Modal card pattern
  - UI DSL: `docs/api/ui-dsl-reference.md`

  **Acceptance Criteria**:
  ```lua
  -- Test in tests/test_descent_leveling.lua:
  local Leveling = require("descent.leveling")
  local Player = require("descent.player")
  
  -- Create level 1 player
  local player = Player.new()
  assert(player.level == 1, "Should start at level 1")
  
  -- Check XP requirement (Human species, 1.0x mod)
  local xp_needed = Leveling.xp_for_level(2)
  assert(xp_needed == 20, "Level 2 needs 20 XP (10 * 2 * 1.0)")
  
  -- Grant XP and level up
  player.xp = 20
  local levelup = Leveling.check_levelup(player)
  assert(levelup.ready == true, "Should be ready to level up")
  
  -- Apply level up
  Leveling.apply_levelup(player, {stat = "str"})
  assert(player.level == 2, "Should be level 2")
  assert(player.str == 11, "STR should increase by 1") -- assuming base 10
  
  print("Level-up system tests passed!")
  ```

  **Manual Visual Verification**:
  ```
  1. Use debug command to grant XP: descent.debug.grant_xp(30)
  2. Trigger level up to level 3
  3. Verify: Modal appears with 3 spell cards
  4. Select a spell with keyboard
  5. Verify: Player.known_spells contains new spell
  6. Take system screenshot (Cmd+Shift+4 on macOS) and save to .sisyphus/evidence/task-16-spell-select.png
  ```

  **Commit**: YES (groups with 15)
  - Message: `feat(descent): implement level-up system with spell selection`
  - Files: `assets/scripts/descent/leveling.lua`, `assets/scripts/descent/ui/levelup_ui.lua`, `assets/scripts/tests/test_descent_leveling.lua`

---

- [ ] 17. Implement Boss Fight

  **What to do**:
  - Create `descent/boss.lua` for Dungeon Lord boss
  - Boss stats from design doc: 100 HP, 20 DMG, Slow
  - Phase system:
    - Phase 1 (100-50% HP): Melee only
    - Phase 2 (50-25% HP): Summons 2 enemies every 5 turns
    - Phase 3 (25-0% HP): Berserk (+50% damage)
  - Boss room is special: No exploration, just boss arena
  - Create boss healthbar UI
  - On boss death: Transition to victory state

  **Must NOT do**:
  - Do not add complex boss patterns
  - Do not add cutscenes

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Game design implementation
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: NO (depends on many systems)
  - **Parallel Group**: Sequential (after Wave 3)
  - **Blocks**: Task 18
  - **Blocked By**: Tasks 8, 9, 12

  **References**:
  - Boss design: Master design doc
  - Summoning: Use enemy spawn system

  **Acceptance Criteria**:
  ```lua
  -- Test in tests/test_descent_boss.lua:
  local Boss = require("descent.boss")
  
  -- Create boss
  local boss = Boss.create()
  assert(boss.hp == 100, "Boss should have 100 HP")
  assert(boss.phase == 1, "Should start in phase 1")
  
  -- Damage to phase 2
  boss:take_damage(55)
  assert(boss.hp == 45, "Should have 45 HP")
  assert(boss.phase == 2, "Should transition to phase 2")
  
  -- Check summon behavior in phase 2
  local actions = boss:get_actions(5) -- turn 5
  local summon_action = false
  for _, action in ipairs(actions) do
    if action.type == "summon" then summon_action = true end
  end
  assert(summon_action, "Should summon in phase 2")
  
  -- Damage to phase 3
  boss:take_damage(25)
  assert(boss.phase == 3, "Should transition to phase 3")
  assert(boss.damage_multiplier == 1.5, "Should have +50% damage")
  
  print("Boss system tests passed!")
  ```

  **Commit**: YES
  - Message: `feat(descent): implement Dungeon Lord boss with phases`
  - Files: `assets/scripts/descent/boss.lua`, `assets/scripts/descent/ui/boss_healthbar.lua`, `assets/scripts/tests/test_descent_boss.lua`

---

- [ ] 18. Implement Victory and Death Screens

  **What to do**:
  - Create `descent/ui/victory_screen.lua`
    - Display: "Victory!", run stats (time, kills, floor reached, gold)
    - Option: Return to main menu
  - Create `descent/ui/death_screen.lua`
    - Display: "You died!", cause of death, run stats
    - Option: Try again (new run), Return to main menu
  - Create `descent/run_stats.lua` to track run statistics
  - Integrate with turn manager (VICTORY and GAME_OVER states)

  **Must NOT do**:
  - Do not add high score persistence
  - Do not add death messages variety (single generic message)

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: UI screens
  - **Skills**: `["frontend-ui-ux"]`

  **Parallelization**:
  - **Can Run In Parallel**: NO (final integration)
  - **Parallel Group**: Sequential (after Task 17)
  - **Blocks**: Task 19
  - **Blocked By**: Task 17

  **References**:
  - UI patterns: Existing game over screens
  - Stats tracking: Simple Lua table

  **Acceptance Criteria**:
  ```lua
  -- Test in tests/test_descent_end_screens.lua:
  local VictoryScreen = require("descent.ui.victory_screen")
  local DeathScreen = require("descent.ui.death_screen")
  local RunStats = require("descent.run_stats")
  
  -- Test death screen data
  local stats = RunStats.new()
  stats:record_kill("goblin")
  stats:record_floor(3)
  local death_data = DeathScreen.prepare_data(stats, "killed by an Orc")
  assert(death_data.cause == "killed by an Orc", "Should show cause of death")
  assert(death_data.floor == 3, "Should show floor reached")
  
  -- Test victory screen data
  local victory_data = VictoryScreen.prepare_data(stats)
  assert(victory_data.kills >= 1, "Should show total kills")
  
  print("End screen tests passed!")
  ```

  **Manual Death Screen Verification**:
  ```
  1. Start descent mode
  2. Use debug: descent.debug.set_player_hp(1)
  3. Get hit by enemy
  4. Verify: Death screen appears with "You died!"
  5. Verify: Shows cause of death (enemy name)
  6. Verify: Shows run stats (floor, kills, time)
  7. Press key for "Try Again"
  8. Verify: New game starts
  9. Take system screenshot (Cmd+Shift+4 on macOS) and save to .sisyphus/evidence/task-18-death-screen.png
  ```

  **Manual Victory Screen Verification**:
  ```
  1. Use debug: descent.debug.skip_to_floor(5)
  2. Use debug: descent.debug.kill_boss()
  3. Verify: Victory screen appears with "Victory!"
  4. Verify: Shows run stats
  5. Take system screenshot (Cmd+Shift+4 on macOS) and save to .sisyphus/evidence/task-18-victory-screen.png
  ```

  **Commit**: YES
  - Message: `feat(descent): implement victory and death screens`
  - Files: `assets/scripts/descent/ui/victory_screen.lua`, `assets/scripts/descent/ui/death_screen.lua`, `assets/scripts/descent/run_stats.lua`

---

- [ ] 19. Full MVP Integration and Polish

  **What to do**:
  - Add `GAMESTATE.DESCENT` to the game state enum
  - Create `initDescent()` function for Descent mode initialization
  - Add "Descent" button to main menu (or replace "Start Game")
  - Integrate all systems into cohesive game flow:
    1. Main menu → Descent button → Character creation → Game loop → Victory/Death → Main menu
  - Create game entry point in `descent/init.lua`
  - Test complete run (start to victory)
  - Time calibration: Ensure 15-20 minute run time
    - Adjust enemy HP, floor sizes, XP rates as needed
  - Add basic sound effects (existing engine sounds)
  - Final test: 5 complete runs without crashes

  **Must NOT do**:
  - Do not add tutorial
  - Do not add options menu

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Integration work
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: NO (final integration)
  - **Parallel Group**: Sequential (after Task 18)
  - **Blocks**: Tasks 20-24 (content expansion)
  - **Blocked By**: Task 18

  **References**:
  - All previous tasks
  - Game state management: `assets/scripts/core/main.lua:45-48` (GAMESTATE enum definition)
  - State change function: `assets/scripts/core/main.lua:1091-1106` (changeGameState pattern)
  - Main menu buttons: `assets/scripts/core/main.lua:268-310` (MainMenuButtons.setButtons pattern)
  - Main menu module: `assets/scripts/ui/main_menu_buttons.lua`

  **Descent Mode Entry Point Pattern**:
  
  To add Descent as a new game mode, follow this pattern from `assets/scripts/core/main.lua`:
  
  1. **Add GAMESTATE enum value** (line 45-48):
     ```lua
     GAMESTATE = {
         MAIN_MENU = 0,
         IN_GAME = 1,
         DESCENT = 2  -- ADD THIS
     }
     ```
  
  2. **Create initDescent function** (similar to `initMainGame` at line 1048):
     ```lua
     function initDescent()
         log_debug("[initDescent] Starting Descent mode...")
         record_telemetry_once("scene_descent", "scene_enter", { scene = "descent" })
         
         -- Initialize descent module
         local Descent = require("descent.init")
         Descent.start()
     end
     ```
  
  3. **Update changeGameState** (line 1091-1106):
     ```lua
     function changeGameState(newState)
         if currentGameState == GAMESTATE.MAIN_MENU and newState ~= GAMESTATE.MAIN_MENU then
             clearMainMenu()
         end
     
         if newState == GAMESTATE.MAIN_MENU then
             initMainMenu()
         elseif newState == GAMESTATE.IN_GAME then
             initMainGame()
         elseif newState == GAMESTATE.DESCENT then  -- ADD THIS
             initDescent()
         else
             error("Invalid game state: " .. tostring(newState))
         end
         currentGameState = newState
         globals.currentGameState = newState
     end
     ```
  
  4. **Add main menu button** (in initMainMenu, around line 268):
     ```lua
     MainMenuButtons.setButtons({
         {
             label = "Descent",  -- Can use localization later
             onClick = function()
                 record_telemetry("descent_clicked", { scene = "main_menu" })
                 changeGameState(GAMESTATE.DESCENT)
             end
         },
         -- ... other buttons
     })
     ```
  
  5. **descent/init.lua entry point**:
     ```lua
     local M = {}
     
     function M.start()
         -- Initialize turn manager
         local TurnManager = require("descent.turn_manager")
         M.turn_manager = TurnManager.new()
         
         -- Set up input context
         local DescentInput = require("descent.input")
         DescentInput.setup_context()
         input.set_context("roguelike")
         
         -- Generate first floor
         local Dungeon = require("descent.dungeon")
         M.current_floor = Dungeon.generate(1)
         
         -- Show character creation
         local CharCreate = require("descent.ui.character_creation")
         CharCreate.show(function(selection)
             M.start_run(selection)
         end)
     end
     
     function M.start_run(player_config)
         -- Initialize player
         local Player = require("descent.player")
         M.player = Player.new(player_config)
         
         -- Start game loop
         M.turn_manager:start()
     end
     
     return M
     ```
  
  6. **Per-Frame Update Integration** (CRITICAL for gameplay):
      
      The engine's main loop is in `main.lua:1340-1405` (function `main.update(dt)`).
      
      **CHOSEN APPROACH: Timer-based updates (NOT main.update modification)**
      
      Since Descent is turn-based, per-frame updates are minimal. We use the **timer system**:
      - Input polling happens through the input context (action bindings handle this)
      - Turn processing is event-driven, not per-frame
      - Rendering uses a timer callback that runs every frame
      - Animations use the timer system (already exists)
      
      This approach is chosen because:
      1. Avoids modifying core `main.update` logic (less integration risk)
      2. Turn-based games don't need 60fps update logic
      3. Timer callbacks already support frame-by-frame execution
      4. Easier cleanup (just clear the timer group)
      
      **Implementation in descent/init.lua**:
      
      **Timer API Reference** (verified from `/assets/scripts/core/timer.lua:65-86`):
      - `timer.run(action, after, tag, group)` - Runs `action` every frame; `after` callback when stopped (or nil)
      - `timer.run_every_render_frame(action, after, tag, group)` - Same but explicitly for render-safe operations
      - `timer.kill_group(group)` - Kills ALL timers in the specified group (line 504)
      
      ```lua
      function M.start_run(player_config)
          M.is_active = true
          
          -- Render timer: runs every render frame to queue draw commands
          -- timer.run_every_render_frame(action, after_callback, tag, group)
          -- action = function to call every frame
          -- after = nil (infinite loop - never calls completion callback)
          -- tag = unique timer identifier
          -- group = "descent" (for easy cleanup)
          timer.run_every_render_frame(function()
              if M.is_active then
                  M.render()  -- Queue draw commands for map, entities, UI
                  M.turn_manager:update()  -- Check for input, process turns
              end
          end, nil, "descent_render", "descent")
          
          -- Turn manager drives the game loop
          M.turn_manager:start()
      end
      
      function M.stop()
          M.is_active = false
          timer.kill_group("descent")  -- Clean up ALL descent timers (NOT timer.clear_group!)
          input.set_context("gameplay")  -- Restore default context
          -- Any entities created for descent are cleaned up here
      end
      ```
      
      **Input Processing Flow** (no main.update modification needed):
      ```lua
      -- In descent/turn_manager.lua, during PLAYER_TURN state:
      function TurnManager:check_input()
          if input.action_pressed("move_up") then
              self:player_move(0, -1)
          elseif input.action_pressed("move_down") then
              self:player_move(0, 1)
          -- ... etc
          end
      end
      
      -- This is called by the render timer callback:
      -- timer.run -> M.render() -> M.turn_manager:update() -> check_input()
      ```
  
  7. **Cleanup on Exit** (returning to main menu):
     ```lua
     -- Add to changeGameState:
     if currentGameState == GAMESTATE.DESCENT and newState ~= GAMESTATE.DESCENT then
         local Descent = require("descent.init")
         Descent.stop()  -- Clean up descent state
     end
     ```

  **Acceptance Criteria**:
  **Full playthrough verification** (manual):
  ```
  1. Start game (./build/raylib-cpp-cmake-template)
  2. Click "Descent" button in main menu
  3. Create character (Human + Gladiator)
  4. Complete floors 1-5 (use stopwatch to track time)
  5. Defeat boss
  6. Verify: Victory screen shows
  7. Verify: Total time between 15-20 minutes
  8. Take system screenshot and save to .sisyphus/evidence/task-19-full-run.png
  ```

  **Stability test** (manual - 5 runs):
  ```
  Run 5 complete playthroughs. For each:
  1. Start game, enter Descent mode
  2. Play through all 5 floors
  3. Complete run (victory or death)
  4. Note any crashes or errors in console
  5. Return to main menu
  
  Acceptance: All 5 runs complete without crashes.
  Record issues in .sisyphus/evidence/task-19-stability-notes.txt
  ```
  
  **Timed run verification** (with stopwatch):
  ```
  1. Start system stopwatch (or use `time` command around manual play)
  2. Play through entire run optimally
  3. Verify completion time: 15-20 minutes target
  
  If too short: Increase floor sizes or enemy counts
  If too long: Reduce enemy HP or floor dimensions
  Document calibration changes in commit message
  ```

  **Commit**: YES
  - Message: `feat(descent): complete MVP integration`
  - Files: `assets/scripts/descent/init.lua`, main menu integration

---

### Wave 5: Content Expansion (Post-MVP)

- [ ] 20. Add Remaining Species (3 more)

  **What to do**:
  - Add Minotaur: HP+2, MP-1, 1.1x XP, Horn Attack trait
  - Add Deep Elf: HP-1, MP+2, 0.8x XP, Magic Affinity trait
  - Add Troll: HP+4, MP-2, 1.4x XP, Regeneration + Claws traits
  - Update character creation to show all species
  - Test each species for balance

  **Commit**: YES
  - Message: `feat(descent): add Minotaur, Deep Elf, Troll species`

---

- [ ] 21. Add Remaining Backgrounds (3 more)

  **What to do**:
  - Add Monk: Quarterstaff, Robe, Orb; Fighting+2, Dodging+2, Invocations+1
  - Add Ice Elementalist: Dagger, Robe, Book of Frost; Spellcasting+2, Ice Magic+3
  - Add Artificer: Club, Leather, Wands; Evocations+3, Fighting+1
  - Update character creation to show all backgrounds

  **Commit**: YES
  - Message: `feat(descent): add Monk, Ice Elementalist, Artificer backgrounds`

---

- [ ] 22. Add Remaining Gods (4 more)

  **What to do**:
  - Add Vehumet: MP on Kill, Spell Range+
  - Add Makhleb: HP on Kill, Destruction bolt
  - Add Gozag: Potion Petition (50g), Bribe (100g)
  - Add Elyvilon: Purification, Divine Vigor; no attacking pacified
  - Update altar system to use all 5 gods (3 random per run)

  **Commit**: YES
  - Message: `feat(descent): add Vehumet, Makhleb, Gozag, Elyvilon gods`

---

- [ ] 23. Add Remaining Spells (9 more)

  **What to do**:
  - Ice: Ice Bolt (12 dmg ranged), Frozen Armor (+5 AC)
  - Fire: Fireball (15 dmg AoE), Inner Flame (explode on death)
  - Other: Haste (2x speed), Regeneration (1 HP/turn), Pain (8 dmg ignores armor), Confuse (random move), Invisibility
  - Add spell selection pool for level-up

  **Commit**: YES
  - Message: `feat(descent): add remaining 9 spells`

---

- [ ] 24. Add Remaining Enemies (10 more)

  **What to do**:
  - Add: Snake, Imp, Ogre, Wizard, Troll (enemy), Wraith, Demon, Knight, Orc Warlord (miniboss)
  - Update floor enemy pools
  - Implement special abilities per design doc

  **Commit**: YES
  - Message: `feat(descent): add remaining 10 enemy types`

---

## Commit Strategy

| After Task | Message | Files | Pre-commit |
|------------|---------|-------|------------|
| 1 | `feat(descent): copy dungeon_mode tileset` | assets/graphics/dungeon_mode/* | n/a |
| 2 | `feat(descent): create module structure` | assets/scripts/descent/* | n/a |
| 3 | `feat(descent): setup test infrastructure` | assets/scripts/tests/test_descent_*.lua | n/a |
| 4+5 | `feat(descent): implement turn system and FOV bindings` | turn_manager.lua, fov.lua, C++ | tests pass |
| 6 | `feat(descent): implement map rendering` | map.lua | tests pass |
| 7+8 | `feat(descent): add input context and dungeon gen` | input.lua, dungeon.lua | tests pass |
| 9 | `feat(descent): implement combat system` | combat.lua | tests pass |
| 10+11 | `feat(descent): implement items and character creation` | items.lua, UI | tests pass |
| 12 | `feat(descent): implement enemy AI` | enemy.lua | tests pass |
| 13+14 | `feat(descent): implement gods and spells` | gods.lua, spells.lua | tests pass |
| 15+16 | `feat(descent): implement shop and leveling` | shop.lua, leveling.lua | tests pass |
| 17 | `feat(descent): implement boss fight` | boss.lua | tests pass |
| 18 | `feat(descent): implement victory/death screens` | UI files | tests pass |
| 19 | `feat(descent): complete MVP integration` | init.lua | full run works |
| 20-24 | `feat(descent): add full content` | data files | tests pass |

---

## Success Criteria

### Final Verification Commands

```bash
# Build and run game
just build-debug && ./build/raylib-cpp-cmake-template
```

**Run all descent tests (in Lua console)**:
```lua
-- After game starts, open Lua console (~ key or configured)
local t = require("tests.test_runner")
t.set_filter("descent")
local results = t.run()
-- Expected: All tests pass
```

**Timed full run
time ./build/raylib-cpp-cmake-template --mode descent --autoplay
# Expected: Completes in 15-20 minutes
```

### Final Checklist
- [ ] All "Must Have" present
- [ ] All "Must NOT Have" absent
- [ ] All tests pass
- [ ] 5 complete runs without crashes
- [ ] Run time within 15-20 minutes
- [ ] Character creation works (all species/backgrounds)
- [ ] Combat feels responsive (instant + HitFX)
- [ ] FOV reveals/hides correctly
- [ ] Boss fight has all 3 phases
- [ ] Victory/death screens display correct stats
