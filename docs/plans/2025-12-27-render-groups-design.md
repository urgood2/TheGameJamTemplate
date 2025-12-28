# Render Groups System Design

**Date:** 2025-12-27
**Status:** Approved
**Goal:** Provide C++ batched shader rendering without ShaderPipelineComponent

## Overview

Create a render groups system that allows Lua to register entities for batched shader rendering, with C++ handling the iteration and rendering. This avoids the buggy ShaderPipelineComponent while providing the same batched rendering benefits.

## Motivation

Current card rendering (gameplay.lua:1970-2140) iterates a Lua table, checks for ShaderPipelineComponent, and calls batched rendering. This works but:
- Requires per-entity ShaderPipelineComponent (buggy)
- Lua iteration overhead
- Not reusable for other entity types

## Design

### Core Data Structures

**File:** `src/systems/render_groups/render_groups.hpp`

```cpp
namespace render_groups {

struct EntityEntry {
    entt::entity entity;
    std::vector<std::string> shaders;  // empty = use group defaults
};

struct RenderGroup {
    std::string name;
    std::vector<std::string> defaultShaders;
    std::vector<EntityEntry> entities;
};

extern std::unordered_map<std::string, RenderGroup> groups;

// Group management
void createGroup(const std::string& name, const std::vector<std::string>& defaultShaders);
void clearGroup(const std::string& groupName);
void clearAll();
RenderGroup* getGroup(const std::string& groupName);

// Entity management
void addEntity(const std::string& groupName, entt::entity e);
void addEntityWithShaders(const std::string& groupName, entt::entity e, const std::vector<std::string>& shaders);
void removeEntity(const std::string& groupName, entt::entity e);
void removeFromAll(entt::entity e);

// Per-entity shader manipulation
void addShader(const std::string& groupName, entt::entity e, const std::string& shader);
void removeShader(const std::string& groupName, entt::entity e, const std::string& shader);
void setShaders(const std::string& groupName, entt::entity e, const std::vector<std::string>& shaders);
void resetToDefault(const std::string& groupName, entt::entity e);

// Lua bindings
void exposeToLua(sol::state& lua);

}  // namespace render_groups
```

### Draw Command

**File:** `src/systems/layer/layer_optimized.hpp`

```cpp
struct CmdDrawRenderGroup {
    entt::registry* registry;
    std::string groupName;
    bool autoOptimize = true;
};
```

### Execution Logic

**File:** `src/systems/layer/layer_optimized.cpp`

```cpp
void ExecuteDrawRenderGroup(std::shared_ptr<layer::Layer> layer, CmdDrawRenderGroup* c) {
    auto* group = render_groups::getGroup(c->groupName);
    if (!group) return;

    // 1. Collect valid entities with z-order, remove invalid
    std::vector<std::pair<int, size_t>> sortedIndices;
    sortedIndices.reserve(group->entities.size());

    for (size_t i = 0; i < group->entities.size(); ) {
        entt::entity e = group->entities[i].entity;

        // Lazy cleanup of invalid entities
        if (!c->registry->valid(e)) {
            group->entities[i] = group->entities.back();
            group->entities.pop_back();
            continue;
        }

        if (!c->registry->all_of<AnimationQueueComponent>(e)) {
            ++i;
            continue;
        }

        auto& anim = c->registry->get<AnimationQueueComponent>(e);
        if (anim.noDraw) {
            ++i;
            continue;
        }

        int z = layer_order_system::getZIndex(*c->registry, e);
        sortedIndices.emplace_back(z, i);
        ++i;
    }

    // 2. Sort by z-order
    std::sort(sortedIndices.begin(), sortedIndices.end());

    // 3. Batch render
    shader_draw_commands::DrawCommandBatch batch;
    batch.beginRecording();

    for (auto& [z, idx] : sortedIndices) {
        auto& entry = group->entities[idx];
        const auto& shaders = entry.shaders.empty() ? group->defaultShaders : entry.shaders;

        shader_draw_commands::executeEntityWithShaders(*c->registry, entry.entity, shaders, batch);
    }

    batch.endRecording();
    if (c->autoOptimize) batch.optimize();
    batch.execute();
}
```

### Core Renderer

**File:** `src/systems/shaders/shader_draw_commands.cpp`

```cpp
void executeEntityWithShaders(
    entt::registry& registry,
    entt::entity e,
    const std::vector<std::string>& shaders,
    DrawCommandBatch& batch
) {
    // Get animation/sprite data (reuse existing logic)
    if (!registry.all_of<AnimationQueueComponent>(e)) return;
    auto& aqc = registry.get<AnimationQueueComponent>(e);
    if (aqc.noDraw) return;

    // Get current sprite from animation queue
    // ... (existing getCurrentSprite logic)

    // Get transform for positioning
    if (!registry.all_of<transform::Transform>(e)) return;
    auto& t = registry.get<transform::Transform>(e);

    // Build rectangles (existing logic)
    // ...

    // Execute shader passes
    if (shaders.empty()) {
        batch.addDrawTexturePro(*getAtlas(), srcRect, destRect, origin, rotation, WHITE);
    } else {
        for (const auto& shaderName : shaders) {
            batch.addBeginShader(shaderName);
            // inject uniforms, draw sprite
            batch.addDrawTexturePro(*getAtlas(), srcRect, destRect, origin, rotation, WHITE);
            batch.addEndShader();
        }
    }
}
```

## Lua API

```lua
-- Group setup
render_groups.create("enemies", {"flash"})
render_groups.create("items", {"3d_skew"})

-- Entity lifecycle
render_groups.add("enemies", entity)
render_groups.add("enemies", boss, {"3d_skew_holo", "flash"})
render_groups.remove("enemies", entity)
render_groups.removeFromAll(entity)

-- Dynamic shader changes
render_groups.addShader("enemies", entity, "dissolve")
render_groups.removeShader("enemies", entity, "dissolve")
render_groups.setShaders("enemies", entity, {"outline"})
render_groups.resetToDefault("enemies", entity)

-- Rendering (each frame)
command_buffer.queueDrawRenderGroup(layers.sprites, function(cmd)
    cmd.registry = registry
    cmd.groupName = "enemies"
end, z_orders.enemies, layer.DrawCommandSpace.World)

-- Scene cleanup
render_groups.clearAll()
```

## Files to Create/Modify

### New Files
- `src/systems/render_groups/render_groups.hpp`
- `src/systems/render_groups/render_groups.cpp`

### Modified Files
- `src/systems/layer/layer_optimized.hpp` - Add CmdDrawRenderGroup
- `src/systems/layer/layer_optimized.cpp` - Add ExecuteDrawRenderGroup, register command
- `src/systems/layer/layer.cpp` - Add Lua bindings for queueDrawRenderGroup
- `src/systems/shaders/shader_draw_commands.hpp` - Declare executeEntityWithShaders
- `src/systems/shaders/shader_draw_commands.cpp` - Implement executeEntityWithShaders
- `CMakeLists.txt` - Add render_groups source files

## Benefits

- No per-entity ShaderPipelineComponent overhead
- C++ iteration (no Lua table traversal during render)
- Simple vector-based shader storage
- Reusable across any entity type
- Lazy cleanup of destroyed entities
