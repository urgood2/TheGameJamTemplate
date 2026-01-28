# Hybrid DSL Tutorial System - Implementation Plan

> **Status**: Planning Complete, Implementation Pending  
> **Author**: AI Assistant  
> **Date**: January 2026

## Overview

A dynamic, step-based tutorial authoring system that wraps the existing coroutine tutorial infrastructure (`tutorial_system_v2`) and dialogue system (`tutorial.dialogue`). Tutorials are authored as declarative scripts with a fluent API, where objectives auto-detect player actions via signal listeners (event-driven, no polling).

### Target Syntax

```lua
local Tutorial = require("tutorial.script_dsl")

Tutorial.new("onboarding")
    :step("welcome", function(t)
        t:say("Welcome!", { speaker = "Guide" })
    end)
    :step("movement", function(t)
        t:say("Use WASD to move.")
        t:objective("MOVE_DISTANCE", { distance = 100 })
        t:say("Great job!")
    end)
    :onComplete(function()
        signal.emit("tutorial_complete", "onboarding")
    end)
    :register()
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         script_dsl.lua                              │
│  (Fluent builder: :step(), :say(), :objective(), :register())       │
└─────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Generated Coroutine Function                      │
│  (Yields on dialogue completion, objective completion, etc.)        │
└─────────────────────────────────────────────────────────────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              ▼                    ▼                    ▼
┌─────────────────────┐ ┌─────────────────────┐ ┌─────────────────────┐
│  tutorial.dialogue  │ │   objectives.lua    │ │   progress.lua      │
│  (Speaker, box,     │ │  (Signal listeners, │ │  (SaveManager       │
│   spotlight, text)  │ │   condition checks) │ │   persistence)      │
└─────────────────────┘ └─────────────────────┘ └─────────────────────┘
              │                    │
              │                    ▼
              │          ┌─────────────────────┐
              │          │ objective_types.lua │
              │          │ (27 type defs with  │
              │          │  signal mappings)   │
              │          └─────────────────────┘
              │                    │
              ▼                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     signal_group.lua + hump.signal                  │
│             (Event-driven: enemy_killed, player_moved, etc.)        │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Existing Systems Integration

### 1. Tutorial System V2 (C++)
**Location**: `src/systems/tutorial/tutorial_system_v2.cpp` + `.hpp`

The C++ side drives Lua coroutines. It expects:
```lua
tutorials["tutorial_name"] = coroutine.create(function() ... end)
```

### 2. Dialogue System
**Location**: `assets/scripts/tutorial/dialogue/init.lua`

Full-featured dialogue with:
- Speaker sprites with shaders and jiggle effects
- Styled dialogue boxes with typewriter text
- Spotlight/focus effects
- Input prompts
- Fluent API: `:say()`, `:waitForInput()`, `:focusOn()`, etc.

### 3. Signal System
**Location**: `assets/scripts/external/hump/signal.lua` + `assets/scripts/core/signal_group.lua`

50+ game events already emitted:
- `enemy_killed`, `enemy_damaged`
- `player_moved`, `player_damaged`, `player_level_up`
- `spell_cast`, `pickup_collected`
- `wand_panel_opened`, `inventory_opened`
- `phase_changed`, `wave_complete`
- etc.

### 4. SaveManager
**Location**: `assets/scripts/core/save_manager.lua`

Collector pattern for persistence:
```lua
SaveManager.register("tutorial_progress", {
    collect = function() return { completed = {...}, current_step = ... } end,
    distribute = function(data) ... end,
})
```

### 5. Base Wait Functions
**Location**: `assets/scripts/tutorial/base_functions.lua`

Existing coroutine utilities:
- `wait(seconds)` - Time-based wait
- `waitForKeyPress(key)` - Input wait
- `waitForEvent(event_name)` - C++ event bridge
- `waitForCondition(fn)` - Polling condition

---

## Files to Create

### 1. `assets/scripts/tutorial/helpers.lua`

Coroutine utilities, deep merge, wait helpers.

```lua
--[[
================================================================================
TUTORIAL HELPERS
================================================================================
Utility functions for the tutorial DSL system.
]]

local helpers = {}

--------------------------------------------------------------------------------
-- TABLE UTILITIES
--------------------------------------------------------------------------------

--- Deep merge two tables (b overrides a)
--- @param a table Base table
--- @param b table Override table
--- @return table Merged result
function helpers.deep_merge(a, b)
    local result = {}
    for k, v in pairs(a) do
        if type(v) == "table" then
            result[k] = helpers.deep_merge(v, b[k] or {})
        else
            result[k] = v
        end
    end
    for k, v in pairs(b or {}) do
        if result[k] == nil then
            result[k] = v
        elseif type(v) == "table" and type(result[k]) == "table" then
            result[k] = helpers.deep_merge(result[k], v)
        else
            result[k] = v
        end
    end
    return result
end

--------------------------------------------------------------------------------
-- COROUTINE UTILITIES
--------------------------------------------------------------------------------

--- Frame-based wait (uses GetFrameTime if available)
--- @param seconds number Seconds to wait
function helpers.wait_seconds(seconds)
    local elapsed = 0
    while elapsed < seconds do
        local dt = GetFrameTime and GetFrameTime() or 0.016
        elapsed = elapsed + dt
        coroutine.yield()
    end
end

