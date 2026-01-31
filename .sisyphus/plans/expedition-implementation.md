# Expedition Implementation Plan (Game #3)

## TL;DR

> **Quick Summary**: Implement "Expedition", an FTL-style event-driven roguelike with 3-person crew, branching map navigation, skill-check events, and resource management. Target: 15-20 minute sessions, win by reaching destination boss.
> 
> **Deliverables**: 
> - Fully playable vertical slice with 30 events
> - Self-contained Lua module at `assets/scripts/expedition/`
> - Sprite mapping to existing `assets/images/dungeon_tiles/dungeon_mode/` tiles
> - Lua test suite for all game logic
> - Map, event, and crew UI screens
> 
> **Estimated Effort**: Large (~3-4 weeks for vertical slice)
> **Parallel Execution**: YES - 3 waves (Foundation → Systems → Polish)
> **Critical Path**: Asset Setup → Game State → Map System → Event System → UI Integration

---

## Context

### Original Request
Create a detailed implementation plan for Game #3 "Expedition" from the roguelike prototypes master design document.

### Interview Summary
**Key Decisions Made**:
- **Role swapping**: Removed - Fighter/Medic/Engineer are fixed identities
- **Blue options**: Skill-gated event options (e.g., "Engineer skill 4+ can bypass trap")
- **Visual style**: 8x8 dungeon_mode tileset sprites (~50-60 needed)
- **Probability display**: Show exact percentages (e.g., "[Fight] (80% success)")
- **Map structure**: Linear with branches (FTL-style), see 2 jumps ahead
- **Crew HP**: 3 HP per crew, incapacitated at 0 (can't use skills)
- **Skill progression**: Upgrade nodes only (+1 skill), max skill 5 = 100% success
- **Final boss**: Pass 2 of 3 skill checks (Fight + Tech + Medical)

**Research Findings**:
- Test runner at `assets/scripts/tests/test_runner.lua` with BDD-style describe/it/expect
- UI DSL at `docs/api/ui_helper_reference.md` with dsl.* helpers
- Signal system at `assets/scripts/external/hump/signal.lua` (HUMP library)
- Signal groups at `assets/scripts/core/signal_group.lua`
- Constants pattern in `assets/scripts/core/constants.lua`
- Dungeon sprites at `assets/images/dungeon_tiles/dungeon_mode/` (256 8x8 sprites, already in repo)
- Main menu at `assets/scripts/ui/main_menu_buttons.lua` (uses `MainMenuButtons.setButtons()` pattern)

### Metis Review
**Identified Gaps (addressed)**:
- Starting resources: Using master plan values (Fuel 25, Supplies 10, Scrap 5, Credits 20)
- Skill progression: Upgrade nodes give +1 skill (max 5)
- Event repeatability: Events can repeat across nodes
- Map seeding: Use seeded RNG for reproducibility
- Incapacitation recovery: Repair/heal events restore HP

---

## Work Objectives

### Core Objective
Implement a playable vertical slice of Expedition that demonstrates the full game loop: crew management, map navigation with branching paths, event resolution with skill checks, resource management, and victory/defeat conditions.

### Concrete Deliverables
1. Sprites used directly from `assets/images/dungeon_tiles/dungeon_mode/` (256 files already in repo)
2. `assets/scripts/expedition/` - Complete Lua game module
3. `assets/scripts/expedition/tests/` - Lua test suite
4. Working game loop from start to victory/defeat

### Definition of Done
- [ ] Can start new Expedition run from game menu
- [ ] Map displays with branching paths, node types visible
- [ ] Can navigate map by selecting adjacent nodes
- [ ] Events display with options and success percentages
- [ ] Skill checks resolve correctly (80% at skill 3)
- [ ] Resources track correctly (fuel decrements on travel)
- [ ] Blue options appear only when skill threshold met
- [ ] Victory screen on boss defeat, defeat screen on fuel=0 or all incapacitated
- [ ] All 30 events from master plan implemented
- [ ] Session completes in 15-20 minutes

### Must Have
- All 30 events from master plan with exact outcomes
- 3 crew members with HP (3 each) and skills (starting 3, max 5)
- 4 resources: Fuel (25/30), Supplies (10/20), Scrap (5/50), Credits (20/100)
- Branching map with 18-22 nodes
- Node type distribution per master plan
- Skill check formula: Success = Skill × 20% + 20%
- Blue options gated by skill level
- Seeded RNG for reproducible runs

### Must NOT Have (Guardrails)

**Scope Boundaries (from master plan):**
- No ship systems or ship management
- No real-time combat or animations
- No crew recruitment or party changes
- No meta-progression or unlockables
- No save/load within runs
- No procedurally generated event text
- No difficulty modes

**Implementation Guardrails:**
- No custom UI primitives (use dsl.* only)
- No C++ changes (Lua-only implementation)
- No procedural event modifiers
- No resource types beyond the 4 specified
- Menu integration allowed: May add button to `assets/scripts/ui/main_menu_buttons.lua` via `MainMenuButtons.setButtons()`

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: YES - `assets/scripts/tests/test_runner.lua`
- **User wants tests**: Lua tests for game logic
- **Framework**: BDD-style (describe/it/expect)

### Lua Test Approach

Each game system has corresponding test file in `assets/scripts/expedition/tests/`:

**Test Framework**: Uses `tests.test_runner` with `t.describe/t.it/t.expect` pattern.

**Available Matchers** (from `assets/scripts/tests/test_runner.lua`):
- `t.expect(value).to_be(expected)` - strict equality
- `t.expect(value).to_equal(expected)` - deep table equality
- `t.expect(value).to_contain(expected)` - string/table containment
- `t.expect(value).to_be_truthy()` - truthy check (not nil, not false)
- `t.expect(value).to_be_falsy()` - falsy check (nil or false)
- `t.expect(fn).to_throw(pattern?)` - error check
- `t.expect(value).to_be_nil()` - nil check
- `t.expect(value).to_be_type(type)` - type check
- `t.expect(value).never().to_*()` - negation

**Expressing Range/Comparison Tests** (NO built-in matchers for these):
```lua
-- "to_be_between(min, max)" → use explicit assertion
local successes = 780
t.expect(successes >= 750 and successes <= 850).to_be(true)
-- OR: t.expect(successes >= 750).to_be(true); t.expect(successes <= 850).to_be(true)

-- "to_be_at_least(n)" → use explicit comparison
t.expect(count >= 18).to_be(true)

-- "to_be_at_most(n)" → use explicit comparison
t.expect(skill <= 5).to_be(true)

-- "to_not_be(nil)" / "to_not_equal" → use .never()
t.expect(value).never().to_be_nil()
```

**Test Structure:**
```lua
-- assets/scripts/expedition/tests/test_skill_checks.lua
local t = require("tests.test_runner")
local SkillCheck = require("expedition.systems.skill_check")
local ExpeditionRNG = require("expedition.systems.rng")

t.describe("Skill Check System", function()
    t.it("succeeds ~80% at skill 3 over 1000 trials", function()
        local rng = ExpeditionRNG.new(12345)
        local successes = 0
        for i = 1, 1000 do
            if SkillCheck.check(3, rng) then successes = successes + 1 end
        end
        -- Range check: 80% ± 5% = [750, 850]
        t.expect(successes >= 750 and successes <= 850).to_be(true)
    end)
    
    t.it("always succeeds at skill 5", function()
        local rng = ExpeditionRNG.new(99999)
        for i = 1, 100 do
            t.expect(SkillCheck.check(5, rng)).to_be(true)
        end
    end)
end)

-- Run tests
t.run()
```

**Running Tests:**
```lua
-- From game console or test script:
local TestRunner = require("tests.test_runner")
TestRunner.run_directory("assets/scripts/expedition/tests")
```

**Test Coverage Required:**
- Crew system: HP, skills, incapacitation
- Resource system: Consumption, caps, edge cases
- Skill checks: Probability distribution
- Event system: Outcome resolution, blue options
- Map system: Generation, connectivity, node types

### Manual Verification (UI only)

UI elements verified via interactive testing:
```
1. Launch game, navigate to Expedition
2. Verify map renders all nodes
3. Click adjacent node → verify navigation
4. Verify event text displays
5. Verify percentages shown on options
6. Complete full run (15-20 min target)
```

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately) - Foundation:
├── Task 1: Asset Setup (copy sprites, verify atlas)
├── Task 2: Module Structure (folder scaffolding)
└── Task 3: Constants & Data Tables (events, node types)

Wave 2 (After Wave 1) - Core Systems:
├── Task 4: Crew System (HP, skills)
├── Task 5: Resource System (fuel, supplies, scrap, credits)
├── Task 6: Skill Check System (probability, blue options)
├── Task 7: Map Generation (graph, node placement)
└── Task 8: Event System (resolution, outcomes)

Wave 3 (After Wave 2) - Integration:
├── Task 9: Game State Machine (screens, transitions)
├── Task 10: Map UI (node display, navigation)
├── Task 11: Event UI (text, options, outcomes)
├── Task 12: HUD (crew status, resources)
└── Task 13: Victory/Defeat Screens

