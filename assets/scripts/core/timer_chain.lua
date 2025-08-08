---
--- TimerChain: Fluent, chainable API for Lua timer sequences.
---
--- Collects steps mirroring your existing timer.* signatures
--- and schedules them in a precise, maintainable sequence.
---
---@class TimerChain
local TimerChain = {}
TimerChain.__index = TimerChain

-- no-op helper
local function noop() end

--- Creates a new TimerChain.
---
--- Each chain auto-generates a unique group/tag prefix.
---@param group string? Optional group name. Defaults to a unique chain ID.
---@

--[[
Table-based overloads: accept a single config table instead of individual args.
Each config table should match the fields documented in TimerChain:step().
]]--

--- Table-variant of after().
---@param config table { delay:number, fn:function, tag?:string, group?:string }
---@return TimerChain self
function TimerChain:afterTable(config)
    return self:after(config.delay, config.fn, config.tag, config.group)
end

--- Table-variant of every().
---@param config table { interval:number, fn:function, times?:number, immediate?:boolean, after?:function, tag?:string, group?:string }
---@return TimerChain self
function TimerChain:everyTable(config)
    return self:every(config.interval, config.fn, config.times, config.immediate, config.after, config.tag, config.group)
end

--- Table-variant of cooldown().
---@param config table { delay:number, cond:function, fn:function, times?:number, after?:function, tag?:string, group?:string }
---@return TimerChain self
function TimerChain:cooldownTable(config)
    return self:cooldown(config.delay, config.cond, config.fn, config.times, config.after, config.tag, config.group)
end

--- Table-variant of every_step().
---@param config table { start_delay:number, end_delay:number, times:number, fn:function, immediate?:boolean, step:function, after?:function, tag?:string, group?:string }
---@return TimerChain self
function TimerChain:every_stepTable(config)
    return self:every_step(config.start_delay, config.end_delay, config.times, config.fn, config.immediate, config.step, config.after, config.tag, config.group)
end

--- Table-variant of for_time().
---@param config table { delay:number, fn_dt:function, after?:function, tag?:string, group?:string }
---@return TimerChain self
function TimerChain:for_timeTable(config)
    return self:for_time(config.delay, config.fn_dt, config.after, config.tag, config.group)
end

--- Table-variant of tween().
---@param config table { delay:number, getter:function, setter:function, target:any, tag?:string, group?:string, easing?:function, after?:function }
---@return TimerChain self
function TimerChain:tweenTable(config)
    return self:tween(config.delay, config.getter, config.setter, config.target, config.tag, config.group, config.easing, config.after)
end

return TimerChain
function TimerChain.new(group)
    local self = setmetatable({}, TimerChain)
    self._chain_id    = "chain_" .. tostring(os.time()) .. "_" .. math.random(1,9999)
    self._group       = group or self._chain_id
    self._steps       = {}       -- list of step-config tables
    self._on_complete = nil      -- optional final callback
    return self
end

--- Override the chain's group for all steps.
---@param group string New group name.
---@return TimerChain self
function TimerChain:withGroup(group)
    self._group = group
    return self
end

--- Adds a custom step by table config.
---
--- Use this for full flexibility or new step types.
---@param config table Configuration, must include `type` and matching fields.
--- Config table specification (per-step fields):
---  * Common fields:
---    - `type` (string): one of "after","every","cooldown","every_step","for_time","tween","fork"
---    - `tag` (string?, optional): timer tag override
---    - `group` (string?, optional): timer group override
---  * Type-specific fields:
---    - "after": `delay` (number), `fn` (function)
---    - "every": `interval` (number), `fn` (function), `times` (number?, default=0), `immediate` (boolean?, default=false), `after` (function?, default=noop)
---    - "cooldown": `delay` (number), `cond` (function), `fn` (function), `times` (number?, default=0), `after` (function?, default=noop)
---    - "every_step": `start_delay` (number), `end_delay` (number), `times` (number), `fn` (function), `immediate` (boolean?, default=false), `step` (function), `after` (function?, default=noop)
---    - "for_time": `delay` (number), `fn_dt` (function), `after` (function?, default=noop)
---    - "tween": `delay` (number), `getter` (function), `setter` (function), `target` (any), `easing` (function?, default=easeInOut), `after` (function?, default=noop)
---    - "fork": `chain` (TimerChain)

