--[[
=============================================================================
PROJECTILE SPAWNING & MANAGEMENT SYSTEM
=============================================================================
A complete projectile system for Lua/C++ game engine (Raylib + EnTT + Chipmunk2D)

Features:
- Entity-based projectiles with physics integration
- Multiple movement patterns (straight, homing, orbital, arc/gravity)
- Collision handling (pierce, bounce, explode, pass-through)
- Lifetime management (time, distance, hit-count based)
- Damage integration with combat system
- Event hooks for spawn/hit/destroy
- Modifier support for wand system integration
- Projectile pooling for performance

Architecture:
- Uses existing ECS (EnTT registry)
- Integrates with Chipmunk2D physics for collision
- Connects to combat system for damage application
- Emits events for wand system subscriptions
=============================================================================
]]--

local timer = require("core.timer")
local component_cache = require("core.component_cache")
local entity_cache = require("core.entity_cache")

-- Module table
local ProjectileSystem = {}

-- Projectile pool for reuse
ProjectileSystem.pool = {}
ProjectileSystem.active_projectiles = {}
ProjectileSystem.next_projectile_id = 1

-- Physics step timer handle
ProjectileSystem.physics_step_timer_id = nil
ProjectileSystem.use_physics_step_timer = true  -- Set to true to update on physics steps

-- Movement pattern constants
ProjectileSystem.MovementType = {
    STRAIGHT = "straight",
    HOMING = "homing",
    ORBITAL = "orbital",
    ARC = "arc",           -- gravity-affected
    CUSTOM = "custom"      -- uses custom update function
}

-- Collision behavior constants
ProjectileSystem.CollisionBehavior = {
    DESTROY = "destroy",         -- destroy on first hit
    PIERCE = "pierce",           -- pass through N enemies
    BOUNCE = "bounce",           -- ricochet off surfaces
    EXPLODE = "explode",         -- AoE damage on hit
    PASS_THROUGH = "pass_through" -- ignore collision but still deal damage
}

-- Physics collision category for projectiles
ProjectileSystem.COLLISION_CATEGORY = "projectile"

--[[
=============================================================================
PROJECTILE DATA STRUCTURES
=============================================================================
]]--

-- ProjectileData component (attached to entity)
-- Stores damage, owner, piercing state, and modifiers
function ProjectileSystem.createProjectileData(params)
    return {
        -- Core damage data
        damage = params.damage or 10,
        damageType = params.damageType or "physical",
        owner = params.owner or entt_null,
        faction = params.faction or "player", -- for friendly fire logic

        -- Piercing/hit tracking
        pierceCount = params.pierceCount or 0,
        maxPierceCount = params.maxPierceCount or 0,
        hitEntities = {}, -- track hit entities to avoid double-hit

        -- Modifiers from cards/wand system
        modifiers = params.modifiers or {},
        speedMultiplier = params.speedMultiplier or 1.0,
        damageMultiplier = params.damageMultiplier or 1.0,
        sizeMultiplier = params.sizeMultiplier or 1.0,

        -- Event hooks
        onSpawnCallback = params.onSpawn,
        onHitCallback = params.onHit,
        onDestroyCallback = params.onDestroy,

        -- Metadata
        projectileId = ProjectileSystem.next_projectile_id,
        creationTime = os.clock()
    }
end

-- ProjectileBehavior component
-- Stores movement pattern and targeting info
function ProjectileSystem.createProjectileBehavior(params)
    return {
        -- Movement type
        movementType = params.movementType or ProjectileSystem.MovementType.STRAIGHT,

        -- Collision behavior
        collisionBehavior = params.collisionBehavior or ProjectileSystem.CollisionBehavior.DESTROY,

        -- Base velocity (for straight/arc patterns)
        velocity = params.velocity or {x = 0, y = 0},
        baseSpeed = params.baseSpeed or 300, -- pixels per second

        -- Homing parameters
        homingTarget = params.homingTarget,
        homingStrength = params.homingStrength or 5.0, -- turn rate
        homingMaxSpeed = params.homingMaxSpeed or 400,

        -- Orbital parameters
        orbitCenter = params.orbitCenter,
        orbitRadius = params.orbitRadius or 100,
        orbitSpeed = params.orbitSpeed or 2.0, -- radians/sec
        orbitAngle = params.orbitAngle or 0,

        -- Gravity scale (for arc movement)
        gravityScale = params.gravityScale or 1.0,

        -- Bounce parameters
        bounceCount = params.bounceCount or 0,
        maxBounces = params.maxBounces or 3,
        bounceDampening = params.bounceDampening or 0.8,

        -- Custom update function
        customUpdate = params.customUpdate
    }
