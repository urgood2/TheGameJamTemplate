# Particle Builder Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement a fluent, composable Lua API for creating particles with minimal boilerplate.

**Architecture:** Recipe/Emission/Handle pattern. Recipes are immutable particle definitions, Emissions configure spawn events, Handles control streams. Shader-enabled particles use full entities routed through the local_command pipeline.

**Tech Stack:** Lua (Sol2 bindings), existing `particle.CreateParticle()` C++ API, ShaderBuilder, draw.local_command

---

## Task 1: Test Infrastructure Setup

**Files:**
- Create: `assets/scripts/tests/test_runner.lua`
- Create: `assets/scripts/tests/test_particle_builder.lua`
- Create: `assets/scripts/tests/mocks/particle_mock.lua`

**Step 1: Create test runner**

```lua
-- assets/scripts/tests/test_runner.lua
local TestRunner = {}

local tests = {}
local results = { passed = 0, failed = 0, errors = {} }

function TestRunner.describe(name, fn)
    tests[name] = fn
end

function TestRunner.it(name, fn)
    local ok, err = pcall(fn)
    if ok then
        results.passed = results.passed + 1
        print("[PASS] " .. name)
    else
        results.failed = results.failed + 1
        table.insert(results.errors, { name = name, error = err })
        print("[FAIL] " .. name .. ": " .. tostring(err))
    end
end

function TestRunner.assert_equals(expected, actual, msg)
    if expected ~= actual then
        error((msg or "Assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

function TestRunner.assert_true(value, msg)
    if not value then
        error((msg or "Assertion failed") .. ": expected true, got " .. tostring(value))
    end
end

function TestRunner.assert_nil(value, msg)
    if value ~= nil then
        error((msg or "Assertion failed") .. ": expected nil, got " .. tostring(value))
    end
end

function TestRunner.assert_not_nil(value, msg)
    if value == nil then
        error((msg or "Assertion failed") .. ": expected non-nil value")
    end
end

function TestRunner.assert_table_contains(tbl, key, msg)
    if tbl[key] == nil then
        error((msg or "Assertion failed") .. ": table missing key " .. tostring(key))
    end
end

function TestRunner.run_all()
    results = { passed = 0, failed = 0, errors = {} }
    for name, fn in pairs(tests) do
        print("\n=== " .. name .. " ===")
        fn()
    end
    print("\n=== RESULTS ===")
    print("Passed: " .. results.passed)
    print("Failed: " .. results.failed)
    if #results.errors > 0 then
        print("\nFailures:")
        for _, e in ipairs(results.errors) do
            print("  - " .. e.name .. ": " .. e.error)
        end
    end
    return results.failed == 0
end

function TestRunner.reset()
    tests = {}
    results = { passed = 0, failed = 0, errors = {} }
end

return TestRunner
```

**Step 2: Create particle mock**

```lua
-- assets/scripts/tests/mocks/particle_mock.lua
local ParticleMock = {}

ParticleMock.calls = {}
ParticleMock.created_entities = {}
ParticleMock._next_entity_id = 1000

-- Mock RenderSpace enum
ParticleMock.RenderSpace = {
    WORLD = "World",
    SCREEN = "Screen"
}

-- Mock ParticleRenderType enum
ParticleMock.ParticleRenderType = {
    TEXTURE = 0,
    RECTANGLE_LINE = 1,
    RECTANGLE_FILLED = 2,
    CIRCLE_LINE = 3,
    CIRCLE_FILLED = 4,
    ELLIPSE = 5,
    LINE = 6,
    ELLIPSE_STRETCH = 7,
    LINE_FACING = 8
}

function ParticleMock.CreateParticle(location, size, opts, animConfig, tag)
    local entity = ParticleMock._next_entity_id
    ParticleMock._next_entity_id = ParticleMock._next_entity_id + 1

    table.insert(ParticleMock.calls, {
        fn = "CreateParticle",
        args = {
            location = location,
            size = size,
            opts = opts,
            animConfig = animConfig,
            tag = tag
        },
        returned = entity
    })

    ParticleMock.created_entities[entity] = {
        location = location,
        size = size,
        opts = opts,
        animConfig = animConfig,
        tag = tag
    }

    return entity
end

function ParticleMock.reset()
    ParticleMock.calls = {}
    ParticleMock.created_entities = {}
    ParticleMock._next_entity_id = 1000
end

function ParticleMock.get_last_call()
    return ParticleMock.calls[#ParticleMock.calls]
end

function ParticleMock.get_call_count()
    return #ParticleMock.calls
end

return ParticleMock
```

**Step 3: Create initial test file (empty, will add tests per task)**

```lua
-- assets/scripts/tests/test_particle_builder.lua
local TestRunner = require("tests.test_runner")
local ParticleMock = require("tests.mocks.particle_mock")

-- Tests will be added here as we implement each feature

return function()
    TestRunner.run_all()
end
```

**Step 4: Commit**

```bash
cd /Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/.worktrees/particle-builder
git add assets/scripts/tests/
git commit -m "test: add Lua test infrastructure for particle builder"
```

---

## Task 2: Recipe Core - define() and shape()

**Files:**
- Create: `assets/scripts/core/particles.lua`
- Modify: `assets/scripts/tests/test_particle_builder.lua`

**Step 1: Write failing test for Recipe creation and shape**

Add to `test_particle_builder.lua`:

```lua
local TestRunner = require("tests.test_runner")
local ParticleMock = require("tests.mocks.particle_mock")
local it, assert_equals, assert_not_nil = TestRunner.it, TestRunner.assert_equals, TestRunner.assert_not_nil

TestRunner.describe("Recipe", function()
    it("define() returns a Recipe object", function()
        local Particles = require("core.particles")
        local recipe = Particles.define()
        assert_not_nil(recipe, "define() should return a recipe")
        assert_not_nil(recipe._config, "recipe should have _config")
    end)

    it("shape() sets renderType for circle", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():shape("circle")
        assert_equals("circle", recipe._config.shape)
    end)

    it("shape() sets renderType for rect", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():shape("rect")
        assert_equals("rect", recipe._config.shape)
    end)

    it("shape() sets renderType for line", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():shape("line")
        assert_equals("line", recipe._config.shape)
    end)

    it("shape() sets sprite with ID", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():shape("sprite", "my_sprite")
        assert_equals("sprite", recipe._config.shape)
        assert_equals("my_sprite", recipe._config.spriteId)
    end)

    it("methods chain and return self", function()
        local Particles = require("core.particles")
        local recipe = Particles.define()
        local returned = recipe:shape("circle")
        assert_equals(recipe, returned, "shape() should return self for chaining")
    end)
end)
```

