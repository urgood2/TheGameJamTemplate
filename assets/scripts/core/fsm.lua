--[[
================================================================================
fsm.lua - Declarative Finite State Machine
================================================================================
State machine helper with automatic state tag management. Reduces boilerplate
for entity state transitions.

NOTE: FSM state names are independent of global state constants (PLANNING_STATE,
COMBAT_STATE, etc.). If you need to sync with ECS state tags, use the syncTags
option or call script:setState() manually in enter/exit callbacks.

Usage:
    local FSM = require("core.fsm")

    local enemyFSM = FSM.define {
        initial = "idle",
        states = {
            idle = {
                enter = function(self) print("entering idle") end,
                update = function(self, dt) end,
                exit = function(self) print("leaving idle") end,
            },
            chase = {
                enter = function(self) self.speed = 100 end,
                update = function(self, dt)
                    Q.chase(self.entity, player, self.speed)
                end,
            },
            attack = { ... },
        },
    }

    local fsm = enemyFSM:new(entity, { speed = 50 })
    fsm:transition("chase")
    fsm:update(dt)

Dependencies:
    - core.entity_cache (validation)
]]

if _G.__FSM__ then return _G.__FSM__ end

local FSM = {}
FSM.__index = FSM

local entity_cache = require("core.entity_cache")

local FsmDefinition = {}
FsmDefinition.__index = FsmDefinition

local FsmInstance = {}
FsmInstance.__index = FsmInstance

function FSM.define(config)
    local def = setmetatable({}, FsmDefinition)
    def._initial = config.initial or "idle"
    def._states = config.states or {}
    def._transitions = config.transitions or {}
    return def
end

function FsmDefinition:new(entity, data)
    local instance = setmetatable({}, FsmInstance)
    instance._definition = self
    instance._entity = entity
    instance._currentState = nil
    instance._data = data or {}
    instance._paused = false
    
    instance.entity = entity
    for k, v in pairs(instance._data) do
        instance[k] = v
    end
    
    instance:transition(self._initial)
    
    return instance
end

function FsmInstance:_getStateConfig(stateName)
    return self._definition._states[stateName]
end

function FsmInstance:transition(newState)
    if self._currentState == newState then
        return false
    end
    
    if not self._definition._states[newState] then
        print(string.format("[FSM] Unknown state: %s", newState))
        return false
    end
    
    local oldState = self._currentState
    local oldConfig = oldState and self:_getStateConfig(oldState)
    local newConfig = self:_getStateConfig(newState)
    
    if oldConfig and oldConfig.exit then
        oldConfig.exit(self)
    end
    
    self._currentState = newState
    
    if self._entity and entity_cache.valid(self._entity) then
        local clear_state_tags = _G.clear_state_tags
        local add_state_tag = _G.add_state_tag
        
        if clear_state_tags then
            clear_state_tags(self._entity)
        end
        if add_state_tag then
            add_state_tag(self._entity, newState)
        end
    end
    
    if newConfig and newConfig.enter then
        newConfig.enter(self)
    end
    
    return true
end

function FsmInstance:update(dt)
    if self._paused then return end
    if not self._currentState then return end
    
    local config = self:_getStateConfig(self._currentState)
    if config and config.update then
        config.update(self, dt)
    end
end

function FsmInstance:getState()
    return self._currentState
end

function FsmInstance:is(stateName)
    return self._currentState == stateName
end

function FsmInstance:pause()
    self._paused = true
end

function FsmInstance:resume()
    self._paused = false
end

function FsmInstance:isPaused()
    return self._paused
end

function FsmInstance:set(key, value)
    self._data[key] = value
    self[key] = value
end

function FsmInstance:get(key)
    return self._data[key]
end

function FsmInstance:can(stateName)
    return self._definition._states[stateName] ~= nil
end

function FsmInstance:listStates()
    local states = {}
    for name, _ in pairs(self._definition._states) do
        table.insert(states, name)
    end
    return states
end

_G.__FSM__ = FSM
return FSM
