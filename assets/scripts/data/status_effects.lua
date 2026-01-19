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
-- NEW STATUS EFFECTS (Phase 1 Demo Implementation)
--------------------------------------------------------------------------------

StatusEffects.arcane_charge = {
    id = "arcane_charge",
    buff_type = true,
    stack_mode = "count",
    max_stacks = 10,
    duration = 0,  -- Permanent until consumed

    -- Each stack represents stored arcane energy
    -- Consumed by abilities that scale with charges (e.g., wand effects, spells)
    -- Consumption handled by: StatusEngine.remove(ctx, target, "arcane_charge", stacks_to_consume)
    stat_mods_per_stack = {
        spell_power = 5,
    },

    icon = "buff-arcane-charge.png",
    icon_position = "above",
    show_stacks = true,
    shader = "arcane_glow",
    shader_uniforms = { intensity = 0.3 },
}

StatusEffects.focused = {
    id = "focused",
    buff_type = true,
    stack_mode = "replace",
    max_stacks = 1,
    duration = 5,

    -- Concentration buff - increases accuracy and crit
    stat_mods = {
        offensive_ability = 50,
        crit_chance = 15,
    },

    icon = "buff-focused.png",
    icon_position = "above",
    shader = "focus_outline",
    shader_uniforms = { intensity = 0.4 },
}

--------------------------------------------------------------------------------
-- ELEMENTAL FORM STATUS EFFECTS
--------------------------------------------------------------------------------
-- TODO: The `aura` field is defined for these forms but not yet processed by
-- StatusEngine.tick(). Aura effects (applying statuses, damage, slow to nearby
-- enemies) will need an aura tick system in gameplay.lua or combat_system.lua
-- to become functional. For now, only stat_mods and visual effects (shader,
-- particles) are active.

StatusEffects.fireform = {
    id = "fireform",
    buff_type = true,
    stack_mode = "replace",
    max_stacks = 1,
    duration = 15,

    -- Fire form: increased fire damage, burn nearby enemies
    stat_mods = {
        fire_modifier_pct = 25,
        fire_resistance = 50,
    },
    aura = {
        radius = 80,
        tick_interval = 1.0,
        apply_status = "burning",
        apply_stacks = 1,
    },

    icon = "form-fire.png",
    icon_position = "above",
    icon_scale = 0.8,
    shader = "fire_aura",
    shader_uniforms = { intensity = 0.7, color = { 1.0, 0.4, 0.1 } },

    particles = function()
        local Particles = require("core.particles")
        return Particles.define()
            :shape("circle")
            :size(3, 6)
            :color("orange", "red")
            :velocity(20, 40)
            :lifespan(0.3, 0.5)
            :fade()
    end,
    particle_rate = 0.05,
}

StatusEffects.iceform = {
    id = "iceform",
    buff_type = true,
    stack_mode = "replace",
    max_stacks = 1,
    duration = 15,

    -- Ice form: increased cold damage, slow nearby enemies
    stat_mods = {
        cold_modifier_pct = 25,
        cold_resistance = 50,
        run_speed = -20,  -- Slower movement in ice form
    },
    aura = {
        radius = 100,
        tick_interval = 0.5,
        slow = 30,  -- Slow nearby enemies by 30%
    },

    icon = "form-ice.png",
    icon_position = "above",
    icon_scale = 0.8,
    shader = "ice_aura",
    shader_uniforms = { intensity = 0.6, color = { 0.3, 0.7, 1.0 } },

    particles = function()
        local Particles = require("core.particles")
        return Particles.define()
            :shape("diamond")
            :size(2, 4)
            :color("cyan", "white")
            :velocity(10, 25)
            :lifespan(0.4, 0.6)
            :fade()
    end,
    particle_rate = 0.08,
}

StatusEffects.stormform = {
    id = "stormform",
    buff_type = true,
    stack_mode = "replace",
    max_stacks = 1,
    duration = 15,

    -- Storm form: increased lightning damage, chain attacks
    stat_mods = {
        lightning_modifier_pct = 25,
        lightning_resistance = 50,
        attack_speed = 0.15,
    },
    aura = {
        radius = 120,
        tick_interval = 2.0,
        damage = 15,
        damage_type = "lightning",
        chain = 2,  -- Chain to 2 targets
    },

    icon = "form-storm.png",
    icon_position = "above",
    icon_scale = 0.8,
    shader = "electric_aura",
    shader_uniforms = { intensity = 0.8, color = { 0.8, 0.8, 1.0 } },

    particles = function()
        local Particles = require("core.particles")
        return Particles.define()
            :shape("line")
            :size(1, 3)
            :color("white", "cyan")
            :velocity(40, 80)
            :lifespan(0.1, 0.2)
            :fade()
    end,
    particle_rate = 0.03,
}

StatusEffects.voidform = {
    id = "voidform",
    buff_type = true,
    stack_mode = "replace",
    max_stacks = 1,
    duration = 15,

    -- Void form: increased aether damage, damage reduction, life drain
    stat_mods = {
        aether_modifier_pct = 25,
        void_resistance = 50,
        damage_taken_reduction_pct = 15,
    },
    aura = {
        radius = 60,
        tick_interval = 1.0,
        damage = 10,
        damage_type = "aether",
        lifesteal = 0.5,  -- 50% of damage heals player
    },

    icon = "form-void.png",
    icon_position = "above",
    icon_scale = 0.8,
    shader = "void_aura",
    shader_uniforms = { intensity = 0.9, color = { 0.5, 0.1, 0.8 } },

    particles = function()
        local Particles = require("core.particles")
        return Particles.define()
            :shape("circle")
            :size(2, 5)
            :color("purple", "black")
            :velocity(15, 30)
            :lifespan(0.5, 0.8)
            :fade()
    end,
    particle_rate = 0.06,
}

--------------------------------------------------------------------------------
-- STATUS EFFECT ALIASES (for spec compatibility)
--------------------------------------------------------------------------------

-- Alias scorch to burning (same effect, different name)
StatusEffects.scorch = StatusEffects.burning

-- Alias freeze to frozen (same effect, different name)
StatusEffects.freeze = StatusEffects.frozen

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
