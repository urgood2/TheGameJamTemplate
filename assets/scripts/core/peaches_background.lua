-- peaches_background.lua
-- Background shader phase tweening system
-- Extracted from gameplay.lua to reduce local variable count

local timer = require("core.timer")
local Easing = require("util.easing")

local M = {}

-- Internal state
local defaults = nil

-- Phase-specific settings (action uses shader defaults)
M.targets = {
    planning = {
        blob_count = 4.4,
        blob_spacing = -1.2,
        shape_amplitude = 0.14,
        distortion_strength = 2.5,
        noise_strength = 0.08,
        radial_falloff = 0.12,
        wave_strength = 1.1,
        highlight_gain = 2.6,
        cl_shift = -0.04,
        edge_softness_min = 0.45,
        edge_softness_max = 0.86,
        colorTint = { x = 0.22, y = 0.55, z = 0.78 },
        blob_color_blend = 0.55,
        hue_shift = 0.45,
        pixel_size = 5.0,
        pixel_enable = 1.0,
        blob_offset = { x = -0.05, y = -0.05 },
        movement_randomness = 7.5
    },
    shop = {
        blob_count = 6.8,
        blob_spacing = -0.4,
        shape_amplitude = 0.32,
        distortion_strength = 5.0,
        noise_strength = 0.22,
        radial_falloff = -0.15,
        wave_strength = 2.3,
        highlight_gain = 4.6,
        cl_shift = 0.18,
        edge_softness_min = 0.24,
        edge_softness_max = 0.55,
        colorTint = { x = 0.82, y = 0.50, z = 0.28 },
        blob_color_blend = 0.78,
        hue_shift = 0.05,
        pixel_size = 7.0,
        pixel_enable = 1.0,
        blob_offset = { x = 0.08, y = -0.14 },
        movement_randomness = 12.0
    }
}

-- Vector helpers
local function make_vec2(x, y)
    if _G.Vector2 then
        return _G.Vector2(x, y)
    end
    return { x = x, y = y }
end

local function make_vec3(x, y, z)
    if _G.Vector3 then
        return _G.Vector3(x, y, z)
    end
    return { x = x, y = y, z = z }
end

local function copy_vec2(v)
    if not v then return { x = 0, y = 0 } end
    return { x = v.x or v[1] or 0, y = v.y or v[2] or 0 }
end

local function copy_vec3(v)
    if not v then return { x = 0, y = 0, z = 0 } end
    return { x = v.x or v[1] or 0, y = v.y or v[2] or 0, z = v.z or v[3] or 0 }
end

-- Initialize defaults from current shader uniforms
local function ensure_defaults()
    if defaults or not globalShaderUniforms then
        return defaults ~= nil
    end

    defaults = {
        blob_count = globalShaderUniforms:get("peaches_background", "blob_count") or 0.0,
        blob_spacing = globalShaderUniforms:get("peaches_background", "blob_spacing") or 0.0,
        shape_amplitude = globalShaderUniforms:get("peaches_background", "shape_amplitude") or 0.0,
        distortion_strength = globalShaderUniforms:get("peaches_background", "distortion_strength") or 0.0,
        noise_strength = globalShaderUniforms:get("peaches_background", "noise_strength") or 0.0,
        radial_falloff = globalShaderUniforms:get("peaches_background", "radial_falloff") or 0.0,
        wave_strength = globalShaderUniforms:get("peaches_background", "wave_strength") or 0.0,
        highlight_gain = globalShaderUniforms:get("peaches_background", "highlight_gain") or 0.0,
        cl_shift = globalShaderUniforms:get("peaches_background", "cl_shift") or 0.0,
        edge_softness_min = globalShaderUniforms:get("peaches_background", "edge_softness_min") or 0.0,
        edge_softness_max = globalShaderUniforms:get("peaches_background", "edge_softness_max") or 0.0,
        colorTint = copy_vec3(globalShaderUniforms:get("peaches_background", "colorTint")),
        blob_color_blend = globalShaderUniforms:get("peaches_background", "blob_color_blend") or 0.0,
        hue_shift = globalShaderUniforms:get("peaches_background", "hue_shift") or 0.0,
        pixel_size = globalShaderUniforms:get("peaches_background", "pixel_size") or 0.0,
        pixel_enable = globalShaderUniforms:get("peaches_background", "pixel_enable") or 0.0,
        blob_offset = copy_vec2(globalShaderUniforms:get("peaches_background", "blob_offset")),
        movement_randomness = globalShaderUniforms:get("peaches_background", "movement_randomness") or 0.0
    }

    M.targets.action = {
        blob_count = defaults.blob_count,
        blob_spacing = defaults.blob_spacing,
        shape_amplitude = defaults.shape_amplitude,
        distortion_strength = defaults.distortion_strength,
        noise_strength = defaults.noise_strength,
        radial_falloff = defaults.radial_falloff,
        wave_strength = defaults.wave_strength,
        highlight_gain = defaults.highlight_gain,
        cl_shift = defaults.cl_shift,
        edge_softness_min = defaults.edge_softness_min,
        edge_softness_max = defaults.edge_softness_max,
        colorTint = copy_vec3(defaults.colorTint),
        blob_color_blend = defaults.blob_color_blend,
        hue_shift = defaults.hue_shift,
        pixel_size = defaults.pixel_size,
        pixel_enable = defaults.pixel_enable,
        blob_offset = copy_vec2(defaults.blob_offset),
        movement_randomness = defaults.movement_randomness
    }

    return true