**Step 2: Run test to verify it fails**

```bash
cd /Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/.worktrees/particle-builder
# Run in-game or via Lua standalone:
lua -e "package.path = 'assets/scripts/?.lua;' .. package.path; require('tests.test_particle_builder')()"
```

Expected: FAIL with "module 'core.particles' not found"

**Step 3: Write minimal implementation**

```lua
-- assets/scripts/core/particles.lua
--[[
================================================================================
PARTICLE BUILDER - Fluent API for Particle Effects
================================================================================
Reduces verbose particle.CreateParticle() calls to composable recipes.

Usage:
    local Particles = require("core.particles")

    local spark = Particles.define()
        :shape("circle")
        :size(4, 8)
        :color("orange", "red")
        :fade()
        :lifespan(0.3)

    spark:burst(10):at(x, y)

Design:
    - Recipe: Immutable particle definition (what it looks like, how it behaves)
    - Emission: Spawn configuration (where, when, how many)
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

_G.__PARTICLES_BUILDER__ = Particles
return Particles
```

**Step 4: Run test to verify it passes**

```bash
lua -e "package.path = 'assets/scripts/?.lua;' .. package.path; require('tests.test_particle_builder')()"
```

Expected: PASS

**Step 5: Commit**

```bash
git add assets/scripts/core/particles.lua assets/scripts/tests/test_particle_builder.lua
git commit -m "feat(particles): add Recipe.define() and shape() method"
```

---

## Task 3: Recipe - size(), color(), lifespan()

**Files:**
- Modify: `assets/scripts/core/particles.lua`
- Modify: `assets/scripts/tests/test_particle_builder.lua`

**Step 1: Write failing tests**

Add to `test_particle_builder.lua`:

```lua
TestRunner.describe("Recipe properties", function()
    it("size() with single value", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():size(6)
        assert_equals(6, recipe._config.sizeMin)
        assert_equals(6, recipe._config.sizeMax)
    end)

    it("size() with range", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():size(4, 8)
        assert_equals(4, recipe._config.sizeMin)
        assert_equals(8, recipe._config.sizeMax)
    end)

    it("color() with single color", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():color("red")
        assert_equals("red", recipe._config.startColor)
        assert_equals("red", recipe._config.endColor)
    end)

    it("color() with start and end", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():color("orange", "red")
        assert_equals("orange", recipe._config.startColor)
        assert_equals("red", recipe._config.endColor)
    end)

    it("lifespan() with single value", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():lifespan(0.5)
        assert_equals(0.5, recipe._config.lifespanMin)
        assert_equals(0.5, recipe._config.lifespanMax)
    end)

    it("lifespan() with range", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():lifespan(0.3, 0.6)
        assert_equals(0.3, recipe._config.lifespanMin)
        assert_equals(0.6, recipe._config.lifespanMax)
    end)
end)
```

**Step 2: Run test to verify it fails**

Expected: FAIL with "attempt to index nil" or similar

**Step 3: Write minimal implementation**

Add to `particles.lua` RecipeMethods:

```lua
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
```

**Step 4: Run test to verify it passes**

**Step 5: Commit**

```bash
git add assets/scripts/core/particles.lua assets/scripts/tests/test_particle_builder.lua
git commit -m "feat(particles): add size(), color(), lifespan() to Recipe"
```

---

## Task 4: Recipe - velocity(), gravity(), drag()

**Files:**
- Modify: `assets/scripts/core/particles.lua`
- Modify: `assets/scripts/tests/test_particle_builder.lua`

**Step 1: Write failing tests**

```lua
TestRunner.describe("Recipe motion", function()
    it("velocity() with single value", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():velocity(100)
        assert_equals(100, recipe._config.velocityMin)
        assert_equals(100, recipe._config.velocityMax)
    end)

    it("velocity() with range", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():velocity(100, 200)
        assert_equals(100, recipe._config.velocityMin)
        assert_equals(200, recipe._config.velocityMax)
    end)

    it("gravity() sets gravity strength", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():gravity(200)
        assert_equals(200, recipe._config.gravity)
    end)

    it("drag() sets drag factor", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():drag(0.95)
        assert_equals(0.95, recipe._config.drag)
    end)
end)
```

**Step 2: Run test to verify it fails**

**Step 3: Write minimal implementation**

```lua
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
```

**Step 4: Run test to verify it passes**

**Step 5: Commit**

```bash
git add assets/scripts/core/particles.lua assets/scripts/tests/test_particle_builder.lua
git commit -m "feat(particles): add velocity(), gravity(), drag() to Recipe"
```

---

## Task 5: Recipe - Behaviors (fade, shrink, spin, etc.)

**Files:**
- Modify: `assets/scripts/core/particles.lua`
- Modify: `assets/scripts/tests/test_particle_builder.lua`

**Step 1: Write failing tests**

```lua
TestRunner.describe("Recipe behaviors", function()
    it("fade() enables alpha fade", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():fade()
        assert_true(recipe._config.fade)
    end)

    it("fadeIn() sets fade in percentage", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():fadeIn(0.2)
        assert_equals(0.2, recipe._config.fadeInPct)
    end)

    it("shrink() enables scale shrink", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():shrink()
        assert_true(recipe._config.shrink)
    end)

    it("grow() sets scale range", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():grow(1, 3)
        assert_equals(1, recipe._config.scaleStart)
        assert_equals(3, recipe._config.scaleEnd)
    end)

    it("spin() sets rotation speed", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():spin(90)
        assert_equals(90, recipe._config.spinMin)
        assert_equals(90, recipe._config.spinMax)
    end)

    it("spin() with range", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():spin(90, 180)
        assert_equals(90, recipe._config.spinMin)
        assert_equals(180, recipe._config.spinMax)
    end)

    it("wiggle() sets wiggle amount", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():wiggle(10)
        assert_equals(10, recipe._config.wiggle)
    end)

    it("stretch() enables velocity stretching", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():stretch()
        assert_true(recipe._config.stretch)
    end)

    it("bounce() sets restitution", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():bounce(0.6)
        assert_equals(0.6, recipe._config.bounceRestitution)
    end)

    it("homing() sets homing strength", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():homing(0.5)
        assert_equals(0.5, recipe._config.homingStrength)
    end)
end)
```

**Step 2: Run test to verify it fails**

**Step 3: Write minimal implementation**

```lua
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
```

