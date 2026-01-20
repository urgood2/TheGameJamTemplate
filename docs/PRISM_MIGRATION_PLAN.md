# Comprehensive Migration Plan: Prism → TheGameJamTemplate

## Executive Summary

This plan adapts **PrismRL/prism** (a Lua roguelike engine for LÖVE) systems into your existing **C++20/Lua game engine** (TheGameJamTemplate using Raylib + EnTT + Chipmunk2D).

**Key Principle**: Don't port Prism 1:1. Recreate roguelike *semantics* (grid map, actions, turns, FOV, A*) using your engine's existing strengths.

**Baseline Assumptions**:
- Your template has C++20, Raylib 5.5, EnTT registry, Sol2, Chipmunk2D, and LDtk integration working
- Scripts attach via `script:attach_ecs { ... }` (data assigned before attach_ecs) per `claude.md`
- Existing LOS algorithm (`src/systems/line_of_sight/line_of_sight.cpp`) is functional and reusable
- You want a vertical slice (playable demo) within 5-7 days, full implementation deferred
- Turn-based mode coexists with real-time physics (not a full engine overhaul)

**Scope Boundaries**:
- No UI/UX overhaul, no new renderer, no asset pipeline changes
- No multiplayer/networking
- No changes to core realtime combat systems outside the roguelike slice

---

## Architecture Overview

### What You're Adapting FROM (Prism)

| System | Implementation | Key Files |
|--------|----------------|-----------|
| Entity Model | Custom `Object:extend()` inheritance | `engine/core/object.lua`, `actor.lua`, `entity.lua` |
| Components | Data + behavior attached to entities | `engine/core/component.lua` |
| Turn Loop | Coroutine-based with Scheduler | `engine/core/scheduler.lua`, `level.lua` |
| Actions | Command pattern with `canPerform()`/`perform()` | `engine/core/action.lua` |
| FOV | Symmetric shadowcasting | `engine/algorithms/fov/` |
| Pathfinding | A* with callbacks | `engine/algorithms/astar/` |
| Rendering | Grid-based terminal display | `spectrum/display.lua` |
| Map | Grid with opacity/passability caches | `engine/core/level.lua`, `map.lua` |

### What You're Adapting TO (TheGameJamTemplate)

| System | Implementation | Key Files |
|--------|----------------|-----------|
| Entity Model | **EnTT ECS** (keep this) | `src/components/components.hpp` |
| Scripting | **Sol2 Lua bindings** (keep this) | `src/systems/scripting/` |
| Rendering | **Raylib sprites** (keep this) | `src/systems/layer/` |
| Physics | **Chipmunk2D** (keep, add grid option) | `src/systems/physics/` |
| LOS | **C++ implementation exists** (extend) | `src/systems/line_of_sight/` |
| Maps | **LDtk loader exists** (extend) | `src/systems/ldtk_loader/` |

---

## Phase 0: Foundation — GridWorld Primitives

**Goal**: Establish core grid abstractions all later phases depend on.

**Complexity**: M (Medium) | **Duration**: 1-2 days | **Critical Path**: YES

### Prerequisites
- Project builds successfully with `just build-debug`
- EnTT registry is created and accessible from Lua via `registry` global
- Sol2 bindings working (verify via a simple Lua test script)
- Decide whether `GridWorld` lives in registry context or a global singleton

### What to Build

#### C++ (Core Types)
```cpp
// src/systems/roguelike/grid_types.hpp
struct GridCoord { int x, y; };
struct GridRect { int x, y, w, h; };
enum class GridDir { N, NE, E, SE, S, SW, W, NW };

// Helpers
GridCoord world_to_grid(float worldX, float worldY, int tileSize);
Vector2 grid_to_world(GridCoord cell, int tileSize);
```

```cpp
// src/systems/roguelike/grid_world.hpp
class GridWorld {
    int width, height, tileSize;
    std::vector<uint8_t> tileFlags;  // blocksMove, blocksLight per tile
    std::vector<entt::entity> occupancy;  // which entity occupies each tile

public:
    bool blocksMovement(int x, int y) const;
    bool blocksLight(int x, int y) const;
    entt::entity getOccupant(int x, int y) const;
    void setOccupant(int x, int y, entt::entity e);
    void clearOccupant(int x, int y);
};
```

#### Lua (Configuration)
```lua
-- assets/scripts/roguelike/grid_config.lua
return {
    tileSize = 16,           -- pixels per tile
    allowDiagonals = true,   -- 8-way vs 4-way movement
    diagonalCost = 1.4,      -- movement cost for diagonals
}
```

### Files to Create
| File | Purpose |
|------|---------|
| `src/systems/roguelike/grid_types.hpp` | GridCoord, GridRect, GridDir |
| `src/systems/roguelike/grid_world.hpp` | GridWorld class declaration |
| `src/systems/roguelike/grid_world.cpp` | GridWorld implementation |
| `src/systems/roguelike/grid_math.hpp` | Coordinate conversion utilities |
| `assets/scripts/roguelike/grid_config.lua` | Lua-side configuration |

### Files to Modify
| File | Change |
|------|--------|
| `src/components/components.hpp` | Add `GridPositionComponent { int x, y; }` |
| `src/systems/scripting/scripting_bindings.cpp` | Expose grid helpers to Lua |

### Dependencies
- None (this is foundation)

### Acceptance Criteria
- [ ] `GridCoord`, `GridRect`, `GridDir` types compile
- [ ] `GridWorld` class instantiates and reserves storage for 80x50 grid
- [ ] `world_to_grid()` and `grid_to_world()` round-trip correctly (test with (0,0) and (80,50))
- [ ] Lua can call `grid.world_to_grid(16, 16, 16)` and get `{x=1, y=1}`
- [ ] `GridPositionComponent` added to ECS, no build errors
- [ ] Unit test: Grid operations don't crash with out-of-bounds access
- [ ] `GridWorld` reports out-of-bounds as blocked for movement/light
- [ ] GridWorld occupancy operations are O(1) for get/set/clear

### Verification Checklist
```bash
# After Phase 0 is "done":
just build-debug
# Run a test script that creates a GridWorld and calls conversion functions
# Verify no crashes and correct values
```

---

## Phase 1: Grid/Map System

**Goal**: Add grid-based map representation alongside existing world.

