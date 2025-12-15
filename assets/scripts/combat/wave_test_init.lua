--[[
    Wave System Test Integration

    This file sets up the wave system to run during the action phase.
    Require this file from gameplay.lua or main init to enable waves.

    Usage:
        require("combat.wave_test_init")

    To customize waves, modify the test_stages table below.
]]

local signal = require("external.hump.signal")
local WaveSystem = require("combat.wave_system")
local WaveVisuals = require("combat.wave_visuals")

local WaveTestInit = {}

-- Test stage configuration - modify this to change what spawns
local test_stages = {
    {
        id = "test_stage_1",
        waves = {
            { "goblin", "goblin", "goblin" },
            { "goblin", "archer", "archer" },
            { "dasher", "goblin", "goblin" },
        },
        elite = { base = "goblin", modifiers = { "tanky", "fast" } },
        next = "shop",
    },
    {
        id = "test_stage_2",
        waves = {
            { "archer", "archer", "dasher" },
            { "trapper", "goblin", "goblin" },
            { "summoner" },
        },
        elite = { base = "dasher", modifier_count = 2 },
        next = "shop",
    },
}

-- Track if we're initialized
local initialized = false
local current_provider = nil

-- Initialize the wave system when action phase starts
local function on_action_phase_started()
    print("[WaveTestInit] Action phase started - initializing waves")

    -- Create a sequence provider from test stages
    local providers = require("combat.stage_providers")
    current_provider = providers.sequence(test_stages)

    -- Start the first stage
    local first_stage = current_provider.next()
    if first_stage then
        WaveSystem.director.start_stage(first_stage)
        print("[WaveTestInit] Started stage: " .. (first_stage.id or "unnamed"))
    end
end

-- Handle stage completion - go to shop or next stage
local function on_stage_completed(results)
    print("[WaveTestInit] Stage completed!")

    if results and results.next == "shop" then
        print("[WaveTestInit] Transitioning to shop...")
        signal.emit("goto_shop")
        -- The shop system should call WaveTestInit.continue_from_shop() when done
    else
        -- Try next stage
        local next_stage = current_provider and current_provider.next()
        if next_stage then
            WaveSystem.director.start_stage(next_stage)
        else
            print("[WaveTestInit] All stages complete!")
            signal.emit("run_complete")
        end
    end
end

-- Call this from shop when player is done shopping
function WaveTestInit.continue_from_shop()
    print("[WaveTestInit] Continuing from shop...")

    local next_stage = current_provider and current_provider.next()
    if next_stage then
        -- Need to re-enter action phase first
        if startActionPhase then
            -- Don't emit action_phase_started again (would cause recursion)
            -- Just start the stage directly
        end
        WaveSystem.director.start_stage(next_stage)
        print("[WaveTestInit] Started next stage: " .. (next_stage.id or "unnamed"))
    else
        print("[WaveTestInit] No more stages - run complete!")
        signal.emit("run_complete")
    end
end

-- Reset and start fresh
function WaveTestInit.restart()
    print("[WaveTestInit] Restarting wave test...")
    WaveSystem.director.cleanup()

    local providers = require("combat.stage_providers")
    current_provider = providers.sequence(test_stages)

    local first_stage = current_provider.next()
    if first_stage then
        WaveSystem.director.start_stage(first_stage)
    end
end

-- Get current state for debugging
function WaveTestInit.get_state()
    return {
        initialized = initialized,
        director_state = WaveSystem.director.get_state(),
        current_stage_index = current_provider and current_provider.current_index() or 0,
    }
end

-- Initialize - register signal handlers
function WaveTestInit.init()
    if initialized then
        print("[WaveTestInit] Already initialized")
        return
    end

    print("[WaveTestInit] Initializing wave test system...")

    -- Initialize visual feedback handlers
    WaveVisuals.init()

    -- Register for action phase start
    signal.register("action_phase_started", on_action_phase_started)

    -- Register for stage completion
    signal.register("stage_completed", on_stage_completed)

    initialized = true
    print("[WaveTestInit] Wave test system ready!")
end

-- Auto-initialize on require
WaveTestInit.init()

return WaveTestInit
