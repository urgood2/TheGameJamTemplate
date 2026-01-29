package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"
local t = require("tests.test_runner")

_G.ActionResult = { SUCCESS = "success", RUNNING = "running", FAILURE = "failure" }

local MockBlackboard = {}
MockBlackboard.__index = MockBlackboard
function MockBlackboard.new()
    return setmetatable({ _data = {} }, MockBlackboard)
end
function MockBlackboard:contains(key) return self._data[key] ~= nil end
function MockBlackboard:get_int(key) return self._data[key] end

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

t.describe("ActionBuilder", function()
    local Action
    
    t.before_each(function()
        reset_mocks()
        package.loaded["ai.action_builder"] = nil
        package.loaded["ai.action_context"] = nil
        Action = require("ai.action_builder")
    end)

    t.it("creates action with name", function()
        local action = Action.new("test"):build()
        t.expect(action.name).to_be("test")
    end)

    t.it("has default cost of 1", function()
        local action = Action.new("test"):build()
        t.expect(action.cost).to_be(1)
    end)

    t.it("sets custom cost", function()
        local action = Action.new("test"):cost(2.5):build()
        t.expect(action.cost).to_be(2.5)
    end)

    t.it("adds preconditions", function()
        local action = Action.new("test")
            :pre("has_weapon", true)
            :pre("has_ammo", true)
            :build()
        t.expect(action.pre.has_weapon).to_be(true)
        t.expect(action.pre.has_ammo).to_be(true)
    end)

    t.it("adds postconditions", function()
        local action = Action.new("test")
            :post("enemy_dead", true)
            :build()
        t.expect(action.post.enemy_dead).to_be(true)
    end)

    t.it("adds watch keys", function()
        local action = Action.new("test")
            :watch("health")
            :watch("ammo")
            :build()
        t.expect(#action.watch).to_be(2)
    end)

    t.it("auto-watches preconditions when no explicit watch", function()
        local action = Action.new("test")
            :pre("a", true)
            :pre("b", false)
            :build()
        t.expect(action.watch).to_be_truthy()
        local has_a, has_b = false, false
        for _, v in ipairs(action.watch) do
            if v == "a" then has_a = true end
            if v == "b" then has_b = true end
        end
        t.expect(has_a).to_be(true)
        t.expect(has_b).to_be(true)
    end)

    t.it("on_update callback receives ctx and dt", function()
        local received_ctx, received_dt
        local action = Action.new("test")
            :on_update(function(ctx, dt)
                received_ctx = ctx
                received_dt = dt
                return ActionResult.SUCCESS
            end)
            :build()
        
        local result = action.update(42, 0.016)
        t.expect(received_ctx.entity).to_be(42)
        t.expect(received_dt).to_be(0.016)
        t.expect(result).to_be(ActionResult.SUCCESS)
    end)

    t.it("on_start callback receives ctx", function()
        local received_entity
        local action = Action.new("test")
            :on_start(function(ctx)
                received_entity = ctx.entity
            end)
            :build()
        
        action.start(99)
        t.expect(received_entity).to_be(99)
    end)
    
    t.it("on_finish callback receives ctx", function()
        local received_entity
        local action = Action.new("test")
            :on_finish(function(ctx)
                received_entity = ctx.entity
            end)
            :build()
        
        action.finish(77)
        t.expect(received_entity).to_be(77)
    end)
    
    t.it("on_abort callback receives ctx and reason", function()
        local received_entity, received_reason
        local action = Action.new("test")
            :on_abort(function(ctx, reason)
                received_entity = ctx.entity
                received_reason = reason
            end)
            :build()
        
        action.abort(55, "worldstate_changed")
        t.expect(received_entity).to_be(55)
        t.expect(received_reason).to_be("worldstate_changed")
    end)

    t.it("fluent chaining works", function()
        local action = Action.new("complex_action")
            :cost(3)
            :pre("ready", true)
            :post("done", true)
            :watch("ready")
            :on_start(function(ctx) end)
            :on_update(function(ctx, dt) return ActionResult.SUCCESS end)
            :on_finish(function(ctx) end)
            :build()
        
        t.expect(action.name).to_be("complex_action")
        t.expect(action.cost).to_be(3)
        t.expect(action.pre.ready).to_be(true)
        t.expect(action.post.done).to_be(true)
        t.expect(action.start).to_be_truthy()
        t.expect(action.update).to_be_truthy()
        t.expect(action.finish).to_be_truthy()
    end)
end)

if arg and arg[0] and arg[0]:match("test_action_builder%.lua$") then
    local success = t.run()
    os.exit(success and 0 or 1)
end

return t