**Complexity**: M | **Duration**: 1-2 days | **Depends On**: Phase 0

### Prerequisites
- Phase 0 complete and verified
- At least one LDtk level in `assets/` with an IntGrid layer named `collision` or similar
- `src/systems/ldtk_loader/ldtk_combined.hpp` available and building

### What to Build

#### C++ (Map Loading)
```cpp
// src/systems/roguelike/grid_map_from_ldtk.hpp
class GridMapLoader {
public:
    // Load from LDtk IntGrid layer
    static GridWorld loadFromLDtk(const ldtk::World& world,
                                   const std::string& levelName,
                                   const std::string& intGridLayer);

    // Load from procedural generator output
    static GridWorld loadFromGenerated(int w, int h,
                                        const std::vector<uint8_t>& tiles);
};
```

#### Lua (Tile Definitions)
```lua
-- assets/scripts/roguelike/tile_defs.lua
-- Maps LDtk IntGrid values → tile properties
return {
    [0] = { blocksMove = false, blocksLight = false, cost = 1 },   -- floor
    [1] = { blocksMove = true,  blocksLight = true,  cost = 999 }, -- wall
    [2] = { blocksMove = false, blocksLight = false, cost = 2 },   -- water (slower)
    [3] = { blocksMove = true,  blocksLight = false, cost = 999 }, -- glass wall
}
```

### Integration Points
- **LDtk**: Your `src/systems/ldtk_loader/` already parses grid metadata
- **Physics**: Reuse `physics.create_tilemap_colliders()` for static walls
- **Rendering**: Tiles become normal batched sprites (no change needed)

### Prism References
- `engine/core/level.lua` lines 50-80 (passability cache initialization)
- `engine/structures/grid.lua` (data structure patterns)

### Files to Create
| File | Purpose |
|------|---------|
| `src/systems/roguelike/grid_map_from_ldtk.hpp/.cpp` | LDtk→GridWorld loader |
| `assets/scripts/roguelike/tile_defs.lua` | Tile property definitions |

### Acceptance Criteria
- [ ] `GridMapLoader::loadFromLDtk()` successfully loads a test LDtk map into GridWorld
- [ ] Occupancy tracking works: placing two entities in same cell returns error or overwrites correctly
- [ ] `tile_defs.lua` loaded by Lua without errors
- [ ] Tile blocking flags match LDtk IntGrid values (e.g., 1=wall=blocksMove=true)
- [ ] No memory leaks or out-of-bounds access when loading 10x10 and 100x100 maps
- [ ] GridWorld dimensions match LDtk level dimensions

### Verification Checklist
```lua
-- Load sample LDtk level and check tile properties
local map = require("roguelike.grid_map_from_ldtk")
local tiles = map.load_ldtk("level1", "collision")
assert(tiles:blocksMovement(1, 1) == false)  -- floor
assert(tiles:blocksMovement(0, 0) == true)   -- wall
```

---

## Phase 2: Turn-Based Core ⭐ (Critical Path)

**Goal**: Implement "everything is an Action" + "Scheduler picks next actor"

**Complexity**: L (Large) | **Duration**: 3-4 days | **Depends On**: Phase 0, Phase 1

### Prerequisites
- Phase 0 and 1 complete and verified
- Confirm `signal.emit()` and `signal.register()` working from `assets/scripts/external/hump/signal.lua`
- Verify ScriptComponent lifecycle: init/update/destroy hooks working (check `claude.md` patterns)
- Input system wired (arrow keys, action keys available)

### Architecture Decision

**Hybrid C++/Lua approach**:
- **C++ owns**: Scheduling, turn state, determinism
- **Lua owns**: Action definitions, validation rules, game-specific logic

### Missing Decision (Clarify Early)
- Will actions be pure Lua tables, or Lua objects with metatables? Choose one and stick to it to avoid inconsistent behavior in Sol2 bindings.

### What to Build

#### C++ Components
```cpp
// src/systems/roguelike/turn/turn_components.hpp

struct TurnActorComponent {
    int speed = 100;        // higher = acts more often
    int energy = 0;         // accumulates each tick
    bool isPlayer = false;
};

struct PendingActionComponent {
    sol::table actionData;  // Lua table describing the action
    bool ready = false;
};

// Singleton resource
struct TurnState {
    entt::entity currentActor = entt::null;
    int turnNumber = 0;
    enum class Phase { AwaitingInput, Resolving, Animating } phase;
};
```

#### C++ Turn Scheduler
```cpp
// src/systems/roguelike/turn/turn_scheduler.hpp
class TurnScheduler {
    std::vector<entt::entity> actors;

public:
    void addActor(entt::entity e, int speed);
    void removeActor(entt::entity e);
    entt::entity getNextActor(entt::registry& reg);  // energy-based selection
    void tick(entt::registry& reg);  // add energy to all actors
};
```

#### Lua Action System
```lua
-- assets/scripts/roguelike/actions/action_base.lua
local Action = {}
Action.__index = Action

function Action:canPerform(ctx)
    -- Override in subclasses
    return true, nil  -- (success, error_message)
end

function Action:perform(ctx)
    -- Override in subclasses
    error("Action:perform() must be overridden")
end

function Action:getCost()
    return 100  -- default energy cost
end

return Action
```

```lua
-- assets/scripts/roguelike/actions/move.lua
local Action = require("roguelike.actions.action_base")
local MoveAction = setmetatable({}, { __index = Action })

function MoveAction.new(actor, dx, dy)
    return setmetatable({
        actor = actor,
        dx = dx,
        dy = dy,
    }, { __index = MoveAction })
end

function MoveAction:canPerform(ctx)
    local newX = ctx.gridPos.x + self.dx
    local newY = ctx.gridPos.y + self.dy

    if not ctx.gridWorld:inBounds(newX, newY) then
        return false, "Out of bounds"
    end
    if ctx.gridWorld:blocksMovement(newX, newY) then
        return false, "Blocked"
    end
    if ctx.gridWorld:getOccupant(newX, newY) ~= nil then
        return false, "Occupied"
    end
    return true
end

function MoveAction:perform(ctx)
    local oldX, oldY = ctx.gridPos.x, ctx.gridPos.y
    local newX, newY = oldX + self.dx, oldY + self.dy

    -- Update grid occupancy
    ctx.gridWorld:clearOccupant(oldX, oldY)
    ctx.gridWorld:setOccupant(newX, newY, self.actor)

    -- Update component
    ctx.gridPos.x = newX
    ctx.gridPos.y = newY

    -- Emit signal for animation/FOV update
    signal.emit("actor_moved", self.actor, oldX, oldY, newX, newY)
end

return MoveAction
```

