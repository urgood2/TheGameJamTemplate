--------------------------------------------
-- Centralized Timer System (Full Parity)
--------------------------------------------

if _G.__GLOBAL_TIMER__ then
    return _G.__GLOBAL_TIMER__
end

local timer = {}
local empty_function = function() end

-- All active timers live here
timer.timers = {}
timer.global_multiplier = 1.0

-- Safe self-cancellation support
local _is_updating = false
local _pending_cancels = {}


--------------------------------------------------------
-- Basic Utility
--------------------------------------------------------
--------------------------------------------------------
-- Tag Utility
--------------------------------------------------------
local function random_uid()
  return "timer_" .. tostring(math.random(1, 1e9))
end

local function ensure_valid_tag(tag)
  -- If nil/false, auto-generate a unique tag
  if tag == nil or tag == false then
    tag = random_uid()
  end

  -- Coerce non-string/non-number keys safely
  if type(tag) ~= "string" and type(tag) ~= "number" then
    tag = tostring(tag)
  end

  -- Overwrite existing timers silently if tag already exists
  return tag
end

function timer.resolve_delay(delay)
  if not delay then return 0 end
  if type(delay) == "table" then
    return main and main.random_float and main:random_float(delay[1], delay[2])
      or (delay[1] + math.random() * (delay[2] - delay[1]))
  else
    return delay
  end
end

--------------------------------------------------------
-- Timer Creation
--------------------------------------------------------

function timer.run(action, after, tag, group)
  tag = ensure_valid_tag(tag)
  timer.timers[tag] = {
    type = "run",
    timer = 0,
    action = action,
    after = after or empty_function,
    group = group,
  }
end


function timer.run_every_render_frame(action, after, tag, group)
  tag = ensure_valid_tag(tag)
  timer.timers[tag] = {
    type = "every_render_frame",
    timer = 0,
    action = action,
    after = after or empty_function,
    group = group,
  }
end

function timer.after(delay, action, tag, group)
  tag = ensure_valid_tag(tag)
  timer.timers[tag] = {
    type = "after",
    timer = 0,
    unresolved_delay = delay,
    delay = timer.resolve_delay(delay),
    action = action,
    group = group,
  }
  return tag
end

function timer.cooldown(delay, condition, action, times, after, tag, group)
  tag = ensure_valid_tag(tag)
  timer.timers[tag] = {
    type = "cooldown",
    timer = 0,
    unresolved_delay = delay,
    delay = timer.resolve_delay(delay),
    condition = condition,
    action = action,
    times = times or 0,
    max_times = times or 0,
    after = after or empty_function,
    multiplier = 1,
    group = group,
  }
  return tag
end

function timer.every(delay, action, times, immediate, after, tag, group)
  tag = ensure_valid_tag(tag)
  timer.timers[tag] = {
    type = "every",
    timer = 0,
    index = 1,
    unresolved_delay = delay,
    delay = timer.resolve_delay(delay),
    action = action,
    times = times or 0,
    max_times = times or 0,
    after = after or empty_function,
    multiplier = 1,
    group = group,
  }
  if immediate then action() end
  return tag
end

--------------------------------------------------------
-- Options-Table API (Ergonomic alternatives)
--------------------------------------------------------

--- Options-table variant of timer.after
--- @param opts table { delay, action, tag?, group? }
--- @return string tag The timer tag
function timer.after_opts(opts)
    assert(opts.delay, "timer.after_opts: delay required")
    assert(opts.action, "timer.after_opts: action required")
    return timer.after(opts.delay, opts.action, opts.tag, opts.group)
end

--- Options-table variant of timer.every
--- @param opts table { delay, action, times?, immediate?, after?, tag?, group? }
--- @return string tag The timer tag
function timer.every_opts(opts)
    assert(opts.delay, "timer.every_opts: delay required")
    assert(opts.action, "timer.every_opts: action required")
    return timer.every(
        opts.delay,
        opts.action,
        opts.times or 0,
        opts.immediate or false,
        opts.after,
        opts.tag,
        opts.group
    )
end

--- Options-table variant of timer.cooldown
--- @param opts table { delay, condition, action, times?, after?, tag?, group? }
--- @return string tag The timer tag
function timer.cooldown_opts(opts)
    assert(opts.delay, "timer.cooldown_opts: delay required")
    assert(opts.condition, "timer.cooldown_opts: condition required")
    assert(opts.action, "timer.cooldown_opts: action required")
    return timer.cooldown(
        opts.delay,
        opts.condition,
        opts.action,
        opts.times or 0,
        opts.after,
        opts.tag,
        opts.group
    )