--- Wait for a condition with timeout
--- @param condition function Returns true when done
--- @param timeout number? Max seconds to wait (default: infinite)
--- @return boolean success True if condition met, false if timeout
function helpers.wait_for_condition(condition, timeout)
    local elapsed = 0
    while not condition() do
        if timeout and elapsed >= timeout then
            return false
        end
        local dt = GetFrameTime and GetFrameTime() or 0.016
        elapsed = elapsed + dt
        coroutine.yield()
    end
    return true
end

--- Wait for a flag table to have flag.done == true
--- @param flag table { done = false }
--- @param timeout number? Max seconds
--- @return boolean
function helpers.wait_for_flag(flag, timeout)
    return helpers.wait_for_condition(function()
        return flag.done == true
    end, timeout)
end

--------------------------------------------------------------------------------
-- UNIQUE ID GENERATION
--------------------------------------------------------------------------------

local id_counter = 0

--- Generate a unique ID for internal tracking
--- @param prefix string? Optional prefix
--- @return string
function helpers.unique_id(prefix)
    id_counter = id_counter + 1
    return (prefix or "id") .. "_" .. os.time() .. "_" .. id_counter
end

return helpers
```

---

### 2. `assets/scripts/tutorial/progress.lua`

SaveManager-based tutorial progress persistence.

```lua
--[[
================================================================================
TUTORIAL PROGRESS
================================================================================
Persistence layer for tutorial completion state using SaveManager's collector pattern.
]]

local SaveManager = require("core.save_manager")

local TutorialProgress = {
    _data = {
        completed = {},           -- { tutorial_id = true, ... }
        step_progress = {},       -- { tutorial_id = { step_id = true, ... }, ... }
        current_tutorial = nil,   -- Currently active tutorial ID
        current_step = nil,       -- Current step within active tutorial
    },
}

--------------------------------------------------------------------------------
-- SAVEMANAGER COLLECTOR
--------------------------------------------------------------------------------

SaveManager.register("tutorial_progress", {
    collect = function()
        return {
            completed = TutorialProgress._data.completed,
            step_progress = TutorialProgress._data.step_progress,
            -- Don't persist current_tutorial/current_step (runtime only)
        }
    end,
    distribute = function(data)
        if data then
            TutorialProgress._data.completed = data.completed or {}
            TutorialProgress._data.step_progress = data.step_progress or {}
        end
    end,
})

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--- Check if a tutorial has been completed
--- @param tutorial_id string
--- @return boolean
function TutorialProgress.is_completed(tutorial_id)
    return TutorialProgress._data.completed[tutorial_id] == true
end

--- Mark a tutorial as completed
--- @param tutorial_id string
function TutorialProgress.mark_completed(tutorial_id)
    TutorialProgress._data.completed[tutorial_id] = true
    TutorialProgress._data.step_progress[tutorial_id] = nil  -- Clear step progress
    SaveManager.save()
end

--- Check if a specific step has been completed
--- @param tutorial_id string
--- @param step_id string
--- @return boolean
function TutorialProgress.is_step_completed(tutorial_id, step_id)
    local steps = TutorialProgress._data.step_progress[tutorial_id]
    return steps and steps[step_id] == true
end

--- Mark a step as completed
--- @param tutorial_id string
--- @param step_id string
function TutorialProgress.mark_step_completed(tutorial_id, step_id)
    if not TutorialProgress._data.step_progress[tutorial_id] then
        TutorialProgress._data.step_progress[tutorial_id] = {}
    end
    TutorialProgress._data.step_progress[tutorial_id][step_id] = true
    -- Don't save on every step (batch at tutorial completion)
end

--- Get/set current tutorial (runtime only, not persisted)
--- @param tutorial_id string?
--- @return string?
function TutorialProgress.current_tutorial(tutorial_id)
    if tutorial_id ~= nil then
        TutorialProgress._data.current_tutorial = tutorial_id
    end
    return TutorialProgress._data.current_tutorial
end

--- Get/set current step (runtime only)
--- @param step_id string?
--- @return string?
function TutorialProgress.current_step(step_id)
    if step_id ~= nil then
        TutorialProgress._data.current_step = step_id
    end
    return TutorialProgress._data.current_step
end

--- Reset all progress (for debug/testing)
function TutorialProgress.reset_all()
    TutorialProgress._data = {
        completed = {},
        step_progress = {},
        current_tutorial = nil,
        current_step = nil,
    }
    SaveManager.save()
end

--- Reset a specific tutorial's progress
--- @param tutorial_id string
function TutorialProgress.reset(tutorial_id)
    TutorialProgress._data.completed[tutorial_id] = nil
    TutorialProgress._data.step_progress[tutorial_id] = nil
    SaveManager.save()
end

return TutorialProgress
```

---

### 3. `assets/scripts/tutorial/objective_types.lua`

27+ objective type definitions with signal mappings.

```lua
--[[
================================================================================
OBJECTIVE TYPES
================================================================================
Defines all supported objective types with their signal mappings and completion logic.

Each type has:
  - signals: Array of {event_name, handler_factory} tuples
  - init: Optional setup function (called when objective starts)
  - check: Optional polling check (for non-signal objectives)
  - default_params: Default parameters for this type
]]

local ObjectiveTypes = {}

--------------------------------------------------------------------------------
-- MOVEMENT OBJECTIVES
--------------------------------------------------------------------------------

ObjectiveTypes.MOVE_TO_POSITION = {
    signals = {
        { "player_moved", function(params, state, complete)
            return function(x, y)
                local dx = x - params.x
                local dy = y - params.y
                local dist = math.sqrt(dx*dx + dy*dy)
                if dist <= (params.threshold or 32) then
                    complete()
                end
            end
        end },
    },
    default_params = { x = 0, y = 0, threshold = 32 },
}

