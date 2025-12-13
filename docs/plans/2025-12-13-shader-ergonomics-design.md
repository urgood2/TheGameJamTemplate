# Shader Ergonomics Design

## Overview

Improve the developer experience for shader composition and command buffer usage through pure Lua wrappers. No C++ changes required.

## Goals

1. **Fluent shader composition** - Easy layering of shaders on entities
2. **Generic shader families** - Extend 3d_skew pattern to other shader types
3. **Table-based commands** - Less verbose than callback pattern
4. **Backwards compatible** - Existing code continues to work

## Design Decisions (from brainstorming)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Shader layering API | Fluent builder | `entity:shader():add("glow"):apply()` |
| Command buffer API | Table-based | `{ text = "hello", x = 100 }` with defaults |
| add_local_command params | Separate options table | Command data vs render options |
| Shader family detection | Convention-based (prefix) | Simplest - no C++ changes |
| Implementation location | Pure Lua wrappers | Fast iteration, no recompile |

## Module Structure

```
assets/scripts/core/
├── shader_builder.lua      -- Fluent API + shader family registry
├── draw.lua                -- Table-based command wrappers
```

---

## Module 1: shader_builder.lua

### Shader Family Registry

Define uniform patterns per shader family prefix:

```lua
local families = {
    ["3d_skew"] = {
        uniforms = { "regionRate", "pivot", "quad_center", "quad_size",
                     "uv_passthrough", "tilt_enabled", "card_rotation" },
        defaults = {
            uv_passthrough = 0.0,
            tilt_enabled = 1.0,
        },
    },
    ["liquid"] = {
        uniforms = { "wave_speed", "wave_amplitude", "distortion" },
        defaults = { wave_speed = 1.0, wave_amplitude = 0.1 },
    },
    -- extensible: add new families here
}
```

### Fluent Builder API

```lua
local ShaderBuilder = {}

function ShaderBuilder.for_entity(entity)
    return {
        _entity = entity,
        _passes = {},
        _uniforms = {},

        add = function(self, shaderName, uniforms)
            table.insert(self._passes, shaderName)
            if uniforms then
                for k, v in pairs(uniforms) do
                    self._uniforms[shaderName .. "." .. k] = v
                end
            end
            return self
        end,

        withUniform = function(self, shaderName, name, value)
            self._uniforms[shaderName .. "." .. name] = value
            return self
        end,

        apply = function(self)
            -- Get or create ShaderPipelineComponent
            local comp = registry:has(self._entity, shader_pipeline.ShaderPipelineComponent)
                and registry:get(self._entity, shader_pipeline.ShaderPipelineComponent)
                or registry:emplace(self._entity, shader_pipeline.ShaderPipelineComponent)

            -- Add passes
            for _, shaderName in ipairs(self._passes) do
                local pass = comp:addPass(shaderName)

                -- Detect family and inject uniforms
                local family = detect_family(shaderName)
                if family then
                    inject_family_uniforms(shaderName, family, self._uniforms)
                end
            end

            return self._entity
        end,

        clear = function(self)
            local comp = registry:get(self._entity, shader_pipeline.ShaderPipelineComponent)
            if comp then comp:clearAll() end
            return self
        end,
    }
end

-- Convenience: attach to entity metatable (optional)
-- entity:shader():add("3d_skew_holo"):apply()
```

### Family Detection

```lua
local function detect_family(shaderName)
    for prefix, config in pairs(families) do
        if shaderName:sub(1, #prefix) == prefix then
            return prefix, config
        end
    end
    return nil
end
```

### Uniform Injection

```lua
local function inject_family_uniforms(shaderName, familyPrefix, customUniforms)
    local family = families[familyPrefix]
    if not family then return end

    -- Apply defaults
    for name, value in pairs(family.defaults or {}) do
        globalShaderUniforms:set(shaderName, name, value)
    end

    -- Apply custom overrides
    local prefix = shaderName .. "."
    for key, value in pairs(customUniforms) do
        if key:sub(1, #prefix) == prefix then
            local uniformName = key:sub(#prefix + 1)
            globalShaderUniforms:set(shaderName, uniformName, value)
        end
    end
end
```

---

## Module 2: draw.lua

### Table-Based Command Buffer Wrappers

