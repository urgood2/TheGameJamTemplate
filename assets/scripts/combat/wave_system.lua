-- assets/scripts/combat/wave_system.lua
-- Main entry point for wave system

local signal = require("external.hump.signal")

local WaveDirector = require("combat.wave_director")
local providers = require("combat.stage_providers")
local generators = require("combat.wave_generators")
local WaveHelpers = require("combat.wave_helpers")
local EnemyFactory = require("combat.enemy_factory")
local WaveVisuals = require("combat.wave_visuals")  -- Registers visual signal handlers

local WaveSystem = {}

-- Re-export submodules for convenience
WaveSystem.director = WaveDirector
WaveSystem.providers = providers
WaveSystem.generators = generators
WaveSystem.helpers = WaveHelpers
WaveSystem.factory = EnemyFactory
WaveSystem.visuals = WaveVisuals

--============================================
-- QUICK START API
--============================================

--- Start a run with the given stage provider
-- @param provider A stage provider (from providers.sequence, providers.endless, or providers.hybrid)
function WaveSystem.start_run(provider)
    WaveDirector.stage_provider = provider
    provider.reset()

    local first_stage = provider.next()
    if first_stage then
        WaveDirector.start_stage(first_stage)
    else
        print("WaveSystem.start_run: provider returned no stages")
    end
end

--- Start a quick test with minimal configuration
-- @param stages Array of stage configs (or single stage config)
function WaveSystem.quick_test(stages)
    if stages.waves then
        -- Single stage passed
        stages = { stages }
    end

    local provider = providers.sequence(stages)
    WaveSystem.start_run(provider)
end

--- Start endless mode
-- @param config Optional endless config overrides
function WaveSystem.start_endless(config)
    config = config or {}
    local provider = providers.endless(config)
    WaveSystem.start_run(provider)
end

--- Continue from shop to next stage
function WaveSystem.continue_from_shop()
    if not WaveDirector.stage_provider then
        print("WaveSystem.continue_from_shop: no stage provider set")
        return
    end

    local next_stage = WaveDirector.stage_provider.next()
    if next_stage then
        WaveDirector.start_stage(next_stage)
    else
        signal.emit("run_complete")
    end
end

--============================================
-- CONVENIENCE ACCESSORS
--============================================

function WaveSystem.get_state()
    return WaveDirector.get_state()
end

function WaveSystem.pause()
    WaveDirector.pause()
end

function WaveSystem.resume()
    WaveDirector.resume()
end

function WaveSystem.cleanup()
    WaveDirector.cleanup()
end

function WaveSystem.go_to(target)
    WaveDirector.go_to(target)
end

--============================================
-- EXAMPLE STAGE CONFIGS
--============================================

WaveSystem.examples = {}

-- Minimal test stage
WaveSystem.examples.minimal = {
    waves = {
        { "goblin", "goblin", "goblin" },
        { "goblin", "goblin", "archer" },
    },
    next = "shop",
}

-- Stage with elite
WaveSystem.examples.with_elite = {
    waves = {
        { "goblin", "goblin", "dasher" },
        { "archer", "archer", "trapper" },
    },
    elite = { base = "goblin", modifiers = { "tanky", "fast" } },
    next = "shop",
}

-- Endless mode config
WaveSystem.examples.endless_config = {
    enemy_pool = {
        { type = "goblin", weight = 5, cost = 1 },
        { type = "archer", weight = 3, cost = 2 },
        { type = "dasher", weight = 2, cost = 3 },
        { type = "trapper", weight = 2, cost = 3 },
        { type = "summoner", weight = 1, cost = 5 },
        { type = "exploder", weight = 2, cost = 2 },
    },
    elite_every = 3,
    shop_every = 1,
    reward_every = 5,
}

return WaveSystem
