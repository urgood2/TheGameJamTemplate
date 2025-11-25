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
local signal = require("external.hump.signal")
local Node = require("monobehavior.behavior_script_v2")

---@diagnostic disable: undefined-global
-- Suppress warnings for runtime globals (registry, physics_manager)

-- Module table
local ProjectileSystem = {}

-- Active projectiles tracking
ProjectileSystem.active_projectiles = {}
ProjectileSystem.projectile_scripts = {}
ProjectileSystem.next_projectile_id = 1

-- Physics step timer handle
ProjectileSystem.physics_step_timer_tag = "projectile_system_update"
ProjectileSystem.physics_step_timer_active = false
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

-- Helper: cached access to projectile script tables
local function addIfNotPresent(list, seen, value)
    if not value or seen[value] then return end
    seen[value] = true
    list[#list + 1] = value
end

--- Returns the script table for a projectile entity, using a local cache for stability.
--- @param entity integer
--- @return table|nil
function ProjectileSystem.getProjectileScript(entity)
    if ProjectileSystem.projectile_scripts[entity] then
        return ProjectileSystem.projectile_scripts[entity]
    end

    local script = getScriptTableFromEntityID(entity)
    if script then
        ProjectileSystem.projectile_scripts[entity] = script
    end
    return script
end

local function resolveCollisionTargets(params)
    local targets = {}
    local seen = {}

    if params.collideWithTags then
        for _, tag in ipairs(params.collideWithTags) do
            addIfNotPresent(targets, seen, tag)
        end
        return targets
    end

    local targetTag = params.targetCollisionTag or "enemy"
    addIfNotPresent(targets, seen, targetTag)

    local collideWithWorld = params.collideWithWorld
    if collideWithWorld == nil then
        collideWithWorld = true
    end

    if collideWithWorld then
        addIfNotPresent(targets, seen, "WORLD")
    end

    return targets
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

    -- Create new entity with transform
    local entity = create_transform_entity()

    -- Add default state tag so projectile renders
    if add_default_state_tag then
        add_default_state_tag(entity)
    end

    -- Increment projectile ID
    ProjectileSystem.next_projectile_id = ProjectileSystem.next_projectile_id + 1

    -- Set transform properties
    local transform = component_cache.get(entity, Transform)
    if transform then
        transform.actualX = params.position.x
        transform.actualY = params.position.y
        transform.actualW = (params.size or 8) * (params.sizeMultiplier or 1.0)
        transform.actualH = (params.size or 8) * (params.sizeMultiplier or 1.0)
        transform.actualR = params.rotation or 0

        -- Create visual representation
        local spriteToUse = params.sprite or "b1761.png"
        animation_system.setupAnimatedObjectOnEntity(
            entity,
            spriteToUse,
            true,  -- use animation
            nil,   -- no custom offset
            params.shadow or false
        )

        -- Resize to fit transform
        animation_system.resizeAnimationObjectsInEntityToFit(
            entity,
            transform.actualW,
            transform.actualH
        )
    else
        log_error("Failed to get Transform component for projectile entity")
        registry:destroy(entity)
        return entt_null
    end

    -- Create projectile components
    local projectileData = ProjectileSystem.createProjectileData(params)
    local projectileBehavior = ProjectileSystem.createProjectileBehavior(params)
    local projectileLifetime = ProjectileSystem.createProjectileLifetime({
        maxLifetime = params.lifetime or 5.0,
        maxDistance = params.maxDistance,
        startPosition = {x = params.position.x, y = params.position.y},
        maxHits = params.maxHits
    })

    -- Initialize script table and store data BEFORE attach_ecs
    local ProjectileType = Node:extend()
    local projectileScript = ProjectileType {}

    -- Assign data to script table first
    projectileScript.projectileData = projectileData
    projectileScript.projectileBehavior = projectileBehavior
    projectileScript.projectileLifetime = projectileLifetime

    -- NOW attach to entity (must be after data assignment)
    projectileScript:attach_ecs { create_new = false, existing_entity = entity }
    ProjectileSystem.projectile_scripts[entity] = projectileScript

    -- Setup physics body for projectile
    if params.usePhysics ~= false then
        ProjectileSystem.setupPhysics(entity, params)
    end

    -- Calculate initial velocity based on movement type
    -- Pass projectileScript directly instead of relying on getScriptTableFromEntityID
    ProjectileSystem.initializeMovement(entity, params, projectileScript)

    -- Add to active projectiles tracking
    ProjectileSystem.active_projectiles[entity] = true

    -- Call onSpawn callback if provided
    if projectileData.onSpawnCallback then
        projectileData.onSpawnCallback(entity, params)
    end

    -- Emit spawn event for wand system
    if params.emitEvents ~= false then
        signal.emit("projectile_spawned", entity, {
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
    local world = PhysicsManager.get_world("world")
    if not physics or not world then
        log_debug("Physics world not available, projectile will not have collision")
        return
    end
    local transform = component_cache.get(entity, Transform)

    -- Determine shape and config
    local shapeType = params.shapeType or "circle"
    local isSensor = (params.collisionBehavior == ProjectileSystem.CollisionBehavior.PASS_THROUGH)

    -- Create physics body using correct signature
    local config = {
        shape = shapeType,
        tag = ProjectileSystem.COLLISION_CATEGORY,
        sensor = isSensor,
        density = params.density or 1.0
    }

    -- Use globals that are available in the runtime environment
    physics.create_physics_for_transform(
        registry, -- global
        physics_manager_instance, -- global
        entity,
        "world",
        config
    )

    -- Set additional physics properties
    -- Make it a bullet for high-speed collision detection
    physics.SetBullet(world, entity, true)

    -- Set friction and restitution
    physics.SetFriction(world, entity, params.friction or 0.0)
    physics.SetRestitution(world, entity, params.restitution or 0.5)

    -- Disable rotation if needed
    if params.fixedRotation ~= false then
        physics.SetFixedRotation(world, entity, true)
    end

    -- Note: Gravity is set globally per world, not per-entity
    -- Arc projectiles will use the world's gravity automatically

    -- Configure physics sync: Make physics authoritative for projectiles (matches gameplay.lua)
    physics.set_sync_mode(registry, entity, physics.PhysicsSyncMode.AuthoritativePhysics)

    -- Setup collision masks for this projectile entity
    local collisionTargets = resolveCollisionTargets(params)
    if #collisionTargets > 0 then
        physics.enable_collision_between_many(
            world,
            ProjectileSystem.COLLISION_CATEGORY,
            collisionTargets
        )
        physics.update_collision_masks_for(world, ProjectileSystem.COLLISION_CATEGORY, collisionTargets)

        for _, tag in ipairs(collisionTargets) do
            physics.enable_collision_between_many(world, tag, { ProjectileSystem.COLLISION_CATEGORY })
            physics.update_collision_masks_for(world, tag, { ProjectileSystem.COLLISION_CATEGORY })
        end
    end

    -- Setup collision callback
    ProjectileSystem.setupCollisionCallback(entity)
end

-- Initialize movement based on movement type
function ProjectileSystem.initializeMovement(entity, params, projectileScript)
    -- Use provided script or retrieve it (for backward compatibility)
    projectileScript = projectileScript or ProjectileSystem.getProjectileScript(entity)

    if not projectileScript then
        log_error("initializeMovement: No script table found for entity " .. tostring(entity))
        return
    end

    local behavior = projectileScript.projectileBehavior
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
        local world = PhysicsManager.get_world("world")
        if physics and world then
            physics.SetVelocity(world, entity, behavior.velocity.x, behavior.velocity.y)
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
            local projectileScript = ProjectileSystem.getProjectileScript(entity)
            if not projectileScript then
                toRemove[#toRemove + 1] = entity
            else
                local shouldDestroy = false
                if projectileScript.projectileLifetime
                    and projectileScript.projectileLifetime.shouldDespawn then
                    shouldDestroy = true
                else
                    shouldDestroy = ProjectileSystem.updateProjectile(entity, dt, projectileScript)
                end

                if shouldDestroy then
                    toRemove[#toRemove + 1] = entity
                end
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
function ProjectileSystem.updateProjectile(entity, dt, projectileScript)
    projectileScript = projectileScript or ProjectileSystem.getProjectileScript(entity)
    if not projectileScript then return true end

    local data = projectileScript.projectileData
    local behavior = projectileScript.projectileBehavior
    local lifetime = projectileScript.projectileLifetime
    local transform = component_cache.get(entity, Transform)

    if not data or not behavior or not lifetime or not transform then
        if lifetime then
            lifetime.shouldDespawn = true
            lifetime.despawnReason = "missing_components"
        end
        return true
    end

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
    local world = PhysicsManager.get_world("world")
    if physics and world then
        -- Sync velocity from physics (in case physics modified it)
        local vx, vy = physics.GetVelocity(world, entity)
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
    -- Get physics world once at function start
    local world = PhysicsManager.get_world("world")

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
        if physics and world then
            currentVelX, currentVelY = physics.GetVelocity(world, entity)
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
        if physics and world then
            physics.SetVelocity(world, entity, desiredVelX, desiredVelY)

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
        if physics and world then
            local vx, vy = physics.GetVelocity(world, entity)
            if vx ~= 0 or vy ~= 0 then
                transform.visualR = math.atan2(vy, vx)
            end
        end
    end
end

function ProjectileSystem.updateOrbitalMovement(entity, dt, transform, behavior)
    -- Get physics world once at function start
    local world = PhysicsManager.get_world("world")

    -- Update orbit angle
    behavior.orbitAngle = behavior.orbitAngle + behavior.orbitSpeed * dt

    -- Calculate position on orbit
    local centerX = behavior.orbitCenter.x
    local centerY = behavior.orbitCenter.y

    local targetX = centerX + math.cos(behavior.orbitAngle) * behavior.orbitRadius
    local targetY = centerY + math.sin(behavior.orbitAngle) * behavior.orbitRadius

    -- Physics-driven: Calculate velocity to reach target position
    if physics and world then
        -- Get current position from transform (updated by physics sync)
        local currentX = transform.actualX + transform.actualW / 2
        local currentY = transform.actualY + transform.actualH / 2

        -- Calculate velocity needed to reach target (simple proportional control)
        local velocityX = (targetX - currentX) / dt
        local velocityY = (targetY - currentY) / dt

        -- Apply velocity to physics body
        physics.SetVelocity(world, entity, velocityX, velocityY)

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
    -- Get physics world once at function start
    local world = PhysicsManager.get_world("world")

    -- Physics-driven: Chipmunk2D handles gravity automatically
    if physics and world then
        -- Sync velocity from physics (gravity is applied by Chipmunk2D)
        local vx, vy = physics.GetVelocity(world, entity)
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

    local projectileScript = ProjectileSystem.getProjectileScript(projectileEntity)
    if not projectileScript or not projectileScript.projectileData then return end

    local data = projectileScript.projectileData
    local behavior = projectileScript.projectileBehavior
    local lifetime = projectileScript.projectileLifetime

    local targetGameObject = component_cache.get(otherEntity, GameObject)
    local isDamageable = targetGameObject ~= nil

    -- Check if already hit this entity (for piercing) – only track damageable targets
    if isDamageable and data.hitEntities[otherEntity] then
        return
    end

    if isDamageable then
        data.hitEntities[otherEntity] = true
    end

    lifetime.hitCount = lifetime.hitCount + 1

    -- Apply damage to other entity
    ProjectileSystem.applyDamage(projectileEntity, otherEntity, data, targetGameObject)

    -- Call onHit callback
    if data.onHitCallback then
        data.onHitCallback(projectileEntity, otherEntity, data)
    end

    -- Emit hit event
    signal.emit("projectile_hit", projectileEntity, {
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
function ProjectileSystem.applyDamage(projectileEntity, targetEntity, data, precomputedGameObject)
    -- Check if target has health
    local targetGameObj = precomputedGameObject or component_cache.get(targetEntity, GameObject)
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
    local world = PhysicsManager.get_world("world")
    if physics and world then
        physics.SetVelocity(world, projectileEntity,
            behavior.velocity.x, behavior.velocity.y)
    end

    -- Check max bounces
    if behavior.bounceCount >= behavior.maxBounces then
        local projectileScript = ProjectileSystem.getProjectileScript(projectileEntity)
        if projectileScript and projectileScript.projectileLifetime then
            projectileScript.projectileLifetime.shouldDespawn = true
            projectileScript.projectileLifetime.despawnReason = "bounce_depleted"
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
    signal.emit("projectile_exploded", projectileEntity, {
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
    if not entity then return end

    local projectileScript = ProjectileSystem.getProjectileScript(entity)
    if projectileScript and projectileScript.projectileData then
        local data = projectileScript.projectileData

        -- Call onDestroy callback
        if data.onDestroyCallback then
            data.onDestroyCallback(entity, data)
        end

        -- Emit destroy event
        signal.emit("projectile_destroyed", entity, {
            owner = data.owner,
            reason = projectileScript.projectileLifetime and projectileScript.projectileLifetime.despawnReason
        })
    end

    -- Remove from active projectiles
    ProjectileSystem.active_projectiles[entity] = nil
    ProjectileSystem.projectile_scripts[entity] = nil

    -- Simply destroy the entity if it still exists
    if entity_cache.valid(entity) then
        registry:destroy(entity)
    end

    log_debug("Destroyed projectile", entity)
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
    -- Track last physics tick time for dt calculation
    ProjectileSystem._lastUpdateTime = os.clock()

    -- Register projectile update on physics step timer
    if ProjectileSystem.use_physics_step_timer and timer then
        -- Check if timer has every_physics_step function
        if timer.every_physics_step then
            -- Use physics_step tag so this runs synchronously with physics updates
            -- Note: timer.every_physics_step callbacks do NOT receive dt parameter
            timer.every_physics_step(function()
                -- Calculate dt based on time since last update
                local now = os.clock()
                local dt = now - ProjectileSystem._lastUpdateTime
                ProjectileSystem._lastUpdateTime = now

                ProjectileSystem.updateInternal(dt)
            end, ProjectileSystem.physics_step_timer_tag)
            ProjectileSystem.physics_step_timer_active = true

            log_debug("ProjectileSystem registered with physics step timer")
        else
            -- Fallback: Use regular timer if every_physics_step doesn't exist
            log_debug("timer.every_physics_step() not available, falling back to manual updates")
            ProjectileSystem.use_physics_step_timer = false
            log_debug("ProjectileSystem will use manual update() calls")
        end
    else
        log_debug("ProjectileSystem will use manual update() calls")
    end

    log_debug("ProjectileSystem initialized")
end

-- Clean up all projectiles
function ProjectileSystem.cleanup()
    -- Cancel physics step timer if active
    if ProjectileSystem.physics_step_timer_active and timer and timer.cancel_physics_step then
        timer.cancel_physics_step(ProjectileSystem.physics_step_timer_tag)
        ProjectileSystem.physics_step_timer_active = false
    end

    -- Destroy all active projectiles
    for entity, _ in pairs(ProjectileSystem.active_projectiles) do
        if entity_cache.valid(entity) then
            registry:destroy(entity)
        end
        ProjectileSystem.projectile_scripts[entity] = nil
    end

    ProjectileSystem.active_projectiles = {}
    ProjectileSystem.projectile_scripts = {}

    log_debug("ProjectileSystem cleaned up")
end

return ProjectileSystem
