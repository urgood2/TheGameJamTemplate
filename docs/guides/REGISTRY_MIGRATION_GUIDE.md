# globals::getRegistry() Migration Guide

This document describes the migration pattern for replacing `globals::getRegistry()` calls with explicit registry parameters, improving testability and making dependencies explicit.

## Migration Pattern

### Before (Global Access)
```cpp
void processEntity(entt::entity e) {
    auto& registry = globals::getRegistry();
    auto& transform = registry.get<Transform>(e);
    // ... use transform
}
```

### After (Explicit Parameter)
```cpp
// New: Registry-parameterized version (preferred)
void processEntity(entt::registry& registry, entt::entity e) {
    auto& transform = registry.get<Transform>(e);
    // ... use transform
}

// Deprecated wrapper (keeps Lua/legacy compatibility)
[[deprecated("Use processEntity(registry, e) instead")]]
void processEntity(entt::entity e) {
    processEntity(globals::getRegistry(), e);
}
```

### For Lua Bindings
When the function needs to be exposed to Lua (which can't pass a registry reference), use a lambda:

```cpp
rec.bind_function(lua, {"Namespace"}, "functionName",
    [](entt::entity e, ...) {
        return Namespace::functionName(globals::getRegistry(), e, ...);
    },
    "---@param e Entity", "Description");
```

## File Classifications

### Migrated Files (Deprecated Wrapper Pattern Applied)
These files have registry-parameterized versions with deprecated wrappers:

| File | Functions Migrated |
|------|-------------------|
| `entity_gamestate_management.cpp` | State management functions |
| `guiIndicatorSystem.cpp` | GUI indicator functions |
| `physics_world.cpp` | Physics world operations |
| `graphics.cpp` | Graphics utilities |
| `tutorial_system_v2.cpp` | Tutorial system |
| `anim_system.cpp` | Animation queue functions |
| `transform.cpp` | Transform operations |
| `ai_system.cpp` | AI/GOAP functions |
| `textVer2.cpp` | Text system (15+ functions) |
| `element.cpp` | UI element functions |

### Acceptable Usage (No Migration Needed)

#### Bridge Layer Functions
Files that intentionally use `globals::getRegistry()` because they bridge Lua calls to C++:

| File | Reason |
|------|--------|
| `scripting_functions.cpp` | Lua-facing GOAP/blackboard accessors |
| `ui.cpp` | Lua binding lambdas for UI system |

Lua cannot pass an `entt::registry&`, so these bridge functions appropriately access the global registry.

#### Top-Level Orchestration
Entry points that distribute the registry to subsystems:

| File | Reason |
|------|--------|
| `game.cpp` | Game loop (Init, Update, Draw) |
| `main.cpp` | Application entry point |

These are the natural points where globals become explicit parameters passed down the call stack.

#### Context-Aware Fallback
Files that already have context-aware patterns:

| File | Pattern |
|------|---------|
| `controller_nav.cpp` | `(globals::g_ctx) ? globals::g_ctx->registry : globals::getRegistry()` |

#### Dead/Commented Code
Files where all usages are commented out:

| File | Status |
|------|--------|
| `ldtk_test.cpp` | All usages commented |
| `box.cpp` | Active usages commented |

### Deferred (Architecture Changes Required)

| File | Reason |
|------|--------|
| `layer.cpp` | Render command pipeline needs `CmdStruct` changes |
| `layer_optimized.cpp` | Same as above |
| `transform_functions.cpp` | Internal dispatch table functions |

## When to Migrate vs Skip

### Migrate When:
- Function is called from C++ code that has registry access
- Function can be tested in isolation
- Function is part of a subsystem API

### Skip When:
- Function is a Lua bridge (lambda in binding code)
- Function is a top-level entry point (game loop, main)
- File has context-aware fallback already
- All usages are commented/dead code

## Statistics

After this migration effort:
- **~292 total usages** remain across all `.cpp` files
- Most remaining usages are in acceptable categories
- Core subsystems now have explicit registry parameters

## Benefits

1. **Testability**: Functions can be called with mock registries
2. **Explicit Dependencies**: Clear what each function needs
3. **Future-Proofing**: Easier to support multiple registries if needed
4. **IDE Support**: Better code navigation and refactoring

## Related Files

- `src/core/globals.hpp` - Definition of `globals::getRegistry()`
- `src/core/engine_context.hpp` - `EngineContext` struct with registry member

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
