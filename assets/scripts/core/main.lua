local globals = require("init.globals")
require("registry")
local task = require("task/task")
local sol_coroutine = require("coroutine")  -- Sol overrides this in require()

-- Represents game loop main module
main = {}


--------------------------------------------------------------------
-- 1. Define the script table that will live inside ScriptComponent
--------------------------------------------------------------------
local PlayerLogic = {
    -- Custom data carried by this table
    speed = 150,      -- pixels / second
    hp    = 10,

    -- Called once, right after the component is attached.
    init = function(self)
        print("[player] init, entity-id =", self.id)
        self.x, self.y = 0, 0     -- give the table some state
        
    end,

    -- Called every frame by script_system_update()
    update = function(self, dt)
        -- Simple movement example
        self.x = self.x + self.speed * dt
        -- print("[player] update; entity-id =", self.id, "position:", self.x, self.y)
        -- You still have full registry access through self.owner
        -- (e.g., self.owner:get(self.id, Transform).x = self.x)
        
        if not self._has_spawned_task then
            print("[player]", self.id, " update; spawning coroutine task")
            task.run_named_task(self, "blinker", function()
                print("start lua coroutine task")
                task.wait(5.0)
                print("end lua coroutine task")
            end)
            
            print("[player]", self.id, " update; spawning coroutine task2")
            task.run_named_task(self, "blinker1", function()
                print("start lua coroutine task 2")
                task.wait(6.0)
                print("end lua coroutine task 2")
            end)
            
            print("[player]", self.id, " update; spawning coroutine task3")
            task.run_named_task(self, "blinker2", function()
                print("start lua coroutine task 3")
                task.wait(7.0)
                print("end lua coroutine task 3")
            end)
            
            self._has_spawned_task = true
        end
    end,

    -- Called just before the entity is destroyed
    destroy = function(self)
        print("[player] destroy; final position:", self.x, self.y)
    end
}

function main.init()
    -- -- entity creation example
    bowser = registry:create()
    -- -- registry:emplace(bowser, Transform, {})-- Pass an empty table for defualt construction
    
    registry:add_script(bowser, PlayerLogic) -- Attach the script to the entity
    
    
    -- transformComp = registry:emplace(bowser, Transform)
    
    -- transformComp.actualX = 100
    -- transformComp.actualY = 200
    
    -- assert(registry:has(bowser, Transform))
    

    -- assert(not registry:any_of(bowser, -1, -2))

    -- transform = registry:get(bowser, Transform)
    -- transform.actualX = 10
    -- print('Bowser position = ' .. transform.actualX .. ', ' .. transform.actualY)
    

end
  
function main.update(dt)
    -- entity iteration example
    -- local view = registry:runtime_view(Transform)
    -- assert(view:size_hint() > 0)

    -- -- local koopa = registry:create()
    -- registry:emplace(koopa, Transform(100, -200))
    -- transform = registry:get(koopa, Transform)
    -- print('Koopa position = ' .. tostring(transform))

    -- assert(view:size_hint() == 2)

    -- view:each(function(entity)
    --     print('Iterating Transform entity: ' .. entity)
    --     -- registry:remove(entity, Transform)
    -- end)

    -- -- assert(view:size_hint() == 0)
    -- print ('All Transform entities processed, view size: ' .. view:size_hint())

end

function main.draw(dt)
    -- This is where you would handle rendering logic
    -- For now, we just print a message
    -- print("Drawing frame with dt: " .. dt)
end