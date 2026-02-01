# Shader Preset System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a preset-based shader configuration system that routes through the performant batched pipeline.

**Architecture:** Presets defined in Lua (`assets/scripts/data/shader_presets.lua`) are loaded into a C++ registry at startup. Four Lua API functions (`applyShaderPreset`, `addShaderPreset`, `clearShaderPasses`, `addShaderPass`) populate `ShaderPipelineComponent` and `ShaderUniformComponent`, which the existing batched render loop already reads.

**Tech Stack:** C++20, Sol2 (Lua binding), EnTT (ECS), existing shader_pipeline and shader_system modules.

---

## Task 1: Create Shader Preset Header

**Files:**
- Create: `src/systems/shaders/shader_presets.hpp`

**Step 1: Write the failing test**

Create `tests/unit/test_shader_presets.cpp`:

```cpp
#include <gtest/gtest.h>
#include "systems/shaders/shader_presets.hpp"

TEST(ShaderPresets, GetPresetReturnsNullptrForUnknown) {
    const auto* preset = shader_presets::getPreset("nonexistent");
    EXPECT_EQ(preset, nullptr);
}

TEST(ShaderPresets, HasPresetReturnsFalseForUnknown) {
    EXPECT_FALSE(shader_presets::hasPreset("nonexistent"));
}
```

**Step 2: Run test to verify it fails**

Run: `just test 2>&1 | grep -E "(FAILED|error:|shader_presets)"`
Expected: Compilation error - `shader_presets.hpp` not found

**Step 3: Write minimal header**

Create `src/systems/shaders/shader_presets.hpp`:

```cpp
#pragma once

#include <string>
#include <vector>
#include <unordered_map>
#include "shader_system.hpp"

namespace shader_presets {

struct ShaderPresetPass {
    std::string shaderName;
    shaders::ShaderUniformSet defaultUniforms;
};

struct ShaderPreset {
    std::string id;
    std::vector<ShaderPresetPass> passes;
    shaders::ShaderUniformSet uniforms;  // shared defaults (all passes)
    bool needsAtlasUniforms = false;
};

// Registry storage
inline std::unordered_map<std::string, ShaderPreset> presetRegistry;

inline const ShaderPreset* getPreset(const std::string& name) {
    auto it = presetRegistry.find(name);
    return it != presetRegistry.end() ? &it->second : nullptr;
}

inline bool hasPreset(const std::string& name) {
    return presetRegistry.find(name) != presetRegistry.end();
}

inline void clearPresets() {
    presetRegistry.clear();
}

}  // namespace shader_presets
```

**Step 4: Run test to verify it passes**

Run: `just test 2>&1 | grep -E "(PASSED|FAILED).*ShaderPresets"`
Expected: PASSED

**Step 5: Commit**

```bash
git add src/systems/shaders/shader_presets.hpp tests/unit/test_shader_presets.cpp
git commit -m "feat(shaders): add shader preset registry header with basic API"
```

---

## Task 2: Add Lua Preset Loading

**Files:**
- Modify: `src/systems/shaders/shader_presets.hpp`
- Create: `src/systems/shaders/shader_presets.cpp`

**Step 1: Write the failing test**

Add to `tests/unit/test_shader_presets.cpp`:

```cpp
#include "sol/sol.hpp"

TEST(ShaderPresets, LoadPresetsFromLuaRegistersPresets) {
    shader_presets::clearPresets();

    sol::state lua;
    lua.open_libraries(sol::lib::base, sol::lib::table);

    // Create a minimal preset table
    lua.script(R"(
        ShaderPresets = {
            test_preset = {
                id = "test_preset",
                passes = {"test_shader"},
                uniforms = {
                    intensity = 0.5,
                },
            }
        }
    )");

    shader_presets::loadPresetsFromLuaState(lua);

    EXPECT_TRUE(shader_presets::hasPreset("test_preset"));

    const auto* preset = shader_presets::getPreset("test_preset");
    ASSERT_NE(preset, nullptr);
    EXPECT_EQ(preset->id, "test_preset");
    EXPECT_EQ(preset->passes.size(), 1);
    EXPECT_EQ(preset->passes[0].shaderName, "test_shader");
}
```

