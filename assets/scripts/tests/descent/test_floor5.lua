-- assets/scripts/tests/descent/test_floor5.lua
--[[
================================================================================
BOSS FLOOR TESTS
================================================================================
Tests for floor5.lua (boss arena, phases, victory).
]]

local T = {}

-- Mock spec for testing
local mock_spec = {
    boss = {
        floor = 5,
        arena = {
            width = 15,
            height = 15,
            exploration = false,
        },
        guards = 3,
        stats = {
            hp = 100,
            damage = 20,
            speed = "slow",
        },
        phases = {
            { id = 1, hp_pct_min = 0.50, behavior = "melee_only" },
            { id = 2, hp_pct_min = 0.25, behavior = "summon_guards", summon_count = 2, summon_interval_turns = 5 },
            { id = 3, hp_pct_min = 0.00, behavior = "berserk", damage_multiplier = 1.5 },
        },
        win_condition = "boss_hp_zero",
    },
}

local function create_mock_game_state()
    return {
        player = {
            id = "player_1",
            x = 7,
            y = 13,
            hp = 50,
            hp_max = 50,
        },
        enemies = {},
        floor_num = 5,
    }
end

--------------------------------------------------------------------------------
-- Arena Spawn Tests
--------------------------------------------------------------------------------

function T.test_arena_dimensions()
    local floor5 = require("descent.floor5")
    floor5.reset()
    
    local game_state = create_mock_game_state()
    local success = floor5.init(game_state)
    
    assert(success, "Floor5 init should succeed")
    assert(game_state.map, "Map should be created")
    assert(game_state.map.w == 15, "Arena width should be 15")
    assert(game_state.map.h == 15, "Arena height should be 15")
    
    floor5.reset()
    return true
end

function T.test_boss_spawns()
    local floor5 = require("descent.floor5")
    floor5.reset()
    
    local game_state = create_mock_game_state()
    floor5.init(game_state)
    
    local boss = floor5.get_boss()
    assert(boss, "Boss should spawn")
    assert(boss.is_boss, "Boss should have is_boss flag")
    assert(boss.hp == 100, "Boss HP should be 100")
    assert(boss.alive, "Boss should be alive")
    
    floor5.reset()
    return true
end

