# Codebase Improvements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement 9 codebase improvements covering compilation speed, runtime performance, and developer experience.

**Architecture:** Sequential phases - quick fixes first, then build improvements, then header refactoring, then runtime enhancements. Each task isolated with its own commit.

**Tech Stack:** C++20, Lua 5.4, Sol2, EnTT, Raylib, CMake, Just

---

## Phase 1: Zero-Risk Quick Fixes

### Task 1: Enable Auto-Scaling Build Parallelism

**Files:**
- Modify: `justfile:36,51,59`

**Step 1: Update justfile build commands**

Replace `-j 10` with `-j` in three locations:

```just
# Line 36 (in build-with-config)
@cmake --build ./build --config {{config}} --target raylib-cpp-cmake-template -j --

# Line 51 (in build-debug-fast)
cmake --build build-debug --target raylib-cpp-cmake-template -j --

# Line 55 (in build-release-fast)
cmake --build build-release --target raylib-cpp-cmake-template -j --
```

**Step 2: Verify change**

Run: `grep -n "\-j" justfile | head -10`
Expected: Lines show `-j --` or `-j` without number

**Step 3: Commit**

```bash
git add justfile
git commit -m "build: auto-scale parallelism instead of hardcoded -j 10"
```

---

### Task 2: Add EmmyLua Type Stubs for IDE Autocomplete

**Files:**
- Create: `assets/scripts/types/init.lua`
- Create: `.luarc.json`

**Step 1: Create types directory**

Run: `mkdir -p assets/scripts/types`

**Step 2: Create type stubs file**

Create `assets/scripts/types/init.lua`:

```lua
---@meta
-- EmmyLua type definitions for C++ bindings and Lua modules
-- This file provides IDE autocomplete support

---------------------------------------------------------------------------
-- Core C++ Bindings
---------------------------------------------------------------------------

---@class Registry
---@field create fun(): number Create a new entity
---@field valid fun(entity: number): boolean Check if entity is valid
---@field destroy fun(entity: number) Destroy an entity
registry = {}

---@class ComponentCache
---@field get fun(entity: number, component_type: any): any Get component from cache
---@field invalidate fun(entity: number) Invalidate cached components for entity
---@field begin_frame fun() Begin batch mode (skip per-access frame checks)
---@field end_frame fun() End batch mode
component_cache = {}

---------------------------------------------------------------------------
-- Q.lua - Quick Transform Operations
---------------------------------------------------------------------------

---@class Q
---@field move fun(entity: number, x: number, y: number) Move entity to absolute position
---@field center fun(entity: number): number?, number? Get entity center (x, y or nil, nil)
---@field offset fun(entity: number, dx: number, dy: number) Move relative to current position
Q = {}

---------------------------------------------------------------------------
-- EntityBuilder
---------------------------------------------------------------------------

---@class EntityBuilderOptions
---@field sprite? string Sprite name
---@field position? {x: number, y: number} Initial position
---@field size? number[] Width and height {w, h}
---@field shadow? boolean Add shadow component
---@field data? table Custom script data
---@field interactive? table Interactive options (hover, click, collision)
---@field state? any Initial state
---@field shaders? string[] Shader names to apply

---@class EntityBuilder
---@field create fun(opts: EntityBuilderOptions): number, table Create entity with full options
---@field simple fun(sprite: string, x: number, y: number, w: number, h: number): number Create simple entity
---@field validated fun(ScriptType: table, entity: number, data?: table): table Create script with validation
EntityBuilder = {}

---------------------------------------------------------------------------
-- PhysicsBuilder
---------------------------------------------------------------------------

---@class PhysicsBuilder
---@field for_entity fun(entity: number): PhysicsBuilder Start building physics for entity
---@field circle fun(): PhysicsBuilder Set shape to circle
---@field box fun(): PhysicsBuilder Set shape to box
---@field tag fun(tag: string): PhysicsBuilder Set collision tag
---@field bullet fun(): PhysicsBuilder Enable bullet mode (CCD)
---@field sensor fun(): PhysicsBuilder Make sensor (no physical collision)
---@field friction fun(f: number): PhysicsBuilder Set friction coefficient
---@field density fun(d: number): PhysicsBuilder Set density
---@field collideWith fun(tags: string[]): PhysicsBuilder Set collision targets
---@field apply fun() Apply physics configuration
PhysicsBuilder = {}

---------------------------------------------------------------------------
-- ShaderBuilder
---------------------------------------------------------------------------

---@class ShaderBuilder
---@field for_entity fun(entity: number): ShaderBuilder Start building shaders for entity
---@field add fun(shader_name: string, params?: table): ShaderBuilder Add shader with optional params
---@field remove fun(shader_name: string): ShaderBuilder Remove shader
---@field apply fun() Apply shader configuration
ShaderBuilder = {}

---------------------------------------------------------------------------
-- Timer API
---------------------------------------------------------------------------

---@class TimerOptions
---@field delay number Delay in seconds
---@field action fun() Callback function
---@field tag? string Optional tag for cancellation
---@field times? number Number of repetitions (for every_opts)
---@field immediate? boolean Run immediately then repeat (for every_opts)

---@class TimerSequence
---@field wait fun(seconds: number): TimerSequence Wait for duration
---@field do_now fun(action: fun()): TimerSequence Execute action immediately
---@field start fun() Start the sequence

---@class Timer
---@field after fun(delay: number, action: fun(), tag?: string) One-shot timer
---@field after_opts fun(opts: TimerOptions) One-shot timer with options
---@field every fun(delay: number, action: fun(), tag?: string) Repeating timer
---@field every_opts fun(opts: TimerOptions) Repeating timer with options
---@field cancel fun(tag: string) Cancel timer by tag
---@field sequence fun(tag?: string): TimerSequence Create timer sequence
timer = {}

---------------------------------------------------------------------------
-- Signal/Event System (HUMP)
---------------------------------------------------------------------------

---@class Signal
---@field emit fun(event: string, ...: any) Emit event with arguments
---@field register fun(event: string, handler: fun(...: any)) Register event handler
---@field remove fun(handler: fun()) Remove specific handler
---@field clear fun(event: string) Clear all handlers for event
signal = {}

---------------------------------------------------------------------------
-- Logging
---------------------------------------------------------------------------

---@param ... any
log_debug = function(...) end

---@param ... any
log_info = function(...) end

---@param ... any
log_warn = function(...) end

---@param ... any
log_error = function(...) end

---------------------------------------------------------------------------
-- Entity Helpers
---------------------------------------------------------------------------

---@param entity number
---@return boolean
ensure_entity = function(entity) end

---@param entity number
---@return boolean
ensure_scripted_entity = function(entity) end

---@param entity number
---@return table?
safe_script_get = function(entity) end

---@param entity number
---@param field string
---@param default any
---@return any
script_field = function(entity, field, default) end

---@param entity number
---@return table?
getScriptTableFromEntityID = function(entity) end

---------------------------------------------------------------------------
-- Physics Functions
---------------------------------------------------------------------------

---@class Physics
---@field create_physics_for_transform fun(registry: Registry, physics_manager: any, entity: number, world_name: string, config: table)
---@field set_sync_mode fun(registry: Registry, entity: number, mode: number)
---@field enable_collision_between_many fun(world: any, tag: string, targets: string[])
---@field update_collision_masks_for fun(world: any, tag: string, targets: string[])
physics = {}

---@class PhysicsManager
---@field get_world fun(name: string): any Get physics world by name
PhysicsManager = {}

---------------------------------------------------------------------------
-- Draw Commands
---------------------------------------------------------------------------

---@class Draw
---@field textPro fun(layer: number, opts: table, z?: number, space?: string)
---@field local_command fun(entity: number, cmd_type: string, opts: table, meta?: table)
draw = {}

---------------------------------------------------------------------------
-- Misc Globals
---------------------------------------------------------------------------

---@type number
PLANNING_STATE = 0

---@param name string
---@param entity number
setEntityAlias = function(name, entity) end

---@param name string
---@return number?
getEntityByAlias = function(name) end
```

**Step 3: Create .luarc.json for VS Code**

Create `.luarc.json` at project root:

```json
{
  "workspace.library": [
    "assets/scripts/types"
  ],
  "diagnostics.globals": [
    "registry",
    "component_cache",
    "signal",
    "timer",
    "physics",
    "draw",
    "log_debug",
    "log_info",
    "log_warn",
    "log_error",
    "ensure_entity",
    "ensure_scripted_entity",
    "safe_script_get",
    "script_field",
    "getScriptTableFromEntityID",
    "setEntityAlias",
    "getEntityByAlias",
    "PLANNING_STATE"
  ],
  "runtime.version": "Lua 5.4",
  "runtime.path": [
    "assets/scripts/?.lua",
    "assets/scripts/?/init.lua"
  ]
}
```

**Step 4: Verify files created**

Run: `ls -la assets/scripts/types/init.lua .luarc.json`
Expected: Both files exist

**Step 5: Commit**

```bash
git add assets/scripts/types/init.lua .luarc.json
git commit -m "dx: add EmmyLua type stubs for IDE autocomplete"
```

---

## Phase 2: Isolated Performance Fixes

### Task 3: Fix MakeKey() String Allocation in Physics

**Files:**
- Modify: `src/systems/physics/physics_world.hpp:48-50`
- Modify: `src/systems/physics/physics_world.hpp` (callback map types)
- Modify: `src/systems/physics/physics_world.cpp` (usages)

**Step 1: Update MakeKey function and add key type**

In `src/systems/physics/physics_world.hpp`, find around line 48:

```cpp
// OLD CODE:
static inline std::string MakeKey(const std::string& a, const std::string& b){
    return (a <= b) ? (a + ":" + b) : (b + ":" + a);
}
```

Replace with:

```cpp
// Zero-allocation collision key type
struct CollisionKey {
    std::string_view first;
    std::string_view second;

    bool operator==(const CollisionKey& other) const {
        return first == other.first && second == other.second;
    }

    bool operator<(const CollisionKey& other) const {
        if (first != other.first) return first < other.first;
        return second < other.second;
    }
};

struct CollisionKeyHash {
    std::size_t operator()(const CollisionKey& k) const {
        std::size_t h1 = std::hash<std::string_view>{}(k.first);
        std::size_t h2 = std::hash<std::string_view>{}(k.second);
        return h1 ^ (h2 << 1);
    }
};

static inline CollisionKey MakeKey(std::string_view a, std::string_view b) {
    return (a <= b) ? CollisionKey{a, b} : CollisionKey{b, a};
}
```

**Step 2: Update callback map types**

In the same header, find the callback map declarations (around lines 60-80) and update:

```cpp
// OLD:
std::unordered_map<std::string, std::function<void(...)>> collisionEnter;
std::unordered_map<std::string, std::function<void(...)>> collisionExit;
std::unordered_map<std::string, std::function<void(...)>> triggerEnter;
std::unordered_map<std::string, std::function<void(...)>> triggerExit;

// NEW:
std::unordered_map<CollisionKey, std::function<void(cpArbiter*, cpSpace*, entt::entity, entt::entity)>, CollisionKeyHash> collisionEnter;
std::unordered_map<CollisionKey, std::function<void(cpArbiter*, cpSpace*, entt::entity, entt::entity)>, CollisionKeyHash> collisionExit;
std::unordered_map<CollisionKey, std::function<void(cpArbiter*, cpSpace*, entt::entity, entt::entity)>, CollisionKeyHash> triggerEnter;
std::unordered_map<CollisionKey, std::function<void(cpArbiter*, cpSpace*, entt::entity, entt::entity)>, CollisionKeyHash> triggerExit;
```

**Step 3: Update physics_world.cpp usages**

Find all uses of `MakeKey` and ensure they work with the new return type. The usages should work without changes since we're using the same function name.

**Step 4: Build and test**

Run: `just build-debug && just test`
Expected: Build succeeds, all tests pass

**Step 5: Commit**

```bash
git add src/systems/physics/physics_world.hpp src/systems/physics/physics_world.cpp
git commit -m "perf: eliminate string allocation in physics collision callbacks

Replace std::string concatenation with CollisionKey struct using
string_view pairs. Zero heap allocations per collision frame."
```

---

### Task 4: Add EntityBuilder.validated() Helper

