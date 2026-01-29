# Wand System Integration Guide for Projectile System

## Quick Start Integration

This guide shows how to integrate the Projectile System with your Wand/Card Execution Engine (Task 2).

## Step 1: Import the System

```lua
local ProjectileSystem = require("combat.projectile_system")

-- Initialize once during game setup
function initGame()
    ProjectileSystem.init()
    -- ... other init code
end

-- Update every frame
function updateGame(dt)
    ProjectileSystem.update(dt)
    -- ... other update code
end
```

## Step 2: Map Action Cards to Projectile Spawners

### Example Card Definition

```lua
local action_card_defs = {
    {
        id = "fire_basic_bolt",
        displayName = "Fire Bolt",
        description = "Shoots a bolt of fire",
        baseDamage = 25,
        damageType = "fire",
        projectileSprite = "fireball_anim",
        projectileSpeed = 400,

        -- Execution function
        execute = function(ctx, cardData, modifierCards)
            return executeFireBolt(ctx, cardData, modifierCards)
        end
    },
    {
        id = "ice_shard",
        displayName = "Ice Shard",
        description = "Launches a piercing ice projectile",
        baseDamage = 18,
        damageType = "cold",
        projectileSprite = "ice_shard_anim",
        projectileSpeed = 500,
        basePierceCount = 2,

        execute = function(ctx, cardData, modifierCards)
            return executeIceShard(ctx, cardData, modifierCards)
        end
    },
    {
        id = "magic_missile",
        displayName = "Magic Missile",
        description = "Fires a homing projectile",
        baseDamage = 30,
        damageType = "arcane",
        projectileSprite = "magic_missile_anim",
        projectileSpeed = 350,
        isHoming = true,

        execute = function(ctx, cardData, modifierCards)
            return executeMagicMissile(ctx, cardData, modifierCards)
        end
    }
}
```

## Step 3: Implement Execution Functions

### Basic Projectile Action

```lua
function executeFireBolt(ctx, cardData, modifierCards)
    -- Start with default modifiers
    local mods = {
        speedMultiplier = 1.0,
        damageMultiplier = 1.0,
        sizeMultiplier = 1.0,
        pierceCount = 0,
        bounceCount = 0,
        explosionRadius = nil,
        homingEnabled = false
    }

    -- Apply modifier cards from stack
    for _, modCard in ipairs(modifierCards) do
        applyModifierToProjectile(modCard, mods)
    end

    -- Get player position and facing direction
    local playerPos = getPlayerPosition()
    local playerAngle = getPlayerFacingAngle()

    -- Spawn projectile with card data + modifiers
    local projectile = ProjectileSystem.spawn({
        -- Position & direction
        position = {x = playerPos.x, y = playerPos.y},
        angle = playerAngle,

        -- Movement
        movementType = ProjectileSystem.MovementType.STRAIGHT,
        baseSpeed = cardData.projectileSpeed,

        -- Damage
        damage = cardData.baseDamage,
        damageType = cardData.damageType,
        owner = ctx.playerEntity,
        faction = "player",

        -- Collision behavior (modified by cards)
        collisionBehavior = getCollisionBehavior(mods),
        maxPierceCount = mods.pierceCount,
        maxBounces = mods.bounceCount,
        explosionRadius = mods.explosionRadius,

        -- Lifetime
        lifetime = 5.0,

        -- Visual
        sprite = cardData.projectileSprite,
        size = 16,
        shadow = true,

        -- Apply modifiers
        speedMultiplier = mods.speedMultiplier,
        damageMultiplier = mods.damageMultiplier,
        sizeMultiplier = mods.sizeMultiplier,

        -- Store modifier data for on-hit effects
        modifiers = mods,

        -- Event hooks
        onHit = function(proj, target, data)
            handleProjectileHit(ctx, proj, target, data, modifierCards)
        end
    })

    return projectile
end
```

### Homing Projectile Action