**Step 4: Run test to verify it passes**

**Step 5: Commit**

```bash
git add assets/scripts/core/particles.lua assets/scripts/tests/test_particle_builder.lua
git commit -m "feat(particles): add behavior methods (fade, shrink, spin, etc.)"
```

---

## Task 6: Recipe - trail(), flash(), callbacks

**Files:**
- Modify: `assets/scripts/core/particles.lua`
- Modify: `assets/scripts/tests/test_particle_builder.lua`

**Step 1: Write failing tests**

```lua
TestRunner.describe("Recipe advanced", function()
    it("trail() stores recipe and rate", function()
        local Particles = require("core.particles")
        local trailRecipe = Particles.define():shape("circle"):size(2)
        local recipe = Particles.define():trail(trailRecipe, 0.1)
        assert_equals(trailRecipe, recipe._config.trailRecipe)
        assert_equals(0.1, recipe._config.trailRate)
    end)

    it("flash() stores colors", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():flash("white", "orange", "red")
        assert_equals(3, #recipe._config.flashColors)
    end)

    it("onSpawn() stores callback", function()
        local Particles = require("core.particles")
        local fn = function() end
        local recipe = Particles.define():onSpawn(fn)
        assert_equals(fn, recipe._config.onSpawn)
    end)

    it("onUpdate() stores callback", function()
        local Particles = require("core.particles")
        local fn = function() end
        local recipe = Particles.define():onUpdate(fn)
        assert_equals(fn, recipe._config.onUpdate)
    end)

    it("onDeath() stores callback", function()
        local Particles = require("core.particles")
        local fn = function() end
        local recipe = Particles.define():onDeath(fn)
        assert_equals(fn, recipe._config.onDeath)
    end)
end)
```

**Step 2: Run test to verify it fails**

**Step 3: Write minimal implementation**

```lua
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
```

**Step 4: Run test to verify it passes**

**Step 5: Commit**

```bash
git add assets/scripts/core/particles.lua assets/scripts/tests/test_particle_builder.lua
git commit -m "feat(particles): add trail(), flash(), callbacks to Recipe"
```

---

## Task 7: Recipe - z(), space(), shaders()

**Files:**
- Modify: `assets/scripts/core/particles.lua`
- Modify: `assets/scripts/tests/test_particle_builder.lua`

**Step 1: Write failing tests**

```lua
TestRunner.describe("Recipe rendering", function()
    it("z() sets draw order", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():z(100)
        assert_equals(100, recipe._config.z)
    end)

    it("space() with 'world'", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():space("world")
        assert_equals("world", recipe._config.space)
    end)

    it("space() with 'screen'", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():space("screen")
        assert_equals("screen", recipe._config.space)
    end)

    it("shaders() stores shader list", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():shaders({ "glow", "dissolve" })
        assert_equals(2, #recipe._config.shaders)
        assert_equals("glow", recipe._config.shaders[1])
    end)

    it("shaderUniforms() stores uniforms", function()
        local Particles = require("core.particles")
        local recipe = Particles.define()
            :shaders({ "glow" })
            :shaderUniforms({ glow_intensity = 2.0 })
        assert_equals(2.0, recipe._config.shaderUniforms.glow_intensity)
    end)
end)
```

**Step 2: Run test to verify it fails**

**Step 3: Write minimal implementation**

```lua
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
```

**Step 4: Run test to verify it passes**

**Step 5: Commit**

```bash
git add assets/scripts/core/particles.lua assets/scripts/tests/test_particle_builder.lua
git commit -m "feat(particles): add z(), space(), shaders() to Recipe"
```

---

## Task 8: Emission - burst() and at()

**Files:**
- Modify: `assets/scripts/core/particles.lua`
- Modify: `assets/scripts/tests/test_particle_builder.lua`

**Step 1: Write failing tests**

```lua
TestRunner.describe("Emission burst", function()
    it("burst() returns Emission object", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():shape("circle")
        local emission = recipe:burst(10)
        assert_not_nil(emission)
        assert_equals(10, emission._count)
    end)

    it("burst() does not modify recipe", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():shape("circle")
        local emission = recipe:burst(10)
        assert_nil(recipe._count)
    end)

    it("at() sets position and triggers spawn", function()
        local Particles = require("core.particles")
        ParticleMock.reset()

        -- Inject mock
        local recipe = Particles.define():shape("circle"):size(6):lifespan(1)
        recipe._particleModule = ParticleMock

        recipe:burst(5):at(100, 200)

        assert_equals(5, ParticleMock.get_call_count())
    end)

    it("at() passes correct position to CreateParticle", function()
        local Particles = require("core.particles")
        ParticleMock.reset()

        local recipe = Particles.define():shape("circle"):size(6):lifespan(1)
        recipe._particleModule = ParticleMock

        recipe:burst(1):at(150, 250)

        local call = ParticleMock.get_last_call()
        assert_equals(150, call.args.location.x)
        assert_equals(250, call.args.location.y)
    end)
end)
```

**Step 2: Run test to verify it fails**

**Step 3: Write minimal implementation**

Add Emission class to `particles.lua`:

```lua
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
    local pos = self._position

    -- Resolve random values
    local size = self:_randomRange(config.sizeMin or 6, config.sizeMax or 6)
    local lifespan = self:_randomRange(config.lifespanMin or 1, config.lifespanMax or 1)
    local velocity = self:_randomRange(config.velocityMin or 0, config.velocityMax or 0)

    -- Build angle (random direction by default)
    local angle = math.random() * math.pi * 2
    local vx = math.cos(angle) * velocity
    local vy = math.sin(angle) * velocity

    -- Map shape to C++ renderType
    local renderTypeMap = {
        circle = particleModule.ParticleRenderType and particleModule.ParticleRenderType.CIRCLE_FILLED or 4,
        rect = particleModule.ParticleRenderType and particleModule.ParticleRenderType.RECTANGLE_FILLED or 2,
        line = particleModule.ParticleRenderType and particleModule.ParticleRenderType.LINE_FACING or 8,
        sprite = particleModule.ParticleRenderType and particleModule.ParticleRenderType.TEXTURE or 0,
    }

    local opts = {
        renderType = renderTypeMap[config.shape] or renderTypeMap.circle,
        velocity = { x = vx, y = vy },
        lifespan = lifespan,
        gravity = config.gravity,
        startColor = config.startColor,
        endColor = config.endColor,
        rotationSpeed = config.spinMin and self:_randomRange(config.spinMin, config.spinMax),
        autoAspect = config.stretch,
        z = config.z,
        space = config.space,
    }

    local location = { x = pos.x, y = pos.y }
    local sizeVec = { x = size, y = size }

    particleModule.CreateParticle(location, sizeVec, opts, nil, nil)
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
```

