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
local CombatSystem = require("combat.combat_system")

---@diagnostic disable: undefined-global
-- Suppress warnings for runtime globals (registry, physics_manager)

-- Module table
local ProjectileSystem = {}

-- Active projectiles tracking
ProjectileSystem.active_projectiles = {}
ProjectileSystem.projectile_scripts = {}
ProjectileSystem.next_projectile_id = 1
ProjectileSystem.world_bounds = nil
ProjectileSystem.world_bounds_margin = nil
ProjectileSystem._playable_bounds = nil
ProjectileSystem.collisionTargetSet = { WORLD = true }
ProjectileSystem.collisionTargetList = { "WORLD" }
ProjectileSystem.collisionCallbacksRegistered = {}

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

local function getGlobalNumber(name, fallback)
    local value = rawget(_G, name)
    if type(value) == "number" then
        return value
    end
    return fallback
end

-- Gravity used when we are driving arc motion manually (pixels/sec^2)
local MANUAL_GRAVITY_ACCEL = 900

-- Returns the physics world for a projectile when physics is enabled on it
local function getPhysicsWorld(projectileScript)
    if not (projectileScript and projectileScript.usePhysics) then
        return nil
    end
    if not (physics and PhysicsManager and PhysicsManager.get_world) then
        return nil
    end
    return PhysicsManager.get_world("world")
end

function ProjectileSystem.refreshWorldBounds()
    local left = getGlobalNumber("SCREEN_BOUND_LEFT", 0)
    local top = getGlobalNumber("SCREEN_BOUND_TOP", 0)
    local right = getGlobalNumber("SCREEN_BOUND_RIGHT",
        globals and globals.screenWidth and globals.screenWidth() or 1280)
    local bottom = getGlobalNumber("SCREEN_BOUND_BOTTOM",
        globals and globals.screenHeight and globals.screenHeight() or 720)

    if right <= left or bottom <= top then
        ProjectileSystem.world_bounds = nil
        ProjectileSystem._playable_bounds = nil
        return
    end

    local wallThickness = getGlobalNumber("SCREEN_BOUND_THICKNESS",
        getGlobalNumber("PROJECTILE_WALL_THICKNESS", 30)) or 0

    ProjectileSystem.world_bounds = {
        left = left - wallThickness,
        right = right + wallThickness,
        top = top - wallThickness,
        bottom = bottom + wallThickness
    }
    ProjectileSystem.wall_thickness = wallThickness

    ProjectileSystem._playable_bounds = {
        minX = left,
        maxX = right,
        minY = top,
        maxY = bottom
    }
end

function ProjectileSystem.getPlayableBounds()
    if not ProjectileSystem._playable_bounds then
        ProjectileSystem.refreshWorldBounds()
    end
    return ProjectileSystem._playable_bounds
