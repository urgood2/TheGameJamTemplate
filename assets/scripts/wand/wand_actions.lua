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
local component_cache = require("core.component_cache")
local entity_cache = require("core.entity_cache")
local CardRegistry = require("wand.card_registry")
local Particles = require("core.particles")

-- Helper to get raw card definition from card script/instance
-- Card scripts don't have all properties (like custom_render), so we look up the definition
local function getRawCardDefinition(cardInstance)
    if not cardInstance then return nil end
    -- Use card_id first (always a string), then id (might be a function on script objects)
    local cardId = cardInstance.card_id
    if not cardId or type(cardId) ~= "string" then
        cardId = cardInstance.id
        if type(cardId) ~= "string" then
            return nil
        end
    end
    local def = CardRegistry.get_card(cardId)
    if def then
        log_debug("[WandActions] Found raw card definition for:", cardId)
    else
        log_debug("[WandActions] No raw card definition found for:", cardId)
    end
    return def
end

local PLAYER_LAUNCH_RECOIL_STRENGTH = 120
local PLAYER_LAUNCH_SCALE_MULT = 1.08
local PLAYER_LAUNCH_SCALE_CAP = 1.28

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

local function applyPlayerLaunchFeedback(context, angle)
    if not context then return end

    local aimAngle = angle or context.playerAngle or 0
    local recoilFn = rawget(_G, "apply_player_projectile_recoil")
    if recoilFn then
        recoilFn(aimAngle, PLAYER_LAUNCH_RECOIL_STRENGTH)
    end

    local playerEntity = context.playerEntity
    if not (playerEntity and entity_cache and entity_cache.valid(playerEntity)) then
        return
    end

    local t = component_cache.get(playerEntity, Transform)
    if not t then return end

    local currentScale = t.visualS or t.actualS or 1.0
    local bumpedScale = currentScale * PLAYER_LAUNCH_SCALE_MULT
    local targetScale = math.min(bumpedScale, PLAYER_LAUNCH_SCALE_CAP)
    t.visualS = math.max(currentScale, targetScale)
