--[[
================================================================================
TEST: Steering Behavior Debug Visualization
================================================================================
Tests for the steering debug module that tracks behavior vectors for visualization.

TDD Approach:
- RED: Tests fail before implementation
- GREEN: Implement, tests pass

Run with: lua assets/scripts/tests/test_steering_debug.lua
]]

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

-- Clear cached module
package.loaded["core.steering_debug"] = nil
_G.steering_debug = nil

local t = require("tests.test_runner")

--------------------------------------------------------------------------------
-- Tests: Module API
--------------------------------------------------------------------------------

t.describe("steering_debug - Module API", function()

    t.it("can be required", function()
        local steering_debug = require("core.steering_debug")
        t.expect(steering_debug).to_be_truthy()
    end)

    t.it("has enable/disable functions", function()
        local steering_debug = require("core.steering_debug")
        t.expect(type(steering_debug.enable)).to_be("function")
        t.expect(type(steering_debug.disable)).to_be("function")
        t.expect(type(steering_debug.is_enabled)).to_be("function")
    end)

    t.it("has add_behavior_vector function", function()
        local steering_debug = require("core.steering_debug")
        t.expect(type(steering_debug.add_behavior_vector)).to_be("function")
    end)

    t.it("has set_final_vector function", function()
        local steering_debug = require("core.steering_debug")
        t.expect(type(steering_debug.set_final_vector)).to_be("function")
    end)

    t.it("has get_entity_vectors function", function()
        local steering_debug = require("core.steering_debug")
        t.expect(type(steering_debug.get_entity_vectors)).to_be("function")
    end)

    t.it("has clear_entity function", function()
        local steering_debug = require("core.steering_debug")
        t.expect(type(steering_debug.clear_entity)).to_be("function")
    end)
end)

--------------------------------------------------------------------------------
-- Tests: No-op when disabled
--------------------------------------------------------------------------------

t.describe("steering_debug - No-op when disabled", function()

    t.it("is disabled by default", function()
        package.loaded["core.steering_debug"] = nil
        local steering_debug = require("core.steering_debug")
        t.expect(steering_debug.is_enabled()).to_be(false)
    end)

    t.it("does not store data when disabled", function()
        package.loaded["core.steering_debug"] = nil
        local steering_debug = require("core.steering_debug")
        steering_debug.disable()

        steering_debug.add_behavior_vector(1, "flee", 10, 20, 0.5)
        steering_debug.set_final_vector(1, 15, 25)

        local vectors = steering_debug.get_entity_vectors(1)
        t.expect(vectors).to_be_falsy()
    end)

    t.it("calls are safe when disabled", function()
        package.loaded["core.steering_debug"] = nil
        local steering_debug = require("core.steering_debug")
        steering_debug.disable()

        -- Should not error
        steering_debug.add_behavior_vector(1, "test", 0, 0, 1)
        steering_debug.set_final_vector(1, 0, 0)
        steering_debug.clear_entity(1)

        t.expect(true).to_be(true)
    end)
end)

--------------------------------------------------------------------------------
-- Tests: Behavior vectors
--------------------------------------------------------------------------------

