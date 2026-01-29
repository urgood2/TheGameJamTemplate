--[[
Fluent Action Builder DSL for GOAP actions.

Example:
    local Action = require("ai.action_builder")
    
    local action = Action.new("attack_melee")
        :cost(1.5)
        :pre("has_weapon", true)
        :post("enemy_damaged", true)
        :on_update(function(ctx, dt)
            return ActionResult.SUCCESS
        end)
        :build()
]]

local ActionContext = require("ai.action_context")

local ActionBuilder = {}
ActionBuilder.__index = ActionBuilder

function ActionBuilder.new(name)
    local self = setmetatable({}, ActionBuilder)
    self._name = name
    self._cost = 1
    self._pre = {}
    self._post = {}
    self._watch = {}
    self._on_start = nil
    self._on_update = nil
    self._on_finish = nil
    self._on_abort = nil
    return self
end

function ActionBuilder:cost(n)
    self._cost = n
    return self
end

function ActionBuilder:pre(key, value)
    self._pre[key] = value
    return self
end

function ActionBuilder:post(key, value)
    self._post[key] = value
    return self
end

function ActionBuilder:watch(key)
    table.insert(self._watch, key)
    return self
end

function ActionBuilder:on_start(fn)
    self._on_start = fn
    return self
end

function ActionBuilder:on_update(fn)
    self._on_update = fn
    return self
end

function ActionBuilder:on_finish(fn)
    self._on_finish = fn
    return self
end

function ActionBuilder:on_abort(fn)
    self._on_abort = fn
    return self
end

function ActionBuilder:build()
    local builder = self
    
    local watch_list = #self._watch > 0 and self._watch or nil
    if not watch_list and next(self._pre) then
        watch_list = {}
        for key, _ in pairs(self._pre) do
            table.insert(watch_list, key)
        end
    end
    
    local action = {
        name = self._name,
        cost = self._cost,
        pre = self._pre,
        post = self._post,
        watch = watch_list,
    }
    
    if self._on_start then
        action.start = function(e)
            local ctx = ActionContext.new(e)
            return builder._on_start(ctx)
        end
    end
    
    if self._on_update then
        action.update = function(e, dt)
            local ctx = ActionContext.new(e)
            ctx.dt = dt
            return builder._on_update(ctx, dt)
        end
    end
    
    if self._on_finish then
        action.finish = function(e)
            local ctx = ActionContext.new(e)
            return builder._on_finish(ctx)
        end
    end
    
    if self._on_abort then
        action.abort = function(e, reason)
            local ctx = ActionContext.new(e)
            return builder._on_abort(ctx, reason)
        end
    end
    
    return action
end

local Action = {
    new = ActionBuilder.new
}

return Action