**Files:**
- Modify: `assets/scripts/core/entity_builder.lua`

**Step 1: Add validated() function**

In `assets/scripts/core/entity_builder.lua`, add after the existing `EntityBuilder.simple()` function:

```lua
--- Create a script with validated initialization order.
--- This prevents the common mistake of assigning data after attach_ecs().
--- @param ScriptType table The script class (extends Node)
--- @param entity number The entity ID to attach to
--- @param data table? Optional data to assign to script before attach
--- @return table script The initialized script table
function EntityBuilder.validated(ScriptType, entity, data)
    local script = ScriptType {}

    -- Assign all data BEFORE attach_ecs (critical!)
    if data then
        for k, v in pairs(data) do
            script[k] = v
        end
    end

    -- Now safe to attach
    script:attach_ecs { create_new = false, existing_entity = entity }

    return script
end
```

**Step 2: Verify syntax**

Run: `luac -p assets/scripts/core/entity_builder.lua`
Expected: No output (successful parse)

**Step 3: Build and test**

Run: `just build-debug && just test`
Expected: All tests pass

**Step 4: Commit**

```bash
git add assets/scripts/core/entity_builder.lua
git commit -m "feat(lua): add EntityBuilder.validated() for safe script init

Prevents the common mistake of assigning data after attach_ecs(),
which causes data loss. Enforces correct initialization order."
```

---

## Phase 3: Build System Changes

### Task 5: Expand PCH with Heavy Headers

**Files:**
- Modify: `src/util/common_headers.hpp`

**Step 1: Read current PCH contents**

Run: `cat src/util/common_headers.hpp`

**Step 2: Add heavy headers to PCH**

Add these includes to `src/util/common_headers.hpp` (after existing includes):

```cpp
// Heavy headers - precompile to speed up builds
// These are included in 40+ files each

// EnTT - full header instead of just forward declarations
// (entt/fwd.hpp already included above, but we need full entt for templates)
#include "entt/entt.hpp"

// Sol2 - Lua binding library (included in 45 files)
#include "sol/sol.hpp"

// Raylib - graphics library (included in 47 files)
#include "raylib.h"
```

**Step 3: Clean and rebuild to verify**

Run: `rm -rf build && just build-debug`
Expected: Build succeeds (may be slower first time, faster subsequent)

**Step 4: Run tests**

Run: `just test`
Expected: All tests pass

**Step 5: Commit**

```bash
git add src/util/common_headers.hpp
git commit -m "build: expand PCH with entt/sol2/raylib for faster compiles

These headers are included in 40+ files each. Precompiling them
reduces incremental build times significantly."
```

---

## Phase 4: Header Refactoring

### Task 6: Split physics_lua_bindings.hpp

**Files:**
- Modify: `src/systems/physics/physics_lua_bindings.hpp` (reduce to interface)
- Create: `src/systems/physics/physics_lua_bindings.cpp` (implementations)
- Modify: `CMakeLists.txt` (if needed - likely auto-globbed)

**Step 1: Read current header**

Run: `wc -l src/systems/physics/physics_lua_bindings.hpp`
Expected: ~2389 lines

**Step 2: Create new cpp file with implementations**

Create `src/systems/physics/physics_lua_bindings.cpp` containing all the function bodies from the header. Keep only declarations in the header.

The header should become (~150 lines):

```cpp
#pragma once

#include <sol/forward.hpp>

// Forward declarations
class EngineContext;

namespace physics {

/// Expose all physics bindings to Lua
void exposePhysicsToLua(sol::state& lua, EngineContext* ctx);

/// Expose PhysicsBuilder to Lua
void exposePhysicsBuilderToLua(sol::state& lua, EngineContext* ctx);

/// Expose collision utilities to Lua
void exposeCollisionToLua(sol::state& lua, EngineContext* ctx);

} // namespace physics
```

The cpp file contains all the actual binding implementations.

**Step 3: Build and test**

Run: `just build-debug && just test`
Expected: Build succeeds, all tests pass

**Step 4: Commit**