t.describe("steering_debug - Behavior vectors", function()

    t.it("stores behavior vectors", function()
        package.loaded["core.steering_debug"] = nil
        local steering_debug = require("core.steering_debug")
        steering_debug.enable()

        steering_debug.add_behavior_vector(42, "flee", 10, -5, 0.8)
        steering_debug.add_behavior_vector(42, "attack", 5, 3, 0.5)

        local vectors = steering_debug.get_entity_vectors(42)
        t.expect(vectors).to_be_truthy()
        t.expect(vectors.behaviors).to_be_truthy()
        t.expect(#vectors.behaviors).to_be(2)

        t.expect(vectors.behaviors[1].name).to_be("flee")
        t.expect(vectors.behaviors[1].x).to_be(10)
        t.expect(vectors.behaviors[1].y).to_be(-5)
        t.expect(vectors.behaviors[1].weight).to_be(0.8)

        steering_debug.disable()
    end)

    t.it("stores final blended vector", function()
        package.loaded["core.steering_debug"] = nil
        local steering_debug = require("core.steering_debug")
        steering_debug.enable()

        steering_debug.set_final_vector(42, 12.5, -2.5)

        local vectors = steering_debug.get_entity_vectors(42)
        t.expect(vectors.final).to_be_truthy()
        t.expect(vectors.final.x).to_be(12.5)
        t.expect(vectors.final.y).to_be(-2.5)

        steering_debug.disable()
    end)

    t.it("clears vectors at frame boundary", function()
        package.loaded["core.steering_debug"] = nil
        local steering_debug = require("core.steering_debug")
        steering_debug.enable()

        steering_debug.add_behavior_vector(42, "flee", 10, 5, 1)
        steering_debug.begin_frame()  -- Clear for new frame

        local vectors = steering_debug.get_entity_vectors(42)
        t.expect(vectors).to_be_falsy()

        steering_debug.disable()
    end)

    t.it("clears specific entity data", function()
        package.loaded["core.steering_debug"] = nil
        local steering_debug = require("core.steering_debug")
        steering_debug.enable()

        steering_debug.add_behavior_vector(42, "flee", 10, 5, 1)
        steering_debug.add_behavior_vector(99, "attack", 5, 3, 1)
        steering_debug.clear_entity(42)

        local vectors42 = steering_debug.get_entity_vectors(42)
        local vectors99 = steering_debug.get_entity_vectors(99)

        t.expect(vectors42).to_be_falsy()
        t.expect(vectors99).to_be_truthy()

        steering_debug.disable()
    end)
end)

--------------------------------------------------------------------------------
-- Tests: Multiple entities
--------------------------------------------------------------------------------

t.describe("steering_debug - Multiple entities", function()

    t.it("tracks vectors separately per entity", function()
        package.loaded["core.steering_debug"] = nil
        local steering_debug = require("core.steering_debug")
        steering_debug.enable()

        steering_debug.add_behavior_vector(1, "flee", 10, 0, 1)
        steering_debug.add_behavior_vector(2, "attack", 0, 10, 1)

        local v1 = steering_debug.get_entity_vectors(1)
        local v2 = steering_debug.get_entity_vectors(2)

        t.expect(v1.behaviors[1].name).to_be("flee")
        t.expect(v2.behaviors[1].name).to_be("attack")

        steering_debug.disable()
    end)

    t.it("can get all tracked entities", function()
        package.loaded["core.steering_debug"] = nil
        local steering_debug = require("core.steering_debug")
        steering_debug.enable()

        steering_debug.add_behavior_vector(100, "a", 1, 1, 1)
        steering_debug.add_behavior_vector(200, "b", 1, 1, 1)
        steering_debug.add_behavior_vector(300, "c", 1, 1, 1)

        local entities = steering_debug.get_tracked_entities()
        t.expect(#entities).to_be(3)

        steering_debug.disable()
    end)
end)

--------------------------------------------------------------------------------
-- Tests: Vector metadata
--------------------------------------------------------------------------------

t.describe("steering_debug - Vector metadata", function()

    t.it("can set behavior color hint", function()
        package.loaded["core.steering_debug"] = nil
        local steering_debug = require("core.steering_debug")
        steering_debug.enable()

        steering_debug.add_behavior_vector(42, "flee", 10, 5, 1, { r = 255, g = 0, b = 0 })

        local vectors = steering_debug.get_entity_vectors(42)
        t.expect(vectors.behaviors[1].color).to_be_truthy()
        t.expect(vectors.behaviors[1].color.r).to_be(255)

        steering_debug.disable()
    end)

    t.it("can set entity position for visualization", function()
        package.loaded["core.steering_debug"] = nil
        local steering_debug = require("core.steering_debug")
        steering_debug.enable()

        steering_debug.set_entity_position(42, 100, 200)

        local vectors = steering_debug.get_entity_vectors(42)
        t.expect(vectors.position).to_be_truthy()
        t.expect(vectors.position.x).to_be(100)
        t.expect(vectors.position.y).to_be(200)

        steering_debug.disable()
    end)
end)

--------------------------------------------------------------------------------
-- Run Tests
--------------------------------------------------------------------------------

local success = t.run()
os.exit(success and 0 or 1)