end

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
        hitCooldown = params.hitCooldown or params.rehitCooldown or 0.25, -- allow re-hits after this many seconds

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
        orbitCenterEntity = params.orbitCenterEntity,
        orbitRadius = params.orbitRadius or 100,
        orbitSpeed = params.orbitSpeed or 2.0, -- radians/sec
        orbitAngle = params.orbitAngle or 0,

        -- Gravity scale (for arc movement)
        gravityScale = params.gravityScale or 1.0,
        forceManualGravity = params.forceManualGravity or false,

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
    -- Give homing/orbital a longer default so they don't despawn immediately when travel paths are longer
    local function defaultLifetime()
        if params.movementType == ProjectileSystem.MovementType.HOMING then
            return 10.0
        elseif params.movementType == ProjectileSystem.MovementType.ORBITAL then
            return 12.0
        end
        return 5.0
    end

    return {
        -- Time-based despawn
        maxLifetime = params.maxLifetime or params.lifetime or defaultLifetime(), -- seconds
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

local function ensureCollisionCallbackForTarget(target)
    if not target then return end
    if ProjectileSystem.collisionCallbacksRegistered[target] then return end
    if not physics or not physics.on_pair_begin then return end

    local world = PhysicsManager and PhysicsManager.get_world and PhysicsManager.get_world("world") or nil
    if not world then return end

    physics.on_pair_begin(world, ProjectileSystem.COLLISION_CATEGORY, target, function(arb)
        if not arb or not arb.entities then return true end
        local a, b = arb:entities()
        if not a or not b then return true end

        local projectile, other = nil, nil
        if ProjectileSystem.active_projectiles[a] then
            projectile = a
            other = b
        elseif ProjectileSystem.active_projectiles[b] then
            projectile = b
            other = a
        end

        if not projectile then return true end

        ProjectileSystem.handleCollision(projectile, other)
        return true
    end)

    ProjectileSystem.collisionCallbacksRegistered[target] = true
end

local function registerCollisionTargets(targets)
    if not targets then return end

    for _, tag in ipairs(targets) do
        if tag and not ProjectileSystem.collisionTargetSet[tag] then
            ProjectileSystem.collisionTargetSet[tag] = true
            table.insert(ProjectileSystem.collisionTargetList, tag)
        end
        ensureCollisionCallbackForTarget(tag)
    end
end

local function ensureCollisionCategoryRegistered()
    if not PhysicsManager or not PhysicsManager.get_world then
        return
    end

    local world = PhysicsManager.get_world("world")
    if world and world.AddCollisionTag then
        world:AddCollisionTag(ProjectileSystem.COLLISION_CATEGORY)
    end
end

-- Steering helpers (for homing projectiles)
local function canUseSteering()
    return steering and steering.make_steerable and steering.seek_point and registry
end

local function ensureSteeringAgent(entity, behavior)
    if behavior._steeringReady then return true end
    if not canUseSteering() then
        return false
    end

    -- Map homing stats onto steering caps
    local maxSpeed = behavior.homingMaxSpeed or behavior.baseSpeed or 400
    local maxForce = maxSpeed * (behavior.homingStrength or 5.0) * 10 -- generous force so missiles turn fast
    local maxTurnRate = math.pi * 2.0
    local turnMul = 2.0

    steering.make_steerable(registry, entity, maxSpeed, maxForce, maxTurnRate, turnMul)

    behavior._steeringReady = true
    behavior._steeringMaxSpeed = maxSpeed
    return true
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

    local wantsPhysics = params.usePhysics ~= false

    -- Create new entity with transform
    local entity = create_transform_entity()

    -- Ensure projectiles live in the action phase only (match pickup setup in gameplay.lua)
    if add_state_tag and ACTION_STATE then
        add_state_tag(entity, ACTION_STATE)
    end
    if remove_default_state_tag then
        remove_default_state_tag(entity)
    end

    -- Increment projectile ID
    ProjectileSystem.next_projectile_id = ProjectileSystem.next_projectile_id + 1

    local sizeMultiplier = params.sizeMultiplier or 1.0
    local spriteSize = params.size or 8
    local width = spriteSize * sizeMultiplier
    local height = spriteSize * sizeMultiplier
    local spawnX = params.position.x
    local spawnY = params.position.y

    if params.positionIsCenter then
        spawnX = spawnX - width * 0.5
        spawnY = spawnY - height * 0.5
    end

    local startCenter = {
        x = spawnX + width * 0.5,
        y = spawnY + height * 0.5
    }

    -- Set transform properties (position stored as top-left in Transform)
    local transform = component_cache.get(entity, Transform)
    if transform then
        transform.actualX = spawnX
        transform.actualY = spawnY
        transform.actualW = width
        transform.actualH = height
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
        startPosition = startCenter,
        maxHits = params.maxHits
    })

    -- Initialize script table and store data BEFORE attach_ecs
    local ProjectileType = Node:extend()
    local projectileScript = ProjectileType {}

    -- Assign data to script table first
    projectileScript.projectileData = projectileData
    projectileScript.projectileBehavior = projectileBehavior
    projectileScript.projectileLifetime = projectileLifetime
    projectileScript.usePhysics = wantsPhysics

    -- NOW attach to entity (must be after data assignment)
    projectileScript:attach_ecs { create_new = false, existing_entity = entity }
    ProjectileSystem.projectile_scripts[entity] = projectileScript

    -- Setup physics body for projectile
    if wantsPhysics then
        ProjectileSystem.setupPhysics(entity, params, projectileScript)
    else
        projectileScript.usePhysics = false
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
function ProjectileSystem.setupPhysics(entity, params, projectileScript)
    projectileScript = projectileScript or ProjectileSystem.getProjectileScript(entity)

    -- Check if physics world is available
    local world = getPhysicsWorld(projectileScript) or (PhysicsManager and PhysicsManager.get_world and PhysicsManager.get_world("world")) or nil
    if not physics or not world then
        if projectileScript then
            projectileScript.usePhysics = false
        end
        log_debug("Physics world not available, projectile will not have collision")
        return
    end
    if projectileScript then
        projectileScript.usePhysics = true
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

    -- Configure physics sync:
    -- - Orbital and arc projectiles are driven kinematically, so Transform is the authority.
    -- - All others are physics-driven.
    local syncMode = physics.PhysicsSyncMode.AuthoritativePhysics
    if params.movementType == ProjectileSystem.MovementType.ORBITAL
        or params.movementType == ProjectileSystem.MovementType.ARC then
        syncMode = physics.PhysicsSyncMode.AuthoritativeTransform
    end
    physics.set_sync_mode(registry, entity, syncMode)

    -- Setup collision masks for this projectile entity
    local collisionTargets = resolveCollisionTargets(params)
    registerCollisionTargets(collisionTargets)
    if #collisionTargets > 0 then
        physics.enable_collision_between_many(
            world,
            ProjectileSystem.COLLISION_CATEGORY,
            collisionTargets
        )

        for _, tag in ipairs(collisionTargets) do
            physics.enable_collision_between_many(world, tag, { ProjectileSystem.COLLISION_CATEGORY })
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
    local world = getPhysicsWorld(projectileScript)
    local usePhysics = world ~= nil

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
        if usePhysics then
            physics.SetVelocity(world, entity, behavior.velocity.x, behavior.velocity.y)
        end

    elseif behavior.movementType == ProjectileSystem.MovementType.HOMING then
        -- Initialize with starting velocity
        local function applyVelocity(dx, dy)
            behavior.velocity.x = dx
            behavior.velocity.y = dy
            if usePhysics then
                physics.SetVelocity(world, entity, dx, dy)
            end
        end

        if params.direction then
            local speed = behavior.baseSpeed * (params.speedMultiplier or 1.0)
            applyVelocity(params.direction.x * speed, params.direction.y * speed)
        elseif params.angle then
            local speed = behavior.baseSpeed * (params.speedMultiplier or 1.0)
            applyVelocity(math.cos(params.angle) * speed, math.sin(params.angle) * speed)
        elseif behavior.homingTarget and entity_cache.valid(behavior.homingTarget) then
            local targetTransform = component_cache.get(behavior.homingTarget, Transform)
            if targetTransform and transform then
                local targetX = targetTransform.actualX + targetTransform.actualW * 0.5
                local targetY = targetTransform.actualY + targetTransform.actualH * 0.5
                local currentX = transform.actualX + transform.actualW * 0.5
                local currentY = transform.actualY + transform.actualH * 0.5
                local dx = targetX - currentX
                local dy = targetY - currentY
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist > 0 then
                    dx = dx / dist
                    dy = dy / dist
                    local speed = behavior.baseSpeed * (params.speedMultiplier or 1.0)
                    applyVelocity(dx * speed, dy * speed)
                end
            end
        end

    elseif behavior.movementType == ProjectileSystem.MovementType.ORBITAL then
        -- Set orbit center if not provided
        if not behavior.orbitCenter then
            behavior.orbitCenter = {
                x = transform.actualX + transform.actualW * 0.5,
                y = transform.actualY + transform.actualH * 0.5
            }
        end

        if transform then
            -- Place projectile on the orbit path at the current angle for immediate visible motion
            local angle = behavior.orbitAngle or 0
            local radius = behavior.orbitRadius or 0
            transform.actualX = (behavior.orbitCenter.x + math.cos(angle) * radius) - transform.actualW * 0.5
            transform.actualY = (behavior.orbitCenter.y + math.sin(angle) * radius) - transform.actualH * 0.5
            transform.actualR = angle + math.pi / 2
        end

    elseif behavior.movementType == ProjectileSystem.MovementType.ARC then
        -- Same as straight but with gravity enabled
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

        -- Apply velocity and let gravity influence via physics
        if usePhysics then
            physics.SetVelocity(world, entity, behavior.velocity.x, behavior.velocity.y)
        end

        -- If physics is disabled or we are forcing manual gravity, kick in a small downward impulse
        -- so manual arc projectiles immediately begin to fall.
        if (not usePhysics) or behavior.forceManualGravity then
            local kickDt = params.manualGravityKickDt or (1 / 60)
            behavior.velocity.y = behavior.velocity.y + (MANUAL_GRAVITY_ACCEL * behavior.gravityScale * kickDt)
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
        ProjectileSystem.updateStraightMovement(entity, dt, transform, behavior, projectileScript)

    elseif behavior.movementType == ProjectileSystem.MovementType.HOMING then
        ProjectileSystem.updateHomingMovement(entity, dt, transform, behavior, projectileScript)

    elseif behavior.movementType == ProjectileSystem.MovementType.ORBITAL then
        ProjectileSystem.updateOrbitalMovement(entity, dt, transform, behavior, projectileScript)

    elseif behavior.movementType == ProjectileSystem.MovementType.ARC then
        -- Arc movement handled by physics gravity
        ProjectileSystem.updateArcMovement(entity, dt, transform, behavior, projectileScript)

    elseif behavior.movementType == ProjectileSystem.MovementType.CUSTOM then
        if behavior.customUpdate then
            behavior.customUpdate(entity, dt, transform, behavior, data)
        end
    end

    -- Update distance traveled
    if lifetime.maxDistance and lifetime.startPosition then
        local centerX = transform.actualX + transform.actualW * 0.5
        local centerY = transform.actualY + transform.actualH * 0.5
        local dx = centerX - lifetime.startPosition.x
        local dy = centerY - lifetime.startPosition.y
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

    if ProjectileSystem.checkWorldBounds(entity, projectileScript, transform) then
        return projectileScript.projectileLifetime.shouldDespawn
    end

    return false