```bash
git add src/systems/physics/physics_lua_bindings.hpp src/systems/physics/physics_lua_bindings.cpp
git commit -m "refactor: split physics_lua_bindings into header + impl

Reduces header from 2389 lines to ~150 lines. Implementation now
in cpp file, reducing recompilation when bindings change."
```

---

### Task 7: Decompose scripting_functions.cpp

**Files:**
- Modify: `src/systems/scripting/scripting_functions.cpp` (reduce to orchestrator)
- Modify: Multiple system files to add `exposeToLua` functions
- Create: `src/systems/scripting/binding_registry.hpp` (optional, for cleaner pattern)

**Step 1: Identify systems to extract**

The following systems have bindings in scripting_functions.cpp that should be moved to their own files:
- sound_system
- event_system
- camera_system
- input_system
- layer_system
- transform_system
- text_system
- ui_system
- particle_system
- collision_system

**Step 2: Add exposeToLua to each system**

For each system, add a function like:

```cpp
// In sound_system.hpp
namespace sound {
    void exposeToLua(sol::state& lua, EngineContext* ctx);
}

// In sound_system.cpp
void sound::exposeToLua(sol::state& lua, EngineContext* ctx) {
    // Move binding code from scripting_functions.cpp here
    lua.set_function("play_sound", [ctx](const std::string& name) {
        // implementation
    });
}
```

**Step 3: Update scripting_functions.cpp to call system registrations**

```cpp
void initLuaStateWithAllObjectAndFunctionBindings(sol::state& lua, EngineContext* ctx) {
    // Core systems
    sound::exposeToLua(lua, ctx);
    event::exposeToLua(lua, ctx);
    camera::exposeToLua(lua, ctx);
    input::exposeToLua(lua, ctx);
    layer::exposeToLua(lua, ctx);
    transform::exposeToLua(lua, ctx);
    text::exposeToLua(lua, ctx);
    ui::exposeToLua(lua, ctx);
    particle::exposeToLua(lua, ctx);
    collision::exposeToLua(lua, ctx);
    physics::exposePhysicsToLua(lua, ctx);

    // Remaining bindings that don't fit elsewhere
    // ... (should be minimal)
}
```

**Step 4: Build and test**

Run: `just build-debug && just test`
Expected: Build succeeds, all tests pass

**Step 5: Commit**

```bash
git add src/systems/scripting/scripting_functions.cpp src/systems/scripting/scripting_functions.hpp
git add src/systems/sound/*.cpp src/systems/sound/*.hpp
git add src/systems/event/*.cpp src/systems/event/*.hpp
# ... (add all modified system files)
git commit -m "refactor: decompose scripting_functions into self-registering systems

Each system now owns its Lua bindings via exposeToLua().
scripting_functions.cpp is now just an orchestrator (~200 lines).
Adding new system bindings no longer requires editing the monolith."
```

---

## Phase 5: Runtime Enhancements

### Task 8: Add Shader/Texture Batching (Opt-in)

**Files:**
- Modify: `src/systems/layer/layer_command_buffer.hpp` (add fields + flag)
- Modify: `src/systems/layer/layer_command_buffer.cpp` (extend sort)
- Modify: `src/systems/scripting/scripting_functions.cpp` (expose toggle)

**Step 1: Add flag and fields to header**

In `src/systems/layer/layer_command_buffer.hpp`:

```cpp
// Add near top of file, after includes
extern bool g_enableShaderTextureBatching;

// In DrawCommandV2 struct, add:
struct DrawCommandV2 {
    DrawCommandType type;
    void* data;
    int z;
    DrawCommandSpace space = DrawCommandSpace::Screen;
    uint64_t uniqueID = 0;
    uint64_t followAnchor;
    // NEW: For state batching optimization
    unsigned int shader_id = 0;
    unsigned int texture_id = 0;
};
```

**Step 2: Define flag and extend sort in cpp**

In `src/systems/layer/layer_command_buffer.cpp`:

```cpp
// Add at top of file
bool g_enableShaderTextureBatching = false;

// In the sort function, extend the comparator:
if (g_enableStateBatching) {
    std::stable_sort(commands.begin(), commands.end(),
        [](const DrawCommandV2& a, const DrawCommandV2& b) {
            if (a.z != b.z) return a.z < b.z;
            if (a.space != b.space) return a.space < b.space;
            // NEW: Optional shader/texture batching
            if (g_enableShaderTextureBatching) {
                if (a.shader_id != b.shader_id) return a.shader_id < b.shader_id;
                if (a.texture_id != b.texture_id) return a.texture_id < b.texture_id;
            }
            return false;
        });
}
```