**Step 2: Run test to verify it fails**

Run: `just test 2>&1 | grep -E "(FAILED|error:|LoadPresetsFromLua)"`
Expected: Linker error - `loadPresetsFromLuaState` not found

**Step 3: Implement Lua loader**

Add to `src/systems/shaders/shader_presets.hpp`:

```cpp
#include "sol/sol.hpp"

namespace shader_presets {

// Forward declaration
void loadPresetsFromLuaState(sol::state& lua);
void loadPresetsFromLuaFile(sol::state& lua, const std::string& path);

}  // namespace shader_presets
```

Create `src/systems/shaders/shader_presets.cpp`:

```cpp
#include "shader_presets.hpp"
#include "util/common_headers.hpp"

namespace shader_presets {

namespace {

ShaderUniformValue tableToUniformValue(sol::object obj) {
    if (obj.is<float>() || obj.is<double>()) {
        return static_cast<float>(obj.as<double>());
    }
    if (obj.is<bool>()) {
        return obj.as<bool>();
    }
    if (obj.is<int>()) {
        return obj.as<int>();
    }
    if (obj.is<sol::table>()) {
        auto t = obj.as<sol::table>();
        size_t size = t.size();
        if (size == 2) {
            return Vector2{t[1].get<float>(), t[2].get<float>()};
        }
        if (size == 3) {
            return Vector3{t[1].get<float>(), t[2].get<float>(), t[3].get<float>()};
        }
        if (size == 4) {
            return Vector4{t[1].get<float>(), t[2].get<float>(), t[3].get<float>(), t[4].get<float>()};
        }
    }
    SPDLOG_WARN("shader_presets: unsupported uniform value type");
    return 0.0f;
}

void parseUniformsTable(sol::table uniformsTable, shaders::ShaderUniformSet& uniformSet) {
    for (auto& [key, value] : uniformsTable) {
        if (key.is<std::string>()) {
            std::string uniformName = key.as<std::string>();
            uniformSet.set(uniformName, tableToUniformValue(value));
        }
    }
}

bool isSkewShader(const std::string& shaderName) {
    return shaderName.find("3d_skew") == 0;
}

}  // anonymous namespace

void loadPresetsFromLuaState(sol::state& lua) {
    sol::optional<sol::table> presetsTableOpt = lua["ShaderPresets"];
    if (!presetsTableOpt) {
        SPDLOG_WARN("shader_presets: ShaderPresets table not found");
        return;
    }

    sol::table presetsTable = *presetsTableOpt;

    for (auto& [key, value] : presetsTable) {
        if (!key.is<std::string>() || !value.is<sol::table>()) {
            continue;
        }

        std::string presetName = key.as<std::string>();
        sol::table presetTable = value.as<sol::table>();

        ShaderPreset preset;
        preset.id = presetTable.get_or<std::string>("id", presetName);

        // Parse passes array
        sol::optional<sol::table> passesOpt = presetTable["passes"];
        if (passesOpt) {
            for (auto& [idx, passName] : *passesOpt) {
                if (passName.is<std::string>()) {
                    ShaderPresetPass pass;
                    pass.shaderName = passName.as<std::string>();
                    preset.passes.push_back(std::move(pass));
                }
            }
        }

        // Parse shared uniforms
        sol::optional<sol::table> uniformsOpt = presetTable["uniforms"];
        if (uniformsOpt) {
            parseUniformsTable(*uniformsOpt, preset.uniforms);
        }

        // Parse per-pass uniforms
        sol::optional<sol::table> passUniformsOpt = presetTable["pass_uniforms"];
        if (passUniformsOpt) {
            for (auto& pass : preset.passes) {
                sol::optional<sol::table> passSpecificOpt = (*passUniformsOpt)[pass.shaderName];
                if (passSpecificOpt) {
                    parseUniformsTable(*passSpecificOpt, pass.defaultUniforms);
                }
            }
        }

        // Determine needsAtlasUniforms - explicit flag or auto-detect from 3d_skew
        sol::optional<bool> needsAtlasOpt = presetTable["needs_atlas_uniforms"];
        if (needsAtlasOpt) {
            preset.needsAtlasUniforms = *needsAtlasOpt;
        } else {
            // Auto-detect: if any pass is a 3d_skew shader, enable atlas uniforms
            for (const auto& pass : preset.passes) {
                if (isSkewShader(pass.shaderName)) {
                    preset.needsAtlasUniforms = true;
                    break;
                }
            }
        }

        presetRegistry[presetName] = std::move(preset);
        SPDLOG_DEBUG("shader_presets: loaded preset '{}'", presetName);
    }

    SPDLOG_INFO("shader_presets: loaded {} presets", presetRegistry.size());
}

void loadPresetsFromLuaFile(sol::state& lua, const std::string& path) {
    auto result = lua.safe_script_file(path, sol::script_pass_on_error);
    if (!result.valid()) {
        sol::error err = result;
        SPDLOG_ERROR("shader_presets: failed to load '{}': {}", path, err.what());
        return;
    }
    loadPresetsFromLuaState(lua);
}

}  // namespace shader_presets
```

