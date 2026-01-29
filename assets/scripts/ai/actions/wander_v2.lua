--[[
wander_v2.lua - Demo action using the new GOAP API helpers

This is a refactored version of wander.lua using:
- ActionBuilder for fluent action definition
- action_helpers for common behavior patterns
- ActionContext for cleaner entity/blackboard access

Original wander.lua pattern:
    return {
        name = "wander",
        cost = 5,
        pre = { wander = false },
        post = { wander = true },
        start = function(e) ... end,
        update = function(e, dt) ... end,
        finish = function(e) ... end
    }

New pattern with ActionBuilder:
    return Action.new("wander_v2")
        :cost(5)
        :pre("wander", false)
        :post("wander", true)
        :on_start(function(ctx) ... end)
        :on_update(function(ctx, dt) ... end)
        :on_finish(function(ctx) ... end)
        :build()
]]

local Action = require("ai.action_builder")
local helpers = require("ai.action_helpers")

return Action.new("wander_v2")
    :cost(5)
    :pre("wander", false)
    :post("wander", true)
    
    :on_start(function(ctx)
        log_debug("Entity", ctx.entity, "is wandering (v2).")
    end)
    
    :on_update(function(ctx, dt)
        local result = helpers.wait_seconds(ctx, 1.0)
        if result ~= ActionResult.SUCCESS then
            return result
        end
        
        local goalLoc = Vec2(
            random_utils.random_float(0, globals.screenWidth()), 
            random_utils.random_float(0, globals.screenHeight())
        )
        
        startEntityWalkMotion(ctx.entity)
        
        return helpers.move_toward(ctx, goalLoc, 100)
    end)
    
    :on_finish(function(ctx)
        log_debug("Done wandering (v2): entity", ctx.entity)
    end)
    
    :build()