Wave 4 (After Wave 3) - Polish:
├── Task 14: All 30 Events Data Entry
├── Task 15: Balance Testing (session timing)
└── Task 16: Full Test Suite & Bug Fixes
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 10, 11, 12 | 2, 3 |
| 2 | None | 4, 5, 6, 7, 8 | 1, 3 |
| 3 | None | 8, 14 | 1, 2 |
| 4 | 2 | 6, 9, 12 | 5, 7 |
| 5 | 2 | 8, 9, 12 | 4, 6, 7 |
| 6 | 2, 4 | 8, 11 | 5, 7 |
| 7 | 2 | 9, 10 | 4, 5, 6 |
| 8 | 2, 3, 5, 6 | 9, 11, 14 | None |
| 9 | 4, 5, 7, 8 | 10, 11, 12, 13 | None |
| 10 | 1, 7, 9 | 15 | 11, 12 |
| 11 | 1, 6, 8, 9 | 14, 15 | 10, 12 |
| 12 | 1, 4, 5, 9 | 15 | 10, 11 |
| 13 | 9 | 15 | 10, 11, 12 |
| 14 | 3, 8, 11 | 15, 16 | 13 |
| 15 | 10, 11, 12, 13, 14 | 16 | None |
| 16 | 15 | None | None |

### Agent Dispatch Summary

| Wave | Tasks | Recommended Agents |
|------|-------|-------------------|
| 1 | 1, 2, 3 | category="quick", parallel background tasks |
| 2 | 4, 5, 6, 7, 8 | category="unspecified-high", sequential with tests |
| 3 | 9, 10, 11, 12, 13 | category="visual-engineering", UI work |
| 4 | 14, 15, 16 | category="unspecified-low", data entry and testing |

---

## TODOs

### Wave 1: Foundation

- [ ] 1. Sprite Mapping Setup (NO COPY NEEDED - sprites already in repo)

  **What to do**:
  - Create sprite mapping table in `assets/scripts/expedition/data/sprites.lua`
  - Map game concepts to existing sprites in `assets/images/dungeon_tiles/dungeon_mode/`
  - Verify sprites load correctly via animation_system

  **NOTE**: Sprites already exist at `assets/images/dungeon_tiles/dungeon_mode/` (256 8x8 PNG files).
  NO COPYING REQUIRED - reference directly from this in-repo location.

  **Sprite mapping table** (`data/sprites.lua`):
  ```lua
  -- assets/scripts/expedition/data/sprites.lua
  -- Maps game concepts to dungeon_mode sprite filenames
  local M = {}
  
  -- Base path (relative to assets/images/)
  M.BASE_PATH = "dungeon_tiles/dungeon_mode/"
  
  -- Crew portraits
  M.CREW = {
      fighter = "dm_144_hero_knight.png",
      medic = "dm_145_hero_mage.png",
      engineer = "dm_146_hero_rogue.png",
  }
  
  -- Node type icons
  M.NODE = {
      empty = "dm_192_floor_stone.png",
      combat = "dm_160_sword.png",
      hazard = "dm_232_status_poison.png",
      distress = "dm_033_exclaim.png",
      derelict = "dm_142_chest_closed.png",  -- Note: using closed chest
      trade = "dm_190_coin_gold.png",
      mystery = "dm_064_at_symbol.png",  -- Using @ for mystery
      repair = "dm_173_gloves.png",
      upgrade = "dm_226_magic_sparkle.png",  -- Note: file may be dm_226_magic_sparkle or similar
      boss = "dm_159_dragon.png",
      destination = "dm_141_throne.png",
      current = "dm_064_at_symbol.png",
      fog = "dm_063_question.png",  -- Using ? for unrevealed
  }
  
  -- UI elements
  M.UI = {
      hp_full = "dm_236_hp_full.png",
      hp_half = "dm_237_hp_half.png",
      hp_empty = "dm_238_hp_empty.png",
  }
  
  -- Resource icons
  M.RESOURCE = {
      fuel = "dm_176_potion_red.png",
      supplies = "dm_212_barrel.png",
      scrap = "dm_185_gem_red.png",
      credits = "dm_190_coin_gold.png",
  }
  
  return M
  ```

  **Must NOT do**:
  - Copy sprites to a new location
  - Modify existing sprites
  - Reference paths outside `assets/images/dungeon_tiles/dungeon_mode/`

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple data file creation
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2, 3)
  - **Blocks**: Tasks 10, 11, 12
  - **Blocked By**: None

  **References**:
  - Sprite source: `assets/images/dungeon_tiles/dungeon_mode/` (already in repo, 256 files)
  - Sprite dimensions: 8x8 pixels, PNG, RGBA
  - Animation system: `_G.animation_system.createAnimatedObjectWithTransform(spriteName, true)`

  **Acceptance Criteria**:
  ```lua
  -- tests/test_sprites.lua
  local t = require("tests.test_runner")
  local sprites = require("expedition.data.sprites")
  
  t.describe("Sprite Mapping", function()
      t.it("defines crew sprites", function()
          t.expect(sprites.CREW.fighter).to_be("dm_144_hero_knight.png")
          t.expect(sprites.NODE.combat).to_be("dm_160_sword.png")
      end)
      
      t.it("sprite files exist on disk", function()
          local path = "assets/images/dungeon_tiles/dungeon_mode/dm_144_hero_knight.png"
          local f = io.open(path, "r")
          t.expect(f).never().to_be_nil()
          if f then f:close() end
      end)
  end)
  ```

  **Commit**: YES
  - Message: `feat(expedition): create sprite mapping for dungeon_mode tiles`
  - Files: `assets/scripts/expedition/data/sprites.lua`
  - Pre-commit: Run sprite mapping test

---

- [ ] 2. Module Structure

  **What to do**:
  - Create `assets/scripts/expedition/` directory structure
  - Create module entry point `init.lua`
  - Create subdirectory structure
  - Add module to game's script loading

  **Directory structure**:
  ```
  assets/scripts/expedition/
  ├── init.lua              # Module entry, exports API
  ├── constants.lua         # Enums, magic numbers
  ├── data/
  │   ├── events.lua        # All 30 events data
  │   ├── sprites.lua       # Sprite mapping to dungeon_mode tiles
  │   └── node_types.lua    # Node type definitions
  ├── systems/
  │   ├── crew.lua          # Crew management
  │   ├── resources.lua     # Resource tracking
  │   ├── skill_check.lua   # Skill check logic
  │   ├── map.lua           # Map generation & state
  │   ├── events.lua        # Event resolution
  │   └── rng.lua           # Seeded RNG wrapper (uses procgen.create_rng)
  ├── ui/
  │   ├── map_screen.lua    # Map display
  │   ├── event_screen.lua  # Event display
  │   ├── hud.lua           # Status display
  │   └── screens.lua       # Victory/defeat
  └── tests/
      ├── test_crew.lua
      ├── test_resources.lua
      ├── test_skill_check.lua
      ├── test_map.lua
      ├── test_events.lua
      └── test_rng.lua       # RNG determinism tests
  ```

  **Must NOT do**:
  - Create files outside `assets/scripts/expedition/`
  - Modify existing core modules
  - Add C++ code

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: File scaffolding, minimal logic
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 3)
  - **Blocks**: Tasks 4, 5, 6, 7, 8
  - **Blocked By**: None

  **References**:
  - Pattern: `assets/scripts/core/` structure
  - Module loading: `assets/scripts/init/` patterns
  - Constants pattern: `assets/scripts/core/constants.lua`

  **Acceptance Criteria**:
  ```bash
  # Verify directory structure
  find assets/scripts/expedition -type f -name "*.lua" | wc -l
  # Assert: >= 15 files (stubs)
  
  # Verify init.lua exists and is valid Lua
  luac -p assets/scripts/expedition/init.lua
  # Assert: Exit code 0 (no syntax errors)
  ```

  **Commit**: YES
  - Message: `feat(expedition): scaffold module directory structure`
  - Files: `assets/scripts/expedition/**/*.lua`
  - Pre-commit: `luac -p` on all .lua files

---

- [ ] 3. Constants & Data Tables

  **What to do**:
  - Define all Expedition constants in `constants.lua`
  - Create node type definitions in `data/node_types.lua`
  - Create event data stubs in `data/events.lua`
  - Define resource starting values and caps

  **constants.lua content**:
  ```lua
  local M = {}
  
  -- Game states
  M.STATE = {
      MAP = "expedition_map",
      EVENT = "expedition_event",
      VICTORY = "expedition_victory",
      DEFEAT = "expedition_defeat",
  }
  
  -- Crew roles
  M.ROLE = {
      FIGHTER = "fighter",
      MEDIC = "medic",
      ENGINEER = "engineer",
  }
  
  -- Skill types (map to roles)
  M.SKILL = {
      COMBAT = "combat",
      MEDICAL = "medical",
      TECHNICAL = "technical",
  }
  
  -- Node types with spawn weights
  M.NODE_TYPE = {
      EMPTY = { id = "empty", weight = 20, icon = "floor_stone" },
      COMBAT = { id = "combat", weight = 15, icon = "sword" },
      HAZARD = { id = "hazard", weight = 15, icon = "status_poison" },
      DISTRESS = { id = "distress", weight = 10, icon = "exclaim" },
      DERELICT = { id = "derelict", weight = 10, icon = "chest_closed" },
      TRADE = { id = "trade", weight = 10, icon = "coin_gold" },
      MYSTERY = { id = "mystery", weight = 10, icon = "question" },
      REPAIR = { id = "repair", weight = 5, icon = "gloves" },
      UPGRADE = { id = "upgrade", weight = 3, icon = "magic_sparkle" },
      BOSS = { id = "boss", weight = 2, icon = "dragon" },
  }
  
  -- Resources
  M.RESOURCE = {
      FUEL = { id = "fuel", start = 25, max = 30 },
      SUPPLIES = { id = "supplies", start = 10, max = 20 },
      SCRAP = { id = "scrap", start = 5, max = 50 },
      CREDITS = { id = "credits", start = 20, max = 100 },
  }
  
  -- Crew defaults
  M.CREW = {
      START_HP = 3,
      MAX_HP = 3,
      START_SKILL = 3,
      MAX_SKILL = 5,
  }
  
  -- Map parameters
  M.MAP = {
      MIN_NODES = 18,
      MAX_NODES = 22,
      BRANCHES = 3,
      FORECAST_DEPTH = 2,
  }
  
  -- Skill check formula: base 20% + skill * 20%
  M.SKILL_CHECK = {
      BASE_CHANCE = 0.20,
      PER_SKILL = 0.20,
  }
  
  return M
  ```

  **Must NOT do**:
  - Hard-code values outside constants.lua
  - Add node types not in master plan
  - Change skill check formula

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Data entry, straightforward definitions
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2)
  - **Blocks**: Tasks 8, 14
  - **Blocked By**: None

  **References**:
  - Node types: See **Appendix A: Game Specification** below (Node Types section)
  - Resources: See **Appendix A: Game Specification** below (Resources section)
  - Skill check formula: See **Appendix A: Game Specification** below (Skill Checks section)

  **Acceptance Criteria**:
  ```lua
  -- tests/test_constants.lua
  local t = require("tests.test_runner")
  local C = require("expedition.constants")
  
  t.describe("Constants", function()
      t.it("has correct resource starting values", function()
          t.expect(C.RESOURCE.FUEL.start).to_equal(25)
          t.expect(C.CREW.START_SKILL).to_equal(3)
          t.expect(C.NODE_TYPE.EMPTY.weight).to_equal(20)
      end)
      
      t.it("node type weights sum to 100", function()
          local total = 0
          for _, v in pairs(C.NODE_TYPE) do total = total + v.weight end
          t.expect(total).to_equal(100)
      end)
  end)
  ```

  **Commit**: YES
  - Message: `feat(expedition): define constants and data tables`
  - Files: `assets/scripts/expedition/constants.lua`, `assets/scripts/expedition/data/*.lua`
  - Pre-commit: `luac -p` on all files