```lua
function executeMagicMissile(ctx, cardData, modifierCards)
    local mods = aggregateModifiers(modifierCards)
    local playerPos = getPlayerPosition()

    -- Find nearest enemy for homing
    local target = findNearestEnemy(playerPos, 500)

    -- Calculate initial direction towards target (or forward if no target)
    local initialAngle = target
        and calculateAngleToTarget(playerPos, getEntityPosition(target))
        or getPlayerFacingAngle()

    return ProjectileSystem.spawn({
        position = {x = playerPos.x, y = playerPos.y},
        angle = initialAngle,

        -- Homing movement
        movementType = ProjectileSystem.MovementType.HOMING,
        homingTarget = target,
        baseSpeed = cardData.projectileSpeed,
        homingStrength = 8.0,
        homingMaxSpeed = cardData.projectileSpeed * 1.5,

        damage = cardData.baseDamage,
        damageType = cardData.damageType,
        owner = ctx.playerEntity,

        collisionBehavior = getCollisionBehavior(mods),

        lifetime = 6.0,
        sprite = cardData.projectileSprite,

        speedMultiplier = mods.speedMultiplier,
        damageMultiplier = mods.damageMultiplier,

        onHit = function(proj, target, data)
            handleProjectileHit(ctx, proj, target, data, modifierCards)
        end
    })
end
```

## Step 4: Implement Modifier Application

```lua
function applyModifierToProjectile(modCard, mods)
    if modCard.id == "double_damage" then
        mods.damageMultiplier = mods.damageMultiplier * 2.0

    elseif modCard.id == "projectile_pierces_twice" then
        mods.pierceCount = mods.pierceCount + 2

    elseif modCard.id == "triple_shot" then
        mods.multishot = 3
        mods.multishot_spread = math.pi / 6  -- 30 degree spread

    elseif modCard.id == "heavy_impact" then
        mods.knockback = 150
        mods.slowOnHit = 0.5  -- 50% slow for 2 seconds
        mods.slowDuration = 2.0

    elseif modCard.id == "explosive_rounds" then
        mods.explosionRadius = 80
        mods.explosionDamageMult = 0.6  -- 60% damage in AoE

    elseif modCard.id == "bouncing_shots" then
        mods.bounceCount = 3
        mods.bounceDampening = 0.85

    elseif modCard.id == "homing" then
        mods.homingEnabled = true
        mods.homingStrength = 10.0

    elseif modCard.id == "faster_projectiles" then
        mods.speedMultiplier = mods.speedMultiplier * 1.5

    elseif modCard.id == "larger_projectiles" then
        mods.sizeMultiplier = mods.sizeMultiplier * 1.3
    end
end

function getCollisionBehavior(mods)
    -- Priority: explosion > bounce > pierce > destroy
    if mods.explosionRadius then
        return ProjectileSystem.CollisionBehavior.EXPLODE
    elseif mods.bounceCount > 0 then
        return ProjectileSystem.CollisionBehavior.BOUNCE
    elseif mods.pierceCount > 0 then
        return ProjectileSystem.CollisionBehavior.PIERCE
    else
        return ProjectileSystem.CollisionBehavior.DESTROY
    end
end
```

## Step 5: Handle Multi-Shot Modifier

```lua
function executeProjectileWithMultishot(ctx, cardData, modifierCards)
    local mods = aggregateModifiers(modifierCards)
    local playerPos = getPlayerPosition()
    local baseAngle = getPlayerFacingAngle()

    -- Check for multishot modifier
    if mods.multishot and mods.multishot > 1 then
        local projectiles = {}
        local spread = mods.multishot_spread or (math.pi / 4)
        local count = mods.multishot

        -- Calculate angles for spread
        local startAngle = baseAngle - (spread / 2)
        local angleStep = spread / (count - 1)

        for i = 0, count - 1 do
            local angle = startAngle + (angleStep * i)

            local proj = ProjectileSystem.spawn({
                position = {x = playerPos.x, y = playerPos.y},
                angle = angle,
                movementType = ProjectileSystem.MovementType.STRAIGHT,
                baseSpeed = cardData.projectileSpeed,
                damage = cardData.baseDamage,
                damageType = cardData.damageType,
                owner = ctx.playerEntity,
                collisionBehavior = getCollisionBehavior(mods),
                maxPierceCount = mods.pierceCount,
                speedMultiplier = mods.speedMultiplier,
                damageMultiplier = mods.damageMultiplier,
                sprite = cardData.projectileSprite,
                lifetime = 4.0
            })

            table.insert(projectiles, proj)
        end

        return projectiles
    else
        -- Single projectile
        return {executeSingleProjectile(ctx, cardData, modifierCards, baseAngle)}
    end
end
```

## Step 6: Implement On-Hit Effects