**Step 4: Run test to verify it passes**

**Step 5: Commit**

```bash
git add assets/scripts/core/particles.lua assets/scripts/tests/test_particle_builder.lua
git commit -m "feat(particles): add Emission with burst() and at()"
```

---

## Task 9: Emission - Position Modes (inCircle, inRect, from/toward)

**Files:**
- Modify: `assets/scripts/core/particles.lua`
- Modify: `assets/scripts/tests/test_particle_builder.lua`

**Step 1: Write failing tests**

```lua
TestRunner.describe("Emission positioning", function()
    it("inCircle() spawns within radius", function()
        local Particles = require("core.particles")
        ParticleMock.reset()

        local recipe = Particles.define():shape("circle"):size(4)
        recipe._particleModule = ParticleMock

        recipe:burst(10):inCircle(100, 100, 50)

        assert_equals(10, ParticleMock.get_call_count())
        -- All particles should be within 50 units of (100,100)
        for _, call in ipairs(ParticleMock.calls) do
            local dx = call.args.location.x - 100
            local dy = call.args.location.y - 100
            local dist = math.sqrt(dx*dx + dy*dy)
            assert_true(dist <= 50, "particle outside circle")
        end
    end)

    it("inRect() spawns within rectangle", function()
        local Particles = require("core.particles")
        ParticleMock.reset()

        local recipe = Particles.define():shape("circle"):size(4)
        recipe._particleModule = ParticleMock

        recipe:burst(10):inRect(100, 100, 50, 30)

        for _, call in ipairs(ParticleMock.calls) do
            local x, y = call.args.location.x, call.args.location.y
            assert_true(x >= 100 and x <= 150, "x outside rect")
            assert_true(y >= 100 and y <= 130, "y outside rect")
        end
    end)

    it("from/toward sets directed velocity", function()
        local Particles = require("core.particles")
        ParticleMock.reset()

        local recipe = Particles.define():shape("circle"):size(4):velocity(100)
        recipe._particleModule = ParticleMock

        recipe:burst(1):from(0, 0):toward(100, 0)

        local call = ParticleMock.get_last_call()
        -- Velocity should be positive X (toward target)
        assert_true(call.args.opts.velocity.x > 0, "velocity should point toward target")
    end)
end)
```

**Step 2: Run test to verify it fails**

**Step 3: Write minimal implementation**

```lua
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
```

Update `_spawnSingle` to handle spawn modes:

```lua
function EmissionMethods:_spawnSingle(particleModule, index, total)
    local config = self._recipe._config

    -- Resolve position based on spawn mode
    local pos
    if self._spawnMode == "circle" then
        local angle = math.random() * math.pi * 2
        local r = math.sqrt(math.random()) * self._spawnRadius  -- sqrt for uniform distribution
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

    -- Resolve velocity
    local velocity = self:_randomRange(config.velocityMin or 0, config.velocityMax or 0)
    local vx, vy

    if self._spawnMode == "toward" and self._towardPos then
        -- Direction toward target
        local dx = self._towardPos.x - pos.x
        local dy = self._towardPos.y - pos.y
        local dist = math.sqrt(dx*dx + dy*dy)
        if dist > 0 then
            vx = (dx / dist) * velocity
            vy = (dy / dist) * velocity
        else
            vx, vy = 0, 0
        end
    else
        -- Random direction
        local angle = math.random() * math.pi * 2
        vx = math.cos(angle) * velocity
        vy = math.sin(angle) * velocity
    end

    -- ... rest of _spawnSingle stays the same
```

**Step 4: Run test to verify it passes**

**Step 5: Commit**

```bash
git add assets/scripts/core/particles.lua assets/scripts/tests/test_particle_builder.lua
git commit -m "feat(particles): add inCircle(), inRect(), from/toward positioning"
```

---

## Task 10: Emission - Direction Modifiers (spread, angle, outward)

**Files:**
- Modify: `assets/scripts/core/particles.lua`
- Modify: `assets/scripts/tests/test_particle_builder.lua`

**Step 1: Write failing tests**

```lua
TestRunner.describe("Emission direction", function()
    it("spread() limits angle range", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():shape("circle")
        local emission = recipe:burst(10):spread(30)
        assert_equals(30, emission._spread)
    end)

    it("angle() sets fixed angle", function()
        local Particles = require("core.particles")
        ParticleMock.reset()

        local recipe = Particles.define():shape("circle"):velocity(100)
        recipe._particleModule = ParticleMock

        recipe:burst(1):angle(0):at(0, 0)  -- angle 0 = right

        local call = ParticleMock.get_last_call()
        assert_true(call.args.opts.velocity.x > 0, "should point right")
        assert_true(math.abs(call.args.opts.velocity.y) < 1, "should have minimal y")
    end)

    it("outward() points away from spawn center", function()
        local Particles = require("core.particles")
        ParticleMock.reset()

        local recipe = Particles.define():shape("circle"):velocity(100)
        recipe._particleModule = ParticleMock

        recipe:burst(1):inCircle(100, 100, 50):outward()

        local call = ParticleMock.get_last_call()
        local px, py = call.args.location.x, call.args.location.y
        local vx, vy = call.args.opts.velocity.x, call.args.opts.velocity.y
        -- Velocity should point away from center (100, 100)
        local dx, dy = px - 100, py - 100
        local dot = dx * vx + dy * vy
        assert_true(dot >= 0, "velocity should point outward")
    end)
end)
```

**Step 2: Run test to verify it fails**

**Step 3: Write minimal implementation**

```lua
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
```

Update velocity calculation in `_spawnSingle`:

```lua
-- Determine base angle
local baseAngle
if self._angleMin then
    baseAngle = math.rad(self:_randomRange(self._angleMin, self._angleMax))
elseif self._directionMode == "outward" and self._spawnCenter then
    local dx = pos.x - self._spawnCenter.x
    local dy = pos.y - self._spawnCenter.y
    baseAngle = math.atan2(dy, dx)
elseif self._directionMode == "inward" and self._spawnCenter then
    local dx = self._spawnCenter.x - pos.x
    local dy = self._spawnCenter.y - pos.y
    baseAngle = math.atan2(dy, dx)
elseif self._spawnMode == "toward" and self._towardPos then
    local dx = self._towardPos.x - pos.x
    local dy = self._towardPos.y - pos.y
    baseAngle = math.atan2(dy, dx)
else
    baseAngle = math.random() * math.pi * 2
end

-- Apply spread
if self._spread then
    local spreadRad = math.rad(self._spread)
    baseAngle = baseAngle + (math.random() * 2 - 1) * spreadRad
end

vx = math.cos(baseAngle) * velocity
vy = math.sin(baseAngle) * velocity
```