ObjectiveTypes.MOVE_DISTANCE = {
    signals = {
        { "player_moved", function(params, state, complete)
            return function(x, y)
                if not state.start_x then
                    state.start_x, state.start_y = x, y
                    state.total_distance = 0
                else
                    local dx = x - (state.last_x or state.start_x)
                    local dy = y - (state.last_y or state.start_y)
                    state.total_distance = state.total_distance + math.sqrt(dx*dx + dy*dy)
                end
                state.last_x, state.last_y = x, y
                
                if state.total_distance >= params.distance then
                    complete()
                end
            end
        end },
    },
    default_params = { distance = 100 },
}

ObjectiveTypes.MOVE_STEPS = {
    signals = {
        { "player_step", function(params, state, complete)
            return function()
                state.steps = (state.steps or 0) + 1
                if state.steps >= params.count then
                    complete()
                end
            end
        end },
    },
    default_params = { count = 10 },
}

ObjectiveTypes.DASH = {
    signals = {
        { "player_dashed", function(params, state, complete)
            return function()
                state.dashes = (state.dashes or 0) + 1
                if state.dashes >= (params.count or 1) then
                    complete()
                end
            end
        end },
    },
    default_params = { count = 1 },
}

ObjectiveTypes.STAND_STILL = {
    init = function(params, state)
        state.still_time = 0
        state.is_moving = false
    end,
    signals = {
        { "player_moved", function(params, state, complete)
            return function()
                state.is_moving = true
                state.still_time = 0
            end
        end },
        { "frame_update", function(params, state, complete)
            return function(dt)
                if not state.is_moving then
                    state.still_time = state.still_time + dt
                    if state.still_time >= params.duration then
                        complete()
                    end
                end
                state.is_moving = false
            end
        end },
    },
    default_params = { duration = 2.0 },
}

--------------------------------------------------------------------------------
-- COMBAT OBJECTIVES
--------------------------------------------------------------------------------

ObjectiveTypes.KILL_ENEMY = {
    signals = {
        { "enemy_killed", function(params, state, complete)
            return function(entity, enemy_type)
                state.kills = (state.kills or 0) + 1
                if state.kills >= (params.count or 1) then
                    complete()
                end
            end
        end },
    },
    default_params = { count = 1 },
}

ObjectiveTypes.KILL_ENEMY_TYPE = {
    signals = {
        { "enemy_killed", function(params, state, complete)
            return function(entity, enemy_type)
                if enemy_type == params.enemy_type then
                    state.kills = (state.kills or 0) + 1
                    if state.kills >= (params.count or 1) then
                        complete()
                    end
                end
            end
        end },
    },
    default_params = { enemy_type = "slime", count = 1 },
}

ObjectiveTypes.DEAL_DAMAGE = {
    signals = {
        { "damage_dealt", function(params, state, complete)
            return function(amount, target_entity)
                state.total_damage = (state.total_damage or 0) + amount
                if state.total_damage >= params.amount then
                    complete()
                end
            end
        end },
    },
    default_params = { amount = 100 },
}

ObjectiveTypes.TAKE_DAMAGE = {
    signals = {
        { "player_damaged", function(params, state, complete)
            return function(amount, source)
                state.total_damage = (state.total_damage or 0) + amount
                if state.total_damage >= (params.amount or 1) then
                    complete()
                end
            end
        end },
    },
    default_params = { amount = 1 },
}

ObjectiveTypes.TRIGGER_WAND = {
    signals = {
        { "wand_triggered", function(params, state, complete)
            return function(wand_id)
                state.triggers = (state.triggers or 0) + 1
                if state.triggers >= (params.count or 1) then
                    complete()
                end
            end
        end },
    },
    default_params = { count = 1 },
}

ObjectiveTypes.CAST_SPELL = {
    signals = {
        { "spell_cast", function(params, state, complete)
            return function(spell_id, spell_type)
                state.casts = (state.casts or 0) + 1
                if state.casts >= (params.count or 1) then
                    complete()
                end
            end
        end },
    },
    default_params = { count = 1 },
}

ObjectiveTypes.CAST_SPELL_TYPE = {
    signals = {
        { "spell_cast", function(params, state, complete)
            return function(spell_id, spell_type)
                if spell_type == params.spell_type then
                    state.casts = (state.casts or 0) + 1
                    if state.casts >= (params.count or 1) then
                        complete()
                    end
                end
            end
        end },
    },
    default_params = { spell_type = "fireball", count = 1 },
}

ObjectiveTypes.DISCOVER_SPELL_TYPE = {
    signals = {
        { "spell_discovered", function(params, state, complete)
            return function(spell_id, spell_type)
                if spell_type == params.spell_type then
                    complete()
                end
            end
        end },
    },
    default_params = { spell_type = "fireball" },
}

ObjectiveTypes.COLLECT_PICKUP = {
    signals = {
        { "pickup_collected", function(params, state, complete)
            return function(pickup_type, amount)
                if not params.pickup_type or pickup_type == params.pickup_type then
                    state.collected = (state.collected or 0) + (amount or 1)
                    if state.collected >= (params.count or 1) then
                        complete()
                    end
                end
            end
        end },
    },
    default_params = { count = 1 },
}

ObjectiveTypes.BUMP_ENEMY = {
    signals = {
        { "player_bumped_enemy", function(params, state, complete)
            return function(enemy_entity)
                state.bumps = (state.bumps or 0) + 1
                if state.bumps >= (params.count or 1) then
                    complete()
                end
            end
        end },
    },
    default_params = { count = 1 },
}

