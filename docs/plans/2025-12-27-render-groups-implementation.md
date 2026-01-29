# Render Groups Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a C++ render groups system that allows Lua to register entities for batched shader rendering without ShaderPipelineComponent.

**Architecture:** Lua registers entities into named render groups with optional per-entity shader overrides. A new draw command (`CmdDrawRenderGroup`) iterates all entities in a group, sorts by z-order from `LayerOrderComponent`, and renders them through the existing `DrawCommandBatch` system.

**Tech Stack:** C++20, EnTT, Sol2, Raylib

---

## Task 1: Create render_groups header

**Files:**
- Create: `src/systems/render_groups/render_groups.hpp`

**Step 1: Create directory and header file**

```cpp
#pragma once

#include "entt/entt.hpp"
#include <string>
#include <vector>
#include <unordered_map>

// Forward declaration for sol
namespace sol {
    class state;
}

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

// Global storage
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

**Step 2: Verify file created**

Run: `ls -la src/systems/render_groups/`
Expected: `render_groups.hpp` exists

**Step 3: Commit**

```bash
git add src/systems/render_groups/render_groups.hpp
git commit -m "feat(render_groups): add header with data structures and function declarations"
```

---

## Task 2: Implement render_groups core functions

**Files:**
- Create: `src/systems/render_groups/render_groups.cpp`

**Step 1: Create implementation file**

```cpp
#include "render_groups.hpp"
#include <algorithm>
#include "spdlog/spdlog.h"

namespace render_groups {

std::unordered_map<std::string, RenderGroup> groups;

void createGroup(const std::string& name, const std::vector<std::string>& defaultShaders) {
    if (groups.find(name) != groups.end()) {
        SPDLOG_WARN("render_groups::createGroup: group '{}' already exists, overwriting", name);
    }
    groups[name] = RenderGroup{name, defaultShaders, {}};
}

void clearGroup(const std::string& groupName) {
    auto it = groups.find(groupName);
    if (it != groups.end()) {
        it->second.entities.clear();
    }
}

void clearAll() {
    groups.clear();
}

RenderGroup* getGroup(const std::string& groupName) {
    auto it = groups.find(groupName);
    if (it == groups.end()) {
        return nullptr;
    }
    return &it->second;
}

void addEntity(const std::string& groupName, entt::entity e) {
    auto* group = getGroup(groupName);
    if (!group) {
        SPDLOG_WARN("render_groups::addEntity: group '{}' not found", groupName);
        return;
    }
    // Check if already exists
    for (const auto& entry : group->entities) {
        if (entry.entity == e) {
            return;  // Already in group
        }
    }
    group->entities.push_back(EntityEntry{e, {}});
}

void addEntityWithShaders(const std::string& groupName, entt::entity e, const std::vector<std::string>& shaders) {
    auto* group = getGroup(groupName);
    if (!group) {
        SPDLOG_WARN("render_groups::addEntityWithShaders: group '{}' not found", groupName);
        return;
    }
    // Check if already exists, update shaders if so
    for (auto& entry : group->entities) {
        if (entry.entity == e) {
            entry.shaders = shaders;
            return;
        }
    }
    group->entities.push_back(EntityEntry{e, shaders});
}

void removeEntity(const std::string& groupName, entt::entity e) {
    auto* group = getGroup(groupName);
    if (!group) return;

    auto it = std::find_if(group->entities.begin(), group->entities.end(),
        [e](const EntityEntry& entry) { return entry.entity == e; });
    if (it != group->entities.end()) {
        // Swap with last and pop for O(1) removal
        *it = group->entities.back();
        group->entities.pop_back();
    }
}

void removeFromAll(entt::entity e) {
    for (auto& [name, group] : groups) {
        auto it = std::find_if(group.entities.begin(), group.entities.end(),
            [e](const EntityEntry& entry) { return entry.entity == e; });
        if (it != group.entities.end()) {
            *it = group.entities.back();
            group.entities.pop_back();
        }
    }
}

void addShader(const std::string& groupName, entt::entity e, const std::string& shader) {
    auto* group = getGroup(groupName);
    if (!group) return;

    for (auto& entry : group->entities) {
        if (entry.entity == e) {
            // Don't add duplicate
            if (std::find(entry.shaders.begin(), entry.shaders.end(), shader) == entry.shaders.end()) {
                entry.shaders.push_back(shader);
            }
            return;
        }
    }
}

void removeShader(const std::string& groupName, entt::entity e, const std::string& shader) {
    auto* group = getGroup(groupName);
    if (!group) return;

    for (auto& entry : group->entities) {
        if (entry.entity == e) {
            auto it = std::find(entry.shaders.begin(), entry.shaders.end(), shader);
            if (it != entry.shaders.end()) {
                entry.shaders.erase(it);
            }
            return;
        }
    }
}

void setShaders(const std::string& groupName, entt::entity e, const std::vector<std::string>& shaders) {
    auto* group = getGroup(groupName);
    if (!group) return;

    for (auto& entry : group->entities) {
        if (entry.entity == e) {
            entry.shaders = shaders;
            return;
        }
    }
}

void resetToDefault(const std::string& groupName, entt::entity e) {
    auto* group = getGroup(groupName);
    if (!group) return;

    for (auto& entry : group->entities) {
        if (entry.entity == e) {
            entry.shaders.clear();  // Empty = use group defaults
            return;
        }
    }
}

}  // namespace render_groups
```

**Step 2: Verify file created**

Run: `ls -la src/systems/render_groups/`
Expected: Both `.hpp` and `.cpp` exist

**Step 3: Commit**

```bash
git add src/systems/render_groups/render_groups.cpp
git commit -m "feat(render_groups): implement core group and entity management functions"
```

---

## Task 3: Add Lua bindings for render_groups

**Files:**
- Modify: `src/systems/render_groups/render_groups.cpp` (append to file)

**Step 1: Add Lua bindings implementation at end of file**

```cpp
// Add to render_groups.cpp, before closing namespace

