--[[
================================================================================
WAND ACTION EXECUTION SYSTEM
================================================================================
Handles execution of action cards - spawning projectiles, applying effects,
creating hazards, and other spell actions.

Responsibilities:
- Execute action cards with modifier support
- Spawn projectiles via ProjectileSystem (Task 1)
- Apply effects via CombatSystem
- Handle special actions (teleport, summon, etc.)
- Process on-hit callbacks

Integration:
- Uses ProjectileSystem from combat/projectile_system.lua
- Uses WandModifiers from wand/wand_modifiers.lua
- Uses CombatSystem from combat/combat_system.lua
================================================================================
]] --

local WandActions = {}

-- Dependencies
local ProjectileSystem = require("combat.projectile_system")
local WandModifiers = require("wand.wand_modifiers")
local CardUpgrade = require("wand.card_upgrade_system")
local BehaviorRegistry = require("wand.card_behavior_registry")

--[[
================================================================================
UPGRADE & STAT HELPERS
================================================================================
]] --

local function collectUpgradeBehaviors(card)
    if not card or not CardUpgrade.getCustomBehaviors then
        return nil
    end

    local behaviors = CardUpgrade.getCustomBehaviors(card)
    if not behaviors then return nil end

    local active = {}
    for behaviorId, params in pairs(behaviors) do
        if params and params.enabled ~= false then
            active[behaviorId] = params
        end
    end

    if next(active) then
        return active
    end

    return nil
end

local function applyUpgradeBehaviorsToProps(props, behaviors, modifiers)
    if not behaviors then return end

    for behaviorId, params in pairs(behaviors) do
        if behaviorId == "on_hit_explosion" then
            props.explosionRadius = params.radius or props.explosionRadius or modifiers.explosionRadius
            props.explosionDamageMult = params.damage_mult or props.explosionDamageMult or
                modifiers.explosionDamageMult or 1.0
            props.collisionBehaviorOverride = ProjectileSystem.CollisionBehavior.EXPLODE
        elseif behaviorId == "chain_explosion" then
            props.chainExplosion = params
        elseif behaviorId == "gravity_well" then
            props.gravityWell = params
        elseif behaviorId == "pierce_spawn_projectile" then
            props.pierceSpawnProjectile = params
        elseif params and params.behavior_id then
            -- Preserve any behavior_registry-backed behaviors even if we don't inspect the ID here
            props.behaviorDriven = true
        end
    end
end

local function getProjectilePosition(projectile)
    if not (component_cache and Transform and projectile) then
        return nil
    end

    local transform = component_cache.get(projectile, Transform)
    if transform then
        return {
            x = transform.actualX + (transform.actualW or 0) * 0.5,
            y = transform.actualY + (transform.actualH or 0) * 0.5
        }
    end

    return nil
end

local function triggerExplosionFromBehavior(projectile, params, fallbackBehavior)
    local script = ProjectileSystem.getProjectileScript and ProjectileSystem.getProjectileScript(projectile)
    if not (script and script.projectileData) then return end

    local behavior = fallbackBehavior or {}
    behavior.explosionRadius = params and (params.radius or params.explosion_radius) or behavior.explosionRadius
    behavior.explosionDamageMult = params and (params.damage_mult or params.explosionDamageMult) or
        behavior.explosionDamageMult or 1.0

    ProjectileSystem.handleExplosion(projectile, script.projectileData, behavior)
end