ObjectiveTypes.LEVEL_UP = {
    signals = {
        { "player_level_up", function(params, state, complete)
            return function(new_level)
                complete()
            end
        end },
    },
    default_params = {},
}

--------------------------------------------------------------------------------
-- UI OBJECTIVES
--------------------------------------------------------------------------------

ObjectiveTypes.OPEN_INVENTORY = {
    signals = {
        { "inventory_opened", function(params, state, complete)
            return function() complete() end
        end },
    },
    default_params = {},
}

ObjectiveTypes.CLOSE_INVENTORY = {
    signals = {
        { "inventory_closed", function(params, state, complete)
            return function() complete() end
        end },
    },
    default_params = {},
}

ObjectiveTypes.OPEN_WAND_PANEL = {
    signals = {
        { "wand_panel_opened", function(params, state, complete)
            return function() complete() end
        end },
    },
    default_params = {},
}

ObjectiveTypes.CLOSE_WAND_PANEL = {
    signals = {
        { "wand_panel_closed", function(params, state, complete)
            return function() complete() end
        end },
    },
    default_params = {},
}

ObjectiveTypes.EQUIP_CARD = {
    signals = {
        { "card_equipped", function(params, state, complete)
            return function(card_id, slot)
                if not params.card_type or card_id == params.card_type then
                    complete()
                end
            end
        end },
    },
    default_params = {},
}

ObjectiveTypes.QUICK_EQUIP = {
    signals = {
        { "quick_equip_used", function(params, state, complete)
            return function() complete() end
        end },
    },
    default_params = {},
}

ObjectiveTypes.DECK_CHANGED = {
    signals = {
        { "deck_changed", function(params, state, complete)
            return function() complete() end
        end },
    },
    default_params = {},
}

--------------------------------------------------------------------------------
-- GAME STATE OBJECTIVES
--------------------------------------------------------------------------------

ObjectiveTypes.ENTER_PHASE = {
    signals = {
        { "phase_changed", function(params, state, complete)
            return function(new_phase)
                if new_phase == params.phase then
                    complete()
                end
            end
        end },
    },
    default_params = { phase = "action" },
}

ObjectiveTypes.ACTION_PHASE_START = {
    signals = {
        { "action_phase_started", function(params, state, complete)
            return function() complete() end
        end },
    },
    default_params = {},
}

ObjectiveTypes.WAVE_COMPLETE = {
    signals = {
        { "wave_complete", function(params, state, complete)
            return function(wave_number)
                if not params.wave or wave_number >= params.wave then
                    complete()
                end
            end
        end },
    },
    default_params = {},
}

ObjectiveTypes.SURVIVE_SECONDS = {
    init = function(params, state)
        state.elapsed = 0
    end,
    signals = {
        { "frame_update", function(params, state, complete)
            return function(dt)
                state.elapsed = (state.elapsed or 0) + dt
                if state.elapsed >= params.duration then
                    complete()
                end
            end
        end },
    },
    default_params = { duration = 30 },
}

--------------------------------------------------------------------------------
-- INPUT OBJECTIVES
--------------------------------------------------------------------------------

ObjectiveTypes.PRESS_KEY = {
    signals = {
        { "key_pressed", function(params, state, complete)
            return function(key)
                if key == params.key then
                    complete()
                end
            end
        end },
    },
    -- Also supports polling fallback
    check = function(params, state)
        if isKeyPressed and isKeyPressed(params.key) then
            return true
        end
        return false
    end,
    default_params = { key = "KEY_SPACE" },
}

ObjectiveTypes.CLICK_MOUSE = {
    signals = {
        { "mouse_clicked", function(params, state, complete)
            return function(button)
                if not params.button or button == params.button then
                    complete()
                end
            end
        end },
    },
    check = function(params, state)
        if IsMouseButtonPressed and IsMouseButtonPressed(params.button or 0) then
            return true
        end
        return false
    end,
    default_params = { button = 0 },
}

--------------------------------------------------------------------------------
-- GENERIC OBJECTIVES
--------------------------------------------------------------------------------

ObjectiveTypes.WAIT_FOR_EVENT = {
    init = function(params, state)
        state.event_received = false
    end,
    signals = {
        -- Dynamically registered based on params.event
    },
    -- Special handling: register signal dynamically
    dynamic_signal = function(params, state, complete)
        return params.event, function(...)
            if params.filter then
                if params.filter(...) then
                    complete()
                end
            else
                complete()
            end
        end
    end,
    default_params = { event = "custom_event" },
}

ObjectiveTypes.CUSTOM = {
    -- Custom objectives use params.check function directly
    check = function(params, state)
        if params.check then
            return params.check(state)
        end
        return false
    end,
    default_params = {},
}

return ObjectiveTypes
```

---

### 4. `assets/scripts/tutorial/objectives.lua`

Objective execution wrapper with signal_group integration.

```lua
--[[
================================================================================
OBJECTIVES
================================================================================
Executes objectives defined in objective_types.lua.
Uses signal_group for automatic cleanup when objectives complete or are cancelled.
]]

local signal = require("external.hump.signal")
local signal_group = require("core.signal_group")
local ObjectiveTypes = require("tutorial.objective_types")
local helpers = require("tutorial.helpers")

local Objectives = {}

--------------------------------------------------------------------------------
-- OBJECTIVE INSTANCE
--------------------------------------------------------------------------------

local ObjectiveInstance = {}
ObjectiveInstance.__index = ObjectiveInstance

