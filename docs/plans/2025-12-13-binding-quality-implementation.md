# Binding Quality Implementation Plan

**Date:** 2025-12-13
**Branch:** feature/binding-quality
**Scope:** 290 incomplete bindings across 15 C++ files

## Summary

Update C++ binding registration calls to include proper `@param` and `@return` annotations so that `chugget_code_definitions.lua` provides full IDE autocomplete with documentation.

## Work Packages

Each package is one C++ file that an agent will update.

### Package 1: TextSystem (62 functions) - HIGHEST PRIORITY
**File:** `src/systems/text/textVer2.cpp`
**Modules:** TextSystem.Text, TextSystem.Character, TextSystem.Builders.TextBuilder
**Issues:** missing_param on Character/Text properties, missing_return on Builder methods

### Package 2: Physics (46 functions)
**File:** `src/systems/physics/physics_lua_bindings.hpp`
**Modules:** physics.*
**Issues:** missing_return on setter functions (SetBullet, SetFriction, etc.)

### Package 3: Steering (13 functions)
**File:** `src/systems/physics/steering.hpp`
**Modules:** steering.*
**Issues:** missing_return on all functions

### Package 4: Global Functions (28 functions)
**File:** `src/systems/scripting/scripting_functions.cpp`
**Modules:** global (Vector2, Vector3, log_error, etc.)
**Issues:** missing_param, plain_text_sig

### Package 5: GameCamera (18 functions)
**File:** `src/systems/camera/camera_bindings.hpp`
**Modules:** GameCamera.*
**Issues:** missing_param, missing_return

### Package 6: Controller Nav (14 functions)
**File:** `src/systems/input/controller_nav.cpp`
**Modules:** controller_nav.*
**Issues:** missing_param, missing_return

### Package 7: Transform (13 functions)
**File:** `src/systems/transform/transform_functions.hpp` or related
**Modules:** Transform.*
**Issues:** missing_param on spring properties

### Package 8: Spring (13 functions)
**File:** `src/systems/spring/spring_lua_bindings.hpp`
**Modules:** Spring.*, spring.*
**Issues:** plain_text_sig, missing_return

### Package 9: Shaders (8 functions)
**File:** `src/systems/shaders/shader_system.cpp`
**Modules:** shaders.*, shader_draw_commands.*
**Issues:** missing_param, missing_return

### Package 10: Layer (7 functions)
**File:** `src/systems/layer/layer.cpp`
**Modules:** layer.*
**Issues:** missing_param

### Package 11: Camera (7 functions)
**File:** `src/systems/camera/camera_bindings.hpp` (same as Package 5)
**Modules:** camera.*
**Issues:** missing_return

### Package 12: EnTT/Registry (7 functions)
**File:** `src/systems/scripting/scripting_functions.cpp` (same as Package 4)
**Modules:** entt.*
**Issues:** plain_text_sig

### Package 13: Scheduler (6 functions)
**File:** TBD (search for scheduler bindings)
**Modules:** scheduler.*
**Issues:** missing_param, plain_text_sig

### Package 14: Smaller Modules (remaining ~40 functions)
**Files:** Various
**Modules:** localization, collision, particle, shader_pipeline, random_utils, etc.

## Pattern to Follow

### Before (incomplete):
```cpp
lua["physics"]["SetBullet"] = [](PhysicsWorld& w, Entity e, bool b) {
    // implementation
};
// OR
rec.bind_function(lua, {"physics"}, "SetBullet",
    [](PhysicsWorld& w, Entity e, bool b) { ... },
    "",  // empty signature
    "Enable CCD"
);
```

### After (complete):
```cpp
rec.bind_function(lua, {"physics"}, "SetBullet",
    [](PhysicsWorld& w, Entity e, bool b) { ... },
    "---@param world PhysicsWorld # The physics world\n"
    "---@param entity Entity # The entity to modify\n"
    "---@param bullet boolean # Enable continuous collision detection\n"
    "---@return nil",
    "Enable CCD for fast-moving bodies to prevent tunneling."
);
```

## Execution Strategy

1. **Parallel dispatch:** Launch agents for each package
2. **Each agent:**
   - Reads the C++ file
   - Identifies binding registrations for its module
   - Infers parameter types from lambda/function signatures
   - Adds `@param` and `@return` annotations
   - Preserves existing descriptions or adds minimal ones
3. **After all agents complete:**
   - Build the game
   - Run it to regenerate definitions
   - Re-run audit to verify 0 incomplete

## Acceptance Criteria

- Audit script reports 0 incomplete bindings
- No compilation errors
- Existing functionality unchanged

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