**Step 3: Expose toggle to Lua**

In appropriate bindings file:

```cpp
lua.set_function("set_shader_texture_batching", [](bool enabled) {
    g_enableShaderTextureBatching = enabled;
    spdlog::info("Shader/texture batching: {}", enabled ? "enabled" : "disabled");
});

lua.set_function("get_shader_texture_batching", []() {
    return g_enableShaderTextureBatching;
});
```

**Step 4: Build and test**

Run: `just build-debug && just test`
Expected: Build succeeds, all tests pass

**Step 5: Commit**

```bash
git add src/systems/layer/layer_command_buffer.hpp src/systems/layer/layer_command_buffer.cpp
git add src/systems/scripting/scripting_functions.cpp
git commit -m "feat: add opt-in shader/texture batching for draw commands

Adds shader_id and texture_id fields to DrawCommandV2.
When g_enableShaderTextureBatching is true, commands are
sorted to minimize GPU state changes.

Toggle via Lua: set_shader_texture_batching(true/false)
Default: disabled (preserves existing behavior)"
```

---

### Task 9: Generate Unified Lua API Documentation

**Files:**
- Create: `tools/generate_unified_docs.lua`
- Modify: `justfile` (add recipe)

**Step 1: Create documentation generator**

Create `tools/generate_unified_docs.lua`:

```lua
#!/usr/bin/env lua
-- Generate unified Lua API documentation from multiple sources

local output = {}

local function add(line)
    table.insert(output, line)
end

local function add_section(title)
    add("")
    add("## " .. title)
    add("")
end

-- Header
add("# Unified Lua API Reference")
add("")
add("> Auto-generated from binding definitions and api.lua module")
add("")
add("**Last updated:** " .. os.date("%Y-%m-%d"))
add("")

-- Try to load api.lua for documentation
local api_path = "assets/scripts/core/api.lua"
local api_file = io.open(api_path, "r")

if api_file then
    add_section("Core API (from api.lua)")
    add("See `assets/scripts/core/api.lua` for the authoritative documentation table.")
    add("")
    add("Key modules:")
    add("- `registry` - ECS entity management")
    add("- `component_cache` - Cached component access")
    add("- `physics` - Physics world and collision")
    add("- `timer` - Timer and sequence API")
    add("- `signal` - Event pub/sub system")
    add("- `draw` - Drawing commands")
    api_file:close()
end

add_section("Builder APIs")

add("### EntityBuilder")
add("")
add("```lua")
add("local EntityBuilder = require('core.entity_builder')")
add("")
add("-- Full options")
add("local entity, script = EntityBuilder.create({")
add("    sprite = 'kobold',")
add("    position = { x = 100, y = 200 },")
add("    size = { 64, 64 },")
add("    shadow = true,")
add("    data = { health = 100 },")
add("})")
add("")
add("-- Simple creation")
add("local entity = EntityBuilder.simple('sprite', x, y, w, h)")
add("")
add("-- Validated (prevents data-after-attach bug)")
add("local script = EntityBuilder.validated(MyScript, entity, { health = 100 })")
add("```")
add("")

add("### PhysicsBuilder")
add("")
add("```lua")
add("local PhysicsBuilder = require('core.physics_builder')")
add("")
add("PhysicsBuilder.for_entity(entity)")
add("    :circle()")
add("    :tag('projectile')")
add("    :bullet()")
add("    :collideWith({ 'enemy', 'WORLD' })")
add("    :apply()")
add("```")
add("")

add("### ShaderBuilder")
add("")
add("```lua")
add("local ShaderBuilder = require('core.shader_builder')")
add("")
add("ShaderBuilder.for_entity(entity)")
add("    :add('3d_skew_holo', { sheen_strength = 1.5 })")
add("    :add('dissolve', { dissolve = 0.5 })")
add("    :apply()")
add("```")
add("")

