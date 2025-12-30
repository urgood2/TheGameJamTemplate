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

--- Helper to convert various color inputs to a Color table
--- @param arg1 any First argument (r, table, string, or Color)
--- @param arg2 any|nil Second argument (g or endColor)
--- @param arg3 any|nil Third argument (b)
--- @param arg4 any|nil Fourth argument (a)
--- @return table, table|nil Normalized start color, optional end color
local function normalizeColors(arg1, arg2, arg3, arg4)
    local Col = _G.Col or function(r, g, b, a) return { r = r, g = g, b = b, a = a or 255 } end

    -- Case 1: color(r, g, b) or color(r, g, b, a) - 3+ numbers
    if type(arg1) == "number" and type(arg2) == "number" and type(arg3) == "number" then
        local a = (type(arg4) == "number") and arg4 or 255
        local c = Col(arg1, arg2, arg3, a)
        return c, nil  -- Same color for start/end
    end

    -- Case 2: color({r, g, b}) or color({r, g, b, a}) - table
    if type(arg1) == "table" then
        local r, g, b, a
        if arg1.r then
            -- Named fields: {r=255, g=200, b=50}
            r, g, b, a = arg1.r, arg1.g, arg1.b, arg1.a or 255
        else
            -- Array style: {255, 200, 50}
            r, g, b, a = arg1[1], arg1[2], arg1[3], arg1[4] or 255
        end
        local startCol = Col(r, g, b, a)

        -- Check if arg2 is an end color
        local endCol = nil
        if type(arg2) == "table" then
            if arg2.r then
                endCol = Col(arg2.r, arg2.g, arg2.b, arg2.a or 255)
            else
                endCol = Col(arg2[1], arg2[2], arg2[3], arg2[4] or 255)
            end
        elseif type(arg2) == "string" then
            endCol = arg2  -- Named color, will be resolved later
        end

        return startCol, endCol
    end

    -- Case 3: color("yellow") or color("yellow", "red") - named colors
    if type(arg1) == "string" then
        -- Named colors - keep as string, will be resolved at spawn time
        return arg1, arg2  -- arg2 could be another named color or nil
    end

    -- Case 4: color(Color) - already a Color userdata
    return arg1, arg2
end

--- Set particle color (start/end for interpolation)
--- Supports multiple calling conventions:
---   :color(255, 200, 50)      -- RGB
---   :color(255, 200, 50, 128) -- RGBA
---   :color({255, 200, 50})    -- Table
---   :color("yellow")          -- Named color
---   :color(startColor, endColor) -- Gradient
--- @return self
function RecipeMethods:color(arg1, arg2, arg3, arg4)
    local startCol, endCol = normalizeColors(arg1, arg2, arg3, arg4)
    self._config.startColor = startCol
    self._config.endColor = endCol or startCol
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
--- @param freq number? Wiggle frequency in Hz (default: 10)
--- @return self
function RecipeMethods:wiggle(amount, freq)
    self._config.wiggle = amount
    if freq then
        self._config.wiggleFreq = freq
    end
    return self
end

--- Set wiggle frequency (use with :wiggle())
--- @param freq number Frequency in Hz
--- @return self
function RecipeMethods:wiggleFreq(freq)
    self._config.wiggleFreq = freq
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
--- @param groundY number? Ground Y level (default: 900)
--- @return self
function RecipeMethods:bounce(restitution, groundY)
    self._config.bounceRestitution = restitution
    if groundY then
        self._config.bounceGroundY = groundY
    end
    return self
end

--- Set bounce ground level (use with :bounce())
--- @param groundY number Ground Y level in pixels
--- @return self
function RecipeMethods:bounceGroundY(groundY)
    self._config.bounceGroundY = groundY
    return self
end

--- Enable homing toward target
--- @param strength number Homing strength (0-1)
--- @param target table|number|nil Target position {x,y} or entity ID (nil = set later)
--- @return self
function RecipeMethods:homing(strength, target)
    self._config.homingStrength = strength
    self._config.homingTarget = target
    return self
