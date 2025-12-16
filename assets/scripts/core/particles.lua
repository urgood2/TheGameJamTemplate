-- assets/scripts/core/particles.lua
--[[
================================================================================
PARTICLE BUILDER - Fluent API for Particle Effects
================================================================================
Reduces verbose particle.CreateParticle() calls to composable recipes.

Usage:
    local Particles = require("core.particles")

    -- Simple burst
    local spark = Particles.define()
        :shape("circle")
        :size(4, 8)
        :color("orange", "red")
        :fade()
        :lifespan(0.3)

    spark:burst(10):at(x, y)

    -- Mixed particles (composite effects)
    local fire = Particles.define():shape("circle"):size(4,8):color("orange","red"):fade()
    local smoke = Particles.define():shape("circle"):size(8,16):color("gray"):fade():velocity(0,-50)

    Particles.mix({ fire, smoke })
        :burst(10, 5)  -- 10 fire particles, 5 smoke particles
        :at(x, y)

    -- Streaming mixed particles
    local fireStream = Particles.mix({ fire, smoke })
        :burst(3, 2)  -- 3 fire, 2 smoke per emission
        :at(x, y)
        :stream()
        :every(0.1)   -- Emit every 0.1 seconds

    -- Update in game loop
    fireStream:update(dt)

Design:
    - Recipe: Immutable particle definition (what it looks like, how it behaves)
    - Emission: Spawn configuration (where, when, how many)
    - MixedEmission: Combines multiple recipes in one emission
    - Handle: Controller for streams (stop, pause, resume)
]]

-- Singleton guard
if _G.__PARTICLES_BUILDER__ then
    return _G.__PARTICLES_BUILDER__
end

local Particles = {}

--------------------------------------------------------------------------------
-- RECIPE
--------------------------------------------------------------------------------

local RecipeMethods = {}
RecipeMethods.__index = RecipeMethods

--- Set particle shape
--- @param shapeType string "circle"|"rect"|"line"|"sprite"
--- @param spriteId string? Sprite ID if shapeType is "sprite"
--- @return self
function RecipeMethods:shape(shapeType, spriteId)
    self._config.shape = shapeType
    if spriteId then
        self._config.spriteId = spriteId
    end
    return self
end

--- Set particle size (single value or random range)
--- @param minOrFixed number Min size, or fixed size if max not provided
--- @param max number? Max size for random range
--- @return self
function RecipeMethods:size(minOrFixed, max)
    self._config.sizeMin = minOrFixed
    self._config.sizeMax = max or minOrFixed
    return self
end

--- Set particle color (start/end for interpolation)
--- @param startColor string|table Color name or {r,g,b,a}
--- @param endColor string|table? End color (defaults to startColor)
--- @return self
function RecipeMethods:color(startColor, endColor)
    self._config.startColor = startColor
    self._config.endColor = endColor or startColor
    return self
end

--- Set particle lifespan (single value or random range)
--- @param minOrFixed number Min lifespan in seconds, or fixed if max not provided
--- @param max number? Max lifespan for random range
--- @return self
function RecipeMethods:lifespan(minOrFixed, max)
    self._config.lifespanMin = minOrFixed
    self._config.lifespanMax = max or minOrFixed
    return self
end

--- Set particle velocity (speed in pixels/second)
--- @param minOrFixed number Min velocity, or fixed if max not provided
--- @param max number? Max velocity for random range
--- @return self
function RecipeMethods:velocity(minOrFixed, max)
    self._config.velocityMin = minOrFixed
    self._config.velocityMax = max or minOrFixed
    return self
end

--- Set gravity strength (positive = down)
--- @param strength number Gravity in pixels/second^2
--- @return self
function RecipeMethods:gravity(strength)
    self._config.gravity = strength
    return self
end

--- Set drag factor (velocity multiplier per frame)
--- @param factor number Drag factor (0.95 = 5% slowdown per frame)
--- @return self
function RecipeMethods:drag(factor)
    self._config.drag = factor
    return self
end

--- Enable alpha fade (1 -> 0 over lifetime)
--- @return self
function RecipeMethods:fade()
    self._config.fade = true
    return self
end

--- Enable fade in then out (0 -> 1 -> 0)
--- @param fadeInPct number Percentage of lifetime for fade in (0-1)
--- @return self
function RecipeMethods:fadeIn(fadeInPct)
    self._config.fadeInPct = fadeInPct
    return self