end

function ProjectileSystem.checkWorldBounds(entity, projectileScript, transform)
    local playable = ProjectileSystem.getPlayableBounds()
    if not playable then return false end

    local width = transform.actualW or 0
    local height = transform.actualH or 0
    local leftEdge = transform.actualX
    local rightEdge = leftEdge + width
    local topEdge = transform.actualY
    local bottomEdge = topEdge + height

    local minX = math.min(playable.minX, playable.maxX)
    local maxX = math.max(playable.minX, playable.maxX)
    local minY = math.min(playable.minY, playable.maxY)
    local maxY = math.max(playable.minY, playable.maxY)

    local hitLeft = leftEdge <= minX
    local hitRight = rightEdge >= maxX
    local hitTop = topEdge <= minY
    local hitBottom = bottomEdge >= maxY

    if not (hitLeft or hitRight or hitTop or hitBottom) then
        return false
    end

    local collisionInfo = {
        hitLeft = hitLeft,
        hitRight = hitRight,
        hitTop = hitTop,
        hitBottom = hitBottom,
        bounds = {
            minX = minX,
            maxX = maxX,
            minY = minY,
            maxY = maxY
        }
    }

    return ProjectileSystem.handleWorldBoundaryCollision(entity, projectileScript, transform, collisionInfo)