end

--- Set homing target (use with :homing())
--- @param target table|number Target position {x,y} or entity ID
--- @return self
function RecipeMethods:homingTarget(target)
    self._config.homingTarget = target
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

--- Enable scale pulsing (oscillates scale over time)
--- @param amount number Pulse amount (0.4 = ±40% size variation)
--- @param minSpeed number? Min pulse speed in Hz (default: 2.0)
--- @param maxSpeed number? Max pulse speed in Hz (default: 6.0)
--- @return self
function RecipeMethods:pulse(amount, minSpeed, maxSpeed)
    self._config.pulse = {
        amount = amount or 0.4,
        minSpeed = minSpeed or 2.0,
        maxSpeed = maxSpeed or 6.0,
    }
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
    -- If size is directly overridden, use it; otherwise use sizeMin/sizeMax
    local size
    local overrideSize = getValue("size", nil)
    if overrideSize then
        size = overrideSize
    else
        size = self:_randomRange(getValue("sizeMin", 6), getValue("sizeMax", 6))
    end

    -- Resolve other random values
    -- Check for direct override before using min/max ranges
    local lifespan = getValue("lifespan", nil) or self:_randomRange(getValue("lifespanMin", 1), getValue("lifespanMax", 1))
    local velocity = getValue("velocity", nil) or self:_randomRange(getValue("velocityMin", 0), getValue("velocityMax", 0))

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
        local dist = math.sqrt(dx*dx + dy*dy)
        if dist < 0.01 then
            -- If particle is at center, use random direction
            baseAngle = math.random() * math.pi * 2
        else
            baseAngle = math.atan(dy, dx)
        end
    elseif self._directionMode == "inward" and self._spawnCenter then
        -- Point toward spawn center
        local dx = self._spawnCenter.x - pos.x
        local dy = self._spawnCenter.y - pos.y
        local dist = math.sqrt(dx*dx + dy*dy)
        if dist < 0.01 then
            -- If particle is at center, use random direction
            baseAngle = math.random() * math.pi * 2
        else
            baseAngle = math.atan(dy, dx)
        end
    elseif self._spawnMode == "toward" and self._towardPos then
        -- Point toward target
        local dx = self._towardPos.x - pos.x
        local dy = self._towardPos.y - pos.y
        baseAngle = math.atan(dy, dx)
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
        ellipse_stretch = particleModule.ParticleRenderType and particleModule.ParticleRenderType.ELLIPSE_STRETCH or 7,
        rect = particleModule.ParticleRenderType and particleModule.ParticleRenderType.RECTANGLE_FILLED or 2,
        line = particleModule.ParticleRenderType and particleModule.ParticleRenderType.LINE_FACING or 8,
        sprite = particleModule.ParticleRenderType and particleModule.ParticleRenderType.TEXTURE or 0,
    }

    -- Get shape with override support
    local shape = getValue("shape", "circle")
    local stretchEnabled = getValue("stretch", false)

    -- When stretch is enabled with circle shape, use ELLIPSE_STRETCH for velocity-based stretching
    if stretchEnabled and shape == "circle" then
        shape = "ellipse_stretch"
    end

    -- Use Vec2 for C++ compatibility (or fall back to table for mock testing)
    local Vec2 = _G.Vec2 or function(x, y) return { x = x, y = y } end

    -- Resolve a color value (handles strings via util.getColor, or returns as-is)
    local function resolveColor(c)
        if c == nil then return nil end
        if type(c) == "string" then
            -- Named color - try to resolve via util.getColor
            if _G.util and _G.util.getColor then
                return _G.util.getColor(c)
            else
                -- Fallback: return white if we can't resolve
                local Col = _G.Col or function(r, g, b, a) return { r = r, g = g, b = b, a = a or 255 } end
                return Col(255, 255, 255, 255)
            end
        end
        return c
    end

    local opts = {
        renderType = renderTypeMap[shape] or renderTypeMap.circle,
        velocity = Vec2(vx, vy),
        lifespan = lifespan,
        gravity = getValue("gravity", nil),
        startColor = resolveColor(getValue("startColor", nil)),
        endColor = resolveColor(getValue("endColor", nil)),
        rotationSpeed = getValue("spinMin", nil) and self:_randomRange(getValue("spinMin", 0), getValue("spinMax", 0)),
        autoAspect = getValue("stretch", false) or nil,  -- Boolean: stretch based on velocity
        faceVelocity = getValue("stretch", false) or nil,  -- Boolean: rotate to face velocity
        z = getValue("z", nil),
        space = getValue("space", nil),
    }

    -- Check if any enhanced features need callbacks
    local hasEnhanced = config.wiggle or config.bounceRestitution or
                        config.homingStrength or config.trailRecipe or config.flashColors or
                        config.pulse or config.onSpawn or config.onUpdate or config.onDeath

    if hasEnhanced then
        -- Per-particle state (captured in closure)
        local state = {
            entity = nil,  -- Set in onInit
            wigglePhase = math.random() * math.pi * 2,
            originalDir = { x = vx, y = vy },
            trailTimer = 0,
            -- Pulse state (random speed and phase per particle for organic variation)
            pulseSpeed = config.pulse and (config.pulse.minSpeed + math.random() * (config.pulse.maxSpeed - config.pulse.minSpeed)) or nil,
            pulsePhase = config.pulse and (math.random() * math.pi * 2) or nil,
        }

        -- Get component_cache and entity_cache for position access
        local component_cache = _G.component_cache or (function()
            local ok, cc = pcall(require, "core.component_cache")
            return ok and cc or nil
        end)()
        local entity_cache = _G.entity_cache or (function()
            local ok, ec = pcall(require, "core.entity_cache")
            return ok and ec or nil
        end)()
        local Transform = _G.Transform

        opts.onInitCallback = function(entity, particle)
            state.entity = entity
            -- Call user's onSpawn if provided
            if config.onSpawn then
                config.onSpawn(particle, entity)
            end
        end

        opts.onUpdateCallback = function(particle, dt)
            -- Safety check: ensure entity is still valid
            if not state.entity then return end
            if entity_cache and not entity_cache.valid(state.entity) then return end

            -- Get transform for position-based features
            local transform = nil
            if component_cache and Transform then
                transform = component_cache.get(state.entity, Transform)
            end

            -- 1. WIGGLE: Lateral oscillation
            if config.wiggle then
                state.wigglePhase = state.wigglePhase + dt * (config.wiggleFreq or 10)
                local origLen = math.sqrt(state.originalDir.x^2 + state.originalDir.y^2)
                if origLen > 0.01 then
                    local perpX = -state.originalDir.y / origLen
                    local perpY = state.originalDir.x / origLen
                    local wiggleOffset = math.sin(state.wigglePhase) * config.wiggle
                    local vel = particle.velocity
                    if vel then
                        -- Apply perpendicular wiggle force
                        particle.velocity = Vec2(
                            vel.x + perpX * wiggleOffset * dt * 60,
                            vel.y + perpY * wiggleOffset * dt * 60
                        )
                    end
                end
            end

            -- 2. BOUNCE: Reflect off ground
            if config.bounceRestitution and transform then
                local groundY = config.bounceGroundY or 900
                if transform.actualY > groundY then
                    transform.actualY = groundY
                    local vel = particle.velocity
                    if vel and vel.y > 0 then
                        particle.velocity = Vec2(vel.x, -vel.y * config.bounceRestitution)
                    end
                end
            end

            -- 3. HOMING: Seek toward target
            if config.homingStrength and config.homingTarget and transform then
                local targetPos = config.homingTarget
                -- If target is entity ID, get its position
                if type(targetPos) == "number" and component_cache and Transform then
                    local targetTransform = component_cache.get(targetPos, Transform)
                    if targetTransform then
                        targetPos = { x = targetTransform.actualX, y = targetTransform.actualY }
                    else
                        targetPos = nil  -- Entity no longer valid
                    end
                end

                if targetPos and targetPos.x and targetPos.y then
                    local dx = targetPos.x - transform.actualX
                    local dy = targetPos.y - transform.actualY
                    local dist = math.sqrt(dx*dx + dy*dy)
                    if dist > 1 then
                        local vel = particle.velocity
                        if vel then
                            local speed = math.sqrt(vel.x^2 + vel.y^2)
                            if speed > 0.01 then
                                local targetVelX = (dx / dist) * speed
                                local targetVelY = (dy / dist) * speed
                                local str = config.homingStrength
                                particle.velocity = Vec2(
                                    vel.x + (targetVelX - vel.x) * str * dt * 5,
                                    vel.y + (targetVelY - vel.y) * str * dt * 5
                                )
                            end
                        end
                    end
                end
            end

            -- 4. TRAIL: Spawn trail particles
            if config.trailRecipe and config.trailRate and transform then
                state.trailTimer = state.trailTimer + dt
                if state.trailTimer >= config.trailRate then
                    state.trailTimer = state.trailTimer - config.trailRate
                    -- Guard against infinite recursion: skip if trail recipe has its own trail
                    local trailConfig = config.trailRecipe._config
                    if trailConfig and trailConfig.trailRecipe then
                        if not state.trailWarned then
                            log_warn("Trail particle recipe has its own :trail() - skipping to prevent infinite recursion")
                            state.trailWarned = true
                        end
                    else
                        -- Spawn trail particle at current position
                        config.trailRecipe:burst(1):at(transform.actualX, transform.actualY)
                    end
                end
            end

            -- 5. FLASH: Cycle through colors
            if config.flashColors and #config.flashColors > 0 then
                local age = particle.age or 0
                local life = particle.lifespan or 1
                local progress = math.min(age / life, 0.999)
                local numColors = #config.flashColors
                local colorIndex = math.floor(progress * numColors) + 1

                local color = config.flashColors[colorIndex]
                if color then
                    -- Resolve color if it's a string
                    if type(color) == "string" then
                        color = resolveColor(color)
                    end
                    -- Convert table to Col object if needed
                    if type(color) == "table" and color.r == nil then
                        -- Array-style table {r, g, b, a}
                        color = Col(color[1] or 255, color[2] or 255, color[3] or 255, color[4] or 255)
                    elseif type(color) == "table" and color.r then
                        -- Named table {r=, g=, b=, a=}
                        color = Col(color.r, color.g, color.b, color.a or 255)
                    end
                    particle.color = color
                end
            end

            -- 6. PULSE: Oscillate scale over time
            if config.pulse and state.pulseSpeed then
                local age = particle.age or 0
                local pulse = math.sin(age * state.pulseSpeed + state.pulsePhase)
                particle.scale = 1.0 + pulse * config.pulse.amount
            end

            -- Call user's onUpdate if provided
            if config.onUpdate then
                config.onUpdate(particle, dt, state.entity)
            end
        end

        -- Wire up onDeathCallback for user's onDeath
        if config.onDeath then
            opts.onDeathCallback = function(particle)
                config.onDeath(particle, state.entity)
            end
        end
    end

    local location = Vec2(pos.x, pos.y)
    local sizeVec = Vec2(size, size)

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

        -- Setup shader rendering pipeline
        Particles.setupShaderRendering(entity, config)
    end

    -- Handle custom drawCommand
    -- Note: drawCommand is stored in _drawCommand, not in _config
    local drawCommand = self._recipe._drawCommand
    if drawCommand then
        if not config.shaders or #config.shaders == 0 then
            -- Warn: drawCommand requires shaders to work
            if _G.log_warn then
                log_warn("Particle drawCommand requires :shaders() to be set - custom rendering will not work")
            end
        else
            -- Build props for the custom draw command
            local drawProps = {
                entity = entity,
                x = pos.x,
                y = pos.y,
                size = size,
                color = resolveColor(getValue("startColor", nil)),
                velocity = { x = vx, y = vy },
                lifespan = lifespan,
                config = self._recipe:getConfig(),  -- Full config including drawCommand
            }

            -- Call the custom draw command
            -- User should use draw.local_command() to add commands to shader pipeline
            drawCommand(entity, drawProps)
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