end

--- Enable scale shrink (1 -> 0 over lifetime)
--- @return self
function RecipeMethods:shrink()
    self._config.shrink = true
    return self
end

--- Set scale interpolation
--- @param startScale number Starting scale
--- @param endScale number Ending scale
--- @return self
function RecipeMethods:grow(startScale, endScale)
    self._config.scaleStart = startScale
    self._config.scaleEnd = endScale
    return self
end

--- Set rotation speed (degrees/second)
--- @param minOrFixed number Min spin speed, or fixed
--- @param max number? Max spin for random range
--- @return self
function RecipeMethods:spin(minOrFixed, max)
    self._config.spinMin = minOrFixed
    self._config.spinMax = max or minOrFixed
    return self
end

--- Set lateral wiggle amount
--- @param amount number Wiggle in pixels
--- @return self
function RecipeMethods:wiggle(amount)
    self._config.wiggle = amount
    return self
end

--- Enable velocity-based stretching
--- @return self
function RecipeMethods:stretch()
    self._config.stretch = true
    return self
end

--- Enable bouncing with restitution
--- @param restitution number Bounce factor (0-1)
--- @return self
function RecipeMethods:bounce(restitution)
    self._config.bounceRestitution = restitution
    return self
end

--- Enable homing toward target
--- @param strength number Homing strength (0-1)
--- @return self
function RecipeMethods:homing(strength)
    self._config.homingStrength = strength
    return self
end

--- Spawn trail particles behind this particle
--- @param recipe Recipe Trail particle recipe
--- @param rate number Spawn rate in seconds
--- @return self
function RecipeMethods:trail(recipe, rate)
    self._config.trailRecipe = recipe
    self._config.trailRate = rate
    return self
end

--- Cycle through colors
--- @param ... string|table Colors to flash
--- @return self
function RecipeMethods:flash(...)
    self._config.flashColors = {...}
    return self
end

--- Set spawn callback
--- @param fn function(particle, entity)
--- @return self
function RecipeMethods:onSpawn(fn)
    self._config.onSpawn = fn
    return self
end

--- Set update callback (called every frame)
--- @param fn function(particle, dt, entity)
--- @return self
function RecipeMethods:onUpdate(fn)
    self._config.onUpdate = fn
    return self
end

--- Set death callback
--- @param fn function(particle, entity)
--- @return self
function RecipeMethods:onDeath(fn)
    self._config.onDeath = fn
    return self
end

--- Set particle draw order
--- @param order number Z-index for draw order
--- @return self
function RecipeMethods:z(order)
    self._config.z = order
    return self
end

--- Set render space
--- @param spaceName string "world" or "screen"
--- @return self
function RecipeMethods:space(spaceName)
    self._config.space = spaceName
    return self
end

--- Set shaders for particle (enables entity-based rendering)
--- @param shaderList table List of shader names
--- @return self
function RecipeMethods:shaders(shaderList)
    self._config.shaders = shaderList
    return self
end

--- Set shader uniforms
--- @param uniforms table Uniform name -> value mapping
--- @return self
function RecipeMethods:shaderUniforms(uniforms)
    self._config.shaderUniforms = uniforms
    return self
end

--- Set custom draw command for this particle
--- @param fn function(particle, props) Custom draw function
--- @return self
function RecipeMethods:drawCommand(fn)
    self._drawCommand = fn
    return self
end

--- Get the recipe configuration (includes all settings)
--- @return table Configuration table
function RecipeMethods:getConfig()
    local config = {}
    -- Copy all _config fields
    for k, v in pairs(self._config) do
        config[k] = v
    end
    -- Add drawCommand if set
    config.drawCommand = self._drawCommand
    return config
end

--------------------------------------------------------------------------------
-- EMISSION
--------------------------------------------------------------------------------

local EmissionMethods = {}
EmissionMethods.__index = EmissionMethods

--- Set spawn position and trigger burst
--- @param x number X position
--- @param y number Y position
--- @return self
function EmissionMethods:at(x, y)
    self._position = { x = x, y = y }
    self:_spawn()
    return self
end

--- Spawn within a circle
--- @param cx number Center X
--- @param cy number Center Y
--- @param radius number Circle radius
--- @return self
function EmissionMethods:inCircle(cx, cy, radius)
    self._spawnMode = "circle"
    self._spawnCenter = { x = cx, y = cy }
    self._spawnRadius = radius
    self:_spawn()
    return self
