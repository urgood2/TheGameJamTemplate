local Object = require("external/object")
local task = require("task/task")

local node = Object:extend()

-- This script is a MonoBehavior script that will be attached to a node. It should be named accordingly for the component it represents, and linked up c++ side.

-- Called once, right after the component is attached.

function node:init(args) end

-- Called every frame by script_system_update()
function node:update(dt)
    print('node [#' .. self.id() .. '] update()', transform)
    -- local transform = self.owner:get(self.id(), Transform)
    
    -- coroutine task example
    -- task.run_named_task("blinker", function()
    --     print("start")
    --     task.wait(1.0)
    --     print("end")
    --   end)
    
    print("tasks active:", task.count_tasks())
end

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


return node
