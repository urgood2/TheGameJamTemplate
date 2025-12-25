--[[
================================================================================
STATUS EFFECTS & MARKS DEFINITIONS
================================================================================
Centralized registry for DoTs, buffs, debuffs, and detonatable marks.

Status types:
- dot_type = true: Damage over time (burn, electrocute, poison)
- is_mark = true: Detonatable mark (static_charge, exposed)
- Neither: Simple buff/debuff (slowed, stunned)

Trigger options for marks:
- "lightning", "fire", etc.: Damage type triggers detonation
- "any": Any damage triggers detonation
- "on_damaged": Triggers when THIS entity takes damage (defensive marks)
- { "fire", "lightning" }: Array of damage types
- function(hit): Custom function returning true to detonate
]]

local Particles = require("core.particles")

local StatusEffects = {}

--------------------------------------------------------------------------------
-- DOT STATUS EFFECTS
--------------------------------------------------------------------------------

StatusEffects.electrocute = {
    id = "electrocute",
    dot_type = true,

    -- Visual indicator
    icon = "status-electrocute.png",
    icon_position = "above",
    icon_offset = { x = 0, y = -12 },
    icon_scale = 0.5,
    icon_bob = true,

    -- Shader effect on entity
    shader = "electric_crackle",
    shader_uniforms = { intensity = 0.6 },

    -- Looping particles
    particles = function()
        return Particles.define()
            :shape("line")
            :size(2, 4)
            :color("cyan", "white")
            :velocity(30, 60)
            :lifespan(0.15, 0.25)
            :fade()
    end,
    particle_rate = 0.1,
    particle_orbit = true,
}

StatusEffects.burning = {
    id = "burning",
    dot_type = true,
    icon = "status-burn.png",
    icon_position = "above",
    shader = "fire_tint",
    shader_uniforms = { intensity = 0.4 },
}

StatusEffects.frozen = {
    id = "frozen",
    dot_type = false,
    icon = "status-frozen.png",
    icon_position = "above",
    shader = "ice_tint",
    shader_uniforms = { intensity = 0.7 },
}

--------------------------------------------------------------------------------
-- DETONATABLE MARKS
--------------------------------------------------------------------------------

StatusEffects.static_charge = {
    id = "static_charge",
    is_mark = true,

    -- What triggers detonation
    trigger = "lightning",

    -- Passive effects while marked
    vulnerable = 15,              -- +15% damage taken

    -- Effects on detonation
    damage = 25,                  -- Bonus damage per stack
    chain = 150,                  -- Chain to other marked enemies in range

    -- Meta
    max_stacks = 3,
    duration = 8,

    -- Visual
    icon = "mark-static-charge.png",
    icon_position = "above",
    show_stacks = true,
    shader = "static_buildup",
    shader_uniforms_per_stack = {
        { intensity = 0.2 },
        { intensity = 0.4 },
        { intensity = 0.7 },
    },
}

StatusEffects.exposed = {
    id = "exposed",
    is_mark = true,
    trigger = "any",
    vulnerable = 30,
    duration = 5,
    max_stacks = 1,
    icon = "mark-exposed.png",
    icon_position = "above",
}

StatusEffects.heat_buildup = {
    id = "heat_buildup",
    is_mark = true,
    trigger = "ice",
    vulnerable = 25,
    damage = 40,
    radius = 60,
    duration = 6,
    max_stacks = 1,
    icon = "mark-heat.png",
    icon_position = "above",
}

StatusEffects.oil_slick = {
    id = "oil_slick",
    is_mark = true,
    trigger = "fire",
    slow = 40,
    damage = 50,
    apply = "burning",
    radius = 80,
    duration = 10,
    max_stacks = 1,
    icon = "mark-oil.png",
    icon_position = "above",
}

--------------------------------------------------------------------------------
-- DEFENSIVE MARKS (trigger on_damaged)
--------------------------------------------------------------------------------

StatusEffects.static_shield = {
    id = "static_shield",
    is_mark = true,
    trigger = "on_damaged",

    -- Passive while active
    block = 15,

    -- On trigger (when hit)
    damage = 25,
    chain = 120,
    apply = "static_charge",

    -- Meta
    max_stacks = 1,
    duration = 6,
    uses = 3,

    icon = "mark-static-shield.png",
    icon_position = "above",
    shader = "lightning_shield",
    shader_uniforms = { intensity = 0.5 },
}

StatusEffects.mirror_ward = {
    id = "mirror_ward",
    is_mark = true,
    trigger = "on_damaged",
    reflect = 50,
    duration = 4,
    uses = -1,
    max_stacks = 1,
    icon = "mark-mirror.png",
    icon_position = "above",
}

StatusEffects.mana_barrier = {
    id = "mana_barrier",
    is_mark = true,
    trigger = "on_damaged",
    absorb_to_mana = 0.5,
    block = 10,
    duration = 5,
    uses = -1,
    max_stacks = 1,
    icon = "mark-mana-barrier.png",
    icon_position = "above",
}

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------------------

--- Check if a status effect should be triggered by given damage
--- @param status_def table Status effect definition
--- @param damage_type string Damage type that was dealt
--- @param tags table|nil Tags from the damage source
--- @return boolean
function StatusEffects.shouldTrigger(status_def, damage_type, tags)
    local trigger = status_def.trigger
    if not trigger then return false end

    -- Function trigger
    if type(trigger) == "function" then
        return trigger({ damage_type = damage_type, tags = tags })
    end

    -- "any" trigger
    if trigger == "any" then
        return true
    end

    -- "on_damaged" triggers handled separately
    if trigger == "on_damaged" then
        return false
    end

    -- Array of damage types
    if type(trigger) == "table" then
        for _, t in ipairs(trigger) do
            if t == damage_type then return true end
        end
        return false
    end

    -- Single damage type string
    return trigger == damage_type
end

--- Check if a status is a defensive mark (triggers on_damaged)
--- @param status_def table Status effect definition
--- @return boolean
function StatusEffects.isDefensiveMark(status_def)
    return status_def.trigger == "on_damaged"
end

--- Get status effect by ID
--- @param id string Status effect ID
--- @return table|nil
function StatusEffects.get(id)
    return StatusEffects[id]
end

return StatusEffects