#### C++ Turn Loop Integration
```cpp
// src/systems/roguelike/turn/turn_system.cpp
void TurnSystem::update(entt::registry& reg, sol::state& lua) {
    auto& state = reg.ctx().get<TurnState>();

    switch (state.phase) {
        case TurnState::Phase::AwaitingInput:
            // Wait for player input or AI decision
            if (hasActionReady(state.currentActor)) {
                state.phase = TurnState::Phase::Resolving;
            }
            break;

        case TurnState::Phase::Resolving:
            executeAction(reg, lua, state.currentActor);
            state.phase = TurnState::Phase::Animating;
            break;

        case TurnState::Phase::Animating:
            if (animationsComplete()) {
                advanceToNextActor(reg);
                state.phase = TurnState::Phase::AwaitingInput;
            }
            break;
    }
}
```

### Integration Points
- Use existing `core/timer.lua` for action animations
- Use existing `signal` system for turn events
- Player input routes through existing input system, but queues actions instead of direct movement
- Reuse existing `LocationComponent` or decide to standardize on `GridPositionComponent` for roguelike entities

### Prism References
- `engine/core/action.lua` - Action base class pattern
- `engine/core/scheduler.lua` - Scheduler interface
- `engine/core/turnhandler.lua` - Turn execution flow
- `engine/core/level.lua:run()` - Main turn loop

### Files to Create
| File | Purpose |
|------|---------|
| `src/systems/roguelike/turn/turn_components.hpp` | TurnActorComponent, TurnState |
| `src/systems/roguelike/turn/turn_scheduler.hpp/.cpp` | Energy-based scheduler |
| `src/systems/roguelike/turn/turn_system.hpp/.cpp` | Main turn loop |
| `assets/scripts/roguelike/actions/action_base.lua` | Action base class |
| `assets/scripts/roguelike/actions/move.lua` | Move action |
| `assets/scripts/roguelike/actions/wait.lua` | Wait/skip action |
| `assets/scripts/roguelike/actions/melee.lua` | Melee attack action |

### Key Design Decisions
1. **Turn State as Singleton**: `reg.ctx().get<TurnState>()` holds phase, current actor, turn counter
2. **Action Queueing**: Actions stored in PendingActionComponent until next phase (prevent double-actions)
3. **Energy System**: Higher speed = accumulates energy faster. Each action deducts its cost. Choose actor with most energy.
4. **Signals over Callbacks**: Turn events emitted as signals (`turn_started`, `actor_acted`, `turn_ended`) for decoupling

### Acceptance Criteria
- [ ] TurnScheduler correctly selects actor with highest energy
- [ ] Player pressing arrow key queues MoveAction (no immediate execution)
- [ ] Turn phases advance: AwaitingInput → Resolving → Animating → AwaitingInput
- [ ] Multiple actors in registry all participate in turn order
- [ ] Turn determinism: same seed + input sequence = same outcome (for testing)
- [ ] Signals emit at correct times (capture with signal.register and count)
- [ ] No action executes twice in a single turn phase

### Verification Checklist
```bash
# After Phase 2:
# 1. Create 3 test entities with speeds 100, 150, 100
# 2. Verify TurnScheduler picks entity #2 on turn 1
# 3. After entity #2 acts (cost 100), entity #1 should be next (has 150 energy)
# 4. Player input queues action, system resolves it next phase
```

---

## Phase 3: FOV & Visibility

**Goal**: Provide "seen/explored/remembered" visibility system.

**Complexity**: M | **Duration**: 1-2 days | **Depends On**: Phase 0, 1, 2

### Prerequisites
- Phases 0-2 complete and verified
- Confirm existing LOS in `src/systems/line_of_sight/line_of_sight.cpp` builds and is callable
- Understand its signature: takes origin, radius, and opaque-check callback
- Rendering system can tint/hide tiles based on visibility

### Key Insight
**You already have C++ LOS!** `src/systems/line_of_sight/line_of_sight.cpp` implements octant-based visibility. Extend it rather than rewriting.

### What to Build

#### C++ Components
```cpp
// src/systems/roguelike/fov/fov_components.hpp

struct VisionComponent {
    int radius = 8;
    bool darkvision = false;
};

struct VisibilityMapComponent {
    std::vector<bool> visible;    // currently seen this turn
    std::vector<bool> explored;   // ever seen
    int width, height;

    bool isVisible(int x, int y) const;
    bool isExplored(int x, int y) const;
    void setVisible(int x, int y, bool v);
    void markExplored(int x, int y);
    void clearVisible();  // call at start of each turn
};
```

#### C++ FOV System
```cpp
// src/systems/roguelike/fov/fov_system.cpp
void FOVSystem::recompute(entt::registry& reg, entt::entity viewer) {
    auto& vision = reg.get<VisionComponent>(viewer);
    auto& gridPos = reg.get<GridPositionComponent>(viewer);
    auto& visMap = reg.get<VisibilityMapComponent>(viewer);
    auto& gridWorld = reg.ctx().get<GridWorld>();

    visMap.clearVisible();

    // Reuse existing LOS algorithm with callback
    computeShadowcastFOV(
        gridPos.x, gridPos.y, vision.radius,
        [&](int x, int y) { return gridWorld.blocksLight(x, y); },  // opaque check
        [&](int x, int y) {  // reveal callback
            visMap.setVisible(x, y, true);
            visMap.markExplored(x, y);
        }
    );
}
```

#### Lua Rendering Policy
```lua
-- assets/scripts/roguelike/render_visibility.lua
local RenderVisibility = {}

function RenderVisibility.getTileTint(x, y, playerVisMap)
    if playerVisMap:isVisible(x, y) then
        return { r = 1, g = 1, b = 1, a = 1 }  -- full brightness
    elseif playerVisMap:isExplored(x, y) then
        return { r = 0.3, g = 0.3, b = 0.4, a = 1 }  -- dim/blue tint
    else
        return nil  -- don't render at all
    end
end

return RenderVisibility
```