---

### Wave 2: Core Systems

- [ ] 4. Crew System

  **What to do**:
  - Implement crew state management in `systems/crew.lua`
  - Track HP, skill levels, incapacitation status
  - Provide API for damage, healing, skill checks
  - Write comprehensive tests

  **API Design**:
  ```lua
  local Crew = {}
  
  -- Create new crew for a run
  function Crew.new()
      return {
          fighter = { hp = 3, max_hp = 3, skill = 3 },
          medic = { hp = 3, max_hp = 3, skill = 3 },
          engineer = { hp = 3, max_hp = 3, skill = 3 },
      }
  end
  
  -- Check if crew member is incapacitated
  function Crew.is_incapacitated(crew, role)
  function Crew.is_all_incapacitated(crew)
  
  -- Damage/heal crew
  function Crew.damage(crew, role, amount)
  function Crew.heal(crew, role, amount)
  function Crew.heal_all(crew, amount)
  
  -- Skills
  function Crew.get_skill(crew, role)
  function Crew.upgrade_skill(crew, role)
  
  -- Max HP upgrades (for Cybernetics Lab)
  function Crew.upgrade_max_hp(crew, role)  -- increases max_hp by 1, cap at 4
  
  -- Get role for skill type
  function Crew.role_for_skill(skill_type)
  ```

  **Must NOT do**:
  - Add crew recruitment
  - Add crew death (incapacitation only)
  - Add morale or relationships
  - Allow skills above 5
  - Allow max HP above 4

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Core system with test coverage required
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 5, 7)
  - **Blocks**: Tasks 6, 9, 12
  - **Blocked By**: Task 2

  **References**:
  - Crew specs: See **Appendix A: Game Specification** below (Crew Roles section)
  - Test runner: `assets/scripts/tests/test_runner.lua`
  - Object pattern: `docs/external/object.md`

  **Acceptance Criteria**:
  ```lua
  -- tests/test_crew.lua
  local t = require("tests.test_runner")
  local Crew = require("expedition.systems.crew")
  
  t.describe("Crew System", function()
      t.it("creates crew with correct starting values", function()
          local crew = Crew.new()
          t.expect(crew.fighter.hp).to_equal(3)
          t.expect(crew.fighter.skill).to_equal(3)
      end)
      
      t.it("incapacitates at 0 HP", function()
          local crew = Crew.new()
          Crew.damage(crew, "fighter", 3)
          t.expect(Crew.is_incapacitated(crew, "fighter")).to_be(true)
      end)
      
      t.it("caps skill at 5", function()
          local crew = Crew.new()
          Crew.upgrade_skill(crew, "fighter")
          Crew.upgrade_skill(crew, "fighter")
          Crew.upgrade_skill(crew, "fighter") -- Would be 6
          t.expect(crew.fighter.skill).to_equal(5)
      end)
      
      t.it("caps HP at max_hp", function()
          local crew = Crew.new()
          Crew.damage(crew, "fighter", 1)
          Crew.heal(crew, "fighter", 5)
          t.expect(crew.fighter.hp).to_equal(3) -- max_hp is 3
      end)
      
      t.it("can upgrade max HP (Cybernetics Lab)", function()
          local crew = Crew.new()
          Crew.upgrade_max_hp(crew, "fighter")
          t.expect(crew.fighter.max_hp).to_equal(4)
          -- Now heal should respect new max
          Crew.heal(crew, "fighter", 5)
          t.expect(crew.fighter.hp).to_equal(4)
      end)
      
      t.it("caps max HP at 4", function()
          local crew = Crew.new()
          Crew.upgrade_max_hp(crew, "fighter")
          Crew.upgrade_max_hp(crew, "fighter") -- Would be 5
          t.expect(crew.fighter.max_hp).to_equal(4)
      end)
  end)
  ```

  **Commit**: YES
  - Message: `feat(expedition): implement crew system with tests`
  - Files: `assets/scripts/expedition/systems/crew.lua`, `assets/scripts/expedition/tests/test_crew.lua`
  - Pre-commit: Run crew tests

---

- [ ] 5. Resource System

  **What to do**:
  - Implement resource tracking in `systems/resources.lua`
  - Track all 4 resources with caps
  - Provide API for spend, gain, check affordability
  - Handle fuel consumption on travel

  **API Design**:
  ```lua
  local Resources = {}
  
  function Resources.new()
      return {
          fuel = 25,
          supplies = 10,
          scrap = 5,
          credits = 20,
      }
  end
  
  function Resources.get(res, type)
  function Resources.add(res, type, amount)
  function Resources.spend(res, type, amount) -- Returns false if insufficient
  function Resources.can_afford(res, type, amount)
  function Resources.travel(res) -- Spend 1 fuel, return false if can't
  ```

  **Must NOT do**:
  - Add resource types beyond the 4
  - Add interest or passive generation
  - Allow negative resources

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Core system with test coverage required
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 4, 6, 7)
  - **Blocks**: Tasks 8, 9, 12
  - **Blocked By**: Task 2

  **References**:
  - Resource specs: See **Appendix A: Game Specification** below (Resources section)
  - Constants: `assets/scripts/expedition/constants.lua`

  **Acceptance Criteria**:
  ```lua
  -- tests/test_resources.lua
  local t = require("tests.test_runner")
  local Resources = require("expedition.systems.resources")
  
  t.describe("Resource System", function()
      t.it("initializes with correct starting values", function()
          local res = Resources.new()
          t.expect(res.fuel).to_equal(25)
          t.expect(res.supplies).to_equal(10)
      end)
      
      t.it("respects caps", function()
          local res = Resources.new()
          Resources.add(res, "fuel", 100)
          t.expect(res.fuel).to_equal(30) -- Capped
      end)
      
      t.it("prevents overspending", function()
          local res = Resources.new()
          local success = Resources.spend(res, "fuel", 100)
          t.expect(success).to_be(false)
          t.expect(res.fuel).to_equal(25) -- Unchanged
      end)
      
      t.it("travel consumes 1 fuel", function()
          local res = Resources.new()
          Resources.travel(res)
          t.expect(res.fuel).to_equal(24)
      end)
  end)
  ```

  **Commit**: YES
  - Message: `feat(expedition): implement resource system with tests`
  - Files: `assets/scripts/expedition/systems/resources.lua`, `assets/scripts/expedition/tests/test_resources.lua`
  - Pre-commit: Run resource tests

---

