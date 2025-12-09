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