---@return TimerChain self
function TimerChain:step(config)
    assert(type(config) == "table", "TimerChain:step() expects a table")
    assert(config.type, "TimerChain step missing 'type' field")
    self._steps[#self._steps + 1] = config
    return self
end

--- Alias: after(0, fn)
---@alias then TimerChain.then|
---@param fn function Callback to invoke immediately.
---@param tag string? Optional tag override.
---@param group string? Optional group override.
---@return TimerChain self
function TimerChain:then_(fn, tag, group)
    return self:after(0, fn, tag, group)
end
TimerChain.then = TimerChain.then_

--- Pause for a given delay without action.
---@param delay number Seconds to wait.
---@return TimerChain self
function TimerChain:wait(delay)
    return self:after(delay, noop)
end

--- Alias for an immediate action.
---@param fn function Callback to run now.
---@return TimerChain self
function TimerChain:do_now(fn)
    return self:after(0, fn)
end

--- Register a callback to run after the final step.
---@param fn function Callback invoked when all steps complete.
---@return TimerChain self
function TimerChain:onComplete(fn)
    assert(type(fn) == "function", "onComplete expects a function")
    self._on_complete = fn
    return self
end

--- Validates the chain's configuration, errors on any missing/invalid fields.
---@return boolean true if valid, errors otherwise
function TimerChain:validate()
    for i, e in ipairs(self._steps) do
        local t = e.type
        assert(t, ("step[%d] missing type"):format(i))
        if t == "fork" then
            assert(getmetatable(e.chain) == TimerChain,
                   ("step[%d] invalid fork target"):format(i))
        elseif t == "after" then
            assert(type(e.delay) == "number" and e.delay >= 0,
                   ("step[%d] invalid delay"):format(i))
            assert(type(e.fn) == "function",
                   ("step[%d] missing fn"):format(i))
        elseif t == "every" then
            assert(type(e.interval) == "number" and e.interval > 0,
                   ("step[%d] invalid interval"):format(i))
            assert(type(e.fn) == "function",
                   ("step[%d] missing fn"):format(i))
        elseif t == "cooldown" then
            assert(type(e.delay) == "number" and e.delay > 0,
                   ("step[%d] invalid delay"):format(i))
            assert(type(e.cond) == "function",
                   ("step[%d] missing cond"):format(i))
        elseif t == "every_step" then
            assert(type(e.start_delay) == "number" and e.start_delay >= 0,
                   ("step[%d] invalid start_delay"):format(i))
            assert(type(e.end_delay)   == "number" and e.end_delay >= e.start_delay,
                   ("step[%d] invalid end_delay"):format(i))
            assert(type(e.fn) == "function",
                   ("step[%d] missing fn"):format(i))
        elseif t == "for_time" then
            assert(type(e.delay) == "number" and e.delay >= 0,
                   ("step[%d] invalid duration"):format(i))
            assert(type(e.fn_dt) == "function",
                   ("step[%d] missing fn_dt"):format(i))
        elseif t == "tween" then
            assert(type(e.delay) == "number" and e.delay >= 0,
                   ("step[%d] invalid duration"):format(i))
            assert(type(e.getter) == "function" and type(e.setter) == "function",
                   ("step[%d] missing getter/setter"):format(i))
        end
    end
    return true
end

--- Schedule a one-shot after step.
---@param delay number Seconds until callback.
---@param action function Callback to invoke.
---@param tag string? Optional tag override.
---@param group string? Optional group override.
---@return TimerChain self
function TimerChain:after(delay, action, tag, group)
    return self:step{
        type  = "after",
        delay = delay,
        fn    = action,
        tag   = tag or "",
        group = group or self._group,
    }
end

--- Schedule a repeating timer step.
---@param interval number Seconds between ticks.
---@param action function Callback each tick.
---@param times number? Number of repeats (0 = infinite).
---@param immediate boolean? Fire once immediately.
---@param after function? Callback after repeats.
---@param tag string? Optional tag override.
---@param group string? Optional group override.
---@return TimerChain self
function TimerChain:every(interval, action, times, immediate, after, tag, group)
    return self:step{
        type      = "every",
        interval  = interval,
        fn        = action,
        times     = times or 0,
        immediate = immediate or false,
        after     = after or noop,
        tag       = tag or "",
        group     = group or self._group,
    }
end

--- Schedule a cooldown timer step.
---@param delay number Base cooldown interval.
---@param condition function Condition to check each cycle.
---@param action function Callback when condition met.
---@param times number? Number of activations (0 = infinite).
---@param after function? Callback after end.
---@param tag string? Optional tag override.
---@param group string? Optional group override.
---@return TimerChain self
function TimerChain:cooldown(delay, condition, action, times, after, tag, group)
    return self:step{
        type  = "cooldown",
        delay = delay,
        cond  = condition,
        fn    = action,
        times = times or 0,
        after = after or noop,
        tag   = tag or "",
        group = group or self._group,
    }
end

--- Schedule a stepped interval timer step.
---@param start_delay number Delay for first step.
---@param end_delay number Delay for last step.
---@param times number Number of steps.
---@param action function Callback on each step.
---@param immediate boolean? Run first step immediately.
---@param step_method function Step delay calculator.
---@param after function? Callback after steps.
---@param tag string? Optional tag override.
---@param group string? Optional group override.
---@return TimerChain self
function TimerChain:every_step(start_delay, end_delay, times, action, immediate, step_method, after, tag, group)
    return self:step{
        type        = "every_step",
        start_delay = start_delay,
        end_delay   = end_delay,
        times       = times,
        fn          = action,
        immediate   = immediate or false,
        step        = step_method,
        after       = after or noop,
        tag         = tag or "",
        group       = group or self._group,
    }
end

--- Schedule a duration-based callback every frame.
---@param duration number Time to run in seconds.
---@param action function(dt) Callback each frame with dt.
---@param after function? Callback when duration ends.
---@param tag string? Optional tag override.
---@param group string? Optional group override.
---@return TimerChain self
function TimerChain:for_time(duration, action, after, tag, group)
    return self:step{
        type   = "for_time",
        delay  = duration,
        fn_dt  = action,
        after  = after or noop,
        tag    = tag or "",
        group  = group or self._group,
    }
end

--- Schedule a tween over time.
---@param duration number Tween duration.
---@param getter function() Returns current value.
---@param setter function(value) Sets value.
---@param target any Target value to reach.
---@param tag string? Optional tag override.
---@param group string? Optional group override.
---@param easing function(t) Easing (0<=t<=1).
---@param after function? Callback on completion.
---@return TimerChain self
function TimerChain:tween(duration, getter, setter, target, tag, group, easing, after)
    return self:step{
        type   = "tween",
        delay  = duration,
        getter = getter,
        setter = setter,
        target = target,
        easing = easing or function(t) return t < .5 and 2*t*t or t*(4-2*t)-1 end,
        after  = after or noop,
        tag    = tag or "",
        group  = group or self._group,
    }
end

--- Fork another chain to start at the current offset.
---@param chain TimerChain The chain to launch in parallel.
---@return TimerChain self
function TimerChain:fork(chain)
    chain._group = self._group
    return self:step{ type = "fork", chain = chain }
end

--- Pause all timers in this chain's group.
---@return TimerChain self
function TimerChain:pause()
    timer.pause_group(self._group)
    return self
end

--- Resume all timers in this chain's group.
---@return TimerChain self
function TimerChain:resume()
    timer.resume_group(self._group)
    return self
end

--- Cancel/kill all timers in this chain's group.
---@return TimerChain self
function TimerChain:cancel()
    timer.kill_group(self._group)
    return self
end

--- Validates and schedules all recorded steps.
--- Automatically schedules an onComplete hook if provided.
---@return TimerChain self
function TimerChain:start()
    self:validate()
    local offset = 0
    for i, e in ipairs(self._steps) do
        local tag = (e.tag and #e.tag > 0) and e.tag or (self._chain_id .. "_" .. i)
        local grp = e.group or self._group

        if e.type == "after" then
            timer.after(offset + e.delay, e.fn, tag, grp)
            offset = offset + e.delay

        elseif e.type == "every" then
            timer.after(offset,
                function() timer.every(e.interval, e.fn, e.times, e.immediate, e.after, tag, grp) end,
                tag .. "_start", grp
            )

        elseif e.type == "cooldown" then
            timer.after(offset,
                function() timer.cooldown(e.delay, e.cond, e.fn, e.times, e.after, tag, grp) end,
                tag .. "_start", grp
            )

        elseif e.type == "every_step" then
            timer.after(offset,
                function()
                    timer.every_step(e.start_delay, e.end_delay, e.times, e.fn,
                                     e.immediate, e.step, e.after, tag, grp)
                end,
                tag .. "_start", grp
            )

        elseif e.type == "for_time" then
            timer.after(offset,
                function() timer.for_time(e.delay, e.fn_dt, e.after, tag, grp) end,
                tag .. "_start", grp
            )
            offset = offset + e.delay

        elseif e.type == "tween" then
            timer.after(offset,
                function()
                    timer.tween(e.delay, e.getter, e.setter, e.target,
                                tag, grp, e.easing, e.after)
                end,
                tag .. "_start", grp
            )
            offset = offset + e.delay

        elseif e.type == "fork" then
            timer.after(offset,
                function() e.chain:start() end,
                tag .. "_fork", grp
            )
        end
    end

    if self._on_complete then
        timer.after(offset, self._on_complete, self._chain_id .. "_complete", self._group)
    end

    return self
end

return TimerChain