local function runUpgradeBehaviors(event, behaviors, payload)
    if not behaviors or not next(behaviors) then return end

    for behaviorId, params in pairs(behaviors) do
        if params == false or (params and params.enabled == false) then
            goto continue
        end

        if params and params.behavior_id and BehaviorRegistry.has(params.behavior_id) then
            BehaviorRegistry.execute(params.behavior_id, {
                event = event,
                params = params,
                card = payload.card,
                projectile = payload.projectile,
                target = payload.target,
                context = payload.context,
                position = payload.position,
                damage = payload.damage,
                collision_behavior = payload.collisionBehavior
            })
            goto continue
        end

        if behaviorId == "on_hit_explosion" then
            -- Only fire here if the projectile wasn't already configured to explode
            if payload.collisionBehavior ~= ProjectileSystem.CollisionBehavior.EXPLODE then
                triggerExplosionFromBehavior(payload.projectile, params)
            end
        elseif behaviorId == "chain_explosion" then
            triggerExplosionFromBehavior(payload.projectile, params)
        end

        ::continue::
    end
end

--[[
================================================================================
MAIN ACTION EXECUTION
================================================================================
]] --

--- Executes an action card with the given modifiers
--- @param actionCard table Action card definition
--- @param modifiers table Modifier aggregate from WandModifiers
--- @param context table Execution context
--- @param childInfo table|nil Sub-cast metadata for this action
--- @return table|nil Result of action execution (e.g., spawned entities)
function WandActions.execute(actionCard, modifiers, context, childInfo)
    if not actionCard or actionCard.type ~= "action" then
        log_debug("WandActions.execute: invalid action card")
        return nil
    end

    -- Determine action type and execute
    local actionType = WandActions.getActionType(actionCard)

    if actionType == "projectile" then
        return WandActions.executeProjectileAction(actionCard, modifiers, context, childInfo)
    elseif actionType == "effect" then
        return WandActions.executeEffectAction(actionCard, modifiers, context)
    elseif actionType == "hazard" then
        return WandActions.executeHazardAction(actionCard, modifiers, context)
    elseif actionType == "summon" then
        return WandActions.executeSummonAction(actionCard, modifiers, context)
    elseif actionType == "teleport" then
        return WandActions.executeTeleportAction(actionCard, modifiers, context)
    elseif actionType == "meta" then
        return WandActions.executeMetaAction(actionCard, modifiers, context)
    else
        log_debug("WandActions.execute: unknown action type", actionType)
        return nil
    end
end

--- Determines the action type from card properties
--- @param card table Action card
--- @return string Action type
function WandActions.getActionType(card)
    -- Check for explicit type markers
    if card.summon_entity then return "summon" end
    if card.teleport_to_impact or card.teleport_on_hit then return "teleport" end
    if card.heal_amount or card.shield_strength then return "effect" end
    if card.leave_hazard then return "hazard" end
    if card.add_mana_amount then return "meta" end

    -- Default to projectile if has damage or projectile speed
    if card.damage or card.projectile_speed then return "projectile" end

    -- Fallback
    return "projectile"
end

--[[
================================================================================
PROJECTILE ACTION EXECUTION
================================================================================
Spawns projectiles using the ProjectileSystem from Task 1.
]] --

--- Executes a projectile action card
--- @param actionCard table Action card definition
--- @param modifiers table Modifier aggregate
--- @param context table Execution context
--- @param childInfo table|nil Sub-cast metadata for this action
--- @return table List of spawned projectile entity IDs
function WandActions.executeProjectileAction(actionCard, modifiers, context, childInfo)
    -- Apply modifiers to action properties
    local props = WandModifiers.applyToAction(actionCard, modifiers)

    -- Apply upgrade behaviors (custom hooks, explosions, etc.)
    local upgradeBehaviors = collectUpgradeBehaviors(actionCard)
    applyUpgradeBehaviorsToProps(props, upgradeBehaviors, modifiers)

    -- Get spawn position and base angle
    local spawnPos = context.playerPosition or { x = 0, y = 0 }
    local baseAngle = context.playerAngle or 0

    -- Apply spread from action card
    if props.spreadAngle and props.spreadAngle > 0 then
        local spreadOffset = (math.random() - 0.5) * props.spreadAngle
        baseAngle = baseAngle + spreadOffset
    end

    -- Calculate multicast angles
    local angles = WandModifiers.calculateMulticastAngles(modifiers, baseAngle)

    local spawnedProjectiles = {}

    -- Spawn projectiles for each angle
    for _, angle in ipairs(angles) do
        local projectileId = WandActions.spawnSingleProjectile(
            actionCard,
            props,
            modifiers,
            context,
            spawnPos,
            angle,
            childInfo,
            upgradeBehaviors
        )

        if projectileId and projectileId ~= entt_null then
            table.insert(spawnedProjectiles, projectileId)
        end
    end

    return spawnedProjectiles
