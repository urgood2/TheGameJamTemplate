# Codebase Improvements Design

**Date:** 2025-12-18
**Status:** Approved
**Scope:** 9 tasks across compilation, performance, and DX improvements

## Overview

Implement 9 codebase improvements identified from comprehensive analysis, focusing on:
- Compilation time reduction
- Runtime performance fixes
- Developer experience enhancements

## Constraints

- **Testing gate:** `just build-debug && just test` after each task
- **Rollback strategy:** Each task gets separate commit for easy revert
- **Header refactoring:** Sequential (one file at a time)
- **Shader batching:** Opt-in via global flag

## Task Ordering

### Phase 1: Zero-Risk Quick Fixes
1. **Task 2:** Change `-j 10` to `-j` in justfile (~2 min)
2. **Task 3:** Add EmmyLua type stubs for autocomplete (~30 min)

### Phase 2: Isolated Performance Fixes
3. **Task 1:** Fix `MakeKey()` string allocation in physics (~5 min)
4. **Task 5:** Add `EntityBuilder.validated()` helper (~20 min)

### Phase 3: Build System Changes
5. **Task 4:** Expand PCH with entt/sol2/raylib (~15 min)

### Phase 4: Header Refactoring
6. **Task 7:** Split physics_lua_bindings.hpp → interface + impl (~2 hrs)
7. **Task 8:** Decompose scripting_functions.cpp (~4 hrs)

### Phase 5: Runtime Enhancements
8. **Task 6:** Shader/texture batching (opt-in) (~2 hrs)
9. **Task 9:** Generate unified Lua API docs (~1 hr)

## Implementation Details

### Task 1: MakeKey() String Fix

**Location:** `src/systems/physics/physics_world.hpp:48-50`

**Current (allocates per collision):**
```cpp
static inline std::string MakeKey(const std::string& a, const std::string& b){
    return (a <= b) ? (a + ":" + b) : (b + ":" + a);
}
```

**New (zero allocation):**
```cpp
using CollisionKey = std::pair<std::string_view, std::string_view>;
static inline CollisionKey MakeKey(std::string_view a, std::string_view b) {
    return (a <= b) ? std::make_pair(a, b) : std::make_pair(b, a);
}
```

Update callback maps to use `CollisionKey` type.

---

### Task 2: Justfile Parallelism

**Location:** `justfile` lines 36, 51, 59

**Change:** `-j 10` → `-j` (auto-scale to available cores)

---

### Task 3: EmmyLua Type Stubs

**New files:**
- `assets/scripts/types/init.lua` - Type annotations
- `.luarc.json` - VS Code Lua extension config

**Coverage:**
- Core C++ bindings (registry, component_cache, physics, timer)
- Builder APIs (EntityBuilder, PhysicsBuilder, ShaderBuilder, Q)
- Common globals (signal, log_debug, log_error)

---

### Task 4: PCH Expansion

**Location:** `src/util/common_headers.hpp`

**Add:**
```cpp
#include "entt/entt.hpp"  // Replace entt/fwd.hpp
#include "sol/sol.hpp"    // Currently in 45 files
#include "raylib.h"       // Currently in 47 files
```

**Expected impact:** ~20% faster clean builds

---

### Task 5: EntityBuilder.validated()

**Location:** `assets/scripts/core/entity_builder.lua`

```lua
function EntityBuilder.validated(ScriptType, entity, data)
    local script = ScriptType {}
    for k, v in pairs(data or {}) do script[k] = v end
    script:attach_ecs { create_new = false, existing_entity = entity }
    return script
end
```

Prevents the "data assigned after attach_ecs" footgun.

---

### Task 6: Shader/Texture Batching (Opt-in)

**Location:** `src/systems/layer/layer_command_buffer.hpp`

**Add fields:**
```cpp
struct DrawCommandV2 {
    // ... existing fields ...
    unsigned int shader_id = 0;
    unsigned int texture_id = 0;
};
```

**Add global flag:**
```cpp
extern bool g_enableShaderTextureBatching;  // Default: false
```

**Extend sort (only when enabled):**
```cpp
if (g_enableShaderTextureBatching) {
    if (a.shader_id != b.shader_id) return a.shader_id < b.shader_id;
    if (a.texture_id != b.texture_id) return a.texture_id < b.texture_id;
}
```

---

### Task 7: Split physics_lua_bindings.hpp

**Current:** 2,389-line header

**New structure:**
```
src/systems/physics/
├── physics_lua_bindings.hpp  # Interface (~150 lines)
├── physics_lua_bindings.cpp  # Implementation (NEW)
```

Move all `lua.new_usertype<>()` calls to cpp file.

---

### Task 8: Decompose scripting_functions.cpp

**Current:** 2,387-line monolith

**New pattern:** Self-registering systems

```cpp
// Each system (e.g., sound_system.cpp)
void sound::exposeToLua(sol::state& lua, EngineContext* ctx);

// scripting_functions.cpp (~200 lines)
void initAllBindings(sol::state& lua, EngineContext* ctx) {
    sound::exposeToLua(lua, ctx);
    physics::exposePhysicsToLua(lua, ctx);
    // ...
}
```

**Systems to extract:** sound, event, camera, input, layer, transform, text, ui, particles, collision

---

### Task 9: Unified Lua API Docs

**New files:**
- `tools/generate_unified_docs.lua`
- `docs/api/UNIFIED_LUA_API.md` (generated)

**Justfile recipe:**
```bash
docs-lua-api:
    lua tools/generate_unified_docs.lua > docs/api/UNIFIED_LUA_API.md
```

## Risk Assessment

| Task | Risk | Rollback |
|------|------|----------|
| 1. MakeKey fix | Low | Simple revert |
| 2. Justfile -j | None | Simple revert |
| 3. EmmyLua stubs | None | Delete files |
| 4. PCH expansion | Medium | Revert + clean rebuild |
| 5. validated() helper | None | Delete function |
| 6. Shader batching | Low (opt-in) | Revert or flag=false |
| 7. Split physics bindings | Medium | Revert + clean rebuild |
| 8. Decompose scripting | Medium | Revert + clean rebuild |
| 9. Unified docs | None | Delete generated file |

## Testing Strategy

- **Gate:** `just build-debug && just test` after each task
- **Polling:** Exponential backoff (1s → 2s → 4s → 8s cap)
- **Rollback:** Individual commits enable surgical reverts

## Branch Strategy

- **Worktree:** `.worktrees/codebase-improvements/`
- **Branch:** `feature/codebase-improvements-2025-12`
