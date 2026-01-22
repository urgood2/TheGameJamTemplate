--[[
================================================================================
TEST: component_cache.safe_get improvements
================================================================================
Tests for improved error messages in component_cache.safe_get.

TDD Approach:
- RED: Tests fail before improvement
- GREEN: Implement improvements, tests pass

Run with: lua assets/scripts/tests/test_component_cache_safe_get.lua
]]

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

-- Track logged messages
local logged_messages = {}

-- Mock logging functions
_G.log_debug = function(...)
    local args = {...}
    local msg = table.concat(args, " ")
    table.insert(logged_messages, { level = "debug", message = msg })
end

_G.log_warn = function(...)
    local args = {...}
    local msg = table.concat(args, " ")
    table.insert(logged_messages, { level = "warn", message = msg })
end

-- Mock entity state
local valid_entities = {}
local entity_components = {}

-- Mock registry
_G.registry = {
    valid = function(self, eid)
        return valid_entities[eid] == true
    end,
    get = function(self, eid, comp)
        if not entity_components[eid] then return nil end
        return entity_components[eid][comp]
    end
}

-- Mock component types
_G.Transform = "Transform"
_G.GameObject = "GameObject"
_G.AnimationQueueComponent = "AnimationQueueComponent"

-- Mock frame counter
local frame_counter = 0
_G.GetFrameCount = function() return frame_counter end

-- Clear and reload component_cache
package.loaded["core.component_cache"] = nil
_G.component_cache = nil

local component_cache = require("core.component_cache")
local t = require("tests.test_runner")

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function clear_logs()
    logged_messages = {}
end

local function find_log(pattern)
    for _, log in ipairs(logged_messages) do
        if log.message:match(pattern) then
            return log
        end
    end
    return nil
end

local function create_entity(eid, components)
    valid_entities[eid] = true
    entity_components[eid] = components or {}
end

local function destroy_entity(eid)
    valid_entities[eid] = nil
    entity_components[eid] = nil
end

local function advance_frame()
    frame_counter = frame_counter + 1
    component_cache.update_frame()
end

--------------------------------------------------------------------------------
-- Tests: Basic functionality preserved
--------------------------------------------------------------------------------

t.describe("component_cache.safe_get - Basic functionality", function()

    t.it("returns nil, false for invalid entity", function()
        clear_logs()
        advance_frame()

        local comp, valid = component_cache.safe_get(99999, Transform)

        t.expect(comp).to_be_falsy()
        t.expect(valid).to_be(false)
    end)

    t.it("returns component, true for valid entity with component", function()
        clear_logs()
        advance_frame()

        local transform = { actualX = 100, actualY = 200 }
        create_entity(1001, { [Transform] = transform })

        local comp, valid = component_cache.safe_get(1001, Transform)

        t.expect(comp).to_be(transform)
        t.expect(valid).to_be(true)

        destroy_entity(1001)
    end)

    t.it("returns nil, true for valid entity missing component", function()
        clear_logs()
        advance_frame()

        create_entity(1002, {})  -- No components

        local comp, valid = component_cache.safe_get(1002, Transform)

        t.expect(comp).to_be_falsy()
        t.expect(valid).to_be(true)  -- Entity is valid, just missing component

        destroy_entity(1002)
    end)
end)

--------------------------------------------------------------------------------
-- Tests: Debug logging for missing components
--------------------------------------------------------------------------------

t.describe("component_cache.safe_get - Debug logging", function()

    t.it("can enable debug mode", function()
        t.expect(type(component_cache.set_debug_mode)).to_be("function")
    end)

    t.it("logs when entity is invalid in debug mode", function()
        clear_logs()
        advance_frame()
        component_cache.set_debug_mode(true)

        component_cache.safe_get(88888, Transform)

        local log = find_log("invalid")
        t.expect(log).to_be_truthy()
        if log then
            t.expect(log.message:match("88888")).to_be_truthy()
        end

        component_cache.set_debug_mode(false)
    end)

    t.it("logs component name when component is missing in debug mode", function()
        clear_logs()
        advance_frame()
        component_cache.set_debug_mode(true)

        create_entity(1003, {})

        component_cache.safe_get(1003, Transform)

        local log = find_log("Transform")
        t.expect(log).to_be_truthy()

        destroy_entity(1003)
        component_cache.set_debug_mode(false)
    end)

    t.it("does NOT log when debug mode is disabled", function()
        clear_logs()
        advance_frame()
        component_cache.set_debug_mode(false)

        component_cache.safe_get(77777, Transform)

        t.expect(#logged_messages).to_be(0)
    end)
end)

--------------------------------------------------------------------------------
-- Tests: safe_get_with_context helper
--------------------------------------------------------------------------------

t.describe("component_cache.safe_get_with_context", function()

    t.it("exists as a helper function", function()
        t.expect(type(component_cache.safe_get_with_context)).to_be("function")
    end)

    t.it("accepts context string for better error messages", function()
        clear_logs()
        advance_frame()
        component_cache.set_debug_mode(true)

        create_entity(1004, {})

        component_cache.safe_get_with_context(1004, Transform, "Player spawn")

        local log = find_log("Player spawn")
        t.expect(log).to_be_truthy()

        destroy_entity(1004)
        component_cache.set_debug_mode(false)
    end)
end)

--------------------------------------------------------------------------------
-- Run Tests
--------------------------------------------------------------------------------

local success = t.run()
os.exit(success and 0 or 1)