end

-- ProjectileLifetime component
-- Manages despawn conditions
function ProjectileSystem.createProjectileLifetime(params)
    return {
        -- Time-based despawn
        maxLifetime = params.maxLifetime or 5.0, -- seconds
        currentLifetime = 0,

        -- Distance-based despawn
        maxDistance = params.maxDistance,
        distanceTraveled = 0,
        startPosition = params.startPosition,

        -- Hit-count based despawn
        maxHits = params.maxHits,
        hitCount = 0,

        -- Flags
        shouldDespawn = false,
        despawnReason = nil
    }
end

--[[
=============================================================================
PROJECTILE SPAWNING API
=============================================================================
]]--

-- Main projectile spawn function
-- Returns: entity ID of spawned projectile
function ProjectileSystem.spawn(params)
    -- Validate required parameters
    if not params.position then
        log_error("ProjectileSystem.spawn: position is required")
        return entt_null
    end

    -- Try to get from pool first (performance optimization)
    local entity = ProjectileSystem.getFromPool()
    if entity == entt_null then
        -- Create new entity
        entity = registry:create()
    end

    -- Increment projectile ID
    ProjectileSystem.next_projectile_id = ProjectileSystem.next_projectile_id + 1

    -- Create transform component
    local transform = component_cache.get_or_emplace(entity, Transform)
    transform.actualX = params.position.x
    transform.actualY = params.position.y
    transform.actualW = (params.size or 8) * (params.sizeMultiplier or 1.0)
    transform.actualH = (params.size or 8) * (params.sizeMultiplier or 1.0)
    transform.actualR = params.rotation or 0

    -- Create visual representation (animated sprite or simple sprite)
    if params.sprite then
        animation_system.setupAnimatedObjectOnEntity(
            entity,
            params.sprite,
            params.looping or false,
            nil, -- no shader pass by default
            params.shadow or false
        )

        if params.size then
            animation_system.resizeAnimationObjectsInEntityToFit(
                entity,
                transform.actualW,
                transform.actualH
            )
        end
    end

    -- Attach projectile components
    local projectileData = ProjectileSystem.createProjectileData(params)
    local projectileBehavior = ProjectileSystem.createProjectileBehavior(params)
    local projectileLifetime = ProjectileSystem.createProjectileLifetime({
        maxLifetime = params.lifetime or 5.0,
        maxDistance = params.maxDistance,
        startPosition = {x = params.position.x, y = params.position.y},
        maxHits = params.maxHits
    })

    -- Store components on entity (using table attachment)
    if not registry:has(entity, GameObject) then
        registry:emplace(entity, GameObject)
    end

    local gameObj = component_cache.get(entity, GameObject)
    gameObj.projectileData = projectileData
    gameObj.projectileBehavior = projectileBehavior
    gameObj.projectileLifetime = projectileLifetime

    -- Setup physics body for projectile
    if params.usePhysics ~= false then
        ProjectileSystem.setupPhysics(entity, params)
    end

    -- Calculate initial velocity based on movement type
    ProjectileSystem.initializeMovement(entity, params)

    -- Add to active projectiles tracking
    ProjectileSystem.active_projectiles[entity] = true

    -- Call onSpawn callback if provided
    if projectileData.onSpawnCallback then
        projectileData.onSpawnCallback(entity, params)
    end

    -- Emit spawn event for wand system
    if params.emitEvents ~= false then
        publishLuaEvent("projectile_spawned", {
            entity = entity,
            owner = params.owner,
            position = params.position,
            projectileType = params.projectileType or "default"
        })
    end

    log_debug("Spawned projectile", entity, "at", params.position.x, params.position.y)

    return entity
end

