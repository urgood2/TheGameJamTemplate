--[[
================================================================================
ACTION API - Easy-to-Use Combat System Wrapper
================================================================================

This module provides a simple, intuitive interface to the powerful combat_system.lua.
It's designed for gameplay testing and rapid iteration.

QUICK START:
    local ActionAPI = require("combat.action_api")

    -- Deal damage
    ActionAPI.damage(ctx, player, enemy, 50, "fire")

    -- Heal
    ActionAPI.heal(ctx, player, player, 30)

    -- Apply status
    ActionAPI.apply_status(ctx, enemy, "burning", { duration = 5 })

    -- Cast prayer
    ActionAPI.cast_prayer(ctx, player, "ember_psalm")

DOCUMENTATION:
    All functions follow a consistent pattern:
    - First parameter is always 'ctx' (combat context)
    - Source entity (when applicable) comes second
    - Target entity comes third
    - Additional parameters follow
    - Optional parameters have sensible defaults

================================================================================
]]

local CombatSystem = require("combat.combat_system")
local Game = CombatSystem.Game
local Core = CombatSystem.Core

local ActionAPI = {}

-- Internal references to combat_system modules
local Effects = Game.Effects
local StatusEngine = Game.StatusEngine
local Systems = Game.Systems
local PetsAndSets = Game.PetsAndSets
local ItemSystem = Game.ItemSystem

--============================================================================
-- DAMAGE FUNCTIONS
--============================================================================

--- Deal simple damage to a target
-- @param ctx: Combat context
-- @param source: Entity dealing damage
-- @param target: Entity receiving damage
-- @param amount: Base damage amount
-- @param damage_type: (Optional) "physical", "fire", "ice", etc. Default "physical"
--
-- Example:
--   ActionAPI.damage(ctx, player, enemy, 50, "fire")
function ActionAPI.damage(ctx, source, target, amount, damage_type)
    damage_type = damage_type or "physical"

    local def = {
        components = {
            { type = damage_type, amount = amount }
        }
    }

    Effects.deal_damage(def)(ctx, source, target)
end