end

--- Spawns a single projectile
--- @param actionCard table Action card definition
--- @param props table Modified properties from WandModifiers.applyToAction
--- @param modifiers table Modifier aggregate
--- @param context table Execution context
--- @param position table {x, y} spawn position
--- @param angle number Spawn angle in radians
--- @param childInfo table|nil Sub-cast metadata for this action
--- @param upgradeBehaviors table|nil Custom behaviors from CardUpgrade
--- @return number Entity ID of spawned projectile
function WandActions.spawnSingleProjectile(actionCard, props, modifiers, context, position, angle, childInfo,
    upgradeBehaviors)
    -- Determine movement type
    local movementType = ProjectileSystem.MovementType.STRAIGHT

    if props.homingEnabled or modifiers.autoAim then
        movementType = ProjectileSystem.MovementType.HOMING
    elseif actionCard.gravity_affected then
        movementType = ProjectileSystem.MovementType.ARC
    end

    -- Determine collision behavior (upgrade behaviors can override to explode)
    local collisionBehavior = props.collisionBehaviorOverride or WandModifiers.getCollisionBehavior(modifiers)

    -- Find homing target if needed
    local homingTarget = nil
    if movementType == ProjectileSystem.MovementType.HOMING then
        homingTarget = context.findNearestEnemy and context.findNearestEnemy(position, 500)
        if homingTarget then
            -- Adjust initial angle towards target if auto-aim
            if modifiers.autoAim then
                local targetTransform = component_cache and component_cache.get(homingTarget, Transform)
                if targetTransform then
                    local dx = targetTransform.actualX - position.x
                    local dy = targetTransform.actualY - position.y
                    angle = math.atan2(dy, dx)
                end
            end
        else
            -- No target found, fall back to straight
            movementType = ProjectileSystem.MovementType.STRAIGHT
        end
    end

    -- Build spawn parameters
    local spawnCenter = { x = position.x, y = position.y }

    local spawnParams = {
        -- Position and direction
        position = spawnCenter,
        positionIsCenter = true,
        angle = angle,

        -- Movement
        movementType = movementType,
        baseSpeed = props.speed,

        -- Homing parameters
        homingTarget = homingTarget,
        homingStrength = props.homingStrength or 8.0,
        homingMaxSpeed = (props.speed or 400) * 1.5,

        -- Gravity (for arc movement)
        gravityScale = actionCard.gravity_affected and 1.5 or 0,

        -- Damage
        damage = props.damage,
        damageType = props.damageType,
        owner = context.playerEntity or entt_null,
        faction = "player",

        -- Collision behavior
        collisionBehavior = collisionBehavior,
        maxPierceCount = props.pierceCount or 0,
        maxBounces = props.bounceCount or 0,
        bounceDampening = modifiers.bounceDampening or 0.8,
        explosionRadius = props.explosionRadius,
        explosionDamageMult = props.explosionDamageMult or modifiers.explosionDamageMult or 1.0,

        -- Lifetime
        lifetime = props.lifetime,

        -- Visual
        sprite = actionCard.projectileSprite or actionCard.sprite or "b488.png",
        size = props.size or 16,
        shadow = true,

        -- Multipliers
        speedMultiplier = 1.0,  -- already applied to baseSpeed
        damageMultiplier = 1.0, -- already applied to damage
        sizeMultiplier = 1.0,   -- already applied to size

        -- Store modifiers for on-hit processing
        modifiers = modifiers,

        -- Child cast info for collision/death triggers
        subCast = childInfo,

        -- Event hooks
        onHit = function(proj, target, data)
            WandActions.handleProjectileHit(proj, target, data, modifiers, context, upgradeBehaviors, actionCard,
                collisionBehavior)
        end,

        onDestroy = function(proj, data)
            WandActions.handleProjectileDestroy(proj, data, modifiers, context, upgradeBehaviors, actionCard,
                collisionBehavior)
        end,
    }

    -- Spawn the projectile
    local projectileId = ProjectileSystem.spawn(spawnParams)

    log_debug("WandActions: Spawned projectile", projectileId, "at angle", angle * 180 / math.pi, "degrees")

    return projectileId