### Prism References
- `engine/algorithms/fov/fov.lua` - Shadowcasting implementation
- `engine/algorithms/fov/quadrant.lua` - Quadrant transformation
- `extra/senses.lua` - Explored/remembered tracking (if available)

### Files to Create
| File | Purpose |
|------|---------|
| `src/systems/roguelike/fov/fov_components.hpp` | VisionComponent, VisibilityMapComponent |
| `src/systems/roguelike/fov/fov_system.hpp/.cpp` | FOV recomputation system |
| `assets/scripts/roguelike/render_visibility.lua` | Visibility-based tinting |

### Acceptance Criteria
- [ ] FOVSystem::recompute() completes in <1ms for 80x50 grid with 8-radius FOV
- [ ] Explored tiles persist across turns (not cleared each frame)
- [ ] Currently visible tiles render at full brightness
- [ ] Explored but not visible tiles render at 30% brightness
- [ ] Never-explored tiles don't render (or render as black)
- [ ] FOV updates correctly when player moves to adjacent tile
- [ ] LOS respects wall tiles (no visibility through walls)

### Verification Checklist
```bash
# After Phase 3:
# 1. Place player at (40, 25)
# 2. Call FOVSystem::recompute()
# 3. Check visible set includes (40, 25) +/- 8 tiles
# 4. Check visible set excludes (40, 25) +/- 10 tiles (beyond radius)
# 5. Move player to (42, 25), recompute, verify visible set shifted
```

---

## Phase 4: Pathfinding

**Goal**: Grid A* with configurable costs.

**Complexity**: M | **Duration**: 1-2 days | **Depends On**: Phase 0, 1

### Prerequisites
- Phase 0 and 1 complete and verified
- Review `include/fudge_pathfinding/astar_search.h` template - decide: use it or write from scratch
- Verify ability to call C++ functions from Lua and return std::vector<GridCoord>
- Define coordinate convention for path output (start excluded or included) and stick to it

### Key Insight
You have `include/fudge_pathfinding/` headers. Use these or implement simple A* - grid pathfinding is straightforward.

### What to Build

#### C++ A* Implementation
```cpp
// src/systems/roguelike/path/grid_astar.hpp
struct PathResult {
    std::vector<GridCoord> path;
    bool found;
    int totalCost;
};

class GridAStar {
public:
    using PassableFunc = std::function<bool(int x, int y)>;
    using CostFunc = std::function<int(int x, int y)>;

    static PathResult findPath(
        GridCoord start,
        GridCoord goal,
        PassableFunc isPassable,
        CostFunc getCost,
        bool allowDiagonal = true,
        int maxIterations = 1000
    );
};
```

#### Lua Bindings
```lua
-- Usage in Lua
local path = grid.find_path(
    startX, startY,
    goalX, goalY,
    {
        -- Optional overrides
        passable = function(x, y)
            return not gridWorld:blocksMovement(x, y)
        end,
        cost = function(x, y)
            return tileDefs[gridWorld:getTileType(x, y)].cost or 1
        end,
        diagonal = true,
    }
)

if path then
    for i, step in ipairs(path) do
        print(step.x, step.y)
    end
end
```

### Prism References
- `engine/algorithms/astar/astar.lua` - Main algorithm
- `engine/algorithms/astar/path.lua` - Path result object

### Files to Create
| File | Purpose |
|------|---------|
| `src/systems/roguelike/path/grid_astar.hpp/.cpp` | A* implementation |
| `src/systems/roguelike/path/path_components.hpp` | PathRequest/PathResult components |

### Acceptance Criteria
- [ ] GridAStar::findPath() returns path from (5,5) to (15,15) on open grid
- [ ] Pathfinding returns no path when goal is surrounded by walls
- [ ] Path respects diagonal=true/false setting
- [ ] Path cost calculation matches tile_defs.lua costs
- [ ] Lua binding `grid.find_path()` works and returns Lua table of {x,y} steps
- [ ] Pathfinding <10ms for 80x50 grid worst-case (arbitrary goal, long path)

### Verification Checklist
```bash
# After Phase 4:
# 1. Load 80x50 map with maze
# 2. Find path from (5,5) to (75,45)
# 3. Verify: path exists, each step is adjacent (4-way or 8-way), path length is reasonable
# 4. Add obstacle between (5,5) and goal
# 5. Verify: pathfinding finds alternate route or returns nil
```

---

## Phase 5: Actor/Controller System

**Goal**: Entities participate in turns, receive input/AI.

**Complexity**: L | **Duration**: 3-4 days | **Depends On**: Phase 0, 1, 2, 4

### Prerequisites
- Phases 0-4 complete and verified
- Understand how to emit and subscribe to signals (from your signal system)
- Confirm input state is accessible (arrow keys, action keys)
- Verify Transform component updating correctly when grid position changes

### What to Build

#### C++ Components
```cpp
// src/systems/roguelike/actor/actor_components.hpp

struct GridMovementComponent {
    int moveCost = 100;       // energy cost per move
    bool canDiagonal = true;
    bool blocksOthers = true;
    int sizeX = 1, sizeY = 1; // for multi-tile actors later
};

enum class ControllerType { Player, AI, Scripted };
struct ControllerComponent {
    ControllerType type;
};
```

#### Lua Player Controller
```lua
-- assets/scripts/roguelike/controllers/player_turn_controller.lua
local PlayerController = {}

function PlayerController.getAction(entity, ctx)
    -- Map input to action
    if input.is_action_just_pressed("move_up") then
        return MoveAction.new(entity, 0, -1)
    elseif input.is_action_just_pressed("move_down") then
        return MoveAction.new(entity, 0, 1)
    -- ... etc
    elseif input.is_action_just_pressed("wait") then
        return WaitAction.new(entity)
    end

    return nil  -- no action yet, keep waiting
end

return PlayerController
```

#### Lua AI Controller
```lua
-- assets/scripts/roguelike/controllers/ai_turn_controller.lua
local AIController = {}

function AIController.getAction(entity, ctx)
    local myPos = ctx.gridPos
    local playerPos = ctx.playerGridPos

    -- Simple chase behavior
    local path = grid.find_path(myPos.x, myPos.y, playerPos.x, playerPos.y)

    if path and #path > 0 then
        local next = path[1]
        local dx = next.x - myPos.x
        local dy = next.y - myPos.y
        return MoveAction.new(entity, dx, dy)
    end

    return WaitAction.new(entity)
end

return AIController
```

