--[[
================================================================================
WAND MODIFIER AGGREGATION AND APPLICATION SYSTEM
================================================================================
Handles modifier card stacking, application to actions, and multicast logic.

Responsibilities:
- Aggregate modifier properties from card stack
- Apply modifiers to action cards
- Determine collision behaviors
- Calculate multicast angles
- Track on-hit effects

Integration:
- Used by wand_actions.lua to modify projectile properties
- Reads from card definitions in card_eval_order_test.lua
================================================================================
]]--

local WandModifiers = {}

--[[
================================================================================
MODIFIER AGGREGATION
================================================================================
Takes a list of modifier cards and combines them into a single aggregate.
]]--

--- Creates an empty modifier aggregate with default values
--- @return table Modifier aggregate
function WandModifiers.createAggregate()
    return {
        -- Speed modifiers
        speedMultiplier = 1.0,
        speedBonus = 0,           -- additive bonus (cards with speed_modifier)

        -- Damage modifiers
        damageMultiplier = 1.0,
        damageBonus = 0,          -- flat bonus (cards with damage_modifier)

        -- Size modifiers
        sizeMultiplier = 1.0,

        -- Lifetime modifiers
        lifetimeMultiplier = 1.0,
        lifetimeBonus = 0,        -- additive bonus in ms

        -- Spread modifiers
        spreadAngleBonus = 0,     -- additive (cards with spread_modifier)

        -- Crit modifiers
        critChanceBonus = 0,      -- additive % (cards with critical_hit_chance_modifier)

        -- Behavior modifiers
        pierceCount = 0,
        bounceCount = 0,
        bounceDampening = 0.8,
        explosionRadius = nil,
        explosionDamageMult = 1.0,

        -- Homing
        homingEnabled = false,
        homingStrength = 0,
        homingMaxSpeed = 0,
        homingTarget = nil,

        -- Seeking (alt homing)
        seekStrength = 0,

        -- Auto-aim
        autoAim = false,

        -- Ricochet
        ricochetCount = 0,

        -- Multicast
        multicastCount = 1,       -- 1 = single shot
        circularPattern = false,
        spreadAngle = math.pi / 6, -- default 30 degrees

        -- On-hit effects
        freezeOnHit = false,
        freezeDuration = 2.0,

        chainLightning = false,
        chainLightningTargets = 3,
        chainLightningDamageMult = 0.5,

        lifesteal = 0,            -- percent of damage healed

        knockback = 0,
        slowOnHit = 0,            -- percent slow
        slowDuration = 0,

        healOnHit = 0,            -- flat heal amount

        statusEffects = {},       -- list of status effects to apply

        -- Trigger modifiers
        triggerOnCollision = false,
        triggerOnTimer = nil,     -- milliseconds
        triggerOnDeath = false,

        -- Special modifiers
        phaseInOut = false,
        longDistanceCast = false,
        teleportCastFromEnemy = false,

        forceCrit = false,

        -- Meta modifiers (affect wand state)
        addCardsToBlock = 0,
        immunityDuration = 0,

        -- Stored modifier cards for on-hit processing
        modifierCards = {},

        -- Snapshot of player stats
        statsSnapshot = {},

        -- Total mana cost of modifiers
        manaCost = 0,
    }
end

--- Aggregates a list of modifier cards into a single modifier aggregate
--- @param modifierCards table List of modifier card objects
--- @return table Modifier aggregate
function WandModifiers.aggregate(modifierCards)
    local agg = WandModifiers.createAggregate()

    if not modifierCards or #modifierCards == 0 then
        return agg
    end

    -- Store original cards for reference
    agg.modifierCards = modifierCards

    -- Apply each modifier card
    for _, card in ipairs(modifierCards) do
        WandModifiers.applyCardToAggregate(agg, card)
    end

    -- Post-processing: compute derived values

    -- Speed: apply bonus to multiplier
    if agg.speedBonus ~= 0 then
        -- speedBonus is typically -3 to +3, treating as % change per point
        -- -3 = 70% speed, 0 = 100%, +3 = 130%
        agg.speedMultiplier = agg.speedMultiplier * (1.0 + agg.speedBonus * 0.1)
    end

    -- Lifetime: apply bonus (in seconds, converted from ms in cards)
    if agg.lifetimeBonus ~= 0 then
        -- lifetimeBonus is typically -1 to +1, treating as multiplier change
        agg.lifetimeMultiplier = agg.lifetimeMultiplier * (1.0 + agg.lifetimeBonus)
    end

    -- Homing: enable if seek_strength or homing_strength present
    if agg.seekStrength > 0 then
        agg.homingEnabled = true
        agg.homingStrength = agg.seekStrength
    end

    -- Ricochet -> Bounce conversion
    if agg.ricochetCount > 0 and agg.bounceCount == 0 then
        agg.bounceCount = agg.ricochetCount
    end

    return agg