end

--- Spawn within a rectangle
--- @param x number Left X
--- @param y number Top Y
--- @param w number Width
--- @param h number Height
--- @return self
function EmissionMethods:inRect(x, y, w, h)
    self._spawnMode = "rect"
    self._spawnRect = { x = x, y = y, w = w, h = h }
    self:_spawn()
    return self
end

--- Set spawn origin (use with :toward())
--- @param x number Origin X
--- @param y number Origin Y
--- @return self
function EmissionMethods:from(x, y)
    self._fromPos = { x = x, y = y }
    return self
end

--- Set target position and spawn
--- @param x number Target X
--- @param y number Target Y
--- @return self
function EmissionMethods:toward(x, y)
    self._towardPos = { x = x, y = y }
    self._position = self._fromPos or { x = 0, y = 0 }
    self._spawnMode = "toward"
    self:_spawn()
    return self
end

--- Set emission spread angle (cone)
--- @param degrees number Spread in degrees (±degrees from base direction)
--- @return self
function EmissionMethods:spread(degrees)
    self._spread = degrees
    return self
end

--- Set fixed emission angle
--- @param minDeg number Min angle in degrees (0 = right, 90 = down)
--- @param maxDeg number? Max angle for random range
--- @return self
function EmissionMethods:angle(minDeg, maxDeg)
    self._angleMin = minDeg
    self._angleMax = maxDeg or minDeg
    return self
end

--- Point particles away from spawn center
--- @return self
function EmissionMethods:outward()
    self._directionMode = "outward"
    return self
end

--- Point particles toward spawn center
--- @return self
function EmissionMethods:inward()
    self._directionMode = "inward"
    return self
end

--- Override recipe properties for this emission
--- @param overrides table Property overrides
--- @return self
function EmissionMethods:override(overrides)
    self._overrides = overrides
    return self
end

--- Apply per-particle customization
--- @param fn function(index, total) -> table of overrides
--- @return self
function EmissionMethods:each(fn)
    self._eachFn = fn
    return self
end

--- Internal: Spawn particles
function EmissionMethods:_spawn()
    local particleModule = self._recipe._particleModule or _G.particle
    if not particleModule then
        log_warn("Particles: particle module not available")
        return
    end

    for i = 1, self._count do
        self:_spawnSingle(particleModule, i, self._count)
    end
end