**Step 4: Update CMakeLists.txt to include new source file**

Add `src/systems/shaders/shader_presets.cpp` to the sources list in CMakeLists.txt (find the existing shader sources and add alongside them).

**Step 5: Run test to verify it passes**

Run: `just test 2>&1 | grep -E "(PASSED|FAILED).*LoadPresetsFromLua"`
Expected: PASSED

**Step 6: Commit**

```bash
git add src/systems/shaders/shader_presets.cpp src/systems/shaders/shader_presets.hpp tests/unit/test_shader_presets.cpp CMakeLists.txt
git commit -m "feat(shaders): add Lua preset loading"
```

---

## Task 3: Add Entity Preset API Functions

**Files:**
- Modify: `src/systems/shaders/shader_presets.hpp`
- Modify: `src/systems/shaders/shader_presets.cpp`

**Step 1: Write the failing test**

Add to `tests/unit/test_shader_presets.cpp`:

```cpp
#include "entt/entt.hpp"
#include "systems/shaders/shader_pipeline.hpp"

TEST(ShaderPresets, ApplyShaderPresetCreatesComponent) {
    shader_presets::clearPresets();

    // Register a test preset
    shader_presets::ShaderPreset preset;
    preset.id = "test";
    preset.passes.push_back({"test_shader", {}});
    shader_presets::presetRegistry["test"] = preset;

    entt::registry registry;
    auto entity = registry.create();

    sol::state lua;
    sol::table overrides = lua.create_table();

    shader_presets::applyShaderPreset(registry, entity, "test", overrides);

    EXPECT_TRUE(registry.all_of<shader_pipeline::ShaderPipelineComponent>(entity));

    auto& pipeline = registry.get<shader_pipeline::ShaderPipelineComponent>(entity);
    EXPECT_EQ(pipeline.passes.size(), 1);
    EXPECT_EQ(pipeline.passes[0].shaderName, "test_shader");
}

TEST(ShaderPresets, ClearShaderPassesRemovesAllPasses) {
    entt::registry registry;
    auto entity = registry.create();

    auto& pipeline = registry.emplace<shader_pipeline::ShaderPipelineComponent>(entity);
    pipeline.addPass("shader1");
    pipeline.addPass("shader2");
    EXPECT_EQ(pipeline.passes.size(), 2);

    shader_presets::clearShaderPasses(registry, entity);

    EXPECT_EQ(pipeline.passes.size(), 0);
}
```

**Step 2: Run test to verify it fails**

Run: `just test 2>&1 | grep -E "(FAILED|error:|ApplyShaderPreset)"`
Expected: Linker error - `applyShaderPreset` not found

**Step 3: Implement entity API**

Add to `src/systems/shaders/shader_presets.hpp`:

```cpp
#include "entt/entt.hpp"
#include "shader_pipeline.hpp"

namespace shader_presets {

void applyShaderPreset(entt::registry& reg, entt::entity e,
                       const std::string& presetName,
                       const sol::table& overrides);

void addShaderPreset(entt::registry& reg, entt::entity e,
                     const std::string& presetName,
                     const sol::table& overrides);

void clearShaderPasses(entt::registry& reg, entt::entity e);

void addShaderPass(entt::registry& reg, entt::entity e,
                   const std::string& shaderName,
                   const sol::table& uniforms);

}  // namespace shader_presets
```

Add to `src/systems/shaders/shader_presets.cpp`:

```cpp
namespace {

bool needsAtlasUniformsForPass(const ShaderPreset& preset, const std::string& passName) {
    if (preset.needsAtlasUniforms) return true;
    return isSkewShader(passName);
}

shaders::ShaderUniformSet resolveUniforms(
    const ShaderPreset& preset,
    const std::string& passName,
    const sol::table& overrides
) {
    shaders::ShaderUniformSet result;

    // 1. Preset's shared uniforms (base defaults)
    for (const auto& [name, value] : preset.uniforms.uniforms) {
        result.set(name, value);
    }

    // 2. Preset's per-pass defaults
    for (const auto& pass : preset.passes) {
        if (pass.shaderName == passName) {
            for (const auto& [name, value] : pass.defaultUniforms.uniforms) {
                result.set(name, value);
            }
            break;
        }
    }

    // 3. Override's top-level uniforms (all passes)
    for (auto& [key, value] : overrides) {
        if (key.is<std::string>() && !value.is<sol::table>()) {
            std::string uniformName = key.as<std::string>();
            result.set(uniformName, tableToUniformValue(value));
        }
    }

    // 4. Override's per-pass uniforms
    sol::optional<sol::table> passOverridesOpt = overrides[passName];
    if (passOverridesOpt) {
        parseUniformsTable(*passOverridesOpt, result);
    }

    return result;
}

}  // anonymous namespace

void applyShaderPreset(entt::registry& reg, entt::entity e,
                       const std::string& presetName,
                       const sol::table& overrides) {
    const auto* preset = getPreset(presetName);
    if (!preset) {
        SPDLOG_WARN("shader_presets: preset '{}' not found", presetName);
        return;
    }

    // Get or create pipeline component
    auto& pipeline = reg.get_or_emplace<shader_pipeline::ShaderPipelineComponent>(e);
    pipeline.passes.clear();  // replace mode

    // Get or create uniform component
    auto& uniformComp = reg.get_or_emplace<shaders::ShaderUniformComponent>(e);

    for (const auto& presetPass : preset->passes) {
        // Add pass to pipeline
        shader_pipeline::ShaderPass pass;
        pass.shaderName = presetPass.shaderName;
        pass.enabled = true;
        pass.injectAtlasUniforms = needsAtlasUniformsForPass(*preset, pass.shaderName);
        pipeline.passes.push_back(pass);

        // Resolve and store uniforms for this pass
        auto resolved = resolveUniforms(*preset, pass.shaderName, overrides);
        uniformComp.shaderUniforms[pass.shaderName] = resolved;
    }
}

void addShaderPreset(entt::registry& reg, entt::entity e,
                     const std::string& presetName,
                     const sol::table& overrides) {
    const auto* preset = getPreset(presetName);
    if (!preset) {
        SPDLOG_WARN("shader_presets: preset '{}' not found", presetName);
        return;
    }

    // Get or create pipeline component (don't clear - append mode)
    auto& pipeline = reg.get_or_emplace<shader_pipeline::ShaderPipelineComponent>(e);

    // Get or create uniform component
    auto& uniformComp = reg.get_or_emplace<shaders::ShaderUniformComponent>(e);

    for (const auto& presetPass : preset->passes) {
        shader_pipeline::ShaderPass pass;
        pass.shaderName = presetPass.shaderName;
        pass.enabled = true;
        pass.injectAtlasUniforms = needsAtlasUniformsForPass(*preset, pass.shaderName);
        pipeline.passes.push_back(pass);

        auto resolved = resolveUniforms(*preset, pass.shaderName, overrides);
        uniformComp.shaderUniforms[pass.shaderName] = resolved;
    }
}

void clearShaderPasses(entt::registry& reg, entt::entity e) {
    if (reg.all_of<shader_pipeline::ShaderPipelineComponent>(e)) {
        auto& pipeline = reg.get<shader_pipeline::ShaderPipelineComponent>(e);
        pipeline.passes.clear();
    }
}

void addShaderPass(entt::registry& reg, entt::entity e,
                   const std::string& shaderName,
                   const sol::table& uniforms) {
    auto& pipeline = reg.get_or_emplace<shader_pipeline::ShaderPipelineComponent>(e);

    shader_pipeline::ShaderPass pass;
    pass.shaderName = shaderName;
    pass.enabled = true;
    pass.injectAtlasUniforms = isSkewShader(shaderName);
    pipeline.passes.push_back(pass);

    if (uniforms.valid()) {
        auto& uniformComp = reg.get_or_emplace<shaders::ShaderUniformComponent>(e);
        shaders::ShaderUniformSet uniformSet;
        parseUniformsTable(uniforms, uniformSet);
        uniformComp.shaderUniforms[shaderName] = uniformSet;
    }
}
```

