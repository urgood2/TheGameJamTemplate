local task = require("task/task")

local node = {}

-- This script is a MonoBehavior script that will be attached to a node. It should be named accordingly for the component it represents, and linked up c++ side.

function node:init()
  print('node [#' .. self.id() .. '] init()', self)
end

function node:update(dt)
  local transform = self.owner:get(self.id(), Transform)
  transform.x = transform.x + 1
  print('node [#' .. self.id() .. '] update()', transform)
  
  if true then
    -- coroutine task example
    task.run_named_task("blinker", function()
        print("start")
        task.wait(1.0)
        print("end")
      end)
  end
  
  print("tasks active:", task.count_tasks())

end

function node:destroy()
  print('bye, bye! from: node #' .. self.id())
end

return node