--- Internal: Spawn a single particle
function EmissionMethods:_spawnSingle(particleModule, index, total)
    local config = self._recipe._config

    -- Get per-particle overrides
    local perParticle = {}
    if self._eachFn then
        perParticle = self._eachFn(index, total) or {}
    end

    -- Helper function to get value with override priority
    -- Priority: recipe config < emission overrides < per-particle
    local function getValue(key, default)
        if perParticle[key] ~= nil then return perParticle[key] end
        if self._overrides and self._overrides[key] ~= nil then return self._overrides[key] end
        return config[key] or default
    end

    -- Resolve position based on spawn mode
    local pos
    if self._spawnMode == "circle" then
        -- Use sqrt(random) for uniform distribution within circle
        local angle = math.random() * math.pi * 2
        local r = math.sqrt(math.random()) * self._spawnRadius
        pos = {
            x = self._spawnCenter.x + math.cos(angle) * r,
            y = self._spawnCenter.y + math.sin(angle) * r
        }
    elseif self._spawnMode == "rect" then
        pos = {
            x = self._spawnRect.x + math.random() * self._spawnRect.w,
            y = self._spawnRect.y + math.random() * self._spawnRect.h
        }
    else
        pos = self._position or { x = 0, y = 0 }
    end

    -- Resolve size with override support
    local size
    if perParticle.size then
        size = perParticle.size
    elseif self._overrides and self._overrides.size then
        size = self._overrides.size
    else
        size = self:_randomRange(config.sizeMin or 6, config.sizeMax or 6)
    end

    -- Resolve other random values
    local lifespan = self:_randomRange(getValue("lifespanMin", 1), getValue("lifespanMax", 1))
    local velocity = self:_randomRange(getValue("velocityMin", 0), getValue("velocityMax", 0))

    -- Resolve velocity direction
    local vx, vy

    -- Determine base angle
    local baseAngle
    if self._angleMin then
        -- Fixed angle or range
        baseAngle = math.rad(self:_randomRange(self._angleMin, self._angleMax))
    elseif self._directionMode == "outward" and self._spawnCenter then
        -- Point away from spawn center
        local dx = pos.x - self._spawnCenter.x
        local dy = pos.y - self._spawnCenter.y
        baseAngle = math.atan2(dy, dx)
    elseif self._directionMode == "inward" and self._spawnCenter then
        -- Point toward spawn center
        local dx = self._spawnCenter.x - pos.x
        local dy = self._spawnCenter.y - pos.y
        baseAngle = math.atan2(dy, dx)
    elseif self._spawnMode == "toward" and self._towardPos then
        -- Point toward target
        local dx = self._towardPos.x - pos.x
        local dy = self._towardPos.y - pos.y
        baseAngle = math.atan2(dy, dx)
    else
        -- Random direction
        baseAngle = math.random() * math.pi * 2
    end

    -- Apply spread
    if self._spread then
        local spreadRad = math.rad(self._spread)
        baseAngle = baseAngle + (math.random() * 2 - 1) * spreadRad
    end

    vx = math.cos(baseAngle) * velocity
    vy = math.sin(baseAngle) * velocity

    -- Map shape to C++ renderType
    local renderTypeMap = {
        circle = particleModule.ParticleRenderType and particleModule.ParticleRenderType.CIRCLE_FILLED or 4,
        rect = particleModule.ParticleRenderType and particleModule.ParticleRenderType.RECTANGLE_FILLED or 2,
        line = particleModule.ParticleRenderType and particleModule.ParticleRenderType.LINE_FACING or 8,
        sprite = particleModule.ParticleRenderType and particleModule.ParticleRenderType.TEXTURE or 0,
    }

    -- Get shape with override support
    local shape = getValue("shape", "circle")

    local opts = {
        renderType = renderTypeMap[shape] or renderTypeMap.circle,
        velocity = { x = vx, y = vy },
        lifespan = lifespan,
        gravity = getValue("gravity", nil),
        startColor = getValue("startColor", nil),
        endColor = getValue("endColor", nil),
        rotationSpeed = getValue("spinMin", nil) and self:_randomRange(getValue("spinMin", 0), getValue("spinMax", 0)),
        autoAspect = getValue("stretch", nil),
        z = getValue("z", nil),
        space = getValue("space", nil),
    }

    local location = { x = pos.x, y = pos.y }
    local sizeVec = { x = size, y = size }

    local entity = particleModule.CreateParticle(location, sizeVec, opts, nil, nil)

    -- If recipe has shaders, add ShaderParticleTag to prevent double-render
    if config.shaders and #config.shaders > 0 then
        -- Get registry (use _registry for testing, fall back to global)
        local registry = self._recipe._registry or _G.registry
        if registry then
            -- Get ShaderParticleTag (use _shadersModule for testing, fall back to global)
            local shadersModule = self._recipe._shadersModule or _G.shaders
            if shadersModule and shadersModule.ShaderParticleTag then
                registry:emplace(entity, shadersModule.ShaderParticleTag)
            end
        end
    end

    return entity
end

--- Internal: Get random value in range
function EmissionMethods:_randomRange(min, max)
    if min == max then return min end
    return min + math.random() * (max - min)
end

--- Create an emission for burst spawning
--- @param count number Number of particles to spawn
--- @return Emission
function RecipeMethods:burst(count)
    local emission = setmetatable({}, EmissionMethods)
    emission._recipe = self
    emission._count = count
    emission._mode = "burst"
    return emission
end

--------------------------------------------------------------------------------
-- HANDLE
--------------------------------------------------------------------------------
--[[
Handles provide control over continuous particle streams.

Usage:
    local sparkStream = Particles.define()
        :shape("circle")
        :size(2, 4)
        :velocity(50, 100)
        :lifespan(0.5)
        :fade()
        :burst(3)
        :at(x, y)
        :stream()
        :every(0.1)      -- Spawn every 0.1 seconds
        :for_(2.0)       -- Run for 2 seconds total
        :attachTo(entity) -- Stop when entity is destroyed

    -- Update in game loop
    function update(dt)
        sparkStream:update(dt)
    end

    -- Stop manually
    sparkStream:stop()

API:
    - stream()         - Start streaming particles
    - every(interval)  - Set spawn interval in seconds (default: 0.1)
    - for_(duration)   - Set total duration in seconds (nil = infinite)
    - times(count)     - Set max spawn count (nil = infinite)
    - attachTo(entity) - Tie lifecycle to entity validity
    - stop()          - Stop the stream
    - update(dt)      - Call every frame to manage spawning
]]

