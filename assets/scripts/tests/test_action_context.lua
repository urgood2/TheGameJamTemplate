package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"
local t = require("tests.test_runner")

local MockBlackboard = {}
MockBlackboard.__index = MockBlackboard

function MockBlackboard.new()
    local self = setmetatable({}, MockBlackboard)
    self._data = {}
    return self
end

function MockBlackboard:set_int(key, value)
    self._data[key] = value
end

function MockBlackboard:get_int(key)
    local v = self._data[key]
    if v == nil then error("Key not found: " .. key) end
    return v
end

function MockBlackboard:contains(key)
    return self._data[key] ~= nil
end

local mock_blackboards = {}
_G.ai = _G.ai or {}
_G.ai.get_blackboard = function(entity)
    if not mock_blackboards[entity] then
        mock_blackboards[entity] = MockBlackboard.new()
    end
    return mock_blackboards[entity]
end

local function reset_mocks()
    mock_blackboards = {}
end

t.describe("ActionContext", function()
    local ActionContext

    t.before_each(function()
        reset_mocks()
        package.loaded["ai.action_context"] = nil
        ActionContext = require("ai.action_context")
    end)

    t.it("stores entity reference", function()
        local ctx = ActionContext.new(42)
        t.expect(ctx.entity).to_be(42)
    end)

    t.it("provides blackboard access", function()
        local ctx = ActionContext.new(1)
        t.expect(ctx.blackboard).to_be_truthy()
    end)

    t.it("get_target returns nil when no target set", function()
        local ctx = ActionContext.new(1)
        t.expect(ctx:get_target()).to_be_nil()
    end)

    t.it("get_target returns entity ID when target set", function()
        local entity = 1
        local target_id = 999
        local bb = ai.get_blackboard(entity)
        bb:set_int("target_entity", target_id)

        local ctx = ActionContext.new(entity)
        t.expect(ctx:get_target()).to_be(target_id)
    end)

    t.it("has dt field initialized to 0", function()
        local ctx = ActionContext.new(1)
        t.expect(ctx.dt).to_be(0)
    end)
end)

if arg and arg[0] and arg[0]:match("test_action_context%.lua$") then
    local success = t.run()
    os.exit(success and 0 or 1)
end

return t
