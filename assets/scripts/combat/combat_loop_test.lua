--[[
    Combat Loop Test Scenario

    This file demonstrates a complete 2-wave combat scenario using the
    Entity Lifecycle & Combat Loop Framework.

    To run this test:
    1. Require this module in your main game loop
    2. Call setup_test_combat() during initialization
    3. Call update_test_combat(dt) in your update loop
    4. Press a key to start combat (or call start_test_combat())

    Example:
        local CombatLoopTest = require("combat.combat_loop_test")
        CombatLoopTest.setup_test_combat()

        -- In update loop:
        CombatLoopTest.update_test_combat(dt)

        -- To start:
        CombatLoopTest.start_test_combat()
]]

local CombatLoopIntegration = require("combat.combat_loop_integration")

local CombatLoopTest = {}

-- Global test state
CombatLoopTest.combat_loop = nil
CombatLoopTest.test_running = false
CombatLoopTest.test_player = nil

--[[
    Setup test combat scenario
]]
function CombatLoopTest.setup_test_combat()
    log_debug("[CombatLoopTest] Setting up test combat scenario")

    -- Create test player if needed
    if not CombatLoopTest.test_player then
        CombatLoopTest.test_player = CombatLoopTest.create_test_player()
    end

    -- Define 2-wave test scenario
    local test_waves = {
        -- Wave 1: Simple instant wave with goblins
        {
            wave_number = 1,
            type = "instant",
            enemies = {
                { type = "kobold", count = 5 }
            },
            spawn_config = {
                type = "random_area",
                area = { x = 200, y = 200, w = 1200, h = 800 }
            },
            difficulty_scale = 1.0,
            rewards = {
                base_xp = 50,
                base_gold = 20,
                interest_per_second = 0,
                target_time = 60,
                speed_multiplier = 1,
                perfect_bonus = 10
            }
        },

        -- Wave 2: Timed wave with multiple spawn events
        {
            wave_number = 2,
            type = "timed",
            spawn_schedule = {
                { delay = 0, enemy = "kobold", count = 3 },
                { delay = 3, enemy = "kobold", count = 2 },
                { delay = 6, enemy = "kobold", count = 3 },
                { delay = 10, enemy = "kobold", count = 2 }
            },
            spawn_config = {
                type = "off_screen",
                margin = 50
            },
            difficulty_scale = 1.5,
            rewards = {
                base_xp = 100,
                base_gold = 50,
                interest_per_second = 2,
                target_time = 45,
                speed_multiplier = 2,
                perfect_bonus = 20
            }
        }
    }

    -- Create loot tables
    local loot_tables = {
        kobold = {
            gold = { min = 1, max = 3, chance = 100 },
            xp = { base = 10, variance = 2, chance = 100 },
            items = {}
        },
        unknown = {
            gold = { min = 1, max = 2, chance = 80 },
            xp = { base = 5, variance = 1, chance = 80 }
        }
    }

    -- Initialize combat loop integration
    CombatLoopTest.combat_loop = CombatLoopIntegration.new({
        waves = test_waves,
        player_entity = CombatLoopTest.test_player,
        entity_factory_fn = create_ai_entity,
        loot_tables = loot_tables,
        loot_collection_mode = "auto_collect",

        -- Callbacks
        on_wave_start = function(wave_number)
            log_debug("[TEST] ===== Wave", wave_number, "Started =====")
            CombatLoopTest.show_wave_ui(wave_number)
        end,

        on_wave_complete = function(wave_number, stats)
            log_debug("[TEST] ===== Wave", wave_number, "Complete =====")
            CombatLoopTest.show_wave_stats(stats)
        end,

        on_combat_end = function(victory, stats)
            if victory then
                log_debug("[TEST] ===== VICTORY =====")
                CombatLoopTest.show_victory_screen(stats)
            else
                log_debug("[TEST] ===== DEFEAT =====")
                CombatLoopTest.show_defeat_screen()
            end
        end,

        on_all_waves_complete = function(total_stats)
            log_debug("[TEST] ===== ALL WAVES COMPLETE =====")
            CombatLoopTest.show_final_stats(total_stats)
            CombatLoopTest.test_running = false
        end
    })

    log_debug("[CombatLoopTest] Test combat setup complete")
end