**Step 4: Run test to verify it passes**

Run: `just test 2>&1 | grep -E "(PASSED|FAILED).*ShaderPresets"`
Expected: All PASSED

**Step 5: Commit**

```bash
git add src/systems/shaders/shader_presets.hpp src/systems/shaders/shader_presets.cpp tests/unit/test_shader_presets.cpp
git commit -m "feat(shaders): add entity preset API (apply, add, clear, addPass)"
```

---

## Task 4: Expose API to Lua

**Files:**
- Modify: `src/systems/shaders/shader_presets.hpp`
- Modify: `src/systems/shaders/shader_presets.cpp`
- Modify: `src/systems/scripting/scripting_functions.cpp`

**Step 1: Add exposeToLua function**

Add to `src/systems/shaders/shader_presets.hpp`:

```cpp
struct EngineContext;

namespace shader_presets {

void exposeToLua(sol::state& lua, EngineContext* ctx = nullptr);

}  // namespace shader_presets
```

Add to `src/systems/shaders/shader_presets.cpp`:

```cpp
void exposeToLua(sol::state& lua, EngineContext* ctx) {
    sol::table sp = lua.create_named_table("shader_presets");

    sp.set_function("loadFromFile", [&lua](const std::string& path) {
        loadPresetsFromLuaFile(lua, path);
    });

    sp.set_function("hasPreset", &hasPreset);

    sp.set_function("getPresetNames", []() {
        std::vector<std::string> names;
        for (const auto& [name, preset] : presetRegistry) {
            names.push_back(name);
        }
        return names;
    });

    // Global functions for convenient access
    lua.set_function("applyShaderPreset",
        [](entt::registry& reg, entt::entity e, const std::string& name, sol::optional<sol::table> overrides) {
            sol::table tbl = overrides.value_or(sol::table{});
            applyShaderPreset(reg, e, name, tbl);
        }
    );

    lua.set_function("addShaderPreset",
        [](entt::registry& reg, entt::entity e, const std::string& name, sol::optional<sol::table> overrides) {
            sol::table tbl = overrides.value_or(sol::table{});
            addShaderPreset(reg, e, name, tbl);
        }
    );

    lua.set_function("clearShaderPasses",
        [](entt::registry& reg, entt::entity e) {
            clearShaderPasses(reg, e);
        }
    );

    lua.set_function("addShaderPass",
        [](entt::registry& reg, entt::entity e, const std::string& shaderName, sol::optional<sol::table> uniforms) {
            sol::table tbl = uniforms.value_or(sol::table{});
            addShaderPass(reg, e, shaderName, tbl);
        }
    );
}
```

**Step 2: Register in scripting_functions.cpp**

Add include at top of `src/systems/scripting/scripting_functions.cpp`:

```cpp
#include "systems/shaders/shader_presets.hpp"
```