**Step 4: Run test to verify it passes**

**Step 5: Commit**

```bash
git add assets/scripts/core/particles.lua assets/scripts/tests/test_particle_builder.lua
git commit -m "feat(particles): add spread(), angle(), outward/inward direction modes"
```

---

## Task 11: Emission - override() and each()

**Files:**
- Modify: `assets/scripts/core/particles.lua`
- Modify: `assets/scripts/tests/test_particle_builder.lua`

**Step 1: Write failing tests**

```lua
TestRunner.describe("Emission customization", function()
    it("override() applies property overrides", function()
        local Particles = require("core.particles")
        ParticleMock.reset()

        local recipe = Particles.define():shape("circle"):size(6):color("red")
        recipe._particleModule = ParticleMock

        recipe:burst(1):override({ size = 12 }):at(0, 0)

        local call = ParticleMock.get_last_call()
        assert_equals(12, call.args.size.x)
    end)

    it("each() applies per-particle function", function()
        local Particles = require("core.particles")
        ParticleMock.reset()

        local recipe = Particles.define():shape("circle"):size(4)
        recipe._particleModule = ParticleMock

        recipe:burst(5):each(function(i, total)
            return { size = i * 2 }
        end):at(0, 0)

        -- Each particle should have increasing size
        for i, call in ipairs(ParticleMock.calls) do
            assert_equals(i * 2, call.args.size.x)
        end
    end)
end)
```

**Step 2: Run test to verify it fails**

**Step 3: Write minimal implementation**

```lua
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
```

Update `_spawnSingle` to use overrides:

```lua
function EmissionMethods:_spawnSingle(particleModule, index, total)
    local config = self._recipe._config

    -- Get per-particle overrides
    local perParticle = {}
    if self._eachFn then
        perParticle = self._eachFn(index, total) or {}
    end

    -- Merge: recipe config < emission overrides < per-particle
    local function getValue(key, default)
        if perParticle[key] ~= nil then return perParticle[key] end
        if self._overrides and self._overrides[key] ~= nil then return self._overrides[key] end
        return config[key] or default
    end

    -- Resolve size (check override first)
    local size
    if perParticle.size then
        size = perParticle.size
    elseif self._overrides and self._overrides.size then
        size = self._overrides.size
    else
        size = self:_randomRange(config.sizeMin or 6, config.sizeMax or 6)
    end

    -- ... continue using getValue() for other properties
```

**Step 4: Run test to verify it passes**

**Step 5: Commit**

```bash
git add assets/scripts/core/particles.lua assets/scripts/tests/test_particle_builder.lua
git commit -m "feat(particles): add override() and each() customization"
```

---

## Task 12: Handle - stream(), every(), attachTo()

**Files:**
- Modify: `assets/scripts/core/particles.lua`
- Modify: `assets/scripts/tests/test_particle_builder.lua`

**Step 1: Write failing tests**

```lua
TestRunner.describe("Handle streams", function()
    it("stream() returns Handle", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():shape("circle")
        local handle = recipe:stream()
        assert_not_nil(handle)
        assert_not_nil(handle.stop)
        assert_not_nil(handle.pause)
    end)

    it("every() sets emission rate", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():shape("circle")
        local handle = recipe:stream():every(0.1)
        assert_equals(0.1, handle._rate)
    end)

    it("for() sets duration limit", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():shape("circle")
        local handle = recipe:stream():every(0.1):for(2.0)
        assert_equals(2.0, handle._duration)
    end)

    it("times() sets count limit", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():shape("circle")
        local handle = recipe:stream():every(0.1):times(50)
        assert_equals(50, handle._maxCount)
    end)

    it("stop() sets active to false", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():shape("circle")
        local handle = recipe:stream():every(0.1):at(0, 0)
        handle:stop()
        assert_equals(false, handle._active)
    end)
end)
```

**Step 2: Run test to verify it fails**

**Step 3: Write minimal implementation**

```lua
--------------------------------------------------------------------------------
-- HANDLE (for streams)
--------------------------------------------------------------------------------

local HandleMethods = {}
HandleMethods.__index = HandleMethods

--- Set emission rate
--- @param seconds number Time between emissions
--- @return self
function HandleMethods:every(seconds)
    self._rate = seconds
    return self
end

--- Set duration limit
--- @param seconds number Max duration in seconds
--- @return self
function HandleMethods:for(seconds)
    self._duration = seconds
    return self
end

--- Set particle count limit
--- @param count number Max particles to emit
--- @return self
function HandleMethods:times(count)
    self._maxCount = count
    return self
end

--- Set position and start streaming
--- @param x number X position
--- @param y number Y position
--- @return self
function HandleMethods:at(x, y)
    self._position = { x = x, y = y }
    self:_start()
    return self
end

--- Attach to entity (follows entity position)
--- @param entity userdata Entity to follow
--- @param opts table? { offset = Vec2, inheritRotation = bool }
--- @return self
function HandleMethods:attachTo(entity, opts)
    self._attachEntity = entity
    self._attachOpts = opts or {}
    self:_start()
    return self
end

--- Stop emitting
function HandleMethods:stop()
    self._active = false
end

--- Pause emitting (can resume)
function HandleMethods:pause()
    self._paused = true
end

--- Resume after pause
function HandleMethods:resume()
    self._paused = false
end

--- Check if still active
--- @return boolean
function HandleMethods:isActive()
    return self._active and not self._paused
end

--- Stop and clean up
function HandleMethods:destroy()
    self._active = false
    self._destroyed = true
end

--- Internal: Start the stream
function HandleMethods:_start()
    self._active = true
    self._paused = false
    self._elapsed = 0
    self._emitCount = 0
    self._lastEmit = 0

    -- Register with update system
    Particles._registerHandle(self)
end

--- Internal: Update (called each frame)
function HandleMethods:_update(dt)
    if not self._active or self._paused then return end

    self._elapsed = self._elapsed + dt

    -- Check duration limit
    if self._duration and self._elapsed >= self._duration then
        self:stop()
        return
    end

    -- Check count limit
    if self._maxCount and self._emitCount >= self._maxCount then
        self:stop()
        return
    end

    -- Emit if rate elapsed
    if self._elapsed - self._lastEmit >= self._rate then
        self._lastEmit = self._elapsed
        self:_emit()
        self._emitCount = self._emitCount + 1
    end
end

--- Internal: Emit one particle
function HandleMethods:_emit()
    local pos = self._position
    if self._attachEntity then
        -- Get entity position (will need component_cache in real impl)
        pos = self:_getEntityPosition()
    end

    -- Create single-particle burst emission
    local emission = self._recipe:burst(1)
    emission._position = pos
    emission:_spawn()
end

--- Create a stream handle
--- @return Handle
function RecipeMethods:stream()
    local handle = setmetatable({}, HandleMethods)
    handle._recipe = self
    handle._rate = 0.1  -- default 10 per second
    handle._active = false
    return handle
end
```

