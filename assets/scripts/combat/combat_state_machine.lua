--[[
    Combat State Machine

    Manages combat loop states and transitions:
    - INIT: Initial state
    - WAVE_START: Initialize wave, prepare for spawning
    - SPAWNING: Enemies being spawned
    - COMBAT: Active battle
    - VICTORY: Wave cleared, calculate rewards
    - INTERMISSION: Between waves
    - DEFEAT: Player death
    - GAME_WON: All waves complete
    - GAME_OVER: Final state

    Integrates with:
    - Wave manager (wave progression)
    - Event bus (state change events)
    - Game state system (pause/resume)
]]

local timer = require("core.timer")

local CombatStateMachine = {}
CombatStateMachine.__index = CombatStateMachine

-- State constants
CombatStateMachine.States = {
    INIT = "INIT",
    WAVE_START = "WAVE_START",
    SPAWNING = "SPAWNING",
    COMBAT = "COMBAT",
    VICTORY = "VICTORY",
    INTERMISSION = "INTERMISSION",
    DEFEAT = "DEFEAT",
    GAME_WON = "GAME_WON",
    GAME_OVER = "GAME_OVER"
}

--[[
    Create a new combat state machine

    @param config table {
        wave_manager = WaveManager instance,
        combat_context = Combat context,
        player_entity = Player entity ID,

        -- State callbacks
        on_wave_start = function(wave_number),
        on_combat_start = function(),
        on_victory = function(wave_stats),
        on_defeat = function(),
        on_intermission = function(next_wave),
        on_game_won = function(total_stats),
        on_game_over = function(),

        -- Condition checkers
        is_player_alive = function() -> boolean,

        -- Auto-progress settings
        victory_delay = number (seconds to wait before intermission),
        intermission_duration = number (auto-progress to next wave),
        defeat_delay = number (delay before game over screen)
    }
    @return CombatStateMachine instance
]]
function CombatStateMachine.new(config)
    local self = setmetatable({}, CombatStateMachine)

    -- Dependencies
    self.wave_manager = config.wave_manager
    self.combat_context = config.combat_context
    self.player_entity = config.player_entity

    -- Callbacks
    self.on_wave_start = config.on_wave_start
    self.on_combat_start = config.on_combat_start
    self.on_victory = config.on_victory
    self.on_defeat = config.on_defeat
    self.on_intermission = config.on_intermission
    self.on_game_won = config.on_game_won
    self.on_game_over = config.on_game_over

    -- Condition checkers
    self.is_player_alive = config.is_player_alive or function()
        return true  -- Default: assume player is alive
    end

    -- Auto-progress settings
    self.victory_delay = config.victory_delay or 2.0
    self.intermission_duration = config.intermission_duration or 5.0
    self.defeat_delay = config.defeat_delay or 2.0

    -- State
    self.current_state = self.States.INIT
    self.previous_state = nil
    self.state_start_time = 0

    -- Flags
    self.running = false
    self.paused = false

    return self
end

--[[
    Start the combat state machine
]]
function CombatStateMachine:start()
    log_debug("[CombatStateMachine] Starting")

    self.running = true
    self.paused = false
    self:change_state(self.States.WAVE_START)
end

--[[
    Update the state machine (call every frame)

    @param dt number - Delta time
]]
function CombatStateMachine:update(dt)
    if not self.running or self.paused then
        return
    end

    local state = self.current_state

    if state == self.States.WAVE_START then
        self:update_wave_start(dt)

    elseif state == self.States.SPAWNING then
        self:update_spawning(dt)

    elseif state == self.States.COMBAT then
        self:update_combat(dt)

    elseif state == self.States.VICTORY then
        self:update_victory(dt)

    elseif state == self.States.INTERMISSION then
        self:update_intermission(dt)

    elseif state == self.States.DEFEAT then
        self:update_defeat(dt)

    elseif state == self.States.GAME_WON then
        self:update_game_won(dt)

    elseif state == self.States.GAME_OVER then
        self:update_game_over(dt)
    end
end

--[[
    Change to a new state

    @param new_state string - State constant
]]
function CombatStateMachine:change_state(new_state)
    if self.current_state == new_state then
        return
    end

    log_debug("[CombatStateMachine] State transition:", self.current_state, "->", new_state)

    -- Exit current state
    self:exit_state(self.current_state)

    -- Change state
    self.previous_state = self.current_state
    self.current_state = new_state
    self.state_start_time = os.clock()

    -- Enter new state
    self:enter_state(new_state)

    -- Emit event
    if self.combat_context and self.combat_context.bus then
        self.combat_context.bus:emit("OnCombatStateChanged", {
            from = self.previous_state,
            to = new_state
        })
    end