add_section("Quick Helpers (Q.lua)")

add("```lua")
add("local Q = require('core.Q')")
add("")
add("Q.move(entity, x, y)       -- Move to absolute position")
add("Q.offset(entity, dx, dy)   -- Move relative")
add("local cx, cy = Q.center(entity)  -- Get center point")
add("```")
add("")

add_section("Timer API")

add("```lua")
add("local timer = require('core.timer')")
add("")
add("-- One-shot")
add("timer.after(2.0, function() print('done') end, 'my_tag')")
add("")
add("-- Repeating")
add("timer.every(0.5, function() print('tick') end, 'heartbeat')")
add("")
add("-- Sequence")
add("timer.sequence('anim')")
add("    :wait(0.5)")
add("    :do_now(function() print('start') end)")
add("    :wait(0.3)")
add("    :do_now(function() print('end') end)")
add("    :start()")
add("")
add("-- Cancel")
add("timer.cancel('my_tag')")
add("```")
add("")

add_section("Event System (Signal)")

add("```lua")
add("local signal = require('external.hump.signal')")
add("")
add("-- Emit event")
add("signal.emit('player_damaged', player_entity, { damage = 25, type = 'fire' })")
add("")
add("-- Register handler")
add("signal.register('player_damaged', function(entity, data)")
add("    log_debug('Player took', data.damage, data.type, 'damage')")
add("end)")
add("```")
add("")

add_section("Common Patterns")

add("### Safe Entity Access")
add("")
add("```lua")
add("if ensure_entity(eid) then")
add("    local script = safe_script_get(eid)")
add("    local health = script_field(eid, 'health', 100)  -- with default")
add("end")
add("```")
add("")

add("### Component Cache")
add("")
add("```lua")
add("local transform = component_cache.get(entity, Transform)")
add("if transform then")
add("    transform.actualX = 100")
add("end")
add("```")
add("")

add_section("Performance Settings")

add("```lua")
add("-- Enable shader/texture batching (reduces GPU state changes)")
add("set_shader_texture_batching(true)")
add("")
add("-- Check current state")
add("local enabled = get_shader_texture_batching()")
add("```")
add("")

add_section("See Also")

add("- `CLAUDE.md` - Quick reference and patterns")
add("- `docs/api/` - Individual API documentation files")
add("- `docs/content-creation/` - Content creation guides")
add("- `assets/scripts/core/api.lua` - Full API documentation table")

-- Output
print(table.concat(output, "\n"))
```

**Step 2: Add justfile recipe**

Add to `justfile`:

```just
# Generate unified Lua API documentation
docs-lua-api:
    lua tools/generate_unified_docs.lua > docs/api/UNIFIED_LUA_API.md
    @echo "Generated docs/api/UNIFIED_LUA_API.md"
```

**Step 3: Generate initial documentation**

Run: `lua tools/generate_unified_docs.lua > docs/api/UNIFIED_LUA_API.md`

**Step 4: Verify output**

Run: `head -50 docs/api/UNIFIED_LUA_API.md`
Expected: Well-formatted markdown documentation

**Step 5: Commit**

```bash
git add tools/generate_unified_docs.lua justfile docs/api/UNIFIED_LUA_API.md
git commit -m "docs: add unified Lua API documentation generator

Creates tools/generate_unified_docs.lua that consolidates API docs
from multiple sources. Run with: just docs-lua-api"
```

---

## Final Steps

### Task 10: Final Verification and Summary

**Step 1: Run full test suite**

Run: `just build-debug && just test`
Expected: All tests pass

**Step 2: Verify all commits**

Run: `git log --oneline -10`
Expected: 9 commits for 9 tasks

**Step 3: Summary report**

Document what was accomplished:
- ✅ Task 1: Justfile parallelism
- ✅ Task 2: EmmyLua type stubs
- ✅ Task 3: MakeKey fix
- ✅ Task 4: EntityBuilder.validated()
- ✅ Task 5: PCH expansion
- ✅ Task 6: Split physics bindings
- ✅ Task 7: Decompose scripting_functions
- ✅ Task 8: Shader/texture batching
- ✅ Task 9: Unified Lua docs

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