end

function ProjectileSystem.handleWorldBoundaryCollision(entity, projectileScript, transform, collisionInfo)
    local behavior = projectileScript.projectileBehavior
    local lifetime = projectileScript.projectileLifetime
    local data = projectileScript.projectileData

    local bounds = collisionInfo.bounds
    if collisionInfo.hitLeft then
        transform.actualX = bounds.minX
    elseif collisionInfo.hitRight then
        transform.actualX = bounds.maxX - (transform.actualW or 0)
    end
    if collisionInfo.hitTop then
        transform.actualY = bounds.minY
    elseif collisionInfo.hitBottom then
        transform.actualY = bounds.maxY - (transform.actualH or 0)
    end

    local collisionType = behavior.collisionBehavior

    if collisionType == ProjectileSystem.CollisionBehavior.BOUNCE then
        if collisionInfo.hitLeft or collisionInfo.hitRight then
            behavior.velocity.x = -behavior.velocity.x * behavior.bounceDampening
        end
        if collisionInfo.hitTop or collisionInfo.hitBottom then
            behavior.velocity.y = -behavior.velocity.y * behavior.bounceDampening
        end

        behavior.bounceCount = (behavior.bounceCount or 0) + 1

        local world = getPhysicsWorld(projectileScript)
        if world then
            physics.SetVelocity(world, entity, behavior.velocity.x, behavior.velocity.y)
        end

        if behavior.bounceCount >= behavior.maxBounces then
            lifetime.shouldDespawn = true
            lifetime.despawnReason = "bounce_depleted"
            return true
        end

        return false
    end

    if collisionType == ProjectileSystem.CollisionBehavior.EXPLODE then
        ProjectileSystem.handleExplosion(entity, data, behavior)
    end

    lifetime.shouldDespawn = true
    lifetime.despawnReason = "world_bounds"
    return true
