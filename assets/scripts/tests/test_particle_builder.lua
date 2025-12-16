-- assets/scripts/tests/test_particle_builder.lua
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

return function()
    TestRunner.run_all()
end