--- Create a new objective instance
--- @param type_name string Objective type (e.g., "KILL_ENEMY")
--- @param params table? Parameters for this objective
--- @param group_name string? Signal group name for cleanup
--- @return table ObjectiveInstance
function ObjectiveInstance.new(type_name, params, group_name)
    local type_def = ObjectiveTypes[type_name]
    if not type_def then
        error("Unknown objective type: " .. tostring(type_name))
    end
    
    local self = setmetatable({}, ObjectiveInstance)
    self.type_name = type_name
    self.type_def = type_def
    self.params = helpers.deep_merge(type_def.default_params or {}, params or {})
    self.state = {}
    self.completed = false
    self.cancelled = false
    self.group_name = group_name or helpers.unique_id("objective")
    self.signal_group = signal_group.new(self.group_name)
    self._on_complete = nil
    
    return self
end

--- Start listening for objective completion
--- @param on_complete function? Callback when complete
function ObjectiveInstance:start(on_complete)
    self._on_complete = on_complete
    
    -- Run init if defined
    if self.type_def.init then
        self.type_def.init(self.params, self.state)
    end
    
    -- Create completion function
    local function complete()
        if self.completed or self.cancelled then return end
        self.completed = true
        self.signal_group:cleanup()
        if self._on_complete then
            self._on_complete()
        end
    end
    
    -- Register static signals
    if self.type_def.signals then
        for _, sig_def in ipairs(self.type_def.signals) do
            local event_name = sig_def[1]
            local handler_factory = sig_def[2]
            local handler = handler_factory(self.params, self.state, complete)
            self.signal_group:on(event_name, handler)
        end
    end
    
    -- Register dynamic signal if defined
    if self.type_def.dynamic_signal then
        local event_name, handler = self.type_def.dynamic_signal(self.params, self.state, complete)
        if event_name and handler then
            self.signal_group:on(event_name, handler)
        end
    end
end

--- Cancel the objective and cleanup
function ObjectiveInstance:cancel()
    if self.completed or self.cancelled then return end
    self.cancelled = true
    self.signal_group:cleanup()
end

--- Check polling condition (for objectives that support it)
--- @return boolean
function ObjectiveInstance:check()
    if self.completed then return true end
    if self.type_def.check then
        return self.type_def.check(self.params, self.state)
    end
    return false
end

--- Is this objective done?
--- @return boolean
function ObjectiveInstance:is_done()
    return self.completed
end

--------------------------------------------------------------------------------
-- MODULE API
--------------------------------------------------------------------------------

--- Create and start an objective that blocks the coroutine until complete
--- @param type_name string Objective type
--- @param params table? Parameters
--- @param group_name string? Group name for cleanup
function Objectives.wait_for(type_name, params, group_name)
    local done_flag = { done = false }
    
    local objective = ObjectiveInstance.new(type_name, params, group_name)
    objective:start(function()
        done_flag.done = true
    end)
    
    -- If objective supports polling, check each frame
    local has_polling = objective.type_def.check ~= nil
    
    while not done_flag.done do
        -- Check polling condition
        if has_polling and objective:check() then
            objective.completed = true
            objective.signal_group:cleanup()
            done_flag.done = true
            break
        end
        coroutine.yield()
    end
end

--- Create an objective instance without blocking (for parallel objectives)
--- @param type_name string
--- @param params table?
--- @param group_name string?
--- @return table ObjectiveInstance
function Objectives.create(type_name, params, group_name)
    return ObjectiveInstance.new(type_name, params, group_name)
end

--- Convenience: wait for any of multiple objectives
--- @param objectives table[] Array of {type_name, params} tuples
--- @param group_name string?
function Objectives.wait_for_any(objectives, group_name)
    local done_flag = { done = false }
    local instances = {}
    
    for _, obj_def in ipairs(objectives) do
        local instance = ObjectiveInstance.new(obj_def[1], obj_def[2], group_name)
        instance:start(function()
            done_flag.done = true
        end)
        table.insert(instances, instance)
    end
    
    while not done_flag.done do
        -- Check polling for all
        for _, instance in ipairs(instances) do
            if instance:check() then
                instance.completed = true
                instance.signal_group:cleanup()
                done_flag.done = true
                break
            end
        end
        coroutine.yield()
    end
    
    -- Cleanup all
    for _, instance in ipairs(instances) do
        instance:cancel()
    end
end

--- Convenience: wait for all objectives
--- @param objectives table[] Array of {type_name, params} tuples
--- @param group_name string?
function Objectives.wait_for_all(objectives, group_name)
    local remaining = #objectives
    local instances = {}
    
    for _, obj_def in ipairs(objectives) do
        local instance = ObjectiveInstance.new(obj_def[1], obj_def[2], group_name)
        instance:start(function()
            remaining = remaining - 1
        end)
        table.insert(instances, instance)
    end
    
    while remaining > 0 do
        for _, instance in ipairs(instances) do
            if not instance.completed and instance:check() then
                instance.completed = true
                instance.signal_group:cleanup()
                remaining = remaining - 1
            end
        end
        coroutine.yield()
    end
end

return Objectives
```

---

### 5. `assets/scripts/tutorial/script_dsl.lua`

Main DSL module with fluent API.

```lua
--[[
================================================================================
TUTORIAL SCRIPT DSL
================================================================================
Declarative tutorial authoring with fluent API.

Usage:
    local Tutorial = require("tutorial.script_dsl")

    Tutorial.new("onboarding")
        :step("welcome", function(t)
            t:say("Welcome to the game!", { speaker = "Guide" })
        end)
        :step("movement", function(t)
            t:say("Use WASD to move around.")
            t:objective("MOVE_DISTANCE", { distance = 100 })
            t:say("Great job! You moved 100 units.")
        end)
        :step("combat", function(t)
            t:say("Now let's learn combat.")
            t:objective("KILL_ENEMY", { count = 1 })
        end)
        :onComplete(function()
            print("Tutorial complete!")
        end)
        :register()

    -- Start the tutorial
    Tutorial.start("onboarding")
]]

