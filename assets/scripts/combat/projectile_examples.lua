--[[
=============================================================================
PROJECTILE SYSTEM EXAMPLES & TESTS
=============================================================================
Demonstrates how to use the projectile system with various configurations
]]--

local ProjectileSystem = require("combat.projectile_system")

local ProjectileExamples = {}

--[[
=============================================================================
EXAMPLE 1: BASIC STRAIGHT PROJECTILE
=============================================================================
A simple projectile that travels in a straight line
]]--

function ProjectileExamples.spawnBasicFireball(x, y, angle, owner)
    return ProjectileSystem.spawn({
        -- Position & direction
        position = {x = x, y = y},
        angle = angle,

        -- Movement
        movementType = ProjectileSystem.MovementType.STRAIGHT,
        baseSpeed = 400,

        -- Damage
        damage = 25,
        damageType = "fire",
        owner = owner,

        -- Collision
        collisionBehavior = ProjectileSystem.CollisionBehavior.DESTROY,

        -- Lifetime
        lifetime = 3.0,

        -- Visual
        sprite = "fireball_anim",
        size = 16,
        shadow = true,

        -- Event hooks
        onSpawn = function(entity, params)
            log_debug("Fireball spawned!")
            -- Spawn particle trail
            if particle then
                -- Add trail effect
            end
        end,

        onHit = function(projectile, target, data)
            log_debug("Fireball hit target!")
            -- Play hit sound
            -- Spawn hit particles
        end,

        onDestroy = function(entity, data)
            log_debug("Fireball destroyed")
        end
    })
end

--[[
=============================================================================
EXAMPLE 2: HOMING MISSILE
=============================================================================
A projectile that tracks and follows a target
]]--

function ProjectileExamples.spawnHomingMissile(x, y, targetEntity, owner)
    if not targetEntity or targetEntity == entt_null then
        log_debug("No valid target for homing missile")
        return entt_null
    end

    return ProjectileSystem.spawn({
        -- Position
        position = {x = x, y = y},

        -- Movement - homing
        movementType = ProjectileSystem.MovementType.HOMING,
        baseSpeed = 300,
        homingTarget = targetEntity,
        homingStrength = 10.0,  -- High turn rate for aggressive tracking
        homingMaxSpeed = 500,

        -- Start with direction towards target
        direction = (function()
            local targetTrans = component_cache.get(targetEntity, Transform)
            if targetTrans then
                local dx = targetTrans.actualX - x
                local dy = targetTrans.actualY - y
                local dist = math.sqrt(dx*dx + dy*dy)
                return {x = dx/dist, y = dy/dist}
            end
            return {x = 1, y = 0}
        end)(),

        -- Damage
        damage = 40,
        damageType = "physical",
        owner = owner,

        -- Collision
        collisionBehavior = ProjectileSystem.CollisionBehavior.DESTROY,

        -- Lifetime
        lifetime = 6.0,

        -- Visual
        sprite = "missile_anim",
        size = 20,
        shadow = true,

        -- Modifiers from cards
        speedMultiplier = 1.2,
        damageMultiplier = 1.5,

        onHit = function(projectile, target, data)
            -- Explosion on hit
            ProjectileSystem.handleExplosion(projectile, data, {
                explosionRadius = 60,
                explosionDamageMult = 0.5
            })
        end
    })
end

--[[
=============================================================================
EXAMPLE 3: PIERCING ARROW
=============================================================================
A projectile that can pass through multiple enemies
]]--

function ProjectileExamples.spawnPiercingArrow(x, y, angle, owner, pierceCount)
    return ProjectileSystem.spawn({
        -- Position & direction
        position = {x = x, y = y},
        angle = angle,

        -- Movement
        movementType = ProjectileSystem.MovementType.STRAIGHT,
        baseSpeed = 600,

        -- Damage
        damage = 15,
        damageType = "pierce",
        owner = owner,

        -- Collision - pierce through enemies
        collisionBehavior = ProjectileSystem.CollisionBehavior.PIERCE,
        pierceCount = 0,
        maxPierceCount = pierceCount or 3,

        -- Lifetime
        lifetime = 2.0,
        maxDistance = 800,  -- Max travel distance

        -- Visual
        sprite = "arrow_sprite.png",
        size = 24,
        fixedRotation = false,  -- Rotate to face direction

        -- Physics
        gravityScale = 0,  -- No gravity for arrow

        onHit = function(projectile, target, data)
            -- Reduce damage on each pierce
            data.damageMultiplier = data.damageMultiplier * 0.8
            log_debug("Arrow pierced! Remaining pierces:", data.maxPierceCount - data.pierceCount)
        end
    })
end

--[[
=============================================================================
EXAMPLE 4: BOUNCING PROJECTILE
=============================================================================
A projectile that bounces off walls/enemies
]]--

