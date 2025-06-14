local globals = require("init.globals")
require("registry")

-- Represents game loop main module
main = {}

function main.init()
    -- -- entity creation example
    -- bowser = registry:create()
    -- -- registry:emplace(bowser, Transform, {})-- Pass an empty table for defualt construction
    
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