Add after line 237 (after `shader_draw_commands::exposeToLua`):

```cpp
  //---------------------------------------------------------
  // methods from shader_presets.cpp. These can be called from lua
  //---------------------------------------------------------
  shader_presets::exposeToLua(stateToInit, ctx);
```

**Step 3: Build and verify compilation**

Run: `just build-debug 2>&1 | tail -10`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add src/systems/shaders/shader_presets.hpp src/systems/shaders/shader_presets.cpp src/systems/scripting/scripting_functions.cpp
git commit -m "feat(shaders): expose shader preset API to Lua"
```

---

## Task 5: Create Shader Presets Data File

**Files:**
- Create: `assets/scripts/data/shader_presets.lua`

**Step 1: Create the preset definitions file**

Create `assets/scripts/data/shader_presets.lua`:

```lua
--[[
================================================================================
SHADER PRESET DEFINITIONS
================================================================================
Centralized registry for shader presets that can be applied to entities.

Usage:
    -- Replace all passes with preset
    applyShaderPreset(registry, entity, "holographic", {
        sheen_strength = 1.0,  -- override for all passes
    })

    -- Append preset passes to existing
    addShaderPreset(registry, entity, "glow", { intensity = 1.5 })

    -- Clear all passes
    clearShaderPasses(registry, entity)

    -- Add single pass directly
    addShaderPass(registry, entity, "outline", { thickness = 2.0 })
]]

local ShaderPresets = {}

-- Basic holographic card effect
ShaderPresets.holographic = {
    id = "holographic",
    passes = {"3d_skew_holo"},
    -- needs_atlas_uniforms auto-detected from 3d_skew prefix
    uniforms = {
        sheen_strength = 0.8,
        sheen_speed = 1.2,
        sheen_width = 0.3,
    },
}

-- Gold foil card effect
ShaderPresets.gold_foil = {
    id = "gold_foil",
    passes = {"3d_skew_foil"},
    uniforms = {
        sheen_strength = 1.0,
    },
}

-- Polychrome rainbow effect
ShaderPresets.polychrome = {
    id = "polychrome",
    passes = {"3d_skew_polychrome"},
    uniforms = {},
}

-- Negative/inverted effect
ShaderPresets.negative = {
    id = "negative",
    passes = {"3d_skew_negative"},
    uniforms = {},
}

-- Dissolve effect (for card destruction)
ShaderPresets.dissolve = {
    id = "dissolve",
    passes = {"dissolve"},
    needs_atlas_uniforms = false,
    uniforms = {
        dissolve = 0.0,  -- 0 = fully visible, 1 = fully dissolved
        burn_colour_1 = {1.0, 0.5, 0.0, 1.0},
        burn_colour_2 = {1.0, 0.0, 0.0, 1.0},
    },
}

-- Multi-pass fancy card (example)
ShaderPresets.legendary_card = {
    id = "legendary_card",
    passes = {"3d_skew_holo", "3d_skew_foil"},
    uniforms = {
        sheen_strength = 1.0,
    },
    pass_uniforms = {
        ["3d_skew_foil"] = {
            sheen_speed = 0.5,
        },
    },
}

return ShaderPresets
```

**Step 2: Commit**

```bash
git add assets/scripts/data/shader_presets.lua
git commit -m "feat(shaders): add shader_presets.lua with initial preset definitions"
```

---

## Task 6: Load Presets at Engine Startup

**Files:**
- Modify: `src/core/init.cpp` or appropriate initialization file

**Step 1: Find where shaders are loaded**

Search for where `loadShadersFromJSON` is called - that's where we add preset loading.

**Step 2: Add preset loading after shader loading**

Add after shaders are loaded:

```cpp
#include "systems/shaders/shader_presets.hpp"