end

--[[
=============================================================================
MOVEMENT PATTERNS
=============================================================================
]]--

local function getVelocityXY(world, entity, fallbackVelocity, usePhysics)
    if usePhysics and physics and world then
        local vel = physics.GetVelocity(world, entity)
        if vel then
            return vel.x or 0, vel.y or 0
        end
    end

    if fallbackVelocity then
        return fallbackVelocity.x or 0, fallbackVelocity.y or 0
    end

    return 0, 0
end

function ProjectileSystem.updateStraightMovement(entity, dt, transform, behavior, projectileScript)
    -- Physics-driven: Let Chipmunk2D handle movement via velocity
    -- Rotation is updated to face direction for visual purposes only
    local world = getPhysicsWorld(projectileScript)
    local usePhysics = world ~= nil
    if usePhysics then
        -- Sync velocity from physics (in case physics modified it)
        local vx, vy = getVelocityXY(world, entity, behavior.velocity, usePhysics)
        behavior.velocity.x = vx
        behavior.velocity.y = vy

        -- Update rotation to face direction (visual only, physics rotation locked)
        if vx ~= 0 or vy ~= 0 then
            transform.visualR = math.atan(vy, vx)
        end
        return
    end

    -- Fallback: Manual movement if physics disabled (testing only)
    local vx = behavior.velocity.x or 0
    local vy = behavior.velocity.y or 0
    transform.actualX = transform.actualX + vx * dt
    transform.actualY = transform.actualY + vy * dt

    -- Update rotation to face direction
    if vx ~= 0 or vy ~= 0 then
        transform.actualR = math.atan(vy, vx)
    end
end

function ProjectileSystem.updateHomingMovement(entity, dt, transform, behavior, projectileScript)
    -- Get physics world once at function start
    local world = getPhysicsWorld(projectileScript)
    local usePhysics = world ~= nil

    -- Check if target is valid
    if not behavior.homingTarget or not entity_cache.valid(behavior.homingTarget) then
        -- Fall back to straight movement
        ProjectileSystem.updateStraightMovement(entity, dt, transform, behavior, projectileScript)
        return
    end

    -- Get target position
    local targetTransform = component_cache.get(behavior.homingTarget, Transform)
    if not targetTransform then
        ProjectileSystem.updateStraightMovement(entity, dt, transform, behavior, projectileScript)
        return
    end

    local targetX = targetTransform.actualX + targetTransform.actualW / 2
    local targetY = targetTransform.actualY + targetTransform.actualH / 2

    -- If steering is available, drive homing via steering behaviors (matches gameplay.lua usage)
    if ensureSteeringAgent(entity, behavior) then
        steering.seek_point(registry, entity, { x = targetX, y = targetY }, 1.0, 30)

        -- if usePhysics then
        --     local vx, vy = getVelocityXY(world, entity, behavior.velocity, usePhysics)
        --     local speed = math.sqrt(vx * vx + vy * vy)
        --     local maxSpeed = behavior._steeringMaxSpeed or behavior.homingMaxSpeed or behavior.baseSpeed or speed

        --     if speed > 0 then
        --         -- Clamp to configured max speed so steering doesn't overshoot
        --         if maxSpeed and speed > maxSpeed then
        --             local scale = maxSpeed / speed
        --             vx = vx * scale
        --             vy = vy * scale
        --             physics.SetVelocity(world, entity, vx, vy)
        --         end

        --         behavior.velocity.x = vx
        --         behavior.velocity.y = vy
        --         transform.visualR = math.atan(vy, vx)
        --     end
        -- end

        return
    end

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
        local currentVelX, currentVelY = getVelocityXY(world, entity, behavior.velocity, usePhysics)

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
        if usePhysics then
            physics.SetVelocity(world, entity, desiredVelX, desiredVelY)

            -- Update visual rotation to face direction
            if desiredVelX ~= 0 or desiredVelY ~= 0 then
                transform.visualR = math.atan(desiredVelY, desiredVelX)
            end
        else
            -- Fallback: Manual movement
            transform.actualX = transform.actualX + desiredVelX * dt
            transform.actualY = transform.actualY + desiredVelY * dt
            transform.actualR = math.atan(desiredVelY, desiredVelX)
        end
    else
        -- Target reached or very close, maintain current velocity
        if usePhysics then
            local vx, vy = getVelocityXY(world, entity, behavior.velocity, usePhysics)
            if vx ~= 0 or vy ~= 0 then
                transform.visualR = math.atan(vy, vx)
            end
        end
    end