Add handle registry to Particles module:

```lua
-- Active handles
Particles._handles = {}

function Particles._registerHandle(handle)
    table.insert(Particles._handles, handle)
end

--- Update all active streams (call from game loop)
function Particles.update(dt)
    for i = #Particles._handles, 1, -1 do
        local handle = Particles._handles[i]
        if handle._destroyed then
            table.remove(Particles._handles, i)
        else
            handle:_update(dt)
        end
    end
end
```

**Step 4: Run test to verify it passes**

**Step 5: Commit**

```bash
git add assets/scripts/core/particles.lua assets/scripts/tests/test_particle_builder.lua
git commit -m "feat(particles): add Handle with stream(), every(), attachTo()"
```

---

## Task 13: Particles.mix() for Multiple Recipes

**Files:**
- Modify: `assets/scripts/core/particles.lua`
- Modify: `assets/scripts/tests/test_particle_builder.lua`

**Step 1: Write failing tests**

```lua
TestRunner.describe("Particles.mix", function()
    it("mix() with equal weight recipes", function()
        local Particles = require("core.particles")
        ParticleMock.reset()

        local r1 = Particles.define():shape("circle"):size(4)
        local r2 = Particles.define():shape("rect"):size(8)
        r1._particleModule = ParticleMock
        r2._particleModule = ParticleMock

        local mixed = Particles.mix(r1, r2)
        mixed._particleModule = ParticleMock
        mixed:burst(10):at(0, 0)

        assert_equals(10, ParticleMock.get_call_count())
    end)

    it("mix() with weighted recipes", function()
        local Particles = require("core.particles")
        ParticleMock.reset()

        local r1 = Particles.define():shape("circle"):size(4)
        local r2 = Particles.define():shape("rect"):size(8)
        r1._particleModule = ParticleMock
        r2._particleModule = ParticleMock

        -- 80% r1, 20% r2
        local mixed = Particles.mix({ r1, 8 }, { r2, 2 })
        mixed._particleModule = ParticleMock
        mixed:burst(100):at(0, 0)

        -- Count shapes
        local circles, rects = 0, 0
        for _, call in ipairs(ParticleMock.calls) do
            local rt = call.args.opts.renderType
            if rt == 4 then circles = circles + 1
            elseif rt == 2 then rects = rects + 1
            end
        end

        -- Should be roughly 80/20 split (allow some variance)
        assert_true(circles > 60, "expected ~80 circles, got " .. circles)
        assert_true(rects > 10, "expected ~20 rects, got " .. rects)
    end)
end)
```

**Step 2: Run test to verify it fails**

**Step 3: Write minimal implementation**

```lua
--- Create a mixed recipe from multiple recipes
--- @param ... Recipe|{Recipe, number} Recipes with optional weights
--- @return MixedRecipe
function Particles.mix(...)
    local args = {...}
    local entries = {}
    local totalWeight = 0

    for _, arg in ipairs(args) do
        if type(arg) == "table" and arg._config then
            -- Plain recipe, weight = 1
            table.insert(entries, { recipe = arg, weight = 1 })
            totalWeight = totalWeight + 1
        elseif type(arg) == "table" and arg[1] then
            -- Weighted: { recipe, weight }
            local recipe, weight = arg[1], arg[2] or 1
            table.insert(entries, { recipe = recipe, weight = weight })
            totalWeight = totalWeight + weight
        end
    end

    -- Create a pseudo-recipe that delegates to random selection
    local mixed = {
        _entries = entries,
        _totalWeight = totalWeight,
        _particleModule = nil,
    }

    function mixed:burst(count)
        local emission = setmetatable({}, EmissionMethods)
        emission._recipe = self
        emission._count = count
        emission._mode = "burst"
        emission._isMixed = true
        return emission
    end

    -- Select random recipe based on weights
    function mixed:_selectRecipe()
        local r = math.random() * self._totalWeight
        local cumulative = 0
        for _, entry in ipairs(self._entries) do
            cumulative = cumulative + entry.weight
            if r <= cumulative then
                return entry.recipe
            end
        end
        return self._entries[1].recipe
    end

    return mixed
end
```

Update `_spawnSingle` to handle mixed recipes:

```lua
function EmissionMethods:_spawnSingle(particleModule, index, total)
    local recipe = self._recipe

    -- For mixed recipes, select one
    if recipe._selectRecipe then
        recipe = recipe:_selectRecipe()
    end

    local config = recipe._config
    -- ... rest stays the same
```

**Step 4: Run test to verify it passes**

**Step 5: Commit**

```bash
git add assets/scripts/core/particles.lua assets/scripts/tests/test_particle_builder.lua
git commit -m "feat(particles): add Particles.mix() for weighted recipe selection"
```

---

## Task 14: C++ ShaderParticleTag Component

**Files:**
- Modify: `src/systems/particles/particle.hpp`

**Step 1: Write failing C++ test**

Add to `tests/unit/test_particle_system.cpp` (create if needed):

```cpp
#include <gtest/gtest.h>
#include "systems/particles/particle.hpp"
#include <entt/entt.hpp>

TEST(ParticleSystem, ShaderParticleTagExists) {
    entt::registry registry;
    auto entity = registry.create();

    registry.emplace<particle::ShaderParticleTag>(entity);

    EXPECT_TRUE(registry.all_of<particle::ShaderParticleTag>(entity));
}

TEST(ParticleSystem, DrawParticlesExcludesTaggedEntities) {
    // This test verifies the exclusion logic
    entt::registry registry;

    // Create regular particle
    auto regular = registry.create();
    registry.emplace<particle::Particle>(regular);
    registry.emplace<transform::Transform>(regular);

    // Create shader particle (should be excluded)
    auto shaderParticle = registry.create();
    registry.emplace<particle::Particle>(shaderParticle);
    registry.emplace<transform::Transform>(shaderParticle);
    registry.emplace<particle::ShaderParticleTag>(shaderParticle);

    // View with exclusion
    auto view = registry.view<particle::Particle, transform::Transform>(
        entt::exclude<particle::ShaderParticleTag>);

    int count = 0;
    for (auto entity : view) {
        count++;
        EXPECT_EQ(entity, regular);
    }

    EXPECT_EQ(count, 1);
}
```