// After shaders::loadShadersFromJSON(...);
shader_presets::loadPresetsFromLuaFile(lua, "assets/scripts/data/shader_presets.lua");
```

**Step 3: Build and test**

Run: `just build-debug && just test`
Expected: Build succeeds, tests pass

**Step 4: Commit**

```bash
git add src/core/init.cpp
git commit -m "feat(shaders): load shader presets at engine startup"
```

---

## Task 7: Integration Test with Existing Batched Pipeline

**Files:**
- Modify: `tests/unit/test_shader_presets.cpp`

**Step 1: Write integration test**

Add to `tests/unit/test_shader_presets.cpp`:

```cpp
TEST(ShaderPresets, AppliedPresetWorksWithBatchedPipeline) {
    shader_presets::clearPresets();

    // Register a preset that looks like 3d_skew (auto atlas uniforms)
    shader_presets::ShaderPreset preset;
    preset.id = "test_skew";
    preset.passes.push_back({"3d_skew_test", {}});
    shader_presets::presetRegistry["test_skew"] = preset;

    entt::registry registry;
    auto entity = registry.create();

    sol::state lua;
    sol::table overrides = lua.create_table();

    shader_presets::applyShaderPreset(registry, entity, "test_skew", overrides);

    // Verify pipeline component is set up correctly for batched rendering
    auto& pipeline = registry.get<shader_pipeline::ShaderPipelineComponent>(entity);
    EXPECT_EQ(pipeline.passes.size(), 1);
    EXPECT_EQ(pipeline.passes[0].shaderName, "3d_skew_test");
    EXPECT_TRUE(pipeline.passes[0].enabled);
    EXPECT_TRUE(pipeline.passes[0].injectAtlasUniforms);  // auto-detected from 3d_skew prefix
}

TEST(ShaderPresets, UniformOverridesAreApplied) {
    shader_presets::clearPresets();

    shader_presets::ShaderPreset preset;
    preset.id = "test";
    preset.passes.push_back({"test_shader", {}});
    preset.uniforms.set("base_value", 1.0f);
    shader_presets::presetRegistry["test"] = preset;

    entt::registry registry;
    auto entity = registry.create();

    sol::state lua;
    lua.open_libraries(sol::lib::base, sol::lib::table);
    sol::table overrides = lua.create_table();
    overrides["base_value"] = 2.0f;
    overrides["new_value"] = 3.0f;

    shader_presets::applyShaderPreset(registry, entity, "test", overrides);

    auto& uniformComp = registry.get<shaders::ShaderUniformComponent>(entity);
    const auto* uniformSet = uniformComp.getSet("test_shader");
    ASSERT_NE(uniformSet, nullptr);

    const auto* baseValue = uniformSet->get("base_value");
    ASSERT_NE(baseValue, nullptr);
    EXPECT_FLOAT_EQ(std::get<float>(*baseValue), 2.0f);  // overridden

    const auto* newValue = uniformSet->get("new_value");
    ASSERT_NE(newValue, nullptr);
    EXPECT_FLOAT_EQ(std::get<float>(*newValue), 3.0f);  // added
}
```

**Step 2: Run tests**

Run: `just test 2>&1 | grep -E "(PASSED|FAILED).*ShaderPresets"`
Expected: All PASSED

**Step 3: Commit**

```bash
git add tests/unit/test_shader_presets.cpp
git commit -m "test(shaders): add integration tests for preset system"
```

---

## Task 8: Final Build and Full Test Run

**Step 1: Full build**

Run: `just build-debug`
Expected: Build succeeds with no errors

**Step 2: Run all tests**

Run: `just test`
Expected: All tests pass

**Step 3: Create final commit**

```bash
git add -A
git commit -m "feat(shaders): complete shader preset system implementation"
```

---

## Summary

| Task | Files | Description |
|------|-------|-------------|
| 1 | `shader_presets.hpp`, `test_shader_presets.cpp` | Basic registry header |
| 2 | `shader_presets.cpp` | Lua preset loading |
| 3 | Both | Entity API (apply, add, clear, addPass) |
| 4 | `scripting_functions.cpp` | Expose to Lua |
| 5 | `shader_presets.lua` | Preset definitions |
| 6 | `init.cpp` | Load at startup |
| 7 | Tests | Integration tests |
| 8 | - | Final verification |

**Verification commands:**
```bash
just build-debug  # Build
just test         # Run tests
```

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