end

function ProjectileSystem.updateOrbitalMovement(entity, dt, transform, behavior, projectileScript)
    -- Get physics world once at function start
    local world = getPhysicsWorld(projectileScript)
    local usePhysics = world ~= nil

    -- Ensure we always have a center point (fallback to current position)
    if not behavior.orbitCenter then
        if transform then
            behavior.orbitCenter = {
                x = transform.actualX + (transform.actualW or 0) * 0.5,
                y = transform.actualY + (transform.actualH or 0) * 0.5
            }
        else
            return
        end
    end

    if behavior.orbitCenterEntity and entity_cache.valid(behavior.orbitCenterEntity) then
        local centerTransform = component_cache.get(behavior.orbitCenterEntity, Transform)
        if centerTransform then
            behavior.orbitCenter = behavior.orbitCenter or {}
            behavior.orbitCenter.x = centerTransform.actualX + (centerTransform.actualW or 0) * 0.5
            behavior.orbitCenter.y = centerTransform.actualY + (centerTransform.actualH or 0) * 0.5
        end
    end

    -- Update orbit angle
    behavior.orbitAngle = behavior.orbitAngle + behavior.orbitSpeed * dt

    -- Calculate position on orbit
    local centerX = behavior.orbitCenter.x
    local centerY = behavior.orbitCenter.y
    local targetX = centerX + math.cos(behavior.orbitAngle) * behavior.orbitRadius
    local targetY = centerY + math.sin(behavior.orbitAngle) * behavior.orbitRadius
    local tangentSpeed = (behavior.orbitSpeed or 0) * (behavior.orbitRadius or 0)
    local velocityX = -math.sin(behavior.orbitAngle) * tangentSpeed
    local velocityY = math.cos(behavior.orbitAngle) * tangentSpeed

    -- Always place the transform along the orbit for visuals
    if transform then
        transform.actualX = targetX - transform.actualW / 2
        transform.actualY = targetY - transform.actualH / 2
        transform.actualR = behavior.orbitAngle + math.pi / 2
        transform.visualR = transform.actualR
    end

    if usePhysics then
        -- Keep the physics body in lockstep with the transform for collision.
        physics.SetPosition(world, entity, { x = targetX, y = targetY })
        physics.SetVelocity(world, entity, velocityX, velocityY)
    else
        -- Fallback: record velocity for any consumers
        behavior.velocity.x = velocityX
        behavior.velocity.y = velocityY
    end
end