--[[
    Create a test player entity
]]
function CombatLoopTest.create_test_player()
    -- Use existing survivor entity if available
    if survivorEntity and registry and registry:valid(survivorEntity) then
        log_debug("[CombatLoopTest] Using existing survivor entity as player")
        return survivorEntity
    end

    -- Create a simple test player entity
    log_debug("[CombatLoopTest] Creating test player entity")

    local player = registry:create()

    -- Add transform
    transform.CreateOrEmplace(registry, entt_null, 800, 600, 64, 64, player)

    -- Set health via blackboard
    if setBlackboardFloat then
        setBlackboardFloat(player, "health", 100)
        setBlackboardFloat(player, "max_health", 100)
    end

    return player
end

--[[
    Start the test combat
]]
function CombatLoopTest.start_test_combat()
    if not CombatLoopTest.combat_loop then
        log_error("[CombatLoopTest] Combat loop not initialized! Call setup_test_combat() first")
        return false
    end

    if CombatLoopTest.test_running then
        log_debug("[CombatLoopTest] Combat test already running")
        return false
    end

    log_debug("[CombatLoopTest] ========================================")
    log_debug("[CombatLoopTest] Starting Combat Loop Test Scenario")
    log_debug("[CombatLoopTest] 2 waves with various spawn patterns")
    log_debug("[CombatLoopTest] ========================================")

    CombatLoopTest.test_running = true
    CombatLoopTest.combat_loop:start()

    return true
end

--[[
    Update the test combat (call every frame)
]]
function CombatLoopTest.update_test_combat(dt)
    if not CombatLoopTest.test_running or not CombatLoopTest.combat_loop then
        return
    end

    CombatLoopTest.combat_loop:update(dt)
end

--[[
    Stop the test combat
]]
function CombatLoopTest.stop_test_combat()
    if CombatLoopTest.combat_loop then
        CombatLoopTest.combat_loop:stop()
        CombatLoopTest.test_running = false
        log_debug("[CombatLoopTest] Test combat stopped")
    end
end

--[[
    Reset the test combat
]]
function CombatLoopTest.reset_test_combat()
    if CombatLoopTest.combat_loop then
        CombatLoopTest.combat_loop:reset()
        log_debug("[CombatLoopTest] Test combat reset")
    end
end

--[[
    Show wave UI
]]
function CombatLoopTest.show_wave_ui(wave_number)
    log_debug("[TEST UI] ╔════════════════════════╗")
    log_debug("[TEST UI] ║   WAVE", wave_number, "STARTING   ║")
    log_debug("[TEST UI] ╚════════════════════════╝")

    -- Could spawn UI elements here using the UI system
end

--[[
    Show wave statistics
]]
function CombatLoopTest.show_wave_stats(stats)
    log_debug("[TEST STATS] ┌─────────────────────────────────┐")
    log_debug("[TEST STATS] │ Wave", stats.wave_number, "Complete                │")
    log_debug("[TEST STATS] ├─────────────────────────────────┤")
    log_debug("[TEST STATS] │ Time:", string.format("%.1fs", stats.duration), "                    │")
    log_debug("[TEST STATS] │ Enemies:", stats.enemies_killed, "/", stats.enemies_spawned, "               │")
    log_debug("[TEST STATS] │ Damage Dealt:", stats.damage_dealt, "           │")
    log_debug("[TEST STATS] │ Damage Taken:", stats.damage_taken, "           │")
    log_debug("[TEST STATS] ├─────────────────────────────────┤")
    log_debug("[TEST STATS] │ Rewards:                        │")
    log_debug("[TEST STATS] │   XP:", stats.total_xp, "                     │")
    log_debug("[TEST STATS] │   Gold:", stats.total_gold, "                   │")
    log_debug("[TEST STATS] │   Perfect Clear:", stats.perfect_clear, "      │")
    log_debug("[TEST STATS] └─────────────────────────────────┘")
end

--[[
    Show victory screen
]]
function CombatLoopTest.show_victory_screen(total_stats)
    log_debug("[TEST VICTORY] ╔══════════════════════════════╗")
    log_debug("[TEST VICTORY] ║        VICTORY!              ║")
    log_debug("[TEST VICTORY] ║  All Waves Completed!        ║")
    log_debug("[TEST VICTORY] ╚══════════════════════════════╝")
end

--[[
    Show defeat screen
]]
function CombatLoopTest.show_defeat_screen()
    log_debug("[TEST DEFEAT] ╔══════════════════════════════╗")
    log_debug("[TEST DEFEAT] ║         DEFEAT               ║")
    log_debug("[TEST DEFEAT] ║    Player Eliminated         ║")
    log_debug("[TEST DEFEAT] ╚══════════════════════════════╝")
end

