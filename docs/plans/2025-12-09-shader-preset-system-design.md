# Shader Preset System Design

## Overview

Generalize the batched shader pipeline (currently optimized for 3d_skew) to work with any shader, with a simple preset-based API for ease of use.

## Goals

1. **Generalize batched pipeline** - Make `executeEntityPipelineWithCommands` work with any shader, not just 3d_skew variants
2. **Simple API** - Preset-based configuration with override capability
3. **Performance** - Route through batched pipeline, not legacy immediate-mode

## Shader Preset Data Structure

Presets live in `assets/scripts/data/shader_presets.lua`:

```lua
local ShaderPresets = {}

ShaderPresets.holographic = {
    id = "holographic",
    passes = {"3d_skew_holo"},
    needs_atlas_uniforms = true,  -- optional, auto-true for 3d_skew_* shaders
    uniforms = {
        sheen_strength = 0.8,
        sheen_speed = 1.2,
    },
}

ShaderPresets.dissolve = {
    id = "dissolve",
    passes = {"dissolve"},
    uniforms = {
        progress = 0.0,
        edge_color = {1.0, 0.5, 0.0, 1.0},
    },
}

ShaderPresets.fancy_card = {
    id = "fancy_card",
    passes = {"3d_skew_holo", "outline", "glow"},
    uniforms = {
        -- top-level = all passes
        iTime = 0.0,
    },
    pass_uniforms = {
        -- per-pass overrides
        ["glow"] = { intensity = 1.5 },
    },
}

return ShaderPresets
```

**Fields:**
- `id` - Unique identifier (matches table key)
- `passes` - Ordered list of shader names (multi-pass pipeline)
- `uniforms` - Default values applied to all passes
- `pass_uniforms` - Per-pass default overrides (optional)
- `needs_atlas_uniforms` - Explicit opt-in for atlas uniform injection (auto-detected for `3d_skew_*`)

## Lua API

### Methods

```lua
-- Replace all passes with preset's passes
entity:applyShaderPreset("holographic", {
    sheen_strength = 1.0,              -- all passes
    ["glow"] = { intensity = 2.0 }     -- specific pass
})

-- Append preset's passes to existing
entity:addShaderPreset("glow", { intensity = 1.5 })

-- Clear all shader passes
entity:clearShaderPasses()

-- For one-off additions without a preset
entity:addShaderPass("outline", { thickness = 2.0 })
```

### Behavior

| Method | Description |
|--------|-------------|
| `applyShaderPreset(name, overrides)` | Clears existing passes, applies preset with optional overrides |
| `addShaderPreset(name, overrides)` | Appends preset's passes without clearing |
| `clearShaderPasses()` | Removes all passes from entity |
| `addShaderPass(shaderName, uniforms)` | Adds single pass directly (no preset needed) |

### Override Resolution Order

1. Preset's `uniforms` (base defaults)
2. Preset's `pass_uniforms[passName]` (per-pass defaults)
3. Override's top-level uniforms (all passes)
4. Override's `[passName]` uniforms (specific pass)

## C++ Implementation

### New Files

- `src/systems/shaders/shader_presets.hpp` - Preset structs and registry API
- `src/systems/shaders/shader_presets.cpp` - Implementation + Lua loading

### Data Structures

```cpp
// shader_presets.hpp

struct ShaderPresetPass {
    std::string shaderName;
    ShaderUniformSet defaultUniforms;  // per-pass defaults
};

struct ShaderPreset {
    std::string id;
    std::vector<ShaderPresetPass> passes;
    ShaderUniformSet uniforms;         // shared defaults (all passes)
    bool needsAtlasUniforms = false;   // explicit flag
};

namespace shader_presets {
    void loadPresetsFromLua(const std::string& path);
    const ShaderPreset* getPreset(const std::string& name);
    bool hasPreset(const std::string& name);
}
```

### Entity API Functions

```cpp
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
```

### Uniform Resolution Helper

```cpp
ShaderUniformSet resolveUniforms(
    const ShaderPreset& preset,
    const std::string& passName,
    const sol::table& overrides
);
// Merges: preset.uniforms → preset.pass_uniforms[pass] → overrides → overrides[pass]
```

### Atlas Auto-Detection

```cpp
bool needsAtlasUniforms(const ShaderPreset& preset, const std::string& passName) {
    if (preset.needsAtlasUniforms) return true;
    return passName.starts_with("3d_skew");
}
```

## Integration with Batched Pipeline

The API populates `ShaderPipelineComponent` and `ShaderUniformComponent`, which the existing batched render loop already reads:

```cpp
void applyShaderPreset(entt::registry& reg, entt::entity e,
                       const std::string& presetName,
                       const sol::table& overrides) {
    const auto* preset = shader_presets::getPreset(presetName);
    if (!preset) return;

    // Get or create pipeline component
    auto& pipeline = reg.get_or_emplace<ShaderPipelineComponent>(e);
    pipeline.passes.clear();  // replace mode

    // Get or create uniform component
    auto& uniformComp = reg.get_or_emplace<ShaderUniformComponent>(e);

    for (const auto& presetPass : preset->passes) {
        // Add pass to pipeline
        ShaderPass pass;
        pass.name = presetPass.shaderName;
        pass.enabled = true;
        pass.injectAtlasUniforms = needsAtlasUniforms(*preset, pass.name);
        pipeline.passes.push_back(pass);

        // Resolve and store uniforms for this pass
        auto resolved = resolveUniforms(*preset, pass.name, overrides);
        uniformComp.perShaderUniforms[pass.name] = resolved;
    }
}
```

**No changes to render loop needed** - it already:
- Iterates `ShaderPipelineComponent::passes`
- Applies uniforms from `ShaderUniformComponent`
- Handles atlas injection when `injectAtlasUniforms` is true

## Loading Flow

1. During engine init (after shaders.json loads):
   ```cpp
   shader_presets::loadPresetsFromLua("assets/scripts/data/shader_presets.lua");
   ```

2. Loader reads Lua table, auto-detects `needs_atlas_uniforms` for `3d_skew_*` passes, registers each preset

## Lua Exposure

```cpp
// Entity methods
lua["applyShaderPreset"] = &applyShaderPreset;
lua["addShaderPreset"] = &addShaderPreset;
lua["clearShaderPasses"] = &clearShaderPasses;
lua["addShaderPass"] = &addShaderPass;

// Query functions
lua["hasShaderPreset"] = &shader_presets::hasPreset;
```

## Validation

At load time:
- Warn if preset references unknown shader name
- Warn if uniform name doesn't exist on target shader (optional, for debugging)

## Summary

| Aspect | Decision |
|--------|----------|
| Preset location | `assets/scripts/data/shader_presets.lua` |
| Multi-pass | Presets define complete pipelines |
| API | `applyShaderPreset` (replace), `addShaderPreset` (append), `clearShaderPasses`, `addShaderPass` |
| Overrides | Top-level (all passes) + per-pass nested |
| Atlas uniforms | Flag in preset, auto-true for `3d_skew_*` |
| Render path | Uses existing batched pipeline via `ShaderPipelineComponent` |