### Integration: Grid ↔ Transform Sync
```cpp
// When grid position changes, update Transform for rendering
void GridMovementSystem::syncTransformFromGrid(entt::registry& reg) {
    auto view = reg.view<GridPositionComponent, Transform>();
    auto& config = reg.ctx().get<GridConfig>();

    for (auto [entity, gridPos, transform] : view.each()) {
        // Convert grid → world coordinates
        float worldX = gridPos.x * config.tileSize + config.tileSize / 2.0f;
        float worldY = gridPos.y * config.tileSize + config.tileSize / 2.0f;

        transform.actualX = worldX;
        transform.actualY = worldY;
    }
}
```

### Prism References
- `engine/core/actor.lua` - Actor entity type
- `extra/controller.lua` - Controller patterns (if exists)
- SystemManager event hooks pattern

### Files to Create
| File | Purpose |
|------|---------|
| `src/systems/roguelike/actor/actor_components.hpp` | GridMovement, Controller |
| `src/systems/roguelike/actor/grid_movement_system.cpp` | Movement + sync |
| `assets/scripts/roguelike/controllers/player_turn_controller.lua` | Player input→action |
| `assets/scripts/roguelike/controllers/ai_turn_controller.lua` | AI decision making |

### Acceptance Criteria
- [ ] Player entity receives TurnActorComponent and ControllerComponent(type=Player)
- [ ] AI entity receives ControllerComponent(type=AI)
- [ ] Pressing arrow key queues MoveAction (not executed immediately)
- [ ] AI computes path to player and moves toward it each turn
- [ ] Grid position change triggers Transform update (verified by visual position)
- [ ] Transform position stays synchronized with grid position (no drift)
- [ ] Multi-actor turns work: player acts, then AI acts, repeat

### Verification Checklist
```bash
# After Phase 5:
# 1. Spawn player at (5,5) with TurnActorComponent(speed=100)
# 2. Spawn 2 enemies at (5,10) and (10,5) with speed=80
# 3. Advance turn 5 times
# 4. Verify: Player can move with arrows, enemies chase toward player
# 5. Verify: Turn order is consistent (player acts after accumulating 100 energy)
```

---

## Phase 6: Game Systems (Deferred - Beyond Vertical Slice)

**Goal**: Inventory, equipment, status effects.

**Complexity**: M | **Duration**: 2-3 days | **Depends On**: Phase 2, 5

### Note
This phase is **DEFERRED** for the vertical slice. Include if time permits after Phase 5 verification.

### Recommendation
**Lua-first implementation**. You already have patterns for this in `core/` modules.

### What to Build

#### Inventory (Lua)
```lua
-- assets/scripts/roguelike/systems/inventory.lua
local Inventory = {}

function Inventory.new(capacity)
    return {
        items = {},
        capacity = capacity or 20,
    }
end

function Inventory.addItem(inv, item)
    if #inv.items >= inv.capacity then
        return false, "Inventory full"
    end
    table.insert(inv.items, item)
    signal.emit("inventory_changed", inv)
    return true
end

function Inventory.removeItem(inv, item)
    for i, v in ipairs(inv.items) do
        if v == item then
            table.remove(inv.items, i)
            signal.emit("inventory_changed", inv)
            return true
        end
    end
    return false
end

return Inventory
```

#### Status Effects (Lua)
```lua
-- assets/scripts/roguelike/systems/status_effects.lua
local StatusEffects = {}

function StatusEffects.apply(entity, effectDef)
    local script = getScriptTableFromEntityID(entity)
    script.statusEffects = script.statusEffects or {}

    table.insert(script.statusEffects, {
        id = effectDef.id,
        turnsRemaining = effectDef.duration,
        onTurnStart = effectDef.onTurnStart,
        onTurnEnd = effectDef.onTurnEnd,
    })
end

function StatusEffects.tickAll(entity)
    local script = getScriptTableFromEntityID(entity)
    if not script.statusEffects then return end

    for i = #script.statusEffects, 1, -1 do
        local effect = script.statusEffects[i]

        if effect.onTurnEnd then
            effect.onTurnEnd(entity, effect)
        end

        effect.turnsRemaining = effect.turnsRemaining - 1
        if effect.turnsRemaining <= 0 then
            table.remove(script.statusEffects, i)
            signal.emit("status_effect_expired", entity, effect.id)
        end
    end
end

return StatusEffects
```

### Prism References
- `extra/inventory.lua`
- `extra/equipment.lua`
- `extra/condition.lua` (status effects)

---

## Phase 7: Level/Map Generation (Deferred - Beyond Vertical Slice)

**Goal**: Procedural dungeon generation.

**Complexity**: L | **Duration**: 2-3 days | **Depends On**: Phase 0, 1

### Note
This phase is **DEFERRED** for the vertical slice. Use hand-crafted LDtk maps instead. Include if time permits.

### What to Build

#### Lua Level Builder
```lua
-- assets/scripts/roguelike/gen/level_builder.lua
local LevelBuilder = {}

function LevelBuilder.new(width, height)
    return {
        width = width,
        height = height,
        tiles = {},       -- 2D array of tile types
        spawns = {},      -- { { type="player", x=5, y=5 }, ... }
    }
end

function LevelBuilder.fill(builder, tileType)
    for y = 1, builder.height do
        builder.tiles[y] = {}
        for x = 1, builder.width do
            builder.tiles[y][x] = tileType
        end
    end
    return builder
end

function LevelBuilder.setTile(builder, x, y, tileType)
    if builder.tiles[y] then
        builder.tiles[y][x] = tileType
    end
    return builder
end

function LevelBuilder.addSpawn(builder, spawnType, x, y, data)
    table.insert(builder.spawns, {
        type = spawnType,
        x = x,
        y = y,
        data = data or {},
    })
    return builder
end

function LevelBuilder.build(builder)
    -- Convert to GridWorld-compatible format
    return {
        width = builder.width,
        height = builder.height,
        tiles = builder.tiles,
        spawns = builder.spawns,
    }
end

return LevelBuilder
```