local signal = require("external.hump.signal")
local TutorialDialogue = require("tutorial.dialogue")
local Objectives = require("tutorial.objectives")
local Progress = require("tutorial.progress")
local helpers = require("tutorial.helpers")

local Tutorial = {}
Tutorial.__index = Tutorial

-- Global registry
local _registry = {}
local _active_tutorial = nil

--------------------------------------------------------------------------------
-- STEP CONTEXT (passed to step functions)
--------------------------------------------------------------------------------

local StepContext = {}
StepContext.__index = StepContext

function StepContext.new(tutorial, step_id)
    local self = setmetatable({}, StepContext)
    self.tutorial = tutorial
    self.step_id = step_id
    self._dialogue_queue = {}
    self._group_name = tutorial.id .. "_" .. step_id
    return self
end

--- Queue dialogue text
--- @param text string Text to display
--- @param opts table? Options (speaker, typingSpeed, effects, etc.)
--- @return StepContext self
function StepContext:say(text, opts)
    table.insert(self._dialogue_queue, {
        type = "say",
        text = text,
        opts = opts or {},
    })
    return self
end

--- Queue focus spotlight
--- @param target table {x, y} or entity
--- @param size number? Spotlight size
--- @return StepContext self
function StepContext:focusOn(target, size)
    table.insert(self._dialogue_queue, {
        type = "focus",
        target = target,
        size = size,
    })
    return self
end

--- Queue unfocus
--- @return StepContext self
function StepContext:unfocus()
    table.insert(self._dialogue_queue, {
        type = "unfocus",
    })
    return self
end

--- Wait for objective completion (blocking)
--- @param type_name string Objective type
--- @param params table? Objective parameters
--- @return StepContext self
function StepContext:objective(type_name, params)
    table.insert(self._dialogue_queue, {
        type = "objective",
        objective_type = type_name,
        params = params or {},
    })
    return self
end

--- Wait for multiple objectives (any)
--- @param objectives table[] Array of {type_name, params}
--- @return StepContext self
function StepContext:objectiveAny(objectives)
    table.insert(self._dialogue_queue, {
        type = "objective_any",
        objectives = objectives,
    })
    return self
end

--- Wait for multiple objectives (all)
--- @param objectives table[] Array of {type_name, params}
--- @return StepContext self
function StepContext:objectiveAll(objectives)
    table.insert(self._dialogue_queue, {
        type = "objective_all",
        objectives = objectives,
    })
    return self
end

--- Wait for seconds
--- @param seconds number
--- @return StepContext self
function StepContext:wait(seconds)
    table.insert(self._dialogue_queue, {
        type = "wait",
        duration = seconds,
    })
    return self
end

--- Execute callback
--- @param fn function
--- @return StepContext self
function StepContext:call(fn)
    table.insert(self._dialogue_queue, {
        type = "call",
        fn = fn,
    })
    return self
end

--- Execute the queued actions (called internally)
function StepContext:_execute()
    local dialogue = nil
    local dialogue_batch = {}
    
    local function flush_dialogue()
        if #dialogue_batch == 0 then return end
        
        -- Create dialogue instance and chain all batched says
        dialogue = TutorialDialogue.new(self.tutorial.config.dialogue or {})
        
        for _, item in ipairs(dialogue_batch) do
            if item.type == "say" then
                dialogue:say(item.text, item.opts)
            elseif item.type == "focus" then
                dialogue:focusOn(item.target, item.size)
            elseif item.type == "unfocus" then
                dialogue:unfocus()
            end
        end
        
        -- Wait for dialogue completion
        local done_flag = { done = false }
        dialogue:onComplete(function()
            done_flag.done = true
        end)
        dialogue:start()
        
        helpers.wait_for_flag(done_flag)
        
        dialogue_batch = {}
        dialogue = nil
    end
    
    for _, action in ipairs(self._dialogue_queue) do
        if action.type == "say" or action.type == "focus" or action.type == "unfocus" then
            -- Batch dialogue actions
            table.insert(dialogue_batch, action)
        else
            -- Non-dialogue action: flush dialogue first
            flush_dialogue()
            
            if action.type == "objective" then
                Objectives.wait_for(action.objective_type, action.params, self._group_name)
            elseif action.type == "objective_any" then
                Objectives.wait_for_any(action.objectives, self._group_name)
            elseif action.type == "objective_all" then
                Objectives.wait_for_all(action.objectives, self._group_name)
            elseif action.type == "wait" then
                helpers.wait_seconds(action.duration)
            elseif action.type == "call" then
                action.fn()
            end
        end
    end
    
    -- Flush any remaining dialogue
    flush_dialogue()
end

--------------------------------------------------------------------------------
-- TUTORIAL BUILDER
--------------------------------------------------------------------------------

--- Create a new tutorial builder
--- @param id string Unique tutorial ID
--- @return Tutorial
function Tutorial.new(id)
    local self = setmetatable({}, Tutorial)
    self.id = id
    self.steps = {}       -- Ordered list of step definitions
    self.config = {
        dialogue = {},    -- Default dialogue config
        skip_completed = true,  -- Skip already-completed steps
    }
    self._on_complete = nil
    self._on_skip = nil
    return self
