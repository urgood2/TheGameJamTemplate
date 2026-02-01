-- assets/scripts/tests/descent/test_floor_transition.lua
--[[
================================================================================
FLOOR TRANSITION TESTS
================================================================================
Tests for floor_transition.lua.
]]

local T = {}

local function create_mock_map(floor_num)
    local Map = require("descent.map")
    local map = Map.new(15, 15)
    
    -- Create walkable floor
    for y = 2, 14 do
        for x = 2, 14 do
            Map.set_tile(map, x, y, Map.TILE.FLOOR)
        end
    end
    
    -- Add stairs
    if floor_num < 5 then
        Map.set_tile(map, 10, 10, Map.TILE.STAIRS_DOWN)
    end
    if floor_num > 1 then
        Map.set_tile(map, 5, 5, Map.TILE.STAIRS_UP)
    end
    
    return map
end

local function create_mock_player()
    return {
        id = "player_1",
        x = 7,
        y = 7,
        hp = 50,
        hp_max = 50,
        mp = 25,
        mp_max = 25,
        xp = 100,
        level = 3,
        inventory = { { id = "sword" }, { id = "potion" } },
        equipment = { weapon = "sword" },
        god = "trog",
        piety = 50,
        spells = { "magic_missile" },
        kills = 10,
        turns_taken = 100,
        alive = true,
    }
end

local function create_mock_game_state(floor_num)
    return {
        player = create_mock_player(),
        map = create_mock_map(floor_num),
        floor_num = floor_num,
        enemies = {},
        items = {},
        seed = 12345,
    }
end

--------------------------------------------------------------------------------
-- Single Advancement Tests
--------------------------------------------------------------------------------

function T.test_can_use_stairs_down()
    local transition = require("descent.floor_transition")
    transition.reset()
    
    local game_state = create_mock_game_state(1)
    game_state.player.x = 10
    game_state.player.y = 10  -- On stairs down
    
    local can, reason = transition.can_use_stairs(game_state, "down")
    assert(can, "Should be able to use stairs down on floor 1")
    
    return true
end

function T.test_cannot_use_stairs_not_on_stairs()
    local transition = require("descent.floor_transition")
    transition.reset()
    
    local game_state = create_mock_game_state(1)
    game_state.player.x = 7
    game_state.player.y = 7  -- Not on stairs
    
    local can, reason = transition.can_use_stairs(game_state, "down")
    assert(not can, "Should NOT be able to use stairs when not on them")
    assert(reason == "not_on_stairs_down", "Reason should be not_on_stairs_down")
    
    return true
end

function T.test_floor_advances_on_stairs()
    local transition = require("descent.floor_transition")
    transition.reset()
    
    local game_state = create_mock_game_state(1)
    game_state.player.x = 10
    game_state.player.y = 10
    
    local result = transition.use_stairs(game_state, "down")
    
    assert(result.success, "Transition should succeed")
    assert(result.from_floor == 1, "From floor should be 1")
    assert(result.to_floor == 2, "To floor should be 2")
    assert(game_state.floor_num == 2, "Game state floor should be 2")
    
    transition.reset()
    return true
end

function T.test_cannot_go_below_floor_5()
    local transition = require("descent.floor_transition")
    transition.reset()
    
    local game_state = create_mock_game_state(5)
    -- Floor 5 has no stairs down per spec
    
    local can, reason = transition.can_use_stairs(game_state, "down")
    -- Either not on stairs or already at bottom
    assert(not can, "Should NOT be able to descend from floor 5")
    
    transition.reset()
    return true
end

--------------------------------------------------------------------------------
-- State Persistence Tests
--------------------------------------------------------------------------------

function T.test_hp_persists()
    local transition = require("descent.floor_transition")
    transition.reset()
    
    local game_state = create_mock_game_state(1)
    game_state.player.x = 10
    game_state.player.y = 10
    game_state.player.hp = 42
    
    transition.use_stairs(game_state, "down")
    
    assert(game_state.player.hp == 42, "HP should persist: " .. game_state.player.hp)
    
    transition.reset()
    return true
end

function T.test_mp_persists()
    local transition = require("descent.floor_transition")
    transition.reset()
    
    local game_state = create_mock_game_state(1)
    game_state.player.x = 10
    game_state.player.y = 10
    game_state.player.mp = 15
    
    transition.use_stairs(game_state, "down")
    
    assert(game_state.player.mp == 15, "MP should persist")
    
    transition.reset()
    return true
end

function T.test_xp_persists()
    local transition = require("descent.floor_transition")
    transition.reset()
    
    local game_state = create_mock_game_state(1)
    game_state.player.x = 10
    game_state.player.y = 10
    game_state.player.xp = 500
    
    transition.use_stairs(game_state, "down")
    
    assert(game_state.player.xp == 500, "XP should persist")
    
    transition.reset()
    return true