function ProjectileExamples.spawnBouncingOrb(x, y, direction, owner)
    return ProjectileSystem.spawn({
        -- Position & direction
        position = {x = x, y = y},
        direction = direction,

        -- Movement
        movementType = ProjectileSystem.MovementType.STRAIGHT,
        baseSpeed = 350,

        -- Damage
        damage = 20,
        damageType = "physical",
        owner = owner,

        -- Collision - bounce
        collisionBehavior = ProjectileSystem.CollisionBehavior.BOUNCE,
        bounceCount = 0,
        maxBounces = 5,
        bounceDampening = 0.9,  -- Lose 10% speed per bounce

        -- Lifetime
        lifetime = 8.0,

        -- Visual
        sprite = "bouncing_orb_anim",
        size = 12,
        looping = true,
        shadow = true,

        -- Physics
        restitution = 0.95,  -- Very bouncy
        friction = 0.1,

        onHit = function(projectile, target, data)
            local behavior = component_cache.get(projectile, GameObject).projectileBehavior
            log_debug("Orb bounced! Bounces remaining:",
                behavior.maxBounces - behavior.bounceCount)
        end
    })
end

--[[
=============================================================================
EXAMPLE 5: EXPLOSIVE PROJECTILE (GRENADE)
=============================================================================
Arc projectile affected by gravity that explodes on impact
]]--

function ProjectileExamples.spawnGrenade(x, y, angle, power, owner)
    return ProjectileSystem.spawn({
        -- Position & direction
        position = {x = x, y = y},
        angle = angle,

        -- Movement - arc with gravity
        movementType = ProjectileSystem.MovementType.ARC,
        baseSpeed = power or 400,
        gravityScale = 1.8,  -- Affected by gravity

        -- Damage
        damage = 50,
        damageType = "fire",
        owner = owner,

        -- Collision - explode on impact
        collisionBehavior = ProjectileSystem.CollisionBehavior.EXPLODE,
        explosionRadius = 100,
        explosionDamageMult = 1.2,

        -- Lifetime
        lifetime = 5.0,

        -- Visual
        sprite = "grenade_sprite.png",
        size = 16,
        shadow = true,
        fixedRotation = false,

        onHit = function(projectile, target, data)
            log_debug("Grenade exploded!")
            -- Play explosion sound
            -- Camera shake
        end
    })
end

--[[
=============================================================================
EXAMPLE 6: ORBITAL PROJECTILE
=============================================================================
Projectile that orbits around a center point
]]--

function ProjectileExamples.spawnOrbitalShield(centerX, centerY, owner)
    return ProjectileSystem.spawn({
        -- Position (will be calculated from orbit)
        position = {x = centerX, y = centerY},

        -- Movement - orbital
        movementType = ProjectileSystem.MovementType.ORBITAL,
        orbitCenter = {x = centerX, y = centerY},
        orbitRadius = 80,
        orbitSpeed = 2.0,  -- radians per second
        orbitAngle = 0,

        -- Damage
        damage = 10,
        damageType = "physical",
        owner = owner,

        -- Collision - pass through and damage
        collisionBehavior = ProjectileSystem.CollisionBehavior.PASS_THROUGH,

        -- Lifetime
        lifetime = 10.0,

        -- Visual
        sprite = "shield_orb_anim",
        size = 20,
        looping = true,

        -- Physics - sensor only, no collision
        usePhysics = true,
        shapeType = "circle"
    })
end

--[[
=============================================================================
EXAMPLE 7: CUSTOM MOVEMENT PROJECTILE
=============================================================================
Projectile with custom update logic (sine wave pattern)
]]--

function ProjectileExamples.spawnSineWaveProjectile(x, y, angle, owner)
    local baseVelX = math.cos(angle) * 300
    local baseVelY = math.sin(angle) * 300
    local time = 0

    return ProjectileSystem.spawn({
        -- Position & direction
        position = {x = x, y = y},
        angle = angle,

        -- Movement - custom
        movementType = ProjectileSystem.MovementType.CUSTOM,
        baseSpeed = 300,

        -- Damage
        damage = 18,
        damageType = "lightning",
        owner = owner,

        -- Collision
        collisionBehavior = ProjectileSystem.CollisionBehavior.DESTROY,

        -- Lifetime
        lifetime = 4.0,

        -- Visual
        sprite = "lightning_bolt_anim",
        size = 14,

        -- Custom update function - sine wave motion
        customUpdate = function(entity, dt, transform, behavior, data)
            time = time + dt

            -- Perpendicular direction for sine wave
            local perpX = -math.sin(angle)
            local perpY = math.cos(angle)

            -- Apply sine wave offset
            local amplitude = 50
            local frequency = 5
            local offset = math.sin(time * frequency) * amplitude

            -- Update position
            transform.actualX = transform.actualX + baseVelX * dt + perpX * offset * dt
            transform.actualY = transform.actualY + baseVelY * dt + perpY * offset * dt

            -- Update rotation
            transform.actualR = angle + math.sin(time * frequency) * 0.3
        end
    })
end

--[[
=============================================================================
EXAMPLE 8: MULTI-SHOT SPREAD
=============================================================================
Spawn multiple projectiles in a spread pattern
]]--