end

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
    do
        -- Re-read the live aim angle (gameplay.lua writes globals.mouseAimAngle)
        local liveAim = nil
        if context and context.getPlayerFacingAngle then
            liveAim = context.getPlayerFacingAngle()
        end
        if liveAim == nil and globals and type(globals.mouseAimAngle) == "number" then
            liveAim = globals.mouseAimAngle
        end
        if liveAim == nil then
            local g = rawget(_G, "mouseAimAngle")
            if type(g) == "number" then
                liveAim = g
            end
        end
        if type(liveAim) == "number" then
            baseAngle = liveAim
        end
    end

    -- Apply spread from action card
    if props.spreadAngle and props.spreadAngle > 0 then
        local spreadOffset = (math.random() - 0.5) * props.spreadAngle
        baseAngle = baseAngle + spreadOffset
    end

    -- Calculate multicast angles
    local angles = WandModifiers.calculateMulticastAngles(modifiers, baseAngle)

    applyPlayerLaunchFeedback(context, baseAngle)

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
    -- Get raw card definition (card scripts don't have all properties like custom_render)
    local cardDef = getRawCardDefinition(actionCard) or actionCard

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
                    angle = math.atan(dy, dx)  -- Lua 5.4: atan2 removed, use atan(y,x)
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

        -- Visual (use cardDef for properties not on card scripts)
        sprite = cardDef.projectileSprite or cardDef.sprite or "b7835.png",
        size = props.size or 16,
        shadow = cardDef.projectile_shadow ~= false,  -- default true unless explicitly false

        -- Custom projectile colors (for lightning, fire, etc.)
        projectileColor = cardDef.projectile_color,
        projectileCoreColor = cardDef.projectile_core_color,

        -- Collision radius (separate from visual size)
        collisionRadius = cardDef.collision_radius,

        -- Custom rendering options (from raw card definition)
        useSprite = cardDef.use_sprite or false,
        spriteId = cardDef.projectile_sprite_id,
        customRender = cardDef.custom_render,

        -- Trail particles (recipe or factory function)
        trailRecipe = cardDef.trail_particles,
        trailRate = cardDef.trail_rate,

        -- On-hit particles config
        onHitParticles = cardDef.on_hit_particles,

        -- Sound effects
        wallHitSfx = cardDef.wall_hit_sfx,  -- Override default wall impact sound

        -- Multipliers
        speedMultiplier = 1.0,  -- already applied to baseSpeed
        damageMultiplier = 1.0, -- already applied to damage
        sizeMultiplier = 1.0,   -- already applied to size

        -- Store modifiers for on-hit processing
        modifiers = modifiers,

        -- Child cast info for collision/death triggers
        subCast = childInfo,

        -- Event hooks
        onSpawn = function(proj, params)
            -- Call card-defined onSpawn if present
            local cardOnSpawn = cardDef.on_spawn or cardDef.onSpawn
            if cardOnSpawn then
                cardOnSpawn(proj, params, actionCard, modifiers, context)
            end
        end,

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

    -- Spawn on-hit particles with directional context
    local hitPosition = getProjectilePosition(projectile)
    if hitData and hitData.onHitParticles and hitPosition then
        local targetTransform = component_cache.get(target, Transform)
        if targetTransform then
            local tx = targetTransform.actualX + (targetTransform.actualW or 0) * 0.5
            local ty = targetTransform.actualY + (targetTransform.actualH or 0) * 0.5

            -- Calculate direction: projectile → target (impact direction)
            local dx = tx - hitPosition.x
            local dy = ty - hitPosition.y
            local impactAngle = math.deg(math.atan(dy, dx))

            local config = hitData.onHitParticles
            -- config can be a table { recipe, count, spread } or a factory function
            local recipe, count, spread
            if type(config) == "function" then
                -- Factory function returns { recipe, count, spread }
                local result = config()
                recipe = result.recipe or result[1]
                count = result.count or result[2] or 6
                spread = result.spread or result[3] or 30
            else
                recipe = config.recipe or config[1]
                count = config.count or config[2] or 6
                spread = config.spread or config[3] or 30
            end

            if recipe and recipe.burst then
                recipe:burst(count)
                    :angle(impactAngle - spread, impactAngle + spread)
                    :at(tx, ty)
            end
        end
    end

    -- Custom upgrade behaviors
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
    -- Chain lightning (from modifier OR from action card with chain_count)
    local hasChainLightning = modifiers.chainLightning
        or (actionCard and actionCard.chain_count and actionCard.chain_count > 0)
    if hasChainLightning then
        -- Spawn impact particles for the initial hit (facing away from projectile)
        if particle and particle.spawnDirectionalLinesCone then
            local projPos = getProjectilePosition(projectile)
            local targetTransform = component_cache.get(target, Transform)
            if projPos and targetTransform then
                local tx = targetTransform.actualX + (targetTransform.actualW or 0) * 0.5
                local ty = targetTransform.actualY + (targetTransform.actualH or 0) * 0.5
                local dx = tx - projPos.x
                local dy = ty - projPos.y
                local len = math.sqrt(dx * dx + dy * dy)
                if len > 0.01 then
                    dx, dy = dx / len, dy / len
                else
                    dx, dy = 1, 0
                end

                local z_orders = require("core.z_orders")
                particle.spawnDirectionalLinesCone(Vec2(tx, ty), 8, 0.2, {
                    direction = Vec2(dx, dy),  -- away from projectile
                    spread = 35,
                    colors = { util.getColor("CYAN"), util.getColor("WHITE"), util.getColor("BLUE") },
                    minSpeed = 120,
                    maxSpeed = 280,
                    minLength = 8,
                    maxLength = 22,
                    minThickness = 1.0,
                    maxThickness = 2.5,
                    shrink = true,
                    space = "world",
                    z = z_orders.particle_vfx
                })
            end
        end

        WandActions.spawnChainLightning(projectile, target, hitData, modifiers, context, actionCard)
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




  --[[
  ================================================================================
  CHAIN LIGHTNING HELPERS
  ================================================================================
  ]] --

  --- Finds enemies within range of a position using physics spatial query
  --- @param position table {x, y}
  --- @param range number Search radius in pixels
  --- @param excludeEntities table|nil Entities to exclude (e.g., primary target)
  --- @param maxCount number|nil Maximum enemies to return
  --- @return table List of {entity, distance, x, y} sorted by distance
  local function findEnemiesInRange(position, range, excludeEntities, maxCount)
      local world = PhysicsManager and PhysicsManager.get_world and PhysicsManager.get_world("world")
      if not (physics and physics.GetObjectsInArea and world) then
          return {}
      end

      local px, py = position.x, position.y
      local excludeSet = {}
      if excludeEntities then
          for _, e in ipairs(excludeEntities) do
              excludeSet[e] = true
          end
      end

      -- AABB query (first pass - fast)
      local candidates = physics.GetObjectsInArea(world, px - range, py - range, px + range, py + range) or {}

      local found = {}
      local rangeSq = range * range

      for _, eid in ipairs(candidates) do
          -- Skip excluded entities and non-enemies
          if not excludeSet[eid] and isEnemyEntity(eid) then
              local t = component_cache.get(eid, Transform)
              if t then
                  local ex = (t.actualX or 0) + (t.actualW or 0) * 0.5
                  local ey = (t.actualY or 0) + (t.actualH or 0) * 0.5
                  local dx, dy = ex - px, ey - py
                  local distSq = dx * dx + dy * dy

                  -- Circular range check (AABB was just first pass)
                  if distSq <= rangeSq then
                      found[#found + 1] = {
                          entity = eid,
                          distance = math.sqrt(distSq),
                          x = ex,
                          y = ey
                      }
                  end
              end
          end
      end

      -- Sort by distance (closest first)
      table.sort(found, function(a, b) return a.distance < b.distance end)

      -- Limit count if specified
      if maxCount and #found > maxCount then
          local limited = {}
          for i = 1, maxCount do
              limited[i] = found[i]
          end
          return limited
      end

      return found
  end


  
  --- Draws a jagged lightning arc between two points
  --- @param fromPos table {x, y}
  --- @param toPos table {x, y}
  --- @param duration number|nil How long the arc is visible (seconds), default 0.15
  local function drawLightningArc(fromPos, toPos, duration)
      local timer = require("core.timer")
      local z_orders = require("core.z_orders")

      duration = duration or 0.15
      local segments = 6
      local jitter = 12

      -- Build jagged path (randomized once, then fades)
      local points = {}
      for i = 0, segments do
          local t = i / segments
          local x = fromPos.x + (toPos.x - fromPos.x) * t
          local y = fromPos.y + (toPos.y - fromPos.y) * t

          -- Add jitter to middle points only
          if i > 0 and i < segments then
              x = x + (math.random() - 0.5) * jitter * 2
              y = y + (math.random() - 0.5) * jitter * 2
          end
          points[#points + 1] = { x = x, y = y }
      end

      -- Draw fading arc over duration
      local elapsed = 0
      local frameTime = 1 / 60
      local timerTag = "lightning_arc_" .. tostring(math.random(100000))

      timer.every_opts({
          delay = frameTime,
          action = function()
              elapsed = elapsed + frameTime
              if elapsed >= duration then
                  timer.cancel(timerTag)
                  return
              end

              -- Draw each segment - full opacity, no alpha fade
              for i = 1, #points - 1 do
                  local x1, y1 = points[i].x, points[i].y
                  local x2, y2 = points[i + 1].x, points[i + 1].y

                  -- Outer glow (cyan) - draw multiple offset lines for thickness
                  for offset = -2, 2 do
                      command_buffer.queueDrawLine(layers.sprites, function(c)
                          c.x1 = x1 + offset * 0.5
                          c.y1 = y1 + offset * 0.5
                          c.x2 = x2 + offset * 0.5
                          c.y2 = y2 + offset * 0.5
                          c.color = util.getColor("CYAN")
                          c.lineWidth = 4
                      end, z_orders.particle_vfx, layer.DrawCommandSpace.World)
                  end

                  -- Main arc (cyan)
                  command_buffer.queueDrawLine(layers.sprites, function(c)
                      c.x1 = x1
                      c.y1 = y1
                      c.x2 = x2
                      c.y2 = y2
                      c.color = util.getColor("CYAN")
                      c.lineWidth = 4
                  end, z_orders.particle_vfx + 1, layer.DrawCommandSpace.World)

                  -- Core (white, bright)
                  command_buffer.queueDrawLine(layers.sprites, function(c)
                      c.x1 = x1
                      c.y1 = y1
                      c.x2 = x2
                      c.y2 = y2
                      c.color = util.getColor("WHITE")
                      c.lineWidth = 4
                  end, z_orders.particle_vfx + 2, layer.DrawCommandSpace.World)
              end
          end,
          tag = timerTag,
          times = math.ceil(duration / frameTime)
      })
  end
  
  
  

--- Spawns chain lightning arcs to nearby enemies (instant damage, no projectiles)
--- @param sourceProjectile number Source projectile entity ID
--- @param hitTarget number Entity that was hit
--- @param hitData table Hit data from projectile
--- @param modifiers table Modifier aggregate
--- @param context table Execution context
--- @param actionCard table|nil The action card (for chain_count, chain_range, etc.)
function WandActions.spawnChainLightning(sourceProjectile, hitTarget, hitData, modifiers, context, actionCard)
    -- Get source position from the HIT ENEMY (not the projectile!)
    -- The projectile already hit this enemy - chains start FROM this enemy
    local sourcePos = nil
    local targetTransform = component_cache.get(hitTarget, Transform)
    if targetTransform then
        sourcePos = {
            x = targetTransform.actualX + (targetTransform.actualW or 0) * 0.5,
            y = targetTransform.actualY + (targetTransform.actualH or 0) * 0.5
        }
    else
        log_debug("WandActions.spawnChainLightning: No valid hit target position")
        return
    end

    -- Get chain parameters from card, PLUS joker bonuses from modifiers
    local baseChainCount = (actionCard and actionCard.chain_count) or 3
    local jokerChainBonus = modifiers.chainLightningTargets or 0  -- From jokers via extra_chain
    local chainCount = baseChainCount + jokerChainBonus

    local baseChainRange = (actionCard and actionCard.chain_range) or 150
    local jokerRangeBonus = modifiers.chainLightningRange or 0    -- From jokers via chain_range_mod
    local chainRange = baseChainRange + jokerRangeBonus

    local chainDamageMult = (actionCard and actionCard.chain_damage_mult) or modifiers.chainLightningDamageMult or 0.5

    -- MOD_BIG_SLOW: increase range based on size multiplier
    chainRange = chainRange * (modifiers.sizeMultiplier or 1.0)

    -- Calculate chain damage (modifiers already applied to hitData.damage)
    local baseDamage = (hitData and hitData.damage) or 10
    local chainDamage = baseDamage * chainDamageMult

    -- MOD_FORCE_CRIT: apply crit multiplier to chain damage
    if modifiers.forceCrit then
        chainDamage = chainDamage * 2.0
    end

    -- Get combat context and owner for damage application
    local ctx = rawget(_G, "combat_context")
    local owner = context and context.playerEntity
    local ActionAPI = require("combat.action_api")

    -- Get owner's combat actor for damage source
    local ownerActor = nil
    if owner and entity_cache.valid(owner) then
        local ownerScript = getScriptTableFromEntityID(owner)
        ownerActor = ownerScript and ownerScript.combatTable
    end

    -- Initial chain start sfx
    local startSfx = (actionCard and actionCard.chain_start_sfx) or "electric_layer"
    playSoundEffect("effects", startSfx)

    -- Stagger timing config
    local baseDelay = 0.4  -- seconds between first chains
    local hitSfx = (actionCard and actionCard.chain_hit_sfx) or "chain_lightning_individual_hit"

    -- TRUE CASCADING with stagger: recursive timer-based chaining
    local hitEntities = { hitTarget }
    local totalChainsDone = 0
    local timer = require("core.timer")
    local z_orders = require("core.z_orders")

    -- Recursive function to process each chain with stagger
    local function processNextChain(currentPos, chainsRemaining)
        if chainsRemaining <= 0 then
            log_debug("WandActions.spawnChainLightning: Chained to", totalChainsDone, "targets")
            return
        end

        -- Find nearest enemy from current position (excluding already-hit enemies)
        local nearbyEnemies = findEnemiesInRange(currentPos, chainRange, hitEntities, 1)

        if #nearbyEnemies == 0 then
            log_debug("WandActions.spawnChainLightning: No more chain targets found after", totalChainsDone, "chains")
            return
        end

        local targetInfo = nearbyEnemies[1]
        local targetEntity = targetInfo.entity
        local targetPos = { x = targetInfo.x, y = targetInfo.y }

        -- Draw lightning arc visual (from current position to target)
        drawLightningArc(currentPos, targetPos, 0.15)

        -- Apply damage via combat system
        if ctx and ActionAPI then
            local targetScript = getScriptTableFromEntityID(targetEntity)
            local targetActor = targetScript and targetScript.combatTable

            if targetActor then
                -- Use lightning damage type
                ActionAPI.damage(ctx, ownerActor, targetActor, chainDamage, "lightning")
                log_debug("WandActions.spawnChainLightning: Hit", targetEntity, "for", chainDamage, "lightning damage")
                
                hitFX(targetEntity, 5, 0.3)
                
                -- Hit sfx (plays each chain)
                playSoundEffect("effects", hitSfx)

                -- Spawn line particles flying away from where lightning came from
                if particle and particle.spawnDirectionalLinesCone then
                    local dx = targetPos.x - currentPos.x
                    local dy = targetPos.y - currentPos.y
                    local len = math.sqrt(dx * dx + dy * dy)
                    if len > 0.01 then
                        dx, dy = dx / len, dy / len
                    else
                        dx, dy = 1, 0  -- fallback direction
                    end

                    particle.spawnDirectionalLinesCone(Vec2(targetPos.x, targetPos.y), 8, 0.2, {
                        direction = Vec2(dx, dy),  -- away from source
                        spread = 35,
                        colors = { util.getColor("CYAN"), util.getColor("WHITE"), util.getColor("BLUE") },
                        minSpeed = 120,
                        maxSpeed = 280,
                        minLength = 8,
                        maxLength = 22,
                        minThickness = 1.0,
                        maxThickness = 2.5,
                        shrink = true,
                        space = "world",
                        z = z_orders.particle_vfx
                    })
                end
            end
        end

        -- MOD_HEAL_ON_HIT: heal for each chain hit
        if modifiers.healOnHit and modifiers.healOnHit > 0 and owner then
            if WandActions.applyHealing then
                WandActions.applyHealing(owner, modifiers.healOnHit)
            end
        end

        -- Mark this enemy as hit
        hitEntities[#hitEntities + 1] = targetEntity
        totalChainsDone = totalChainsDone + 1

        -- Calculate delay for next chain (cubic falloff: faster as chain progresses)
        -- remaining/total gives 1.0 → 0.0, cubed makes it decay faster at the end
        local remaining = chainsRemaining - 1
        local progress = remaining / chainCount  -- 1.0 at start, approaches 0 at end
        local delay = baseDelay * (progress * progress * progress)  -- cubic falloff

        -- Schedule next chain
        if remaining > 0 then
            timer.after(delay, function()
                processNextChain(targetPos, remaining)
            end)
        else
            log_debug("WandActions.spawnChainLightning: Chained to", totalChainsDone, "targets")
        end
    end

    -- Start the chain from the initially hit enemy
    processNextChain(sourcePos, chainCount)
end


return WandActions