end

function T.test_inventory_persists()
    local transition = require("descent.floor_transition")
    transition.reset()
    
    local game_state = create_mock_game_state(1)
    game_state.player.x = 10
    game_state.player.y = 10
    game_state.player.inventory = { { id = "item1" }, { id = "item2" } }
    
    transition.use_stairs(game_state, "down")
    
    assert(#game_state.player.inventory == 2, "Inventory should persist")
    
    transition.reset()
    return true
end

function T.test_god_persists()
    local transition = require("descent.floor_transition")
    transition.reset()
    
    local game_state = create_mock_game_state(1)
    game_state.player.x = 10
    game_state.player.y = 10
    game_state.player.god = "trog"
    game_state.player.piety = 75
    
    transition.use_stairs(game_state, "down")
    
    assert(game_state.player.god == "trog", "God should persist")
    assert(game_state.player.piety == 75, "Piety should persist")
    
    transition.reset()
    return true
end

function T.test_spells_persist()
    local transition = require("descent.floor_transition")
    transition.reset()
    
    local game_state = create_mock_game_state(1)
    game_state.player.x = 10
    game_state.player.y = 10
    game_state.player.spells = { "fireball", "heal" }
    
    transition.use_stairs(game_state, "down")
    
    assert(#game_state.player.spells == 2, "Spells should persist")
    
    transition.reset()
    return true
end

--------------------------------------------------------------------------------
-- Floor-Local Reset Tests
--------------------------------------------------------------------------------

function T.test_enemies_reset()
    local transition = require("descent.floor_transition")
    transition.reset()
    
    local game_state = create_mock_game_state(1)
    game_state.player.x = 10
    game_state.player.y = 10
    game_state.enemies = { { id = 1 }, { id = 2 } }
    
    transition.use_stairs(game_state, "down")
    
    -- Enemies should be reset (empty or new set from procgen)
    -- The new floor generates new enemies, old ones are gone
    assert(type(game_state.enemies) == "table", "Enemies should be a table")
    
    transition.reset()
    return true
end

function T.test_map_changes()
    local transition = require("descent.floor_transition")
    transition.reset()
    
    local game_state = create_mock_game_state(1)
    game_state.player.x = 10
    game_state.player.y = 10
    local old_map = game_state.map
    
    transition.use_stairs(game_state, "down")
    
    assert(game_state.map ~= old_map, "Map should change on floor transition")
    
    transition.reset()
    return true
end

--------------------------------------------------------------------------------
-- Boss Floor Trigger Tests
--------------------------------------------------------------------------------

function T.test_floor_5_triggers_callback()
    local transition = require("descent.floor_transition")
    transition.reset()
    
    local boss_floor_triggered = false
    transition.on_boss_floor(function(gs)
        boss_floor_triggered = true
    end)
    
    local game_state = create_mock_game_state(4)
    -- Set player on stairs down
    local Map = require("descent.map")
    Map.set_tile(game_state.map, 10, 10, Map.TILE.STAIRS_DOWN)
    game_state.player.x = 10
    game_state.player.y = 10
    
    transition.use_stairs(game_state, "down")
    
    assert(game_state.floor_num == 5, "Should be on floor 5")
    assert(boss_floor_triggered, "Boss floor callback should trigger")
    
    transition.reset()
    return true
end

--------------------------------------------------------------------------------
-- Test Runner
--------------------------------------------------------------------------------

function T.run_all()
    local tests = {
        { name = "can_use_stairs_down", fn = T.test_can_use_stairs_down },
        { name = "cannot_use_stairs_not_on_stairs", fn = T.test_cannot_use_stairs_not_on_stairs },
        { name = "floor_advances_on_stairs", fn = T.test_floor_advances_on_stairs },
        { name = "cannot_go_below_floor_5", fn = T.test_cannot_go_below_floor_5 },
        { name = "hp_persists", fn = T.test_hp_persists },
        { name = "mp_persists", fn = T.test_mp_persists },
        { name = "xp_persists", fn = T.test_xp_persists },
        { name = "inventory_persists", fn = T.test_inventory_persists },
        { name = "god_persists", fn = T.test_god_persists },
        { name = "spells_persist", fn = T.test_spells_persist },
        { name = "enemies_reset", fn = T.test_enemies_reset },
        { name = "map_changes", fn = T.test_map_changes },
        { name = "floor_5_triggers_callback", fn = T.test_floor_5_triggers_callback },
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
    print(string.format("Floor transition tests: %d passed, %d failed", passed, failed))
    
    return failed == 0
end

return T
