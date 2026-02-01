-- assets/scripts/descent/turn_manager.lua
--[[
================================================================================
DESCENT TURN MANAGER FSM
================================================================================
Manages the turn-based game loop:
- PLAYER_TURN: Wait for valid player input, execute action
- ENEMY_TURN: Process all enemies in deterministic order
- Back to PLAYER_TURN

Key invariants (per PLAN.md):
- Invalid/no-op input consumes 0 turns
- No input for N frames does NOT advance turns (dt-independent)
- Simulation is turn-driven, not time-driven

Usage:
    local tm = require("descent.turn_manager")
    tm.init()
    
    -- In game loop:
    tm.update()  -- Called every frame, but only advances on valid input
    
    -- Player action:
    tm.submit_action({ type = "move", dx = 1, dy = 0 })

================================================================================
]]

local TurnManager = {}

-- Turn phases
TurnManager.PHASE = {
    IDLE = "idle",           -- Not active
    PLAYER_TURN = "player",  -- Waiting for player input
    ENEMY_TURN = "enemy",    -- Processing enemy actions
    ANIMATION = "animation", -- Optional: waiting for animations
}

-- Internal state
local _state = {
    phase = TurnManager.PHASE.IDLE,
    turn_count = 0,
    pending_action = nil,
    enemy_index = 0,
    enemy_list = {},
    callbacks = {},
    initialized = false,
}

-- Callback types
local CALLBACKS = {
    on_phase_change = {},
    on_turn_start = {},
    on_turn_end = {},
    on_player_action = {},
    on_enemy_action = {},
}

--------------------------------------------------------------------------------
-- Internal Helpers
--------------------------------------------------------------------------------

--- Log helper
--- @param msg string Message to log
local function log(msg)
    local fn = log_debug or print
    fn("[TurnManager] " .. msg)
end

--- Notify all registered callbacks for an event
--- @param event string Event name
--- @param ... any Arguments to pass to callbacks
local function notify(event, ...)
    local callbacks = CALLBACKS[event]
    if callbacks then
        for _, cb in ipairs(callbacks) do
            local ok, err = pcall(cb, ...)
            if not ok then
                log("Callback error for " .. event .. ": " .. tostring(err))
            end
        end
    end
end

--- Set the current phase
--- @param new_phase string New phase
local function set_phase(new_phase)
    local old_phase = _state.phase
    if old_phase == new_phase then return end
    
    _state.phase = new_phase
    log("Phase: " .. old_phase .. " -> " .. new_phase)
    notify("on_phase_change", new_phase, old_phase)
end

--------------------------------------------------------------------------------
-- Action Validation
--------------------------------------------------------------------------------

--- Validate a player action
--- @param action table Action to validate
--- @return boolean, string Valid flag and error message if invalid
local function validate_action(action)
    if not action then
        return false, "No action provided"
    end
    
    if not action.type then
        return false, "Action missing type"
    end
    
    -- Action-specific validation (extensible)
    local validators = {
        move = function(a)
            if a.dx == nil or a.dy == nil then
                return false, "Move action missing dx/dy"
            end
            if a.dx == 0 and a.dy == 0 then
                return false, "Move action is no-op (0,0)"
            end
            return true
        end,
        wait = function() return true end,
        attack = function(a)
            if not a.target_x or not a.target_y then
                return false, "Attack missing target"
            end
            return true
        end,
        use_item = function(a)
            if not a.item_id then
                return false, "Use item missing item_id"
            end
            return true
        end,
        stairs = function() return true end,
        pickup = function() return true end,
        drop = function(a)
            if not a.item_id then
                return false, "Drop missing item_id"
            end
            return true
        end,
    }
    
    local validator = validators[action.type]
    if validator then
        return validator(action)
    end
    
    -- Unknown action types are invalid
    return false, "Unknown action type: " .. tostring(action.type)
end

--------------------------------------------------------------------------------
-- Enemy Turn Processing
--------------------------------------------------------------------------------

--- Get sorted list of enemies for deterministic processing
--- @return table Sorted enemy list
local function get_sorted_enemies()
    -- This should be provided by the enemy system
    -- For now, return empty list
    -- Enemies should be sorted by a stable key (entity_id or spawn_order)
    
    local enemy_module_ok, enemies = pcall(require, "descent.enemy")
    if enemy_module_ok and enemies and enemies.get_all_sorted then
        return enemies.get_all_sorted()
    end
    
    return {}
end

--- Process a single enemy's turn
--- @param enemy table Enemy entity
--- @return boolean True if action was taken
local function process_enemy(enemy)
    -- Delegate to enemy AI module
    local ai_ok, enemy_ai = pcall(require, "descent.actions_enemy")
    if ai_ok and enemy_ai and enemy_ai.decide_action then
        local action = enemy_ai.decide_action(enemy)
        if action then
            notify("on_enemy_action", enemy, action)
            return true
        end
    end
    return false
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Initialize the turn manager
--- @param config table|nil Optional configuration
function TurnManager.init(config)
    _state = {
        phase = TurnManager.PHASE.PLAYER_TURN,
        turn_count = 0,
        pending_action = nil,
        enemy_index = 0,
        enemy_list = {},
        callbacks = {},
        initialized = true,
    }
    
    log("Initialized (turn 0)")
    notify("on_turn_start", 0)