end

--[[
================================================================================
PROJECTILE EVENT HANDLERS
================================================================================
]] --

--- Handles projectile hit event
--- @param projectile number Projectile entity ID
--- @param target number Target entity ID
--- @param hitData table Hit data from projectile system
--- @param modifiers table Modifier aggregate
--- @param context table Execution context
--- @param upgradeBehaviors table|nil Custom behaviors attached to the card
--- @param actionCard table|nil Action card reference for context
--- @param collisionBehavior string|nil Collision behavior applied to this projectile
function WandActions.handleProjectileHit(projectile, target, hitData, modifiers, context, upgradeBehaviors, actionCard,
    collisionBehavior)
    -- Apply on-hit effects from modifiers
    if not target or target == entt_null then return end

    -- Collision-triggered sub-cast
    if hitData and hitData.subCast and hitData.subCast.collision then
        local WandExecutor = require("wand.wand_executor")
        WandExecutor.enqueueSubCast({
            block = hitData.subCast.block,
            inheritedModifiers = hitData.subCast.inheritedModifiers or modifiers,
            context = hitData.subCast.context or context,
            source = {
                trigger = "collision",
                blockIndex = hitData.subCast.parent and hitData.subCast.parent.blockIndex,
                cardIndex = hitData.subCast.parent and hitData.subCast.parent.cardIndex,
                wandId = hitData.subCast.parent and hitData.subCast.parent.wandId
            },
            traceId = hitData.subCast.traceId
        })
    end

    -- Custom upgrade behaviors
    local hitPosition = getProjectilePosition(projectile)
    runUpgradeBehaviors("on_hit", upgradeBehaviors, {
        card = actionCard,
        projectile = projectile,
        target = target,
        context = context,
        position = hitPosition,
        damage = hitData and hitData.damage,
        collisionBehavior = collisionBehavior
    })

    -- Healing (life steal)
    if modifiers.healOnHit > 0 and context.playerEntity then
        local healAmount = modifiers.healOnHit
        WandActions.applyHealing(context.playerEntity, healAmount)
    end

    -- Freeze
    if modifiers.freezeOnHit then
        WandActions.applyStatusEffect(target, "frozen", modifiers.freezeDuration or 2.0)
    end

    -- Slow
    if modifiers.slowOnHit and modifiers.slowOnHit > 0 then
        WandActions.applyStatusEffect(target, "slow", modifiers.slowDuration or 2.0, {
            slowPercent = modifiers.slowOnHit
        })
    end

    -- Knockback
    if modifiers.knockback and modifiers.knockback > 0 then
        WandActions.applyKnockback(projectile, target, modifiers.knockback)
    end

    -- Chain lightning (spawn additional projectiles to nearby enemies)
    if modifiers.chainLightning then
        WandActions.spawnChainLightning(projectile, target, hitData, modifiers, context)
    end

    log_debug("WandActions: Projectile hit", target)
end

