-- assets/scripts/descent/player.lua
--[[
================================================================================
DESCENT PLAYER MODULE
================================================================================
Player state management for Descent roguelike mode.

Features:
- Stat management (HP, MP, XP, attributes)
- Level-up system with XP thresholds per spec
- Equipment stat integration
- Spell selection event hook

Per PLAN.md F1:
- XP thresholds match spec exactly
- Level-up recalculations match spec
- Emits spell selection event hook

Usage:
    local player = require("descent.player")
    local state = player.create()
    player.add_xp(state, 50)  -- May trigger level up
================================================================================
]]

local Player = {}

-- Dependencies
local spec = require("descent.spec")

-- Event callbacks (set externally)
local event_callbacks = {
    on_level_up = nil,
    on_spell_select = nil,
    on_death = nil,
}

--------------------------------------------------------------------------------
-- XP Thresholds
--------------------------------------------------------------------------------

local MAX_LEVEL = 20

-- XP required to reach a level (spec-locked)
-- Formula: base * level * species_xp_mod
local function xp_for_level(level, species_xp_mod)
    if level <= 1 then
        return 0
    end
    local mod = species_xp_mod or 1
    return spec.stats.xp.base * level * mod
end

--------------------------------------------------------------------------------
-- Stat Calculations
--------------------------------------------------------------------------------

local function calculate_max_hp(level, species_hp_mod)
    local base = spec.stats.hp.base
    local mult = spec.stats.hp.level_multiplier
    species_hp_mod = species_hp_mod or 0

    local raw = (base + species_hp_mod) * (1 + level * mult)
    return math.floor(raw)
end

local function calculate_max_mp(level, species_mp_mod)
    local base = spec.stats.mp.base
    local mult = spec.stats.mp.level_multiplier
    species_mp_mod = species_mp_mod or 0

    local raw = (base + species_mp_mod) * (1 + level * mult)
    return math.floor(raw)
end

local function xp_for_next_level(current_level, species_xp_mod)
    local next_level = current_level + 1
    if next_level > MAX_LEVEL then
        return 999999
    end
    return xp_for_level(next_level, species_xp_mod)
end

--------------------------------------------------------------------------------
-- Player Creation
--------------------------------------------------------------------------------

function Player.create(opts)
    opts = opts or {}

    local species_hp_mod = opts.species_hp_mod or 0
    local species_mp_mod = opts.species_mp_mod or 0
    local species_xp_mod = opts.species_xp_mod or 1

    local starting_level = spec.stats.starting_level
    local max_hp = calculate_max_hp(starting_level, species_hp_mod)
    local max_mp = calculate_max_mp(starting_level, species_mp_mod)

    return {
        name = opts.name or "Player",
        species = opts.species or "human",
        background = opts.background or "gladiator",

        level = starting_level,
        xp = 0,
        xp_to_next = xp_for_next_level(starting_level, species_xp_mod),

        hp = max_hp,
        hp_max = max_hp,
        mp = max_mp,
        mp_max = max_mp,

        str = spec.stats.base_attributes.str,
        dex = spec.stats.base_attributes.dex,
        int = spec.stats.base_attributes.int,

        armor = 0,
        evasion = 0,
        damage_bonus = 0,

        species_hp_mod = species_hp_mod,
        species_mp_mod = species_mp_mod,
        species_xp_mod = species_xp_mod,
        species_bonus = 0,
        species_multiplier = 1.0,

        x = 0,
        y = 0,

        alive = true,
        kills = 0,
        turns_taken = 0,

        god = nil,
        piety = 0,

        spells = {},
        max_spells = 3,

        type = "player",
        id = "player_1",
        entity_type = "player",
        entity_id = "player_1",
    }
end

--------------------------------------------------------------------------------
-- XP and Leveling
--------------------------------------------------------------------------------

function Player.add_xp(state, amount)
    if not state.alive then return 0 end

    state.xp = state.xp + amount
    local levels_gained = 0

    while state.xp >= state.xp_to_next and state.level < MAX_LEVEL do
        state.level = state.level + 1
        levels_gained = levels_gained + 1
        state.xp_to_next = xp_for_next_level(state.level, state.species_xp_mod)

        local old_hp_max = state.hp_max
        local old_mp_max = state.mp_max

        state.hp_max = calculate_max_hp(state.level, state.species_hp_mod)
        state.mp_max = calculate_max_mp(state.level, state.species_mp_mod)

        local hp_gain = state.hp_max - old_hp_max
        local mp_gain = state.mp_max - old_mp_max
        state.hp = math.min(state.hp_max, state.hp + hp_gain)
        state.mp = math.min(state.mp_max, state.mp + mp_gain)

        if event_callbacks.on_level_up then
            event_callbacks.on_level_up(state, state.level)
        end

        if event_callbacks.on_spell_select and #state.spells < state.max_spells then
            event_callbacks.on_spell_select(state, state.level)
        end
    end

    return levels_gained