**Step 2: Run test to verify it fails**

```bash
cd /Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/.worktrees/particle-builder
just build-debug && ./build/tests/unit_tests --gtest_filter="ParticleSystem.*"
```

**Step 3: Write minimal implementation**

Add to `particle.hpp` after `ParticleTag`:

```cpp
// Marker component for particles that use shader pipeline
// Particles with this tag are excluded from DrawParticles()
// and rendered via local_command instead
struct ShaderParticleTag {};
```

Update `DrawParticles` function to exclude tagged entities (around line 375):

```cpp
inline void DrawParticles(entt::registry &registry,
                          layer::CommandBuffer &sprites) {
  // Exclude shader particles - they're rendered via local_command
  auto view = registry.view<Particle, transform::Transform>(
      entt::exclude<ShaderParticleTag>);

  // ... rest of function stays the same
```

**Step 4: Run test to verify it passes**

**Step 5: Commit**

```bash
git add src/systems/particles/particle.hpp tests/unit/test_particle_system.cpp
git commit -m "feat(particles): add ShaderParticleTag to exclude from DrawParticles"
```

---

## Task 15: Lua Binding for ShaderParticleTag

**Files:**
- Modify: `src/systems/scripting/scripting_functions.cpp` (where particle bindings are)

**Step 1: Write integration test in Lua test file**

```lua
TestRunner.describe("ShaderParticleTag binding", function()
    it("ShaderParticleTag is accessible from Lua", function()
        -- This test requires real bindings, skip in mock mode
        if not _G.particle or not _G.particle.ShaderParticleTag then
            print("  [SKIP] ShaderParticleTag binding not available in test mode")
            return
        end
        assert_not_nil(_G.particle.ShaderParticleTag)
    end)
end)
```

**Step 2: Run test (will skip in pure Lua mode, pass in game)**

**Step 3: Write implementation**

Find where particle bindings are exposed in `scripting_functions.cpp` and add:

```cpp
// In the particle namespace bindings
particle_ns["ShaderParticleTag"] = sol::object(state.lua_state(), sol::in_place_type<particle::ShaderParticleTag>);

// Also expose as a type for emplace
particle_ns.new_usertype<particle::ShaderParticleTag>("ShaderParticleTag",
    sol::constructors<particle::ShaderParticleTag()>()
);
```

**Step 4: Build and run tests**

**Step 5: Commit**

```bash
git add src/systems/scripting/scripting_functions.cpp
git commit -m "feat(particles): expose ShaderParticleTag to Lua"
```

---

## Task 16: Shader Particle Spawn Path

**Files:**
- Modify: `assets/scripts/core/particles.lua`
- Modify: `assets/scripts/tests/test_particle_builder.lua`

**Step 1: Write failing test**

```lua
TestRunner.describe("Shader particles", function()
    it("particles with shaders add ShaderParticleTag", function()
        local Particles = require("core.particles")
        ParticleMock.reset()

        -- Mock registry and ShaderBuilder
        local tagAdded = false
        local mockRegistry = {
            emplace = function(self, entity, component)
                if component == "ShaderParticleTag" then
                    tagAdded = true
                end
            end
        }

        local recipe = Particles.define()
            :shape("circle")
            :size(6)
            :shaders({ "glow" })
        recipe._particleModule = ParticleMock
        recipe._registry = mockRegistry

        recipe:burst(1):at(0, 0)

        assert_true(tagAdded, "ShaderParticleTag should be added")
    end)
end)
```

**Step 2: Run test to verify it fails**

**Step 3: Write implementation**

Update `_spawnSingle` in `particles.lua`:

```lua
function EmissionMethods:_spawnSingle(particleModule, index, total)
    -- ... existing code to build opts ...

    local entity = particleModule.CreateParticle(location, sizeVec, opts, animConfig, nil)

    -- If shaders specified, add ShaderParticleTag and set up shader pipeline
    if config.shaders and #config.shaders > 0 then
        local registry = self._recipe._registry or _G.registry
        local ShaderBuilder = require("core.shader_builder")

        -- Add exclusion tag
        if registry and particleModule.ShaderParticleTag then
            registry:emplace(entity, particleModule.ShaderParticleTag)
        end

        -- Apply shaders
        local builder = ShaderBuilder.for_entity(entity)
        for _, shader in ipairs(config.shaders) do
            builder:add(shader, config.shaderUniforms)
        end
        builder:apply()

        -- TODO: Set up local_command for custom draw
    end

    return entity
end
```

**Step 4: Run test to verify it passes**

**Step 5: Commit**

```bash
git add assets/scripts/core/particles.lua assets/scripts/tests/test_particle_builder.lua
git commit -m "feat(particles): add shader particle spawn path with ShaderParticleTag"
```

---

## Task 17: Custom drawCommand Support

**Files:**
- Modify: `assets/scripts/core/particles.lua`
- Modify: `assets/scripts/tests/test_particle_builder.lua`

**Step 1: Write failing test**

```lua
TestRunner.describe("Custom drawCommand", function()
    it("drawCommand() stores draw function", function()
        local Particles = require("core.particles")
        local fn = function(p) return { type = "circle" } end
        local recipe = Particles.define():drawCommand(fn)
        assert_equals(fn, recipe._config.drawCommand)
    end)

    it("drawCommand receives particle state", function()
        local Particles = require("core.particles")
        local received = nil

        local recipe = Particles.define()
            :drawCommand(function(p)
                received = p
                return { type = "circle", x = p.x, y = p.y, radius = 5 }
            end)
            :shaders({ "glow" })

        -- This test needs integration with actual rendering
        -- For now just verify the function is stored
        assert_not_nil(recipe._config.drawCommand)
    end)
end)
```

**Step 2: Run test to verify it fails**

**Step 3: Write implementation**

```lua
--- Set custom draw command function
--- @param fn function(particle) -> { type, x, y, ... }
--- @return self
function RecipeMethods:drawCommand(fn)
    self._config.drawCommand = fn
    return self
end
```