--- Handles projectile destroy event
--- @param projectile number Projectile entity ID
--- @param destroyData table Destroy data from projectile system
--- @param modifiers table Modifier aggregate
--- @param context table Execution context
--- @param upgradeBehaviors table|nil Custom behaviors attached to the card
--- @param actionCard table|nil Action card reference for context
--- @param collisionBehavior string|nil Collision behavior applied to this projectile
function WandActions.handleProjectileDestroy(projectile, destroyData, modifiers, context, upgradeBehaviors, actionCard,
    collisionBehavior)
    if destroyData and destroyData.subCast and destroyData.subCast.death then
        local WandExecutor = require("wand.wand_executor")
        WandExecutor.enqueueSubCast({
            block = destroyData.subCast.block,
            inheritedModifiers = destroyData.subCast.inheritedModifiers or modifiers,
            context = destroyData.subCast.context or context,
            source = {
                trigger = "death",
                blockIndex = destroyData.subCast.parent and destroyData.subCast.parent.blockIndex,
                cardIndex = destroyData.subCast.parent and destroyData.subCast.parent.cardIndex,
                wandId = destroyData.subCast.parent and destroyData.subCast.parent.wandId
            },
            traceId = destroyData.subCast.traceId
        })
    end

    local destroyPosition = getProjectilePosition(projectile)
    runUpgradeBehaviors("on_destroy", upgradeBehaviors, {
        card = actionCard,
        projectile = projectile,
        target = destroyData and destroyData.target,
        context = context,
        position = destroyPosition,
        collisionBehavior = collisionBehavior
    })

    -- Check if projectile should trigger on death
    if modifiers.triggerOnDeath then
        -- TODO: Execute sub-cast block
        -- This would be handled by wand_executor
        log_debug("WandActions: Projectile destroyed, trigger on death")
    end
end

--[[
================================================================================
EFFECT ACTIONS
================================================================================
Actions that apply effects to entities (heal, buff, debuff, etc.)
]] --

--- Executes an effect action card
--- @param actionCard table Action card definition
--- @param modifiers table Modifier aggregate
--- @param context table Execution context
--- @return boolean Success
function WandActions.executeEffectAction(actionCard, modifiers, context)
    -- Healing
    if actionCard.heal_amount then
        local healAmount = actionCard.heal_amount
        local radius = actionCard.radius_of_effect or 0

        if radius > 0 then
            -- AOE heal
            WandActions.applyAOEHealing(context.playerPosition, radius, healAmount)
        else
            -- Self heal
            WandActions.applyHealing(context.playerEntity, healAmount)
        end

        return true
    end

    -- Shield
    if actionCard.shield_strength then
        local shieldAmount = actionCard.shield_strength
        local duration = actionCard.shield_duration or 5.0

        WandActions.applyShield(context.playerEntity, shieldAmount, duration)
        return true
    end

    return false
end

--[[
================================================================================
HAZARD ACTIONS
================================================================================
Actions that create persistent hazards (spike traps, AoE zones, etc.)
]] --

--- Executes a hazard action card
--- @param actionCard table Action card definition
--- @param modifiers table Modifier aggregate
--- @param context table Execution context
--- @return number|nil Entity ID of created hazard
function WandActions.executeHazardAction(actionCard, modifiers, context)
    -- TODO: Create hazard entity
    -- This requires a hazard system
    log_debug("WandActions: Creating hazard at", context.playerPosition.x, context.playerPosition.y)

    return nil
end

--[[
================================================================================
SUMMON ACTIONS
================================================================================
Actions that summon entities (minions, allies, etc.)
]] --

--- Executes a summon action card
--- @param actionCard table Action card definition
--- @param modifiers table Modifier aggregate
--- @param context table Execution context
--- @return number|nil Entity ID of summoned entity
function WandActions.executeSummonAction(actionCard, modifiers, context)
    if not actionCard.summon_entity then return nil end

    -- TODO: Summon entity
    -- This requires entity spawning system
    log_debug("WandActions: Summoning", actionCard.summon_entity)

    return nil
end