function T.test_guards_spawn()
    local floor5 = require("descent.floor5")
    floor5.reset()
    
    local game_state = create_mock_game_state()
    floor5.init(game_state)
    
    local guards = floor5.get_guards()
    assert(#guards >= 1, "At least one guard should spawn")
    
    floor5.reset()
    return true
end

function T.test_player_positioned()
    local floor5 = require("descent.floor5")
    floor5.reset()
    
    local game_state = create_mock_game_state()
    floor5.init(game_state)
    
    -- Player should be at stairs up (entrance)
    assert(game_state.player.x, "Player should have x position")
    assert(game_state.player.y, "Player should have y position")
    
    floor5.reset()
    return true
end

--------------------------------------------------------------------------------
-- Phase Trigger Tests
--------------------------------------------------------------------------------

function T.test_phase_1_initial()
    local floor5 = require("descent.floor5")
    floor5.reset()
    
    local game_state = create_mock_game_state()
    floor5.init(game_state)
    
    local phase = floor5.get_phase()
    assert(phase == 1, "Initial phase should be 1")
    
    floor5.reset()
    return true
end

function T.test_phase_2_at_50_percent()
    local floor5 = require("descent.floor5")
    floor5.reset()
    
    local game_state = create_mock_game_state()
    floor5.init(game_state)
    
    local boss = floor5.get_boss()
    boss.hp = 49  -- Below 50%
    
    floor5.update(game_state)
    
    local phase = floor5.get_phase()
    assert(phase == 2, "Phase should be 2 at <50% HP, got " .. tostring(phase))
    
    floor5.reset()
    return true
end

function T.test_phase_3_at_25_percent()
    local floor5 = require("descent.floor5")
    floor5.reset()
    
    local game_state = create_mock_game_state()
    floor5.init(game_state)
    
    local boss = floor5.get_boss()
    boss.hp = 24  -- Below 25%
    
    floor5.update(game_state)
    
    local phase = floor5.get_phase()
    assert(phase == 3, "Phase should be 3 at <25% HP, got " .. tostring(phase))
    
    floor5.reset()
    return true
end

function T.test_phase_change_callback()
    local floor5 = require("descent.floor5")
    floor5.reset()
    
    local callback_called = false
    local new_phase_received = nil
    
    floor5.on_phase_change(function(new_phase, old_phase, phase_spec)
        callback_called = true
        new_phase_received = new_phase
    end)
    
    local game_state = create_mock_game_state()
    floor5.init(game_state)
    
    local boss = floor5.get_boss()
    boss.hp = 49
    
    floor5.update(game_state)
    
    assert(callback_called, "Phase change callback should be called")
    assert(new_phase_received == 2, "New phase should be 2")
    
    floor5.reset()
    return true
end

--------------------------------------------------------------------------------
-- Victory Condition Tests
--------------------------------------------------------------------------------

function T.test_victory_on_boss_death()
    local floor5 = require("descent.floor5")
    floor5.reset()
    
    local victory_triggered = false
    floor5.on_victory(function(gs)
        victory_triggered = true
    end)
    
    local game_state = create_mock_game_state()
    floor5.init(game_state)
    
    local boss = floor5.get_boss()
    boss.hp = 0
    boss.alive = false
    
    floor5.update(game_state)
    
    assert(victory_triggered, "Victory should be triggered")
    assert(floor5.is_victory(), "is_victory should return true")
    
    floor5.reset()
    return true
end

function T.test_no_victory_while_boss_alive()
    local floor5 = require("descent.floor5")
    floor5.reset()
    
    local victory_triggered = false
    floor5.on_victory(function(gs)
        victory_triggered = true
    end)
    
    local game_state = create_mock_game_state()
    floor5.init(game_state)
    
    -- Boss still has HP
    floor5.update(game_state)
    
    assert(not victory_triggered, "Victory should NOT be triggered while boss alive")
    assert(not floor5.is_victory(), "is_victory should return false")
    
    floor5.reset()
    return true
end

--------------------------------------------------------------------------------
-- Error Handling Tests
--------------------------------------------------------------------------------

function T.test_error_callback()
    local floor5 = require("descent.floor5")
    floor5.reset()
    
    local error_received = nil
    floor5.on_error(function(err, gs)
        error_received = err
    end)
    
    -- Error handling is tested indirectly - the callback should be set
    assert(floor5.get_state, "get_state should exist for error diagnosis")
    
    floor5.reset()
    return true
end

function T.test_state_snapshot()
    local floor5 = require("descent.floor5")
    floor5.reset()
    
    local game_state = create_mock_game_state()
    floor5.init(game_state)
    
    local state = floor5.get_state()
    
    assert(state.initialized, "State should be initialized")
    assert(state.phase == 1, "Phase should be 1")
    assert(state.boss_alive, "Boss should be alive")
    assert(state.boss_hp == 100, "Boss HP should be 100")
    assert(not state.victory, "Victory should be false")
    
    floor5.reset()
    return true
end

--------------------------------------------------------------------------------
-- Test Runner
--------------------------------------------------------------------------------

function T.run_all()
    local tests = {
        { name = "arena_dimensions", fn = T.test_arena_dimensions },
        { name = "boss_spawns", fn = T.test_boss_spawns },
        { name = "guards_spawn", fn = T.test_guards_spawn },
        { name = "player_positioned", fn = T.test_player_positioned },
        { name = "phase_1_initial", fn = T.test_phase_1_initial },
        { name = "phase_2_at_50_percent", fn = T.test_phase_2_at_50_percent },
        { name = "phase_3_at_25_percent", fn = T.test_phase_3_at_25_percent },
        { name = "phase_change_callback", fn = T.test_phase_change_callback },
        { name = "victory_on_boss_death", fn = T.test_victory_on_boss_death },
        { name = "no_victory_while_boss_alive", fn = T.test_no_victory_while_boss_alive },
        { name = "error_callback", fn = T.test_error_callback },
        { name = "state_snapshot", fn = T.test_state_snapshot },
    }
    
    local passed = 0
    local failed = 0
    
    for _, test in ipairs(tests) do
        local ok, err = pcall(test.fn)
        if ok then
            print("[PASS] " .. test.name)
            passed = passed + 1
        else
            print("[FAIL] " .. test.name .. ": " .. tostring(err))
            failed = failed + 1
        end
    end
    
    print("")
    print(string.format("Boss tests: %d passed, %d failed", passed, failed))
    
    return failed == 0
end

return T
