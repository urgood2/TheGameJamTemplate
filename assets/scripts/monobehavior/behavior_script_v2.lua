local Object = require("external/object")
local task = require("task/task")
local timer = require("core/timer")

local node = Object:extend()

-- This script is a MonoBehavior script that will be attached to a node. It should be named accordingly for the component it represents, and linked up c++ side.

-- Called once, right after the component is attached.


-- Table of all nodes with update() functions
local updatables = {}

function node:init(args) end

-- TODO: erasing this function for performance, re-add manually if needed
-- Called every frame by script_system_update() if it exists.
-- function node:update(dt)
--     -- print('node [#' .. self.id() .. '] update()', transform)
--     -- local transform = self.owner:get(self.id(), Transform)
    
--     -- coroutine task example
--     -- task.run_named_task("blinker", function()
--     --     print("start")
--     --     task.wait(1.0)
--     --     print("end")
--     --   end)
    
--     -- print("tasks active:", task.count_tasks(self))
-- end

-- Called just before the entity is destroyed
function node:destroy()
    print('bye, bye! from: node #' .. self.id())
end
function node:on_collision(other) end

-- Merge args into self before init so init can read them, also return self from __call for chaining
function node:__call(args)
  local obj = setmetatable({}, self)
  if type(args) == "table" then
    for k, v in pairs(args) do obj[k] = v end
  end
  if obj.init then obj:init(args) end
  if type(self.update) == "function" then
    table.insert(updatables, obj)
  end
  return obj
end

-- ===== ECS attach helpers (ADD-ONLY) =====
-- Requires a global `registry` (entt::registry) with:
--   registry:create(), registry:destroy(eid), registry:add_script(eid, lua_table)
--   (and your meta-based :emplace/:get if you use them elsewhere)

-- Fetch stored entity id (if any)
function node:handle()
  return self._eid
end

-- Queue or immediately run a custom function.
-- Signature: fn(eid, self)
function node:run_custom_func(fn)
  if type(fn) ~= "function" then return self end
  if self._eid then
    -- already attached → run immediately
    fn(self._eid, self)
  else
    -- not attached yet → queue
    if not self._queued_funcs then self._queued_funcs = {} end
    table.insert(self._queued_funcs, fn)
  end
  return self
end

-- Attach policy:
-- opts = {
--   create_new      = true,     -- default true
--   existing_entity = <eid>,    -- if set, attach to this entity (no creation)
-- }
function node:attach_ecs(opts)
  opts = opts or {}
  local create_new = (opts.create_new ~= false) and (opts.existing_entity == nil)
  assert(type(registry) == "userdata" or type(registry) == "table",
         "global 'registry' must be bound to an entt::registry instance")

  -- Pure Lua object case: explicitly disable both
  if not create_new and not opts.existing_entity then
    return self
  end

  -- Create or use existing
  local eid = opts.existing_entity
  if not eid then
    eid = registry:create()
  end

  -- Always attach ScriptComponent
  registry:add_script(eid, self)

  -- Stash handle
  self._eid = eid

  -- Flush queued run_custom_func callbacks (if any)
  if self._queued_funcs then
    for i = 1, #self._queued_funcs do
      local fn = self._queued_funcs[i]
      if type(fn) == "function" then fn(eid, self) end
    end
    self._queued_funcs = nil
  end

  return self
end

-- Queue deletion when a condition is met.
-- Usage:
--   obj:destroy_when(function(self, eid) return ... end, {
--     interval = 0,      -- seconds between checks (0 => every frame). default 0
--     grace    = 0,      -- delay before actual destroy once condition is true. default 0
--     tag      = nil,    -- optional timer tag
--     group    = nil,    -- optional timer group
--     timeout  = nil,    -- optional seconds; cancels watcher if exceeded (no destroy)
--   })
--
-- Notes:
--  • Chainable: returns self
--  • Safe if called before attach: it defers until attach_ecs runs
--  • Cancels its timer automatically if the entity is destroyed some other way
function node:destroy_when(condition, opts)
  assert(type(condition) == "function", "destroy_when: condition must be a function(self, eid)->bool")
  opts = opts or {}

  local interval = opts.interval or 0           -- 0 = per-frame
  local grace    = opts.grace or 0
  local tag      = opts.tag
  local group    = opts.group
  local timeout  = opts.timeout  -- nil or number

  local watcher_handle = nil
  local timeout_handle = nil

  local function do_destroy()
    if self._eid and (registry.valid and registry:valid(self._eid) or true) then
      -- If your binding lacks registry:valid, the 'or true' makes this unconditional.
      -- Remove that 'or true' if you have a working :valid.
      registry:destroy(self._eid)
      self._eid = nil
    end
  end

  local function start_watcher()
    if not self._eid then return end

    -- Optional timeout: cancel the watcher without destroying
    if timeout and timeout > 0 then
      timeout_handle = timer.after(timeout, function()
        if watcher_handle then timer.cancel(watcher_handle) end
      end, tag, group)
    end

    -- Poll condition
    watcher_handle = timer.every(interval, function()
      -- If entity already gone, stop polling
      if not self._eid or (registry.valid and not registry:valid(self._eid)) then
        if watcher_handle then timer.cancel(watcher_handle) watcher_handle = nil end
        if timeout_handle then timer.cancel(timeout_handle) timeout_handle = nil end
        return
      end

      local ok = condition(self, self._eid) == true
      if ok then
        -- Stop polling
        if watcher_handle then timer.cancel(watcher_handle) watcher_handle = nil end
        if timeout_handle then timer.cancel(timeout_handle) timeout_handle = nil end

        if grace > 0 then
          timer.after(grace, function()
            -- double-check still valid before final destroy
            if self._eid and (not registry.valid or registry:valid(self._eid)) then
              do_destroy()
            end
          end, tag, group)
        else
          do_destroy()
        end
      end
    end, 0, true, nil, tag, group)  -- times=0 (infinite), immediate=true
  end

  -- Ensure the watcher timer is canceled if someone destroys us elsewhere
  local base_destroy = self.destroy
  self.destroy = function(s, ...)
    if watcher_handle then timer.cancel(watcher_handle) watcher_handle = nil end
    if timeout_handle then timer.cancel(timeout_handle) timeout_handle = nil end
    if base_destroy then return base_destroy(s, ...) end
  end

  -- Start now if attached, else defer until attach
  if self._eid then
    start_watcher()
  else
    self:run_custom_func(function()
      start_watcher()
    end)
  end

  return self
end


-- Global update dispatcher (called once per frame from Lua main loop)
function node.update_all(dt)
  -- tracy.zoneBeginN("lua node.update_all") -- just some default depth to avoid bugs
  for i = #updatables, 1, -1 do
    local obj = updatables[i]
    if obj._eid and (not registry.valid or registry:valid(obj._eid)) then
      obj:update(dt)
    else
      table.remove(updatables, i)
    end
  end
  -- tracy.zoneEnd()
end



return node