- [ ] 6. Skill Check System

  **What to do**:
  - Implement skill check logic in `systems/skill_check.lua`
  - Formula: Success = 20% + (Skill × 20%)
  - Support seeded RNG for reproducibility using `procgen.create_rng(seed)`
  - Implement blue option gating
  - Create RNG wrapper in `systems/rng.lua` for Expedition-specific seeded randomness

  **RNG Implementation** (CRITICAL):
  ```lua
  -- assets/scripts/expedition/systems/rng.lua
  -- Wrapper around procgen.create_rng for Expedition seeded randomness
  local procgen = require("core.procgen")
  
  local M = {}
  
  --- Create a new seeded RNG for an Expedition run
  ---@param seed number The seed value for reproducibility
  ---@return table RNG object with :random() and :random(min, max) methods
  function M.new(seed)
      local rng = procgen.create_rng(seed)
      return {
          --- Returns random float in [0, 1) OR random int in [min, max]
          ---@param min number|nil If provided with max, returns int in [min, max]
          ---@param max number|nil
          ---@return number
          random = function(self, min, max)
              if min and max then
                  return rng:int(min, max)  -- Uses procgen RNG:int(min, max)
              elseif min then
                  return rng:int(1, min)    -- Returns int in [1, min]
              else
                  return rng:next()         -- Uses procgen RNG:next() for float [0, 1)
              end
          end
      }
  end
  
  return M
  ```
  
  **procgen API Reference** (from `assets/scripts/core/procgen.lua:100-115`):
  - `rng:next()` → float in `[0, 1)` (line 102-105)
  - `rng:int(min, max)` → integer in `[min, max]` inclusive (line 111-115)

  **API Design**:
  ```lua
  local SkillCheck = {}
  
  -- Calculate success chance (0.0 to 1.0)
  -- @param skill_level number The crew skill level (1-5)
  -- @param difficulty number Optional difficulty modifier (default 0). DC+1 = difficulty 1.
  function SkillCheck.get_chance(skill_level, difficulty)
      difficulty = difficulty or 0
      local effective = math.max(1, skill_level - difficulty)
      return math.min(1.0, 0.20 + effective * 0.20)
  end
  
  -- Perform check, returns success boolean
  -- @param skill_level number The skill level (1-5)
  -- @param rng table RNG object from expedition.systems.rng.new()
  -- @param difficulty number Optional difficulty modifier (default 0)
  function SkillCheck.check(skill_level, rng, difficulty)
      local chance = SkillCheck.get_chance(skill_level, difficulty)
      return rng:random() < chance
  end
  
  -- Check if blue option is available
  function SkillCheck.can_use_blue_option(skill_level, required_skill)
      return skill_level >= required_skill
  end
  
  -- Get display string (e.g., "80%")
  -- @param skill_level number The crew skill level
  -- @param difficulty number Optional difficulty modifier
  function SkillCheck.get_display_chance(skill_level, difficulty)
      return string.format("%d%%", math.floor(SkillCheck.get_chance(skill_level, difficulty) * 100))
  end
  ```

  **Must NOT do**:
  - Add critical successes/failures
  - Add luck or modifier stats
  - Change the formula
  - Use `math.random()` directly (use seeded RNG)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Core system with statistical testing
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 4, 5, 7)
  - **Blocks**: Tasks 8, 11
  - **Blocked By**: Tasks 2, 4

  **References**:
  - Skill formula: See **Appendix A: Game Specification** below (Skill Checks section)
  - **Seeded RNG system**: `assets/scripts/core/procgen.lua:91-100` (`procgen.create_rng(seed)`)
  - RNG usage examples: `assets/scripts/tests/test_procgen.lua:83-95` (deterministic testing pattern)

  **Acceptance Criteria**:
  ```lua
  -- tests/test_skill_check.lua
  local t = require("tests.test_runner")
  local SkillCheck = require("expedition.systems.skill_check")
  local ExpeditionRNG = require("expedition.systems.rng")
  
  t.describe("Skill Check System", function()
      t.it("calculates correct chances", function()
          t.expect(SkillCheck.get_chance(3)).to_equal(0.80)
          t.expect(SkillCheck.get_chance(5)).to_equal(1.00)
          t.expect(SkillCheck.get_chance(1)).to_equal(0.40)
      end)
      
      t.it("succeeds ~80% at skill 3 over 1000 trials", function()
          local rng = ExpeditionRNG.new(12345) -- Seeded for reproducibility
          local successes = 0
          for i = 1, 1000 do
              if SkillCheck.check(3, rng) then successes = successes + 1 end
          end
          -- Range check: 80% ± 5% = [750, 850]
          t.expect(successes >= 750 and successes <= 850).to_be(true)
      end)
      
      t.it("always succeeds at skill 5", function()
          local rng = ExpeditionRNG.new(99999)
          for i = 1, 100 do
              t.expect(SkillCheck.check(5, rng)).to_be(true)
          end
      end)
      
      t.it("gates blue options correctly", function()
          t.expect(SkillCheck.can_use_blue_option(3, 4)).to_be(false)
          t.expect(SkillCheck.can_use_blue_option(4, 4)).to_be(true)
      end)
      
      t.it("is deterministic with same seed", function()
          local rng1 = ExpeditionRNG.new(54321)
          local rng2 = ExpeditionRNG.new(54321)
          for i = 1, 10 do
              t.expect(SkillCheck.check(3, rng1)).to_equal(SkillCheck.check(3, rng2))
          end
      end)
  end)
  ```

  **Commit**: YES
  - Message: `feat(expedition): implement skill check system with tests`
  - Files: `assets/scripts/expedition/systems/skill_check.lua`, `assets/scripts/expedition/tests/test_skill_check.lua`
  - Pre-commit: Run skill check tests

---

- [ ] 7. Map Generation System

  **What to do**:
  - Implement map generation in `systems/map.lua`
  - Generate 18-22 node graph with 2-3 branches
  - Assign node types by weighted distribution
  - Track current position and visited nodes
  - Support "forecast" - reveal nodes 2 jumps ahead

  **API Design**:
  ```lua
  local Map = {}
  
  -- Generate new map
  -- @param rng table - ExpeditionRNG instance for deterministic generation
  function Map.new(rng)
      return {
          nodes = {},        -- {id, type, position, connections}
          current = 1,       -- Current node ID
          visited = {},      -- Set of visited node IDs
          destination = nil, -- Final node ID
          extra_jumps = 0,   -- Added by map-affecting event outcomes
      }
  end
  
  -- Get node info
  function Map.get_node(map, id)
  function Map.get_current_node(map)
  function Map.get_adjacent_nodes(map)
  
  -- Navigation
  function Map.can_travel_to(map, target_id)
  function Map.travel_to(map, target_id) -- Returns true if successful
  
  -- Visibility (forecast)
  function Map.get_visible_nodes(map) -- Current + 2 jumps ahead
  function Map.is_node_visible(map, id)
  ```

  **Graph structure**:
  - Start node (ID 1) → branches into 2-3 paths
  - Paths occasionally merge/split
  - All paths converge at boss node before destination
  - Destination is always final node

  **Must NOT do**:
  - Allow backtracking
  - Generate infinite maps
  - Add special node combinations

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Complex algorithm with test coverage
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 4, 5, 6)
  - **Blocks**: Tasks 9, 10
  - **Blocked By**: Task 2

  **References**:
  - Map specs: See **Appendix A: Game Specification** below (Map Structure section)
  - FTL-style sector maps for inspiration

  **Acceptance Criteria**:
  ```lua
  -- tests/test_map.lua
  local t = require("tests.test_runner")
  local Map = require("expedition.systems.map")
  local ExpeditionRNG = require("expedition.systems.rng")
  
  t.describe("Map Generation", function()
      t.it("generates correct number of nodes", function()
          local rng = ExpeditionRNG.new(12345)
          local map = Map.new(rng)
          local count = 0
          for _ in pairs(map.nodes) do count = count + 1 end
          -- Range: 18-22 nodes
          t.expect(count >= 18 and count <= 22).to_be(true)
      end)
      
      t.it("has path from start to destination", function()
          local rng = ExpeditionRNG.new(12345)
          local map = Map.new(rng)
          -- BFS to verify connectivity
          local reachable = Map.get_reachable_from(map, 1)
          t.expect(reachable[map.destination]).to_be(true)
      end)
      
      t.it("node type distribution roughly matches weights", function()
          local counts = {}
          for i = 1, 100 do
              local rng = ExpeditionRNG.new(i)
              local map = Map.new(rng)
              for _, node in pairs(map.nodes) do
                  counts[node.type] = (counts[node.type] or 0) + 1
              end
          end
          -- Empty should be ~20% of all nodes (15-25% acceptable)
          local total = 0
          for _, c in pairs(counts) do total = total + c end
          local empty_pct = counts["empty"] / total * 100
          t.expect(empty_pct >= 15 and empty_pct <= 25).to_be(true)
      end)
      
      t.it("respects forecast depth of 2", function()
          local rng = ExpeditionRNG.new(12345)
          local map = Map.new(rng)
          local visible = Map.get_visible_nodes(map)
          -- Should see current + up to 2 jumps (at least 1 visible)
          t.expect(#visible >= 1).to_be(true)
      end)
  end)
  ```

  **Commit**: YES
  - Message: `feat(expedition): implement map generation with tests`
  - Files: `assets/scripts/expedition/systems/map.lua`, `assets/scripts/expedition/tests/test_map.lua`
  - Pre-commit: Run map tests

---

