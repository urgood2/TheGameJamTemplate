ai = {
    actions = {}, -- Named actions (e.g. "eat", "wander")
    goal_selectors = {}, -- Functions that set the goal state dynamically per entity
    blackboard_init = {}, -- Functions that initialize each entity’s blackboard
    entity_types = {}, -- Worldstate presets for creatures
    worldstate_updaters = {} -- Functions that update worldstate from blackboard/sensory data
}

local function load_directory(dir, outTable, assignByReturnName)
    local list_fn = list_lua_files
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