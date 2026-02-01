-- assets/scripts/descent/god.lua
--[[
================================================================================
DESCENT GOD SYSTEM
================================================================================
Gods and worship mechanics for Descent roguelike mode.

Features:
- Altar placement per spec floors
- Worship persists across floors
- Piety system (gain/lose)
- God abilities and restrictions
- Trog: Blocks spell casting

Usage:
    local god = require("descent.god")
    god.worship(player, "trog")
    local can_cast, msg = god.can_cast_spell(player)
================================================================================
]]

local God = {}

-- Dependencies
local spec = require("descent.spec")

--------------------------------------------------------------------------------
-- God Definitions
--------------------------------------------------------------------------------

local gods = {
    trog = {
        id = "trog",
        name = "Trog",
        title = "The Berserker",
        description = "Grants berserk rage in combat, but forbids all magic.",
        piety_on_kill = 3,
        piety_decay_rate = 0.1,  -- Per turn without combat
        abilities = {
            {
                id = "berserk",
                name = "Berserk",
                description = "Double damage, reduced defense for 10 turns",
                piety_cost = 30,
                min_piety = 30,
            },
            {
                id = "trog_hand",
                name = "Trog's Hand",
                description = "Regeneration boost for 20 turns",
                piety_cost = 50,
                min_piety = 80,
            },
        },
        restrictions = {
            no_spells = true,  -- Cannot cast any spells
        },
        gifts = {
            weapon_blessing_chance = 0.1,  -- 10% chance on kill
        },
    },
    -- More gods can be added here
}

--------------------------------------------------------------------------------
-- Worship State
--------------------------------------------------------------------------------

function God.get(god_id)
    return gods[god_id]
end

function God.get_all_ids()
    local ids = {}
    for id in pairs(gods) do
        table.insert(ids, id)
    end
    table.sort(ids)
    return ids
end

function God.worship(player, god_id)
    local god = gods[god_id]
    if not god then
        return false, "Unknown god: " .. tostring(god_id)
    end

    -- If already worshipping a different god, must abandon first
    if player.god and player.god ~= god_id then
        return false, "Already worshipping " .. gods[player.god].name
    end

    player.god = god_id
    player.piety = player.piety or 0

    return true, "You begin worshipping " .. god.name .. "!"
end

function God.abandon(player)
    if not player.god then
        return false, "You are not worshipping any god"
    end

    local old_god = gods[player.god]
    local god_name = old_god and old_god.name or "unknown god"

    player.god = nil
    player.piety = 0

    return true, "You have abandoned " .. god_name .. "!"
end

function God.is_worshipping(player, god_id)
    if god_id then
        return player.god == god_id
    end
    return player.god ~= nil
end

function God.get_worshipped_god(player)
    if player.god then
        return gods[player.god]
    end
    return nil
end

--------------------------------------------------------------------------------
-- Piety Management
--------------------------------------------------------------------------------

function God.add_piety(player, amount)
    if not player.god then return 0 end

    local old_piety = player.piety or 0
    player.piety = math.max(0, math.min(200, old_piety + amount))
    return player.piety - old_piety
end

function God.get_piety(player)
    return player.piety or 0
end

function God.on_kill(player, enemy)
    if not player.god then return 0 end

    local god = gods[player.god]
    if god and god.piety_on_kill then
        return God.add_piety(player, god.piety_on_kill)
    end
    return 0
end

function God.decay_piety(player)
    if not player.god then return 0 end

    local god = gods[player.god]
    if god and god.piety_decay_rate then
        local decay = god.piety_decay_rate
        return God.add_piety(player, -decay)
    end
    return 0
end

--------------------------------------------------------------------------------
-- Spell Casting Restriction (Trog)
--------------------------------------------------------------------------------

function God.can_cast_spell(player)
    if not player.god then
        return true, nil
    end

    local god = gods[player.god]
    if god and god.restrictions and god.restrictions.no_spells then
        return false, god.name .. " forbids the use of magic!", 0
    end

    return true, nil
end

--------------------------------------------------------------------------------
-- Abilities
--------------------------------------------------------------------------------

function God.get_abilities(player)
    if not player.god then return {} end

    local god = gods[player.god]
    if not god or not god.abilities then return {} end

    local available = {}
    for _, ability in ipairs(god.abilities) do
        local can_use = (player.piety or 0) >= ability.min_piety
        table.insert(available, {
            id = ability.id,
            name = ability.name,
            description = ability.description,
            cost = ability.piety_cost,
            min_piety = ability.min_piety,
            can_use = can_use,
        })
    end

    return available
end

function God.use_ability(player, ability_id)
    if not player.god then
        return false, "You are not worshipping any god"
    end

    local god = gods[player.god]
    if not god or not god.abilities then
        return false, "This god has no abilities"
    end

    local ability = nil
    for _, a in ipairs(god.abilities) do
        if a.id == ability_id then
            ability = a
            break
        end
    end

    if not ability then
        return false, "Unknown ability: " .. tostring(ability_id)
    end

    if (player.piety or 0) < ability.min_piety then
        return false, "Insufficient piety (need " .. ability.min_piety .. ")"
    end

    -- Deduct piety cost
    God.add_piety(player, -ability.piety_cost)

    return true, ability.name .. " activated!", ability
end

--------------------------------------------------------------------------------
-- Altar System
--------------------------------------------------------------------------------

-- Check if a floor should have an altar (per spec)
function God.floor_has_altar(floor_num)
    local floor_spec = spec.floors.floors[floor_num]
    return floor_spec and floor_spec.altar == true
end

-- Get random god for altar
function God.get_random_god_for_altar()
    local ids = God.get_all_ids()
    if #ids == 0 then return nil end
    -- For now, always Trog (can use rng.choose later)
    return "trog"
end

-- Create altar data
function God.create_altar(god_id)
    local god = gods[god_id]
    if not god then return nil end

    return {
        god_id = god_id,
        god_name = god.name,
        god_title = god.title,
        description = god.description,
    }
end

--------------------------------------------------------------------------------
-- Status Effects from Gods
--------------------------------------------------------------------------------

function God.get_active_effects(player)
    -- Placeholder for god-granted status effects
    return {}
end

--------------------------------------------------------------------------------
-- Info Display
--------------------------------------------------------------------------------

function God.get_worship_info(player)
    if not player.god then
        return {
            worshipping = false,
            message = "You are not worshipping any god.",
        }
    end

    local god = gods[player.god]
    return {
        worshipping = true,
        god_id = player.god,
        god_name = god.name,
        god_title = god.title,
        piety = player.piety or 0,
        abilities = God.get_abilities(player),
    }
end

return God
