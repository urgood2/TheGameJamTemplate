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

-- Trigger card with cooldown pie effect
-- Note: Using single pass to avoid double-draw distortion
ShaderPresets.trigger_card = {
    id = "trigger_card",
    passes = {"cooldown_pie"},
    needs_atlas_uniforms = true,
    uniforms = {
        cooldown_progress = 0.0,
        dim_amount = 0.4,
        flash_intensity = 0.0,
    },
}

-- Card outline effect (standalone)
-- Use as a post-pass after 3d_skew for outlined cards
ShaderPresets.card_outline = {
    id = "card_outline",
    passes = {"efficient_pixel_outline"},
    needs_atlas_uniforms = false, -- works on post-pass texture, not atlas
    uniforms = {
        outlineColor = {0.0, 0.0, 0.0, 1.0}, -- black outline
        outlineType = 2, -- 8-way (includes diagonals for smoother outlines)
        thickness = 1.0, -- 1 pixel thick
    },
}

-- Card with colored outline (example: gold for rare cards)
ShaderPresets.card_outline_gold = {
    id = "card_outline_gold",
    passes = {"efficient_pixel_outline"},
    needs_atlas_uniforms = false,
    uniforms = {
        outlineColor = {1.0, 0.84, 0.0, 1.0}, -- gold outline (#FFD700)
        outlineType = 2,
        thickness = 1.5,
    },
}

-- Full card effect: 3d_skew + outline combined
-- Use this preset to replace the default card shader setup
ShaderPresets.card_with_outline = {
    id = "card_with_outline",
    passes = {"3d_skew", "efficient_pixel_outline"},
    pass_uniforms = {
        ["efficient_pixel_outline"] = {
            outlineColor = {0.0, 0.0, 0.0, 1.0},
            outlineType = 2,
            thickness = 1.0,
        },
    },
    -- 3d_skew needs atlas uniforms, outline doesn't
    pass_atlas_uniforms = {
        ["3d_skew"] = true,
        ["efficient_pixel_outline"] = false,
    },
}

return ShaderPresets