end

--- Options-table variant of timer.for_time
--- @param opts table { delay, action, after?, tag?, group? }
--- @return string tag The timer tag
function timer.for_time_opts(opts)
    assert(opts.delay, "timer.for_time_opts: delay required")
    assert(opts.action, "timer.for_time_opts: action required")
    return timer.for_time(opts.delay, opts.action, opts.after, opts.tag, opts.group)
end

--- Create a new TimerChain for fluent sequential timing
--- Convenience wrapper for require("core.timer_chain").new()
--- @param group string? Optional group name
--- @return TimerChain
function timer.sequence(group)
    local TimerChain = require("core.timer_chain")
    return TimerChain.new(group)
end

function timer.every_step(start_delay, end_delay, times, action, immediate, step_method, after, tag, group)
  assert(times >= 2, "timer.every_step requires times >= 2")
  tag = ensure_valid_tag(tag)
  local step = (end_delay - start_delay) / (times - 1)
  local delays = {}
  for i = 1, times do delays[i] = start_delay + (i - 1) * step end
  if step_method then
    local steps = {}
    for i = 1, times - 2 do steps[i] = step_method(i / (times - 1)) end
    for i = 2, times - 1 do
      delays[i] = math.remap(steps[i - 1], 0, 1, start_delay, end_delay)
    end
  end
  timer.timers[tag] = {
    type = "every_step",
    timer = 0,
    index = 1,
    delays = delays,
    action = action,
    times = times or 0,
    max_times = times or 0,
    after = after or empty_function,
    multiplier = 1,
    group = group,
  }
  if immediate then action() end
end

function timer.for_time(delay, action, after, tag, group)
  tag = ensure_valid_tag(tag)
  timer.timers[tag] = {
    type = "for",
    timer = 0,
    unresolved_delay = delay,
    delay = timer.resolve_delay(delay),
    action = action,
    after = after or empty_function,
    group = group,
  }
  return tag
end

--------------------------------------------------------
-- Tween Overloads
--------------------------------------------------------

-- 1) scalar tween(getter, setter)
function timer.tween_scalar(delay, getter, setter, target_value, method, after, tag, group)
  tag = ensure_valid_tag(tag)

  -- Capture the starting value *once*
  local start_value = getter()

  timer.timers[tag] = {
    type = "tween_scalar",
    timer = 0,
    unresolved_delay = delay,
    delay = timer.resolve_delay(delay),

    getter = getter,     -- not strictly needed anymore but left for parity
    setter = setter,

    initial = start_value,
    target  = target_value,

    method = method or function(t) return t end,
    after = after or empty_function,
    group = group,
  }
end


-- 2) tracks tween (array of descriptors {get, set, to, from?})
function timer.tween_tracks(delay, tracks, method, after, tag, group)
  tag = ensure_valid_tag(tag)
  local computed_tracks = {}
  for _, tr in ipairs(tracks) do
    local from = tr.from or tr.get()
    table.insert(computed_tracks, {
      set = tr.set,
      start = from,
      delta = tr.to - from
    })
  end
  timer.timers[tag] = {
    type = "tween_tracks",
    timer = 0,
    unresolved_delay = delay,
    delay = timer.resolve_delay(delay),
    tracks = computed_tracks,
    method = method or function(t) return t end,
    after = after or empty_function,
    group = group,
  }
end

-- 3) table fields tween (your existing one)
function timer.tween_fields(delay, target, source, method, after, tag, group)
  tag = ensure_valid_tag(tag)
  local initial_values = {}
  for k in pairs(source) do
    initial_values[k] = target[k]
  end
  timer.timers[tag] = {
    type = "tween_fields",
    timer = 0,
    unresolved_delay = delay,
    delay = timer.resolve_delay(delay),
    target = target,
    initial_values = initial_values,
    source = source,
    method = method or function(t) return t end,
    after = after or empty_function,
    group = group,
  }
end

--------------------------------------------------------
-- Timer Management
--------------------------------------------------------