```lua
function handleProjectileHit(ctx, projectile, target, data, modifierCards)
    -- Apply on-hit modifiers
    for _, modCard in ipairs(modifierCards) do
        if modCard.category == "on_hit" then
            applyOnHitEffect(modCard, ctx, projectile, target, data)
        end
    end
end

function applyOnHitEffect(modCard, ctx, projectile, target, data)
    local hitPos = getEntityPosition(target)

    if modCard.id == "freeze_on_hit" then
        applyStatusEffect(target, "frozen", 2.0)
        spawnFreezeParticles(hitPos)

    elseif modCard.id == "chain_lightning" then
        local nearbyEnemies = findEnemiesInRadius(hitPos, 150, 3)
        for _, enemy in ipairs(nearbyEnemies) do
            if enemy ~= target then
                -- Spawn chain lightning projectile
                ProjectileSystem.spawn({
                    position = hitPos,
                    homingTarget = enemy,
                    movementType = ProjectileSystem.MovementType.HOMING,
                    baseSpeed = 800,
                    homingStrength = 20.0,
                    damage = data.damage * 0.5,  -- 50% damage on chain
                    damageType = "lightning",
                    owner = data.owner,
                    collisionBehavior = ProjectileSystem.CollisionBehavior.DESTROY,
                    lifetime = 1.0,
                    sprite = "chain_lightning_anim"
                })
            end
        end

    elseif modCard.id == "summon_minion_on_hit" then
        spawnMinion(hitPos, data.owner)

    elseif modCard.id == "life_steal" then
        healPlayer(ctx.playerEntity, data.damage * 0.2)  -- 20% life steal
    end
end
```

## Step 7: Subscribe to Projectile Events

```lua
-- Set up event listeners for wand system
function initWandProjectileIntegration()
    -- Track projectile hits for combo systems
    subscribeToLuaEvent("projectile_hit", function(eventData)
        incrementComboCounter()
        updateCombatLog(eventData)

        -- Trigger on-hit card effects
        local modCards = getModifierCardsForProjectile(eventData.projectile)
        for _, card in ipairs(modCards) do
            if card.onHitEvent then
                card.onHitEvent(eventData)
            end
        end
    end)

    -- Track projectile destruction for cooldown refunds
    subscribeToLuaEvent("projectile_destroyed", function(eventData)
        if eventData.reason == "timeout" then
            -- Refund partial cooldown for missed shots
            refundCooldown(eventData.owner, 0.2)
        end
    end)

    -- Handle explosions for screen shake and camera effects
    subscribeToLuaEvent("projectile_exploded", function(eventData)
        screenShake(0.3, eventData.radius / 200)
        spawnExplosionParticles(eventData.position, eventData.radius)
        playSoundEffect("explosion", eventData.position)
    end)
end
```

## Step 8: Complete Example - Fire Bolt Wand

```lua
-- Complete wand action that uses projectile system
local FireBoltWand = {
    -- Action card
    actionCard = {
        id = "fire_basic_bolt",
        displayName = "Fire Bolt",
        description = "Shoots a bolt of fire",
        baseDamage = 25,
        damageType = "fire",
        cooldown = 0.5,
        energyCost = 10
    },

    -- Modifier cards (stacked on action)
    modifierCards = {
        {id = "double_damage", category = "modifier"},
        {id = "projectile_pierces_twice", category = "modifier"},
        {id = "freeze_on_hit", category = "on_hit"}
    },

    -- Execute wand (called by trigger system)
    execute = function(self, ctx)
        -- Check cooldown and energy
        if not canCastWand(self, ctx) then
            return false
        end

        -- Consume resources
        consumeEnergy(ctx.playerEntity, self.actionCard.energyCost)
        startCooldown(self.actionCard.id, self.actionCard.cooldown)

        -- Aggregate modifiers
        local mods = {
            speedMultiplier = 1.0,
            damageMultiplier = 1.0,
            pierceCount = 0
        }

        for _, modCard in ipairs(self.modifierCards) do
            if modCard.id == "double_damage" then
                mods.damageMultiplier = 2.0
            elseif modCard.id == "projectile_pierces_twice" then
                mods.pierceCount = 2
            end
        end

        -- Get player state
        local playerPos = getPlayerPosition()
        local playerAngle = getPlayerFacingAngle()

        -- Spawn projectile
        local projectile = ProjectileSystem.spawn({
            position = {x = playerPos.x, y = playerPos.y},
            angle = playerAngle,

            movementType = ProjectileSystem.MovementType.STRAIGHT,
            baseSpeed = 400,

            damage = self.actionCard.baseDamage,
            damageType = self.actionCard.damageType,
            owner = ctx.playerEntity,

            collisionBehavior = mods.pierceCount > 0
                and ProjectileSystem.CollisionBehavior.PIERCE
                or ProjectileSystem.CollisionBehavior.DESTROY,
            maxPierceCount = mods.pierceCount,

            speedMultiplier = mods.speedMultiplier,
            damageMultiplier = mods.damageMultiplier,

            lifetime = 5.0,
            sprite = "fireball_anim",
            size = 16,
            shadow = true,

            -- Store modifier cards for on-hit processing
            modifiers = {
                cards = self.modifierCards
            },

            onHit = function(proj, target, data)
                -- Apply freeze on hit
                for _, modCard in ipairs(self.modifierCards) do
                    if modCard.id == "freeze_on_hit" then
                        applyStatusEffect(target, "frozen", 2.0)
                    end
                end
            end
        })

        -- Play cast sound
        playSoundEffect("fire_bolt_cast", playerPos)

        -- Spawn cast particles
        spawnCastParticles(playerPos, playerAngle)

        return true
    end
}

-- Use in trigger system
subscribeToLuaEvent("player_pressed_attack", function(event)
    FireBoltWand:execute({playerEntity = event.player})
end)
```