end

function Player.get_xp_progress(state)
    if state.level >= MAX_LEVEL then
        return 100
    end
    local current_level_xp = xp_for_level(state.level, state.species_xp_mod)
    local next_level_xp = xp_for_level(state.level + 1, state.species_xp_mod)
    local xp_in_level = state.xp - current_level_xp
    local xp_needed = next_level_xp - current_level_xp

    if xp_needed <= 0 then return 100 end
    return math.floor((xp_in_level / xp_needed) * 100)
end

--------------------------------------------------------------------------------
-- HP/MP Management
--------------------------------------------------------------------------------

function Player.heal(state, amount)
    if not state.alive then return 0 end

    local old_hp = state.hp
    state.hp = math.min(state.hp_max, state.hp + amount)
    return state.hp - old_hp
end

function Player.damage(state, amount)
    if not state.alive then return 0 end

    local old_hp = state.hp
    state.hp = math.max(0, state.hp - amount)

    if state.hp <= 0 then
        state.alive = false
        if event_callbacks.on_death then
            event_callbacks.on_death(state, "combat")
        end
    end

    return old_hp - state.hp
end

function Player.restore_mp(state, amount)
    if not state.alive then return 0 end

    local old_mp = state.mp
    state.mp = math.min(state.mp_max, state.mp + amount)
    return state.mp - old_mp
end

function Player.spend_mp(state, amount)
    if state.mp < amount then return false end
    state.mp = state.mp - amount
    return true
end

--------------------------------------------------------------------------------
-- Equipment Integration
--------------------------------------------------------------------------------

function Player.update_equipment_stats(state, inventory)
    if not inventory then return end

    local items = require("descent.items")

    state.armor = items.get_equipment_stat(inventory, "armor")
    state.damage_bonus = items.get_equipment_stat(inventory, "damage")

    local equip_evasion = items.get_equipment_stat(inventory, "evasion")
    local base_evasion = 10 + (state.dex * 2)
    state.evasion = base_evasion + equip_evasion
end

--------------------------------------------------------------------------------
-- Position and Movement
--------------------------------------------------------------------------------

function Player.move_to(state, x, y)
    state.x = x
    state.y = y
end

function Player.get_position(state)
    return state.x, state.y
end

--------------------------------------------------------------------------------
-- Spells
--------------------------------------------------------------------------------

function Player.add_spell(state, spell_id)
    if #state.spells >= state.max_spells then
        return false
    end

    for _, id in ipairs(state.spells) do
        if id == spell_id then
            return false
        end
    end

    table.insert(state.spells, spell_id)
    return true
end

function Player.knows_spell(state, spell_id)
    for _, id in ipairs(state.spells) do
        if id == spell_id then
            return true
        end
    end
    return false
end

--------------------------------------------------------------------------------
-- Event Hooks
--------------------------------------------------------------------------------

function Player.on_level_up(callback)
    event_callbacks.on_level_up = callback
end

function Player.on_spell_select(callback)
    event_callbacks.on_spell_select = callback
end

function Player.on_death(callback)
    event_callbacks.on_death = callback
end

--------------------------------------------------------------------------------
-- Utility
--------------------------------------------------------------------------------

function Player.get_hud_stats(state)
    return {
        level = state.level,
        xp = state.xp,
        xp_to_next = state.xp_to_next,
        xp_progress = Player.get_xp_progress(state),
        hp = state.hp,
        hp_max = state.hp_max,
        mp = state.mp,
        mp_max = state.mp_max,
        str = state.str,
        dex = state.dex,
        int = state.int,
    }
end

function Player.get_xp_thresholds(from_level, to_level, species_xp_mod)
    local thresholds = {}
    local start_level = from_level or 1
    local end_level = to_level or MAX_LEVEL
    local mod = species_xp_mod or 1
    for lvl = start_level, end_level do
        thresholds[lvl] = xp_for_level(lvl, mod)
    end
    return thresholds
end

function Player.reset_callbacks()
    event_callbacks.on_level_up = nil
    event_callbacks.on_spell_select = nil
    event_callbacks.on_death = nil
end

return Player