-- Setup Chipmunk2D physics for projectile
function ProjectileSystem.setupPhysics(entity, params)
    -- Check if physics world is available
    if not physics or not globals.physicsWorld then
        log_warn("Physics world not available, projectile will not have collision")
        return
    end

    local world = globals.physicsWorld
    local transform = component_cache.get(entity, Transform)

    -- Create physics body (dynamic body that moves)
    physics.create_physics_for_transform(world, entity, "dynamic")

    -- Add collider shape based on projectile shape type
    local shapeType = params.shapeType or "circle"
    local isSensor = (params.collisionBehavior == ProjectileSystem.CollisionBehavior.PASS_THROUGH)

    if shapeType == "circle" then
        local radius = (params.size or 8) / 2
        physics.AddCollider(world, entity, ProjectileSystem.COLLISION_CATEGORY,
            "circle", radius, 0, 0, 0, isSensor)
    elseif shapeType == "rectangle" then
        local w = transform.actualW
        local h = transform.actualH
        physics.AddCollider(world, entity, ProjectileSystem.COLLISION_CATEGORY,
            "rectangle", w, h, 0, 0, isSensor)
    end

    -- Set physics properties
    local body = physics.GetBodyFromEntity(world, entity)
    if body then
        -- Make it a bullet for high-speed collision detection
        physics.SetBodyType(body, "dynamic")
        physics.SetBullet(body, true)

        -- Set friction and restitution
        physics.SetFriction(world, entity, params.friction or 0.0)
        physics.SetRestitution(world, entity, params.restitution or 0.5)

        -- Disable rotation if needed
        if params.fixedRotation ~= false then
            physics.SetFixedRotation(body, true)
        end

        -- Set gravity scale
        local behavior = component_cache.get(entity, GameObject).projectileBehavior
        if behavior.gravityScale then
            physics.SetGravityScale(body, behavior.gravityScale)
        end
    end

    -- Configure physics sync: Make physics authoritative for projectiles
    -- This ensures smooth integration with your existing physics-transform sync system
    if registry and registry.emplace then
        local PhysicsSyncConfig = {
            -- Physics is authoritative (physics drives transform)
            mode = "AuthoritativePhysics",  -- PhysicsSyncMode.AuthoritativePhysics

            -- Pull position from physics to transform
            pullPositionFromPhysics = true,

            -- Rotation handling: Use visual rotation for sprite facing
            rotMode = "TransformFixed_PhysicsFollows",  -- We set visualR, physics rotation locked
            pullAngleFromPhysics = false,  -- Don't pull rotation from physics
            useVisualRotationWhenDragging = false,  -- Projectiles can't be dragged

            -- Interpolation for smooth rendering
            useInterpolation = true,

            -- Not kinematic (dynamic body)
            useKinematic = false,
        }

        -- Try to set the sync config (compatible with your physics hook system)
        -- Note: This may need adjustment based on your exact PhysicsSyncConfig component structure
        if registry.try_get then
            local success = pcall(function()
                registry:emplace(entity, "PhysicsSyncConfig", PhysicsSyncConfig)
            end)
            if not success then
                log_debug("PhysicsSyncConfig not available, projectile will use default sync")
            end
        end
    end

    -- Setup collision callback
    ProjectileSystem.setupCollisionCallback(entity)
end

-- Initialize movement based on movement type
function ProjectileSystem.initializeMovement(entity, params)
    local gameObj = component_cache.get(entity, GameObject)
    local behavior = gameObj.projectileBehavior
    local transform = component_cache.get(entity, Transform)

    if behavior.movementType == ProjectileSystem.MovementType.STRAIGHT then
        -- Set initial velocity from direction/speed
        if params.direction then
            local speed = behavior.baseSpeed * (params.speedMultiplier or 1.0)
            behavior.velocity.x = params.direction.x * speed
            behavior.velocity.y = params.direction.y * speed
        elseif params.angle then
            local speed = behavior.baseSpeed * (params.speedMultiplier or 1.0)
            behavior.velocity.x = math.cos(params.angle) * speed
            behavior.velocity.y = math.sin(params.angle) * speed
        elseif params.velocity then
            behavior.velocity.x = params.velocity.x
            behavior.velocity.y = params.velocity.y
        end

        -- Apply velocity to physics body if present
        if physics and globals.physicsWorld then
            physics.SetVelocity(globals.physicsWorld, entity, behavior.velocity.x, behavior.velocity.y)
        end

    elseif behavior.movementType == ProjectileSystem.MovementType.HOMING then
        -- Initialize with starting velocity
        if params.direction then
            local speed = behavior.baseSpeed * (params.speedMultiplier or 1.0)
            behavior.velocity.x = params.direction.x * speed
            behavior.velocity.y = params.direction.y * speed
        end

    elseif behavior.movementType == ProjectileSystem.MovementType.ORBITAL then
        -- Set orbit center if not provided
        if not behavior.orbitCenter then
            behavior.orbitCenter = {x = transform.actualX, y = transform.actualY}
        end

    elseif behavior.movementType == ProjectileSystem.MovementType.ARC then
        -- Same as straight but with gravity enabled
        if params.direction then
            local speed = behavior.baseSpeed * (params.speedMultiplier or 1.0)
            behavior.velocity.x = params.direction.x * speed
            behavior.velocity.y = params.direction.y * speed
        end

        -- Gravity is handled by physics system
    end