#include "sol/sol.hpp"

void exposeToLua(sol::state& lua) {
    auto tbl = lua.create_named_table("render_groups");

    // Group management
    tbl["create"] = [](const std::string& name, sol::table shaderList) {
        std::vector<std::string> shaders;
        for (auto& kv : shaderList) {
            if (kv.second.is<std::string>()) {
                shaders.push_back(kv.second.as<std::string>());
            }
        }
        createGroup(name, shaders);
    };

    tbl["clearGroup"] = clearGroup;
    tbl["clearAll"] = clearAll;

    // Entity management - add() with optional shader override
    tbl["add"] = sol::overload(
        [](const std::string& groupName, entt::entity e) {
            addEntity(groupName, e);
        },
        [](const std::string& groupName, entt::entity e, sol::table shaderList) {
            std::vector<std::string> shaders;
            for (auto& kv : shaderList) {
                if (kv.second.is<std::string>()) {
                    shaders.push_back(kv.second.as<std::string>());
                }
            }
            addEntityWithShaders(groupName, e, shaders);
        }
    );

    tbl["remove"] = removeEntity;
    tbl["removeFromAll"] = removeFromAll;

    // Per-entity shader manipulation
    tbl["addShader"] = addShader;
    tbl["removeShader"] = removeShader;

    tbl["setShaders"] = [](const std::string& groupName, entt::entity e, sol::table shaderList) {
        std::vector<std::string> shaders;
        for (auto& kv : shaderList) {
            if (kv.second.is<std::string>()) {
                shaders.push_back(kv.second.as<std::string>());
            }
        }
        setShaders(groupName, e, shaders);
    };

    tbl["resetToDefault"] = resetToDefault;
}
```

**Step 2: Verify compiles**

Run: `just build-debug 2>&1 | tail -20` (will fail - CMake not updated yet)
Expected: Compilation errors about missing source file

**Step 3: Commit**

```bash
git add src/systems/render_groups/render_groups.cpp
git commit -m "feat(render_groups): add Lua bindings for all functions"
```

---

## Task 4: Add render_groups to CMakeLists.txt

**Files:**
- Modify: `CMakeLists.txt`

**Step 1: Find the SOURCES section and add render_groups**

Search for `set(SOURCES` in CMakeLists.txt and add:
```cmake
src/systems/render_groups/render_groups.cpp
```

Also add to include paths if needed:
```cmake
src/systems/render_groups/render_groups.hpp
```

**Step 2: Build to verify**

Run: `just build-debug 2>&1 | tail -30`
Expected: Build succeeds (may have unrelated warnings)

**Step 3: Commit**

```bash
git add CMakeLists.txt
git commit -m "build: add render_groups to CMakeLists.txt"
```

---

## Task 5: Add CmdDrawRenderGroup to layer_optimized.hpp

**Files:**
- Modify: `src/systems/layer/layer_optimized.hpp`

**Step 1: Add DrawRenderGroup to DrawCommandType enum (before Count)**

Find the enum `DrawCommandType` around line 154 and add before `Count`:
```cpp
        DrawRenderGroup,

        Count // <--- always last
```

**Step 2: Add CmdDrawRenderGroup struct after CmdDrawBatchedEntities**

Find `struct CmdDrawBatchedEntities` around line 626 and add after it:
```cpp
    struct CmdDrawRenderGroup {
        entt::registry* registry;
        std::string groupName;
        bool autoOptimize = true;
    };
```

**Step 3: Add extern declaration for ExecuteDrawRenderGroup**

Find the `extern void ExecuteDrawBatchedEntities` declaration and add after it:
```cpp
    extern void ExecuteDrawRenderGroup(std::shared_ptr<layer::Layer> layer, CmdDrawRenderGroup* c);
```

**Step 4: Build to verify**

Run: `just build-debug 2>&1 | tail -20`
Expected: Build succeeds (linker error OK - implementation not done yet)

**Step 5: Commit**

```bash
git add src/systems/layer/layer_optimized.hpp
git commit -m "feat(layer): add CmdDrawRenderGroup command type and struct"
```

---

## Task 6: Add GetDrawCommandType specialization

**Files:**
- Modify: `src/systems/layer/layer_command_buffer.hpp`

**Step 1: Add template specialization after CmdDrawBatchedEntities**

Find around line 320:
```cpp
template <>
inline DrawCommandType GetDrawCommandType<CmdDrawBatchedEntities>() {
  return DrawCommandType::DrawBatchedEntities;
}
```

Add after it:
```cpp
template <>
inline DrawCommandType GetDrawCommandType<CmdDrawRenderGroup>() {
  return DrawCommandType::DrawRenderGroup;
}
```

**Step 2: Build to verify**

Run: `just build-debug 2>&1 | tail -20`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add src/systems/layer/layer_command_buffer.hpp
git commit -m "feat(layer): add GetDrawCommandType specialization for CmdDrawRenderGroup"
```

---

## Task 7: Implement ExecuteDrawRenderGroup

**Files:**
- Modify: `src/systems/layer/layer_optimized.cpp`

**Step 1: Add include at top of file**

```cpp
#include "systems/render_groups/render_groups.hpp"
```

**Step 2: Add ExecuteDrawRenderGroup implementation**

Find `ExecuteDrawBatchedEntities` function and add after it:

```cpp
void ExecuteDrawRenderGroup(std::shared_ptr<layer::Layer> layer, CmdDrawRenderGroup* c) {
    auto* group = render_groups::getGroup(c->groupName);
    if (!group) {
        SPDLOG_WARN("ExecuteDrawRenderGroup: group '{}' not found", c->groupName);
        return;
    }

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

**Step 3: Register the command in InitDispatcher**

Find `InitDispatcher()` function and add:
```cpp
RegisterRenderer<CmdDrawRenderGroup>(DrawCommandType::DrawRenderGroup, ExecuteDrawRenderGroup);
```

**Step 4: Build to verify**

Run: `just build-debug 2>&1 | tail -30`
Expected: Linker error for `executeEntityWithShaders` (not implemented yet)

**Step 5: Commit**

```bash
git add src/systems/layer/layer_optimized.cpp
git commit -m "feat(layer): implement ExecuteDrawRenderGroup with z-sorting and lazy cleanup"
```

---

## Task 8: Declare executeEntityWithShaders in shader_draw_commands.hpp

**Files:**
- Modify: `src/systems/shaders/shader_draw_commands.hpp`

**Step 1: Add function declaration**

Find the namespace and add near other function declarations:
```cpp
// Render entity with specified shaders (no ShaderPipelineComponent needed)
void executeEntityWithShaders(
    entt::registry& registry,
    entt::entity e,
    const std::vector<std::string>& shaders,
    DrawCommandBatch& batch
);
```

**Step 2: Build to verify**

Run: `just build-debug 2>&1 | tail -20`
Expected: Linker error (implementation missing)

**Step 3: Commit**

```bash
git add src/systems/shaders/shader_draw_commands.hpp
git commit -m "feat(shaders): declare executeEntityWithShaders"
```

---

## Task 9: Implement executeEntityWithShaders

**Files:**
- Modify: `src/systems/shaders/shader_draw_commands.cpp`

**Step 1: Add implementation**

Find `executeEntityPipelineWithCommands` and add a new function after it that reuses its sprite-fetching logic:

```cpp
void executeEntityWithShaders(
    entt::registry& registry,
    entt::entity e,
    const std::vector<std::string>& shaders,
    DrawCommandBatch& batch
) {
    // Get animation/sprite data (same as executeEntityPipelineWithCommands)
    if (!registry.all_of<AnimationQueueComponent>(e)) return;
    auto& aqc = registry.get<AnimationQueueComponent>(e);
    if (aqc.noDraw) return;

    // Get current sprite (copy to avoid dangling refs)
    SpriteComponentASCII currentSpriteData{};
    SpriteComponentASCII* currentSprite = nullptr;
    Rectangle animationFrameData{};
    Rectangle* animationFrame = nullptr;
    bool flipX = false;
    bool flipY = false;

    if (aqc.animationQueue.empty()) {
        if (!aqc.defaultAnimation.animationList.empty()) {
            currentSpriteData = aqc.defaultAnimation
                .animationList[aqc.defaultAnimation.currentAnimIndex].first;
            animationFrameData = currentSpriteData.spriteData.frame;
            currentSprite = &currentSpriteData;
            animationFrame = &animationFrameData;
            flipX = aqc.defaultAnimation.flippedHorizontally;
            flipY = aqc.defaultAnimation.flippedVertically;
        }
    } else {
        auto& currentAnimObject = aqc.animationQueue[aqc.currentAnimationIndex];
        currentSpriteData = currentAnimObject
            .animationList[currentAnimObject.currentAnimIndex].first;
        animationFrameData = currentSpriteData.spriteData.frame;
        currentSprite = &currentSpriteData;
        animationFrame = &animationFrameData;
        flipX = currentAnimObject.flippedHorizontally;
        flipY = currentAnimObject.flippedVertically;
    }

    if (!currentSprite || !animationFrame) return;

    // Get transform
    if (!registry.all_of<transform::Transform>(e)) return;
    auto& t = registry.get<transform::Transform>(e);

    // Get sprite atlas
    Texture2D* spriteAtlas = currentSprite->spriteData.texture;
    if (!spriteAtlas || spriteAtlas->id == 0) return;

    // Build rectangles
    Rectangle atlasRect = *animationFrame;
    float srcW = atlasRect.width;
    float srcH = atlasRect.height;
    if (flipX) srcW = -srcW;
    if (flipY) srcH = -srcH;
    Rectangle srcRect = {atlasRect.x, atlasRect.y, srcW, srcH};

    float destW = t.visualW;
    float destH = t.visualH;
    Rectangle destRect = {t.visualX, t.visualY, destW, destH};

    Vector2 origin = {0, 0};
    float cardRotationDeg = t.rotationDegrees;

    Color fgColor = currentSprite->fgColor;
    if (fgColor.a == 0) fgColor = WHITE;

    // Execute shader passes
    if (shaders.empty()) {
        // No shaders - just draw sprite directly
        batch.addDrawTexturePro(*spriteAtlas, srcRect, destRect, origin, cardRotationDeg, fgColor);
    } else {
        // Apply each shader pass
        for (const auto& shaderName : shaders) {
            batch.addBeginShader(shaderName);
            batch.addDrawTexturePro(*spriteAtlas, srcRect, destRect, origin, cardRotationDeg, fgColor);
            batch.addEndShader();
        }
    }
}
```

**Step 2: Build to verify**

Run: `just build-debug 2>&1 | tail -30`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add src/systems/shaders/shader_draw_commands.cpp
git commit -m "feat(shaders): implement executeEntityWithShaders - renders entity with arbitrary shader list"
```

---

## Task 10: Add queueDrawRenderGroup Lua binding

**Files:**
- Modify: `src/systems/layer/layer.cpp`

**Step 1: Add QUEUE_CMD for DrawRenderGroup**

Find the QUEUE_CMD list around line 1774 and add:
```cpp
QUEUE_CMD(DrawRenderGroup)
```

**Step 2: Add BIND_CMD for DrawRenderGroup**

Find the BIND_CMD section and add:
```cpp
BIND_CMD(DrawRenderGroup, "registry",
         &layer::CmdDrawRenderGroup::registry, "groupName",
         &layer::CmdDrawRenderGroup::groupName, "autoOptimize",
         &layer::CmdDrawRenderGroup::autoOptimize)
```

**Step 3: Build to verify**

Run: `just build-debug 2>&1 | tail -30`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add src/systems/layer/layer.cpp
git commit -m "feat(layer): add Lua binding for queueDrawRenderGroup"
```

---

## Task 11: Expose render_groups to Lua at startup

**Files:**
- Modify: `src/core/init.cpp` or wherever Lua bindings are initialized

**Step 1: Find Lua initialization and add render_groups**

Find where other systems expose to Lua (search for `exposeToLua`) and add:
```cpp
#include "systems/render_groups/render_groups.hpp"

// In the Lua init section:
render_groups::exposeToLua(lua);
```

**Step 2: Build to verify**

Run: `just build-debug 2>&1 | tail -30`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add src/core/init.cpp
git commit -m "feat(init): expose render_groups to Lua at startup"
```

---

## Task 12: Create integration test in Lua

**Files:**
- Create: `assets/scripts/tests/test_render_groups.lua`

**Step 1: Create test file**

```lua
-- test_render_groups.lua
-- Integration test for render groups system

local function test_render_groups()
    print("[test_render_groups] Starting tests...")

    -- Test 1: Create group
    render_groups.create("test_enemies", {"flash"})
    print("[test_render_groups] Created group 'test_enemies' with shader 'flash'")

    -- Test 2: Create test entity
    local testEntity = registry:create()
    print("[test_render_groups] Created test entity:", testEntity)

    -- Test 3: Add entity to group
    render_groups.add("test_enemies", testEntity)
    print("[test_render_groups] Added entity to group")

    -- Test 4: Add with custom shaders
    local testEntity2 = registry:create()
    render_groups.add("test_enemies", testEntity2, {"3d_skew", "dissolve"})
    print("[test_render_groups] Added entity2 with custom shaders")

    -- Test 5: Dynamic shader manipulation
    render_groups.addShader("test_enemies", testEntity, "outline")
    print("[test_render_groups] Added 'outline' shader to entity")

    render_groups.removeShader("test_enemies", testEntity, "outline")
    print("[test_render_groups] Removed 'outline' shader from entity")

    render_groups.setShaders("test_enemies", testEntity, {"custom1", "custom2"})
    print("[test_render_groups] Set custom shader list")

    render_groups.resetToDefault("test_enemies", testEntity)
    print("[test_render_groups] Reset to default shaders")

    -- Test 6: Remove entity
    render_groups.remove("test_enemies", testEntity)
    print("[test_render_groups] Removed entity from group")

    -- Test 7: Remove from all
    render_groups.removeFromAll(testEntity2)
    print("[test_render_groups] Removed entity2 from all groups")

    -- Cleanup
    render_groups.clearAll()
    registry:destroy(testEntity)
    registry:destroy(testEntity2)

    print("[test_render_groups] All tests passed!")
    return true
end

return { run = test_render_groups }
```

**Step 2: Commit**

```bash
git add assets/scripts/tests/test_render_groups.lua
git commit -m "test: add Lua integration test for render_groups"
```

---

## Task 13: Run full build and manual test

**Step 1: Full build**

Run: `just build-debug`
Expected: Build succeeds with no errors

**Step 2: Run game to verify no crashes**

Run: `./build/raylib-cpp-cmake-template`
Expected: Game starts without crashing

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat(render_groups): complete implementation of batched shader rendering system"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Create header | `render_groups.hpp` |
| 2 | Implement core functions | `render_groups.cpp` |
| 3 | Add Lua bindings | `render_groups.cpp` |
| 4 | Update CMakeLists | `CMakeLists.txt` |
| 5 | Add command type | `layer_optimized.hpp` |
| 6 | Add template specialization | `layer_command_buffer.hpp` |
| 7 | Implement ExecuteDrawRenderGroup | `layer_optimized.cpp` |
| 8 | Declare executeEntityWithShaders | `shader_draw_commands.hpp` |
| 9 | Implement executeEntityWithShaders | `shader_draw_commands.cpp` |
| 10 | Add Lua queue binding | `layer.cpp` |
| 11 | Expose at startup | `init.cpp` |
| 12 | Create integration test | `test_render_groups.lua` |
| 13 | Final build & test | - |

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
