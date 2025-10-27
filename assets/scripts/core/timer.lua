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
end

--------------------------------------------------------
-- Tween Overloads
--------------------------------------------------------

-- 1) scalar tween(getter, setter)
function timer.tween_scalar(delay, getter, setter, target_value, method, after, tag, group)
  tag = ensure_valid_tag(tag)
  timer.timers[tag] = {
    type = "tween_scalar",
    timer = 0,
    unresolved_delay = delay,
    delay = timer.resolve_delay(delay),
    getter = getter,
    setter = setter,
    target = target_value,
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
  timer.timers[tag] = nil
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

function timer.update(dt, is_render_frame)
  -- tracy.zoneBeginN("lua timer.update") -- just some default depth to avoid bugs
  local keys = {}
  for tag in pairs(timer.timers) do
    keys[#keys + 1] = tag
  end
  
  -- -- print the tag table for debugging
  -- for i = 1, #keys do
  --   local tag = keys[i]
  --   print("Timer Tag:", tag)
  -- end

  for i = 1, #keys do
    local tag = keys[i]
    local t = timer.timers[tag]
    if not t then goto continue end  -- might’ve been removed during iteration

    if t.paused then goto continue end
    
    if tag == "interval" then
      -- Debug hook: print number of active timers every interval
      print("[Timer] Active timers:", #keys)
    end

    local effective_dt = dt * timer.global_multiplier * (t.multiplier or 1)
    t.timer = (t.timer or 0) + effective_dt

    if t.type == "run" then
      t.action()

    elseif t.type == "every_render_frame" then
      if is_render_frame then
        t.action()
      end

    elseif t.type == "cooldown" then
      if t.timer > t.delay and t.condition() then
        t.action()
        t.timer = 0
        t.delay = timer.resolve_delay(t.unresolved_delay)
        if t.times > 0 then
          t.times = t.times - 1
          if t.times <= 0 then t.after(); timer.timers[tag] = nil end
        end
      end

    elseif t.type == "after" then
      if t.timer > t.delay then
        t.action()
        timer.timers[tag] = nil
      end

    elseif t.type == "every" then
      if t.timer > t.delay then
        t.action()
        t.timer = t.timer - t.delay
        t.index = t.index + 1
        t.delay = timer.resolve_delay(t.unresolved_delay)
        if t.times > 0 then
          t.times = t.times - 1
          if t.times <= 0 then t.after(); timer.timers[tag] = nil end
        end
      end

    elseif t.type == "every_step" then
      if t.timer > t.delays[t.index] then
        t.action()
        t.timer = t.timer - t.delays[t.index]
        t.index = t.index + 1
        if t.times > 0 then
          t.times = t.times - 1
          if t.times <= 0 then t.after(); timer.timers[tag] = nil end
        end
      end

    elseif t.type == "for" then
      t.action(dt)
      if t.timer > t.delay then t.after(); timer.timers[tag] = nil end

    elseif t.type == "tween_scalar" then
      local ratio = math.min(1, t.timer / t.delay)
      local eased = t.method(ratio)
      local start = t.getter()
      local value = start + (t.target - start) * eased
      t.setter(value)
      if t.timer > t.delay then t.after(); timer.timers[tag] = nil end

    elseif t.type == "tween_tracks" then
      local ratio = math.min(1, t.timer / t.delay)
      local eased = t.method(ratio)
      for _, tr in ipairs(t.tracks) do
        tr.set(tr.start + tr.delta * eased)
      end
      if t.timer > t.delay then t.after(); timer.timers[tag] = nil end

    elseif t.type == "tween_fields" or t.type == "tween" then
      local ratio = math.min(1, t.timer / t.delay)
      local eased = t.method(ratio)
      for k, v in pairs(t.source) do
        local start = t.initial_values[k]
        t.target[k] = start + (v - start) * eased
      end
      if t.timer > t.delay then t.after(); timer.timers[tag] = nil end
    end

    ::continue::
  end
  -- tracy.zoneEnd()
end

_G.__GLOBAL_TIMER__ = timer
return timer