end

--[[
=============================================================================
PROJECTILE UPDATE SYSTEM
=============================================================================
]]--

--- Internal update function (called by physics step timer OR manual update())
--- @param dt number Delta time in seconds
function ProjectileSystem.updateInternal(dt)
    -- Update all active projectiles
    local toRemove = {}

    for entity, _ in pairs(ProjectileSystem.active_projectiles) do
        if not entity_cache.valid(entity) then
            toRemove[#toRemove + 1] = entity
        else
            local shouldDestroy = ProjectileSystem.updateProjectile(entity, dt)
            if shouldDestroy then
                toRemove[#toRemove + 1] = entity
            end
        end
    end

    -- Remove destroyed projectiles
    for _, entity in ipairs(toRemove) do
        ProjectileSystem.destroy(entity)
    end
end

--- Public update function (for manual updates when not using physics step timer)
--- @param dt number Delta time in seconds
function ProjectileSystem.update(dt)
    -- If using physics step timer, this is a no-op (timer handles updates)
    if ProjectileSystem.use_physics_step_timer then
        return
    end

    -- Otherwise, call updateInternal directly
    ProjectileSystem.updateInternal(dt)
end

-- Update individual projectile
-- Returns: true if should be destroyed
function ProjectileSystem.updateProjectile(entity, dt)
    local gameObj = component_cache.get(entity, GameObject)
    if not gameObj then return true end

    local data = gameObj.projectileData
    local behavior = gameObj.projectileBehavior
    local lifetime = gameObj.projectileLifetime
    local transform = component_cache.get(entity, Transform)

    if not data or not behavior or not lifetime then return true end

    -- Update lifetime
    lifetime.currentLifetime = lifetime.currentLifetime + dt

    -- Check time-based despawn
    if lifetime.maxLifetime and lifetime.currentLifetime >= lifetime.maxLifetime then
        lifetime.shouldDespawn = true
        lifetime.despawnReason = "timeout"
        return true
    end

    -- Update movement based on type
    if behavior.movementType == ProjectileSystem.MovementType.STRAIGHT then
        ProjectileSystem.updateStraightMovement(entity, dt, transform, behavior)

    elseif behavior.movementType == ProjectileSystem.MovementType.HOMING then
        ProjectileSystem.updateHomingMovement(entity, dt, transform, behavior)

    elseif behavior.movementType == ProjectileSystem.MovementType.ORBITAL then
        ProjectileSystem.updateOrbitalMovement(entity, dt, transform, behavior)

    elseif behavior.movementType == ProjectileSystem.MovementType.ARC then
        -- Arc movement handled by physics gravity
        ProjectileSystem.updateArcMovement(entity, dt, transform, behavior)

    elseif behavior.movementType == ProjectileSystem.MovementType.CUSTOM then
        if behavior.customUpdate then
            behavior.customUpdate(entity, dt, transform, behavior, data)
        end
    end

    -- Update distance traveled
    if lifetime.maxDistance and lifetime.startPosition then
        local dx = transform.actualX - lifetime.startPosition.x
        local dy = transform.actualY - lifetime.startPosition.y
        lifetime.distanceTraveled = math.sqrt(dx * dx + dy * dy)

        if lifetime.distanceTraveled >= lifetime.maxDistance then
            lifetime.shouldDespawn = true
            lifetime.despawnReason = "distance"
            return true
        end
    end

    -- Check hit count despawn
    if lifetime.maxHits and lifetime.hitCount >= lifetime.maxHits then
        lifetime.shouldDespawn = true
        lifetime.despawnReason = "hit_count"
        return true
    end

    return false
end

--[[
=============================================================================
MOVEMENT PATTERNS
=============================================================================
]]--

function ProjectileSystem.updateStraightMovement(entity, dt, transform, behavior)
    -- Physics-driven: Let Chipmunk2D handle movement via velocity
    -- Rotation is updated to face direction for visual purposes only
    if physics and globals.physicsWorld then
        -- Sync velocity from physics (in case physics modified it)
        local vx, vy = physics.GetVelocity(globals.physicsWorld, entity)
        behavior.velocity.x = vx
        behavior.velocity.y = vy

        -- Update rotation to face direction (visual only, physics rotation locked)
        if vx ~= 0 or vy ~= 0 then
            transform.visualR = math.atan2(vy, vx)
        end
        return
    end

    -- Fallback: Manual movement if physics disabled (testing only)
    transform.actualX = transform.actualX + behavior.velocity.x * dt
    transform.actualY = transform.actualY + behavior.velocity.y * dt

    -- Update rotation to face direction
    if behavior.velocity.x ~= 0 or behavior.velocity.y ~= 0 then
        transform.actualR = math.atan2(behavior.velocity.y, behavior.velocity.x)
    end
end

function ProjectileSystem.updateHomingMovement(entity, dt, transform, behavior)
    -- Check if target is valid
    if not behavior.homingTarget or not entity_cache.valid(behavior.homingTarget) then
        -- Fall back to straight movement
        ProjectileSystem.updateStraightMovement(entity, dt, transform, behavior)
        return
    end

    -- Get target position
    local targetTransform = component_cache.get(behavior.homingTarget, Transform)
    if not targetTransform then
        ProjectileSystem.updateStraightMovement(entity, dt, transform, behavior)
        return
    end

    local targetX = targetTransform.actualX + targetTransform.actualW / 2
    local targetY = targetTransform.actualY + targetTransform.actualH / 2

    -- Get current position from transform
    local currentX = transform.actualX + transform.actualW / 2
    local currentY = transform.actualY + transform.actualH / 2

    -- Calculate direction to target
    local dx = targetX - currentX
    local dy = targetY - currentY
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist > 0.1 then
        -- Normalize direction
        dx = dx / dist
        dy = dy / dist

        -- Get current velocity from physics (authoritative)
        local currentVelX, currentVelY = behavior.velocity.x, behavior.velocity.y
        if physics and globals.physicsWorld then
            currentVelX, currentVelY = physics.GetVelocity(globals.physicsWorld, entity)
        end

        local currentSpeed = math.sqrt(currentVelX * currentVelX + currentVelY * currentVelY)

        -- Steer towards target (calculate desired velocity)
        local steerStrength = behavior.homingStrength * dt
        local desiredVelX = currentVelX + dx * steerStrength * currentSpeed
        local desiredVelY = currentVelY + dy * steerStrength * currentSpeed

        -- Clamp to max speed
        local newSpeed = math.sqrt(desiredVelX * desiredVelX + desiredVelY * desiredVelY)
        if newSpeed > behavior.homingMaxSpeed then
            desiredVelX = (desiredVelX / newSpeed) * behavior.homingMaxSpeed
            desiredVelY = (desiredVelY / newSpeed) * behavior.homingMaxSpeed
        end

        -- Update behavior velocity (for tracking)
        behavior.velocity.x = desiredVelX
        behavior.velocity.y = desiredVelY

        -- Apply velocity to physics (physics-driven)
        if physics and globals.physicsWorld then
            physics.SetVelocity(globals.physicsWorld, entity, desiredVelX, desiredVelY)

            -- Update visual rotation to face direction
            if desiredVelX ~= 0 or desiredVelY ~= 0 then
                transform.visualR = math.atan2(desiredVelY, desiredVelX)
            end
        else
            -- Fallback: Manual movement
            transform.actualX = transform.actualX + desiredVelX * dt
            transform.actualY = transform.actualY + desiredVelY * dt
            transform.actualR = math.atan2(desiredVelY, desiredVelX)
        end
    else
        -- Target reached or very close, maintain current velocity
        if physics and globals.physicsWorld then
            local vx, vy = physics.GetVelocity(globals.physicsWorld, entity)
            if vx ~= 0 or vy ~= 0 then
                transform.visualR = math.atan2(vy, vx)
            end
        end
    end
end

function ProjectileSystem.updateOrbitalMovement(entity, dt, transform, behavior)
    -- Update orbit angle
    behavior.orbitAngle = behavior.orbitAngle + behavior.orbitSpeed * dt

    -- Calculate position on orbit
    local centerX = behavior.orbitCenter.x
    local centerY = behavior.orbitCenter.y

    local targetX = centerX + math.cos(behavior.orbitAngle) * behavior.orbitRadius
    local targetY = centerY + math.sin(behavior.orbitAngle) * behavior.orbitRadius

    -- Physics-driven: Calculate velocity to reach target position
    if physics and globals.physicsWorld then
        -- Get current position from transform (updated by physics sync)
        local currentX = transform.actualX + transform.actualW / 2
        local currentY = transform.actualY + transform.actualH / 2

        -- Calculate velocity needed to reach target (simple proportional control)
        local velocityX = (targetX - currentX) / dt
        local velocityY = (targetY - currentY) / dt

        -- Apply velocity to physics body
        physics.SetVelocity(globals.physicsWorld, entity, velocityX, velocityY)

        -- Update visual rotation to face tangent direction
        transform.visualR = behavior.orbitAngle + math.pi / 2
    else
        -- Fallback: Direct position manipulation (not physics-driven)
        transform.actualX = targetX - transform.actualW / 2
        transform.actualY = targetY - transform.actualH / 2
        transform.actualR = behavior.orbitAngle + math.pi / 2
    end
end

function ProjectileSystem.updateArcMovement(entity, dt, transform, behavior)
    -- Physics-driven: Chipmunk2D handles gravity automatically
    if physics and globals.physicsWorld then
        -- Sync velocity from physics (gravity is applied by Chipmunk2D)
        local vx, vy = physics.GetVelocity(globals.physicsWorld, entity)
        behavior.velocity.x = vx
        behavior.velocity.y = vy

        -- Update visual rotation to face velocity direction
        if vx ~= 0 or vy ~= 0 then
            transform.visualR = math.atan2(vy, vx)
        end
    else
        -- Fallback: Manual arc movement with gravity simulation
        behavior.velocity.y = behavior.velocity.y + (900 * behavior.gravityScale * dt)
        transform.actualX = transform.actualX + behavior.velocity.x * dt
        transform.actualY = transform.actualY + behavior.velocity.y * dt
        transform.actualR = math.atan2(behavior.velocity.y, behavior.velocity.x)
    end
end

--[[
=============================================================================
COLLISION HANDLING
=============================================================================
]]--

function ProjectileSystem.setupCollisionCallback(entity)
    -- Create script component for collision handling
    local CollisionScript = {
        projectileEntity = entity,

        init = function(self)
            -- Called when script is attached
        end,

        update = function(self, dt)
            -- Not used for projectiles
        end,

        on_collision = function(self, other)
            ProjectileSystem.handleCollision(self.projectileEntity, other)
        end,

        destroy = function(self)
            -- Called when entity is destroyed
        end
    }

    -- Attach script to entity (or to collider child entity)
    if registry.add_script then
        registry:add_script(entity, CollisionScript)
    end
end

-- Handle collision between projectile and another entity
function ProjectileSystem.handleCollision(projectileEntity, otherEntity)
    if not entity_cache.valid(projectileEntity) or not entity_cache.valid(otherEntity) then
        return
    end

    local gameObj = component_cache.get(projectileEntity, GameObject)
    if not gameObj or not gameObj.projectileData then return end

    local data = gameObj.projectileData
    local behavior = gameObj.projectileBehavior
    local lifetime = gameObj.projectileLifetime

    -- Check if already hit this entity (for piercing)
    if data.hitEntities[otherEntity] then
        return
    end

    -- Mark as hit
    data.hitEntities[otherEntity] = true
    lifetime.hitCount = lifetime.hitCount + 1

    -- Apply damage to other entity
    ProjectileSystem.applyDamage(projectileEntity, otherEntity, data)

    -- Call onHit callback
    if data.onHitCallback then
        data.onHitCallback(projectileEntity, otherEntity, data)
    end

    -- Emit hit event
    publishLuaEvent("projectile_hit", {
        projectile = projectileEntity,
        target = otherEntity,
        owner = data.owner,
        damage = data.damage * data.damageMultiplier
    })

    -- Handle collision behavior
    if behavior.collisionBehavior == ProjectileSystem.CollisionBehavior.DESTROY then
        lifetime.shouldDespawn = true
        lifetime.despawnReason = "hit"

    elseif behavior.collisionBehavior == ProjectileSystem.CollisionBehavior.PIERCE then
        data.pierceCount = data.pierceCount + 1
        if data.pierceCount >= data.maxPierceCount then
            lifetime.shouldDespawn = true
            lifetime.despawnReason = "pierce_depleted"
        end

    elseif behavior.collisionBehavior == ProjectileSystem.CollisionBehavior.BOUNCE then
        ProjectileSystem.handleBounce(projectileEntity, otherEntity, behavior)

    elseif behavior.collisionBehavior == ProjectileSystem.CollisionBehavior.EXPLODE then
        ProjectileSystem.handleExplosion(projectileEntity, data, behavior)
        lifetime.shouldDespawn = true
        lifetime.despawnReason = "explosion"

    elseif behavior.collisionBehavior == ProjectileSystem.CollisionBehavior.PASS_THROUGH then
        -- Just deal damage, don't destroy
    end
end

-- Apply damage to target entity
function ProjectileSystem.applyDamage(projectileEntity, targetEntity, data)
    -- Check if target has health
    local targetGameObj = component_cache.get(targetEntity, GameObject)
    if not targetGameObj then return end

    -- Use combat system if available
    if CombatSystem and CombatSystem.applyDamage then
        local finalDamage = data.damage * data.damageMultiplier

        CombatSystem.applyDamage({
            target = targetEntity,
            source = data.owner,
            damage = finalDamage,
            damageType = data.damageType,
            projectile = projectileEntity
        })
    else
        -- Fallback: apply damage via blackboard
        if ai and ai.get_blackboard then
            local bb = ai:get_blackboard(targetEntity)
            if bb then
                local currentHealth = getBlackboardFloat(targetEntity, "health") or 100
                local finalDamage = data.damage * data.damageMultiplier
                setBlackboardFloat(targetEntity, "health", currentHealth - finalDamage)

                log_debug("Projectile dealt", finalDamage, "damage to", targetEntity)
            end
        end
    end
end

-- Handle bounce collision
function ProjectileSystem.handleBounce(projectileEntity, otherEntity, behavior)
    behavior.bounceCount = behavior.bounceCount + 1

    -- Reverse velocity with dampening
    behavior.velocity.x = -behavior.velocity.x * behavior.bounceDampening
    behavior.velocity.y = -behavior.velocity.y * behavior.bounceDampening

    -- Apply to physics
    if physics and globals.physicsWorld then
        physics.SetVelocity(globals.physicsWorld, projectileEntity,
            behavior.velocity.x, behavior.velocity.y)
    end

    -- Check max bounces
    if behavior.bounceCount >= behavior.maxBounces then
        local gameObj = component_cache.get(projectileEntity, GameObject)
        if gameObj and gameObj.projectileLifetime then
            gameObj.projectileLifetime.shouldDespawn = true
            gameObj.projectileLifetime.despawnReason = "bounce_depleted"
        end
    end
end

-- Handle explosion on impact
function ProjectileSystem.handleExplosion(projectileEntity, data, behavior)
    local transform = component_cache.get(projectileEntity, Transform)
    if not transform then return end

    local explosionRadius = behavior.explosionRadius or 100
    local explosionDamage = (data.damage * data.damageMultiplier) * (behavior.explosionDamageMult or 1.0)

    -- TODO: Query all entities in radius and apply AoE damage
    -- This requires spatial query system

    -- Emit explosion event
    publishLuaEvent("projectile_exploded", {
        projectile = projectileEntity,
        position = {x = transform.actualX, y = transform.actualY},
        radius = explosionRadius,
        damage = explosionDamage,
        owner = data.owner
    })

    -- Create visual effect (particle burst)
    if particle and particle.CreateParticle then
        for i = 1, 20 do
            local angle = (i / 20) * math.pi * 2
            particle.CreateParticle(
                Vec2(transform.actualX, transform.actualY),
                Vec2(8, 8),
                {
                    renderType = particle.ParticleRenderType.CIRCLE_FILLED,
                    velocity = Vec2(math.cos(angle) * 200, math.sin(angle) * 200),
                    lifespan = 0.5,
                    startColor = util.getColor("ORANGE"),
                    endColor = util.getColor("RED")
                }
            )
        end
    end
end

--[[
=============================================================================
PROJECTILE DESTRUCTION & POOLING
=============================================================================
]]--

function ProjectileSystem.destroy(entity)
    if not entity_cache.valid(entity) then return end

    local gameObj = component_cache.get(entity, GameObject)
    if gameObj and gameObj.projectileData then
        local data = gameObj.projectileData

        -- Call onDestroy callback
        if data.onDestroyCallback then
            data.onDestroyCallback(entity, data)
        end

        -- Emit destroy event
        publishLuaEvent("projectile_destroyed", {
            projectile = entity,
            owner = data.owner,
            reason = gameObj.projectileLifetime and gameObj.projectileLifetime.despawnReason
        })
    end

    -- Remove from active projectiles
    ProjectileSystem.active_projectiles[entity] = nil

    -- Return to pool or destroy
    if ProjectileSystem.shouldPool(entity) then
        ProjectileSystem.returnToPool(entity)
    else
        registry:destroy(entity)
    end

    log_debug("Destroyed projectile", entity)
end

-- Check if projectile should be pooled
function ProjectileSystem.shouldPool(entity)
    -- Pool if we have space (max 50 pooled projectiles)
    return #ProjectileSystem.pool < 50
end

-- Return projectile to pool for reuse
function ProjectileSystem.returnToPool(entity)
    -- Clean up components but keep entity alive
    local gameObj = component_cache.get(entity, GameObject)
    if gameObj then
        gameObj.projectileData = nil
        gameObj.projectileBehavior = nil
        gameObj.projectileLifetime = nil
    end

    -- Remove physics
    if physics and globals.physicsWorld then
        physics.DestroyPhysicsForEntity(globals.physicsWorld, entity)
    end

    -- Hide visually
    local transform = component_cache.get(entity, Transform)
    if transform then
        transform.actualX = -10000
        transform.actualY = -10000
    end

    table.insert(ProjectileSystem.pool, entity)
end

-- Get projectile from pool
function ProjectileSystem.getFromPool()
    if #ProjectileSystem.pool > 0 then
        return table.remove(ProjectileSystem.pool)
    end
    return entt_null
end

--[[
=============================================================================
HELPER FUNCTIONS
=============================================================================
]]--

-- Quick spawn for basic straight projectile
function ProjectileSystem.spawnBasic(x, y, angle, speed, damage, owner)
    return ProjectileSystem.spawn({
        position = {x = x, y = y},
        angle = angle,
        baseSpeed = speed,
        damage = damage,
        owner = owner,
        movementType = ProjectileSystem.MovementType.STRAIGHT,
        collisionBehavior = ProjectileSystem.CollisionBehavior.DESTROY,
        lifetime = 3.0,
        sprite = "projectile_basic.png" -- placeholder
    })
end

-- Spawn homing projectile
function ProjectileSystem.spawnHoming(x, y, target, speed, damage, owner)
    return ProjectileSystem.spawn({
        position = {x = x, y = y},
        homingTarget = target,
        baseSpeed = speed,
        homingStrength = 8.0,
        homingMaxSpeed = speed * 1.5,
        damage = damage,
        owner = owner,
        movementType = ProjectileSystem.MovementType.HOMING,
        collisionBehavior = ProjectileSystem.CollisionBehavior.DESTROY,
        lifetime = 5.0,
        sprite = "projectile_homing.png"
    })
end

-- Spawn arc projectile (affected by gravity)
function ProjectileSystem.spawnArc(x, y, angle, speed, damage, owner)
    return ProjectileSystem.spawn({
        position = {x = x, y = y},
        angle = angle,
        baseSpeed = speed,
        damage = damage,
        owner = owner,
        movementType = ProjectileSystem.MovementType.ARC,
        gravityScale = 1.5,
        collisionBehavior = ProjectileSystem.CollisionBehavior.EXPLODE,
        explosionRadius = 80,
        lifetime = 4.0,
        sprite = "projectile_grenade.png"
    })
end

--[[
=============================================================================
INITIALIZATION
=============================================================================
]]--

-- Initialize projectile system
function ProjectileSystem.init()
    -- Setup collision category for projectiles
    if physics and globals.physicsWorld then
        local world = globals.physicsWorld

        -- Add projectile collision category
        physics.set_collision_tags(world, {
            ProjectileSystem.COLLISION_CATEGORY,
            "player", "enemy", "terrain", "obstacle"
        })

        -- Enable collision between projectiles and enemies
        physics.enable_collision_between(world, ProjectileSystem.COLLISION_CATEGORY, "enemy")

        -- Disable collision between projectiles
        physics.disable_collision_between(world, ProjectileSystem.COLLISION_CATEGORY,
            ProjectileSystem.COLLISION_CATEGORY)

        log_debug("Projectile system initialized with physics")
    end

    -- Register projectile update on physics step timer
    if ProjectileSystem.use_physics_step_timer and timer then
        -- Use physics_step tag so this runs synchronously with physics updates
        ProjectileSystem.physics_step_timer_id = timer.every_physics_step(function(dt)
            ProjectileSystem.updateInternal(dt)
        end, "projectile_update")

        log_info("ProjectileSystem registered with physics step timer")
    else
        log_info("ProjectileSystem will use manual update() calls")
    end

    log_info("ProjectileSystem initialized")
end

-- Clean up all projectiles
function ProjectileSystem.cleanup()
    -- Cancel physics step timer if active
    if ProjectileSystem.physics_step_timer_id and timer then
        timer.cancel(ProjectileSystem.physics_step_timer_id)
        ProjectileSystem.physics_step_timer_id = nil
    end

    -- Destroy all active projectiles
    for entity, _ in pairs(ProjectileSystem.active_projectiles) do
        if entity_cache.valid(entity) then
            registry:destroy(entity)
        end
    end

    ProjectileSystem.active_projectiles = {}
    ProjectileSystem.pool = {}

    log_info("ProjectileSystem cleaned up")
end

return ProjectileSystem
