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

StatusEffects.STACK_MODE = {
    REPLACE = "replace",
    TIME_EXTEND = "time_extend",
    INTENSITY = "intensity",
    COUNT = "count",
}

--------------------------------------------------------------------------------
-- DOT STATUS EFFECTS
--------------------------------------------------------------------------------

StatusEffects.electrocute = {
    id = "electrocute",
    dot_type = true,
    damage_type = "lightning",
    stack_mode = "intensity",
    max_stacks = 99,
    duration = 5,
    base_dps = 5,
    scaling = "linear",

    icon = "status-electrocute.png",
    icon_position = "above",
    icon_offset = { x = 0, y = -12 },
    icon_scale = 0.5,
    icon_bob = true,
    show_stacks = true,

    shader = "electric_crackle",
    shader_uniforms = { intensity = 0.6 },

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
    damage_type = "fire",
    stack_mode = "intensity",
    max_stacks = 99,
    duration = 5,
    base_dps = 5,
    scaling = "linear",

    icon = "status-burn.png",
    icon_position = "above",
    show_stacks = true,
    shader = "fire_tint",
    shader_uniforms = { intensity = 0.4 },
}

StatusEffects.frozen = {
    id = "frozen",
    dot_type = false,
    stack_mode = "time_extend",
    max_stacks = 20,
    duration_per_stack = 0.5,
    stat_mods = { run_speed = -50 },

    icon = "status-frozen.png",
    icon_position = "above",
    show_stacks = true,
    shader = "ice_tint",
    shader_uniforms = { intensity = 0.7 },
}

StatusEffects.poison = {
    id = "poison",
    dot_type = true,
    damage_type = "poison",
    stack_mode = "intensity",
    max_stacks = 99,
    duration = 6,
    base_dps = 4,
    scaling = "linear",
    spread_chance = 0.1,
    spread_range = 100,

    icon = "status-poison.png",
    icon_position = "above",
    show_stacks = true,
    shader = "poison_tint",
    shader_uniforms = { intensity = 0.5 },
}

StatusEffects.bleed = {
    id = "bleed",
    dot_type = true,
    damage_type = "blood",
    stack_mode = "intensity",
    max_stacks = 50,
    duration = 4,
    base_dps = 3,
    scaling = "linear",

    icon = "status-bleed.png",
    icon_position = "above",
    show_stacks = true,
    shader = "blood_tint",
    shader_uniforms = { intensity = 0.4 },
}

StatusEffects.doom = {
    id = "doom",
    dot_type = false,
    stack_mode = "intensity",
    max_stacks = 100,
    threshold = 100,
    duration = 0,

    icon = "status-doom.png",
    icon_position = "above",
    show_stacks = true,
    shader = "doom_tint",
    shader_uniforms = { intensity = 0.8 },
}

StatusEffects.corrosion = {
    id = "corrosion",
    dot_type = false,
    stack_mode = "intensity",
    max_stacks = 50,
    duration = 8,
    stat_mods_per_stack = { armor = -2 },

    icon = "status-corrosion.png",
    icon_position = "above",
    show_stacks = true,
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
-- BUFF EFFECTS (PoA-inspired)
--------------------------------------------------------------------------------

StatusEffects.poise = {
    id = "poise",
    buff_type = true,
    stack_mode = "intensity",
    max_stacks = 99,
    decay_per_second = 1,
    stat_mods_per_stack = {
        armor = 5,
        block_chance_pct = 1,
        offensive_ability = 2,
    },

    icon = "buff-poise.png",
    icon_position = "above",
    show_stacks = true,
}

StatusEffects.inflame = {
    id = "inflame",
    buff_type = true,
    stack_mode = "intensity",
    max_stacks = 50,
    duration = 10,
    removed_on_hit = true,
    stat_mods_per_stack = {
        offensive_ability = 10,
        fire_modifier_pct = 2,
    },

    icon = "buff-inflame.png",
    icon_position = "above",
    show_stacks = true,
}

StatusEffects.charge = {
    id = "charge",
    buff_type = true,
    stack_mode = "intensity",
    max_stacks = 30,
    stat_mods_per_stack = { run_speed = 1 },

    icon = "buff-charge.png",
    icon_position = "above",
    show_stacks = true,
}

StatusEffects.meditate = {
    id = "meditate",
    buff_type = true,
    stack_mode = "intensity",
    max_stacks = 50,
    stat_mods_per_stack = {
        cold_modifier_pct = 2,
        aether_modifier_pct = 2,
    },

    icon = "buff-meditate.png",
    icon_position = "above",
    show_stacks = true,
}

StatusEffects.bloodrage = {
    id = "bloodrage",
    buff_type = true,
    stack_mode = "intensity",
    max_stacks = 99,
    stat_mods_per_stack = {
        offensive_ability = 5,
        attack_speed = 0.01,
    },
    self_damage_per_stack = 1,

    icon = "buff-bloodrage.png",
    icon_position = "above",
    show_stacks = true,
}

StatusEffects.barrier = {
    id = "barrier",
    buff_type = true,
    stack_mode = "replace",
    max_stacks = 1,
    duration = 10,
    stat_mods = { flat_absorb = 50 },

    icon = "buff-barrier.png",
    icon_position = "above",
}

StatusEffects.haste = {
    id = "haste",
    buff_type = true,
    stack_mode = "replace",
    max_stacks = 1,
    duration = 5,
    stat_mods = {
        attack_speed = 0.3,
        cast_speed = 0.3,
        run_speed = 50,
    },

    icon = "buff-haste.png",
    icon_position = "above",
}

StatusEffects.fortify = {
    id = "fortify",
    buff_type = true,
    stack_mode = "intensity",
    max_stacks = 10,
    duration = 8,
    stat_mods_per_stack = {
        armor = 20,
        damage_taken_reduction_pct = 2,
    },

    icon = "buff-fortify.png",
    icon_position = "above",
    show_stacks = true,
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