```lua
local draw = {}

-- Defaults for common commands
local DEFAULTS = {
    textPro = {
        origin = { x = 0, y = 0 },
        rotation = 0,
        fontSize = 16,
        spacing = 1,
        color = WHITE,
    },
    rectangle = {
        color = WHITE,
    },
    texturePro = {
        origin = { x = 0, y = 0 },
        rotation = 0,
        tint = WHITE,
    },
}

-- Generic wrapper factory
local function make_queue_wrapper(cmdName, defaults)
    return function(layer, props, z, space)
        z = z or 0
        space = space or layer.DrawCommandSpace.Screen

        command_buffer["queue" .. cmdName](layer, function(c)
            -- Apply defaults first
            for k, v in pairs(defaults) do
                c[k] = v
            end
            -- Apply user props (override defaults)
            for k, v in pairs(props) do
                c[k] = v
            end
        end, z, space)
    end
end

-- Generate wrappers for common commands
draw.textPro = make_queue_wrapper("TextPro", DEFAULTS.textPro)
draw.rectangle = make_queue_wrapper("DrawRectangle", DEFAULTS.rectangle)
draw.texturePro = make_queue_wrapper("TexturePro", DEFAULTS.texturePro)
draw.circleFilled = make_queue_wrapper("DrawCircleFilled", {})
draw.line = make_queue_wrapper("DrawLine", {})
-- ... add more as needed
```

### Table-Based Local Command Wrapper

```lua
-- Render option presets
local RENDER_PRESETS = {
    shaded_text = { textPass = true, uvPassthrough = true },
    sticker = { stickerPass = true, uvPassthrough = true },
    world = { space = layer.DrawCommandSpace.World },
    screen = { space = layer.DrawCommandSpace.Screen },
}

function draw.local_command(entity, cmdType, props, opts)
    opts = opts or {}

    -- Apply preset if specified
    if opts.preset and RENDER_PRESETS[opts.preset] then
        local preset = RENDER_PRESETS[opts.preset]
        for k, v in pairs(preset) do
            if opts[k] == nil then opts[k] = v end
        end
    end

    -- Extract render options with defaults
    local z = opts.z or 0
    local space = opts.space or layer.DrawCommandSpace.Screen
    local textPass = opts.textPass or false
    local uvPassthrough = opts.uvPassthrough or false
    local stickerPass = opts.stickerPass or false

    -- Get defaults for this command type
    local defaults = DEFAULTS[cmdType] or {}

    shader_draw_commands.add_local_command(
        registry, entity, cmdType,
        function(c)
            for k, v in pairs(defaults) do c[k] = v end
            for k, v in pairs(props) do c[k] = v end
        end,
        z, space, textPass, uvPassthrough, stickerPass
    )
end
```

### Usage Examples

**Before (verbose):**
```lua
shader_draw_commands.add_local_command(
    registry, eid, "text_pro",
    function(c)
        c.text = "hello"
        c.font = localization.getFont()
        c.x = 10
        c.y = 20
        c.origin = { x = 0, y = 0 }
        c.rotation = 0
        c.fontSize = 20
        c.spacing = 1
        c.color = WHITE
    end,
    1,
    layer.DrawCommandSpace.World,
    true,
    false,
    false
)
```

**After (concise):**
```lua
draw.local_command(eid, "text_pro", {
    text = "hello",
    font = localization.getFont(),
    x = 10, y = 20,
    fontSize = 20,
}, { z = 1, preset = "shaded_text" })
```

---

## Backwards Compatibility

- All existing `command_buffer.queueXXX` calls continue to work
- All existing `shader_draw_commands.add_local_command` calls continue to work
- All existing `shaderPipelineComp:addPass()` calls continue to work
- New APIs are purely additive

---

## Implementation Tasks

1. **Create shader_builder.lua**
   - Shader family registry with 3d_skew as initial family
   - Family detection by prefix
   - Fluent builder API
   - Uniform injection logic

2. **Create draw.lua**
   - Default values for common commands
   - Table-based queue wrappers
   - Table-based local_command wrapper with presets

3. **Add tests**
   - Unit tests for family detection
   - Integration test: apply shader via builder, verify passes added
   - Integration test: draw commands render correctly

4. **Update CLAUDE.md**
   - Document new APIs
   - Add usage examples

---

## Future Extensions

- Add more shader families (liquid, energy, particle, etc.)
- Add more command type wrappers as needed
- Consider entity metatable extension for `entity:shader()` syntax