end

--- Reset the turn manager
function TurnManager.reset()
    _state.phase = TurnManager.PHASE.IDLE
    _state.turn_count = 0
    _state.pending_action = nil
    _state.enemy_index = 0
    _state.enemy_list = {}
    _state.initialized = false
    
    -- Clear callbacks
    for k in pairs(CALLBACKS) do
        CALLBACKS[k] = {}
    end
end

--- Get current phase
--- @return string Current phase
function TurnManager.get_phase()
    return _state.phase
end

--- Get current turn count
--- @return number Turn count
function TurnManager.get_turn_count()
    return _state.turn_count
end

--- Check if it's the player's turn
--- @return boolean True if player turn
function TurnManager.is_player_turn()
    return _state.phase == TurnManager.PHASE.PLAYER_TURN
end

--- Check if it's the enemy turn
--- @return boolean True if enemy turn
function TurnManager.is_enemy_turn()
    return _state.phase == TurnManager.PHASE.ENEMY_TURN
end

--- Submit a player action
--- Returns immediately if action is invalid (consumes 0 turns)
--- @param action table Action to submit
--- @return boolean, string Success flag and error message if failed
function TurnManager.submit_action(action)
    -- Can only submit during player turn
    if _state.phase ~= TurnManager.PHASE.PLAYER_TURN then
        return false, "Not player turn (current: " .. _state.phase .. ")"
    end
    
    -- Validate action
    local valid, err = validate_action(action)
    if not valid then
        log("Invalid action: " .. tostring(err))
        return false, err
    end
    
    -- Queue the action
    _state.pending_action = action
    log("Action queued: " .. action.type)
    
    return true
end

--- Process one step of the turn
--- This should be called each frame
--- Returns immediately if no work to do (dt-independent)
--- @return boolean True if a turn step was processed
function TurnManager.update()
    if not _state.initialized then
        return false
    end
    
    -- PLAYER_TURN: Process pending action
    if _state.phase == TurnManager.PHASE.PLAYER_TURN then
        if _state.pending_action then
            local action = _state.pending_action
            _state.pending_action = nil
            
            -- Execute player action
            log("Executing player action: " .. action.type)
            notify("on_player_action", action)
            
            -- Transition to enemy turn
            set_phase(TurnManager.PHASE.ENEMY_TURN)
            _state.enemy_list = get_sorted_enemies()
            _state.enemy_index = 0
            
            return true
        end
        
        -- No pending action - do nothing (dt-independent)
        return false
    end
    
    -- ENEMY_TURN: Process enemies one at a time
    if _state.phase == TurnManager.PHASE.ENEMY_TURN then
        _state.enemy_index = _state.enemy_index + 1
        
        if _state.enemy_index <= #_state.enemy_list then
            local enemy = _state.enemy_list[_state.enemy_index]
            process_enemy(enemy)
            return true
        end
        
        -- All enemies processed - end turn
        notify("on_turn_end", _state.turn_count)
        _state.turn_count = _state.turn_count + 1
        set_phase(TurnManager.PHASE.PLAYER_TURN)
        notify("on_turn_start", _state.turn_count)
        
        return true
    end
    
    return false
end

--- Force advance to next player turn (for testing)
--- @param count number|nil Number of turns to advance (default 1)
function TurnManager.advance_turns(count)
    count = count or 1
    for _ = 1, count do
        notify("on_turn_end", _state.turn_count)
        _state.turn_count = _state.turn_count + 1
        notify("on_turn_start", _state.turn_count)
    end
    set_phase(TurnManager.PHASE.PLAYER_TURN)
end

--- Register a callback
--- @param event string Event name (on_phase_change, on_turn_start, on_turn_end, on_player_action, on_enemy_action)
--- @param callback function Callback function
function TurnManager.on(event, callback)
    if CALLBACKS[event] then
        table.insert(CALLBACKS[event], callback)
    else
        log("Unknown event: " .. tostring(event))
    end
end

--- Unregister a callback
--- @param event string Event name
--- @param callback function Callback to remove
function TurnManager.off(event, callback)
    if CALLBACKS[event] then
        for i, cb in ipairs(CALLBACKS[event]) do
            if cb == callback then
                table.remove(CALLBACKS[event], i)
                return
            end
        end
    end
end

--- Get state snapshot (for debugging/testing)
--- @return table State snapshot
function TurnManager.get_state()
    return {
        phase = _state.phase,
        turn_count = _state.turn_count,
        has_pending_action = _state.pending_action ~= nil,
        enemy_count = #_state.enemy_list,
        enemy_index = _state.enemy_index,
        initialized = _state.initialized,
    }
end

--- Pause the turn manager (for menus, etc.)
function TurnManager.pause()
    if _state.phase ~= TurnManager.PHASE.IDLE then
        _state.paused_phase = _state.phase
        set_phase(TurnManager.PHASE.IDLE)
    end
end

--- Resume the turn manager
function TurnManager.resume()
    if _state.paused_phase then
        set_phase(_state.paused_phase)
        _state.paused_phase = nil
    end
end

return TurnManager