--[[
================================================================================
TELEPORT ACTIONS
================================================================================
Actions that teleport the player
]] --

--- Executes a teleport action card
--- @param actionCard table Action card definition
--- @param modifiers table Modifier aggregate
--- @param context table Execution context
--- @return boolean Success
function WandActions.executeTeleportAction(actionCard, modifiers, context)
    -- TODO: Teleport player
    -- This requires physics/transform manipulation
    log_debug("WandActions: Teleporting player")

    return false
end

--[[
================================================================================
META ACTIONS
================================================================================
Actions that affect wand state or player resources
]] --

--- Executes a meta action card
--- @param actionCard table Action card definition
--- @param modifiers table Modifier aggregate
--- @param context table Execution context
--- @return boolean Success
function WandActions.executeMetaAction(actionCard, modifiers, context)
    -- Add mana
    if actionCard.add_mana_amount then
        -- TODO: Add mana to wand
        log_debug("WandActions: Adding mana", actionCard.add_mana_amount)
        return true
    end

    return false
end

--[[
================================================================================
HELPER FUNCTIONS - COMBAT INTEGRATION
================================================================================
These functions integrate with the combat system.
]] --

--- Applies healing to an entity
--- @param entity number Entity ID
--- @param amount number Heal amount
function WandActions.applyHealing(entity, amount)
    -- Integration with combat system
    if _G.CombatSystem and _G.CombatSystem.heal then
        _G.CombatSystem.heal(entity, amount)
    else
        -- Fallback: direct health manipulation
        if component_cache then
            local gameObj = component_cache.get(entity, GameObject)
            if gameObj and gameObj.health then
                gameObj.health = math.min(gameObj.health + amount, gameObj.maxHealth or 100)
            end
        end
    end

    log_debug("WandActions: Healed entity", entity, "for", amount)
end

--- Applies AOE healing
--- @param position table {x, y}
--- @param radius number Radius in pixels
--- @param amount number Heal amount
function WandActions.applyAOEHealing(position, radius, amount)
    -- TODO: Query entities in radius and heal them
    log_debug("WandActions: AOE heal at", position.x, position.y, "radius", radius)
end

--- Applies a status effect to an entity
--- @param entity number Entity ID
--- @param statusType string Status type (frozen, slow, etc.)
--- @param duration number Duration in seconds
--- @param params table|nil Additional parameters
function WandActions.applyStatusEffect(entity, statusType, duration, params)
    -- Integration with combat system
    if _G.CombatSystem and _G.CombatSystem.applyStatusEffect then
        _G.CombatSystem.applyStatusEffect(entity, statusType, duration, params)
    else
        log_debug("WandActions: Applied status", statusType, "to", entity, "for", duration, "seconds")
    end
end

--- Applies knockback to an entity
--- @param projectile number Projectile entity ID
--- @param target number Target entity ID
--- @param force number Knockback force
function WandActions.applyKnockback(projectile, target, force)
    -- TODO: Apply impulse to target physics body
    log_debug("WandActions: Knockback", target, "with force", force)
end

--- Applies a shield to an entity
--- @param entity number Entity ID
--- @param amount number Shield amount
--- @param duration number Duration in seconds
function WandActions.applyShield(entity, amount, duration)
    -- TODO: Apply shield via combat system
    log_debug("WandActions: Shield", entity, "for", amount, "duration", duration)
end

--- Spawns chain lightning projectiles
--- @param sourceProjectile number Source projectile entity ID
--- @param hitTarget number Entity that was hit
--- @param hitData table Hit data
--- @param modifiers table Modifier aggregate
--- @param context table Execution context
function WandActions.spawnChainLightning(sourceProjectile, hitTarget, hitData, modifiers, context)
    -- TODO: Find nearby enemies and spawn homing projectiles
    -- Requires spatial query system

    log_debug("WandActions: Chain lightning from", hitTarget)
end

return WandActions