- [ ] 8. Event System

  **What to do**:
  - Implement event resolution in `systems/events.lua`
  - Load event data from `data/events.lua`
  - Resolve options based on skill checks
  - Apply outcomes (resource changes, crew effects)
  - Handle blue options

  **Event data structure** (CANONICAL SCHEMA - used everywhere):
  ```lua
  -- data/events.lua
  -- This is the ONLY event schema. All events follow this structure.
  return {
      combat_pirate_ambush = {
          id = "combat_pirate_ambush",
          node_type = "combat",
          title = "Pirate Ambush",
          description = "A band of raiders emerges from the asteroid field!",
          options = {
              {
                  text = "Fight them (Fighter skill: 80%)",
                  -- SKILL CHECK OPTION: crew skill check determines success/fail
                  skill_check = { crew = "fighter", difficulty = 0 },  -- difficulty 0 = normal
                  success = { credits = 10 },
                  fail = { supplies = -5, damage = { fighter = 1 } },
              },
              {
                  text = "Pay tribute (-10 credits)",
                  -- IMMEDIATE OPTION: no check, apply outcome directly
                  immediate = { credits = -10 },  -- Safe passage
              },
              {
                  text = "Flee (lose 3 fuel)",
                  immediate = { fuel = -3 },
              },
          },
      },
      
      -- RANDOM OUTCOME example (Mystery events):
      mystery_strange_signal = {
          id = "mystery_strange_signal",
          node_type = "mystery",
          title = "Strange Signal",
          description = "An unusual transmission emanates from a nearby asteroid.",
          options = {
              {
                  text = "Investigate the signal",
                  -- RANDOM OUTCOME: RNG picks one result from weighted list
                  random_outcome = {
                      { weight = 1, result = { scrap = 10 } },       -- +10 scrap
                      { weight = 1, result = { supplies = -5 } },   -- -5 supplies
                      { weight = 1, result = {} },                   -- nothing
                  },
              },
              {
                  text = "Ignore it and move on",
                  immediate = {},  -- Safe passage
              },
          },
      },
      
      -- BOSS MULTI-CHECK example:
      boss_final_guardian = {
          id = "boss_final_guardian",
          node_type = "boss",
          title = "Final Guardian",
          description = "The path to your destination is blocked by an ancient defense system.",
          options = {
              {
                  text = "Face the guardian",
                  -- MULTI-CHECK: sequence of skill checks (boss only)
                  multi_check = {
                      { crew = "fighter", success = { credits = 5 }, fail = { damage = { fighter = 1 } } },
                      { crew = "engineer", success = { credits = 5 }, fail = { damage = { engineer = 1 } } },
                      { crew = "medic", success = { credits = 5 }, fail = { damage = { medic = 1 } } },
                  },
                  win_threshold = 2,           -- Must pass 2 of 3 checks to win
                  lose_on_threshold_fail = true, -- Game over if threshold not met
              },
          },
      },
      
      -- ... 27 more events following same schema
  }
  ```
  
  **Option Type Summary**:
  | Field | Type | When to Use |
  |-------|------|-------------|
  | `skill_check` | `{crew, difficulty}` | Skill check with success/fail outcomes |
  | `immediate` | outcome table | No check, apply directly |
  | `random_outcome` | `[{weight, result}]` | RNG selects one outcome |
  | `multi_check` | `[{crew, success, fail}]` | Boss: sequence of checks |
  | `requires_skill` | number | Blue option gating (4+ = requires skill 4) |
  
  **Outcome Table Keys**:
  - `credits`, `fuel`, `supplies`, `scrap` - resource changes (positive = gain, negative = loss)
  - `damage` - `{crew = amount}` - HP damage to specific crew
  - `damage_all` - number - HP damage to all crew
  - `heal` - `{crew = amount}` - HP heal to specific crew
  - `heal_all` - number - HP heal to all crew
  - `skill_up` - `{crew = amount}` - skill upgrade
  - `extra_jumps` - number - adds jumps required to reach destination (Gravity Well fail)

  **API Design**:
  ```lua
  local Events = {}
  
  function Events.get_event_for_node(node_type, rng)
  function Events.get_options(event, crew) -- Includes blue option filtering
  function Events.resolve_option(event, option_index, crew, resources, rng)
  function Events.apply_outcome(outcome, crew, resources)
  ```

  **Must NOT do**:
  - Generate procedural events
  - Add random modifiers to outcomes
  - Change event data at runtime

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Complex system connecting multiple subsystems
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: NO (depends on 5, 6)
  - **Parallel Group**: Sequential in Wave 2
  - **Blocks**: Tasks 9, 11, 14
  - **Blocked By**: Tasks 2, 3, 5, 6

  **References**:
  - Event specs: See **Appendix A: Game Specification** below (Events section)
  - All 30 events fully specified in Appendix A

  **Acceptance Criteria**:
  ```lua
  -- tests/test_events.lua
  local t = require("tests.test_runner")
  local Events = require("expedition.systems.events")
  local Crew = require("expedition.systems.crew")
  local Resources = require("expedition.systems.resources")
  local ExpeditionRNG = require("expedition.systems.rng")
  
  t.describe("Event System", function()
      t.it("returns event matching node type", function()
          local rng = ExpeditionRNG.new(123)
          local event = Events.get_event_for_node("combat", rng)
          t.expect(event.node_type).to_equal("combat")
      end)
      
      t.it("filters blue options by skill", function()
          local crew = Crew.new()
          local rng = ExpeditionRNG.new(123)
          local event = Events.get_event_for_node("hazard", rng)
          -- Assume hazard has blue option requiring skill 4
          local options = Events.get_options(event, crew)
          -- Should NOT include blue option (crew skill is 3)
          for _, opt in ipairs(options) do
              t.expect((opt.requires_skill or 0) <= 3).to_be(true)
          end
      end)
      
      t.it("applies resource outcomes correctly", function()
          local crew = Crew.new()
          local resources = Resources.new()
          local outcome = { credits = 10, supplies = -5 }
          Events.apply_outcome(outcome, crew, resources)
          t.expect(resources.credits).to_equal(30)
          t.expect(resources.supplies).to_equal(5)
      end)
      
      t.it("is deterministic with same seed", function()
          local rng1 = ExpeditionRNG.new(99999)
          local rng2 = ExpeditionRNG.new(99999)
          local event1 = Events.get_event_for_node("mystery", rng1)
          local event2 = Events.get_event_for_node("mystery", rng2)
          t.expect(event1.id).to_equal(event2.id)
      end)
  end)
  ```

  **Commit**: YES
  - Message: `feat(expedition): implement event resolution system with tests`
  - Files: `assets/scripts/expedition/systems/events.lua`, `assets/scripts/expedition/tests/test_events.lua`
  - Pre-commit: Run event tests

---

### Wave 3: Integration

- [ ] 9. Game State Machine

  **What to do**:
  - Implement game flow in `init.lua`
  - Manage state transitions (Map → Event → Map → ... → Victory/Defeat)
  - Initialize new runs
  - Check win/lose conditions

  **States**:
  ```
  EXPEDITION_MAP → Player selects node
       ↓
  EXPEDITION_EVENT → Event resolves
       ↓
  EXPEDITION_MAP (if continuing)
       ↓
  EXPEDITION_VICTORY (reached destination, passed boss)
  EXPEDITION_DEFEAT (fuel=0 or all incapacitated)
  ```

  **API Design**:
  ```lua
  local Expedition = {}
  
  function Expedition.new_run(seed)
  function Expedition.get_state()
  function Expedition.select_node(node_id)
  function Expedition.select_option(option_index)
  function Expedition.is_game_over()
  function Expedition.get_game_result() -- "victory", "defeat_fuel", "defeat_crew"
  ```

  **Must NOT do**:
  - Add save/load
  - Add pause functionality beyond normal game pause
  - Add mid-run configuration

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Core orchestration logic
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: First in Wave 3
  - **Blocks**: Tasks 10, 11, 12, 13
  - **Blocked By**: Tasks 4, 5, 7, 8

  **Game State Integration** (CRITICAL - clarification):
  
  The existing `changeGameState()` only supports `MAIN_MENU` and `IN_GAME`.
  
  **Expedition runs INSIDE IN_GAME as a UI-driven mode/overlay**, NOT as a new GAMESTATE.
  
  **Integration approach:**
  1. Main menu button calls `changeGameState("IN_GAME")` then immediately `Expedition.start()`
  2. Expedition manages its OWN internal state (`expedition_map`, `expedition_event`, etc.)
  3. Expedition UI panels are displayed via the existing UI DSL overlay system
  4. When Expedition ends (victory/defeat), it calls `changeGameState("MAIN_MENU")`
  
  **Files modified for integration** (explicitly listed):
  1. `assets/scripts/ui/main_menu_buttons.lua` - Add "Expedition" button
  2. `assets/scripts/expedition/init.lua` - Entry point that sets up Expedition mode
  
  **Menu Integration** (how to start Expedition from main menu):
  - Add "Expedition" button to main menu via `assets/scripts/ui/main_menu_buttons.lua`
  - Use `MainMenuButtons.setButtons()` pattern (function at line 154, usage example at line 15)
  - Button onClick: `changeGameState("IN_GAME"); Expedition.start()`
  - Module require path: `local Expedition = require("expedition")`

  **References**:
  - Game state function: `assets/scripts/core/main.lua:1091` (`function changeGameState(newState)`)
  - Signal system: `assets/scripts/external/hump/signal.lua` (HUMP library)
  - Signal groups: `assets/scripts/core/signal_group.lua`
  - Main menu setButtons: `assets/scripts/ui/main_menu_buttons.lua:154` (function definition)
  - Main menu usage example: `assets/scripts/ui/main_menu_buttons.lua:15` (existing button setup)
  - UI overlay pattern: See how other UI panels work in `assets/scripts/ui/`

  **Acceptance Criteria**:
  ```lua
  -- tests/test_game_state.lua
  local t = require("tests.test_runner")
  local Expedition = require("expedition")
  
  t.describe("Game State Machine", function()
      t.it("starts in MAP state", function()
          Expedition.new_run(12345)
          t.expect(Expedition.get_state()).to_equal("expedition_map")
      end)
      
      t.it("transitions to EVENT on node selection", function()
          Expedition.new_run(12345)
          local adjacent = Expedition.get_adjacent_nodes()
          Expedition.select_node(adjacent[1].id)
          t.expect(Expedition.get_state()).to_equal("expedition_event")
      end)
      
      t.it("detects defeat on fuel exhaustion", function()
          Expedition.new_run(12345)
          -- Drain fuel
          Expedition._test_set_fuel(0)
          t.expect(Expedition.is_game_over()).to_be(true)
          t.expect(Expedition.get_game_result()).to_equal("defeat_fuel")
      end)
  end)
  ```

  **Commit**: YES
  - Message: `feat(expedition): implement game state machine`
  - Files: `assets/scripts/expedition/init.lua`
  - Pre-commit: Run all tests

---