end

--- Applies a single modifier card to an aggregate
--- @param agg table Modifier aggregate
--- @param card table Modifier card definition
function WandModifiers.applyCardToAggregate(agg, card)
    if not card then return end

    -- Sum mana cost
    agg.manaCost = agg.manaCost + (card.mana_cost or 0)

    -- Damage modifiers
    if card.damage_modifier and card.damage_modifier ~= 0 then
        agg.damageBonus = agg.damageBonus + card.damage_modifier
    end

    -- Speed modifiers
    if card.speed_modifier and card.speed_modifier ~= 0 then
        agg.speedBonus = agg.speedBonus + card.speed_modifier
    end

    -- Size modifiers
    if card.size_multiplier then
        agg.sizeMultiplier = agg.sizeMultiplier * card.size_multiplier
    end

    -- Lifetime modifiers
    if card.lifetime_modifier and card.lifetime_modifier ~= 0 then
        agg.lifetimeBonus = agg.lifetimeBonus + card.lifetime_modifier
    end

    -- Spread modifiers
    if card.spread_modifier and card.spread_modifier ~= 0 then
        agg.spreadAngleBonus = agg.spreadAngleBonus + card.spread_modifier
    end

    -- Crit modifiers
    if card.critical_hit_chance_modifier and card.critical_hit_chance_modifier ~= 0 then
        agg.critChanceBonus = agg.critChanceBonus + card.critical_hit_chance_modifier
    end

    -- Seeking/Homing
    if card.seek_strength then
        agg.seekStrength = math.max(agg.seekStrength, card.seek_strength)
    end

    if card.homing_strength then
        agg.homingEnabled = true
        agg.homingStrength = math.max(agg.homingStrength, card.homing_strength)
    end

    -- Auto-aim
    if card.auto_aim then
        agg.autoAim = true
    end

    -- Explosion
    if card.make_explosive or card.radius_of_effect then
        if card.radius_of_effect and card.radius_of_effect > 0 then
            agg.explosionRadius = math.max(agg.explosionRadius or 0, card.radius_of_effect)
        end
    end

    -- Ricochet/Bounce
    if card.ricochet_count then
        agg.ricochetCount = agg.ricochetCount + card.ricochet_count
    end

    -- Trigger modifiers
    if card.trigger_on_collision then
        agg.triggerOnCollision = true
    end

    if card.timer_ms then
        agg.triggerOnTimer = card.timer_ms
    end

    if card.trigger_on_death then
        agg.triggerOnDeath = true
    end

    -- Multicast
    if card.multicast_count and card.multicast_count > 1 then
        -- Multiple multicasts stack multiplicatively
        agg.multicastCount = agg.multicastCount * card.multicast_count
    end

    if card.circular_pattern then
        agg.circularPattern = true
    end

    -- On-hit effects
    if card.heal_on_hit then
        agg.healOnHit = agg.healOnHit + card.heal_on_hit
    end

    -- Force crit
    if card.force_crit_next then
        agg.forceCrit = true
    end

    -- Meta modifiers
    if card.add_cards_to_block then
        agg.addCardsToBlock = agg.addCardsToBlock + card.add_cards_to_block
    end

    if card.immunity_duration_ms then
        agg.immunityDuration = math.max(agg.immunityDuration, card.immunity_duration_ms / 1000)
    end

    -- Phase
    if card.phase_in_out then
        agg.phaseInOut = true
    end

    -- Long distance cast
    if card.long_distance_cast then
        agg.longDistanceCast = true
    end

    -- Teleport cast
    if card.teleport_cast_from_enemy then
        agg.teleportCastFromEnemy = true
    end
end

