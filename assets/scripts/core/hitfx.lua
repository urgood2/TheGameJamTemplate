--[[
================================================================================
HITFX - Per-Entity Flash Effects
================================================================================
Provides functions to trigger flash effects on individual entities with proper
per-entity timing. Each entity's flash starts at white when triggered, regardless
of when other entities were hit.

Usage:
    local hitfx = require("core.hitfx")

    -- Flash an entity (starts white, blinks for default duration)
    hitfx.flash(enemy)

    -- Flash with custom duration
    hitfx.flash(enemy, 0.3)  -- 300ms flash

    -- Flash and get a cancel function
    local cancel = hitfx.flash(enemy, 0.5)
    cancel()  -- Stop flash early

Dependencies:
    - shaders.ShaderUniformComponent (C++ binding)
    - shader_pipeline.ShaderPipelineComponent (C++ binding)
    - timer (core.timer)
    - registry (global ECS registry)
]]

local hitfx = {}

-- Localize globals
local registry = _G.registry
local shaders = _G.shaders
local shader_pipeline = _G.shader_pipeline
local timer = require("core.timer")

local DEFAULT_FLASH_DURATION = 0.2  -- seconds

--------------------------------------------------------------------------------
-- HELPER: Ensure entity has required components for flashing
--------------------------------------------------------------------------------

local function ensure_flash_components(entity)
    -- 1. Ensure ShaderPipelineComponent exists
    if not registry:has(entity, shader_pipeline.ShaderPipelineComponent) then
        registry:emplace(entity, shader_pipeline.ShaderPipelineComponent)
    end
    local pipeline = registry:get(entity, shader_pipeline.ShaderPipelineComponent)

    -- 2. Add flash shader pass if not already present
    local hasFlash = false
    for _, pass in ipairs(pipeline.passes or {}) do
        if pass.shaderName == "flash" then
            hasFlash = true
            break
        end
    end
    if not hasFlash then
        pipeline:addPass("flash")
    end

    -- 3. Ensure ShaderUniformComponent exists for per-entity uniforms
    if not registry:has(entity, shaders.ShaderUniformComponent) then
        registry:emplace(entity, shaders.ShaderUniformComponent)
    end
    local uniforms = registry:get(entity, shaders.ShaderUniformComponent)

    return pipeline, uniforms
end

--------------------------------------------------------------------------------
-- HELPER: Remove flash shader pass from entity
--------------------------------------------------------------------------------

local function remove_flash_pass(entity)
    if not registry:valid(entity) then return end
    if not registry:has(entity, shader_pipeline.ShaderPipelineComponent) then return end

    local pipeline = registry:get(entity, shader_pipeline.ShaderPipelineComponent)
    if pipeline and pipeline.removePass then
        pipeline:removePass("flash")
    end
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--- Flash an entity with proper per-entity timing.
--- The flash will always start at white (bright) when triggered.
--- @param entity Entity The entity to flash
--- @param duration number? Optional duration in seconds (default 0.2)
--- @return function cancel Cancel function to stop the flash early
function hitfx.flash(entity, duration)
    duration = duration or DEFAULT_FLASH_DURATION

    -- Validate entity
    if not registry:valid(entity) then
        return function() end  -- no-op cancel
    end

    -- Ensure components exist
    local pipeline, uniforms = ensure_flash_components(entity)

    -- Set flashStartTime to current time (so flash starts at white)
    local currentTime = GetTime()
    uniforms:set("flash", "flashStartTime", currentTime)

    -- Schedule removal
    local cancelled = false
    local timerTag = "hitfx_" .. tostring(entity) .. "_" .. tostring(currentTime)

    timer.after_opts({
        delay = duration,
        action = function()
            if not cancelled then
                remove_flash_pass(entity)
            end
        end,
        tag = timerTag
    })

    -- Return cancel function
    return function()
        cancelled = true
        timer.cancel(timerTag)
        remove_flash_pass(entity)
    end
end

--- Flash an entity indefinitely until manually stopped.
--- @param entity Entity The entity to flash
--- @return function cancel Cancel function to stop the flash
function hitfx.flash_start(entity)
    if not registry:valid(entity) then
        return function() end
    end

    local pipeline, uniforms = ensure_flash_components(entity)
    uniforms:set("flash", "flashStartTime", GetTime())

    return function()
        remove_flash_pass(entity)
    end
end

--- Stop any active flash on an entity.
--- @param entity Entity The entity to stop flashing
function hitfx.flash_stop(entity)
    remove_flash_pass(entity)
end

return hitfx