- [ ] 10. Map UI

  **What to do**:
  - Implement map visualization in `ui/map_screen.lua`
  - Display nodes with type icons (8x8 sprites)
  - Show connections between nodes
  - Highlight current position and adjacent (clickable) nodes
  - Implement fog for non-visible nodes

  **UI Layout**:
  ```
  +----------------------------------+
  |        EXPEDITION MAP            |
  +----------------------------------+
  |                                  |
  |    [?]---[?]---[Boss]---[Goal]  |
  |     |     |      |              |
  |    [?]   [?]    [?]             |
  |     |     |      |              |
  |    [@]---[S]---[T]              |  @ = current, S/T = visible types
  |           |                      |
  |         [Start]                  |
  |                                  |
  +----------------------------------+
  | Fuel: 25 | Supplies: 10 | ...   |
  +----------------------------------+
  ```

  **Must NOT do**:
  - Add animations
  - Add zoom/pan
  - Create custom drawing primitives

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: UI layout and sprite rendering
  - **Skills**: [`frontend-ui-ux`]
    - `frontend-ui-ux`: UI layout patterns

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 11, 12)
  - **Blocks**: Task 15
  - **Blocked By**: Tasks 1, 7, 9

  **References**:
  - UI DSL: `docs/api/ui_helper_reference.md`
  - Sprite panels: `docs/api/sprite-panels.md`
  - Sprite mapping: `assets/scripts/expedition/data/sprites.lua` (maps to `assets/images/dungeon_tiles/dungeon_mode/`)

  **Acceptance Criteria**:
  ```
  # Manual verification (UI):
  1. Launch Expedition, enter map screen
  2. Verify: All visible nodes render with correct icons
  3. Verify: Current position highlighted (@ symbol or glow)
  4. Verify: Adjacent nodes are clickable (cursor change)
  5. Verify: Non-visible nodes show fog/question mark
  6. Verify: Clicking adjacent node triggers travel
  
  # Screenshot evidence:
  - .sisyphus/evidence/task-10-map-render.png
  ```

  **Commit**: YES
  - Message: `feat(expedition): implement map UI screen`
  - Files: `assets/scripts/expedition/ui/map_screen.lua`
  - Pre-commit: Visual inspection

---

- [ ] 11. Event UI

  **What to do**:
  - Implement event display in `ui/event_screen.lua`
  - Show event title, description, options
  - Display skill check percentages on relevant options
  - Show blue options only when available
  - Display outcome after selection

  **UI Layout**:
  ```
  +----------------------------------+
  |       PIRATE AMBUSH              |
  +----------------------------------+
  | A band of raiders emerges from   |
  | the asteroid field!              |
  |                                  |
  | [1] Fight them (Combat: 80%)     |
  | [2] Pay tribute (-10 credits)    |
  | [3] Flee (-3 fuel)               |
  |                                  |
  +----------------------------------+
  | Fighter: ♥♥♥  Medic: ♥♥♡        |
  | Engineer: ♥♥♥                    |
  +----------------------------------+
  ```

  **Must NOT do**:
  - Add animations
  - Add event illustrations
  - Add voiceover or sound

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: UI layout and text display
  - **Skills**: [`frontend-ui-ux`]
    - `frontend-ui-ux`: UI patterns

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 10, 12)
  - **Blocks**: Tasks 14, 15
  - **Blocked By**: Tasks 1, 6, 8, 9

  **References**:
  - UI DSL: `docs/api/ui_helper_reference.md`
  - Text system: `docs/systems/text-ui/`

  **Acceptance Criteria**:
  ```
  # Manual verification (UI):
  1. Trigger an event (travel to non-empty node)
  2. Verify: Event title displays
  3. Verify: Description text displays
  4. Verify: All available options display
  5. Verify: Skill check shows percentage (e.g., "80%")
  6. Verify: Blue option hidden if skill too low
  7. Verify: Selecting option shows outcome
  
  # Screenshot evidence:
  - .sisyphus/evidence/task-11-event-display.png
  - .sisyphus/evidence/task-11-event-outcome.png
  ```

  **Commit**: YES
  - Message: `feat(expedition): implement event UI screen`
  - Files: `assets/scripts/expedition/ui/event_screen.lua`
  - Pre-commit: Visual inspection

---

- [ ] 12. HUD (Status Display)

  **What to do**:
  - Implement status overlay in `ui/hud.lua`
  - Display crew HP using heart icons
  - Display resources with icons and numbers
  - Show current position info

  **UI Elements**:
  ```
  +----------------------------------+
  | Crew:                            |
  |   Fighter ♥♥♥ [Combat: 3]       |
  |   Medic   ♥♥♡ [Medical: 3]      |
  |   Engineer ♥♥♥ [Technical: 4]   |
  +----------------------------------+
  | Resources:                       |
  |   Fuel: 25/30  Supplies: 10/20  |
  |   Scrap: 5/50  Credits: 20/100  |
  +----------------------------------+
  ```

  **Must NOT do**:
  - Add equipment displays
  - Add mini-map in HUD
  - Add detailed tooltips

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: UI layout with dynamic data
  - **Skills**: [`frontend-ui-ux`]
    - `frontend-ui-ux`: Status display patterns

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 10, 11)
  - **Blocks**: Task 15
  - **Blocked By**: Tasks 1, 4, 5, 9

  **References**:
  - HP sprites: via sprite mapping at `assets/scripts/expedition/data/sprites.lua` (UI.hp_full, hp_half, hp_empty)
  - Sprite source: `assets/images/dungeon_tiles/dungeon_mode/dm_236_hp_full.png` etc.
  - UI DSL: `docs/api/ui_helper_reference.md`

  **Acceptance Criteria**:
  ```
  # Manual verification (UI):
  1. Start Expedition run
  2. Verify: All 3 crew members display with names
  3. Verify: HP shows as heart icons (full/half/empty)
  4. Verify: Skill levels display next to crew
  5. Verify: All 4 resources display with current/max
  6. Verify: HUD updates after events change values
  
  # Screenshot evidence:
  - .sisyphus/evidence/task-12-hud-initial.png
  - .sisyphus/evidence/task-12-hud-damaged.png
  ```

  **Commit**: YES
  - Message: `feat(expedition): implement HUD status display`
  - Files: `assets/scripts/expedition/ui/hud.lua`
  - Pre-commit: Visual inspection

---

- [ ] 13. Victory/Defeat Screens

  **What to do**:
  - Implement end screens in `ui/screens.lua`
  - Victory screen: Show completion stats
  - Defeat screen: Show cause of defeat, run stats
  - Provide "Play Again" and "Main Menu" options

  **Victory Screen**:
  ```
  +----------------------------------+
  |        EXPEDITION COMPLETE       |
  +----------------------------------+
  |   You reached the destination!   |
  |                                  |
  |   Jumps taken: 18               |
  |   Events resolved: 15           |
  |   Crew status: All healthy      |
  |   Remaining fuel: 7             |
  |                                  |
  |   [Play Again]  [Main Menu]     |
  +----------------------------------+
  ```

  **Defeat Screen**:
  ```
  +----------------------------------+
  |        EXPEDITION FAILED         |
  +----------------------------------+
  |   Cause: Ran out of fuel        |
  |                                  |
  |   Jumps taken: 12               |
  |   Distance to goal: 8 nodes     |
  |                                  |
  |   [Try Again]   [Main Menu]     |
  +----------------------------------+
  ```

  **Must NOT do**:
  - Add leaderboards
  - Add unlocks or achievements
  - Add replay functionality

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: UI screens with stats
  - **Skills**: [`frontend-ui-ux`]
    - `frontend-ui-ux`: End screen patterns

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 10, 11, 12)
  - **Blocks**: Task 15
  - **Blocked By**: Task 9

  **References**:
  - UI DSL: `docs/api/ui_helper_reference.md`
  - Box drawing sprites: available in `assets/images/dungeon_tiles/dungeon_mode/` (dm_240-250 range)
  - Sprite mapping: `assets/scripts/expedition/data/sprites.lua`

  **Acceptance Criteria**:
  ```
  # Manual verification (UI):
  1. Trigger victory (reach destination with boss passed)
  2. Verify: Victory screen displays with stats
  3. Verify: "Play Again" starts new run
  4. Verify: "Main Menu" exits Expedition
  
  5. Trigger defeat (exhaust fuel)
  6. Verify: Defeat screen displays with cause
  7. Verify: Same buttons work
  
  # Screenshot evidence:
  - .sisyphus/evidence/task-13-victory.png
  - .sisyphus/evidence/task-13-defeat.png
  ```

  **Commit**: YES
  - Message: `feat(expedition): implement victory/defeat screens`
  - Files: `assets/scripts/expedition/ui/screens.lua`
  - Pre-commit: Visual inspection

---

### Wave 4: Polish