end

--[[
    Enter a state (called on state transition)
]]
function CombatStateMachine:enter_state(state)
    if state == self.States.WAVE_START then
        self:enter_wave_start()

    elseif state == self.States.SPAWNING then
        self:enter_spawning()

    elseif state == self.States.COMBAT then
        self:enter_combat()

    elseif state == self.States.VICTORY then
        self:enter_victory()

    elseif state == self.States.INTERMISSION then
        self:enter_intermission()

    elseif state == self.States.DEFEAT then
        self:enter_defeat()

    elseif state == self.States.GAME_WON then
        self:enter_game_won()

    elseif state == self.States.GAME_OVER then
        self:enter_game_over()
    end
end

--[[
    Exit a state (called on state transition)
]]
function CombatStateMachine:exit_state(state)
    -- Cancel any state-specific timers
    timer.cancel("combat_state_timer")
end

-- ============================================================================
-- WAVE_START State
-- ============================================================================

function CombatStateMachine:enter_wave_start()
    log_debug("[CombatStateMachine] Enter WAVE_START")

    -- Start next wave
    local success = self.wave_manager:start_next_wave()

    if not success then
        -- No more waves
        self:change_state(self.States.GAME_WON)
        return
    end

    -- Callback
    if self.on_wave_start then
        self.on_wave_start(self.wave_manager:get_current_wave_number())
    end

    -- Transition to spawning after brief delay
    timer.after(0.5, function()
        if self.current_state == self.States.WAVE_START then
            self:change_state(self.States.SPAWNING)
        end
    end, "combat_state_timer")
end

function CombatStateMachine:update_wave_start(dt)
    -- Handled by timer
end

-- ============================================================================
-- SPAWNING State
-- ============================================================================

function CombatStateMachine:enter_spawning()
    log_debug("[CombatStateMachine] Enter SPAWNING")
    -- Spawning starts automatically when wave_manager starts the wave
end

function CombatStateMachine:update_spawning(dt)
    -- Check if spawning is complete
    if self.wave_manager.spawner.spawn_complete then
        -- First batch of enemies spawned, transition to combat
        self:change_state(self.States.COMBAT)
    end
end

-- ============================================================================
-- COMBAT State
-- ============================================================================

function CombatStateMachine:enter_combat()
    log_debug("[CombatStateMachine] Enter COMBAT")

    -- Emit combat start event
    if self.combat_context and self.combat_context.bus then
        self.combat_context.bus:emit("OnCombatStart", {
            wave_number = self.wave_manager:get_current_wave_number()
        })
    end

    -- Callback
    if self.on_combat_start then
        self.on_combat_start()
    end
end

function CombatStateMachine:update_combat(dt)
    -- Update wave manager
    self.wave_manager:update(dt)

    -- Check for player death
    if not self.is_player_alive() then
        self:change_state(self.States.DEFEAT)
        return
    end

    -- Check for wave completion
    if self.wave_manager:is_wave_complete() then
        self:change_state(self.States.VICTORY)
        return
    end
end

-- ============================================================================
-- VICTORY State
-- ============================================================================

function CombatStateMachine:enter_victory()
    log_debug("[CombatStateMachine] Enter VICTORY")

    -- Complete the wave (calculates rewards)
    self.wave_manager:complete_wave()

    local wave_stats = self.wave_manager:get_wave_stats()

    -- Emit victory event
    if self.combat_context and self.combat_context.bus then
        self.combat_context.bus:emit("OnCombatEnd", {
            victory = true,
            stats = wave_stats
        })
    end

    -- Callback
    if self.on_victory then
        self.on_victory(wave_stats)
    end

    -- Auto-progress to intermission or game won
    timer.after(self.victory_delay, function()
        if self.current_state == self.States.VICTORY then
            if self.wave_manager:has_more_waves() then
                self:change_state(self.States.INTERMISSION)
            else
                self:change_state(self.States.GAME_WON)
            end
        end
    end, "combat_state_timer")
end

function CombatStateMachine:update_victory(dt)
    -- Handled by timer
end

-- ============================================================================
-- INTERMISSION State
-- ============================================================================

