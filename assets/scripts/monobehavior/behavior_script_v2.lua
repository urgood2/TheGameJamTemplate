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

return node
