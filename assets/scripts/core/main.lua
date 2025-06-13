local globals = require("init.globals")

function init()
    -- entity creation example
    bowser = registry:create()
    assert(bowser == 0 and registry:size() == 1)
    registry:emplace(bowser, Transform(5, 6))
    assert(registry:has(bowser, Transform))
    assert(registry:has(bowser, Transform.type_id()))
    
    Layer

    assert(not registry:any_of(bowser, -1, -2))

    transform = registry:get(bowser, Transform)
    transform.x = transform.x + 10
    print('Bowser position = ' .. tostring(transform))

end
  
function update(dt)
    -- entity iteration example
    local view = registry:runtime_view(Transform)
    assert(view:size_hint() > 0)

    local koopa = registry:create()
    registry:emplace(koopa, Transform(100, -200))
    transform = registry:get(koopa, Transform)
    print('Koopa position = ' .. tostring(transform))

    assert(view:size_hint() == 2)

    view:each(function(entity)
    print('Remove Transform from entity: ' .. entity)
    registry:remove(entity, Transform)
    end)

    assert(view:size_hint() == 0)

end