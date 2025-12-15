-- assets/scripts/combat/wave_examples.lua
-- Copy/paste examples for common wave system usage patterns

local WaveSystem = require("combat.wave_system")
local providers = WaveSystem.providers
local signal = require("external.hump.signal")

local examples = {}

--============================================
-- EXAMPLE 1: Quick Test (minimal setup)
--============================================

function examples.quick_test()
    WaveSystem.quick_test({
        waves = {
            { "goblin", "goblin", "goblin" },
            { "goblin", "goblin", "archer" },
        },
        next = "shop",
    })
end

--============================================
-- EXAMPLE 2: Hand-Crafted Campaign
--============================================

function examples.campaign()
    local campaign_stages = {
        -- Stage 1: Tutorial, easy
        {
            id = "stage_1",
            waves = {
                { "goblin", "goblin" },
                { "goblin", "goblin", "goblin" },
            },
            spawn = "around_player",
            next = "stage_2",
        },

        -- Stage 2: Introduce archer
        {
            id = "stage_2",
            waves = {
                { "goblin", "goblin", "archer" },
                { "goblin", "archer", "archer" },
            },
            next = "shop",
        },

        -- Stage 3: First elite
        {
            id = "stage_3",
            waves = {
                { "goblin", "goblin", "dasher" },
                { "archer", "archer", "dasher" },
            },
            elite = { base = "goblin", modifiers = { "tanky", "fast" } },
            next = "shop",
        },

        -- Stage 4: With reward
        {
            id = "stage_4",
            waves = {
                { "dasher", "dasher", "trapper" },
                { "archer", "trapper", "summoner" },
            },
            elite = "goblin_chief",  -- unique elite type (define in enemies.lua)
            show_reward = true,
            next = "shop",
        },
    }

    WaveSystem.start_run(providers.sequence(campaign_stages))
end

--============================================
-- EXAMPLE 3: Endless Mode
--============================================

function examples.endless()
    WaveSystem.start_endless({
        -- Enemy pool with weights and costs
        enemy_pool = {
            { type = "goblin",   weight = 5, cost = 1 },
            { type = "archer",   weight = 3, cost = 2 },
            { type = "dasher",   weight = 2, cost = 3 },
            { type = "trapper",  weight = 2, cost = 3 },
            { type = "summoner", weight = 1, cost = 5 },
            { type = "exploder", weight = 2, cost = 2 },
        },

        -- Scaling
        budget_base = 8,
        budget_per_stage = 3,
        budget_per_wave = 2,

        -- Pacing
        elite_every = 3,
        shop_every = 1,
        reward_every = 5,
    })
end

--============================================
-- EXAMPLE 4: Hybrid (Story + Endless)
--============================================

function examples.hybrid()
    local story_stages = {
        {
            id = "intro",
            waves = { { "goblin", "goblin" } },
            on_complete = function(results)
                -- Show dialogue, then continue
                signal.emit("show_dialogue", "Welcome!", function()
                    WaveSystem.go_to("stage_1")
                end)
            end,
        },
        {
            id = "stage_1",
            waves = {
                { "goblin", "goblin", "goblin" },
                { "goblin", "archer" },
            },
            next = "shop",
        },
        {
            id = "boss_1",
            waves = {
                { "goblin", "goblin", "archer", "archer" },
            },
            elite = "first_boss",
            show_reward = true,
            next = "shop",
        },
    }

    WaveSystem.start_run(providers.hybrid(story_stages, {
        elite_every = 3,
        budget_base = 12,  -- Harder after story
    }))
end

--============================================
-- EXAMPLE 5: Setup Event Listeners
--============================================

function examples.setup_listeners()
    signal.register("stage_started", function(stage_config)
        log_info("Stage started: " .. (stage_config.id or "unknown"))
    end)

    signal.register("wave_started", function(wave_num, wave)
        log_info("Wave " .. wave_num .. " started")
    end)

    signal.register("wave_cleared", function(wave_num)
        log_info("Wave " .. wave_num .. " cleared!")
    end)

    signal.register("elite_spawned", function(e, ctx)
        log_info("Elite spawned: " .. ctx.type)
    end)

    signal.register("stage_completed", function(results)
        log_info("Stage complete: " .. (results.stage or "unknown"))
    end)

    signal.register("enemy_spawned", function(e, ctx)
        -- Track spawns
    end)

    signal.register("enemy_killed", function(e, ctx)
        -- Award XP, drop loot, etc.
    end)

    signal.register("run_complete", function()
        log_info("Run complete - victory!")
    end)

    signal.register("goto_shop", function()
        -- Transition to shop state
        log_info("Going to shop...")
        -- activate_state(SHOP_STATE)
    end)

    signal.register("goto_rewards", function()
        -- Show reward picker
        log_info("Showing rewards...")
        -- activate_state(REWARD_OPENING_STATE)
    end)
end

--============================================
-- EXAMPLE 6: Continue from Shop
--============================================

function examples.on_shop_done()
    -- Call this when player finishes shopping
    WaveSystem.continue_from_shop()
end

--============================================
-- EXAMPLE 7: Debug - Print State
--============================================

function examples.print_state()
    local state = WaveSystem.get_state()
    log_info("=== Wave System State ===")
    log_info("Stage: " .. tostring(state.stage_id))
    log_info("Wave: " .. state.wave_index .. "/" .. state.total_waves)
    log_info("Alive enemies: " .. state.alive_enemies)
    log_info("Spawning complete: " .. tostring(state.spawning_complete))
    log_info("Stage complete: " .. tostring(state.stage_complete))
    log_info("Paused: " .. tostring(state.paused))
end

return examples