local HandleMethods = {}
HandleMethods.__index = HandleMethods

--- Set spawn interval
--- @param interval number Interval in seconds between spawns
--- @return self
function HandleMethods:every(interval)
    self._interval = interval
    return self
end

--- Set total duration
--- @param duration number Total duration in seconds (nil = infinite)
--- @return self
function HandleMethods:for_(duration)
    self._duration = duration
    return self
end

--- Set max spawn count
--- @param count number Max number of spawns (nil = infinite)
--- @return self
function HandleMethods:times(count)
    self._maxCount = count
    return self
end

--- Attach to entity lifecycle
--- @param entity any Entity to track
--- @return self
function HandleMethods:attachTo(entity)
    self._attachedEntity = entity
    return self
end

--- Stop the stream
function HandleMethods:stop()
    self._active = false
end

--- Update the stream (call every frame)
--- @param dt number Delta time in seconds
function HandleMethods:update(dt)
    if not self._active then
        return
    end

    -- Check if attached entity is still valid
    if self._attachedEntity then
        -- In real implementation, would check entity_cache.valid()
        -- For now, we trust the entity reference
    end

    -- Handle first spawn (timeSinceSpawn starts at infinity)
    if self._timeSinceSpawn == math.huge then
        -- First update: check duration before spawning
        if self._duration and self._elapsed + dt > self._duration then
            self._active = false
            return
        end

        -- Check spawn count limit before spawning
        if self._maxCount and self._spawnCount >= self._maxCount then
            self._active = false
            return
        end

        -- Spawn immediately and reset timer
        self._emission:_spawn()
        self._spawnCount = self._spawnCount + 1
        self._timeSinceSpawn = dt  -- Start timer with current dt
    else
        -- Normal updates: accumulate time
        self._timeSinceSpawn = self._timeSinceSpawn + dt

        -- Check if we should spawn
        if self._timeSinceSpawn >= self._interval then
            -- Check duration limit before spawning
            if self._duration and self._elapsed + dt > self._duration then
                self._active = false
                return
            end

            -- Check spawn count limit before spawning
            if self._maxCount and self._spawnCount >= self._maxCount then
                self._active = false
                return
            end

            -- Spawn particles
            self._emission:_spawn()
            self._spawnCount = self._spawnCount + 1

            -- Reset timer, preserving overflow
            self._timeSinceSpawn = self._timeSinceSpawn - self._interval
        end
    end

    -- Accumulate elapsed time after spawn check
    self._elapsed = self._elapsed + dt
end

--- Create a handle for continuous emission
--- @return Handle
function EmissionMethods:stream()
    local handle = setmetatable({}, HandleMethods)
    handle._emission = self
    handle._active = true
    handle._elapsed = 0
    handle._timeSinceSpawn = math.huge  -- Set to infinity to trigger immediate spawn on first update
    handle._spawnCount = 0
    handle._interval = 0.1  -- default 10 times per second
    handle._duration = nil  -- infinite by default
    handle._maxCount = nil  -- infinite by default
    handle._attachedEntity = nil
    return handle
end

--------------------------------------------------------------------------------
-- MIXED EMISSION
--------------------------------------------------------------------------------
--[[
MixedEmission allows spawning particles from multiple recipes in a single emission.
Useful for composite effects like fire + smoke, sparks + debris, etc.

Usage:
    local fire = Particles.define():shape("circle"):size(4,8):color("orange")
    local smoke = Particles.define():shape("circle"):size(8,16):color("gray")

    Particles.mix({ fire, smoke })
        :burst(10, 5)  -- 10 fire, 5 smoke
        :at(x, y)
        :go()
]]

local MixedEmissionMethods = {}
MixedEmissionMethods.__index = MixedEmissionMethods

--- Set particle counts for burst (varargs for per-recipe counts, or single for uniform)
--- @param ... number Counts per recipe, or single count for all
--- @return self
function MixedEmissionMethods:burst(...)
    local counts = {...}
    if #counts == 1 then
        -- Uniform count: apply to all emissions
        for i = 1, #self._emissions do
            self._burstCounts[i] = counts[1]
        end
    else
        -- Per-recipe counts
        for i = 1, #self._emissions do
            self._burstCounts[i] = counts[i] or 0
        end
    end
    return self