end

--- Add a step to the tutorial
--- @param step_id string Step identifier
--- @param step_fn function Step function receiving StepContext
--- @return Tutorial self
function Tutorial:step(step_id, step_fn)
    table.insert(self.steps, {
        id = step_id,
        fn = step_fn,
    })
    return self
end

--- Configure default dialogue settings
--- @param config table Dialogue configuration
--- @return Tutorial self
function Tutorial:dialogueConfig(config)
    self.config.dialogue = helpers.deep_merge(self.config.dialogue, config)
    return self
end

--- Set completion callback
--- @param fn function
--- @return Tutorial self
function Tutorial:onComplete(fn)
    self._on_complete = fn
    return self
end

--- Set skip callback (when user skips entire tutorial)
--- @param fn function
--- @return Tutorial self
function Tutorial:onSkip(fn)
    self._on_skip = fn
    return self
end

--- Set whether to skip completed steps
--- @param skip boolean
--- @return Tutorial self
function Tutorial:skipCompleted(skip)
    self.config.skip_completed = skip
    return self
end

--- Register this tutorial in the global registry
--- @return Tutorial self
function Tutorial:register()
    _registry[self.id] = self
    
    -- Also register with the C++ tutorial system
    if tutorials then
        tutorials[self.id] = function()
            return self:_build_coroutine()
        end
    end
    
    return self
end

--- Build the coroutine function for tutorial_system_v2
--- @return function
function Tutorial:_build_coroutine()
    local tutorial = self
    
    return coroutine.create(function()
        Progress.current_tutorial(tutorial.id)
        
        for i, step_def in ipairs(tutorial.steps) do
            -- Check if step already completed
            if tutorial.config.skip_completed and Progress.is_step_completed(tutorial.id, step_def.id) then
                -- Skip this step
            else
                Progress.current_step(step_def.id)
                
                -- Create step context and execute
                local ctx = StepContext.new(tutorial, step_def.id)
                step_def.fn(ctx)
                ctx:_execute()
                
                -- Mark step complete
                Progress.mark_step_completed(tutorial.id, step_def.id)
            end
        end
        
        -- Tutorial complete
        Progress.mark_completed(tutorial.id)
        Progress.current_tutorial(nil)
        Progress.current_step(nil)
        _active_tutorial = nil
        
        if tutorial._on_complete then
            tutorial._on_complete()
        end
        
        signal.emit("tutorial_complete", tutorial.id)
    end)
end

--------------------------------------------------------------------------------
-- MODULE API
--------------------------------------------------------------------------------

--- Get a registered tutorial
--- @param id string
--- @return Tutorial?
function Tutorial.get(id)
    return _registry[id]
end

--- Start a tutorial
--- @param id string Tutorial ID
--- @param opts table? { force = bool, from_step = string }
function Tutorial.start(id, opts)
    opts = opts or {}
    
    local tutorial = _registry[id]
    if not tutorial then
        print("[Tutorial] Unknown tutorial: " .. tostring(id))
        return
    end
    
    -- Check if already completed (unless force)
    if not opts.force and Progress.is_completed(id) then
        print("[Tutorial] Already completed: " .. id)
        return
    end
    
    -- Stop any active tutorial
    if _active_tutorial then
        Tutorial.stop()
    end
    
    _active_tutorial = tutorial
    
    -- Reset progress if forcing
    if opts.force then
        Progress.reset(id)
    end
    
    -- Start via tutorial system
    if startTutorial then
        startTutorial(id)
    else
        -- Fallback: run directly
        local co = tutorial:_build_coroutine()
        -- Manual resume loop would go here
    end
end

--- Stop the current tutorial
function Tutorial.stop()
    if not _active_tutorial then return end
    
    if stopTutorial then
        stopTutorial()
    end
    
    if _active_tutorial._on_skip then
        _active_tutorial._on_skip()
    end
    
    _active_tutorial = nil
end

--- Check if a tutorial is currently active
--- @return boolean
function Tutorial.is_active()
    return _active_tutorial ~= nil
end

--- Get active tutorial ID
--- @return string?
function Tutorial.active_id()
    return _active_tutorial and _active_tutorial.id
end

--- Check if a tutorial is completed
--- @param id string
--- @return boolean
function Tutorial.is_completed(id)
    return Progress.is_completed(id)
end

--- Reset a tutorial's progress
--- @param id string
function Tutorial.reset(id)
    Progress.reset(id)
end

--- Reset all tutorial progress
function Tutorial.reset_all()
    Progress.reset_all()
end

return Tutorial
```

---

### 6. `assets/scripts/tutorial/scripts/onboarding.lua`

Example onboarding tutorial.

```lua
--[[
================================================================================
ONBOARDING TUTORIAL
================================================================================
The first-time player experience tutorial.
]]

local Tutorial = require("tutorial.script_dsl")
local signal = require("external.hump.signal")