--- Deal weapon-based damage (uses source's weapon stats)
-- @param ctx: Combat context
-- @param source: Entity attacking
-- @param target: Entity being attacked
-- @param scale_pct: (Optional) Weapon damage scaling percentage. Default 100
--
-- Example:
--   ActionAPI.damage_weapon(ctx, player, enemy, 150) -- 150% weapon damage
function ActionAPI.damage_weapon(ctx, source, target, scale_pct)
    scale_pct = scale_pct or 100

    Effects.deal_damage({
        weapon = true,
        scale_pct = scale_pct
    })(ctx, source, target)
end

--- Deal multi-type damage
-- @param ctx: Combat context
-- @param source: Entity dealing damage
-- @param target: Entity receiving damage
-- @param components: Array of {type="fire", amount=50} tables
--
-- Example:
--   ActionAPI.damage_components(ctx, player, enemy, {
--       {type = "fire", amount = 30},
--       {type = "physical", amount = 20}
--   })
function ActionAPI.damage_components(ctx, source, target, components)
    Effects.deal_damage({
        components = components
    })(ctx, source, target)
end

--- Deal damage with type conversions
-- @param ctx: Combat context
-- @param source: Entity dealing damage
-- @param target: Entity receiving damage
-- @param components: Array of damage components
-- @param conversions: Array of {from="physical", to="fire", pct=50} tables
--
-- Example:
--   ActionAPI.damage_with_conversions(ctx, player, enemy,
--       {{type = "physical", amount = 100}},
--       {{from = "physical", to = "fire", pct = 50}}
--   )
function ActionAPI.damage_with_conversions(ctx, source, target, components, conversions)
    Effects.deal_damage({
        components = components,
        skill_conversions = conversions
    })(ctx, source, target)
end

--============================================================================
-- HEALING FUNCTIONS
--============================================================================

--- Heal a target
-- @param ctx: Combat context
-- @param source: Entity causing heal
-- @param target: Entity being healed
-- @param amount: Flat amount to heal
--
-- Example:
--   ActionAPI.heal(ctx, player, ally, 50)
function ActionAPI.heal(ctx, source, target, amount)
    Effects.heal({ flat = amount })(ctx, source, target)
end

--- Heal based on target's max HP percentage
-- @param ctx: Combat context
-- @param source: Entity causing heal
-- @param target: Entity being healed
-- @param percent: Percentage of max HP (0-100)
--
-- Example:
--   ActionAPI.heal_percent(ctx, player, player, 25) -- Heal 25% of max HP
function ActionAPI.heal_percent(ctx, source, target, percent)
    Effects.heal({ percent_of_max = percent })(ctx, source, target)
end

--============================================================================
-- DAMAGE OVER TIME (DoT)
--============================================================================

--- Apply a damage-over-time effect
-- @param ctx: Combat context
-- @param source: Entity applying DoT
-- @param target: Entity receiving DoT
-- @param damage_type: Type of damage ("fire", "poison", etc.)
-- @param dps: Damage per second
-- @param duration: Total duration in seconds
-- @param tick_rate: (Optional) How often to tick in seconds. Default 1.0
--
-- Example:
--   ActionAPI.apply_dot(ctx, player, enemy, "poison", 15, 8, 1.0)
function ActionAPI.apply_dot(ctx, source, target, damage_type, dps, duration, tick_rate)
    tick_rate = tick_rate or 1.0

    Effects.apply_dot({
        type = damage_type,
        dps = dps,
        duration = duration,
        tick = tick_rate
    })(ctx, source, target)
end

--- Remove all DoTs of a specific type from target
-- @param ctx: Combat context
-- @param target: Entity to remove DoT from
-- @param damage_type: Type of DoT to remove
--
-- Example:
--   ActionAPI.remove_dot(ctx, enemy, "poison")
function ActionAPI.remove_dot(ctx, target, damage_type)
    if not target.dots then return end

    for i = #target.dots, 1, -1 do
        if target.dots[i].type == damage_type then
            table.remove(target.dots, i)
        end
    end
end

--============================================================================
-- STATUS EFFECTS
--============================================================================

--- Apply a status effect (buff/debuff)
-- @param ctx: Combat context
-- @param target: Entity receiving status
-- @param status_id: String ID of status
-- @param opts: (Optional) { duration=seconds, stacks=number }
--
-- Example:
--   ActionAPI.apply_status(ctx, player, "haste", { duration = 10 })
function ActionAPI.apply_status(ctx, target, status_id, opts)
    opts = opts or {}
    StatusEngine.apply(ctx, target, status_id, opts)
end

--- Remove a status effect
-- @param ctx: Combat context
-- @param target: Entity to remove status from
-- @param status_id: String ID of status to remove
--
-- Example:
--   ActionAPI.remove_status(ctx, player, "slow")
function ActionAPI.remove_status(ctx, target, status_id)
    StatusEngine.remove(ctx, target, status_id)
end

--- Temporarily modify a stat
-- @param ctx: Combat context
-- @param target: Entity to modify
-- @param stat_name: Name of stat (e.g., "attack_speed", "armor")
-- @param value: Amount to add to base value
-- @param duration: Duration in seconds
--
-- Example:
--   ActionAPI.modify_stat(ctx, player, "attack_speed", 50, 10)
function ActionAPI.modify_stat(ctx, target, stat_name, value, duration)
    Effects.modify_stat({
        id = stat_name .. "_buff",
        name = stat_name,
        base_add = value,
        duration = duration
    })(ctx, target, target)
end

--- Grant a barrier (damage shield)
-- @param ctx: Combat context
-- @param target: Entity receiving barrier
-- @param amount: Barrier amount (flat damage absorption)
-- @param duration: Duration in seconds
--
-- Example:
--   ActionAPI.grant_barrier(ctx, player, 100, 5)
function ActionAPI.grant_barrier(ctx, target, amount, duration)
    Effects.grant_barrier({
        amount = amount,
        duration = duration
    })(ctx, target, target)
end

--============================================================================
-- CROWD CONTROL
--============================================================================

--- Apply stun effect
-- @param ctx: Combat context
-- @param target: Entity to stun
-- @param duration: Duration in seconds
--
-- Example:
--   ActionAPI.apply_stun(ctx, enemy, 2)
function ActionAPI.apply_stun(ctx, target, duration)
    ActionAPI.apply_status(ctx, target, "stunned", { duration = duration })
end

--- Apply slow effect
-- @param ctx: Combat context
-- @param target: Entity to slow
-- @param percent: Slow percentage (0-100)
-- @param duration: Duration in seconds
--
-- Example:
--   ActionAPI.apply_slow(ctx, enemy, 50, 5) -- 50% slow for 5 seconds
function ActionAPI.apply_slow(ctx, target, percent, duration)
    ActionAPI.modify_stat(ctx, target, "run_speed", -percent, duration)
end

--- Apply freeze effect
-- @param ctx: Combat context
-- @param target: Entity to freeze
-- @param duration: Duration in seconds
--
-- Example:
--   ActionAPI.apply_freeze(ctx, enemy, 3)
function ActionAPI.apply_freeze(ctx, target, duration)
    ActionAPI.apply_status(ctx, target, "frozen", { duration = duration })
end

--============================================================================
-- RESISTANCE REDUCTION (RR)
--============================================================================

--- Apply resistance reduction
-- @param ctx: Combat context
-- @param target: Entity to debuff
-- @param damage_type: Type of resistance to reduce
-- @param amount: Amount of reduction (percentage)
-- @param duration: Duration in seconds
-- @param kind: (Optional) "rr1", "rr2", or "rr3". Default "rr1"
--
-- Example:
--   ActionAPI.apply_rr(ctx, enemy, "fire", 25, 8, "rr1")
function ActionAPI.apply_rr(ctx, target, damage_type, amount, duration, kind)
    kind = kind or "rr1"

    Effects.apply_rr({
        type = damage_type,
        amount = amount,
        duration = duration,
        kind = kind
    })(ctx, target, target)
end

--============================================================================
-- UTILITY FUNCTIONS
--============================================================================

--- Force a counter-attack from source to target
-- @param ctx: Combat context
-- @param source: Entity performing counter
-- @param target: Entity being countered
-- @param scale_pct: (Optional) Damage scaling. Default 100
--
-- Example:
--   ActionAPI.force_counter_attack(ctx, enemy, player, 75)
function ActionAPI.force_counter_attack(ctx, source, target, scale_pct)
    scale_pct = scale_pct or 100

    Effects.force_counter_attack({
        scale_pct = scale_pct
    })(ctx, source, target)
end

--- Check if a cooldown is ready
-- @param entity: Entity to check
-- @param key: Cooldown key (e.g., "dash", "fireball")
-- @param ctx: Combat context
-- @return boolean: true if ready, false if on cooldown
--
-- Example:
--   if ActionAPI.check_cooldown(player, "dash", ctx) then
--       -- Dash is ready
--   end
function ActionAPI.check_cooldown(entity, key, ctx)
    entity.timers = entity.timers or {}
    return ctx.time:is_ready(entity.timers, key)
end

--- Set a cooldown timer
-- @param entity: Entity to set cooldown on
-- @param key: Cooldown key
-- @param duration: Cooldown duration in seconds
-- @param ctx: Combat context
--
-- Example:
--   ActionAPI.set_cooldown(player, "dash", 2.0, ctx)
function ActionAPI.set_cooldown(entity, key, duration, ctx)
    entity.timers = entity.timers or {}
    ctx.time:set_cooldown(entity.timers, key, duration)
end

--============================================================================
-- ENTITY CREATION
--============================================================================

--- Create a combat actor
-- @param ctx: Combat context
-- @param template: Template table with entity properties
-- @return entity: Created entity
--
-- Example:
--   local enemy = ActionAPI.create_actor(ctx, {
--       name = "Goblin",
--       max_health = 100,
--       stats = { physique = 10, cunning = 15 }
--   })
function ActionAPI.create_actor(ctx, template)
    -- Create basic entity structure
    local entity = {
        name = template.name or "Actor",
        max_health = template.max_health or 100,
        hp = template.max_health or 100,
        max_energy = template.max_energy or 100,
        energy = template.max_energy or 100,
        level = template.level or 1,
        timers = {},
        statuses = {},
        dots = {},
        equipped = {},
        tags = template.tags or {}
    }

    -- Create stats
    local stat_defs, damage_types = Core.Stats.make()
    entity.stats = Core.Stats.new(stat_defs)

    -- Apply template stats
    if template.stats then
        for stat_name, value in pairs(template.stats) do
            entity.stats:add_base(stat_name, value)
        end
    end

    entity.stats:recompute()

    return entity
end

--- Spawn a pet
-- @param ctx: Combat context
-- @param owner: Owner entity
-- @param template: Pet template
-- @return pet: Created pet entity
--
-- Example:
--   local pet = ActionAPI.spawn_pet(ctx, player, {
--       name = "Fire Imp",
--       inherit_damage_mult = 0.6
--   })
function ActionAPI.spawn_pet(ctx, owner, template)
    return PetsAndSets.spawn_pet(ctx, owner, template)
end

--============================================================================
-- QUERY FUNCTIONS
--============================================================================

--- Get a stat value from an entity
-- @param entity: Entity to query
-- @param stat_name: Name of stat
-- @return number: Computed stat value
--
-- Example:
--   local armor = ActionAPI.get_stat(player, "armor")
function ActionAPI.get_stat(entity, stat_name)
    if not entity.stats then return 0 end
    return entity.stats:get(stat_name)
end

--- Check if entity is alive
-- @param entity: Entity to check
-- @return boolean: true if alive, false if dead
--
-- Example:
--   if ActionAPI.is_alive(enemy) then
--       -- Enemy is still alive
--   end
function ActionAPI.is_alive(entity)
    return entity and not entity.dead and (entity.hp or 0) > 0
end

--- Get entity's HP as a percentage
-- @param entity: Entity to check
-- @return number: HP percentage (0-100)
--
-- Example:
--   local hp_pct = ActionAPI.get_hp_percent(player)
--   if hp_pct < 25 then
--       -- Low health!
--   end
function ActionAPI.get_hp_percent(entity)
    local max_hp = entity.max_health or entity.stats:get("health")
    local current_hp = entity.hp or max_hp
    return (current_hp / max_hp) * 100
end

--============================================================================
-- EVENT SYSTEM
--============================================================================

--- Emit a game event (for hazards, VFX, SFX, etc.)
-- This is the bridge between Lua logic and your game engine
-- @param ctx: Combat context
-- @param event_name: String event name
-- @param data: Table of event data
--
-- Example:
--   ActionAPI.emit(ctx, "spawn_vfx", {
--       effect = "explosion",
--       position = {x = 100, y = 200}
--   })
function ActionAPI.emit(ctx, event_name, data)
    if ctx.bus then
        ctx.bus:emit(event_name, data)
    end
end

--- Create a hazard on the ground
-- @param ctx: Combat context
-- @param position: {x, y} table
-- @param hazard_type: "fire", "poison", "ice", etc.
-- @param opts: { radius=number, dps=number, duration=seconds, ... }
--
-- Example:
--   ActionAPI.create_hazard(ctx, {x = 100, y = 200}, "fire", {
--       radius = 3,
--       dps = 20,
--       duration = 5
--   })
function ActionAPI.create_hazard(ctx, position, hazard_type, opts)
    opts = opts or {}

    ActionAPI.emit(ctx, "spawn_hazard", {
        pos = position,
        type = hazard_type,
        radius = opts.radius or 2,
        dps = opts.dps or 10,
        duration = opts.duration or 5,
        source = ctx.source
    })
end

--- Apply an AoE effect
-- @param ctx: Combat context
-- @param source: Entity causing AoE
-- @param position: {x, y} center point
-- @param radius: Radius in units
-- @param effect_fn: function(ctx, source, target) called for each target
--
-- Example:
--   ActionAPI.aoe(ctx, player, {x = 100, y = 200}, 5, function(ctx, src, tgt)
--       ActionAPI.damage(ctx, src, tgt, 30, "fire")
--   end)
function ActionAPI.aoe(ctx, source, position, radius, effect_fn)
    ActionAPI.emit(ctx, "aoe_effect", {
        source = source,
        pos = position,
        radius = radius,
        effect_fn = effect_fn
    })
end

--============================================================================
-- PRAYER SYSTEM
--============================================================================

ActionAPI.prayers = {}

--- Register a prayer definition
-- @param prayer_def: { id, name, description, cooldown, effect=function(ctx, caster) }
--
-- Example:
--   ActionAPI.register_prayer({
--       id = "divine_shield",
--       name = "Divine Shield",
--       description = "Grant immunity for 3 seconds",
--       cooldown = 60,
--       effect = function(ctx, caster)
--           ActionAPI.apply_status(ctx, caster, "immune", { duration = 3 })
--       end
--   })
function ActionAPI.register_prayer(prayer_def)
    if not prayer_def.id then
        error("Prayer must have an 'id' field")
    end

    ActionAPI.prayers[prayer_def.id] = prayer_def
end

--- Bulk register prayers from a data file
-- @param prayers_table: Table of prayer definitions
--
-- Example:
--   local prayers = require("data.prayers")
--   ActionAPI.register_all_prayers(prayers)
function ActionAPI.register_all_prayers(prayers_table)
    for id, def in pairs(prayers_table) do
        -- Skip non-table entries (e.g., localization helper functions)
        if type(def) == "table" then
            def.id = def.id or id
            ActionAPI.register_prayer(def)
        end
    end
end

--- Check if a prayer is ready to cast
-- @param caster: Entity casting
-- @param prayer_id: Prayer ID
-- @param ctx: Combat context
-- @return boolean: true if ready
--
-- Example:
--   if ActionAPI.is_prayer_ready(player, "divine_shield", ctx) then
--       -- Can cast
--   end
function ActionAPI.is_prayer_ready(caster, prayer_id, ctx)
    local prayer = ActionAPI.prayers[prayer_id]
    if not prayer then return false end

    caster.timers = caster.timers or {}
    local ready_time = caster.timers[prayer_id] or 0
    local now = ctx.time and ctx.time.now or 0

    return now >= ready_time
end

--- Get remaining cooldown in seconds
-- @param caster: Entity to check
-- @param prayer_id: Prayer ID
-- @param ctx: Combat context
-- @return number: Seconds remaining (0 if ready)
--
-- Example:
--   local cd = ActionAPI.get_prayer_cooldown(player, "divine_shield", ctx)
--   print("Ready in " .. cd .. " seconds")
function ActionAPI.get_prayer_cooldown(caster, prayer_id, ctx)
    caster.timers = caster.timers or {}
    local ready_time = caster.timers[prayer_id] or 0
    local now = ctx.time and ctx.time.now or 0

    return math.max(0, ready_time - now)
end

--- Cast a prayer
-- @param ctx: Combat context
-- @param caster: Entity casting the prayer
-- @param prayer_id: String ID of prayer
-- @return boolean, string: success, error_message
--
-- Example:
--   local success, err = ActionAPI.cast_prayer(ctx, player, "divine_shield")
--   if not success then
--       print("Failed: " .. err)
--   end
function ActionAPI.cast_prayer(ctx, caster, prayer_id)
    local prayer = ActionAPI.prayers[prayer_id]

    if not prayer then
        return false, "Prayer not found: " .. tostring(prayer_id)
    end

    -- Check cooldown
    if not ActionAPI.is_prayer_ready(caster, prayer_id, ctx) then
        local remaining = ActionAPI.get_prayer_cooldown(caster, prayer_id, ctx)
        return false, string.format("On cooldown (%.1fs remaining)", remaining)
    end

    -- Execute the prayer effect
    local success, err = pcall(prayer.effect, ctx, caster)

    if not success then
        return false, "Prayer effect error: " .. tostring(err)
    end

    -- Set cooldown
    caster.timers = caster.timers or {}
    local now = ctx.time and ctx.time.now or 0
    caster.timers[prayer_id] = now + (prayer.cooldown or 30)

    -- Emit event for UI/VFX
    ActionAPI.emit(ctx, "prayer_cast", {
        caster = caster,
        prayer_id = prayer_id,
        prayer_name = prayer.name
    })

    return true
end

--============================================================================
-- EXPORTS
--============================================================================

return ActionAPI