function timer.cancel(tag)
  if _is_updating then
    _pending_cancels[#_pending_cancels + 1] = tag
  else
    timer.timers[tag] = nil
  end
end

function timer.clear_all()
  timer.timers = {}
end

function timer.reset(tag)
  if timer.timers[tag] then
    timer.timers[tag].timer = 0
  end
end

function timer.set_multiplier(tag, multiplier)
  if tag == nil then
    timer.global_multiplier = multiplier or 1
  elseif timer.timers[tag] then
    timer.timers[tag].multiplier = multiplier or 1
  end
end

function timer.get_multiplier(tag)
  if tag == nil then return timer.global_multiplier end
  return timer.timers[tag] and timer.timers[tag].multiplier or 1
end

-- Pause / Resume individual
function timer.pause(tag)
  if timer.timers[tag] then timer.timers[tag].paused = true end
end

function timer.resume(tag)
  if timer.timers[tag] then timer.timers[tag].paused = false end
end

-- Group control
function timer.kill_group(group)
  for tag, t in pairs(timer.timers) do
    if t.group == group then timer.timers[tag] = nil end
  end
end

function timer.pause_group(group)
  for _, t in pairs(timer.timers) do
    if t.group == group then t.paused = true end
  end
end

function timer.resume_group(group)
  for _, t in pairs(timer.timers) do
    if t.group == group then t.paused = false end
  end
end

--------------------------------------------------------
-- Queries
--------------------------------------------------------

function timer.get_delay(tag)
  return timer.timers[tag] and timer.timers[tag].delay
end

function timer.get_every_index(tag)
  return timer.timers[tag] and timer.timers[tag].index
end

function timer.get_for_elapsed_time(tag)
  local t = timer.timers[tag]
  if not t then return 0 end
  return t.timer / t.delay
end

function timer.get_timer_and_delay(tag)
  local t = timer.timers[tag]
  if not t then return nil, nil end
  return t.timer, t.delay
end

--------------------------------------------------------
-- Update Loop
--------------------------------------------------------

-- Cache locals for performance
local min = math.min
local resolve_delay = timer.resolve_delay
local timers = timer.timers


function timer.update(dt, is_render_frame)
    -- tracy.zoneBeginN("lua timer.update")

    _is_updating = true  -- Prevent in-loop cancellation
    local global_mult = timer.global_multiplier
    local to_remove = nil
    local resolve_delay = timer.resolve_delay
    local timers = timer.timers

    for tag, t in pairs(timers) do
        if not t or t.paused then
            goto continue
        end

        local effective_dt = dt * global_mult * (t.multiplier or 1)
        t.timer = (t.timer or 0) + effective_dt

        local remove = false
        local ttype = t.type

        if ttype == "run" then
            t.action()
            -- remove = true (intentionally left commented, mirrors your design)

        elseif ttype == "every_render_frame" then
            if is_render_frame then t.action() end

        elseif ttype == "cooldown" then
            if t.timer > t.delay and t.condition() then
                t.action()
                t.timer = 0
                if not t.fixed_delay then
                    t.delay = resolve_delay(t.unresolved_delay)
                end
                -- Defensive: ensure t.times is a number (catch misplaced tag arguments)
                if type(t.times) ~= "number" then
                    log_warn("Timer '" .. tostring(tag) .. "' has non-numeric 'times' field: " .. tostring(t.times) .. " - fixing to 0")
                    t.times = 0
                end
                if t.times > 0 then
                    t.times = t.times - 1
                    if t.times <= 0 then
                        t.after()
                        remove = true
                    end
                end
            end

        elseif ttype == "after" then
            if t.timer > t.delay then
                t.action()
                remove = true
            end

        elseif ttype == "every" then
            if t.timer > t.delay then
                t.action()
                t.timer = t.timer - t.delay
                t.index = t.index + 1
                if not t.fixed_delay then
                    t.delay = resolve_delay(t.unresolved_delay)
                end
                -- Defensive: ensure t.times is a number (catch misplaced tag arguments)
                if type(t.times) ~= "number" then
                    log_warn("Timer '" .. tostring(tag) .. "' has non-numeric 'times' field: " .. tostring(t.times) .. " - fixing to 0")
                    t.times = 0
                end
                if t.times > 0 then
                    t.times = t.times - 1
                    if t.times <= 0 then
                        t.after()
                        remove = true
                    end
                end
            end

        elseif ttype == "every_step" then
            local delays = t.delays
            if t.timer > delays[t.index] then
                t.action()
                t.timer = t.timer - delays[t.index]
                t.index = t.index + 1
                -- Defensive: ensure t.times is a number (catch misplaced tag arguments)
                if type(t.times) ~= "number" then
                    log_warn("Timer '" .. tostring(tag) .. "' has non-numeric 'times' field: " .. tostring(t.times) .. " - fixing to 0")
                    t.times = 0
                end
                if t.times > 0 then
                    t.times = t.times - 1
                    if t.times <= 0 then
                        t.after()
                        remove = true
                    end
                end
            end

        elseif ttype == "for" then
            t.action(dt)
            if t.timer > t.delay then
                t.after()
                remove = true
            end

        elseif ttype == "tween_scalar" then
            local ratio = math.min(1, t.timer / t.delay)
            local eased = t.method(ratio)
            local start = t.getter()
            t.setter(start + (t.target - start) * eased)
            if t.timer > t.delay then
                t.after()
                remove = true
            end

        elseif ttype == "tween_tracks" then
            local ratio = math.min(1, t.timer / t.delay)
            local eased = t.method(ratio)
            local tracks = t.tracks
            for i = 1, #tracks do
                local tr = tracks[i]
                tr.set(tr.start + tr.delta * eased)
            end
            if t.timer > t.delay then
                t.after()
                remove = true
            end

        elseif ttype == "tween_fields" or ttype == "tween" then
            local ratio = math.min(1, t.timer / t.delay)
            local eased = t.method(ratio)
            local source = t.source
            local target = t.target
            local initial = t.initial_values
            for k, v in pairs(source) do
                target[k] = initial[k] + (v - initial[k]) * eased
            end
            if t.timer > t.delay then
                t.after()
                remove = true
            end
        end

        if remove then
            to_remove = to_remove or {}
            to_remove[#to_remove + 1] = tag
        end

        ::continue::
    end

    _is_updating = false  -- done iterating

    -- Remove completed timers
    if to_remove then
        for i = 1, #to_remove do
            timers[to_remove[i]] = nil
        end
    end

    -- Apply deferred cancels requested mid-loop
    if #_pending_cancels > 0 then
        for i = 1, #_pending_cancels do
            local tag = _pending_cancels[i]
            timers[tag] = nil
        end
        _pending_cancels = {}
    end

    -- tracy.zoneEnd()
end


--------------------------------------------------------
-- Physics Step Timers
--------------------------------------------------------

-- Internal bookkeeping
timer._lastPhysicsTick = timer._lastPhysicsTick or 0
timer._physics_once = {}       -- one-shot timers
timer._physics_every = {}      -- persistent timers

--- Run once on the *next* physics step.
---@param fn function
---@param tag? string
---@param group? string
function timer.on_new_physics_step(fn, tag, group)
    tag = ensure_valid_tag(tag)
    timer._physics_once[tag] = {
        fn = fn,
        group = group,
        targetTick = (physicsTickCounter or 0) + 1
    }
end

--- Run every physics step until cancelled.
---@param fn function
---@param tag? string
---@param group? string
function timer.every_physics_step(fn, tag, group)
    tag = ensure_valid_tag(tag)
    timer._physics_every[tag] = {
        fn = fn,
        group = group
    }
end

--- Cancel a physics-step timer (works for both one-shot and every types).
---@param tag string
function timer.cancel_physics_step(tag)
    timer._physics_once[tag] = nil
    timer._physics_every[tag] = nil
end

--- Clear all physics-step timers.
function timer.clear_physics_step()
    timer._physics_once = {}
    timer._physics_every = {}
end

--- Called each frame (or right after physics integration).
--- Detects tick changes and executes relevant timers.
function timer.update_physics_step()
    local tick = physicsTickCounter or 0
    if tick <= timer._lastPhysicsTick then return end

    -- Run all persistent timers
    for tag, t in pairs(timer._physics_every) do
        if t and t.fn then
            -- log_debug("[timer.every_physics_step] Running timer:", tag)
            local ok, err = pcall(t.fn)
            if not ok then
                log_error("[timer.every_physics_step] Error:", err)
            end
        end
    end

    -- Run any queued one-shot timers for this tick
    for tag, t in pairs(timer._physics_once) do
        if t and t.fn and t.targetTick <= tick then
            local ok, err = pcall(t.fn)
            if not ok then
                log_error("[timer.on_new_physics_step] Error:", err)
            end
            timer._physics_once[tag] = nil
        end
    end

    timer._lastPhysicsTick = tick
end

--------------------------------------------------------
-- Example usage (for clarity)
--------------------------------------------------------
--[[
timer.on_new_physics_step(function()
    physics.ApplyImpulse(world, eid, 100, 0)
end)

timer.every_physics_step(function()
    print("Physics tick happened:", physicsTickCounter)
end)
]]
--------------------------------------------------------


_G.__GLOBAL_TIMER__ = timer
return timer