function ProjectileExamples.spawnSpread(x, y, baseAngle, owner, count, spread)
    count = count or 5
    spread = spread or math.pi / 4  -- 45 degrees default

    local projectiles = {}
    local startAngle = baseAngle - (spread / 2)
    local angleStep = spread / (count - 1)

    for i = 0, count - 1 do
        local angle = startAngle + (angleStep * i)

        local projectile = ProjectileSystem.spawn({
            position = {x = x, y = y},
            angle = angle,
            movementType = ProjectileSystem.MovementType.STRAIGHT,
            baseSpeed = 350,
            damage = 12,
            damageType = "physical",
            owner = owner,
            collisionBehavior = ProjectileSystem.CollisionBehavior.DESTROY,
            lifetime = 2.5,
            sprite = "bullet_sprite.png",
            size = 8
        })

        table.insert(projectiles, projectile)
    end

    return projectiles
end

--[[
=============================================================================
EXAMPLE 9: PROJECTILE WITH CARD MODIFIERS
=============================================================================
Shows how to apply card modifiers to projectiles (for wand system integration)
]]--

function ProjectileExamples.spawnWithModifiers(x, y, angle, owner, cardModifiers)
    -- cardModifiers example:
    -- {
    --   speedMultiplier = 1.5,
    --   damageMultiplier = 2.0,
    --   pierceCount = 2,
    --   homingEnabled = true,
    --   explosionOnHit = true
    -- }

    cardModifiers = cardModifiers or {}

    local params = {
        position = {x = x, y = y},
        angle = angle,
        movementType = ProjectileSystem.MovementType.STRAIGHT,
        baseSpeed = 300,
        damage = 20,
        damageType = "physical",
        owner = owner,
        lifetime = 3.0,
        sprite = "modified_projectile.png",
        size = 12,

        -- Apply modifiers
        speedMultiplier = cardModifiers.speedMultiplier or 1.0,
        damageMultiplier = cardModifiers.damageMultiplier or 1.0,
        sizeMultiplier = cardModifiers.sizeMultiplier or 1.0,

        modifiers = cardModifiers
    }

    -- Apply piercing if modifier exists
    if cardModifiers.pierceCount and cardModifiers.pierceCount > 0 then
        params.collisionBehavior = ProjectileSystem.CollisionBehavior.PIERCE
        params.maxPierceCount = cardModifiers.pierceCount
    else
        params.collisionBehavior = ProjectileSystem.CollisionBehavior.DESTROY
    end

    -- Apply homing if modifier exists
    if cardModifiers.homingEnabled and cardModifiers.homingTarget then
        params.movementType = ProjectileSystem.MovementType.HOMING
        params.homingTarget = cardModifiers.homingTarget
        params.homingStrength = cardModifiers.homingStrength or 5.0
    end

    -- Apply explosion if modifier exists
    if cardModifiers.explosionOnHit then
        params.collisionBehavior = ProjectileSystem.CollisionBehavior.EXPLODE
        params.explosionRadius = cardModifiers.explosionRadius or 80
    end

    return ProjectileSystem.spawn(params)
end

--[[
=============================================================================
TEST FUNCTION
=============================================================================
Run this to test basic projectile spawning
]]--

function ProjectileExamples.runTests()
    log_debug("=== Running Projectile System Tests ===")

    -- Test 1: Basic projectile
    log_debug("Test 1: Basic straight projectile")
    local p1 = ProjectileExamples.spawnBasicFireball(400, 300, 0, entt_null)
    log_debug("  Spawned projectile:", p1)

    -- Test 2: Homing projectile (need a target)
    -- log_debug("Test 2: Homing missile")
    -- local target = ... -- get a target entity
    -- local p2 = ProjectileExamples.spawnHomingMissile(400, 300, target, entt_null)

    -- Test 3: Piercing arrow
    log_debug("Test 3: Piercing arrow")
    local p3 = ProjectileExamples.spawnPiercingArrow(400, 300, math.pi/4, entt_null, 3)
    log_debug("  Spawned projectile:", p3)

    -- Test 4: Bouncing orb
    log_debug("Test 4: Bouncing orb")
    local p4 = ProjectileExamples.spawnBouncingOrb(400, 300, {x = 1, y = -0.5}, entt_null)
    log_debug("  Spawned projectile:", p4)

    -- Test 5: Grenade
    log_debug("Test 5: Grenade (arc)")
    local p5 = ProjectileExamples.spawnGrenade(400, 300, -math.pi/4, 500, entt_null)
    log_debug("  Spawned projectile:", p5)

    -- Test 6: Orbital shield
    log_debug("Test 6: Orbital projectile")
    local p6 = ProjectileExamples.spawnOrbitalShield(400, 300, entt_null)
    log_debug("  Spawned projectile:", p6)

    -- Test 7: Sine wave
    log_debug("Test 7: Sine wave projectile")
    local p7 = ProjectileExamples.spawnSineWaveProjectile(400, 300, 0, entt_null)
    log_debug("  Spawned projectile:", p7)

    -- Test 8: Spread shot
    log_debug("Test 8: Spread shot")
    local spread = ProjectileExamples.spawnSpread(400, 300, 0, entt_null, 5, math.pi/3)
    log_debug("  Spawned", #spread, "projectiles")

    log_debug("=== Tests Complete ===")
end

return ProjectileExamples