function CombatStateMachine:enter_intermission()
    log_debug("[CombatStateMachine] Enter INTERMISSION")

    local next_wave = self.wave_manager:get_current_wave_number() + 1

    -- Emit intermission event
    if self.combat_context and self.combat_context.bus then
        self.combat_context.bus:emit("OnIntermission", {
            next_wave = next_wave
        })
    end

    -- Callback
    if self.on_intermission then
        self.on_intermission(next_wave)
    end

    -- Auto-progress to next wave
    if self.intermission_duration > 0 then
        timer.after(self.intermission_duration, function()
            if self.current_state == self.States.INTERMISSION then
                self:progress_to_next_wave()
            end
        end, "combat_state_timer")
    end
end

function CombatStateMachine:update_intermission(dt)
    -- Can manually progress via progress_to_next_wave()
end

--[[
    Manually progress to next wave (e.g., player presses button)
]]
function CombatStateMachine:progress_to_next_wave()
    if self.current_state ~= self.States.INTERMISSION then
        log_debug("[CombatStateMachine] Cannot progress - not in intermission")
        return false
    end

    timer.cancel("combat_state_timer")
    self:change_state(self.States.WAVE_START)
    return true
end

-- ============================================================================
-- DEFEAT State
-- ============================================================================

function CombatStateMachine:enter_defeat()
    log_debug("[CombatStateMachine] Enter DEFEAT")

    -- Stop wave
    self.wave_manager:stop_wave()

    -- Emit defeat event
    if self.combat_context and self.combat_context.bus then
        self.combat_context.bus:emit("OnCombatEnd", {
            victory = false,
            wave_number = self.wave_manager:get_current_wave_number()
        })

        self.combat_context.bus:emit("OnPlayerDeath", {
            player = self.player_entity
        })
    end

    -- Callback
    if self.on_defeat then
        self.on_defeat()
    end

    -- Auto-progress to game over
    timer.after(self.defeat_delay, function()
        if self.current_state == self.States.DEFEAT then
            self:change_state(self.States.GAME_OVER)
        end
    end, "combat_state_timer")
end

function CombatStateMachine:update_defeat(dt)
    -- Handled by timer
end

-- ============================================================================
-- GAME_WON State
-- ============================================================================

function CombatStateMachine:enter_game_won()
    log_debug("[CombatStateMachine] Enter GAME_WON - All waves complete!")

    local total_stats = self.wave_manager:get_total_stats()

    -- Callback
    if self.on_game_won then
        self.on_game_won(total_stats)
    end

    self.running = false
end

function CombatStateMachine:update_game_won(dt)
    -- Final state - no updates needed
end

-- ============================================================================
-- GAME_OVER State
-- ============================================================================

function CombatStateMachine:enter_game_over()
    log_debug("[CombatStateMachine] Enter GAME_OVER")

    -- Callback
    if self.on_game_over then
        self.on_game_over()
    end

    self.running = false
end

function CombatStateMachine:update_game_over(dt)
    -- Final state - no updates needed
end

-- ============================================================================
-- Control Methods
-- ============================================================================

--[[
    Pause the state machine
]]
function CombatStateMachine:pause()
    self.paused = true
    log_debug("[CombatStateMachine] Paused")
end

--[[
    Resume the state machine
]]
function CombatStateMachine:resume()
    self.paused = false
    log_debug("[CombatStateMachine] Resumed")
end

--[[
    Stop the state machine
]]
function CombatStateMachine:stop()
    self.running = false
    timer.cancel("combat_state_timer")
    log_debug("[CombatStateMachine] Stopped")
end

--[[
    Reset the state machine to initial state
]]
function CombatStateMachine:reset()
    self:stop()
    self.current_state = self.States.INIT
    self.previous_state = nil
    self.state_start_time = 0
    self.wave_manager:reset()
    log_debug("[CombatStateMachine] Reset")
end

--[[
    Retry current wave (from defeat state)
]]
function CombatStateMachine:retry_wave()
    if self.current_state ~= self.States.DEFEAT and
       self.current_state ~= self.States.GAME_OVER then
        log_debug("[CombatStateMachine] Cannot retry - not in defeat/game over state")
        return false
    end

    -- Don't increment wave number, restart current wave
    self.wave_manager.current_wave_number = self.wave_manager.current_wave_number - 1
    self:reset()
    self:start()
    return true
end

--[[
    Get current state

    @return string - Current state constant
]]
function CombatStateMachine:get_current_state()
    return self.current_state
end

--[[
    Check if in a specific state

    @param state string - State constant
    @return boolean
]]
function CombatStateMachine:is_in_state(state)
    return self.current_state == state
end

--[[
    Get time in current state

    @return number - Seconds in current state
]]
function CombatStateMachine:get_state_time()
    return os.clock() - self.state_start_time
end

return CombatStateMachine