--- Check if stream is still active
--- @return boolean
function HandleMethods:isActive()
    return self._active
end

--- Update spawn position for the stream
--- @param x number X position
--- @param y number Y position
function HandleMethods:setPosition(x, y)
    if self._emission then
        self._emission._position = { x = x, y = y }
    end
end

--- Update spawn rect bounds for the stream
--- @param x number Left X
--- @param y number Top Y  
--- @param w number Width
--- @param h number Height
function HandleMethods:setSpawnRect(x, y, w, h)
    if self._emission then
        self._emission._spawnMode = "rect"
        self._emission._spawnRect = { x = x, y = y, w = w, h = h }
    end
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

--- Set angular spread (applies to all emissions)
--- @param degrees number Spread angle in degrees
--- @return self
function MixedEmissionMethods:spread(degrees)
    -- Store in degrees - EmissionMethods:_spawnSingle converts to radians
    self._spread = degrees
    return self
end

--- Set emission angle (applies to all emissions)
--- @param minDeg number Min angle in degrees
--- @param maxDeg number? Max angle (same as min if not provided)
--- @return self
function MixedEmissionMethods:angle(minDeg, maxDeg)
    -- Store in degrees - EmissionMethods:_spawnSingle converts to radians
    self._angleMin = minDeg
    self._angleMax = maxDeg or minDeg
    return self