#### Simple Dungeon Generator
```lua
-- assets/scripts/roguelike/gen/rooms_and_corridors.lua
local LevelBuilder = require("roguelike.gen.level_builder")

local function generateDungeon(width, height, roomCount)
    local builder = LevelBuilder.new(width, height)
    builder:fill(1)  -- Fill with walls

    local rooms = {}

    -- Place random rooms
    for i = 1, roomCount do
        local roomW = math.random(4, 8)
        local roomH = math.random(4, 8)
        local roomX = math.random(2, width - roomW - 1)
        local roomY = math.random(2, height - roomH - 1)

        -- Carve room
        for y = roomY, roomY + roomH - 1 do
            for x = roomX, roomX + roomW - 1 do
                builder:setTile(x, y, 0)  -- floor
            end
        end

        table.insert(rooms, { x = roomX + roomW/2, y = roomY + roomH/2 })
    end

    -- Connect rooms with corridors
    for i = 2, #rooms do
        local prev = rooms[i-1]
        local curr = rooms[i]

        -- L-shaped corridor
        for x = math.min(prev.x, curr.x), math.max(prev.x, curr.x) do
            builder:setTile(math.floor(x), math.floor(prev.y), 0)
        end
        for y = math.min(prev.y, curr.y), math.max(prev.y, curr.y) do
            builder:setTile(math.floor(curr.x), math.floor(y), 0)
        end
    end

    -- Place player in first room
    builder:addSpawn("player", math.floor(rooms[1].x), math.floor(rooms[1].y))

    -- Place enemies in other rooms
    for i = 2, #rooms do
        builder:addSpawn("enemy", math.floor(rooms[i].x), math.floor(rooms[i].y))
    end

    return builder:build()
end

return { generate = generateDungeon }
```

### Prism References
- `geometer/levelbuilder.lua`
- `engine/core/levelbuilder.lua`

---

## Vertical Slice Definition

**Goal**: Smallest playable subset that proves the system works end-to-end.

### What's Included (Critical Path)
1. ✅ Phase 0: Grid foundation (coordinates, world conversions)
2. ✅ Phase 1: Single LDtk map loading with occupancy
3. ✅ Phase 2: Turn loop (player + 1 AI enemy, energy-based scheduling)
4. ✅ Phase 3: Basic FOV (8-radius visibility, explored tiles)
5. ✅ Phase 4: A* pathfinding (4-way movement, wall avoidance)
6. ✅ Phase 5: Player/AI controllers (keyboard input, chasing behavior)

### What's NOT in Vertical Slice (Deferral Justified)
- ❌ Phase 6: Inventory/equipment (can add items later)
- ❌ Phase 7: Procgen (use hand-crafted LDtk map, procgen is enhancement)
- ❌ Multi-tile actors (single-tile only)
- ❌ Status effects (simple HP tracking sufficient)
- ❌ Combat animations (instant attacks acceptable)
- ❌ Sound/music (visual only)

### Vertical Slice Gameplay Flow
```
INIT:
  1. Load LDtk map ("tutorial_dungeon") → GridWorld (80x50)
  2. Spawn player at (5, 5) with speed=100
  3. Spawn 1 enemy at (30, 30) with speed=80
  4. Camera focuses on player

TURN LOOP:
  5. TurnScheduler picks current actor (energy-based)
  6. If player:
     - Await keyboard (↑↓←→ or WASD)
     - Queue MoveAction if possible
  7. If enemy:
     - Pathfind to player using A*
     - Queue MoveAction if adjacent to player, or melee attack
  8. Resolve queued action (update grid occupancy)
  9. Emit signal: "actor_moved" (triggers FOV update and animation)
  10. FOV recomputes (visible + explored)
  11. Render: map with visibility tinting + actors + FOV debug overlay
  12. If player.health <= 0: GAME OVER
  13. Repeat from step 5

END: Player defeated or quit
```

### Success Criteria (Minimal)
- Player can move around the map with arrow keys
- Enemy pursues player toward player position
- FOV reveals tiles in radius 8, explored tiles dim after moving away
- Turn order is deterministic (same seed = same turn order)
- No crashes or undefined behavior
- Runs at 60fps on desktop
- No desync between grid position and render transform

**Estimated Time**: 5-7 days of focused development

---

## Risk Mitigation & Decisions