--[[
    Show final statistics
]]
function CombatLoopTest.show_final_stats(total_stats)
    log_debug("[FINAL STATS] ╔════════════════════════════════════╗")
    log_debug("[FINAL STATS] ║      FINAL STATISTICS              ║")
    log_debug("[FINAL STATS] ╠════════════════════════════════════╣")
    log_debug("[FINAL STATS] ║ Waves Completed:", total_stats.waves_completed, "            ║")
    log_debug("[FINAL STATS] ║ Total Enemies:", total_stats.total_enemies_killed, "              ║")
    log_debug("[FINAL STATS] ║ Total Damage:", total_stats.total_damage_dealt, "             ║")
    log_debug("[FINAL STATS] ║ Total XP:", total_stats.total_xp_earned, "                  ║")
    log_debug("[FINAL STATS] ║ Total Gold:", total_stats.total_gold_earned, "                ║")
    log_debug("[FINAL STATS] ║ Total Time:", string.format("%.1fs", total_stats.total_time), "                ║")
    log_debug("[FINAL STATS] ╚════════════════════════════════════╝")
end

--[[
    Keyboard shortcut for testing
    Call this from your main input handler
]]
function CombatLoopTest.handle_input(key)
    if key == "t" or key == "T" then
        if not CombatLoopTest.test_running then
            CombatLoopTest.start_test_combat()
        else
            CombatLoopTest.stop_test_combat()
        end
        return true
    end

    if key == "r" or key == "R" then
        CombatLoopTest.reset_test_combat()
        CombatLoopTest.start_test_combat()
        return true
    end

    return false
end

--[[
    Helper: Manually trigger wave progression (for testing intermission)
]]
function CombatLoopTest.trigger_next_wave()
    if CombatLoopTest.combat_loop then
        return CombatLoopTest.combat_loop:progress_to_next_wave()
    end
    return false
end

--[[
    Helper: Get current combat state
]]
function CombatLoopTest.get_current_state()
    if CombatLoopTest.combat_loop then
        return CombatLoopTest.combat_loop:get_current_state()
    end
    return nil
end

--[[
    Helper: Kill all enemies (for testing victory)
]]
function CombatLoopTest.kill_all_enemies()
    if CombatLoopTest.combat_loop then
        local enemies = CombatLoopTest.combat_loop.wave_manager:get_alive_enemies()
        log_debug("[TEST] Killing", #enemies, "enemies")

        for _, enemy_id in ipairs(enemies) do
            if registry and registry:valid(enemy_id) then
                -- Set health to 0
                if setBlackboardFloat then
                    setBlackboardFloat(enemy_id, "health", 0)
                end

                -- Emit death event
                if CombatLoopTest.combat_loop.combat_context.bus then
                    CombatLoopTest.combat_loop.combat_context.bus:emit("OnEntityDeath", {
                        entity = enemy_id,
                        killer = CombatLoopTest.test_player
                    })
                end
            end
        end
    end
end

--[[
    Helper: Damage player (for testing defeat)
]]
function CombatLoopTest.damage_player(amount)
    if CombatLoopTest.test_player and setBlackboardFloat and getBlackboardFloat then
        local current_hp = getBlackboardFloat(CombatLoopTest.test_player, "health") or 100
        local new_hp = math.max(0, current_hp - amount)
        setBlackboardFloat(CombatLoopTest.test_player, "health", new_hp)
        log_debug("[TEST] Player HP:", new_hp)
    end
end

--[[
    Complete example setup function
    Call this once during game initialization
]]
function CombatLoopTest.initialize()
    CombatLoopTest.setup_test_combat()

    log_debug("[CombatLoopTest] ========================================")
    log_debug("[CombatLoopTest] Combat Loop Test Initialized")
    log_debug("[CombatLoopTest] ========================================")
    log_debug("[CombatLoopTest] Controls:")
    log_debug("[CombatLoopTest]   T - Start/Stop combat test")
    log_debug("[CombatLoopTest]   R - Reset and restart")
    log_debug("[CombatLoopTest] ========================================")
    log_debug("[CombatLoopTest] Helper functions:")
    log_debug("[CombatLoopTest]   CombatLoopTest.kill_all_enemies()")
    log_debug("[CombatLoopTest]   CombatLoopTest.damage_player(50)")
    log_debug("[CombatLoopTest]   CombatLoopTest.trigger_next_wave()")
    log_debug("[CombatLoopTest]   CombatLoopTest.get_current_state()")
    log_debug("[CombatLoopTest] ========================================")
end

return CombatLoopTest