- [ ] 14. All 30 Events Data Entry

  **What to do**:
  - Enter all 30 events from master plan into `data/events.lua`
  - Verify each event has correct structure
  - Add blue options where appropriate (based on Metis recommendation)

  **Events to implement** (from master plan):

  **Combat Events (3)**:
  1. Pirate Ambush
  2. Hostile Patrol
  3. Alien Predator

  **Hazard Events (3)**:
  1. Asteroid Field
  2. Radiation Storm
  3. Gravity Well

  **Distress Events (3)**:
  1. Stranded Crew
  2. Plague Ship
  3. Escape Pod

  **Derelict Events (3)**:
  1. Abandoned Freighter
  2. Ghost Ship
  3. Wreckage Field

  **Trade Events (3)**:
  1. Merchant Station
  2. Black Market
  3. Fuel Depot

  **Mystery Events (3)**:
  1. Strange Signal
  2. Cosmic Anomaly
  3. Ancient Ruins

  **Repair Events (3)**:
  1. Friendly Outpost
  2. Medical Bay
  3. Rest Stop

  **Upgrade Events (3)**:
  1. Training Facility
  2. Cybernetics Lab
  3. Enhancement Pod

  **Boss Events (3)**:
  1. Warlord's Blockade (mid-run, ~node 10)
  2. Nebula Guardian (mid-run, ~node 15)
  3. Final Guardian (destination)

  **Empty Events (3)**:
  1. Safe Passage (nothing happens)
  2. Quiet Sector (+1 fuel bonus)
  3. Scenic Route (no resource change)
  
  **Total: 24 + 3 + 3 = 30 events** ✓

  **Blue option examples**:
  - Hazard: "Engineer 4+ bypasses safely"
  - Distress: "Medic 4+ guarantees success"
  - Combat: "Fighter 4+ intimidates enemies"

  **Must NOT do**:
  - Add events not in master plan
  - Change event outcomes from master plan
  - Add procedural elements

  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
    - Reason: Data entry from existing spec
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Task 13 finishing)
  - **Blocks**: Tasks 15, 16
  - **Blocked By**: Tasks 3, 8, 11

  **References**:
  - Event specs: See **Appendix A: Game Specification** below (Events section)
  - Event structure: Task 8 implementation

  **Acceptance Criteria**:
  ```lua
  -- tests/test_events_data.lua
  local t = require("tests.test_runner")
  local events = require("expedition.data.events")
  
  t.describe("Events Data", function()
      t.it("has all 30 events", function()
          local count = 0
          for _ in pairs(events) do count = count + 1 end
          t.expect(count).to_equal(30)
      end)
      
      t.it("covers all node types", function()
          local node_types = {}
          for _, event in pairs(events) do
              node_types[event.node_type] = true
          end
          t.expect(node_types["combat"]).to_be(true)
          t.expect(node_types["hazard"]).to_be(true)
          t.expect(node_types["distress"]).to_be(true)
          t.expect(node_types["derelict"]).to_be(true)
          t.expect(node_types["trade"]).to_be(true)
          t.expect(node_types["mystery"]).to_be(true)
          t.expect(node_types["repair"]).to_be(true)
          t.expect(node_types["upgrade"]).to_be(true)
          t.expect(node_types["boss"]).to_be(true)
          t.expect(node_types["empty"]).to_be(true)
      end)
  end)
  ```

  **Commit**: YES
  - Message: `feat(expedition): implement all 30 events from master plan`
  - Files: `assets/scripts/expedition/data/events.lua`
  - Pre-commit: Run event count test

---

- [ ] 15. Balance Testing (Session Timing)

  **What to do**:
  - Play multiple complete runs
  - Measure session length
  - Verify difficulty curve
  - Tune if outside 15-20 minute target
  - Document balance findings

  **Testing protocol**:
  1. Play 5 complete runs with different seeds
  2. Record: time, jumps, events, outcome
  3. Calculate: average session length
  4. Identify: any balance issues (too easy/hard, too long/short)

  **Target metrics**:
  - Session length: 15-20 minutes
  - Victory rate (optimal play): ~60-70%
  - Average fuel remaining at victory: 2-5
  - Blue options seen per run: 2-3

  **Must NOT do**:
  - Change core mechanics for balance
  - Add difficulty modes
  - Change resource starting values without documenting

  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
    - Reason: Playtesting and documentation
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential, final testing
  - **Blocks**: Task 16
  - **Blocked By**: Tasks 10, 11, 12, 13, 14

  **References**:
  - Session target: 15-20 minutes (from game design spec)
  - Balance metrics: See Appendix A

  **Acceptance Criteria**:
  ```
  # Balance report document created:
  # .sisyphus/evidence/expedition-balance-report.md
  
  Contents must include:
  - [ ] 5 playthrough logs (seed, time, outcome)
  - [ ] Average session length calculation
  - [ ] Victory/defeat ratio
  - [ ] Any tuning changes made
  - [ ] Confirmation: 15-20 minute target met
  ```

  **Commit**: YES
  - Message: `docs(expedition): add balance testing report`
  - Files: `.sisyphus/evidence/expedition-balance-report.md`
  - Pre-commit: Verify report exists

---

- [ ] 16. Full Test Suite & Bug Fixes

  **What to do**:
  - Run complete test suite
  - Fix any failing tests
  - Fix any bugs found during balance testing
  - Ensure all systems integrate correctly
  - Final code review pass

  **Test suite includes**:
  - test_crew.lua
  - test_resources.lua
  - test_skill_check.lua
  - test_map.lua
  - test_events.lua
  - test_game_state.lua (from Task 9)

  **Bug fix protocol**:
  1. Identify bug
  2. Write failing test that reproduces it
  3. Fix bug
  4. Verify test passes
  5. Run full suite

  **Must NOT do**:
  - Add new features
  - Refactor working code
  - Change APIs

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Debugging and test maintenance
  - **Skills**: []
    - No special skills needed

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Final task
  - **Blocks**: None (completion)
  - **Blocked By**: Task 15

  **References**:
  - Test runner: `assets/scripts/tests/test_runner.lua`
  - All test files in `assets/scripts/expedition/tests/`

  **Acceptance Criteria**:
  ```bash
  # Run full test suite
  # In game console or via test runner:
  expedition.run_tests()
  
  # Assert: All tests pass
  # Output: "X tests passed, 0 failed"
  
  # Or via command line if test runner supports it:
  lua assets/scripts/expedition/tests/run_all.lua
  # Exit code: 0
  ```

  **Commit**: YES
  - Message: `fix(expedition): resolve test failures and bugs from balance testing`
  - Files: Various (bug fixes)
  - Pre-commit: Full test suite passes

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `feat(expedition): create sprite mapping for dungeon_mode tiles` | `assets/scripts/expedition/data/sprites.lua` | Run sprite mapping test |
| 2 | `feat(expedition): scaffold module directory structure` | `assets/scripts/expedition/**/*.lua` | luac syntax check |
| 3 | `feat(expedition): define constants and data tables` | `constants.lua`, `data/*.lua` | Load constants test |
| 4 | `feat(expedition): implement crew system with tests` | `systems/crew.lua`, `tests/test_crew.lua` | Run crew tests |
| 5 | `feat(expedition): implement resource system with tests` | `systems/resources.lua`, `tests/test_resources.lua` | Run resource tests |
| 6 | `feat(expedition): implement skill check system with tests` | `systems/skill_check.lua`, `tests/test_skill_check.lua` | Run skill tests |
| 7 | `feat(expedition): implement map generation with tests` | `systems/map.lua`, `tests/test_map.lua` | Run map tests |
| 8 | `feat(expedition): implement event resolution system with tests` | `systems/events.lua`, `tests/test_events.lua` | Run event tests |
| 9 | `feat(expedition): implement game state machine` | `init.lua` | Run all tests |
| 10 | `feat(expedition): implement map UI screen` | `ui/map_screen.lua` | Visual inspection |
| 11 | `feat(expedition): implement event UI screen` | `ui/event_screen.lua` | Visual inspection |
| 12 | `feat(expedition): implement HUD status display` | `ui/hud.lua` | Visual inspection |
| 13 | `feat(expedition): implement victory/defeat screens` | `ui/screens.lua` | Visual inspection |
| 14 | `feat(expedition): implement all 30 events from master plan` | `data/events.lua` | Event count test |
| 15 | `docs(expedition): add balance testing report` | `expedition-balance-report.md` | Document exists |
| 16 | `fix(expedition): resolve test failures and bugs` | Various | Full test suite |

---

## Success Criteria

### Verification Commands
```lua
-- Run all Expedition tests
require("expedition.tests.run_all")()
-- Expected: "All tests passed"

-- Start new run
local exp = require("expedition")
exp.new_run(12345)
-- Expected: No errors, state = "expedition_map"

-- Verify event count
local events = require("expedition.data.events")
local count = 0
for _ in pairs(events) do count = count + 1 end
assert(count == 30, "Expected 30 events, got " .. count)
```

### Final Checklist
- [ ] All "Must Have" items implemented
- [ ] All "Must NOT Have" items absent
- [ ] All Lua tests pass
- [ ] Session length within 15-20 minutes
- [ ] Victory achievable via optimal play
- [ ] Defeat achievable via poor play or bad RNG
- [ ] All 30 events from master plan present
- [ ] Blue options work correctly
- [ ] Skill check percentages display accurately

---

## Appendix A: Game Specification

This appendix contains all necessary game design specifications inline, eliminating external dependencies.

### Crew Roles (3 fixed)

| Role | Color | Skill Rating | Specialization |
|------|-------|--------------|----------------|
| **Fighter** | Red | Combat: 3 | Resolves violent encounters |
| **Medic** | Green | Medical: 3 | Resolves health/biological events |
| **Engineer** | Blue | Technical: 3 | Resolves repair/puzzle events |

### Skill Checks

```
Success_Chance = Crew_Skill × 20% + 20%
(Skill 3 = 80% success, Skill 5 = 100% success cap)
```

**Crew HP**: Each crew member starts with 3 HP and max HP of 3. At 0 HP, they're incapacitated (can't use skills). No death - just incapacitated until healed.

**Max HP Upgrades**: The Cybernetics Lab upgrade can increase a crew member's max HP by 1 (to max 4). This is tracked per-crew:
```lua
crew.fighter = { hp = 3, max_hp = 3, skill = 3 }
-- After Cybernetics Lab:
crew.fighter = { hp = 3, max_hp = 4, skill = 4 }
```

**Guardrails:**
- Exactly 3 crew, no recruitment
- No crew death (incapacitation only)
- No crew classes beyond these 3
- Skills can only increase, never decrease
- Max HP can only increase (via Cybernetics Lab), cap at 4

### Resources (4 types)

| Resource | Start | Max | Usage |
|----------|-------|-----|-------|
| **Fuel** | 25 | 30 | 1 per jump, 0 = lose |
| **Supplies** | 10 | 20 | Heal crew, trade, events |
| **Scrap** | 5 | 50 | Upgrade currency |
| **Credits** | 20 | 100 | Shop purchases |