function ProjectileSystem.updateArcMovement(entity, dt, transform, behavior, projectileScript)
    -- Manual integration for consistent parabolic arcs regardless of world gravity.
    behavior.velocity.y = behavior.velocity.y + (MANUAL_GRAVITY_ACCEL * behavior.gravityScale * dt)
    transform.actualX = transform.actualX + behavior.velocity.x * dt
    transform.actualY = transform.actualY + behavior.velocity.y * dt
    transform.actualR = math.atan(behavior.velocity.y, behavior.velocity.x)
    transform.visualR = transform.actualR

    local world = getPhysicsWorld(projectileScript)
    if world then
        -- Keep physics body aligned with our kinematic integration for collision.
        local centerX = transform.actualX + (transform.actualW or 0) * 0.5
        local centerY = transform.actualY + (transform.actualH or 0) * 0.5
        physics.SetPosition(world, entity, { x = centerX, y = centerY })
        physics.SetVelocity(world, entity, behavior.velocity.x, behavior.velocity.y)
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
    if not entity_cache.valid(projectileEntity) then
        return
    end

    local projectileScript = ProjectileSystem.getProjectileScript(projectileEntity)
    if not projectileScript or not projectileScript.projectileData then return end

    local data = projectileScript.projectileData
    local behavior = projectileScript.projectileBehavior
    local lifetime = projectileScript.projectileLifetime

    local otherIsValid = otherEntity and otherEntity ~= entt_null and entity_cache.valid(otherEntity)
    local targetGameObject = otherIsValid and component_cache.get(otherEntity, GameObject) or nil
    local isDamageable = targetGameObject ~= nil
    local now = os.clock()

    -- Check if already hit this entity (for piercing) – only track damageable targets
    if isDamageable and otherIsValid then
        local lastHitAt = data.hitEntities[otherEntity]
        if lastHitAt and (now - lastHitAt) < (data.hitCooldown or 0) then
            return
        end
        data.hitEntities[otherEntity] = now
    end

    lifetime.hitCount = lifetime.hitCount + 1

    -- Apply damage to other entity
    if isDamageable then
        ProjectileSystem.applyDamage(projectileEntity, otherEntity, data, targetGameObject)
    end

    -- Call onHit callback
    if isDamageable and data.onHitCallback then
        data.onHitCallback(projectileEntity, otherEntity, data)
    end

    -- Emit hit event
    if isDamageable then
        signal.emit("projectile_hit", projectileEntity, {
            target = otherEntity,
            owner = data.owner,
            damage = data.damage * data.damageMultiplier
        })
    end

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
        ProjectileSystem.handleBounce(projectileEntity, otherEntity, behavior, projectileScript)

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

    local function combatActorForEntity(eid)
        if not eid or eid == entt_null or not entity_cache.valid(eid) then
            return nil
        end
        local script = getScriptTableFromEntityID(eid)
        return script and script.combatTable or nil
    end

    local ctx = rawget(_G, "combat_context")
    local targetCombatActor = combatActorForEntity(targetEntity)
    local sourceCombatActor = combatActorForEntity(data.owner)

    -- Use combat system if available
    if CombatSystem and CombatSystem.Game and CombatSystem.Game.Effects and ctx and targetCombatActor then
        local finalDamage = data.damage * data.damageMultiplier
        local dmgType = data.damageType or "physical"

        CombatSystem.Game.Effects.deal_damage {
            components = { { type = dmgType, amount = finalDamage } },
            tags = { projectile = true }
        }(ctx, sourceCombatActor or targetCombatActor, targetCombatActor)
        return
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
function ProjectileSystem.handleBounce(projectileEntity, otherEntity, behavior, projectileScript)
    projectileScript = projectileScript or ProjectileSystem.getProjectileScript(projectileEntity)
    behavior.bounceCount = behavior.bounceCount + 1

    -- Reverse velocity with dampening
    behavior.velocity.x = -behavior.velocity.x * behavior.bounceDampening
    behavior.velocity.y = -behavior.velocity.y * behavior.bounceDampening

    -- Apply to physics
    local world = getPhysicsWorld(projectileScript)
    if world then
        physics.SetVelocity(world, projectileEntity,
            behavior.velocity.x, behavior.velocity.y)
    end

    -- Check max bounces
    if behavior.bounceCount >= behavior.maxBounces then
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
    local centerX = transform.actualX + transform.actualW * 0.5
    local centerY = transform.actualY + transform.actualH * 0.5

    -- TODO: Query all entities in radius and apply AoE damage
    -- This requires spatial query system

    -- Emit explosion event
    signal.emit("projectile_exploded", projectileEntity, {
        position = {x = centerX, y = centerY},
        radius = explosionRadius,
        damage = explosionDamage,
        owner = data.owner
    })

    -- Create visual effect (particle burst)
    if particle and particle.CreateParticle then
        for i = 1, 20 do
            local angle = (i / 20) * math.pi * 2
            particle.CreateParticle(
                Vec2(centerX, centerY),
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
        positionIsCenter = true,
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
        positionIsCenter = true,
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
        positionIsCenter = true,
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
    ProjectileSystem.collisionTargetSet = { WORLD = true }
    ProjectileSystem.collisionTargetList = { "WORLD" }
    ProjectileSystem.collisionCallbacksRegistered = {}
    -- Track last physics tick time for dt calculation
    ProjectileSystem._lastUpdateTime = os.clock()
    ProjectileSystem.refreshWorldBounds()
    ensureCollisionCategoryRegistered()

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
    ProjectileSystem.world_bounds = nil
    ProjectileSystem._playable_bounds = nil
    ProjectileSystem.collisionTargetSet = { WORLD = true }
    ProjectileSystem.collisionTargetList = { "WORLD" }
    ProjectileSystem.collisionCallbacksRegistered = {}

    log_debug("ProjectileSystem cleaned up")
end

return ProjectileSystem
