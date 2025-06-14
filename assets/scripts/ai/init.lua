
ai = ai or {}  -- preserve C++ bindings if they exist

ai.actions = ai.actions or {} -- Actions are named functions that can be executed by entities
ai.goal_selectors = ai.goal_selectors or {} -- Goal selectors are functions that set the goal state dynamically per entity
ai.blackboard_init = ai.blackboard_init or {} -- Blackboard initialization functions for each entity type
ai.entity_types = ai.entity_types or {} -- Entity types are presets for worldstate, e.g. kobold, goblin, etc.
ai.worldstate_updaters = ai.worldstate_updaters or {} -- Worldstate updaters are functions that update worldstate from blackboard/sensory data

local function load_directory(dir, outTable, assignByReturnName)
    local list_fn = ai.list_lua_files
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