--- Merges player stats into the modifier aggregate
--- @param agg table Modifier aggregate
--- @param playerStats table Player stats object (from combat_system.lua)
function WandModifiers.mergePlayerStats(agg, playerStats)
    if not playerStats or not playerStats.get then return end

    -- Snapshot relevant stats
    -- We snapshot them here so we don't need to keep the full playerStats object around
    -- and to ensure consistency during the cast block execution.
    
    local snapshot = agg.statsSnapshot
    
    -- Global damage modifiers
    snapshot.all_damage_pct = playerStats:get("all_damage_pct")
    snapshot.crit_damage_pct = playerStats:get("crit_damage_pct")
    
    -- Speed modifiers
    snapshot.cast_speed = playerStats:get("cast_speed")
    snapshot.attack_speed = playerStats:get("attack_speed")
    
    -- Resource modifiers
    snapshot.skill_energy_cost_reduction = playerStats:get("skill_energy_cost_reduction")
    
    -- Damage type modifiers
    -- We assume a standard set of damage types, or we could iterate if we had the list
    local damageTypes = {
        "physical", "fire", "cold", "lightning", "poison", 
        "vitality", "aether", "chaos", "holy", "arcane", "void"
    }
    
    for _, dt in ipairs(damageTypes) do
        snapshot[dt .. "_damage_pct"] = playerStats:get(dt .. "_modifier_pct")
    end
    
    -- Apply global modifiers to aggregate fields immediately where appropriate
    
    -- Cast Speed -> Speed Multiplier? 
    -- Usually cast speed affects the rate of fire, not projectile speed.
    -- Projectile speed might be a separate stat, but for now let's leave projectile speed untouched by cast_speed.
    
    -- Crit Chance (if available in stats, usually offensive_ability drives this in GD-like systems)
    -- But if there's a direct crit_chance stat:
    -- agg.critChanceBonus = agg.critChanceBonus + playerStats:get("crit_chance")
    
    -- Mana Cost (Energy Cost)
    if snapshot.skill_energy_cost_reduction > 0 then
        agg.manaCostMultiplier = (agg.manaCostMultiplier or 1.0) * (1.0 - snapshot.skill_energy_cost_reduction / 100)
    end
end

--[[
================================================================================
COLLISION BEHAVIOR RESOLUTION
================================================================================
Determines collision behavior based on modifier priority.
]]--

--- Determines collision behavior from modifiers
--- Priority: explode > bounce > pierce > destroy
--- @param modifiers table Modifier aggregate
--- @return string Collision behavior constant
function WandModifiers.getCollisionBehavior(modifiers)
    local ProjectileSystem = require("assets.scripts.combat.projectile_system")

    -- Priority: explosion > bounce > pierce > destroy
    if modifiers.explosionRadius and modifiers.explosionRadius > 0 then
        return ProjectileSystem.CollisionBehavior.EXPLODE
    elseif modifiers.bounceCount > 0 then
        return ProjectileSystem.CollisionBehavior.BOUNCE
    elseif modifiers.pierceCount > 0 then
        return ProjectileSystem.CollisionBehavior.PIERCE
    else
        return ProjectileSystem.CollisionBehavior.DESTROY
    end
end

--[[
================================================================================
MULTICAST ANGLE CALCULATION
================================================================================
Calculates angles for multicast projectiles based on pattern.
]]--

