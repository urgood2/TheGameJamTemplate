-- assets/scripts/data/elite_modifiers.lua
-- Elite modifier definitions

local entity_cache = require("core.entity_cache")
local timer = require("core.timer")

local modifiers = {}

--============================================
-- STAT MODIFIERS
--============================================

modifiers.tanky = {
    description = "Double HP, larger",
    hp_mult = 2.0,
    size_mult = 1.3,
}

modifiers.fast = {
    description = "50% faster",
    speed_mult = 1.5,
}

modifiers.deadly = {
    description = "75% more damage",
    damage_mult = 1.75,
}

modifiers.armored = {
    description = "Takes 50% less damage",
    damage_reduction = 0.5,
}

--============================================
-- BEHAVIOR MODIFIERS
--============================================

modifiers.vampiric = {
    description = "Heals on hit",
    on_apply = function(e, ctx, helpers)
        local original_on_hit_player = ctx.on_hit_player
        ctx.on_hit_player = function(e, ctx, hit_info, helpers)
            if original_on_hit_player then original_on_hit_player(e, ctx, hit_info, helpers) end
            helpers.heal_enemy(e, ctx.damage * 0.5)
            helpers.spawn_particles("vampiric_heal", e)
        end
    end,
}

modifiers.explosive_death = {
    description = "Explodes on death",
    on_apply = function(e, ctx, helpers)
        local original_on_death = ctx.on_death
        ctx.on_death = function(e, ctx, death_info, helpers)
            if original_on_death then original_on_death(e, ctx, death_info, helpers) end
            helpers.explode(e, 50, 15)
        end
    end,
}

modifiers.summoner_mod = {
    description = "Spawns minions periodically",
    on_apply = function(e, ctx, helpers)
        timer.every(6.0, function()
            if not entity_cache.valid(e) then return false end
            helpers.summon_enemies(e, "goblin", 1)
        end, "elite_" .. e .. "_summon")
    end,
}

modifiers.enraged = {
    description = "Gets faster and stronger at low HP",
    on_apply = function(e, ctx, helpers)
        local triggered = false
        timer.every(0.5, function()
            if not entity_cache.valid(e) then return false end
            if not triggered and helpers.get_hp_percent(e) < 0.3 then
                triggered = true
                ctx.speed = ctx.speed * 1.5
                ctx.damage = ctx.damage * 1.5
                helpers.set_shader(e, "rage_glow")
                helpers.spawn_particles("enrage", e)
            end
        end, "elite_" .. e .. "_enrage")
    end,
}

modifiers.shielded = {
    description = "Immune to damage for first 3 seconds",
    on_apply = function(e, ctx, helpers)
        helpers.set_invulnerable(e, true)
        helpers.set_shader(e, "shield_bubble")
        timer.after(3.0, function()
            if entity_cache.valid(e) then
                helpers.set_invulnerable(e, false)
                helpers.clear_shader(e, "shield_bubble")
            end
        end, "elite_" .. e .. "_shield")
    end,
}

modifiers.regenerating = {
    description = "Slowly regenerates health",
    on_apply = function(e, ctx, helpers)
        timer.every(1.0, function()
            if not entity_cache.valid(e) then return false end
            helpers.heal_enemy(e, ctx.max_hp * 0.02) -- 2% per second
        end, "elite_" .. e .. "_regen")
    end,
}

modifiers.teleporter = {
    description = "Occasionally teleports near player",
    on_apply = function(e, ctx, helpers)
        timer.every(5.0, function()
            if not entity_cache.valid(e) then return false end
            local player_pos = helpers.get_player_position()
            local angle = math.random() * math.pi * 2
            local dist = 80 + math.random() * 40

            local transform = require("core.component_cache").get(e, Transform)
            if transform then
                helpers.spawn_particles("teleport_out", e)
                transform.actualX = player_pos.x + math.cos(angle) * dist
                transform.actualY = player_pos.y + math.sin(angle) * dist
                helpers.spawn_particles("teleport_in", e)
            end
        end, "elite_" .. e .. "_teleport")
    end,
}

--============================================
-- MODIFIER UTILITIES
--============================================

-- Get list of all modifier names
function modifiers.get_all_names()
    local names = {}
    for name, _ in pairs(modifiers) do
        if type(modifiers[name]) == "table" and modifiers[name].description then
            table.insert(names, name)
        end
    end
    return names
end

-- Roll random modifiers
function modifiers.roll_random(count)
    local all = modifiers.get_all_names()
    local result = {}
    local used = {}

    for i = 1, math.min(count, #all) do
        local idx
        repeat
            idx = math.random(1, #all)
        until not used[idx]

        used[idx] = true
        table.insert(result, all[idx])
    end

    return result
end

return modifiers