### Risk 1: Two Coordinate Spaces
**Problem**: Grid coords vs world/physics coords cause bugs (e.g., physics body moves but grid doesn't sync).

**Solution**:
- Grid is authoritative for turn-based mode
- MovementModeComponent { GridTurn | RealtimePhysics } per entity
- Turn actors: disable Chipmunk physics body, use grid position only
- Real-time actors: ignore grid position, use Transform + physics body
- Sync Transform FROM grid position (one direction only)

**Decision Point**: Will this game use BOTH turn-based AND real-time entities simultaneously?
- If YES: Implement MovementModeComponent as described
- If NO: Assume all gameplay is turn-based, simplify (no dual-mode needed)

**Failure Mode**: If both modes move the same entity in one frame, you will see jitter or double-moves. Enforce a single authoritative source per entity.

### Risk 2: Lua Script Initialization Order
**Problem**: Data assigned after `registry:add_script()` is lost (per your CLAUDE.md).

**Solution**: When spawning roguelike actors, follow this order:
```lua
-- WRONG - gridPos lost after attach_ecs
local script = EntityType {}
script:attach_ecs { ... }
script.gridPos = { x = 5, y = 5 }  -- LOST!

-- CORRECT - gridPos set before attach_ecs
local script = EntityType {}
script.gridPos = { x = 5, y = 5 }  -- FIRST
script:attach_ecs { ... }          -- LAST
```
See `src/systems/scripting/scripting_system.cpp:init_script()` for lifecycle details.

### Risk 3: LOS Algorithm Assumptions
**Problem**: `src/systems/line_of_sight/line_of_sight.cpp` assumes globals (`globals::map`, `globals::getWorldWidth/Height`) and specific components, which may not match GridWorld.

**Solution**: Before extending LOS:
1. Review line_of_sight.cpp to identify all globals/assumptions
2. Wrap blocking checks (light/movement) as callbacks:
   ```cpp
   // Instead of: if (globals::map[x][y].blocksLight)
   // Use: if (blocksLightCallback(x, y))
   ```
3. Write unit tests for LOS with mock grid
4. If too tightly coupled, copy algorithm to `roguelike/fov_system.cpp` and adapt

**Decision Point**: Can you refactor LOS to accept callbacks, or does it require full reimplementation?

### Risk 5: Action/Animation Coupling
**Problem**: If actions directly move transforms and also trigger animations, state can diverge (grid vs render).

**Solution**: Make grid updates authoritative, and emit a signal like "actor_moved" for animation/FX layers to respond.

### Risk 4: Phase 2 Scope Creep
**Problem**: Turn system touches scheduler, input, signals, animation - can explode to 2+ weeks.

**Solution**: Minimal turn system = TurnScheduler + 3 actions (Move, Wait, Attack). Leave out:
- Complex action validation chains
- Undo/redo
- Async action resolution
- Damage/HP calculations (stub with placeholder)
Add these AFTER vertical slice works.

**Guardrail**: If Phase 2 exceeds 4 days, freeze new features and finish vertical slice checks first.

---

## File Summary

### New C++ Files
```
src/systems/roguelike/
├── grid_types.hpp
├── grid_world.hpp/.cpp
├── grid_math.hpp
├── grid_map_from_ldtk.hpp/.cpp
├── turn/
│   ├── turn_components.hpp
│   ├── turn_scheduler.hpp/.cpp
│   └── turn_system.hpp/.cpp
├── fov/
│   ├── fov_components.hpp
│   └── fov_system.hpp/.cpp
├── path/
│   ├── grid_astar.hpp/.cpp
│   └── path_components.hpp
└── actor/
    ├── actor_components.hpp
    └── grid_movement_system.hpp/.cpp
```

### New Lua Files
```
assets/scripts/roguelike/
├── grid_config.lua
├── tile_defs.lua
├── render_visibility.lua
├── actions/
│   ├── action_base.lua
│   ├── move.lua
│   ├── wait.lua
│   └── melee.lua
├── controllers/
│   ├── player_turn_controller.lua
│   └── ai_turn_controller.lua
├── systems/
│   ├── inventory.lua
│   ├── equipment.lua
│   └── status_effects.lua
└── gen/
    ├── level_builder.lua
    └── rooms_and_corridors.lua
```

---

## Next Steps

1. **Review this plan** - Ask questions, adjust scope
2. **Phase 0-1 first** - Get grid foundation working
3. **Vertical slice** - Prove turn loop works before adding features
4. **Iterate** - Add systems as needed for your game

---

## Appendix: Prism System Details

### Object System
```lua
-- Prism's inheritance system
local MyClass = prism.Object:extend("MyClass")
function MyClass:new()
    self.super.new(self)
    -- custom initialization
end
```
**Adaptation**: Use EnTT ECS instead. Components are data, systems are behavior.

### Component/Entity Pattern
```lua
-- Prism components are data + optional behavior
local MyComponent = prism.Component:extend("MyComponent")
MyComponent.requirements = { prism.components.Position }  -- Dependencies

function MyComponent:perform(level, actor, target)
    -- component logic
end
```
**Adaptation**: C++ components are pure data. Lua scripts attach logic via ScriptComponent.

### System Lifecycle
```lua
-- Prism systems have hooks throughout game loop
local MySystem = prism.System:extend("MySystem")

function MySystem:beforeAction(level, actor, action)
    -- runs before any action
end

function MySystem:onMove(level, actor, from, to)
    -- runs when entity moves
end

function MySystem:onYield(level, event)
    -- runs when coroutine yields
end
```
**Adaptation**: Emit signals from turn system. Lua scripts subscribe to signals they care about.

### Action Pattern
```lua
-- All game actions extend this
local MoveAction = prism.Action:extend("MoveAction")

function MoveAction:hasRequisiteComponents(entity)
    return entity:has(prism.components.Position)
end

function MoveAction:canPerform(level, ...)
    -- validation logic
    return true
end

function MoveAction:perform(level, ...)
    -- effect logic
end
```
**Adaptation**: Keep this pattern in Lua. C++ TurnSystem invokes Lua `action:perform()`.

### FOV Algorithm
Prism uses **symmetric shadowcasting** with quadrant optimization:
- Divide FOV into 4 quadrants
- Use recursive row-by-row scanning
- Track slopes for wall/floor boundaries
- Cache results in BooleanBuffer

**Adaptation**: Extend your existing C++ LOS with Prism's quadrant math.

### A* Pathfinding
```lua
-- Prism's A* accepts callbacks
local path = prism.astar(start, goal,
    function(x, y) return not isWall(x, y) end,  -- passable
    function(x, y) return terrainCost[x][y] end,   -- cost
    minDistance,
    distanceType
)
```
**Adaptation**: Implement similar callback-based A* in C++. Expose to Lua for dynamic costs.

---

## Implementation Checklist

### Phase 0: Foundation
- [ ] Create `src/systems/roguelike/` directory structure
- [ ] Implement GridCoord/GridRect types
- [ ] Add coordinate conversion utilities (world_to_grid, grid_to_world)
- [ ] Implement GridWorld class: `blocksMovement()`, `blocksLight()`, occupancy tracking
- [ ] Add GridPositionComponent to `src/components/components.hpp`
- [ ] Bind grid helpers to Lua via Sol2
- [ ] Unit test: grid operations (out-of-bounds checks, coordinate round-trip)
- [ ] Build succeeds with no warnings
- [ ] Lua can access `registry` and create a test entity via `script:attach_ecs { ... }`

### Phase 1: Map System
- [ ] Implement LDtk IntGrid → GridWorld loader
- [ ] Parse LDtk "collision" layer and map values → tile flags
- [ ] Create `assets/scripts/roguelike/tile_defs.lua` with tile property table
- [ ] Test map loading with sample LDtk level (verify no crashes)
- [ ] Verify occupancy tracking: same cell = error or replacement
- [ ] Build + run test: load map, print tile at (5,5)
- [ ] Decide how GridWorld stores tile flags vs tile type (bitmask vs enum) and document it

### Phase 2: Turn Core ⭐ CRITICAL
- [ ] Implement TurnScheduler with energy accumulation + selection
- [ ] Create TurnActorComponent, PendingActionComponent, TurnState
- [ ] Implement TurnSystem::update() with 3 phases (AwaitingInput, Resolving, Animating)
- [ ] Write action_base.lua: canPerform(), perform(), getCost()
- [ ] Implement MoveAction: check bounds, occupancy, exec grid update
- [ ] Implement WaitAction (stub)
- [ ] Connect player input (arrow keys) to queue MoveAction
- [ ] Test: single player can move around without energy resets
- [ ] Test: turn determinism with seeded scheduler
- [ ] Emit signals on turn events (use signal.emit)
- [ ] Decide action execution context data shape (what ctx contains) and document it

### Phase 3: FOV System
- [ ] Create VisionComponent and VisibilityMapComponent
- [ ] Review `src/systems/line_of_sight/line_of_sight.cpp` - refactor for callbacks or copy
- [ ] Implement FOVSystem::recompute() calling wrapped LOS
- [ ] Mark tiles visible/explored in VisibilityMapComponent
- [ ] Create `assets/scripts/roguelike/render_visibility.lua` for tinting
- [ ] Hook FOV recompute to `signal.register("actor_moved", ...)`
- [ ] Test: FOV updates when player moves
- [ ] Test: explored tiles stay visible but dimmed
- [ ] Test: LOS respects blocking tiles from `GridWorld`

### Phase 4: Pathfinding
- [ ] Decide: use `include/fudge_pathfinding/astar_search.h` or implement from scratch
- [ ] Implement GridAStar::findPath() with callbacks for passable/cost
- [ ] Expose `grid.find_path()` to Lua (returns table of steps)
- [ ] Test: simple maze solving (no path, optimal path, diagonal handling)
- [ ] Test: performance on 80x50 grid worst-case
- [ ] Decide how to handle diagonal corner-cutting (disallow passing between two blocked orthogonals)

### Phase 5: Actors & Controllers
- [ ] Create GridMovementComponent (moveCost, canDiagonal, blocksOthers)
- [ ] Implement GridMovementSystem::syncTransformFromGrid()
- [ ] Create `assets/scripts/roguelike/controllers/player_turn_controller.lua`
  - Read arrow key input → queue MoveAction
- [ ] Create `assets/scripts/roguelike/controllers/ai_turn_controller.lua`
  - Pathfind to player position → queue MoveAction
- [ ] Spawn test scene: player + 2 AI enemies with different speeds
- [ ] Test: player can move, enemies act on their turns
- [ ] Test: turn order respects speed/energy
- [ ] Test: enemy chases player when visible
- [ ] Decide how to select player entity for AI context (tag component vs singleton in registry ctx)

### Vertical Slice Final Verification
- [ ] Load tutorial LDtk map
- [ ] Spawn player at (5,5) + 1 enemy at (30,30)
- [ ] Run for 10 turns, verify:
  - No crashes
  - Player moves when key pressed
  - Enemy moves toward player
  - Turn order is consistent
  - FOV updates correctly
- [ ] Check frame rate: consistently 60fps

### Phase 6 & 7: Post-Vertical Slice
- [ ] Implement inventory.lua (if time permits)
- [ ] Implement status_effects.lua (if time permits)
- [ ] Implement level_builder.lua + rooms_and_corridors.lua (optional, low priority)

---

## What NOT to Port vs What to Adapt

### ❌ Don't Port
- Spectrum's terminal renderer - You have Raylib sprites
- Prism's Object:extend() inheritance - You have EnTT ECS
- Geometer's in-game editor - Optional, defer indefinitely
- Prism's coroutine-based turnhandler - Use state machine instead
- Full entity composition system (Prism's Component) - Use ECS components

### ✅ Adapt Heavily (Proven Patterns)
- Action pattern - Keep in Lua, C++ calls Lua `action:perform()`
- Turn scheduler (energy-based) - C++ owns state/scheduling, Lua owns decisions
- FOV algorithm - Extend existing C++ LOS with Grid wrapper
- Pathfinding (A* with callbacks) - New C++ grid A*, Lua-friendly bindings
- Level builder pattern - Lua for content builders, C++ for data loading

### Critical Success Metrics (Vertical Slice)
- [ ] Player moves with arrow keys (no lag)
- [ ] FOV reveals tiles in 8-radius, explored tiles dim after moving away
- [ ] Enemy chases player using pathfinding (visible chasing behavior)
- [ ] Turn order is deterministic (seed-based scheduling reproducible)
- [ ] Actions queue and resolve in correct phase order
- [ ] 60fps maintained on desktop, no crashes for 10+ turns
- [ ] Can load hand-crafted LDtk map (procgen deferred)

### Optional Enhancements (Post-Vertical Slice)
- [ ] Inventory system with UI panels
- [ ] Status effects with turn-based duration
- [ ] Procedural dungeon generation
- [ ] Combat animations and sound
- [ ] Save/load game state
- [ ] Multiple floors/levels

---

## Decision Matrix

When in doubt, ask these questions:

| Question | Yes → | No → |
|----------|-------|------|
| Does this exist in current engine already? | Use/extend it | Build new |
| Is this on critical path to playable? | Do it now | Defer to Phase 6-7 |
| Can this be Lua-only? | Implement in Lua | Consider C++ if perf critical |
| Does this block other phases? | Unblock it first | Can work in parallel |
| Will this take >1 day? | Split into smaller tasks | Keep in single task |

---

## Integration Checklist (Copy-Paste)

### Before Starting Phase 0
```
[ ] git branch feature/roguelike-migration
[ ] Review claude.md, SYSTEM_ARCHITECTURE.md
[ ] Verify CMake builds: just build-debug
[ ] Verify Lua scripts load: Lua/C++ boundary works
```

### After Each Phase
```
[ ] Code compiles with no warnings: just build-debug
[ ] Unit tests pass: just test
[ ] Manual verification: run executable, test specific feature
[ ] Document any gotchas in this plan
[ ] Commit with clear message: "Phase N: <description>" (if you are committing)
```

### Before Claiming Vertical Slice Done
```
[ ] Load tutorial map without crashes
[ ] Player can move 10 steps with keyboard
[ ] Enemy visible chasing player for 20 turns
[ ] FOV working: visited tiles dim, new tiles bright
[ ] No memory leaks: run under Valgrind or ASAN
[ ] Frame rate stable: check in profiler (Tracy if available)
```

---

*Document Version: 2.0 (Refined)*
*Last Updated: 2026-01-20*
*Based on: PrismRL/prism (master branch) and TheGameJamTemplate architecture analysis*
*Author Note: This plan prioritizes vertical slice over completeness. Full roguelike features (inventory, status effects, procgen) are explicitly deferred.*