end

--- Particles move outward from spawn center
--- @return self
function MixedEmissionMethods:outward()
    self._directionMode = "outward"
    return self
end

--- Particles move inward toward spawn center
--- @return self
function MixedEmissionMethods:inward()
    self._directionMode = "inward"
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

            -- Copy direction state to each emission
            if self._spread then
                emission._spread = self._spread
            end
            if self._angleMin then
                emission._angleMin = self._angleMin
                emission._angleMax = self._angleMax
            end
            if self._directionMode then
                emission._directionMode = self._directionMode
            end

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

            -- Copy direction state to each emission
            if self._spread then
                emission._spread = self._spread
            end
            if self._angleMin then
                emission._angleMin = self._angleMin
                emission._angleMax = self._angleMax
            end
            if self._directionMode then
                emission._directionMode = self._directionMode
            end

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
-- SHADER RENDERING SETUP
--------------------------------------------------------------------------------

--- Setup shader rendering for a particle entity
--- @param entity any Entity ID
--- @param config table Recipe configuration with shaders and shaderUniforms
function Particles.setupShaderRendering(entity, config)
    if not config.shaders or #config.shaders == 0 then
        return
    end

    -- Use injected ShaderBuilder for testing, or fall back to require
    local ShaderBuilder = Particles._ShaderBuilder or require("core.shader_builder")

    -- Add shader passes using ShaderBuilder
    local builder = ShaderBuilder.for_entity(entity)
    for _, shaderName in ipairs(config.shaders) do
        builder:add(shaderName)
    end
    builder:apply()

    -- Apply shader uniforms if provided
    if config.shaderUniforms then
        -- Use injected globalShaderUniforms for testing, or fall back to global
        local globalShaderUniforms = Particles._globalShaderUniforms or _G.globalShaderUniforms
        if globalShaderUniforms then
            for shaderName, uniforms in pairs(config.shaderUniforms) do
                for uniformName, value in pairs(uniforms) do
                    globalShaderUniforms:set(shaderName, uniformName, value)
                end
            end
        end
    end
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