### Map Structure

**Map Generation**:
- 18-22 nodes total (target: 20)
- Start node → Destination node
- 2-3 branching paths
- Each node visible if within 2 jumps of current position

**Node Types** (10 types):

| Node | Icon | Frequency | Description |
|------|------|-----------|-------------|
| **Empty** | · | 20% | Nothing happens, safe passage |
| **Combat** | ⚔ | 15% | Fight enemies, uses Fighter |
| **Hazard** | ☠ | 15% | Environmental danger, uses Engineer |
| **Distress** | ! | 10% | Rescue event, uses Medic |
| **Derelict** | ◊ | 10% | Abandoned ship, scavenge |
| **Trade** | $ | 10% | Buy/sell resources |
| **Mystery** | ? | 10% | Random event |
| **Repair** | ⚙ | 5% | Heal crew, repair ship |
| **Upgrade** | ★ | 3% | Spend scrap to upgrade |
| **Boss** | ◆ | 2% | Major encounter (story beat) |

### Events (30 total, 3 per node type)

**Combat Events (3)**:
1. **Pirate Ambush**: Fight skill check. Success: +10 credits. Fail: -5 supplies, -1 HP to Fighter.
2. **Hostile Patrol**: Fight skill check. Success: +5 fuel. Fail: -1 HP to all crew.
3. **Alien Predator**: Fight skill check (DC+1). Success: +15 scrap. Fail: -2 HP to Fighter, -3 supplies.

**Hazard Events (3)**:
1. **Asteroid Field**: Tech skill check. Success: Safe passage. Fail: -3 fuel.
2. **Radiation Storm**: Tech skill check. Success: Data (+5 scrap). Fail: -1 HP to all crew.
3. **Gravity Well**: Tech skill check (DC+1). Success: Shortcut (+2 fuel). Fail: Pulled off course (+1 jump to destination).

**Distress Events (3)**:
1. **Stranded Crew**: Medical skill check. Success: Grateful survivor (+10 credits). Fail: -5 supplies.
2. **Plague Ship**: Medical skill check. Success: Cure plague (+20 credits). Fail: Infection (-1 HP to Medic, -1 HP random crew).
3. **Escape Pod**: Medical skill check. Success: Rescued (+5 supplies, +5 credits). Fail: Dead on arrival (nothing).

**Derelict Events (3)**:
1. **Abandoned Freighter**: Free loot: +5 supplies OR +10 scrap (choose).
2. **Ghost Ship**: Mystery: Tech check for +15 scrap OR leave safely.
3. **Wreckage Field**: Salvage: +8 scrap automatically.

**Trade Events (3)**:
1. **Merchant Station**: Buy: Fuel 5 credits each, Supplies 3 credits each.
2. **Black Market**: Buy: Crew upgrade (skill +1) for 30 scrap. Sell: 5 supplies for 10 credits.
3. **Fuel Depot**: Buy: Fuel 3 credits each (discount).

**Mystery Events (3)**:
1. **Strange Signal**: Investigate (random: +10 scrap, -5 supplies, or nothing).
2. **Cosmic Anomaly**: Pass through (random: +3 fuel, -1 HP all, or shortcut).
3. **Ancient Ruins**: Explore: Tech check for +25 scrap, or leave with +5 scrap.

**Repair Events (3)**:
1. **Friendly Outpost**: Heal all crew 1 HP, +3 supplies.
2. **Medical Bay**: Heal all crew to full, -5 credits.
3. **Rest Stop**: Heal 1 crew fully, +2 fuel.

**Upgrade Events (3)**:
1. **Training Facility**: Pay 15 scrap: +1 to any crew skill.
2. **Cybernetics Lab**: Pay 25 scrap: +1 to Fighter skill, +1 max HP.
3. **Enhancement Pod**: Pay 20 scrap: +1 to any crew skill, -1 HP (temporary pain).

**Boss Events (3)**:
1. **Warlord's Blockade** (appears at ~node 10): All crew skill checks in sequence. Each success: +5 credits. Each fail: -1 HP to that crew.
2. **Nebula Guardian** (appears at ~node 15): Choose 2 crew for skill checks. Each success: +10 scrap. Each fail: -2 HP to that crew.
3. **Final Guardian** (destination): Fight + Tech + Medical checks. Must pass 2 of 3 to win. Fail = game over.

**Empty Events (3)**:
1. **Safe Passage**: No event, just travel (nothing happens).
2. **Quiet Sector**: Uneventful journey (+1 fuel bonus from efficient travel).
3. **Scenic Route**: Nothing noteworthy (no resource change).

**Final Event Count**: 24 + 3 + 3 = **30 events** ✓

---

### Event System Mechanics

**Outcome Types** (how events are resolved):

1. **Skill Check (binary)**: Most events. Player chooses option → skill check → success OR fail outcome.
   ```lua
   option = {
       text = "Fight them (Fighter)",
       skill_check = { crew = "fighter", difficulty = 0 },  -- difficulty 0 = normal
       success = { credits = 10 },
       fail = { supplies = -5, damage = { fighter = 1 } }
   }
   ```

2. **Choice (no check)**: Player chooses, immediate outcome. Used for derelict, trade.
   ```lua
   option = {
       text = "Take supplies (+5 supplies)",
       immediate = { supplies = 5 }
   }
   ```

3. **Random Outcome**: Single option triggers RNG selection from multiple outcomes. Used for mystery events.
   ```lua
   option = {
       text = "Investigate the signal",
       random_outcome = {
           { weight = 1, result = { scrap = 10 } },
           { weight = 1, result = { supplies = -5 } },
           { weight = 1, result = {} }  -- nothing
       }
   }
   ```

4. **Multi-Check (boss only)**: Sequence of checks, each with independent outcome.
   ```lua
   -- Boss events encoded as single option that runs multiple checks
   option = {
       text = "Face the guardian",
       multi_check = {
           { crew = "fighter", success = { credits = 5 }, fail = { damage = { fighter = 1 } } },
           { crew = "medic", success = { credits = 5 }, fail = { damage = { medic = 1 } } },
           { crew = "engineer", success = { credits = 5 }, fail = { damage = { engineer = 1 } } }
       },
       -- For Final Guardian: win_threshold = 2 (must pass 2 of 3)
       win_threshold = 2,  -- nil means all checks are independent
       lose_on_threshold_fail = true  -- if threshold not met, game over
   }
   ```

**DC Modifier (difficulty)**:
- `difficulty = 0`: Normal (use crew's base skill)
- `difficulty = 1` (DC+1): Harder check, effectively skill-1 for chance calculation
  ```lua
  function SkillCheck.check_with_difficulty(skill_level, difficulty, rng)
      local effective_skill = math.max(1, skill_level - difficulty)
      return SkillCheck.check(effective_skill, rng)
  end
  ```

**Map/Progress Outcomes** (CRITICAL - exact semantics):

The map stores `extra_jumps` as a counter that must be reduced to 0 before the player can reach the destination node.

**State representation**:
```lua
map = {
    nodes = { ... },
    current = 1,
    destination = 20,     -- Final node ID
    extra_jumps = 0,      -- Penalty counter (Gravity Well fail adds to this)
}
```

**Semantics**:
1. **`extra_jumps = N` in outcome**: Increments `map.extra_jumps` by N
2. **Victory condition**: Player is at destination node AND `map.extra_jumps == 0`
3. **Travel behavior**: Each jump costs 1 fuel AND decrements `map.extra_jumps` by 1 (if > 0)
4. **Fuel outcome**: `{ fuel = N }` directly adds N to resources (negative = loss)

**Example flow** (Gravity Well fail):
```lua
-- Player at node 15, destination is node 20
-- map.extra_jumps = 0
-- Event outcome: { extra_jumps = 1 }
map.extra_jumps = map.extra_jumps + 1  -- Now 1

-- Next jump: Player moves to node 16
-- 1 fuel consumed, extra_jumps decremented
map.extra_jumps = map.extra_jumps - 1  -- Now 0

-- If player reaches destination with extra_jumps > 0, they must keep traveling
-- (UI shows "X extra jumps required" near destination)
```

**Applied in**:
- `Events.apply_outcome()` - handles resource and map changes
- `Map.travel_to()` - decrements extra_jumps on each jump
- `Expedition.check_victory()` - requires extra_jumps == 0

**Guardrails:**
- Events have structured outcomes (not procedural generation)
- Multi-check events are boss-only and resolve in single interaction
- No crew recruitment
- No ship combat (crew skill checks only)

### UI Mockups

**Map Screen**:
```
+-----------------------------------+
| EXPEDITION - Fuel: 15/30          |
+-----------------------------------+
|          [Destination ◆]          |
|           /    \                  |
|         ★        ⚔               |
|         |        |                |
|        ☠        $                 |
|         \      /                  |
|          [YOU @]                  |
+-----------------------------------+
| Fighter: ♥♥♥ | Medic: ♥♥♡ | Eng: ♥♥♥ |
| Supplies: 8 | Scrap: 12 | Credits: 25 |
+-----------------------------------+
```

**Event Screen**:
```
+-----------------------------------+
| PIRATE AMBUSH                     |
+-----------------------------------+
| A band of raiders emerges from    |
| the asteroid field!               |
|                                   |
| [1] Fight them (Fighter skill)    |
|     Success: 80%                  |
| [2] Pay tribute (-10 credits)     |
| [3] Try to flee (lose 3 fuel)     |
+-----------------------------------+
```

---

*Plan generated by Prometheus. Run `/start-work` to begin execution.*
