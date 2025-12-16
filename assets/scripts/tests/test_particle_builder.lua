-- assets/scripts/tests/test_particle_builder.lua
-- Set up package path for standalone execution
package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/tests/?.lua"

local TestRunner = require("test_runner")
local ParticleMock = require("mocks.particle_mock")
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

TestRunner.describe("Recipe behaviors", function()
    local assert_true = TestRunner.assert_true

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

TestRunner.describe("Emission burst", function()
    local assert_nil = TestRunner.assert_nil

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

TestRunner.describe("Emission positioning", function()
    local assert_true = TestRunner.assert_true

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

TestRunner.describe("Emission direction", function()
    local assert_true = TestRunner.assert_true

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

TestRunner.describe("Handle", function()
    local assert_true = TestRunner.assert_true
    local assert_false = TestRunner.assert_false

    it("stream() returns a Handle", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():shape("circle"):size(4)
        local emission = recipe:burst(1)
        emission._position = { x = 0, y = 0 }  -- Set position without spawning
        local handle = emission:stream()
        assert_not_nil(handle)
        assert_equals(type(handle.update), "function")
    end)

    it("every() sets spawn interval", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():shape("circle"):size(4)
        local emission = recipe:burst(1)
        emission._position = { x = 0, y = 0 }
        local handle = emission:stream():every(0.5)
        assert_equals(0.5, handle._interval)
    end)

    it("for_() sets duration", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():shape("circle"):size(4)
        local emission = recipe:burst(1)
        emission._position = { x = 0, y = 0 }
        local handle = emission:stream():for_(2.0)
        assert_equals(2.0, handle._duration)
    end)

    it("times() sets max count", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():shape("circle"):size(4)
        local emission = recipe:burst(1)
        emission._position = { x = 0, y = 0 }
        local handle = emission:stream():times(5)
        assert_equals(5, handle._maxCount)
    end)

    it("stop() deactivates handle", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():shape("circle"):size(4)
        local emission = recipe:burst(1)
        emission._position = { x = 0, y = 0 }
        local handle = emission:stream()
        assert_true(handle._active)
        handle:stop()
        assert_false(handle._active)
    end)

    it("update() spawns particles at interval", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():shape("circle"):size(4)
        recipe._particleModule = ParticleMock
        ParticleMock.reset()

        local emission = recipe:burst(2)
        emission._position = { x = 100, y = 100 }
        local handle = emission:stream():every(0.1)

        -- First update spawns immediately
        handle:update(0.0)
        assert_equals(2, ParticleMock.get_call_count())

        -- Not enough time passed
        handle:update(0.05)
        assert_equals(2, ParticleMock.get_call_count())

        -- Enough time passed, spawn again
        handle:update(0.06)
        assert_equals(4, ParticleMock.get_call_count())
    end)

    it("update() respects duration limit", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():shape("circle"):size(4)
        recipe._particleModule = ParticleMock
        ParticleMock.reset()

        local emission = recipe:burst(1)
        emission._position = { x = 0, y = 0 }
        local handle = emission:stream():every(0.1):for_(0.25)

        handle:update(0.0)   -- t=0.0, spawn
        handle:update(0.1)   -- t=0.1, spawn
        handle:update(0.1)   -- t=0.2, spawn
        handle:update(0.1)   -- t=0.3, exceeds duration, no spawn

        assert_equals(3, ParticleMock.get_call_count())
        assert_false(handle._active)
    end)

    it("update() respects times limit", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():shape("circle"):size(4)
        recipe._particleModule = ParticleMock
        ParticleMock.reset()

        local emission = recipe:burst(1)
        emission._position = { x = 0, y = 0 }
        local handle = emission:stream():every(0.1):times(2)

        handle:update(0.0)   -- spawn 1
        handle:update(0.1)   -- spawn 2
        handle:update(0.1)   -- would be spawn 3, but limited

        assert_equals(2, ParticleMock.get_call_count())
        assert_false(handle._active)
    end)

    it("attachTo() stores entity reference", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():shape("circle"):size(4)
        local emission = recipe:burst(1)
        emission._position = { x = 0, y = 0 }
        local mockEntity = { id = 123 }
        local handle = emission:stream():attachTo(mockEntity)
        assert_equals(mockEntity, handle._attachedEntity)
    end)
end)

TestRunner.describe("Particles.mix()", function()
    local assert_true = TestRunner.assert_true

    it("mix() creates MixedEmission from multiple recipes", function()
        local Particles = require("core.particles")
        local r1 = Particles.define():shape("circle"):size(4)
        local r2 = Particles.define():shape("rect"):size(8)

        local mixed = Particles.mix({ r1, r2 })
        assert_not_nil(mixed)
        assert_equals(2, #mixed._emissions)
    end)

    it("mix() with uniform burst spawns from all recipes", function()
        local Particles = require("core.particles")
        ParticleMock.reset()

        local r1 = Particles.define():shape("circle"):size(4)
        local r2 = Particles.define():shape("rect"):size(8)
        r1._particleModule = ParticleMock
        r2._particleModule = ParticleMock

        Particles.mix({ r1, r2 })
            :burst(3)  -- 3 of each = 6 total
            :at(100, 100)

        assert_equals(6, ParticleMock.get_call_count())
    end)

    it("mix() with per-recipe burst counts", function()
        local Particles = require("core.particles")
        ParticleMock.reset()

        local r1 = Particles.define():shape("circle"):size(4)
        local r2 = Particles.define():shape("rect"):size(8)
        r1._particleModule = ParticleMock
        r2._particleModule = ParticleMock

        Particles.mix({ r1, r2 })
            :burst(5, 2)  -- 5 from r1, 2 from r2 = 7 total
            :at(100, 100)

        assert_equals(7, ParticleMock.get_call_count())
    end)

    it("mix() position is shared across all recipes", function()
        local Particles = require("core.particles")
        ParticleMock.reset()

        local r1 = Particles.define():shape("circle"):size(4)
        local r2 = Particles.define():shape("rect"):size(8)
        r1._particleModule = ParticleMock
        r2._particleModule = ParticleMock

        Particles.mix({ r1, r2 })
            :burst(1, 1)
            :at(200, 300)

        -- Both particles should be at 200, 300
        local calls = ParticleMock.get_all_calls()
        assert_equals(200, calls[1].args.location.x)
        assert_equals(300, calls[1].args.location.y)
        assert_equals(200, calls[2].args.location.x)
        assert_equals(300, calls[2].args.location.y)
    end)

    it("mix() with inCircle distributes all recipes", function()
        local Particles = require("core.particles")
        ParticleMock.reset()

        local r1 = Particles.define():shape("circle"):size(4)
        local r2 = Particles.define():shape("rect"):size(8)
        r1._particleModule = ParticleMock
        r2._particleModule = ParticleMock

        Particles.mix({ r1, r2 })
            :burst(2, 2)
            :inCircle(100, 100, 50)

        assert_equals(4, ParticleMock.get_call_count())
        -- All should be within circle (distance <= 50 from center)
        local calls = ParticleMock.get_all_calls()
        for _, call in ipairs(calls) do
            local dx = call.args.location.x - 100
            local dy = call.args.location.y - 100
            local dist = math.sqrt(dx*dx + dy*dy)
            assert_true(dist <= 50.1, "particle should be within circle")
        end
    end)

    it("mix() stream() returns working Handle", function()
        local Particles = require("core.particles")
        ParticleMock.reset()

        local r1 = Particles.define():shape("circle"):size(4)
        local r2 = Particles.define():shape("rect"):size(8)
        r1._particleModule = ParticleMock
        r2._particleModule = ParticleMock

        local mixed = Particles.mix({ r1, r2 })
            :burst(1, 1)

        -- Set position without spawning (for stream usage)
        mixed._position = { x = 0, y = 0 }
        mixed._spawnMode = "at"
        -- Propagate position to child emissions
        for _, emission in ipairs(mixed._emissions) do
            emission._position = { x = 0, y = 0 }
        end

        local handle = mixed:stream()
            :every(0.1)

        handle:update(0.0)  -- First spawn: 2 particles
        assert_equals(2, ParticleMock.get_call_count())

        handle:update(0.1)  -- Second spawn: 2 more
        assert_equals(4, ParticleMock.get_call_count())
    end)
end)

TestRunner.describe("Shader Particle Path", function()
    local assert_true = TestRunner.assert_true

    it("_spawnSingle returns entity from CreateParticle", function()
        local Particles = require("core.particles")
        local recipe = Particles.define():shape("circle"):size(4)
        recipe._particleModule = ParticleMock
        ParticleMock.reset()

        local emission = recipe:burst(1)
        emission._count = 1
        emission._position = { x = 100, y = 100 }

        local entity = emission:_spawnSingle(ParticleMock, 1, 1)
        assert_not_nil(entity, "_spawnSingle should return entity")
        assert_equals(entity, ParticleMock.get_last_entity())
    end)

    it("particles with shaders get ShaderParticleTag", function()
        local Particles = require("core.particles")
        local recipe = Particles.define()
            :shape("circle")
            :size(4)
            :shaders({ "glow" })
        recipe._particleModule = ParticleMock
        ParticleMock.reset()

        -- Need to mock registry and shaders for this test
        local mockRegistry = {
            emplace_calls = {},
            emplace = function(self, entity, component)
                table.insert(self.emplace_calls, { entity = entity, component = component })
            end
        }
        recipe._registry = mockRegistry
        recipe._shadersModule = { ShaderParticleTag = {} }

        local emission = recipe:burst(1)
        emission._count = 1
        emission._position = { x = 0, y = 0 }

        local entity = emission:_spawnSingle(ParticleMock, 1, 1)

        -- Check that emplace was called for ShaderParticleTag
        assert_true(#mockRegistry.emplace_calls > 0, "should emplace ShaderParticleTag")
        assert_equals(mockRegistry.emplace_calls[1].entity, entity)
    end)

    it("particles without shaders do NOT get ShaderParticleTag", function()
        local Particles = require("core.particles")
        local recipe = Particles.define()
            :shape("circle")
            :size(4)
        recipe._particleModule = ParticleMock
        ParticleMock.reset()

        local mockRegistry = {
            emplace_calls = {},
            emplace = function(self, entity, component)
                table.insert(self.emplace_calls, { entity = entity, component = component })
            end
        }
        recipe._registry = mockRegistry

        local emission = recipe:burst(1)
        emission._count = 1
        emission._position = { x = 0, y = 0 }

        emission:_spawnSingle(ParticleMock, 1, 1)

        -- Should NOT have any emplace calls for ShaderParticleTag
        assert_equals(#mockRegistry.emplace_calls, 0, "should not emplace ShaderParticleTag")
    end)
end)

TestRunner.describe("Custom drawCommand", function()
    local assert_nil = TestRunner.assert_nil

    it("drawCommand() stores function in recipe", function()
        local Particles = require("core.particles")
        local drawFn = function(particle, props) end
        local recipe = Particles.define()
            :shape("circle")
            :size(4)
            :drawCommand(drawFn)

        assert_equals(recipe._drawCommand, drawFn)
    end)

    it("drawCommand() returns self for chaining", function()
        local Particles = require("core.particles")
        local recipe = Particles.define()
            :shape("circle")
            :drawCommand(function() end)
            :size(4)

        assert_equals(recipe._config.sizeMin, 4)
    end)

    it("getConfig() includes drawCommand when set", function()
        local Particles = require("core.particles")
        local drawFn = function(particle, props) end
        local recipe = Particles.define()
            :shape("circle")
            :size(4)
            :drawCommand(drawFn)

        local config = recipe:getConfig()
        assert_equals(config.drawCommand, drawFn)
    end)

    it("getConfig() drawCommand is nil when not set", function()
        local Particles = require("core.particles")
        local recipe = Particles.define()
            :shape("circle")
            :size(4)

        local config = recipe:getConfig()
        assert_nil(config.drawCommand)
    end)
end)

return function()
    TestRunner.run_all()
end
