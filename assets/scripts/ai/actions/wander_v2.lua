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
        local bb = ctx.blackboard
        local has_target = bb:contains("_wander_target_x") and bb:contains("_wander_target_y")
        
        if not has_target then
            local target_x = random_utils.random_float(0, globals.screenWidth())
            local target_y = random_utils.random_float(0, globals.screenHeight())
            bb:set_float("_wander_target_x", target_x)
            bb:set_float("_wander_target_y", target_y)
            startEntityWalkMotion(ctx.entity)
        end
        
        local goalLoc = Vec2(
            bb:get_float("_wander_target_x"),
            bb:get_float("_wander_target_y")
        )
        
        local move_result = helpers.move_toward(ctx, goalLoc, 100)
        
        if move_result == ActionResult.SUCCESS then
            bb:remove("_wander_target_x")
            bb:remove("_wander_target_y")
            return helpers.wait_seconds(ctx, 1.0, "_wander")
        end
        
        return move_result
    end)
    
    :on_finish(function(ctx)
        log_debug("Done wandering (v2): entity", ctx.entity)
    end)
    
    :build()
