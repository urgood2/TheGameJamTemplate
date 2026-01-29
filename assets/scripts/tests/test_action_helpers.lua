package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"
local t = require("tests.test_runner")

_G.ActionResult = { SUCCESS = "success", RUNNING = "running", FAILURE = "failure" }
_G.GetTime = function() return os.clock() end

local move_returns = true
_G.moveEntityTowardGoalOneIncrement = function(e, target, dt)
    return move_returns
end

_G.Vec2 = function(x, y) return {x = x, y = y} end

local MockBlackboard = {}
MockBlackboard.__index = MockBlackboard
function MockBlackboard.new()
    local self = setmetatable({}, MockBlackboard)
    self._data = {}
    return self
end
function MockBlackboard:set_float(key, value) self._data[key] = value end
function MockBlackboard:get_float(key) return self._data[key] or 0 end
function MockBlackboard:contains(key) return self._data[key] ~= nil end
function MockBlackboard:get_or_float(key, default) return self._data[key] or default end
function MockBlackboard:remove(key) self._data[key] = nil end

local mock_blackboards = {}
_G.ai = _G.ai or {}
_G.ai.get_blackboard = function(entity)
    if not mock_blackboards[entity] then
        mock_blackboards[entity] = MockBlackboard.new()
    end
    return mock_blackboards[entity]
end

_G.registry = {
    view = function(self, ...)
        return { each = function() return function() end end }
    end
}

local function reset_mocks()
    mock_blackboards = {}
    move_returns = true
end

t.describe("action_helpers", function()
    local helpers
    local ActionContext
    
    t.before_each(function()
        reset_mocks()
        package.loaded["ai.action_helpers"] = nil
        package.loaded["ai.action_context"] = nil
        ActionContext = require("ai.action_context")
        helpers = require("ai.action_helpers")
    end)

    t.it("move_toward returns RUNNING when not at target", function()
        move_returns = true
        local ctx = ActionContext.new(1)
        ctx.dt = 0.016
        local result = helpers.move_toward(ctx, Vec2(100, 100), 50)
        t.expect(result).to_be(ActionResult.RUNNING)
    end)

    t.it("move_toward returns SUCCESS when at target", function()
        move_returns = false
        local ctx = ActionContext.new(1)
        ctx.dt = 0.016
        local result = helpers.move_toward(ctx, Vec2(100, 100), 50)
        t.expect(result).to_be(ActionResult.SUCCESS)
    end)
    
    t.it("move_toward returns FAILURE when ctx is nil", function()
        local result = helpers.move_toward(nil, Vec2(100, 100), 50)
        t.expect(result).to_be(ActionResult.FAILURE)
    end)

    t.it("wait_seconds returns RUNNING on first call", function()
        local ctx = ActionContext.new(1)
        local result = helpers.wait_seconds(ctx, 1.0)
        t.expect(result).to_be(ActionResult.RUNNING)
    end)

    t.it("wait_seconds returns SUCCESS after duration elapsed", function()
        local ctx = ActionContext.new(1)
        helpers.wait_seconds(ctx, 0.5)
        ctx.blackboard:set_float("_wait_start_time", GetTime() - 1.0)
        local result = helpers.wait_seconds(ctx, 0.5)
        t.expect(result).to_be(ActionResult.SUCCESS)
    end)
    
    t.it("wait_seconds returns FAILURE when ctx is nil", function()
        local result = helpers.wait_seconds(nil, 1.0)
        t.expect(result).to_be(ActionResult.FAILURE)
    end)

    t.it("find_nearest returns nil when no entities match filter", function()
        local ctx = ActionContext.new(1)
        local result = helpers.find_nearest(ctx, function(e) return false end)
        t.expect(result).to_be_nil()
    end)
    
    t.it("find_nearest returns nil when ctx is nil", function()
        local result = helpers.find_nearest(nil, function(e) return true end)
        t.expect(result).to_be_nil()
    end)
end)

if arg and arg[0] and arg[0]:match("test_action_helpers%.lua$") then
    local success = t.run()
    os.exit(success and 0 or 1)
end

return t
