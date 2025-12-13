--[[
================================================================================
SHADER BUILDER - Fluent API for Shader Composition
================================================================================
Pure Lua wrapper over C++ ShaderPipelineComponent for easy shader layering.

Usage:
    -- Basic shader application
    ShaderBuilder.for_entity(entity)
        :add("3d_skew_holo")
        :apply()

    -- With custom uniforms
    ShaderBuilder.for_entity(entity)
        :add("3d_skew_holo", { sheen_strength = 1.5 })
        :add("dissolve", { dissolve = 0.5 })
        :apply()

    -- Chain with clear
    ShaderBuilder.for_entity(entity)
        :clear()
        :add("3d_skew_prismatic")
        :apply()

    -- Per-uniform override
    ShaderBuilder.for_entity(entity)
        :add("3d_skew_holo")
        :withUniform("3d_skew_holo", "sheen_speed", 2.0)
        :apply()

Dependencies:
    - shader_pipeline (C++ binding via Sol2)
    - globalShaderUniforms (C++ binding via Sol2)
    - registry (global ECS registry)

Design:
    - Convention-based family detection (prefix matching)
    - Automatic uniform injection for recognized shader families
    - Backwards compatible with existing ShaderPipelineComponent usage
]]

local ShaderBuilder = {}

--------------------------------------------------------------------------------
-- SHADER FAMILY REGISTRY
--------------------------------------------------------------------------------
-- Define uniform patterns per shader family prefix.
-- Families share common uniform requirements.
--------------------------------------------------------------------------------

local families = {
    ["3d_skew"] = {
        uniforms = {
            "regionRate",
            "pivot",
            "quad_center",
            "quad_size",
            "uv_passthrough",
            "tilt_enabled",
            "card_rotation"
        },
        defaults = {
            uv_passthrough = 0.0,
            tilt_enabled = 1.0,
        },
    },
    ["liquid"] = {
        uniforms = {
            "wave_speed",
            "wave_amplitude",
            "distortion"
        },
        defaults = {
            wave_speed = 1.0,
            wave_amplitude = 0.1,
        },
    },
    -- Add more families as needed:
    -- ["energy"] = { ... },
    -- ["particle"] = { ... },
}

--------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
--------------------------------------------------------------------------------

-- Detect shader family by prefix matching
-- @param shaderName string - Name of the shader
-- @return string|nil, table|nil - Family prefix and config, or nil if no match
local function detect_family(shaderName)
    for prefix, config in pairs(families) do
        if shaderName:sub(1, #prefix) == prefix then
            return prefix, config
        end
    end
    return nil, nil
end

-- Inject uniform defaults and custom overrides for a shader family
-- @param shaderName string - Name of the shader pass
-- @param familyPrefix string - Detected family prefix
-- @param customUniforms table - Custom uniform overrides (keyed by "shaderName.uniformName")
local function inject_family_uniforms(shaderName, familyPrefix, customUniforms)
    local family = families[familyPrefix]
    if not family then return end

    -- Apply family defaults
    for name, value in pairs(family.defaults or {}) do
        globalShaderUniforms:set(shaderName, name, value)
    end

    -- Apply custom overrides (if any match this shader)
    local prefix = shaderName .. "."
    for key, value in pairs(customUniforms) do
        if key:sub(1, #prefix) == prefix then
            local uniformName = key:sub(#prefix + 1)
            globalShaderUniforms:set(shaderName, uniformName, value)
        end
    end
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

-- Create a builder for the given entity
-- @param entity userdata - EnTT entity handle
-- @return table - Builder instance with fluent API
function ShaderBuilder.for_entity(entity)
    return {
        _entity = entity,
        _passes = {},
        _uniforms = {},

        -- Add a shader pass to the pipeline
        -- @param shaderName string - Name of the shader
        -- @param uniforms table|nil - Optional uniform overrides for this shader
        -- @return self - For method chaining
        add = function(self, shaderName, uniforms)
            table.insert(self._passes, shaderName)
            if uniforms then
                for k, v in pairs(uniforms) do
                    self._uniforms[shaderName .. "." .. k] = v
                end
            end
            return self
        end,

        -- Set a specific uniform for a shader
        -- @param shaderName string - Name of the shader
        -- @param name string - Uniform name
        -- @param value any - Uniform value
        -- @return self - For method chaining
        withUniform = function(self, shaderName, name, value)
            self._uniforms[shaderName .. "." .. name] = value
            return self
        end,

        -- Apply all shader passes and uniforms to the entity
        -- @return userdata - The entity (for further chaining if needed)
        apply = function(self)
            -- Get or create ShaderPipelineComponent
            local comp
            if registry:has(self._entity, shader_pipeline.ShaderPipelineComponent) then
                comp = registry:get(self._entity, shader_pipeline.ShaderPipelineComponent)
            else
                comp = registry:emplace(self._entity, shader_pipeline.ShaderPipelineComponent)
            end

            -- Add passes
            for _, shaderName in ipairs(self._passes) do
                comp:addPass(shaderName)

                -- Detect family and inject uniforms
                local familyPrefix, familyConfig = detect_family(shaderName)
                if familyPrefix then
                    inject_family_uniforms(shaderName, familyPrefix, self._uniforms)
                end
            end

            return self._entity
        end,

        -- Clear all existing shader passes from the entity
        -- @return self - For method chaining
        clear = function(self)
            local comp = registry:get(self._entity, shader_pipeline.ShaderPipelineComponent)
            if comp then
                comp:clearAll()
            end
            return self
        end,
    }
end

-- Get the shader family registry (read-only access)
-- Useful for introspection and tooling
-- @return table - Copy of the families registry
function ShaderBuilder.get_families()
    local copy = {}
    for prefix, config in pairs(families) do
        copy[prefix] = {
            uniforms = {},
            defaults = {},
        }
        for _, u in ipairs(config.uniforms) do
            table.insert(copy[prefix].uniforms, u)
        end
        for k, v in pairs(config.defaults or {}) do
            copy[prefix].defaults[k] = v
        end
    end
    return copy
end

-- Register a new shader family or extend an existing one
-- Useful for mods or dynamic shader registration
-- @param prefix string - Family prefix (e.g., "3d_skew")
-- @param config table - Family configuration { uniforms = {}, defaults = {} }
function ShaderBuilder.register_family(prefix, config)
    families[prefix] = {
        uniforms = config.uniforms or {},
        defaults = config.defaults or {},
    }
end

-- Check if a shader belongs to a known family
-- @param shaderName string - Name of the shader
-- @return string|nil - Family prefix, or nil if not in a family
function ShaderBuilder.get_shader_family(shaderName)
    local prefix, _ = detect_family(shaderName)
    return prefix
end

return ShaderBuilder