end

-- Tween helpers
local function tween_scalar(name, target, duration, tag_suffix)
    if target == nil then return end
    timer.tween_scalar(
        duration,
        function() return globalShaderUniforms:get("peaches_background", name) end,
        function(v) globalShaderUniforms:set("peaches_background", name, v) end,
        target,
        Easing.inOutQuad.f,
        nil,
        "peaches_bg_" .. name .. (tag_suffix or "")
    )
end

local function tween_vec2(name, target, duration, tag_suffix)
    if not target then return end
    local baseTag = "peaches_bg_" .. name .. (tag_suffix or "")

    timer.tween_scalar(
        duration,
        function()
            local current = globalShaderUniforms:get("peaches_background", name)
            return current and current.x or 0
        end,
        function(v)
            local current = globalShaderUniforms:get("peaches_background", name)
            local y = (current and current.y) or target.y or 0
            globalShaderUniforms:set("peaches_background", name, make_vec2(v, y))
        end,
        target.x,
        Easing.inOutQuad.f,
        nil,
        baseTag .. "_x"
    )

    timer.tween_scalar(
        duration,
        function()
            local current = globalShaderUniforms:get("peaches_background", name)
            return current and current.y or 0
        end,
        function(v)
            local current = globalShaderUniforms:get("peaches_background", name)
            local x = (current and current.x) or target.x or 0
            globalShaderUniforms:set("peaches_background", name, make_vec2(x, v))
        end,
        target.y,
        Easing.inOutQuad.f,
        nil,
        baseTag .. "_y"
    )
end

local function tween_vec3(name, target, duration, tag_suffix)
    if not target then return end
    local baseTag = "peaches_bg_" .. name .. (tag_suffix or "")

    timer.tween_scalar(
        duration,
        function()
            local current = globalShaderUniforms:get("peaches_background", name)
            return current and current.x or 0
        end,
        function(v)
            local current = globalShaderUniforms:get("peaches_background", name)
            local y = (current and current.y) or target.y or 0
            local z = (current and current.z) or target.z or 0
            globalShaderUniforms:set("peaches_background", name, make_vec3(v, y, z))
        end,
        target.x,
        Easing.inOutQuad.f,
        nil,
        baseTag .. "_x"
    )

    timer.tween_scalar(
        duration,
        function()
            local current = globalShaderUniforms:get("peaches_background", name)
            return current and current.y or 0
        end,
        function(v)
            local current = globalShaderUniforms:get("peaches_background", name)
            local x = (current and current.x) or target.x or 0
            local z = (current and current.z) or target.z or 0
            globalShaderUniforms:set("peaches_background", name, make_vec3(x, v, z))
        end,
        target.y,
        Easing.inOutQuad.f,
        nil,
        baseTag .. "_y"
    )

    timer.tween_scalar(
        duration,
        function()
            local current = globalShaderUniforms:get("peaches_background", name)
            return current and current.z or 0
        end,
        function(v)
            local current = globalShaderUniforms:get("peaches_background", name)
            local x = (current and current.x) or target.x or 0
            local y = (current and current.y) or target.y or 0
            globalShaderUniforms:set("peaches_background", name, make_vec3(x, y, v))
        end,
        target.z,
        Easing.inOutQuad.f,
        nil,
        baseTag .. "_z"
    )
end

-- Public API

--- Tween all background parameters to target values
--- @param targets table Table of target values
--- @param duration number|nil Duration in seconds (default 1.0)
function M.tween(targets, duration)
    if not targets or not ensure_defaults() then
        return
    end

    local dur = duration or 1.0
    tween_scalar("blob_count", targets.blob_count, dur)
    tween_scalar("blob_spacing", targets.blob_spacing, dur)
    tween_scalar("shape_amplitude", targets.shape_amplitude, dur)
    tween_scalar("distortion_strength", targets.distortion_strength, dur)
    tween_scalar("noise_strength", targets.noise_strength, dur)
    tween_scalar("radial_falloff", targets.radial_falloff, dur)
    tween_scalar("wave_strength", targets.wave_strength, dur)
    tween_scalar("highlight_gain", targets.highlight_gain, dur)
    tween_scalar("cl_shift", targets.cl_shift, dur)
    tween_scalar("edge_softness_min", targets.edge_softness_min, dur)
    tween_scalar("edge_softness_max", targets.edge_softness_max, dur)
    tween_vec3("colorTint", targets.colorTint, dur)
    tween_scalar("blob_color_blend", targets.blob_color_blend, dur)
    tween_scalar("hue_shift", targets.hue_shift, dur)
    tween_scalar("pixel_size", targets.pixel_size, dur)
    tween_scalar("pixel_enable", targets.pixel_enable, dur)
    tween_vec2("blob_offset", targets.blob_offset, dur)
    tween_scalar("movement_randomness", targets.movement_randomness, dur)
end

--- Apply a named phase preset
--- @param phase string Phase name: "action", "planning", or "shop"
--- @param duration number|nil Duration in seconds (default 1.0)
function M.applyPhase(phase, duration)
    if not globalShaderUniforms then
        return
    end
    if not ensure_defaults() then
        return
    end
    M.tween(M.targets[phase], duration or 1.0)
end

--- Get current defaults (initializes if needed)
--- @return table|nil defaults Current default values
function M.getDefaults()
    ensure_defaults()
    return defaults
end

return M
