-- scripts/ai/init.lua
ai = {
    actions = {},
    goal_selectors = {},
    blackboard_init = {},
    entity_types = {},
    worldstate_updaters = {}
}

local function load_directory(dir, outTable, assignByReturnName)
    local list_fn = masterStateLua.list_lua_files
    for _, name in ipairs(list_fn(dir)) do
        local mod = require(dir .. "." .. name)
        if assignByReturnName and mod.name then
            outTable[mod.name] = mod
        else
            outTable[name] = mod
        end
    end
end

load_directory("ai.actions", ai.actions, true)
load_directory("ai.goal_selectors", ai.goal_selectors, false)
load_directory("ai.blackboard_init", ai.blackboard_init, false)
load_directory("ai.entity_types", ai.entity_types, false)
ai.worldstate_updaters = require("ai.worldstate_updaters")

-- scripts/ai/actions/eat.lua
return {
    name = "eat",
    cost = 1,
    pre = { hungry = true },
    post = { hungry = false },

    start = function(self, e)
        print("Entity", e, "is eating.")
    end,

    update = coroutine.wrap(function(self, e, dt)
        wait(1.0)
        return "SUCCESS"
    end),

    finish = function(self, e)
        print("Done eating.")
    end
}

-- scripts/ai/goal_selectors/kobold.lua
return function(entity)
    local blackboard = get_blackboard(entity)
    if blackboard.hunger > 0.7 then
        ai.set_goal(entity, { hungry = false })
    elseif blackboard.enemy_visible then
        ai.set_goal(entity, { enemyalive = false })
    else
        ai.set_goal(entity, { wandering = true })
    end
end

-- scripts/ai/blackboard_init/kobold.lua
return function(entity)
    local bb = get_blackboard(entity)
    bb.hunger = 0.5
    bb.enemy_visible = false
    bb.last_ate_time = 0
end

-- scripts/ai/entity_types/kobold.lua
return {
    initial = {
        hungry = true,
        enemyvisible = false,
        has_food = true
    },
    goal = {
        hungry = false
    }
}

-- scripts/ai/worldstate_updaters.lua
return {
    hunger_check = function(entity, dt)
        local bb = get_blackboard(entity)
        bb.hunger = bb.hunger + dt * 0.01
        ai.set_worldstate(entity, "hungry", bb.hunger > 0.7)
    end,

    enemy_sight = function(entity, dt)
        local visible = check_if_enemy_visible(entity)
        ai.set_worldstate(entity, "enemyvisible", visible)
        local bb = get_blackboard(entity)
        bb.enemy_visible = visible
    end
}

-- scripts/test/spawn_demo.lua
local function spawn_kobold()
    local kobold = create_ai_entity("kobold")
    print("Spawned AI entity:", kobold)

    local bb = get_blackboard(kobold)
    bb.enemy_visible = true

    force_interrupt(kobold)
end

spawn_kobold()