end

--- Set spawn position and trigger burst
--- @param x number X position
--- @param y number Y position
--- @return self
function MixedEmissionMethods:at(x, y)
    self._position = { x = x, y = y }
    self._spawnMode = "at"
    self:go()
    return self
end

--- Spawn within a circle
--- @param cx number Center X
--- @param cy number Center Y
--- @param radius number Circle radius
--- @return self
function MixedEmissionMethods:inCircle(cx, cy, radius)
    self._spawnMode = "circle"
    self._spawnCenter = { x = cx, y = cy }
    self._spawnRadius = radius
    self:go()
    return self
end

--- Spawn within a rectangle
--- @param x number Left X
--- @param y number Top Y
--- @param w number Width
--- @param h number Height
--- @return self
function MixedEmissionMethods:inRect(x, y, w, h)
    self._spawnMode = "rect"
    self._spawnRect = { x = x, y = y, w = w, h = h }
    self:go()
    return self
end

--- Set spawn origin (use with :toward())
--- @param x number Origin X
--- @param y number Origin Y
--- @return self
function MixedEmissionMethods:from(x, y)
    self._fromPos = { x = x, y = y }
    return self
end

--- Set target position and spawn
--- @param x number Target X
--- @param y number Target Y
--- @return self
function MixedEmissionMethods:toward(x, y)
    self._towardPos = { x = x, y = y }
    self._position = self._fromPos or { x = 0, y = 0 }
    self._spawnMode = "toward"
    self:go()
    return self
end

--- Spawn all particles from all recipes
function MixedEmissionMethods:go()
    for i, emission in ipairs(self._emissions) do
        local count = self._burstCounts[i] or 0
        if count > 0 then
            emission._count = count

            -- Copy position state to each emission
            if self._spawnMode == "at" and self._position then
                emission._position = self._position
                emission:_spawn()
            elseif self._spawnMode == "circle" then
                emission._spawnMode = "circle"
                emission._spawnCenter = self._spawnCenter
                emission._spawnRadius = self._spawnRadius
                emission:_spawn()
            elseif self._spawnMode == "rect" then
                emission._spawnMode = "rect"
                emission._spawnRect = self._spawnRect
                emission:_spawn()
            elseif self._spawnMode == "toward" then
                emission._fromPos = self._fromPos
                emission._towardPos = self._towardPos
                emission._position = self._position
                emission._spawnMode = "toward"
                emission:_spawn()
            end
        end
    end
end

--- Internal: Spawn particles (called by Handle)
function MixedEmissionMethods:_spawn()
    for i, emission in ipairs(self._emissions) do
        local count = self._burstCounts[i] or 0
        if count > 0 then
            -- Ensure emission has the count set
            emission._count = count
            emission:_spawn()
        end
    end
end

--- Create a handle for continuous emission
--- @return Handle
function MixedEmissionMethods:stream()
    local handle = setmetatable({}, HandleMethods)
    handle._emission = self
    handle._active = true
    handle._elapsed = 0
    handle._timeSinceSpawn = math.huge  -- Set to infinity to trigger immediate spawn on first update
    handle._spawnCount = 0
    handle._interval = 0.1  -- default 10 times per second
    handle._duration = nil  -- infinite by default
    handle._maxCount = nil  -- infinite by default
    handle._attachedEntity = nil
    return handle
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--- Create a new particle recipe
--- @return Recipe
function Particles.define()
    local recipe = setmetatable({}, RecipeMethods)
    recipe._config = {
        shape = "circle",  -- default
    }
    return recipe
end

--- Mix multiple recipes into a single emission
--- @param recipes table Array of Recipe objects
--- @return MixedEmission
function Particles.mix(recipes)
    local mixed = setmetatable({}, MixedEmissionMethods)
    mixed._emissions = {}
    mixed._burstCounts = {}

    -- Create emissions for each recipe
    for i, recipe in ipairs(recipes) do
        local emission = setmetatable({}, EmissionMethods)
        emission._recipe = recipe
        emission._count = 0
        emission._mode = "burst"
        mixed._emissions[i] = emission
        mixed._burstCounts[i] = 0
    end

    return mixed
end

_G.__PARTICLES_BUILDER__ = Particles
return Particles