--- Calculates angles for multicast projectiles
--- @param modifiers table Modifier aggregate
--- @param baseAngle number Base angle (player facing direction)
--- @return table List of angles for each projectile
function WandModifiers.calculateMulticastAngles(modifiers, baseAngle)
    local count = modifiers.multicastCount or 1

    if count == 1 then
        return {baseAngle}
    end

    local angles = {}

    if modifiers.circularPattern then
        -- Circular pattern: evenly distribute around full circle
        local angleStep = (math.pi * 2) / count
        for i = 0, count - 1 do
            angles[#angles + 1] = baseAngle + (angleStep * i)
        end
    else
        -- Spread pattern: distribute within spread angle
        local spread = modifiers.spreadAngle or (math.pi / 6)

        if count == 2 then
            -- Two projectiles: symmetric spread
            angles[#angles + 1] = baseAngle - spread / 2
            angles[#angles + 1] = baseAngle + spread / 2
        else
            -- N projectiles: evenly distribute within spread
            local startAngle = baseAngle - (spread / 2)
            local angleStep = spread / (count - 1)

            for i = 0, count - 1 do
                angles[#angles + 1] = startAngle + (angleStep * i)
            end
        end
    end

    return angles
end

--[[
================================================================================
ON-HIT EFFECT HANDLING
================================================================================
Handles effects that trigger when projectile hits a target.
]]--

--- Creates on-hit callback function from modifiers
--- @param modifiers table Modifier aggregate
--- @param context table Execution context
--- @return function On-hit callback
function WandModifiers.createOnHitCallback(modifiers, context)
    return function(projectile, target, hitData)
        -- Apply healing (life steal)
        if modifiers.healOnHit > 0 and context.playerEntity then
            local healAmount = modifiers.healOnHit
            -- TODO: Call heal function from combat system
            if CombatSystem and CombatSystem.heal then
                CombatSystem.heal(context.playerEntity, healAmount)
            end
        end

        -- Apply status effects
        if modifiers.freezeOnHit and target then
            -- TODO: Apply freeze status via combat system
            if CombatSystem and CombatSystem.applyStatusEffect then
                CombatSystem.applyStatusEffect(target, "frozen", modifiers.freezeDuration)
            end
        end

        -- Chain lightning
        if modifiers.chainLightning then
            -- TODO: Find nearby enemies and spawn chain projectiles
            -- Requires spatial query system
        end

        -- Trigger sub-cast on collision
        if modifiers.triggerOnCollision then
            -- TODO: Execute sub-cast block
            -- This is handled by wand_executor
        end
    end
end

--[[
================================================================================
MODIFIER APPLICATION TO ACTION CARDS
================================================================================
Applies modifiers to action card properties.
]]--

--- Applies modifiers to an action card, returning modified properties
--- @param actionCard table Action card definition
--- @param modifiers table Modifier aggregate
--- @return table Modified action properties
function WandModifiers.applyToAction(actionCard, modifiers)
    local modified = {}

    -- Damage: base + bonus, then multiply
    -- Apply player stats: (Base + Bonus) * (1 + Total% / 100) * Multiplier
    local baseDamage = actionCard.damage or 0
    local damageType = actionCard.damage_type or "physical"
    
    local stats = modifiers.statsSnapshot
    local playerDamagePct = (stats.all_damage_pct or 0) + (stats[damageType .. "_damage_pct"] or 0)
    
    modified.damage = (baseDamage + modifiers.damageBonus) * (1.0 + playerDamagePct / 100) * modifiers.damageMultiplier

    -- Speed: base + card's speed modifier, then apply aggregate multiplier
    local baseSpeed = actionCard.projectile_speed or 300
    local cardSpeedMod = actionCard.speed_modifier or 0
    modified.speed = (baseSpeed + cardSpeedMod * 10) * modifiers.speedMultiplier

    -- Lifetime: base + card's lifetime modifier, then apply aggregate multiplier
    local baseLifetime = actionCard.lifetime or 2000  -- milliseconds
    local cardLifetimeMod = actionCard.lifetime_modifier or 0
    modified.lifetime = (baseLifetime + cardLifetimeMod * 1000) * modifiers.lifetimeMultiplier / 1000  -- convert to seconds

    -- Size: from modifier only (cards don't have base size usually)
    modified.size = 16 * modifiers.sizeMultiplier

    -- Spread angle: base + card's spread + modifier's spread
    local baseSpread = actionCard.spread_angle or 0
    local cardSpreadMod = actionCard.spread_modifier or 0
    modified.spreadAngle = (baseSpread + cardSpreadMod + modifiers.spreadAngleBonus) * (math.pi / 180)  -- convert to radians

    -- Damage type
    modified.damageType = actionCard.damage_type or "physical"

    -- Copy collision behaviors
    modified.pierceCount = modifiers.pierceCount
    modified.bounceCount = modifiers.bounceCount
    modified.explosionRadius = modifiers.explosionRadius

    -- Copy homing
    modified.homingEnabled = modifiers.homingEnabled
    modified.homingStrength = modifiers.homingStrength

    -- Copy multicast
    modified.multicastCount = modifiers.multicastCount
    modified.circularPattern = modifiers.circularPattern

    return modified
end

--[[
================================================================================
UTILITY FUNCTIONS
================================================================================
]]--

--- Checks if modifiers include any on-hit effects
--- @param modifiers table Modifier aggregate
--- @return boolean True if has on-hit effects
function WandModifiers.hasOnHitEffects(modifiers)
    return modifiers.healOnHit > 0
        or modifiers.freezeOnHit
        or modifiers.chainLightning
        or #modifiers.statusEffects > 0
end

--- Checks if modifiers include any trigger effects
--- @param modifiers table Modifier aggregate
--- @return boolean True if has trigger effects
function WandModifiers.hasTriggerEffects(modifiers)
    return modifiers.triggerOnCollision
        or modifiers.triggerOnTimer
        or modifiers.triggerOnDeath
end

--- Gets display name for a modifier for debugging
--- @param card table Modifier card
--- @return string Display name
function WandModifiers.getModifierDisplayName(card)
    return card.test_label or card.card_id or card.id or "unknown_modifier"
end

return WandModifiers