Tutorial.new("onboarding")
    :dialogueConfig({
        speaker = {
            sprite = "guide_portrait.png",
            position = "left",
        },
        box = {
            style = "default",
        },
    })
    
    -- Step 1: Welcome
    :step("welcome", function(t)
        t:say("Welcome, adventurer!", { speaker = "Guide" })
        t:say("I'll teach you the basics of survival.")
        t:say("Let's start with movement.")
    end)
    
    -- Step 2: Movement
    :step("movement", function(t)
        t:say("Use WASD or Arrow Keys to move around.", { speaker = "Guide" })
        t:say("Try moving a short distance.")
        t:objective("MOVE_DISTANCE", { distance = 100 })
        t:say("Excellent! You're a natural.")
    end)
    
    -- Step 3: Combat basics
    :step("combat_intro", function(t)
        t:say("Now let's talk about combat.", { speaker = "Guide" })
        t:say("Your wand automatically fires spells.")
        t:say("Bump into an enemy to trigger your wand!")
        t:objective("BUMP_ENEMY", { count = 1 })
        t:say("Perfect! Your wand unleashed its magic.")
    end)
    
    -- Step 4: Kill an enemy
    :step("first_kill", function(t)
        t:say("Now defeat an enemy completely.", { speaker = "Guide" })
        t:objective("KILL_ENEMY", { count = 1 })
        t:say("Well done! You've vanquished your first foe.")
    end)
    
    -- Step 5: Wand panel
    :step("wand_panel", function(t)
        t:say("Let's look at your wand.", { speaker = "Guide" })
        t:say("Press TAB or click the wand icon to open the Wand Panel.")
        t:objective("OPEN_WAND_PANEL")
        t:say("Here you can see and manage your spell cards.")
        t:say("Close the panel when you're ready.")
        t:objective("CLOSE_WAND_PANEL")
    end)
    
    -- Step 6: Survival
    :step("survive", function(t)
        t:say("Finally, let's test your survival skills.", { speaker = "Guide" })
        t:say("Stay alive for 30 seconds!")
        t:objective("SURVIVE_SECONDS", { duration = 30 })
        t:say("Impressive! You're ready for the real challenges ahead.")
    end)
    
    -- Completion callback
    :onComplete(function()
        signal.emit("tutorial_complete", "onboarding")
        print("[Onboarding] Tutorial complete!")
    end)
    
    :onSkip(function()
        signal.emit("tutorial_skipped", "onboarding")
        print("[Onboarding] Tutorial skipped!")
    end)
    
    :register()
```

---

## Files to Modify

### `assets/scripts/tutorial/register_tutorials.lua`

Add require for the onboarding tutorial:

```lua
-- Add this line in the register() function or at module load:
require("tutorial.scripts.onboarding")
```

---

## Implementation Order

1. **Create `helpers.lua`** - Foundational utilities
2. **Create `progress.lua`** - Persistence (needs SaveManager)
3. **Create `objective_types.lua`** - 27 type definitions
4. **Create `objectives.lua`** - Objective execution (needs signal_group, helpers)
5. **Create `script_dsl.lua`** - Main DSL (needs all above + dialogue)
6. **Create `scripts/` folder**
7. **Create `scripts/onboarding.lua`** - Example tutorial
8. **Modify `register_tutorials.lua`** - Wire it up

---

## Testing

### Basic Test

```lua
-- In Lua console or test script:
local Tutorial = require("tutorial.script_dsl")

-- Reset progress for testing
Tutorial.reset("onboarding")

-- Start the tutorial
Tutorial.start("onboarding", { force = true })
```

### Objective Test

```lua
local Objectives = require("tutorial.objectives")

-- Test MOVE_DISTANCE objective
-- (This will block until you move 50 units)
Objectives.wait_for("MOVE_DISTANCE", { distance = 50 })
print("Moved 50 units!")
```

### Signal Verification

Ensure signals are emitted. Check `assets/scripts/` for `signal.emit()` calls matching the objective types.

---

## Signal Requirements

The following signals must be emitted by game systems for objectives to work:

| Signal | Emitter Location | Payload |
|--------|------------------|---------|
| `player_moved` | Movement system | `(x, y)` |
| `player_step` | Movement system | none |
| `player_dashed` | Movement system | none |
| `enemy_killed` | Combat system | `(entity, enemy_type)` |
| `damage_dealt` | Combat system | `(amount, target_entity)` |
| `player_damaged` | Combat system | `(amount, source)` |
| `wand_triggered` | Wand system | `(wand_id)` |
| `spell_cast` | Wand system | `(spell_id, spell_type)` |
| `pickup_collected` | Pickup system | `(pickup_type, amount)` |
| `player_bumped_enemy` | Collision system | `(enemy_entity)` |
| `player_level_up` | XP system | `(new_level)` |
| `inventory_opened` | UI | none |
| `inventory_closed` | UI | none |
| `wand_panel_opened` | UI | none |
| `wand_panel_closed` | UI | none |
| `card_equipped` | Deck system | `(card_id, slot)` |
| `phase_changed` | Game state | `(new_phase)` |
| `wave_complete` | Wave system | `(wave_number)` |
| `frame_update` | Main loop | `(dt)` |

---

## Architecture Notes

### Event-Driven Design

All objectives use `hump.signal` listeners via `signal_group` for automatic cleanup. This eliminates polling loops and ensures memory safety.

### Coroutine Blocking

The DSL generates coroutines that yield until:
- Dialogue completes (via `onComplete` callback)
- Objectives complete (via signal handlers)
- Timer expires (via `wait_seconds`)

### Dialogue Batching

Multiple `t:say()` calls are batched and flushed together before objectives. This allows natural conversation flow:

```lua
t:say("Line 1")
t:say("Line 2")  -- Batched with Line 1
t:objective("KILL_ENEMY")  -- Flushes dialogue, then waits
t:say("Line 3")  -- New batch
```

### Progress Persistence

Uses existing `SaveManager` collector pattern at key `"tutorial_progress"`. Only completed tutorials and steps are persisted; runtime state is ephemeral.

### No C++ Changes Required

This is a pure Lua implementation that wraps existing systems.