## Helper Functions Template

```lua
-- Implement these helper functions in your wand system:

function getPlayerPosition()
    local transform = component_cache.get(playerEntity, Transform)
    return {x = transform.actualX, y = transform.actualY}
end

function getPlayerFacingAngle()
    -- Return angle player is facing (radians)
    -- Could be based on mouse position, last movement, etc.
    local mousePos = getMouseWorldPosition()
    local playerPos = getPlayerPosition()
    return math.atan2(mousePos.y - playerPos.y, mousePos.x - playerPos.x)
end

function findNearestEnemy(position, maxDistance)
    -- Query spatial system for nearest enemy within maxDistance
    -- Return entity ID or nil
end

function getEntityPosition(entity)
    local transform = component_cache.get(entity, Transform)
    return {x = transform.actualX, y = transform.actualY}
end

function applyStatusEffect(entity, statusType, duration)
    -- Apply status effect (freeze, burn, stun, etc.)
end

function spawnMinion(position, owner)
    -- Spawn minion entity at position
end

function healPlayer(player, amount)
    -- Heal player by amount
end

function canCastWand(wand, ctx)
    -- Check cooldown and energy
    return not isOnCooldown(wand.actionCard.id)
        and getEnergy(ctx.playerEntity) >= wand.actionCard.energyCost
end
```

## Performance Tips

1. **Limit simultaneous projectiles**: Cap at 100-200 for consistent frame times
2. **Use pooling**: Automatic, but benefits increase with higher projectile count
3. **Disable physics for simple projectiles**: Set `usePhysics = false` if not needed
4. **Batch spawn**: Spawn multiple projectiles in one frame for spread shots
5. **Event throttling**: Don't subscribe to every projectile event if not needed

## Debugging

```lua
-- Enable debug logging
function debugProjectiles()
    subscribeToLuaEvent("projectile_spawned", function(data)
        print("SPAWN:", data.projectileType, "at", data.position.x, data.position.y)
    end)

    subscribeToLuaEvent("projectile_hit", function(data)
        print("HIT:", data.projectile, "hit", data.target, "for", data.damage)
    end)

    subscribeToLuaEvent("projectile_destroyed", function(data)
        print("DESTROY:", data.projectile, "reason:", data.reason)
    end)
end
```

## Complete Integration Checklist

- [ ] Import ProjectileSystem module
- [ ] Call ProjectileSystem.init() during game init
- [ ] Call ProjectileSystem.update(dt) in game loop
- [ ] Define action card executors
- [ ] Implement modifier application logic
- [ ] Set up on-hit effect handlers
- [ ] Subscribe to projectile events
- [ ] Test basic projectile spawning
- [ ] Test modifier stacking
- [ ] Test on-hit effects
- [ ] Validate performance with many projectiles
- [ ] Add visual/audio feedback
- [ ] Document card behaviors

---

**Ready to integrate!** See `projectile_examples.lua` for more working code samples.

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