**Step 4: Run test to verify it passes**

**Step 5: Commit**

```bash
git add assets/scripts/core/particles.lua assets/scripts/tests/test_particle_builder.lua
git commit -m "feat(particles): add drawCommand() for custom rendering"
```

---

## Task 18: Integration with draw.local_command

**Files:**
- Modify: `assets/scripts/core/particles.lua`

**Step 1: Document the integration point**

This requires the particle update loop to call `draw.local_command` for shader particles. The full implementation depends on how the game loop is structured.

**Step 2: Write implementation sketch**

```lua
-- In ParticleManager or update system, for each shader particle:
function Particles._updateShaderParticle(entity, particle, dt, config)
    local draw = require("core.draw")

    -- Get current particle state
    local p = {
        x = particle.position.x,
        y = particle.position.y,
        velocity = particle.velocity,
        age = particle.age,
        lifespan = particle.lifespan,
        progress = particle.age / particle.lifespan,
        scale = particle.scale,
        rotation = particle.rotation,
        alpha = particle.alpha,
        color = particle.color,
        data = particle.data,
    }

    -- Get draw props from custom function or default
    local props
    if config.drawCommand then
        props = config.drawCommand(p)
    else
        props = {
            type = "circle",
            x = p.x,
            y = p.y,
            radius = p.scale * (config.sizeMin or 6),
            color = p.color,
        }
    end

    -- Issue local command
    draw.local_command(entity, props.type, props, {
        z = config.z or 0,
    })
end
```

**Step 3: Commit documentation**

```bash
git add assets/scripts/core/particles.lua
git commit -m "docs(particles): add local_command integration sketch"
```

---

## Task 19: Visual Test Scene

**Files:**
- Create: `assets/scripts/test_scenes/particle_test_scene.lua`

**Step 1: Create test scene**

```lua
-- assets/scripts/test_scenes/particle_test_scene.lua
--[[
Visual test scene for particle builder.
Run in-game to verify particle effects work correctly.
]]

local Particles = require("core.particles")

local ParticleTestScene = {}

function ParticleTestScene.run()
    print("=== Particle Builder Visual Tests ===")

    -- Test 1: Basic burst
    print("Test 1: Basic circle burst")
    local spark = Particles.define()
        :shape("circle")
        :size(4, 8)
        :color("orange", "red")
        :fade()
        :lifespan(0.5)
        :velocity(50, 100)
        :gravity(100)

    spark:burst(20):at(200, 200)

    -- Test 2: Rect particles with spin
    print("Test 2: Spinning rectangles")
    local confetti = Particles.define()
        :shape("rect")
        :size(8, 12)
        :color("blue", "purple")
        :spin(180, 360)
        :fade()
        :lifespan(1)
        :gravity(50)

    confetti:burst(30):at(400, 200)

    -- Test 3: Area spawn
    print("Test 3: Circle area spawn")
    local dust = Particles.define()
        :shape("circle")
        :size(2, 4)
        :color("white", "gray")
        :fade()
        :lifespan(0.8)

    dust:burst(50):inCircle(300, 400, 100):outward():velocity(30, 50)

    -- Test 4: Stream
    print("Test 4: Particle stream (5 seconds)")
    local smoke = Particles.define()
        :shape("circle")
        :size(6, 12)
        :color("gray", "transparent")
        :grow(1, 2)
        :fade()
        :lifespan(1, 2)
        :velocity(10, 30)
        :gravity(-20)

    local handle = smoke:stream():every(0.1):for(5):at(500, 500)

    -- Test 5: Mixed recipes
    print("Test 5: Mixed particle types")
    local star = Particles.define():shape("circle"):size(6):color("yellow"):fade()
    local ring = Particles.define():shape("circle"):size(3):color("cyan"):fade()

    Particles.mix(star, ring):burst(40):at(600, 300)

    print("=== Tests running ===")
end

return ParticleTestScene
```

**Step 2: Commit**

```bash
git add assets/scripts/test_scenes/particle_test_scene.lua
git commit -m "test: add visual test scene for particle builder"
```

---

## Task 20: Documentation and Cleanup

**Files:**
- Update: `CLAUDE.md` with Particle Builder section
- Final: `assets/scripts/core/particles.lua` cleanup

**Step 1: Add documentation to CLAUDE.md**

Add section after Physics Builder API:

```markdown
---

## Particle Builder API

### Fluent Particle Effects

```lua
local Particles = require("core.particles")

-- Define a reusable recipe
local spark = Particles.define()
    :shape("circle")           -- circle, rect, line, sprite
    :size(4, 8)                -- random range
    :color("orange", "red")    -- start -> end
    :fade()
    :lifespan(0.3, 0.5)
    :velocity(100, 200)
    :gravity(200)

-- Burst at a point
spark:burst(10):at(x, y)

-- Area spawn
spark:burst(20):inCircle(x, y, radius):outward()

-- Stream attached to entity
local handle = spark:stream():every(0.05):attachTo(entity)
handle:stop()
```

### Recipe Methods

| Method | Description |
|--------|-------------|
| `:shape(type, id?)` | circle, rect, line, sprite |
| `:size(min, max?)` | Particle size |
| `:color(start, end?)` | Color interpolation |
| `:lifespan(min, max?)` | Lifetime in seconds |
| `:velocity(min, max?)` | Speed in pixels/sec |
| `:gravity(strength)` | Gravity pull |
| `:drag(factor)` | Velocity damping |
| `:fade()` | Alpha 1->0 |
| `:shrink()` | Scale 1->0 |
| `:spin(speed)` | Rotation speed |
| `:shaders({...})` | Apply shaders |
```

**Step 2: Final code cleanup**

Ensure all functions have proper LuaLS annotations.

**Step 3: Commit**

```bash
git add CLAUDE.md assets/scripts/core/particles.lua
git commit -m "docs: add Particle Builder documentation to CLAUDE.md"
```

---

## Summary

**Total Tasks:** 20
**Estimated Implementation:** Each task is 2-5 minutes of focused work.

**Key Checkpoints:**
- Task 8: Basic burst spawning works
- Task 12: Streams work
- Task 16: Shader particles work
- Task 19: Visual verification

**Test Strategy:**
- Pure Lua unit tests with mocks for quick iteration
- Integration tests require game running
- Visual test scene for final verification

**After completing all tasks:** Run full test suite and visual tests to verify compatibility with existing C++ bindings.

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
